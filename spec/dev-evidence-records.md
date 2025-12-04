# Evidence Records Implementation Guide

**Version**: 2.0
**Audience**: Software Developers
**Last Updated**: 2025-11-29
**Status**: Draft

> **Scope**: Third-party timestamp attestation for clinical trial diary data
>
> **See**: prd-evidence-records.md for product requirements (executive-level)
> **See**: docs/adr/ADR-008-timestamp-attestation.md for architecture decision
> **See**: prd-event-sourcing-system.md for event sourcing architecture
> **See**: prd-database.md for audit trail requirements
> **See**: prd-clinical-trials.md for FDA 21 CFR Part 11 compliance requirements
> **See**: dev-compliance-practices.md for ALCOA+ implementation guidance

---

## Executive Summary

This document specifies the implementation of **third-party timestamp attestation** for clinical trial diary data. Per [ADR-008](../docs/adr/ADR-008-timestamp-attestation.md), the recommended approach is **Bitcoin blockchain via OpenTimestamps**, with RFC 3161 TSA as a deprecated fallback for regulatory compliance only.

### Recommended Approach: Bitcoin/OpenTimestamps

Evidence Records provide **long-term non-repudiation** of data existence and integrity, essential for:
- FDA 21 CFR Part 11 audit trail tamper-evidence
- Clinical trial data archival (15-25 year retention)
- Third-party verifiable proof of data integrity

**Key Benefits of Bitcoin/OpenTimestamps**:
1. **Superior security** - Zero successful attacks in 16-year history
2. **Infeasible attack economics** - $5-20B attack cost exceeds any clinical trial value
3. **No backdating possible** - Mathematical impossibility, not policy enforcement
4. **Zero cost** - Aggregation makes unlimited timestamps free
5. **Public failure mode** - Any attack attempt visible to entire network
6. **Highest longevity** - Most likely to exist in 2040 (nation-state adoption)

### Deprecated Approach: RFC 3161 TSA

The traditional RFC 3161 Time-Stamp Authority approach is **deprecated** due to:
- Proven track record of compromise (DigiNotar, Comodo, NIC India)
- Silent failure mode (breaches undetectable until discovered)
- Backdating capability if compromised
- Lower attack cost (~$100K vs $5-20B for Bitcoin)

**Use only when**: Regulators explicitly require RFC 3161 format.

---

## Current State Analysis

### Existing Hash Chain Implementation

The `append_only_datastore` package implements:

```dart
// Current hash chain (simplified)
class Event {
  final String eventId;
  final String aggregateId;
  final String eventType;
  final Map<String, dynamic> payload;
  final String previousHash;  // Links to previous event
  final String hash;          // SHA-256 of this event
  final int sequenceNumber;
  final DateTime timestamp;
}
```

**Strengths**:
- Append-only with database-enforced immutability
- SHA-256 hash chain provides tamper detection
- Sequential ordering via sequence numbers
- Client timestamp + server timestamp for ALCOA+ compliance

**Limitations**:
- **No independent time proof** - timestamps are self-asserted
- **Single algorithm** - no structured renewal mechanism
- **No Merkle tree** - each event requires individual hash
- **Not standard format** - proprietary structure, not interoperable
- **No TSA integration** - no third-party attestation

---

## Recommended Implementation: Bitcoin/OpenTimestamps

> **REQ-d00028**: Third-party timestamp attestation using Bitcoin blockchain via OpenTimestamps protocol

### Overview

OpenTimestamps is a free, open-source protocol that aggregates hash commitments into Bitcoin transactions. It provides cryptographically-secure timestamps with zero marginal cost.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Clinical Diary App                            │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              append_only_datastore                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │ │
│  │  │ Event Store  │  │ Hash Chain   │  │ Sync Engine      │  │ │
│  │  │ (Sembast)    │  │ (SHA-256)    │  │ (REST API)       │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           OpenTimestamps Service (NEW)                      │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │ │
│  │  │ Daily Hash   │  │ OTS Client   │  │ Proof Storage    │  │ │
│  │  │ Aggregator   │  │ (HTTP API)   │  │ (.ots files)     │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   ┌──────────────────┐
                   │ OpenTimestamps   │
                   │ Calendar Servers │
                   │ + Bitcoin        │
                   └──────────────────┘
```

### How OpenTimestamps Works

1. **Submit**: Hash is submitted to OpenTimestamps calendar servers
2. **Aggregate**: Calendar server aggregates multiple hashes into a Merkle tree
3. **Commit**: Root hash is embedded in a Bitcoin transaction (OP_RETURN)
4. **Confirm**: Bitcoin network confirms the transaction (~60 minutes)
5. **Upgrade**: Proof file (.ots) is upgraded with Bitcoin block information

### Implementation

#### Dart/Flutter Client

```dart
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// OpenTimestamps client for Bitcoin timestamping
/// REQ-d00028
class OpenTimestampsClient {
  static const List<String> calendarUrls = [
    'https://a.pool.opentimestamps.org',
    'https://b.pool.opentimestamps.org',
    'https://a.pool.eternitywall.com',
  ];

