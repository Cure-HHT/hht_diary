# Core reference final portal image (no-sponsor local-stack rehearsal)
#
# This is the built-in "reference sponsor" variant of the sponsor-owned
# portal-final.Dockerfile. It is identical to a sponsor's image recipe except
# the sponsor id is `reference` and the content/ overlay is empty, so a core
# dev can bring up the local-stack from hht_diary alone (no sponsor checkout).
# Keep it in sync with the sponsor Dockerfile until the recipe is hoisted into
# hht_sponsor_iac as a sponsor-generic, id-parameterized template (follow-up).
#
# Layers:
#   1. sponsor-ci (source + deps) — Flutter web build + gRPC health compile
#   2. portal-server binary — pre-compiled by core repo, pulled as image
#   3. debian:12-slim runtime — nginx + server binary + gRPC health + web builds + Doppler
#
# Runtime split:
#   - nginx serves Flutter web from /app/web on public port 8080
#   - portal-server runs privately on localhost:8081
#
# Single promotable web bundle: the SPA carries no environment identity and
# discovers its environment at runtime from the server's same-origin config
# (/api/v1/portal/config/identity, which reports ENVIRONMENT). The same bundle
# is served in every deployed environment. The only build-time variant is the
# local-stack image, which bakes FIREBASE_AUTH_EMULATOR_HOST so the SPA talks
# to the Firebase emulator (browser-side; Flutter web's String.fromEnvironment
# is compile-time-only, so a runtime container env var is invisible to the SPA).

ARG SPONSOR_CI_IMAGE=ghcr.io/cure-hht/sponsor-ci:main-latest
ARG PORTAL_SERVER_IMAGE=ghcr.io/cure-hht/portal-server:main-latest
ARG DOPPLER_VERSION=3.75.1
# Build identifier substituted into APP_VERSION's build-metadata field as
# ${pubspec_semver}+${BUILD_ID}. CI passes the 7-char short_sha; the
# default `local` is used by ad-hoc `docker build` runs without
# --build-arg (CI's validate-images regex requires 7 hex chars and runs
# only in CI, not locally).
ARG BUILD_ID=local

# Firebase Auth emulator host, baked into the SPA only for the local-stack
# image. Empty for every deployed build (CI/Cloud Run) — those resolve their
# environment from the server at runtime, so one bundle serves them all.
ARG FIREBASE_AUTH_EMULATOR_HOST=""

# ─── Stage 1: Build the Flutter web bundle with sponsor content ──
FROM ${SPONSOR_CI_IMAGE} AS web-build

ARG BUILD_ID
ARG FIREBASE_AUTH_EMULATOR_HOST

WORKDIR /workspace/src

# Copy full sponsor content tree from sponsor repo
COPY content ./sponsor-content

# Apply sponsor portal content into portal UI/app structure
RUN set -eu && \
    mkdir -p /workspace/src/apps/sponsor-portal/portal_ui_evs/web/portal && \
    if [ -d /workspace/src/sponsor-content/portal ]; then \
      cp -R /workspace/src/sponsor-content/portal/. /workspace/src/apps/sponsor-portal/portal_ui_evs/web/portal/; \
    else \
      echo "No sponsor portal content found at content/portal; continuing without portal overlay."; \
    fi && \
    if [ -f /workspace/src/sponsor-content/sponsor-config.json ]; then \
      cp /workspace/src/sponsor-content/sponsor-config.json /workspace/src/apps/sponsor-portal/portal_ui_evs/web/portal/sponsor-config.json; \
    else \
      echo "No sponsor-config.json found in content/; continuing without branding config."; \
    fi && \
    # Sponsor PWA chrome (favicon, app icons) overlays into the SPA web
    # ROOT, not /web/portal/, because index.html references them as
    # `favicon.png` and `icons/Icon-{192,512}.png` relative to the base
    # href (`/`). Optional — if a sponsor doesn't provide these, the
    # manifest icons + favicon link 404, which is the pre-existing
    # behavior across all flavors. CUR-1263 Bug 7 (continued).
    if [ -d /workspace/src/sponsor-content/web ]; then \
      cp -R /workspace/src/sponsor-content/web/. /workspace/src/apps/sponsor-portal/portal_ui_evs/web/; \
      echo "Sponsor PWA chrome overlaid from content/web/"; \
    else \
      echo "No sponsor web overlay at content/web; favicon.png + icons/Icon-{192,512}.png will 404."; \
    fi

