// Known-bugs gallery for the CUR-1426 design-system review.
//
// Each component here reproduces a *real, verified* defect found while reviewing
// PR #670, so a designer/engineer can see the failure live (and confirm a fix
// removes it). These are demonstrations, NOT endorsed usage — every stage is
// annotated with what to look for.
//
// Several bugs only surface in dark mode; those render Light and Dark side by
// side so the regression is obvious. A global "Dark" theme is also wired into
// the MaterialThemeAddon in main.dart so the standard component galleries can be
// flipped to dark too.

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

/// A deliberately non-Carina sponsor brand (red) used to show that a brand
/// override reaches the ColorScheme but NOT the filled primary button.
const _sponsorRed = BrandPalette(
  primary: Color(0xFFB3261E),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFF9DEDC),
  onPrimaryContainer: Color(0xFF410E0B),
  secondary: Color(0xFF8C1D18),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFF9DEDC),
  onSecondaryContainer: Color(0xFF410E0B),
);

WidgetbookFolder knownBugsFolder() {
  return WidgetbookFolder(
    name: 'Known Bugs (CUR-1426 review)',
    children: [
      _component(
        'BUG-1 · Brand override skips filled primary buttons',
        'Brand-override',
        const _BrandOverrideDemo(),
      ),
      _component(
        'BUG-2 · Dark: disabled primary button looks enabled',
        'Light vs Dark',
        const _DisabledButtonDemo(),
      ),
      _component(
        'BUG-3 · Dark: status / semantic colors unreadable',
        'Light vs Dark',
        const _SemanticColorsDemo(),
      ),
      // BUG-4 (dark borders) withdrawn — subtle borders are intended design.
      // BUG-5 (loading scrim) demoted to a Notes entry — code-hygiene only,
      // no visible defect. BUG-6 (stale hover) demoted — not a live defect;
      // see "Notes" for the disposition of all three.
      _component(
        'BUG-8 · AppBanner message text loses contrast',
        'Saturated container',
        const _BannerContrastDemo(),
      ),
      _component(
        'BUG-9 · AppButton medium is 47dp, not the documented 48dp',
        'Pixel guide',
        const _ButtonHeightDemo(),
      ),
      _component(
        'BUG-10 · AppButton accessibility assert over-fires',
        'Caught assert',
        const _AssertBreadthDemo(),
      ),
      _component(
        'BUG-11 · AppTextField ignores a swapped controller',
        'Interactive',
        const _ControllerSwapDemo(),
      ),
      _component(
        'Notes · Non-visual issues (Inter fallback, dropdown overlay)',
        'Notes',
        const _NonVisualNotes(),
      ),
    ],
  );
}

WidgetbookComponent _component(String name, String useCase, Widget child) {
  return WidgetbookComponent(
    name: name,
    useCases: [WidgetbookUseCase(name: useCase, builder: (_) => child)],
  );
}

// ---------------------------------------------------------------------------
// Shared scaffolding
// ---------------------------------------------------------------------------

