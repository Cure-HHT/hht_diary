import 'package:append_only_datastore/src/entry_type_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Minimal fixture: two distinct `EntryTypeDefinition`s with unique ids.
EntryTypeDefinition _defn(String id, {String widgetId = 'epistaxis_form_v1'}) =>
    EntryTypeDefinition(
      id: id,
      version: '1.0.0',
      name: 'Defn $id',
      widgetId: widgetId,
      widgetConfig: const <String, Object?>{},
    );

void main() {
  group('EntryTypeRegistry', () {
    late EntryTypeRegistry registry;

    setUp(() {
      registry = EntryTypeRegistry();
    });

    // Verifies: registered definitions round-trip through byId by the
    // id they were registered under — the registry's primary lookup
    // surface.
    test('register and byId round-trip', () {
      final defn = _defn('demo_note');
      registry.register(defn);
      expect(registry.byId('demo_note'), same(defn));
    });

    // Verifies: byId returns null for unregistered ids so callers can
    // distinguish "unknown type" from "registered" with a null check.
    test('byId returns null for unknown id', () {
      expect(registry.byId('nope'), isNull);
    });

    // Verifies: duplicate id on register throws ArgumentError — silent
    // shadowing would let an app declare two competing definitions for
    // the same entry type and the later one would silently win. Loud
    // failure at registration catches the config bug at boot.
    test('register of duplicate id throws ArgumentError', () {
      final original = _defn('demo_note');
      registry.register(original);
      expect(() => registry.register(_defn('demo_note')), throwsArgumentError);
      // State is unchanged by the throw: the original is still the
      // only entry and byId still returns it.
      expect(registry.all(), hasLength(1));
      expect(registry.byId('demo_note'), same(original));
    });

    // Verifies: isRegistered returns true iff a definition is present
    // under the id. Convenience wrapper over byId != null for callers
    // (notably EntryService.record) that only need the yes/no.
    test('isRegistered matches byId presence', () {
      expect(registry.isRegistered('demo_note'), isFalse);
      registry.register(_defn('demo_note'));
      expect(registry.isRegistered('demo_note'), isTrue);
      expect(registry.isRegistered('other'), isFalse);
    });

    // Verifies: all() returns every registered definition in
    // registration order.
    test('all() returns registered definitions in insertion order', () {
      final first = _defn('first');
      final second = _defn('second');
      final third = _defn('third');
      registry
        ..register(first)
        ..register(second)
        ..register(third);
      // orderedEquals uses == and preserves order; combined with
      // EntryTypeDefinition having no custom operator==, this asserts
      // both the ordering and identity-level reference equality.
      expect(registry.all(), orderedEquals([first, second, third]));
    });

    // Verifies: the list returned by all() is unmodifiable so a caller
    // cannot mutate the registry's backing store by mutating the view.
    test('all() returns an unmodifiable list', () {
      registry.register(_defn('x'));
      final view = registry.all();
      expect(() => view.add(_defn('y')), throwsUnsupportedError);
      expect(view.clear, throwsUnsupportedError);
    });

    // Verifies: a fresh registry holds no definitions.
    test('empty registry reports zero registrations', () {
      expect(registry.all(), isEmpty);
      expect(registry.isRegistered('any'), isFalse);
      expect(registry.byId('any'), isNull);
    });
  });
}
