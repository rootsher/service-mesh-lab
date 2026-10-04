#!/usr/bin/env bash
# Linkerd calls it failure accrual and reads it from annotations on the
# Service, so there is no manifest to apply here. After three consecutive
# failures an endpoint is ejected and probed again with backoff.
set -euo pipefail
source "$(dirname "$0")/../../../scripts/lib.sh"

k -n demo annotate --overwrite service payments-v1 \
  balancer.linkerd.io/failure-accrual=consecutive \
  balancer.linkerd.io/failure-accrual-consecutive-max-failures=3 >/dev/null
