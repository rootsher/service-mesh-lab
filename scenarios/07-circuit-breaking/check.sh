#!/usr/bin/env bash
# The same broken replica as in 06, without retries. After a few consecutive
# failures the mesh stops sending it traffic, and the healthy replica takes
# everything. No request is sent twice.
set -euo pipefail
source "$(dirname "$0")/../../scripts/lib.sh"

trap 'fault disable' EXIT
fault enable

# A handful of requests has to fail before the replica is ejected.
warmup=$(requests demo orders 20 http://payments-v1:9898/ | count '^5')
echo "        warm up: $warmup of 20 failed before the replica was ejected"

after=$(requests demo orders 100 http://payments-v1:9898/ | count '^5')
echo "        then:    $after of 100 failed"
[ "$after" -le 5 ] || fail "the broken replica is taken out of rotation (got $after failures)"
pass "the broken replica is taken out of rotation"
