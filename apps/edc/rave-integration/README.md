# RAVE Integration

Dart client library for Medidata RAVE Web Services (RWS) API integration, specifically for syncing sponsor site data from the Electronic Data Capture (EDC) system.

**Ticket**: [CUR-672](https://linear.app/cure-hht-diary/issue/CUR-672)

## Reference Documentation

All RAVE API documentation and specs are maintained in the **hht_diary_callisto** repository:

| Resource                  | Path                                                                            |
|---------------------------|---------------------------------------------------------------------------------|
| RAVE API Guide            | `../hht_diary_callisto/tools/EDC-integration/docs/RAVE_API_GUIDE.md`            |
| RAVE Error Codes          | `../hht_diary_callisto/tools/EDC-integration/docs/RAVE_ERROR_CODES.md`          |
| Programmer Notes          | `../hht_diary_callisto/tools/EDC-integration/docs/RAVE_API_PROGRAMMER_NOTES.md` |
| Full API Reference (HTML) | `../hht_diary_callisto/docs/rave_api_reference/`                                |
| Python Test Script        | `../hht_diary_callisto/tools/EDC-integration/test_rave_api.py`                  |
| EDC Sync PRD              | `../hht_diary_callisto` branch `feature/CUR-605-edc-integration`                |

### Unmerged Specs (CUR-605)

The following branches in hht_diary_callisto contain unmerged specs needed for this work:
- `feature/CUR-605-edc-integration` - EDC integration tools and `spec/prd-edc-sync.md`
- `feature/CUR-605-edc-read-questionnaire-data` - Additional questionnaire specs

## Configuration

Environment variables (managed via Doppler):

| Variable            | Description                        |
|---------------------|------------------------------------|
| `RAVE_UAT_URL`      | Base URL (UAT: `$RAVE_UAT_URL`)    |
| `RAVE_UAT_USERNAME` | API username for Basic Auth        |
| `RAVE_UAT_PWD`      | API password (PIN is NOT appended) |

**Study OID**: `TER-1754-C01(APPDEV)` for dev/qa/uat environments.

## Features

### Sanity Checks
- `/RaveWebServices/version` - Connectivity check (no auth required)
- `/RaveWebServices/studies` - Authentication verification

### Site Sync
- `/RaveWebServices/datasets/Sites.odm` - Retrieve all sites for a study

## Usage

```dart
import 'package:rave_integration/rave_integration.dart';

final client = RaveClient(
  baseUrl: '$RAVE_UAT_URL',
  username: 'your-username',
  password: 'your-password',
);

// Sanity check - verify connectivity
final version = await client.getVersion();

// Sanity check - verify authentication
final studies = await client.getStudies();

// Get sites for a study
final sites = await client.getSites(studyOid: 'TER-1754-C01(APPDEV)');
for (final site in sites) {
  print('${site.oid}: ${site.name} (active: ${site.isActive})');
}
```

## API Response Format

Sites are returned in ODM (Operational Data Model) XML format:

```xml
<ODM>
  <AdminData>
    <Location OID="DEV_999-001" Name="Site 001" LocationType="Site" mdsol:Active="Yes">
      <MetaDataVersionRef StudyOID="TER-1754-C01(APPDEV)"
                          MetaDataVersionOID="31"
                          mdsol:StudySiteNumber="001"/>
    </Location>
  </AdminData>
</ODM>
```

## Testing

```bash
# Unit tests (no credentials needed)
dart test

# Integration tests (requires RAVE credentials via Doppler)
doppler run -- dart test integration_test/
```

## Related Requirements

- REQ-CAL-p00010: Schema-Driven Data Validation
- REQ-CAL-p00011: EDC Metadata as Validation Source
- REQ-CAL-p00012: Sponsor-Configurable Transformation Rules