  final http.Client httpClient;

  OpenTimestampsClient({http.Client? client})
      : httpClient = client ?? http.Client();

  /// Submit hash to OpenTimestamps calendars
  /// Returns incomplete proof (pending Bitcoin confirmation)
  Future<Uint8List> stamp(Uint8List hash) async {
    final futures = calendarUrls.map((url) => _submitToCalendar(url, hash));
    final results = await Future.wait(futures, eagerError: false);

    // Return first successful result
    for (final result in results) {
      if (result != null) return result;
    }

    throw Exception('All calendar servers failed');
  }

  Future<Uint8List?> _submitToCalendar(String url, Uint8List hash) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$url/digest'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: hash,
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      // Log but continue to next calendar
    }
    return null;
  }

  /// Upgrade incomplete proof to complete Bitcoin-attested proof
  Future<Uint8List?> upgrade(Uint8List incompleteProof) async {
    // Parse proof to get pending attestation URL
    // Submit to URL to get upgraded proof with Bitcoin block
    // Returns null if not yet confirmed (retry later)
  }

  /// Verify a complete OpenTimestamps proof
  Future<VerificationResult> verify(Uint8List data, Uint8List proof) async {
    // Parse proof structure
    // Verify Merkle path to Bitcoin commitment
    // Verify Bitcoin block contains expected transaction
    // Return verification result with timestamp
  }
}

/// Verification result for OpenTimestamps proof
class VerificationResult {
  final bool isValid;
  final DateTime? attestedTime;
  final int? bitcoinBlockHeight;
  final String? bitcoinTxId;
  final List<String> errors;

  VerificationResult({
    required this.isValid,
    this.attestedTime,
    this.bitcoinBlockHeight,
    this.bitcoinTxId,
    this.errors = const [],
  });
}
```

#### Daily Aggregation Strategy

Given our operational constraints (<10 entries/user/day, day-level precision sufficient):

```dart
/// Daily hash aggregation for efficient timestamping
/// REQ-d00028
class DailyTimestampService {
  final OpenTimestampsClient otsClient;
  final LocalStorage storage;

  /// Called daily (e.g., by background scheduler)
  Future<void> createDailyTimestamp() async {
    // 1. Get all events from today
    final todayEvents = await storage.getEventsForDate(DateTime.now());
    if (todayEvents.isEmpty) return;

    // 2. Compute aggregate hash of all event hashes
    final eventHashes = todayEvents.map((e) => e.hash).toList();
    final aggregateHash = _computeAggregateHash(eventHashes);

    // 3. Submit to OpenTimestamps
    final incompleteProof = await otsClient.stamp(aggregateHash);

    // 4. Store incomplete proof locally
    await storage.storePendingProof(
      date: DateTime.now(),
      aggregateHash: aggregateHash,
      eventIds: todayEvents.map((e) => e.id).toList(),
      incompleteProof: incompleteProof,
    );

    // 5. Schedule upgrade check (proof completes after ~60 min)
    await _scheduleUpgradeCheck();
  }

  Uint8List _computeAggregateHash(List<Uint8List> hashes) {
    // Simple concatenation + hash (sufficient for small volumes)
    // No Merkle tree needed for <10 entries
    final combined = hashes.expand((h) => h).toList();
    return Uint8List.fromList(sha256.convert(combined).bytes);
  }
}
```

### Proof Storage

Each device stores:

```
/data/timestamps/
  2025-11-28.ots          # Complete Bitcoin-attested proof
  2025-11-28.json         # Metadata: event IDs covered by proof
  2025-11-29.pending.ots  # Incomplete proof (awaiting Bitcoin)