# Build the single portal web bundle.
#
# Implements: DIARY-OPS-single-promotable-artifact/B — one environment-
# independent bundle; no APP_FLAVOR. The local-stack image is the only variant,
# and differs solely by the baked emulator host.
#
# Cache strategy: the Flutter compile is the most expensive layer in this
# Dockerfile, so its cache key must be independent of the per-commit
# BUILD_ID. We do this in two RUNs:
#
#   1. Compile with a constant sentinel `__BUILD_ID__` standing in for
#      the SHA. dart2js inlines this literal into main.dart.js. This
#      RUN's command string never references ${BUILD_ID}, so its cache
#      key is invalidated only by sponsor-ci digest changes (incl.
#      pubspec.yaml bumps in hht_diary) or sponsor content changes.
#   2. After compile, verify the sentinel survived dart2js (tripwire)
#      and sed-substitute it for ${BUILD_ID} across all generated *.js.
#      Cheap (seconds), invalidated per commit.
#
# APP_VERSION is composed here, not read verbatim from pubspec.yaml.
# APP_SEMVER comes from pubspec, with any inherited +N build number
# defensively stripped (tolerates the transition period while hht_diary
# still ships a stale +N in portal_ui_evs/pubspec.yaml).
WORKDIR /workspace/src/apps/sponsor-portal/portal_ui_evs
RUN set -eu && \
    APP_SEMVER="$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d+ -f1)" && \
    mkdir -p /workspace/out && \
    printf '%s' "${APP_SEMVER}" > /workspace/out/APP_SEMVER && \
    echo "Building portal-ui APP_SEMVER=${APP_SEMVER} (sentinel: __BUILD_ID__)" && \
    EMU_DEFINE=""; \
    if [ -n "${FIREBASE_AUTH_EMULATOR_HOST}" ]; then \
      echo "━━━ local-stack build: baking FIREBASE_AUTH_EMULATOR_HOST=${FIREBASE_AUTH_EMULATOR_HOST} ━━━"; \
      EMU_DEFINE="--dart-define=FIREBASE_AUTH_EMULATOR_HOST=${FIREBASE_AUTH_EMULATOR_HOST}"; \
    else \
      echo "━━━ deployed build: environment-independent bundle (no APP_FLAVOR) ━━━"; \
    fi; \
    # IMPLEMENTS: REQ-p00009 (sponsor portal must always serve the
    # latest deploy; offline-first SW caches old main.dart.js and
    # makes deploys invisible without a hard reload),
    #            REQ-d00083-E (cache storage clear is moot if the SW
    # never registers).
    # CUR-1280: --pwa-strategy=none drops flutter_service_worker.js
    # entirely. Flutter web SPA still loads via flutter_bootstrap.js;
    # we just lose the offline cache, which we don't want for a
    # clinical portal.
    flutter build web --release \
      --pwa-strategy=none \
      --dart-define=APP_VERSION="${APP_SEMVER}+__BUILD_ID__" \
      ${EMU_DEFINE} \
      --output="/workspace/out/web" && \
    test -f "/workspace/out/web/index.html" && \
    echo "✅ portal web compile complete"

