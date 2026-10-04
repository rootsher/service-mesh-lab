#!/usr/bin/env bash
# Only orders may call payments. The decision is made on the caller's mTLS
# identity, its service account, not on its IP address or namespace.
set -euo pipefail
source "$(dirname "$0")/../../scripts/lib.sh"

eventually "newsletter to payments is denied" \
  all_status 403 demo newsletter 5 http://payments:9898/
eventually "newsletter to payments-v1 is denied as well" \
  none_ok demo newsletter 5 http://payments-v1:9898/
pod_ip=$(k -n demo get pod -l app=payments,version=v1 -o jsonpath='{.items[0].status.podIP}')
eventually "newsletter straight to a payments pod IP is denied" \
  none_ok demo newsletter 5 "http://$pod_ip:9898/"
eventually "outside the mesh to payments is denied" \
  none_ok outside outside 5 http://payments.demo:9898/
eventually "orders to payments is allowed" \
  all_status 200 demo orders 20 http://payments:9898/
eventually "newsletter to orders, and on to payments, is allowed" \
  all_status 200 demo newsletter 10 -X POST -d hello http://orders:9898/echo