```

### Verification Procedure

To verify any diary entry was recorded on or before a specific date:

1. Load the .ots proof file for that date
2. Compute the aggregate hash of all events for that date
3. Verify the OpenTimestamps proof against the aggregate hash
4. The Bitcoin block timestamp proves data existed at that time

### Cost Analysis

| Item | Cost |
| ---- | ---- |
| OpenTimestamps submission | Free |
| Proof storage | ~1KB per day |
| Bitcoin transaction fees | Paid by calendar operators |
| **Annual cost per user** | **$0** |

### Security Properties

| Property | Bitcoin/OpenTimestamps |
| -------- | ---------------------- |
| Attack cost | $5-20 billion (51% attack) |
| Backdating possible | No (mathematically impossible) |
| Failure mode | Public (chain fork visible) |
| Historical breaches | Zero in 16 years |
| Single point of failure | None |

### Limitations

| Limitation | Impact | Mitigation |
| ---------- | ------ | ---------- |
| ±2 hour time precision | Acceptable for day-level entries | Combine with internal timestamps |
| ~60 minute finality | Acceptable for diary use case | Queue proofs for later completion |
| Requires internet | Cannot timestamp offline | Queue for when connectivity returns |

---

## Deprecated: RFC 3161 TSA Implementation

> **⚠️ DEPRECATED**: This approach is deprecated per [ADR-008](../docs/adr/ADR-008-timestamp-attestation.md). Use only when regulators explicitly require RFC 3161 format.
>
> **REQ-d00029** (DEPRECATED): RFC 3161 TSA-based timestamp attestation

The following sections document the RFC 3161/RFC 4998 approach for regulatory compliance scenarios where traditional TSA format is mandated.

**Deprecation reasons**:
- Proven track record of compromise (DigiNotar, Comodo, NIC India)
- Silent failure mode (breaches undetectable until discovered)
- Backdating capability if compromised
- Lower attack cost (~$100K vs $5-20B for Bitcoin)
- Ongoing per-timestamp costs ($0.02-0.40 each)

---

## RFC 4998 (ASN.1 ERS) Requirements

### Core Data Structures

RFC 4998 defines the following ASN.1 structures:

#### ArchiveTimeStamp

```asn1
ArchiveTimeStamp ::= SEQUENCE {
    digestAlgorithm [0] AlgorithmIdentifier OPTIONAL,
    attributes [1] Attributes OPTIONAL,
    reducedHashtree [2] SEQUENCE OF PartialHashtree OPTIONAL,
    timeStamp ContentInfo
}

PartialHashtree ::= SEQUENCE OF OCTET STRING
Attributes ::= SET SIZE (1..MAX) OF Attribute
```

**Components**:
- `digestAlgorithm`: Hash algorithm used (SHA-256, SHA-384, etc.)
- `attributes`: Additional metadata (optional)
- `reducedHashtree`: Partial Merkle tree for verification
- `timeStamp`: RFC 3161 TimeStampToken from TSA

#### Archive Chains and Sequences

```asn1
ArchiveTimeStampChain ::= SEQUENCE OF ArchiveTimeStamp
ArchiveTimeStampSequence ::= SEQUENCE OF ArchiveTimeStampChain
EvidenceRecord ::= SEQUENCE {
    version INTEGER { v1(1) },
    digestAlgorithms SET OF AlgorithmIdentifier,
    cryptoInfos [0] CryptoInfos OPTIONAL,
    encryptionInfo [1] EncryptionInfo OPTIONAL,
    archiveTimeStampSequence ArchiveTimeStampSequence
}
```

### Merkle Hash Tree Construction

RFC 4998 uses ordered Merkle hash trees where:

1. **Leaves** are hash values of data objects
2. **Inner nodes** contain hash of concatenated children
3. **Root hash** represents all data objects unambiguously
4. **Reduced hash tree** contains only nodes needed for verification

```
         [Root Hash] ← Timestamped
            /    \
       [H12]      [H34]
       /   \      /   \
     [H1] [H2]  [H3] [H4]
      |    |     |    |
    Doc1 Doc2  Doc3 Doc4
```

### Hash Algorithm Requirements

Within an `ArchiveTimeStampChain`:
- All `reducedHashtrees` MUST use the same hash algorithm
- Hash algorithm in timestamp request MUST match hash tree algorithm
- Algorithms MUST be secure at time of timestamp

### Renewal Requirements

**Timestamp Renewal**: Before TSA certificate expires or algorithm weakens:
1. Hash the content of the old `timeStamp` field
2. Create new ArchiveTimeStamp with new timestamp
3. Add to same ArchiveTimeStampChain

**Hash-Tree Renewal**: When hash algorithm becomes weak:
1. Hash all old ArchiveTimeStamps AND original data
2. Create new ArchiveTimeStamp with new (stronger) algorithm
3. Start new ArchiveTimeStampChain

---

## RFC 6283 (XMLERS) Requirements

### XML Schema Structure

XMLERS provides XML syntax equivalent to ASN.1 ERS:

```xml
<EvidenceRecord xmlns="urn:ietf:params:xml:ns:ers">
  <EncryptionInformation>...</EncryptionInformation>
  <SupportingInformationList>...</SupportingInformationList>
  <ArchiveTimeStampSequence>
    <ArchiveTimeStampChain>
      <ArchiveTimeStamp>
        <HashTree>
          <Sequence>
            <DigestValue>...</DigestValue>
          </Sequence>
        </HashTree>
        <TimeStamp>...</TimeStamp>
      </ArchiveTimeStamp>
    </ArchiveTimeStampChain>
  </ArchiveTimeStampSequence>
