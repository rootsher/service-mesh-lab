#!/usr/bin/env bash
# Inside the mesh every connection is mutual TLS. With the policy applied,
# a client that cannot present a mesh identity does not get an answer at all.
set -euo pipefail
source "$(dirname "$0")/../../scripts/lib.sh"

eventually "plain text from outside the mesh is refused" \
  none_ok outside outside 5 http://orders.demo:9898/
eventually "newsletter to orders still works over mTLS" \
  all_status 200 demo newsletter 10 http://orders.demo:9898/
eventually "orders to payments still works over mTLS" \
  all_status 200 demo orders 10 http://payments:9898/
