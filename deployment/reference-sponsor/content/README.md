# Reference Sponsor Content (empty overlay)

This is the built-in **reference sponsor** content tree for the core local-stack.
It is intentionally minimal: it carries only `sponsor-config.json` so the portal's
`GET /api/v1/sponsor/branding` endpoint has something to return. There is **no**
`portal/` branding overlay and **no** `web/` PWA chrome — the `portal-final`
Dockerfile handles their absence gracefully (it logs a notice and continues; the
favicon + PWA icons simply 404, which is cosmetic).

## Why this exists

The local-stack builds a sponsor's `portal-final` image from a sponsor repo's
`content/` + `deployment/`. With no sponsor checked out, a core dev still needs a
runnable `portal-final` to rehearse the `dev` stack from `hht_diary` alone (e.g.
Postgres-only event-store fixes). This reference sponsor supplies the minimal
inputs for that. See `deployment/reference-sponsor/deployment/base-config.json`
and `deployment/local-stack/README.md`.

## Adding branding

To rehearse with real branding, run the local-stack from a sponsor repo (its thin
wrapper exports `SPONSOR_REPO`) or point `[associated.sponsor].path` in
`deployment/local-stack/.local-stack.local.toml` at a sponsor checkout. Do **not**
add sponsor-specific assets here — this tree stays empty by design.