</EvidenceRecord>
```

### Key Differences from ASN.1 ERS

| Aspect | RFC 4998 (ASN.1) | RFC 6283 (XML) |
| -------- | ----------------- | ---------------- |
| Encoding | DER binary | XML text |
| Size | Compact | Larger |
| Human-readable | No | Yes |
| Canonicalization | N/A | Required (C14N) |
| Integration | CMS/PKCS#7 | XMLDSIG/XAdES |

### XML Canonicalization

For XML data objects, XMLERS requires **Exclusive XML Canonicalization** (exc-c14n) per [RFC 3076](https://datatracker.ietf.org/doc/html/rfc3076) to ensure consistent hashing.

---

## Dart Ecosystem Analysis

### Available Packages

| Package | Purpose | Capabilities | Gaps |
| --------- | --------- | -------------- | ------ |
| [pointycastle](https://pub.dev/packages/pointycastle) | Cryptography | SHA-256/384/512, RSA, ECDSA | No TSP client, no Merkle tree |
| [asn1lib](https://pub.dev/packages/asn1lib) | ASN.1 encoding | BER/DER encode/decode | Minimal complex type support |
| [x509](https://pub.dev/packages/x509) | X.509 certificates | Certificate parsing, EC keys | No TSP, no CMS |
| crypto | Basic hashing | SHA-256, HMAC | No signatures, no ASN.1 |

### Pointy Castle Capabilities

**Digest Algorithms** (all required by ERS):
- SHA-256, SHA-384, SHA-512 (recommended)
- SHA-1 (legacy, not recommended)
- SHA-3 family (future-proof)

**Signature Algorithms**:
- RSA with PKCS#1 v2.0 (SHA-256/RSA)
- ECDSA (P-256, P-384)

**Usage Pattern**:
```dart
import 'package:pointycastle/pointycastle.dart';

// Create digest
final sha256 = Digest('SHA-256');
final hash = sha256.process(Uint8List.fromList(data));

// Create signer (for TSP request signing if needed)
final signer = Signer('SHA-256/RSA');
signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
final signature = signer.generateSignature(hash);
```

---

## Implementation Gaps

### Gap 1: RFC 3161 Time-Stamp Protocol Client

**Status**: Not available in Dart ecosystem

**Required Functionality**:
- Generate TimeStampRequest ASN.1 structure
- HTTP POST to TSA endpoint
- Parse TimeStampResponse
- Verify TimeStampToken (CMS SignedData)
- Extract timestamp and hash from response

**Implementation Approach**:
```dart
/// RFC 3161 Time-Stamp Request
class TimeStampRequest {
  final int version = 1;
  final String hashAlgorithmOid; // e.g., "2.16.840.1.101.3.4.2.1" for SHA-256
  final Uint8List messageImprint;
  final String? policyOid;
  final Uint8List? nonce;
  final bool certReq;

  Uint8List toDer() {
    // Build ASN.1 structure using asn1lib
  }
}

/// TSP Client
class TimeStampClient {
  final String tsaUrl;
  final http.Client httpClient;

  Future<TimeStampResponse> getTimeStamp(Uint8List dataHash) async {
    final request = TimeStampRequest(
      hashAlgorithmOid: SHA256_OID,
      messageImprint: dataHash,
      certReq: true,
    );

    final response = await httpClient.post(
      Uri.parse(tsaUrl),
      headers: {
        'Content-Type': 'application/timestamp-query',
      },
      body: request.toDer(),
    );

    return TimeStampResponse.fromDer(response.bodyBytes);
  }
}
```

**Effort Estimate**: High - requires CMS/PKCS#7 parsing

---

### Gap 2: Merkle Tree Implementation

**Status**: Not available, must implement

**Required Functionality**:
- Build hash tree from list of data hashes
- Generate reduced hash tree for verification
- Verify data membership in tree
- Support variable leaf counts (padding for power-of-2)

**Implementation Approach**:
```dart
/// Merkle Tree for Evidence Records
class MerkleTree {
  final Digest digest;
  final List<Uint8List> leaves;
  late final Uint8List rootHash;
  late final List<List<Uint8List>> levels;

  MerkleTree({
    required this.leaves,
    Digest? digest,
  }) : digest = digest ?? Digest('SHA-256') {
    _buildTree();
  }

  void _buildTree() {
    // Pad to power of 2 if needed
    final paddedLeaves = _padToPowerOfTwo(leaves);

    levels = [paddedLeaves];
    var currentLevel = paddedLeaves;

    while (currentLevel.length > 1) {
      final nextLevel = <Uint8List>[];
      for (var i = 0; i < currentLevel.length; i += 2) {
        final combined = Uint8List.fromList([
          ...currentLevel[i],
          ...currentLevel[i + 1],
        ]);
        nextLevel.add(digest.process(combined));
      }
      levels.add(nextLevel);
      currentLevel = nextLevel;
    }

    rootHash = currentLevel.first;
  }

  /// Get reduced hash tree for single leaf verification
  List<Uint8List> getProof(int leafIndex) {
    final proof = <Uint8List>[];
    var index = leafIndex;

    for (var level = 0; level < levels.length - 1; level++) {
      final siblingIndex = index % 2 == 0 ? index + 1 : index - 1;
      proof.add(levels[level][siblingIndex]);
      index ~/= 2;
    }

    return proof;
  }

