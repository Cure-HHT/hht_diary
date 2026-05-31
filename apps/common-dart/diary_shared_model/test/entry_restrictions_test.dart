// Verifies: DIARY-PRD-entry-time-restrictions/A+E+J+L+M
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

void main() {
  final day = DateTime.utc(2025, 10, 1); // event-date local midnight
  EntryGate gate(DateTime now, EntryRestrictionConfig c) =>
      entryGateForDate(eventLocalMidnight: day, now: now, config: c);

  test('L: no thresholds configured -> always allowed', () {
    expect(
      gate(day.add(const Duration(days: 365)), const EntryRestrictionConfig()),
      EntryGate.allowed,
    );
  });

  const cfg = EntryRestrictionConfig(
    justificationThreshold: Duration(days: 2),
    lockThreshold: Duration(days: 7),
  );

  test('within justification window -> allowed', () {
    expect(gate(day.add(const Duration(days: 1)), cfg), EntryGate.allowed);
  });

  test('A: past justification, before lock -> requiresJustification', () {
    expect(
      gate(day.add(const Duration(days: 3)), cfg),
      EntryGate.requiresJustification,
    );
  });

  test(
    'E/F/G + J: past lock -> locked (lock checked before justification)',
    () {
      expect(gate(day.add(const Duration(days: 8)), cfg), EntryGate.locked);
    },
  );

  test('M: lock does not apply to event dates before Trial Start', () {
    final preTrial = EntryRestrictionConfig(
      justificationThreshold: const Duration(days: 2),
      lockThreshold: const Duration(days: 7),
      trialStart: day.add(
        const Duration(days: 5),
      ), // trial starts after this day
    );
    // 8 days elapsed would normally lock, but the date precedes trial start,
    // so the lock is inapplicable -> falls through to requiresJustification.
    expect(
      gate(day.add(const Duration(days: 8)), preTrial),
      EntryGate.requiresJustification,
    );
  });
}
