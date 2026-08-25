#!/usr/bin/env bash
# cap06 - solution test. Builds and runs an OCI container by hand with runc and
# proves: the config.json recipe lists the Part 1 mechanisms as data (namespaces),
# runc faithfully executes the recipe, changing its command and UTS namespace
# changes the container, and two OCI runtimes execute the same bundle identically.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v runc >/dev/null   || { echo "ERROR: runc not found (see SETUP.md)" >&2; exit 1; }
command -v docker >/dev/null || { echo "ERROR: docker not found - needed only to build the rootfs (see SETUP.md)" >&2; exit 1; }
runtime2=${CAP06_RUNTIME2:-crun}
command -v "$runtime2" >/dev/null || {
  echo "ERROR: second OCI runtime '$runtime2' not found; install crun or set CAP06_RUNTIME2 to another OCI runtime" >&2
  exit 1
}

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/recipe.sh" "$WORK"
namespaces=$(val "$WORK/oci.txt" namespaces)
run_one=$(val "$WORK/oci.txt" run_one)
run_two=$(val "$WORK/oci.txt" run_two)
recipe_hostname=$(val "$WORK/oci.txt" recipe_hostname)
uts_private=$(val "$WORK/oci.txt" uts_private)
uts_host=$(val "$WORK/oci.txt" uts_host)
runtime_runc=$(val "$WORK/oci.txt" runtime_runc)
runtime_two=$(val "$WORK/oci.txt" runtime_two)

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

# 4. the UTS namespace controls whether the recipe or host hostname is observed
host_hostname=$(hostname)
if [ "$uts_private" != "$recipe_hostname" ] || [ "$uts_private" = "$host_hostname" ]; then
  echo "UNEXPECTED: with a private UTS namespace the container did not take the recipe hostname (got '$uts_private')" >&2; exit 1
fi
if [ "$uts_host" != "$host_hostname" ]; then
  echo "UNEXPECTED: without the UTS namespace the container did not expose the host hostname" >&2; exit 1
fi
echo "OK 4 - changing the UTS namespace changes the hostname source as the recipe requires"

# 5. two conforming runtimes execute the exact same recipe with the same result
if [ "$runtime_runc" != "same-oci-recipe" ]; then
  echo "UNEXPECTED: runc did not execute the shared recipe (got '$runtime_runc')" >&2; exit 1
fi
if [ "$runtime_two" != "same-oci-recipe" ]; then
  echo "UNEXPECTED: $runtime2 did not execute the shared recipe (got '$runtime_two')" >&2; exit 1
fi
if [ "$runtime_runc" != "$runtime_two" ]; then
  echo "UNEXPECTED: runc and $runtime2 produced different output" >&2; exit 1
fi
echo "OK 5 - runc and $runtime2 execute the same OCI bundle with identical output ('$runtime_runc')"

echo
echo "ALL CHECKS PASSED"
