#!/usr/bin/env bash
# Runs every scenario in scenarios/, or the one given as the first argument.
# A scenario is a directory with check.sh, which is the same for both meshes,
# manifests both meshes read as they are, and a directory per mesh with what
# only that mesh understands: manifests, and setup.sh or teardown.sh for what
# cannot be a manifest.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib.sh
mesh=${MESH:?MESH is set by the Makefile}

if [ $# -gt 0 ] && [ -n "$1" ]; then
  scenarios=("scenarios/${1#scenarios/}")
else
  scenarios=(scenarios/*/)
fi

# manifests DIR: the directories in DIR whose manifests apply to this mesh.
manifests() {
  local d
  for d in "$1" "$1/$mesh"; do
    if compgen -G "$d/*.yaml" >/dev/null; then echo "$d"; fi
  done
}

teardown() {
  local dir=$1 d
  for d in $(manifests "$dir"); do
    k delete --ignore-not-found -f "$d" >/dev/null
  done
  if [ -x "$dir/$mesh/teardown.sh" ]; then "$dir/$mesh/teardown.sh"; fi
}

for dir in "${scenarios[@]}"; do
  dir=${dir%/}
  echo "${dir#scenarios/}"
  trap 'teardown "$dir"' EXIT
  if [ -x "$dir/$mesh/setup.sh" ]; then "$dir/$mesh/setup.sh"; fi
  for d in $(manifests "$dir"); do
    k apply -f "$d" >/dev/null
  done
  "$dir/check.sh"
  teardown "$dir"
  trap - EXIT
done
