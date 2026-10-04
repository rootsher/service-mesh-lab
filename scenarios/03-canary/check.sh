#!/usr/bin/env bash
# payments is split 90/10 between v1 and v2 by weight. The caller still asks
# for payments; which version answers is the mesh's decision.
set -euo pipefail
source "$(dirname "$0")/../../scripts/lib.sh"

has_v2() {
  local out
  out=$(requests demo orders 30 http://payments:9898/)
  [ "$(echo "$out" | count 'payments v2$')" -gt 0 ]
}
eventually "the route is in place" has_v2

out=$(requests demo orders 300 http://payments:9898/)
v1=$(echo "$out" | count '^200 payments v1$')
v2=$(echo "$out" | count '^200 payments v2$')
echo "        300 requests: v1 $v1, v2 $v2"
[ $((v1 + v2)) -eq 300 ] || fail "every request answered by v1 or v2"
if [ "$v2" -lt 12 ] || [ "$v2" -gt 50 ]; then
  fail "v2 gets about 10% (expected 12 to 50 of 300, got $v2)"
fi
pass "v2 gets about 10% of requests"
