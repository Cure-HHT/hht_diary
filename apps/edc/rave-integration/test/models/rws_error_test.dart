import 'package:rave_integration/src/models/rws_error.dart';
import 'package:test/test.dart';

void main() {
  group('parseRwsError', () {
    test('extracts code and message from a typical RWS error response', () {
      const body = '''
<Response ReferenceNumber="abc123"
          InboundODMFileOID="file-id"
          IsTransactionSuccessful="0"
          ReasonCode="RWS00008"
          ErrorClientResponseMessage="Incorrect login and password combination">
</Response>
''';
      final err = parseRwsError(body);
      expect(err, isNotNull);
      expect(err!.reasonCode, equals('RWS00008'));
      expect(err.message, equals('Incorrect login and password combination'));
    });

    test('returns null for empty body', () {
      expect(parseRwsError(''), isNull);
    });

    test('returns null for plain-text body (no XML markers)', () {
      expect(parseRwsError('Unauthorized'), isNull);
    });

    test('returns code-only when message attribute is absent', () {
      const body = '<Response ReasonCode="RWS00018"/>';
      final err = parseRwsError(body);
      expect(err, isNotNull);
      expect(err!.reasonCode, equals('RWS00018'));
      expect(err.message, isNull);
    });

    test('returns message-only when code attribute is absent (edge case)', () {
      const body =
          '<Response ErrorClientResponseMessage="Something went wrong"/>';
      final err = parseRwsError(body);
      expect(err, isNotNull);
      expect(err!.reasonCode, isNull);
      expect(err.message, equals('Something went wrong'));
    });

    test('parses single-line inline response (no multi-line formatting)', () {
      // RWS responses are usually multi-line XML, but the parser must also
      // accept compact single-line bodies; verify the regex doesn't depend
      // on whitespace formatting.
      const body =
          '<Response ReasonCode="RWS00008" ErrorClientResponseMessage="msg with no quote">';
      final err = parseRwsError(body);
      expect(err!.reasonCode, equals('RWS00008'));
      expect(err.message, equals('msg with no quote'));
    });
  });
}
