import 'package:rave_integration/src/models/exceptions.dart';
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

  group('RaveAuthenticationException', () {
    test('defaults reasonCode and serverMessage to null', () {
      const e = RaveAuthenticationException();
      expect(e.reasonCode, isNull);
      expect(e.serverMessage, isNull);
      expect(e.statusCode, equals(401));
      expect(e.message, equals('Authentication failed'));
    });

    test('carries reasonCode and serverMessage when provided', () {
      const e = RaveAuthenticationException(
        reasonCode: 'RWS00008',
        serverMessage: 'Incorrect login and password combination',
      );
      expect(e.reasonCode, equals('RWS00008'));
      expect(
        e.serverMessage,
        equals('Incorrect login and password combination'),
      );
      expect(e.statusCode, equals(401));
    });

    test('toString includes reasonCode and serverMessage when present', () {
      const eFull = RaveAuthenticationException(
        reasonCode: 'RWS00008',
        serverMessage: 'Incorrect login and password combination',
      );
      expect(
        eFull.toString(),
        equals(
          'RaveAuthenticationException: Authentication failed '
          '(reasonCode: RWS00008, serverMessage: Incorrect login and password combination)',
        ),
      );

      const eEmpty = RaveAuthenticationException();
      expect(
        eEmpty.toString(),
        equals('RaveAuthenticationException: Authentication failed'),
      );
    });

    group('detailSuffix', () {
      test('returns empty string when both fields are null', () {
        const e = RaveAuthenticationException();
        expect(e.detailSuffix, equals(''));
      });

      test('returns " [code: message]" when both are present', () {
        const e = RaveAuthenticationException(
          reasonCode: 'RWS00008',
          serverMessage: 'Incorrect login and password combination',
        );
        expect(
          e.detailSuffix,
          equals(' [RWS00008: Incorrect login and password combination]'),
        );
      });

      test('returns " [code]" when only reasonCode is present', () {
        const e = RaveAuthenticationException(reasonCode: 'RWS00008');
        expect(e.detailSuffix, equals(' [RWS00008]'));
      });

      test('returns " [message]" when only serverMessage is present', () {
        const e = RaveAuthenticationException(
          serverMessage: 'Account locked due to repeated failures',
        );
        expect(
          e.detailSuffix,
          equals(' [Account locked due to repeated failures]'),
        );
      });
    });
  });
}
