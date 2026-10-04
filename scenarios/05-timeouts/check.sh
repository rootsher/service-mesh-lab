#!/usr/bin/env bash
# The route gives payments one second. podinfo's /delay/N answers after N
# seconds, so /delay/2 is cut off by the mesh with a 504 and the caller does
# not wait for it.
set -euo pipefail
source "$(dirname "$0")/../../scripts/lib.sh"

eventually "a two second request is cut off with 504" \
  all_status 504 demo orders 3 http://payments:9898/delay/2
eventually "a fast request is not affected" \
  all_status 200 demo orders 10 http://payments:9898/delay/0
