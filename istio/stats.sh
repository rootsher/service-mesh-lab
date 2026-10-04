#!/usr/bin/env bash
# Golden metrics per workload, and who calls whom over mTLS, both from the
# waypoint. It reports the original caller, not itself. Prometheus is reached through the API server, so
# nothing has to be port forwarded.
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"

query() {
  k get --raw "/api/v1/namespaces/istio-system/services/prometheus:9090/proxy/api/v1/query?query=$(jq -rn --arg q "$1" '$q | @uri')"
}

by_workload() {
  query "$1" | jq -r '.data.result[] | "\(.metric.destination_workload) \(.value[1])"'
}

sel='destination_workload_namespace="demo",reporter="waypoint"'
rps=$(by_workload "sum by (destination_workload) (rate(istio_requests_total{$sel}[1m]))")
ok=$(by_workload "sum by (destination_workload) (rate(istio_requests_total{$sel,response_code!~\"5..\"}[1m])) / sum by (destination_workload) (rate(istio_requests_total{$sel}[1m]))")
p95=$(by_workload "histogram_quantile(0.95, sum by (destination_workload, le) (rate(istio_request_duration_milliseconds_bucket{$sel}[1m])))")

{
  echo "NAME SUCCESS RPS LATENCY_P95"
  while read -r name r; do
    s=$(awk -v n="$name" '$1 == n { printf "%.2f%%", $2 * 100 }' <<<"$ok")
    l=$(awk -v n="$name" '$1 == n { printf "%dms", $2 }' <<<"$p95")
    printf '%s %s %.1frps %s\n' "$name" "${s:--}" "$r" "${l:--}"
  done <<<"$rps"
} | column -t

echo
{
  echo "SRC DST SECURED"
  query "sum by (source_workload, destination_workload, connection_security_policy) (increase(istio_requests_total{$sel}[5m])) > 0" |
    jq -r '.data.result[] | "\(.metric.source_workload) \(.metric.destination_workload) \(if .metric.connection_security_policy == "mutual_tls" then "yes" else "no" end)"' |
    sort
} | column -t