# Stamp BUILD_ID into the compiled JS bundle. This RUN's command string
# references ${BUILD_ID}, so its cache key invalidates per commit — but
# it's grep + sed across one small directory, runs in seconds.
#
# The grep -q tripwire fails the build if dart2js ever transforms the
# sentinel literal in a way that defeats sed. That should never happen
# for a unique 12-char ASCII underscore-bracketed token, but failing
# loud is safer than silently shipping a sentinel-displaying app.
RUN set -eu && \
    SENTINEL="__BUILD_ID__" && \
    APP_SEMVER="$(cat /workspace/out/APP_SEMVER)" && \
    echo "Stamping BUILD_ID=${BUILD_ID} into compiled bundle" && \
    grep -q "${SENTINEL}" "/workspace/out/web/main.dart.js" || { \
      echo "FAIL: sentinel ${SENTINEL} not present in web/main.dart.js"; \
      echo "      dart2js may have transformed the literal; investigate before shipping."; \
      exit 1; \
    } && \
    find "/workspace/out/web" -name "*.js" -exec \
      sed -i "s|${SENTINEL}|${BUILD_ID}|g" {} + && \
    printf '%s+%s' "${APP_SEMVER}" "${BUILD_ID}" > /workspace/out/APP_VERSION && \
    echo "✅ Stamped APP_VERSION=$(cat /workspace/out/APP_VERSION)"

# NOTE (CUR-1409): The kill-switch service-worker restore step from the
# legacy portal-ui image is intentionally omitted here. portal_ui_evs is a
# fresh app that has never registered a service worker in any browser, so
# there is no stale SW to evict — and it ships no
# web/flutter_service_worker.js source to restore. With --pwa-strategy=none
# (above) Flutter emits no functional SW, which is the desired end state for
# this clinical portal.

# ─── Stage 2: Pre-built portal-server binary from core repo ──────
FROM ${PORTAL_SERVER_IMAGE} AS server-binary

# ─── Stage 2b: Build gRPC health server from sponsor-ci source ───
FROM ${SPONSOR_CI_IMAGE} AS grpc-health-build

WORKDIR /workspace/src/apps/common-dart/grpc_health
RUN dart pub get --offline && \
    mkdir -p /workspace/out && \
    dart compile exe bin/server.dart -o /workspace/out/grpc_health_server

# ─── Stage 3: Doppler CLI ────────────────────────────────────────
FROM debian:12-slim AS doppler-download

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG DOPPLER_VERSION
RUN wget -q https://github.com/DopplerHQ/cli/releases/download/${DOPPLER_VERSION}/doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz && \
    tar xzf doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz && \
    chmod +x doppler && \
    rm doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz

# ─── Stage 4: Runtime ────────────────────────────────────────────
FROM debian:12-slim

ENV PORT=8080
ENV BACKEND_PORT=8081
ENV APP_WEB_ROOT=/app/web
# Portal seed-users (CUR-1437): portal_server_evs reads this file at boot and
# applies the role assignments idempotently. Deployed seed is SystemOperator-only;
# operators provision the first Administrators through the portal. The file is
# bundled below from deployment/seed/portal-users.json.
ENV PORTAL_SEED_USERS_PATH=/app/seed/portal-users.json
# Sponsor config directory (CUR-1474): portal-server reads role-permissions.yaml
# and other sponsor config from this directory. A container has no repo tree to
# walk up to the reference sponsor, so the pointer must be set explicitly here.
ENV SPONSOR_CONFIG_DIR=/app/sponsor
# ENVIRONMENT must be set at deploy time (dev/qa/uat/prod). The portal-server
# reports it to the SPA via /api/v1/portal/config/identity so the client
# resolves its environment (banner, dev-tools, prod gating) at runtime. No
# default — start.sh fails hard if unset, so a deployed portal never silently
# renders as dev.

RUN set -eu && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      nginx \
      ca-certificates \
      curl && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf

# Doppler CLI for secret injection at startup
COPY --from=doppler-download /doppler /usr/local/bin/doppler

RUN groupadd --gid 10001 appuser && \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash appuser

WORKDIR /app