  /// Verify leaf membership
  bool verify(Uint8List leafHash, int leafIndex, List<Uint8List> proof) {
    var computed = leafHash;
    var index = leafIndex;

    for (final sibling in proof) {
      if (index % 2 == 0) {
        computed = digest.process(Uint8List.fromList([...computed, ...sibling]));
      } else {
        computed = digest.process(Uint8List.fromList([...sibling, ...computed]));
      }
      index ~/= 2;
    }

    return _bytesEqual(computed, rootHash);
  }
}
```

**Effort Estimate**: Medium - straightforward algorithm

---

### Gap 3: Evidence Record ASN.1 Structures

**Status**: Not available, must implement

**Required Functionality**:
- Encode/decode ArchiveTimeStamp
- Encode/decode ArchiveTimeStampChain
- Encode/decode ArchiveTimeStampSequence
- Encode/decode EvidenceRecord

**Implementation Approach**:
```dart
/// ASN.1 OIDs for ERS
class ErsOids {
  static const String sha256 = '2.16.840.1.101.3.4.2.1';
  static const String sha384 = '2.16.840.1.101.3.4.2.2';
  static const String sha512 = '2.16.840.1.101.3.4.2.3';
  static const String ersContentType = '1.2.840.113549.1.9.16.1.27';
}

/// Archive Time-Stamp per RFC 4998
class ArchiveTimeStamp {
  final String? digestAlgorithmOid;
  final List<List<Uint8List>>? reducedHashTree;
  final Uint8List timeStampToken; // RFC 3161 TimeStampToken

  /// Encode to DER
  Uint8List toDer() {
    final seq = ASN1Sequence();

    if (digestAlgorithmOid != null) {
      final algSeq = ASN1Sequence()
        ..add(ASN1ObjectIdentifier.fromComponentString(digestAlgorithmOid!));
      seq.add(ASN1Application(0, algSeq.encodedBytes));
    }

    if (reducedHashTree != null && reducedHashTree!.isNotEmpty) {
      final hashTreeSeq = ASN1Sequence();
      for (final level in reducedHashTree!) {
        final partialTree = ASN1Sequence();
        for (final hash in level) {
          partialTree.add(ASN1OctetString(hash));
        }
        hashTreeSeq.add(partialTree);
      }
      seq.add(ASN1Application(2, hashTreeSeq.encodedBytes));
    }

    // ContentInfo wrapping TimeStampToken
    seq.add(_wrapAsContentInfo(timeStampToken));

    return seq.encodedBytes;
  }

  /// Decode from DER
  static ArchiveTimeStamp fromDer(Uint8List bytes) {
    final parser = ASN1Parser(bytes);
    final seq = parser.nextObject() as ASN1Sequence;
    // Parse fields...
  }
}

/// Evidence Record per RFC 4998
class EvidenceRecord {
  static const int version = 1;
  final Set<String> digestAlgorithms;
  final List<ArchiveTimeStampChain> archiveTimeStampSequence;

  Uint8List toDer() { /* ... */ }
  static EvidenceRecord fromDer(Uint8List bytes) { /* ... */ }

  /// Add new timestamp (renewal)
  EvidenceRecord addTimeStamp(ArchiveTimeStamp ats) {
    // Add to current chain or start new chain
  }
}
```

**Effort Estimate**: High - complex ASN.1 structures

---

### Gap 4: CMS/PKCS#7 SignedData Handling

**Status**: Partial support via x509 package

**Required Functionality**:
- Parse CMS SignedData (for TimeStampToken)
- Extract signing certificate
- Verify signature
- Extract encapsulated content (TSTInfo)

**Implementation Approach**:
```dart
/// CMS SignedData parser for TimeStampToken verification
class CmsSignedData {
  final int version;
  final Set<String> digestAlgorithms;
  final Uint8List encapContentInfo;
  final List<X509Certificate> certificates;
  final List<SignerInfo> signerInfos;

  static CmsSignedData fromDer(Uint8List bytes) {
    // Parse SignedData structure
    // See RFC 5652 Section 5
  }

  /// Verify signature using embedded certificate
  bool verifySignature() {
    // Extract public key from certificate
    // Verify SignerInfo signature over TSTInfo
  }

  /// Extract TSTInfo content
  TstInfo extractTstInfo() {
    // Parse TSTInfo from encapContentInfo
  }
}

/// TSTInfo from RFC 3161
class TstInfo {
  final int version;
  final String policyOid;
  final MessageImprint messageImprint;
  final BigInt serialNumber;
  final DateTime genTime;
  final Accuracy? accuracy;
  final bool ordering;
  final BigInt? nonce;

