#!/usr/bin/env bash
# Requests with x-canary: true go to v2, everything else to v1. A targeted
# rollout: the people who opted in, not a random slice of everyone.
set -euo pipefail
source "$(dirname "$0")/../../scripts/lib.sh"

eventually "with x-canary: true every request reaches v2" \
  only v2 -H 'x-canary: true' http://payments:9898/
eventually "without the header every request reaches v1" \
  only v1 http://payments:9898/
eventually "any other value of the header reaches v1" \
  only v1 -H 'x-canary: maybe' http://payments:9898/
