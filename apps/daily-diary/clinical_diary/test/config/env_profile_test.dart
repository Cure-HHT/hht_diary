// test/config/env_profile_test.dart
import 'package:clinical_diary/config/env_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._contents);
  final String? _contents;

  @override
  Future<ByteData> load(String key) async {
    if (_contents == null) {
      throw FlutterError('asset not found: $key');
    }
    final bytes = Uint8List.fromList(_contents.codeUnits);
    return ByteData.view(bytes.buffer);
  }
}

void _loadTests() {
  group('EnvProfile.load', () {
    test('reads the env name from the asset', () async {
      final p = await EnvProfile.load(bundle: _FakeBundle('{"env":"qa"}'));
      expect(p.env, AppEnv.qa);
    });

    test('defaults to dev when the asset is missing', () async {
      final p = await EnvProfile.load(bundle: _FakeBundle(null));
      expect(p.env, AppEnv.dev);
    });

    test('defaults to dev when the env name is unknown', () async {
      final p = await EnvProfile.load(bundle: _FakeBundle('{"env":"staging"}'));
      expect(p.env, AppEnv.dev);
    });

    test('defaults to dev when the asset is malformed', () async {
      final p = await EnvProfile.load(bundle: _FakeBundle('not json'));
      expect(p.env, AppEnv.dev);
    });
  });
}

void main() {
  group('EnvProfile registry', () {
    test('dev profile carries dev API base and enables dev affordances', () {
      final p = EnvProfile.forEnv(AppEnv.dev);
      expect(p.name, 'dev');
      expect(
        p.apiBase,
        'https://diary-service-1012274191696.europe-west9.run.app',
      );
      expect(p.showBanner, isTrue);
      expect(p.showDevTools, isTrue);
      expect(p.showResetData, isTrue);
      expect(p.dangerousAffordancesEnabled, isTrue);
    });

    test('prod profile disables every developer/dangerous affordance', () {
      final p = EnvProfile.forEnv(AppEnv.prod);
      expect(p.name, 'prod');
      expect(p.showBanner, isFalse);
      expect(p.showDevTools, isFalse);
      expect(p.showResetData, isFalse);
      expect(p.dangerousAffordancesEnabled, isFalse);
    });

    test('uat hides banner + dev tools but keeps reset-data', () {
      final p = EnvProfile.forEnv(AppEnv.uat);
      expect(p.showBanner, isFalse);
      expect(p.showDevTools, isFalse);
      expect(p.showResetData, isTrue);
    });

    test('local targets the localhost diary-server', () {
      expect(EnvProfile.forEnv(AppEnv.local).apiBase, 'http://localhost:8081');
    });

    test('qa targets its own diary-service URL', () {
      expect(
        EnvProfile.forEnv(AppEnv.qa).apiBase,
        'https://diary-service-421945483876.europe-west9.run.app',
      );
    });
  });
  _loadTests();
}