  static TstInfo fromDer(Uint8List bytes) { /* ... */ }
}
```

**Effort Estimate**: High - requires understanding of CMS structure

---

### Gap 5: XML Canonicalization (for XMLERS)

**Status**: Not available in Dart ecosystem

**Required Functionality**:
- Exclusive XML Canonicalization (exc-c14n)
- Namespace handling
- Whitespace normalization

**Implementation Approach**:
```dart
/// Exclusive XML Canonicalization per RFC 3076
class ExcC14N {
  /// Canonicalize XML element
  String canonicalize(XmlElement element, {
    List<String>? inclusiveNamespaces,
  }) {
    // 1. Normalize whitespace
    // 2. Sort attributes
    // 3. Handle namespaces
    // 4. Output in canonical form
  }
}
```

**Effort Estimate**: Medium - complex but well-documented algorithm

**Alternative**: For clinical diary data stored as JSON, XMLERS may not be necessary. Focus on ASN.1 ERS (RFC 4998) for non-XML data.

---

### Gap 6: Algorithm Renewal Automation

**Status**: Not implemented

**Required Functionality**:
- Monitor algorithm strength status
- Detect approaching certificate expiration
- Trigger renewal before deadlines
- Create new timestamps with appropriate algorithm

**Implementation Approach**:
```dart
/// Algorithm lifecycle management
class AlgorithmManager {
  static const Map<String, DateTime> algorithmSunset = {
    'SHA-1': DateTime(2020, 1, 1),      // Already sunset
    'SHA-256': DateTime(2030, 1, 1),    // Estimated
    'SHA-384': DateTime(2040, 1, 1),    // Estimated
  };

  /// Check if algorithm needs renewal
  bool needsRenewal(String algorithmOid) {
    final sunset = algorithmSunset[_oidToName(algorithmOid)];
    if (sunset == null) return false;

    // Renew 1 year before sunset
    return DateTime.now().isAfter(sunset.subtract(Duration(days: 365)));
  }
}

/// Evidence Record renewal service
class EvidenceRecordRenewalService {
  final TimeStampClient tsaClient;
  final AlgorithmManager algorithmManager;

  /// Renew timestamp if needed
  Future<EvidenceRecord?> renewIfNeeded(EvidenceRecord er) async {
    final lastAts = er.archiveTimeStampSequence.last.last;

    // Check TSA certificate expiration
    final tsaCert = extractTsaCertificate(lastAts);
    if (tsaCert.notAfter.isBefore(DateTime.now().add(Duration(days: 90)))) {
      return await _timestampRenewal(er);
    }

    // Check algorithm strength
    if (algorithmManager.needsRenewal(lastAts.digestAlgorithmOid)) {
      return await _hashTreeRenewal(er);
    }

    return null; // No renewal needed
  }

  /// Timestamp renewal (same algorithm, new TSA token)
  Future<EvidenceRecord> _timestampRenewal(EvidenceRecord er) async {
    final lastAts = er.archiveTimeStampSequence.last.last;
    final hash = sha256.process(lastAts.timeStampToken);
    final newTst = await tsaClient.getTimeStamp(hash);

    final newAts = ArchiveTimeStamp(
      timeStampToken: newTst.token,
    );

    // Add to same chain
    return er.addTimeStampToCurrentChain(newAts);
  }

  /// Hash tree renewal (new algorithm, new chain)
  Future<EvidenceRecord> _hashTreeRenewal(EvidenceRecord er) async {
    // Hash all existing ATSs + original data with new algorithm
    final sha384 = Digest('SHA-384');
    // ... build new Merkle tree

    // Start new chain
    return er.startNewChain(newAts);
  }
}
```

**Effort Estimate**: Medium - logic is straightforward, depends on other gaps

---

## Integration with Existing System

### Integration Points

```
┌─────────────────────────────────────────────────────────────────┐
│                    Clinical Diary App                            │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              append_only_datastore                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │ │
│  │  │ Event Store  │  │ Hash Chain   │  │ Sync Engine      │  │ │
│  │  │ (Sembast)    │  │ (SHA-256)    │  │ (REST API)       │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           Evidence Record Service (NEW)                     │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │ │
│  │  │ Merkle Tree  │  │ TSA Client   │  │ ERS Codec        │  │ │
│  │  │ Builder      │  │ (RFC 3161)   │  │ (RFC 4998)       │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘  │ │
│  │  ┌──────────────┐  ┌──────────────┐                        │ │
│  │  │ Renewal      │  │ Verification │                        │ │
│  │  │ Scheduler    │  │ Service      │                        │ │
│  │  └──────────────┘  └──────────────┘                        │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   ┌──────────────────┐
                   │ External TSA     │
                   │ (DigiCert, etc.) │
                   └──────────────────┘
```

### Batch Timestamping Strategy

For efficiency, batch multiple events into single TSA request:

```dart
/// Batch Evidence Record creation
class BatchEvidenceRecordService {
  final TimeStampClient tsaClient;
  final Duration batchWindow;

  final List<EventRecord> _pendingEvents = [];
  Timer? _batchTimer;

  /// Queue event for batch timestamping
  void queueEvent(EventRecord event) {
    _pendingEvents.add(event);

    _batchTimer ??= Timer(batchWindow, _processBatch);
  }

