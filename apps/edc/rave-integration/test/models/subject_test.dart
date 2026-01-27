import 'package:rave_integration/rave_integration.dart';
import 'package:test/test.dart';

void main() {
  group('RaveSubject', () {
    test('constructs with required fields', () {
      const subject = RaveSubject(subjectKey: '840-001-001', siteOid: '12345');

      expect(subject.subjectKey, equals('840-001-001'));
      expect(subject.siteOid, equals('12345'));
      expect(subject.siteNumber, isNull);
    });

    test('constructs with all fields', () {
      const subject = RaveSubject(
        subjectKey: '840-001-001',
        siteOid: '12345',
        siteNumber: '001',
      );

      expect(subject.subjectKey, equals('840-001-001'));
      expect(subject.siteOid, equals('12345'));
      expect(subject.siteNumber, equals('001'));
    });

    test('equality based on all fields', () {
      const subject1 = RaveSubject(
        subjectKey: '840-001-001',
        siteOid: '12345',
        siteNumber: '001',
      );
      const subject2 = RaveSubject(
        subjectKey: '840-001-001',
        siteOid: '12345',
        siteNumber: '001',
      );
      const subject3 = RaveSubject(
        subjectKey: '840-001-002',
        siteOid: '12345',
        siteNumber: '001',
      );

      expect(subject1, equals(subject2));
      expect(subject1, isNot(equals(subject3)));
    });

    test('equality differs when siteOid differs', () {
      const subject1 = RaveSubject(subjectKey: '840-001-001', siteOid: '12345');
      const subject2 = RaveSubject(subjectKey: '840-001-001', siteOid: '99999');

      expect(subject1, isNot(equals(subject2)));
    });

    test('equality differs when siteNumber differs', () {
      const subject1 = RaveSubject(
        subjectKey: '840-001-001',
        siteOid: '12345',
        siteNumber: '001',
      );
      const subject2 = RaveSubject(
        subjectKey: '840-001-001',
        siteOid: '12345',
        siteNumber: '002',
      );

      expect(subject1, isNot(equals(subject2)));
    });

    test('hashCode consistent with equality', () {
      const subject1 = RaveSubject(
        subjectKey: '840-001-001',
        siteOid: '12345',
        siteNumber: '001',
      );
      const subject2 = RaveSubject(
        subjectKey: '840-001-001',
        siteOid: '12345',
        siteNumber: '001',
      );

      expect(subject1.hashCode, equals(subject2.hashCode));
    });

    test('toString includes key fields', () {
      const subject = RaveSubject(
        subjectKey: '840-001-001',
        siteOid: '12345',
        siteNumber: '001',
      );

      final str = subject.toString();
      expect(str, contains('840-001-001'));
      expect(str, contains('12345'));
      expect(str, contains('001'));
    });

    test('toString with null siteNumber', () {
      const subject = RaveSubject(subjectKey: '840-001-001', siteOid: '12345');

      final str = subject.toString();
      expect(str, contains('840-001-001'));
      expect(str, contains('12345'));
      expect(str, contains('null'));
    });
  });
}
