# DIARY-DEV-runtime-environment-resolution: Runtime Environment Resolution

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-OPS-single-promotable-artifact

## Assertions

A. The mobile and portal applications SHALL resolve the active environment at runtime rather than from a compile-time constant: the *Mobile Application* from a bundled environment pointer asset, and the portal from configuration the server provides over the same origin.

B. When the active environment cannot be determined — the mobile environment pointer is absent or unreadable, or the server provides no environment value — the application SHALL resolve to the dev environment.

C. Backend endpoint, application title, environment banner, developer-tools availability, and reset-data availability SHALL be derived from the resolved environment at runtime.

D. In the prod environment, the application SHALL disable developer tools, the reset-all-data affordance, the environment banner, and any affordance that fabricates, bulk-injects, or exports *Diary* records.

E. The mobile environment pointer SHALL be carried such that changing it does not invalidate the application's compiled output.

## Rationale

Moving the environment from a compile-time constant to a runtime-resolved bundled pointer is what allows one compilation to serve every environment (E) and lets all environment-dependent behavior follow a single source of truth (A, C). The dev default (B) makes any unspecified build safe. The prod gate (D) replaces flavor-based compile-time exclusion with one small, validatable runtime control.

*End* *Runtime Environment Resolution* | **Hash**: b0c74776

---

# DIARY-DEV-deployment-config-defaults: Deployment Configuration Defaults

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-mobile-diary-application
**Satisfies**: DIARY-PRD-configuration-precedence

## Assertions

A. The *Diary* SHALL resolve each *Sponsor* UI *Configuration Parameter* in the order: materialized `settings` projection row, then bundled deployment default, then hardcoded code default; a settings row whose value is null SHALL be treated as unset for this *Resolution*.

B. Deployment defaults SHALL be read from a bundled `assets/config/config_defaults.json` asset selected by store packaging per distribution, and SHALL NOT be appended to the event log, serving only as a *Resolution*-time fallback.

C. When the deployment-default asset is absent, unparseable, or omits a key, the *Diary* SHALL fall back to the hardcoded code default for that key.

D. Deployment defaults SHALL apply to a *Sponsor*-agnostic *Diary* before linking or with no *Sponsor*; a *Sponsor*-locked value delivered at link SHALL take precedence over a deployment default for the same key.

E. When the resolved allow-set (`ui.availableLanguages` / `ui.availableFonts`) is applied or changes and the *Participant*'s pick (`pref.languageCode` / `pref.selectedFont`) is not a member of it, the *Diary* SHALL set the pick to the corresponding default through the normal *User*-setting path as one corrective write whose source is the *User*; when the pick is already a member the *Diary* SHALL NOT write. The operation SHALL be idempotent.

F. When *Sponsor*-applied settings are unlocked, the *Diary* SHALL revert each allow-set and capability `ui.*` *Configuration Parameter* to its deployment-or-code default by clearing the parameter's value, while keeping the value of every other unlocked key; the *Participant*'s pick SHALL NOT be restored by this revert.

## Rationale

The deployment-default layer is the DEV-level *Resolution* of the "platform default" in the parent *DIARY-PRD-configuration-precedence*, whose two-layer platform-default-versus-*Sponsor*-configuration model this requirement realizes without altering it. The bundled-asset, packaging-stamped mechanism mirrors the `assets/config/env.json` pointer of *DIARY-DEV-runtime-environment-resolution*: a per-distribution asset selected at store packaging carries the default without invalidating the compiled output. Keeping the default out of the event log (B) preserves the single-source-of-truth invariant that only applied settings are recorded. The conditional reconciliation (E) keeps a *Participant*'s stored pick coherent with a restricted allow-set by writing the corrective default through the same *User* path any other selection would take, and the idempotent guard avoids a redundant write when the pick is already viable. The unlock revert (F) is the counterpart at end-of-participation: clearing the `ui.*` values returns the allow-sets to the deployment or code default so the *Participant* regains the full option set, while value-override keys keep their value (the keep-as-is rule of the sponsor-requested-settings model); the *Participant*'s own pick is left untouched and simply takes effect again when the allow-set re-includes it.

*End* *Deployment Configuration Defaults* | **Hash**: a83387be
