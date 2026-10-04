#!/usr/bin/env bash
# One of the two payments-v1 replicas fails every request. Called directly,
# payments-v1 fails for a large share of requests. Through the route on
# payments, which only goes to v1 and retries 5xx, the caller does not see it.
set -euo pipefail
source "$(dirname "$0")/../../scripts/lib.sh"

eventually "the route sends payments to v1 only" only v1 http://payments:9898/

trap 'fault disable' EXIT
fault enable

direct=$(requests demo orders 100 http://payments-v1:9898/ | count '^5')
echo "        payments-v1 without retries: $direct of 100 failed"
[ "$direct" -ge 15 ] || fail "the broken replica fails requests when nothing retries (got $direct)"
pass "the broken replica fails requests when nothing retries"

routed=$(requests demo orders 100 http://payments:9898/ | count '^5')
echo "        payments with retries:       $routed of 100 failed"
[ "$routed" -le 3 ] || fail "retries hide the broken replica (got $routed failures)"
pass "retries hide the broken replica"
