#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../../../scripts/lib.sh"

k -n demo annotate service payments-v1 \
  balancer.linkerd.io/failure-accrual- \
  balancer.linkerd.io/failure-accrual-consecutive-max-failures- >/dev/null