/// A self-contained themed stage: paints the resolved surface and provides a
/// Material ancestor so the embedded components render exactly as they would in
/// a real app under [brightness] / [brand] — independent of the book's global
/// theme toggle.
class _Stage extends StatelessWidget {
  final Brightness brightness;
  final BrandPalette? brand;
  final Widget child;
  const _Stage({
    required this.child,
    this.brightness = Brightness.light,
    this.brand,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildAppTheme(
        font: AppFontFamily.inter,
        brightness: brightness,
        brandOverride: brand,
      ),
      child: Builder(
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: (theme.textTheme.bodyMedium ?? const TextStyle())
                    .copyWith(color: theme.colorScheme.onSurface),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A labelled fixed-width column holding one stage; used inside [_SideBySide].
class _LabelledStage extends StatelessWidget {
  final String label;
  final Widget stage;
  const _LabelledStage({required this.label, required this.stage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          stage,
        ],
      ),
    );
  }
}

class _SideBySide extends StatelessWidget {
  final List<Widget> children;
  const _SideBySide({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 24, runSpacing: 24, children: children);
  }
}

/// Renders the same [content] in a Light and a Dark stage, side by side.
class _LightDark extends StatelessWidget {
  final Widget content;
  const _LightDark({required this.content});

  @override
  Widget build(BuildContext context) {
    return _SideBySide(
      children: [
        _LabelledStage(
          label: 'Light (ships today)',
          stage: _Stage(brightness: Brightness.light, child: content),
        ),
        _LabelledStage(
          label: 'Dark (buildAppTheme(brightness: dark))',
          stage: _Stage(brightness: Brightness.dark, child: content),
        ),
      ],
    );
  }
}

/// Standard bug page: header + "what to look for" callout + the demo body.
class _BugPage extends StatelessWidget {
  final String title;
  final String severity;
  final String lookFor;
  final List<Widget> children;
  const _BugPage({
    required this.title,
    required this.severity,
    required this.lookFor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          severity,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.visibility_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('What to look for: $lookFor')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final Color color;
  const _Swatch({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x33000000)),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BUG-1 — Brand override skips filled primary buttons
// ---------------------------------------------------------------------------

class _BrandOverrideDemo extends StatelessWidget {
  const _BrandOverrideDemo();

  @override
  Widget build(BuildContext context) {
    return _BugPage(
      title: 'BUG-1 · Sponsor brand override never reaches filled buttons',
      severity: 'Light mode · ships today · high confidence',
      lookFor:
          'In the "Sponsor brand (red)" stage the colorScheme.primary swatch '
          'and the tertiary/secondary buttons turn red, but the FILLED primary '
          'button stays Carina blue. buildAppTheme threads brandOverride into '
          'the ColorScheme but assigns AppButtonColors.light unconditionally, '
          'and AppButton.primary reads its hexes from that const.',
      children: const [
        _SideBySide(
          children: [
            _LabelledStage(
              label: 'Default brand',
              stage: _Stage(child: _BrandContent()),
            ),
            _LabelledStage(
              label: 'Sponsor brand (red)',
              stage: _Stage(brand: _sponsorRed, child: _BrandContent()),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandContent extends StatelessWidget {
  const _BrandContent();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Swatch(label: 'colorScheme.primary', color: scheme.primary),
        const SizedBox(height: 8),
        AppButton(label: 'Primary (filled)', onPressed: _noop),
        const SizedBox(height: 12),
        AppButton(
          variant: AppButtonVariant.secondary,
          label: 'Secondary (outline)',
          onPressed: _noop,
        ),
        const SizedBox(height: 12),
        AppButton(
          variant: AppButtonVariant.tertiary,
          label: 'Tertiary (text)',
          onPressed: _noop,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BUG-2 — Dark: disabled primary button looks enabled
// ---------------------------------------------------------------------------

class _DisabledButtonDemo extends StatelessWidget {
  const _DisabledButtonDemo();

  @override
  Widget build(BuildContext context) {
    return const _BugPage(
      title: 'BUG-2 · Disabled primary button renders near-white in dark mode',
      severity: 'Dark mode · critical · high confidence',
      lookFor:
          'In the Dark stage the DISABLED button is a near-white block on a '
          'near-black surface — it reads as enabled/active. AppButtonColors.dark '
          '= light, so backgroundDisabled (#E8F3F7) is reused unchanged.',
      children: [_LightDark(content: _DisabledButtonContent())],
    );
  }
}

class _DisabledButtonContent extends StatelessWidget {
  const _DisabledButtonContent();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(label: 'Enabled', onPressed: _noop),
        // onPressed null + not loading => disabled.
        const AppButton(label: 'Disabled'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BUG-3 — Dark: status / semantic colors unreadable
// ---------------------------------------------------------------------------

class _SemanticColorsDemo extends StatelessWidget {
  const _SemanticColorsDemo();

  @override
  Widget build(BuildContext context) {
    return const _BugPage(
      title: 'BUG-3 · Status & severity colors are unreadable in dark mode',
      severity: 'Dark mode · critical · high confidence',
      lookFor:
          'In the Dark stage "At risk" is dark-red on near-black, and the '
          'warning/success banner containers go near-black with low-contrast '
          'text. AppSemanticColors.dark reuses light foreground hues meant for '
          'a light background — a safety-adjacent problem in a clinical UI.',
      children: [_LightDark(content: _SemanticContent())],
    );
  }
}

class _SemanticContent extends StatelessWidget {
  const _SemanticContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusBadge(kind: StatusBadgeKind.active),
            StatusBadge(kind: StatusBadgeKind.pending),
            StatusBadge(kind: StatusBadgeKind.atRisk),
            StatusBadge(kind: StatusBadgeKind.inactive),
          ],
        ),
        SizedBox(height: 16),
        AppBanner(
          severity: AppBannerSeverity.success,
          title: 'Success',
          message: 'Operation completed successfully.',
        ),
        SizedBox(height: 8),
        AppBanner(
          severity: AppBannerSeverity.warning,
          title: 'Warning',
          message: 'This action needs your attention.',
        ),
        SizedBox(height: 8),
        AppBanner(
          severity: AppBannerSeverity.info,
          title: 'Info',
          message: 'Heads up — infoContainer stays light-blue in dark mode.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BUG-8 — AppBanner message text loses contrast on a saturated container
// ---------------------------------------------------------------------------

class _BannerContrastDemo extends StatelessWidget {
  const _BannerContrastDemo();

  @override
  Widget build(BuildContext context) {
    return _BugPage(
      title:
          'BUG-8 · Banner message text inherits onSurface, not the foreground',
      severity: 'Theming · medium confidence',
      lookFor:
          'Both banners use the same severity. The right one runs under a '
          'sponsor AppSemanticColors whose warningContainer is a dark amber. '
          'The TITLE stays legible (explicit foreground color) but the MESSAGE '
          'body goes low-contrast — it has no color override and falls back to '
          'onSurface (dark grey).',
      children: [
        _SideBySide(
          children: [
            const _LabelledStage(
              label: 'Default warning container',
              stage: _Stage(child: _BannerSample()),
            ),
            _LabelledStage(
              label: 'Saturated warning container',
              stage: Builder(
                builder: (context) {
                  // Override only warningContainer to a dark amber, leaving the
                  // warning foreground (and the button colors) untouched. Pass
                  // a concrete typed literal — mirroring buildAppTheme — to
                  // avoid the ThemeExtension F-bound inference issue the web
                  // front-end hits when re-spreading base.extensions.
                  final base = buildAppTheme(font: AppFontFamily.inter);
                  final stressed = base.copyWith(
                    extensions: <ThemeExtension<dynamic>>[
                      AppButtonColors.light,
                      AppSemanticColors.light.copyWith(
                        warningContainer: const Color(0xFF8A5A00),
                      ),
                    ],
                  );
                  return Theme(
                    data: stressed,
                    child: Builder(
                      builder: (ctx) => Material(
                        color: Theme.of(ctx).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: _BannerSample(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BannerSample extends StatelessWidget {
  const _BannerSample();

  @override
  Widget build(BuildContext context) {
    return const AppBanner(
      severity: AppBannerSeverity.warning,
      title: 'Title stays legible',
      message: 'This message body inherits onSurface and can lose contrast.',
    );
  }
}

// ---------------------------------------------------------------------------
// BUG-9 — AppButton medium is 47dp, not 48dp
// ---------------------------------------------------------------------------

class _ButtonHeightDemo extends StatelessWidget {
  const _ButtonHeightDemo();

  @override
  Widget build(BuildContext context) {
    return _BugPage(
      title: 'BUG-9 · Medium button min-height is 47dp; doc promises ≥48dp',
      severity: 'Low confidence · only bites under shrinkWrap tap targets',
      lookFor:
          'The medium button aligns with the 47dp guide, one pixel short of the '
          'red 48dp guide the class doc guarantees. Safe under the default '
          'padded tap target, but a shrinkWrap tap target would ship a 47dp '
          'visual button.',
      children: [
        _Stage(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppButton(
                size: AppButtonSize.medium,
                label: 'Medium',
                onPressed: _noop,
              ),
              const SizedBox(width: 32),
              const _GuideBar(height: 47, label: '47dp (actual)'),
              const SizedBox(width: 16),
              const _GuideBar(height: 48, label: '48dp (documented)'),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideBar extends StatelessWidget {
  final double height;
  final String label;
  const _GuideBar({required this.height, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 90,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.error),
          ),
          alignment: Alignment.center,
          child: Text('$height', style: theme.textTheme.labelSmall),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BUG-10 — AppButton accessibility assert over-fires
// ---------------------------------------------------------------------------

class _AssertBreadthDemo extends StatelessWidget {
  const _AssertBreadthDemo();

  @override
  Widget build(BuildContext context) {
    return _BugPage(
      title:
          'BUG-10 · Icon-only semanticLabel assert fires for non-icon-only buttons',
      severity: 'Debug-only assert · medium confidence',
      lookFor:
          'The first tile constructs AppButton(trailingIcon: …) with no label. '
          'It is NOT icon-only (no leadingIcon → no Semantics wrapper), yet the '
          'assert still throws "icon-only mode requires a semanticLabel". The '
          'guard is broader than the code path it protects. The second tile is '
          'a genuine icon-only button with a semanticLabel and builds fine.',
      children: [
        _Stage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1) trailingIcon only, no label, no semanticLabel:'),
              const SizedBox(height: 8),
              Builder(
                builder: (ctx) {
                  try {
                    final button = AppButton(
                      trailingIcon: Icons.expand_more,
                      onPressed: _noop,
                    );
                    return Row(
                      children: [
                        const Text('Constructed (unexpected): '),
                        button,
                      ],
                    );
                  } catch (e) {
                    return _CaughtAssert(message: e.toString());
                  }
                },
              ),
              const SizedBox(height: 24),
              const Text('2) Genuine icon-only with semanticLabel (correct):'),
              const SizedBox(height: 8),
              AppButton(
                leadingIcon: Icons.add,
                semanticLabel: 'Add',
                onPressed: _noop,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaughtAssert extends StatelessWidget {
  final String message;
  const _CaughtAssert({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.bug_report_outlined,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Assertion thrown at construction:\n$message',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BUG-11 — AppTextField ignores a swapped controller
// ---------------------------------------------------------------------------

class _ControllerSwapDemo extends StatefulWidget {
  const _ControllerSwapDemo();

  @override
  State<_ControllerSwapDemo> createState() => _ControllerSwapDemoState();
}

class _ControllerSwapDemoState extends State<_ControllerSwapDemo> {
  final TextEditingController _external = TextEditingController(
    text: 'EXTERNAL-CONTROLLER-TEXT',
  );
  bool _useExternal = false;

  @override
  void dispose() {
    _external.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BugPage(
      title: 'BUG-11 · Swapping controller null→external is silently ignored',
      severity: 'Edge case · low confidence (matches framework limitation)',
      lookFor:
          'With the toggle OFF the field owns an internal controller — type '
          'anything. Flip the toggle ON to pass an EXTERNAL controller holding '
          '"EXTERNAL-CONTROLLER-TEXT". The field does NOT update: there is no '
          'didUpdateWidget, so the State keeps its original controller.',
      children: [
        Row(
          children: [
            const Text('Pass external controller'),
            const SizedBox(width: 12),
            Switch(
              value: _useExternal,
              onChanged: (v) => setState(() => _useExternal = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Stage(
          child: AppTextField(
            label: 'Field',
            controller: _useExternal ? _external : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notes — non-visual issues
// ---------------------------------------------------------------------------

class _NonVisualNotes extends StatelessWidget {
  const _NonVisualNotes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget note(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Notes & dispositions', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Items withdrawn or demoted after review, plus real issues that '
          'cannot be reproduced as a static gallery tile.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        note(
          'BUG-4 (dark card/input borders) — WITHDRAWN, not a bug',
          'The reviewer applied a WCAG 3:1 UI-component contrast rule, but the '
              'subtle resting border is an intentional design choice (dark-mode '
              'contrast is meant to mirror light mode — subtle, not high-contrast). '
              'No change needed.',
        ),
        note(
          'BUG-5 (table loading scrim) — DEMOTED, code-hygiene only',
          'app_data_table.dart hardcodes ColoredBox(color: Colors.black12) for '
              'the loading overlay instead of a theme color. There is no visible '
              'defect — 12% black is barely perceptible in light mode and the '
              'spinner is the real loading affordance in both modes. The only point '
              'is the "components consume the theme, never raw colors" principle; '
              'swap to a theme-resolved scrim if/when tidying. Negligible impact.',
        ),
        note(
          'BUG-6 (DataTable stale hover after sort) — DEMOTED, latent not live',
          '_DataRow has no key, so its State is reused by position on reorder. '
              'But its only state is _hovered, set solely by MouseRegion '
              'enter/exit. After a reorder Flutter re-hit-tests the pointer '
              'post-frame, so the highlighted slot always matches where the mouse '
              'actually is — correct. Hover is purely cosmetic (no selection or '
              'row-data callback), so there is no wrong-row action. It only becomes '
              'a real bug if row-identity-bound state (inline edit, expand toggle, '
              'a selection checkbox) is ever added to _DataRow; add a stable '
              'ValueKey at that point.',
        ),
        note(
          'Inter fontFamilyFallback is not package-scoped',
          'app_text_theme.dart passes fontFamilyFallback: [\'Inter\'] without '
              'the package: scope. If the bundled Inter asset fails to load, the '
              'fallback resolves to an unregistered bare "Inter" and Flutter drops '
              'to Roboto/SF — different metrics — instead of staying on Inter. Only '
              'manifests on asset-load failure, so there is no live tile.',
        ),
        note(
          'AppDropdown overlay reads the State context, not overlayContext',
          'app_dropdown.dart builds its overlay with Theme.of(context) using '
              'the State.context rather than the builder\'s overlayContext. The '
              'common single-screen case works (try the standard AppDropdown '
              'gallery). It only breaks when the element is deactivated while the '
              'overlay is open — e.g. a tab switch or inner-route push with the '
              'menu down — which a static tile cannot force reliably.',
        ),
      ],
    );
  }
}
