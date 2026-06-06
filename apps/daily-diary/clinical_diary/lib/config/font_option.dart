// Font options the diary can render. The set a participant may choose from is
// constrained by the sponsor/deployment `ui.availableFonts` allow-set; the
// participant's own pick is the `pref.selectedFont` user setting.
library;

/// Available font options. The [fontFamily] name must match the family names in
/// pubspec.yaml and the values stored in `pref.selectedFont` / `ui.availableFonts`.
enum FontOption {
  /// System default font (Roboto on Android, SF on iOS)
  roboto('Roboto'),

  /// OpenDyslexic font for dyslexia accessibility
  openDyslexic('OpenDyslexic'),

  /// Atkinson Hyperlegible for visual impairment accessibility
  atkinsonHyperlegible('AtkinsonHyperlegible');

  const FontOption(this.fontFamily);

  /// The font family name as used in the Flutter theme.
  final String fontFamily;

  /// Human-readable display name for the UI.
  String get displayName {
    switch (this) {
      case FontOption.roboto:
        return 'Roboto (Default)';
      case FontOption.openDyslexic:
        return 'OpenDyslexic';
      case FontOption.atkinsonHyperlegible:
        return 'Atkinson Hyperlegible';
    }
  }

  /// Parse from a stored / wire font-family string. Returns null for an unknown
  /// value.
  static FontOption? fromString(String value) {
    for (final o in FontOption.values) {
      if (o.fontFamily == value) return o;
    }
    return null;
  }
}
