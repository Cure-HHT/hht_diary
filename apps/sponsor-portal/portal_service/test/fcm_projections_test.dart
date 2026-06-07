import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/src/fcm_projections.dart';
import 'package:test/test.dart';

void main() {
  test(
    'fcmActiveTokensSpec keys by aggregateId and folds register/deactivate',
    () {
      expect(fcmActiveTokensSpec.viewName, 'participant_fcm_tokens');
      expect(fcmActiveTokensSpec.rowKey, isA<AggregateIdKey>());
      expect(
        fcmActiveTokensSpec.insertEventTypes,
        contains('fcm_token_registered'),
      );
      expect(
        fcmActiveTokensSpec.removeEventTypes,
        contains('fcm_token_deactivated'),
      );
      expect(fcmActiveTokensSpec.interest.aggregateTypes, contains('FcmToken'));
    },
  );
}
