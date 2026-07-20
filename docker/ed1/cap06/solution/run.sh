#!/usr/bin/env bash
# cap06 - solution test. Builds and runs an OCI container by hand with runc and
# proves: the config.json recipe lists the Part 1 mechanisms as data (namespaces),
# runc faithfully executes the recipe, and changing the recipe changes the
# container. Rootless (a --rootless spec): no sudo.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v runc >/dev/null   || { echo "ERROR: runc not found (see SETUP.md)" >&2; exit 1; }
command -v docker >/dev/null || { echo "ERROR: docker not found - needed only to build the rootfs (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/laricetta.sh" "$WORK"
namespaces=$(val "$WORK/oci.txt" namespaces)
run_one=$(val "$WORK/oci.txt" run_one)
run_two=$(val "$WORK/oci.txt" run_two)

# 1. the recipe carries the Part 1 mechanisms as data
for want in pid mount user; do
  case ",$namespaces," in
    *",$want,"*) : ;;
    *) echo "UNEXPECTED: the recipe does not list the $want namespace ($namespaces)" >&2; exit 1 ;;
  esac
done
echo "OK 1 - the config.json recipe lists the Part 1 namespaces as data ($namespaces)"

# 2. runc faithfully executes the recipe
if [ "$run_one" != "ricetta-uno" ]; then
  echo "UNEXPECTED: runc did not execute the recipe (got '$run_one')" >&2; exit 1
fi
echo "OK 2 - runc executes the recipe: the container printed '$run_one'"

# 3. changing the recipe changes the container: the config.json IS the container
if [ "$run_two" != "ricetta-due" ]; then
  echo "UNEXPECTED: changing the recipe did not change the output (got '$run_two')" >&2; exit 1
fi
echo "OK 3 - change the recipe and the container follows ('$run_two'): config.json is the container"

echo
echo "ALL CHECKS PASSED"