  Future<void> _processBatch() async {
    if (_pendingEvents.isEmpty) return;

    final events = List<EventRecord>.from(_pendingEvents);
    _pendingEvents.clear();
    _batchTimer = null;

    // Build Merkle tree from event hashes
    final leaves = events.map((e) => e.hash).toList();
    final tree = MerkleTree(leaves: leaves);

    // Get single timestamp for root hash
    final tst = await tsaClient.getTimeStamp(tree.rootHash);

    // Store Evidence Record with reduced hash trees
    for (var i = 0; i < events.length; i++) {
      final proof = tree.getProof(i);
      await _storeEvidenceRecord(events[i], tst, proof);
    }
  }
}
```

---

## Implementation Roadmap

### Phase 1: Core Components (MVP)

**Goal**: Basic Evidence Record creation with TSA integration

| Component | Priority | Effort | Dependencies |
| ----------- | ---------- | -------- | -------------- |
| Merkle Tree | P0 | Medium | Pointy Castle |
| TSA Client (HTTP) | P0 | High | asn1lib, http |
| ArchiveTimeStamp codec | P0 | High | asn1lib |
| Basic verification | P0 | Medium | Above |

**Deliverables**:
- Create Evidence Records for event batches
- Verify Evidence Records locally
- Store alongside event data

### Phase 2: Production Hardening

**Goal**: Robust, automated Evidence Record management

| Component | Priority | Effort | Dependencies |
| ----------- | ---------- | -------- | -------------- |
| CMS SignedData parser | P1 | High | asn1lib, x509 |
| TSA certificate validation | P1 | Medium | x509 |
| Renewal scheduler | P1 | Medium | Phase 1 |
| EvidenceRecord codec | P1 | Medium | Phase 1 |

**Deliverables**:
- Full timestamp verification including certificate chain
- Automated renewal before expiration
- Complete RFC 4998 compliance

### Phase 3: Advanced Features

**Goal**: Enterprise-ready Evidence Record system

| Component | Priority | Effort | Dependencies |
| ----------- | ---------- | -------- | -------------- |
| XMLERS support (RFC 6283) | P2 | High | xml, Phase 2 |
| XML canonicalization | P2 | Medium | xml |
| Algorithm renewal | P2 | Medium | Phase 2 |
| Multi-TSA support | P2 | Low | Phase 2 |

**Deliverables**:
- XML Evidence Records for XML-based data
- Cross-algorithm migration support
- TSA failover capability

---

## TSA Provider Options

### Public TSA Services

| Provider | URL | Algorithms | Notes |
| ---------- | ----- | ------------ | ------- |
| FreeTSA | http://freetsa.org/tsr | SHA-256 | Free, for testing |
| DigiCert | https://timestamp.digicert.com | SHA-256/384/512 | Production |
| Sectigo | http://timestamp.sectigo.com | SHA-256/384/512 | Production |
| GlobalSign | http://timestamp.globalsign.com | SHA-256 | Production |

### Selection Criteria

For FDA-regulated clinical trials:
- ✅ Production TSA with SLA
- ✅ Qualified under eIDAS or equivalent
- ✅ Long-term certificate validity (10+ years)
- ✅ SHA-384 or SHA-512 support
- ✅ Response includes full certificate chain

---

## Verification Procedures

### Evidence Record Verification Algorithm

Per RFC 4998 Section 5.2:

```dart
/// Verify Evidence Record
class EvidenceRecordVerifier {
  /// Verify complete Evidence Record for data object
  VerificationResult verify(
    Uint8List dataObject,
    EvidenceRecord evidenceRecord,
  ) {
    final errors = <String>[];

    // 1. Compute hash of data object
    final dataHash = _computeHash(
      dataObject,
      evidenceRecord.digestAlgorithms.first,
    );

    // 2. Verify each chain in sequence
    Uint8List? previousChainHash;

    for (final chain in evidenceRecord.archiveTimeStampSequence) {
      final chainResult = _verifyChain(
        chain,
        dataHash,
        previousChainHash,
      );

      if (!chainResult.isValid) {
        errors.addAll(chainResult.errors);
      }

      // Hash of last ATS becomes input to next chain
      previousChainHash = chain.last.computeHash();
    }

    return VerificationResult(
      isValid: errors.isEmpty,
      errors: errors,
      verificationTime: DateTime.now(),
    );
  }

