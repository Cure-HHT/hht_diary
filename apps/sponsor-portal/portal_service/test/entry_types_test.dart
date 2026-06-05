import 'package:portal_service/portal_service.dart';
import 'package:test/test.dart';

void main() {
  test('portalEntryTypes registers the settings + otp-skip event types', () {
    final ids = portalEntryTypes().map((e) => e.id).toSet();
    expect(
      ids,
      containsAll(<String>{'portal_setting_changed', 'user_login_otp_skipped'}),
    );
  });
}
