# Shared sponsor CI base image
# Includes shared application source + resolved dependencies
# Does NOT include sponsor content, compiled binaries, or runtime-only tooling

FROM ghcr.io/cure-hht/clinical-diary-ci:latest

WORKDIR /workspace/src

# Copy repo metadata / toolchain files first for better layer caching
COPY pubspec.yaml ./
COPY pubspec.lock ./
COPY melos.yaml ./
COPY analysis_options.yaml ./
COPY dart_test.yaml ./
COPY .github/versions.env ./.github/versions.env

# Copy only the shared source trees needed by sponsor builds
COPY apps/common-dart/trial_data_types ./apps/common-dart/trial_data_types
COPY apps/edc/rave-integration ./apps/edc/rave-integration
COPY apps/sponsor-portal/portal_functions ./apps/sponsor-portal/portal_functions
COPY apps/sponsor-portal/portal_server ./apps/sponsor-portal/portal_server
COPY apps/sponsor-portal/portal-ui ./apps/sponsor-portal/portal-ui
COPY apps/daily-diary/diary_functions ./apps/daily-diary/diary_functions
COPY apps/daily-diary/diary_server ./apps/daily-diary/diary_server

# Resolve dependencies for shared packages/apps
RUN set -euo pipefail && \
    cd /workspace/src/apps/common-dart/trial_data_types && dart pub get && \
    cd /workspace/src/apps/edc/rave-integration && dart pub get && \
    cd /workspace/src/apps/sponsor-portal/portal_functions && dart pub get && \
    cd /workspace/src/apps/sponsor-portal/portal_server && dart pub get && \
    cd /workspace/src/apps/sponsor-portal/portal-ui && flutter pub get && \
    cd /workspace/src/apps/daily-diary/diary_functions && dart pub get && \
    cd /workspace/src/apps/daily-diary/diary_server && dart pub get

# Validate the image shape during build:
# - shared source exists
# - sponsor content is NOT present
# - compiled binaries are NOT present
# - built web output is NOT present
RUN set -euo pipefail && \
    test -d /workspace/src/apps/sponsor-portal/portal_functions && \
    test -d /workspace/src/apps/sponsor-portal/portal_server && \
    test -d /workspace/src/apps/sponsor-portal/portal-ui && \
    test -d /workspace/src/apps/daily-diary/diary_functions && \
    test -d /workspace/src/apps/daily-diary/diary_server && \
    test ! -d /workspace/src/sponsor-content && \
    test ! -f /workspace/src/apps/sponsor-portal/portal_server/bin/server && \
    test ! -d /workspace/src/apps/sponsor-portal/portal-ui/build/web

CMD ["/bin/bash"]