  /// Verify single chain
  _ChainResult _verifyChain(
    ArchiveTimeStampChain chain,
    Uint8List dataHash,
    Uint8List? previousHash,
  ) {
    // Each ATS must be valid relative to following ATS time
    // All ATSs must use same hash algorithm
    // First ATS reduced hash tree must contain data hash
    // (or previousHash for renewal chains)
  }
}
```

---

## Security Considerations

### Cryptographic Algorithm Selection

| Algorithm | Status | Recommendation |
| ----------- | -------- | ---------------- |
| SHA-1 | Deprecated | Do not use |
| SHA-256 | Current | Acceptable for new ERs |
| SHA-384 | Current | Recommended |
| SHA-512 | Current | Recommended for long-term |
| SHA-3 | Current | Future-proof option |

### TSA Security

- Use HTTPS for TSA communication
- Validate TSA certificate chain
- Verify certificate not revoked (OCSP/CRL)
- Store TSA certificates with Evidence Records

### Key Protection

- TSA private keys are TSA's responsibility
- Client-side: protect any signing keys in secure storage
- Server-side: use Cloud HSM for high-assurance scenarios

---

## Compliance Mapping

### FDA 21 CFR Part 11 Requirements

| Requirement | Section | Evidence Record Support |
| ------------- | --------- | ------------------------ |
| Audit Trail | §11.10(e) | ERS provides independent timestamp proof |
| Tamper Detection | §11.10(c) | Merkle tree + TSA signature |
| Record Integrity | §11.10(e) | Hash chain with third-party attestation |
| Record Retention | §11.10(c) | Algorithm renewal supports long-term |

### ALCOA+ Mapping

| Principle | Evidence Record Contribution |
| ----------- | ---------------------------- |
| Attributable | Timestamp includes TSA identity |
| Legible | Standard format (RFC 4998) |
| Contemporaneous | TSA timestamp at time of creation |
| Original | Immutable hash in Evidence Record |
| Accurate | Cryptographic verification |
| Complete | Includes all required metadata |
| Consistent | Merkle tree ensures ordering |
| Enduring | Algorithm renewal for longevity |
| Available | Standard format enables retrieval |

---

## Testing Strategy

### Unit Tests

```dart
void main() {
  group('MerkleTree', () {
    test('builds correct root hash', () {
      final leaves = [
        sha256.process(utf8.encode('doc1')),
        sha256.process(utf8.encode('doc2')),
      ];
      final tree = MerkleTree(leaves: leaves);

      // Root should be hash of concatenated children
      final expected = sha256.process(Uint8List.fromList([
        ...leaves[0],
        ...leaves[1],
      ]));
      expect(tree.rootHash, equals(expected));
    });

    test('generates valid proof', () {
      final leaves = List.generate(4, (i) =>
        sha256.process(utf8.encode('doc$i'))
      );
      final tree = MerkleTree(leaves: leaves);

      for (var i = 0; i < leaves.length; i++) {
        final proof = tree.getProof(i);
        expect(tree.verify(leaves[i], i, proof), isTrue);
      }
    });
  });

  group('TimeStampClient', () {
    test('creates valid timestamp request', () async {
      final client = TimeStampClient(tsaUrl: 'http://freetsa.org/tsr');
      final hash = sha256.process(utf8.encode('test data'));

      final response = await client.getTimeStamp(hash);

      expect(response.status, equals(0)); // Granted
      expect(response.token, isNotEmpty);
    });
  });

  group('EvidenceRecord', () {
    test('serializes to valid DER', () {
      final er = EvidenceRecord(
        digestAlgorithms: {'2.16.840.1.101.3.4.2.1'},
        archiveTimeStampSequence: [/* ... */],
      );

      final der = er.toDer();
      final parsed = EvidenceRecord.fromDer(der);

      expect(parsed.version, equals(er.version));
      expect(parsed.digestAlgorithms, equals(er.digestAlgorithms));
    });
  });
}
```

### Integration Tests

- Test with real TSA (FreeTSA for development)
- Verify Evidence Records from test data
- Test renewal scenarios
- Cross-platform verification

---

## References

### Standards

- [RFC 4998 - Evidence Record Syntax (ERS)](https://datatracker.ietf.org/doc/html/rfc4998)
- [RFC 6283 - XML Evidence Record Syntax (XMLERS)](https://datatracker.ietf.org/doc/html/rfc6283)
- [RFC 3161 - Time-Stamp Protocol (TSP)](https://www.rfc-editor.org/rfc/rfc3161)
- [RFC 5652 - CMS (PKCS#7)](https://datatracker.ietf.org/doc/html/rfc5652)
- [RFC 3076 - Exclusive XML Canonicalization](https://datatracker.ietf.org/doc/html/rfc3076)

### Dart Packages

- [pointycastle](https://pub.dev/packages/pointycastle) - Cryptographic algorithms
- [asn1lib](https://pub.dev/packages/asn1lib) - ASN.1 encoding/decoding
- [x509](https://pub.dev/packages/x509) - X.509 certificate parsing

### Internal Documentation

- prd-event-sourcing-system.md - Event sourcing architecture
- prd-database.md - Audit trail requirements
- prd-clinical-trials.md - FDA compliance requirements
- dev-compliance-practices.md - ALCOA+ implementation

---

## Revision History

| Version | Date | Changes | Author |
| ------- | ---------- | ----------------------------------------- | ---------------- |
| 2.0 | 2025-11-29 | Added Bitcoin/OpenTimestamps (REQ-d00028), deprecated TSA (REQ-d00029) | Development Team |
| 1.0 | 2025-11-28 | Initial draft - gap analysis | Development Team |

---

**Document Classification**: Internal Use - Development Implementation
**Review Frequency**: Quarterly or when RFCs are updated
**Owner**: Technical Lead / Security Team
