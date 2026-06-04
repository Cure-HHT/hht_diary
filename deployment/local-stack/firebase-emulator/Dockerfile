# firebase-emulator:local
#
# Cached base image for the local-stack's Firebase auth emulator. Bakes
# the JRE-17 + firebase-tools install that compose used to run inline on
# every container start (~60s cold tax). With this image, the runtime
# command is just `firebase emulators:start ...` (~5-10s).
#
# Sponsor-agnostic: this image holds zero sponsor source. The tag has no
# sponsor suffix on purpose, so:
#   1. `cmd_down`'s sponsor-suffixed image-removal loop does not match it;
#      the cache survives `down` cycles for free.
#   2. Two sponsor repos on one dev box share a single cached image.
#
# Bumping firebase-tools: edit FIREBASE_TOOLS_VERSION below. The next
# `local-stack portal` re-runs `docker build` and the install layer
# rebuilds automatically because its ARG default changed. No explicit
# `docker image rm` is needed for version bumps. (To force a re-pull of
# the FROM base — rare — bring the stack down first, then
# `docker image rm firebase-emulator:local`.)
FROM node:20-slim

ARG FIREBASE_TOOLS_VERSION=15.16.0

RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
        openjdk-17-jre-headless \
        curl \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g "firebase-tools@${FIREBASE_TOOLS_VERSION}"

WORKDIR /app
EXPOSE 9099 4000
