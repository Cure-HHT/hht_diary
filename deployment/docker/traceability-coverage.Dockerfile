# CUR-1557 Part 2: thin layer on the image callisto builds on, carrying the
# test targets' reporter outputs at a stable path so a per-PR run can seed the
# skipped targets' baselines (and the merge can promote a complete set).
#
# Built by traceability-matrix.yml AFTER the run, when every <target>/coverage/
# dir exists on the (bind-mounted) workspace -- fresh for the targets that ran,
# carried for the rest. Build context is the repo root; there is no root
# .dockerignore, so coverage is not ignore-blocked here.
#
# Multi-stage on purpose: a naive `COPY apps` + prune leaves the full app tree
# in an earlier layer (Docker never reclaims deleted files from prior layers),
# roughly doubling an image whose base already carries the source. The `collect`
# stage reduces to just the coverage artifacts; the final image adds ONLY that
# tiny tree via COPY --from.
ARG SPONSOR_CI_IMAGE=ghcr.io/cure-hht/sponsor-ci:main-latest
FROM ${SPONSOR_CI_IMAGE} AS base

FROM base AS collect
# sponsor-ci runs as a non-root USER; COPY'd files are root-owned, so the prune
# must run as root or it fails with "Permission denied".
USER root
COPY apps /tmp/traceability/apps
RUN find /tmp/traceability/apps -type f \
      ! -name machine.jsonl ! -name lcov.info -delete \
 && find /tmp/traceability/apps -type d -empty -delete

FROM base
COPY --from=collect /tmp/traceability /opt/elspais/traceability
# This image is never executed (only `docker create` + `docker cp` to extract
# the coverage tree), so the runtime user is immaterial -- set a non-root user
# to satisfy Trivy DS-0002 ("last USER command should not be 'root'").
USER 65534
