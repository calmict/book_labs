#!/usr/bin/env bash
set -euo pipefail

# Chapter 17 solution — modules, end to end:
#   1. one prefab, installed: tofu init pulls in the local module;
#   2. two isolated instances from one box: for_each over the apps map, the
#      state addresses carry the module.webapp["..."] namespace;
#   3. the output doors, aggregated: tofu output urls maps each app to its url,
#      and both containers answer on their own port;
#   4. reuse and isolation: remove one app from the map and only that
#      instance is destroyed (chapter 15's for_each, over a whole module);
#   5. provider inheritance: the module has no provider block — apply proves
#      it inherited the root's docker provider.
#
# Needs a running Docker engine and free ports 8101, 8102. Runs in a
# throwaway temp dir; guaranteed cleanup (destroy + rm) on exit.

DIR=$(cd "$(dirname "$0")" && pwd)

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform found (see SETUP.md)" >&2
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found" >&2; exit 1; }

WORK=$(mktemp -d)
cleanup() {
  (cd "$WORK" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  docker rm -f cap17-blog-dev cap17-shop-prod >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cp "$DIR/main.tf" "$WORK/"
cp -r "$DIR/modules" "$WORK/"
cd "$WORK"

echo "== 1. One prefab, installed =="
"$TF" init -input=false | grep -E 'webapp in modules/webapp' | sed 's/^ *- /  init: /'
# The module declares no provider CONFIG block — proof it is provider-agnostic.
# Anchor at line start so a comment mentioning it does not count.
grep -qE '^[[:space:]]*provider "docker"' modules/webapp/main.tf && { echo "unexpected: module has a provider block" >&2; exit 1; }
echo "  (the module has no provider block — it inherits the root's)"
echo

echo "== 2. Two isolated instances from one box =="
"$TF" apply -input=false -auto-approve >/dev/null
"$TF" state list | grep -E '^module.webapp\[' | sed 's/^/  /'
echo

echo "== 3. The output doors, aggregated =="
"$TF" output -json urls | tr ',' '\n' | grep -oE '"(blog|shop)": ?"[^"]+"' | sed 's/^/  url: /'
for p in 8101 8102; do
  ok=""
  for _ in $(seq 1 15); do
    if curl -sf "http://localhost:${p}" 2>/dev/null | grep -q 'Welcome to nginx'; then ok=1; break; fi
    sleep 1
  done
  test -n "$ok"
  echo "  port ${p}: answers (Welcome to nginx)"
done
echo

echo "== 4. Reuse and isolation: remove shop, only shop goes =="
"$TF" plan -input=false -no-color -refresh=false \
  -var 'apps={ blog = { environment = "dev", external_port = 8101 } }' >reuse.out
# Look only at ACTION lines (destroyed/created/updated/replaced), not the
# refresh log or the output diff — both mention "blog" harmlessly.
grep -E 'will be (created|destroyed|updated)|must be replaced' reuse.out >acts.out
grep -E 'module.webapp\["shop"\].docker_container.this will be destroyed' acts.out | sed 's/^ *# /  /'
grep -qE 'module.webapp\["blog"\]' acts.out && { echo "unexpected: blog has an action in the plan" >&2; exit 1; }
grep -E '^Plan:' reuse.out | sed 's/^/  /'
echo "  (blog is not touched: each module instance has its own identity)"
echo

echo "=== one box, many isolated instances; variables in, outputs out, provider inherited ==="
