// Verifies: DIARY-DEV-deployment-config-defaults/B+C
import 'package:clinical_diary/config/config_defaults.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty asset yields code defaults', () async {
    final cfg = await loadDeploymentUiDefaults(bundle: _FakeBundle('{}'));
    expect(cfg, SponsorUiConfig.codeDefault);
  });

  test('unparseable asset falls back to code defaults', () async {
    final cfg = await loadDeploymentUiDefaults(bundle: _FakeBundle('not json'));
    expect(cfg, SponsorUiConfig.codeDefault);
  });

  test('asset narrows languages', () async {
    final cfg = await loadDeploymentUiDefaults(
      bundle: _FakeBundle(
        '{"ui.availableLanguages":["en","es"],"ui.defaultLanguage":"en"}',
      ),
    );
    expect(cfg.availableLanguages, ['en', 'es']);
    expect(cfg.defaultLanguage, 'en');
    expect(cfg.availableFonts, kPlatformFontFamilies); // untouched key
  });
}

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._json);
  final String _json;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(_json.codeUnits);
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => _json;
}