# Pre-built portal server binary + version manifest (from core repo)
COPY --from=server-binary /app/server /app/portal-server
COPY --from=server-binary /app/VERSIONS /app/VERSIONS

# Append the portal-ui version (semver + build_id) onto the inherited manifest.
# The file at /workspace/out/APP_VERSION was written in the web-build stage.
# Appended here (not in web-build) because /app/VERSIONS only exists in
# this runtime stage. Runs as root; ownership is fixed up by the chown below.
COPY --from=web-build /workspace/out/APP_VERSION /tmp/portal_ui_app_version
RUN set -eu && \
    APP_VERSION="$(cat /tmp/portal_ui_app_version)" && \
    printf 'portal_ui_version=%s\n' "${APP_VERSION}" >> /app/VERSIONS && \
    printf 'portal_deployment=reference+%s\n' "${APP_VERSION##*+}" >> /app/VERSIONS && \
    rm /tmp/portal_ui_app_version
# portal_deployment is the AXIS-C wrap id: <sponsor>+<sponsor_build_sha>. The
# build sha is reused from APP_VERSION so it can't drift from portal_ui_version.
# (Real sponsors substitute their own id, e.g. <sponsor>+<sha>; the deploy-event
# counter is injected separately at deploy time as Cloud Run env vars.)

# gRPC health server binary (compiled from sponsor-ci source)
COPY --from=grpc-health-build /workspace/out/grpc_health_server /app/grpc_health_server

# The single web bundle, served directly from /app/web (nginx root).
COPY --from=web-build /workspace/out/web /app/web

# Ensure sponsor runtime assets exist in the shipped bundle. Copy the
# *contents* into /app/web/portal/ (which already exists from the Flutter build
# output) so the assets land at /app/web/portal/<file>, not nested under
# /app/web/portal/sponsor-portal-assets/.
COPY --from=web-build /workspace/src/apps/sponsor-portal/portal_ui_evs/web/portal /app/sponsor-portal-assets
RUN set -eu && \
    mkdir -p /app/web/portal && \
    cp -R /app/sponsor-portal-assets/. /app/web/portal/ && \
    rm -rf /app/sponsor-portal-assets

# Sponsor content for server-side branding endpoint (/api/v1/sponsor/branding)
# The handler reads /app/sponsor-content/{SPONSOR_ID}/sponsor-config.json.
# Reference sponsor id is `reference` (matches base-config.json + SPONSOR_ID
# at runtime); the overlay is the empty reference content tree.
COPY content /app/sponsor-content/reference

COPY deployment/nginx/nginx.conf /etc/nginx/nginx.conf
COPY deployment/nginx/evs_proxy.conf /etc/nginx/evs_proxy.conf
COPY deployment/scripts/start.sh /app/start.sh

# Portal seed-users (CUR-1437): read at boot via PORTAL_SEED_USERS_PATH.
COPY deployment/seed/portal-users.json /app/seed/portal-users.json

# Unified sponsor config directory (CUR-1474). The portal-server reads ONE dir,
# resolved from SPONSOR_CONFIG_DIR. role-permissions.yaml binds each role to its
# Action permissions (CAL-DEV-role-permissions-seed).
COPY deployment/sponsor /app/sponsor

RUN set -eu && \
    chmod +x /app/portal-server /app/grpc_health_server /app/start.sh && \
    mkdir -p /var/cache/nginx /var/lib/nginx /var/log/nginx /tmp/nginx && \
    chown -R appuser:appuser /app /var/cache/nginx /var/lib/nginx /var/log/nginx /etc/nginx /tmp

USER appuser

EXPOSE 8080

LABEL org.opencontainers.image.source="https://github.com/Cure-HHT/hht_diary"
LABEL org.opencontainers.image.description="Reference Portal (no-sponsor local-stack rehearsal) - nginx + Dart API + Flutter web"

CMD ["/app/start.sh"]
