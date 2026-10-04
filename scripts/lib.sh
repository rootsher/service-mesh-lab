# shellcheck shell=bash
# Helpers for the scenario checks. The checks are the same for both meshes;
# only the manifests next to them differ.

ctx=${KUBE_CONTEXT:?KUBE_CONTEXT is set by the Makefile}

k() { kubectl --context "$ctx" "$@"; }

# requests NAMESPACE DEPLOYMENT N CURL_ARGS...
# Sends N requests from inside a pod of DEPLOYMENT, one per line of output:
# the status code, a space, and the podinfo message of the answer if any.
# The requests leave the pod like the application's own would, so they carry
# its identity and go through its side of the mesh.
# shellcheck disable=SC2016 # the script runs in the pod, not here
requests() {
  local ns=$1 from=$2 n=$3
  shift 3
  k -n "$ns" exec "deploy/$from" -c app -- sh -c '
    n=$1; shift
    for _ in $(seq "$n"); do
      out=$(curl -s -m 5 -w "\n%{http_code}" "$@")
      code=$(printf "%s" "$out" | tail -n 1)
      msg=$(printf "%s" "$out" | sed -n "s/.*\"message\": \"\([^\"]*\)\".*/\1/p" | head -1)
      echo "$code $msg"
    done' sh "$n" "$@"
}

# count PATTERN: how many lines of stdin match PATTERN (an extended regex).
count() { grep -cE "$1" || true; }

pass() { printf '  \033[32mok\033[0m    %s\n' "$*"; }
fail() { printf '  \033[31mfail\033[0m  %s\n' "$*"; exit 1; }

# eventually DESCRIPTION COMMAND...
# Policy and routes reach the proxies a moment after kubectl apply returns.
# Retries COMMAND for up to 30 seconds before calling it a failure.
eventually() {
  local desc=$1
  shift
  for _ in $(seq 30); do
    if "$@" >/dev/null 2>&1; then
      pass "$desc"
      return 0
    fi
    sleep 1
  done
  fail "$desc"
}

# all_status CODE NAMESPACE DEPLOYMENT N CURL_ARGS...: every one of N
# requests answered with CODE.
all_status() {
  local code=$1
  shift
  local out
  out=$(requests "$@")
  [ "$(echo "$out" | count "^$code ")" -eq "$3" ]
}

# none_ok NAMESPACE DEPLOYMENT N CURL_ARGS...: not a single 200 among N.
none_ok() {
  local out
  out=$(requests "$@")
  [ "$(echo "$out" | count '^200 ')" -eq 0 ]
}

# only VERSION CURL_ARGS...: 30 requests from orders, every one answered
# by that version of payments.
only() {
  local version=$1
  shift
  local out
  out=$(requests demo orders 30 "$@")
  [ "$(echo "$out" | count "^200 payments $version\$")" -eq 30 ]
}

# One of the two payments-v1 replicas answers 500 to everything except probes
# and metrics while fault injection is on. That is podinfo's own switch, so
# the pod stays Ready and keeps receiving traffic: a replica that is broken
# but does not know it.
sick_pod() {
  k -n demo get pod -l app=payments,version=v1 -o jsonpath='{.items[0].metadata.name}'
}

fault() {
  k -n demo exec "$(sick_pod)" -c app -- curl -fs -X POST "localhost:9898/fault_injection/$1" >/dev/null
}
