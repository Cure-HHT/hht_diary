# diary_design_system_book

Widgetbook gallery for [`diary_design_system`](../diary_design_system) — the shared design system consumed by the diary mobile app and the sponsor portal.

## Purpose

Components in `diary_design_system` are built before any consumer references them (see the "build-first, sweep-last" policy in `docs/superpowers/specs/design-system-plan.md` §7). This gallery is where each component is reviewed against the Figma source of truth — variants, sizes, states, edge cases — **before** call sites in the portal or mobile app start consuming it.

## Run locally

```bash
cd apps/common-flutter/diary_design_system_book
flutter pub get
flutter run -d chrome
```

The gallery loads in your browser at the URL Flutter prints. Open the Figma file alongside it for side-by-side visual comparison.

## Adding use cases

Each component phase (3 onward) lands its Widgetbook use cases in the same commit that introduces the component. Use cases live under `lib/use_cases/<component>/`. The top-level `lib/main.dart` registers each component's directory entry.

Refer to existing use cases for the convention. A use case is a one-screen Widget that exercises the component in a known state (variant × size × loading × focused × disabled × …).
