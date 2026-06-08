import 'dart:typed_data';

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/services/branding_asset_cache.dart';
import 'package:clinical_diary/services/sponsor_branding_service.dart';
import 'package:flutter/material.dart';

/// Builds a cache-backed [BrandingLogo] at a caller-chosen size, with a
/// caller-chosen `fallback`. Threaded into the logo-rendering screens (the
/// `LogoMenu`, the profile **Participation Status Badge**) so they stay agnostic
/// to the cache + JWT plumbing while each render site still renders the verified
/// bytes from the content-addressed cache.
typedef BrandingLogoBuilder =
    Widget Function({
      required double width,
      required double height,
      required Widget fallback,
    });

/// Renders the *Sponsor* logo from the content-addressed local cache.
///
/// The asset endpoint is JWT-gated, so the logo cannot be loaded with a plain
/// `Image.network` (no auth header -> 401). This widget resolves the bytes
/// cache-first: a cache hit renders immediately with no network; a miss kicks
/// off ONE JWT-gated `fetchAndCache` per content hash and renders the verified
/// bytes when they arrive. The resolution future is memoized per sha256 so a
/// rebuild does not re-fetch (fetch-once). While loading, or if the logo is
/// unavailable (no role/hash, no JWT, fetch/verify failure), the [fallback]
/// widget is shown — never a crash.
///
// Implements: DIARY-DEV-sponsor-branding-assets/D
// Implements: DIARY-GUI-participation-status-badge/H
class BrandingLogo extends StatefulWidget {
  const BrandingLogo({
    required this.branding,
    required this.cache,
    required this.jwtProvider,
    required this.fallback,
    this.width = 120,
    this.height = 40,
    super.key,
  });

  /// Sponsor branding derived from the diary's event-sourced settings.
  final SponsorBrandingConfig branding;

  /// Content-addressed local cache the logo bytes are served from / fetched into.
  final BrandingAssetCache cache;

  /// Supplies the current patient session JWT for the gated asset fetch.
  /// Returns null when there is no session (logo then stays the [fallback]).
  final Future<String?> Function() jwtProvider;

  /// Shown while the bytes resolve, or when the logo is unavailable.
  final Widget fallback;

  final double width;
  final double height;

  @override
  State<BrandingLogo> createState() => _BrandingLogoState();
}

class _BrandingLogoState extends State<BrandingLogo> {
  // Memoized resolution, keyed by the content hash it resolved. Gating the
  // fetch on the hash makes the network fetch happen at most once per sha256
  // across rebuilds (fetch-once); a new hash starts a fresh resolution.
  String? _resolvedSha256;
  Future<Uint8List?>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    _ensureResolution();
  }

  @override
  void didUpdateWidget(covariant BrandingLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureResolution();
  }

  void _ensureResolution() {
    final sha256 = widget.branding.logoSha256;
    final role = widget.branding.logoRole;
    if (sha256 == null || role == null) {
      // No logo configured — clear any prior resolution; render the fallback.
      _resolvedSha256 = null;
      _bytesFuture = null;
      return;
    }
    if (_resolvedSha256 == sha256 && _bytesFuture != null) {
      // Already resolving / resolved this exact hash — do not re-fetch.
      return;
    }
    _resolvedSha256 = sha256;
    _bytesFuture = _resolve(role: role, sha256: sha256);
  }

  // Cache-first, fetch-once. A cache hit returns bytes with no network; a miss
  // performs one JWT-gated fetch+verify (null on no-JWT / failure / mismatch).
  Future<Uint8List?> _resolve({
    required String role,
    required String sha256,
  }) async {
    final cached = await widget.cache.get(sha256);
    if (cached != null) return cached;
    final jwt = await widget.jwtProvider();
    if (jwt == null || jwt.isEmpty) return null;
    return widget.cache.fetchAndCache(
      role: role,
      sha256: sha256,
      jwt: jwt,
      apiBase: AppConfig.apiBase,
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = _bytesFuture;
    if (future == null) return widget.fallback;
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          // Loading, or unavailable — show the app default; never crash.
          return widget.fallback;
        }
        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => widget.fallback,
        );
      },
    );
  }
}
