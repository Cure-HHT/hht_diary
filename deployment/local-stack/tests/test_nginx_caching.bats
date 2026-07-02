#!/usr/bin/env bats
# IMPLEMENTS REQUIREMENTS:
#   REQ-p00009: Sponsor-Specific Web Portals (stale assets show wrong branding
#               or stale auth code on every redeploy)
#   REQ-o00056: Container infrastructure for Cloud Run (image immutability
#               requires the client to actually fetch the new bundle)
# Parent-repo REQs cited because there is no sponsor-level requirement
# for asset-cache hygiene; per CHECKLIST §3 this is the correct fallback
# when no sponsor-specific equivalent exists.
#
# Verifies the nginx asset cache strategy doesn't pin the SPA entry points
# to a long-lived/immutable cache. main.dart.js and flutter_bootstrap.js
# have fixed filenames across builds; only their content changes. With a
# 1-year immutable cache the browser never refetches, requiring a hard
# reload after every redeploy.
#
# A response is considered "long-lived" if any Cache-Control line declares
# either `immutable` or `max-age=` >= 86400 (one day). nginx's `expires 1y`
# directive auto-generates `Cache-Control: max-age=31536000`, so we must
# match that form and not just the literal word "immutable".

setup() {
  PORT="${PORT:-8080}"
  curl -fsS "http://localhost:$PORT/health" >/dev/null \
    || skip "local-stack not running on :$PORT (run ./local-stack portal first)"
}

# Returns 0 (success) if any `Cache-Control:` header line declares a
# long-lived cache (immutable, or max-age >= 1 day). We scope the scan
# to Cache-Control lines so unrelated `max-age=` tokens (e.g. on
# Strict-Transport-Security) don't pollute the match.
# Used by `! _has_long_cache` assertions on SPA entry points.
_has_long_cache() {
  while IFS= read -r line; do
    if [[ "$line" =~ ^[Cc]ache-[Cc]ontrol: ]]; then
      if [[ "$line" =~ [Ii]mmutable ]]; then
        return 0
      fi
      if [[ "$line" =~ [Mm]ax-[Aa]ge=([0-9]+) ]]; then
        local age="${BASH_REMATCH[1]}"
        if (( age >= 86400 )); then
          return 0
        fi
      fi
    fi
  done <<< "$output"
  return 1
}

# Returns 0 if any Cache-Control header explicitly disables caching.
_has_no_cache_directive() {
  while IFS= read -r line; do
    if [[ "$line" =~ ^[Cc]ache-[Cc]ontrol: ]]; then
      [[ "$line" =~ no-store ]] && return 0
      [[ "$line" =~ no-cache ]] && return 0
      [[ "$line" =~ [Mm]ax-[Aa]ge=0([^0-9]|$) ]] && return 0
    fi
  done <<< "$output"
  return 1
}

@test "main.dart.js is not cached as immutable / long-lived" {
  run curl -sI "http://localhost:$PORT/main.dart.js"
  [ "$status" -eq 0 ]
  [[ "$output" =~ HTTP/1.1\ 200 ]] || [[ "$output" =~ HTTP/2\ 200 ]]
  if _has_long_cache; then
    echo "main.dart.js sent long-lived cache; will require hard reload after deploy"
    echo "$output"
    return 1
  fi
  if ! _has_no_cache_directive; then
    echo "main.dart.js missing no-cache headers:"
    echo "$output"
    return 1
  fi
}

@test "flutter_bootstrap.js is not cached as immutable / long-lived" {
  run curl -sI "http://localhost:$PORT/flutter_bootstrap.js"
  [ "$status" -eq 0 ]
  [[ "$output" =~ HTTP/1.1\ 200 ]] || [[ "$output" =~ HTTP/2\ 200 ]]
  if _has_long_cache; then
    echo "flutter_bootstrap.js sent long-lived cache; will require hard reload after deploy"
    echo "$output"
    return 1
  fi
  if ! _has_no_cache_directive; then
    echo "flutter_bootstrap.js missing no-cache headers:"
    echo "$output"
    return 1
  fi
}

@test "flutter_service_worker.js still no-cache (regression guard)" {
  run curl -sI "http://localhost:$PORT/flutter_service_worker.js"
  [ "$status" -eq 0 ]
  # Either the file is removed (Phase 2 may strip it via --pwa-strategy=none)
  # or no-cache still applies. Both outcomes acceptable here.
  if [[ "$output" =~ HTTP/1.1\ 200 ]] || [[ "$output" =~ HTTP/2\ 200 ]]; then
    if _has_long_cache; then
      echo "flutter_service_worker.js MUST NOT be long-lived cached:"
      echo "$output"
      return 1
    fi
    if ! _has_no_cache_directive; then
      echo "flutter_service_worker.js missing no-cache directive:"
      echo "$output"
      return 1
    fi
  else
    [[ "$output" =~ HTTP/1.1\ 404 ]] || [[ "$output" =~ HTTP/2\ 404 ]]
  fi
}

# CUR-1560: canvaskit is NOT content-addressed — canvaskit.js/.wasm and
# skwasm.js keep fixed names while their content changes with every
# Flutter SDK bump. A stale immutable canvaskit against a new
# main.dart.js breaks rendering after a deploy, so these must
# revalidate (the previous test asserted the opposite on a wrong
# "content-hashed" premise).
@test "canvaskit assets revalidate (fixed names, content changes per SDK bump)" {
  run curl -sI "http://localhost:$PORT/canvaskit/canvaskit.js"
  [ "$status" -eq 0 ]
  if [[ "$output" =~ HTTP/1.1\ 200 ]] || [[ "$output" =~ HTTP/2\ 200 ]]; then
    if _has_long_cache; then
      echo "canvaskit/canvaskit.js sent long-lived cache; a Flutter SDK bump would strand clients:"
      echo "$output"
      return 1
    fi
    if ! _has_no_cache_directive; then
      echo "canvaskit/canvaskit.js missing no-cache headers:"
      echo "$output"
      return 1
    fi
  fi
}

# CUR-1560: the asset manifests keep fixed names while their content
# changes with every build — a stale manifest against a new main.dart.js
# is the blank-login-page-after-deploy failure.
@test "AssetManifest is not cached as immutable / long-lived" {
  local found=0
  for p in /assets/AssetManifest.bin.json /assets/AssetManifest.json /assets/AssetManifest.bin; do
    run curl -sI "http://localhost:$PORT$p"
    [ "$status" -eq 0 ]
    if [[ "$output" =~ HTTP/1.1\ 200 ]] || [[ "$output" =~ HTTP/2\ 200 ]]; then
      found=1
      if _has_long_cache; then
        echo "$p sent long-lived cache; will require hard reload after deploy"
        echo "$output"
        return 1
      fi
      if ! _has_no_cache_directive; then
        echo "$p missing no-cache headers:"
        echo "$output"
        return 1
      fi
    fi
  done
  # At least one manifest variant must exist in any real Flutter web build.
  [ "$found" -eq 1 ]
}

@test "FontManifest.json is not cached as immutable / long-lived" {
  run curl -sI "http://localhost:$PORT/assets/FontManifest.json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ HTTP/1.1\ 200 ]] || [[ "$output" =~ HTTP/2\ 200 ]]
  if _has_long_cache; then
    echo "FontManifest.json sent long-lived cache; will require hard reload after deploy"
    echo "$output"
    return 1
  fi
  if ! _has_no_cache_directive; then
    echo "FontManifest.json missing no-cache headers:"
    echo "$output"
    return 1
  fi
}

# CUR-1560: tree-shaken font files (e.g. MaterialIcons-Regular.otf) are
# regenerated per build under the same name.
@test "tree-shaken fonts under /assets/fonts/ revalidate" {
  run curl -sI "http://localhost:$PORT/assets/fonts/MaterialIcons-Regular.otf"
  [ "$status" -eq 0 ]
  if [[ "$output" =~ HTTP/1.1\ 200 ]] || [[ "$output" =~ HTTP/2\ 200 ]]; then
    if _has_long_cache; then
      echo "/assets/fonts/* sent long-lived cache; icon glyphs go stale across deploys"
      echo "$output"
      return 1
    fi
    if ! _has_no_cache_directive; then
      echo "/assets/fonts/* missing no-cache headers:"
      echo "$output"
      return 1
    fi
  fi
}

@test "index.html is not heuristically cached" {
  # No explicit Cache-Control means the browser may apply heuristic
  # freshness based on Last-Modified, which is wrong for the SPA loader:
  # index.html is the entry point and must always reflect the current
  # deploy. Assert an explicit no-cache directive (or max-age=0).
  run curl -sI "http://localhost:$PORT/"
  [ "$status" -eq 0 ]
  [[ "$output" =~ HTTP/1.1\ 200 ]] || [[ "$output" =~ HTTP/2\ 200 ]]
  if _has_long_cache; then
    echo "index.html sent long-lived cache; redeploys would be invisible"
    echo "$output"
    return 1
  fi
  if ! _has_no_cache_directive; then
    echo "index.html missing explicit Cache-Control: no-cache directive:"
    echo "$output"
    return 1
  fi
}
