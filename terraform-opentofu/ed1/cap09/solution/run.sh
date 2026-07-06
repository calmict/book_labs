#!/usr/bin/env bash
set -euo pipefail

# Chapter 9 solution — arguments, attributes and the blind eye, end to end:
#   1. the dossier: the plan declares the unknown ((known after apply) on
#      the content), the apply discovers real id and IP and writes them;
#   2. the night team: docker update changes the restart policy by hand,
#      and the plan wants to converge it back (chapters 1-2 at work);
#   3. the blind-eye contract: ignore_changes = [restart] makes the plan
#      say No changes — while reality KEEPS the hand-made policy.
#
# Needs a running Docker engine and free port 8093. Runs in a throwaway
# temp dir; guaranteed cleanup (destroy + rm) on exit.

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
  rm -rf "$WORK"
}
trap cleanup EXIT

cd "$WORK"
# The exercise's mid-state: dossier written (TODO 1), no lifecycle yet —
# the blind-eye contract arrives in phase 3, as in the reader's journey.
cat > main.tf <<'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "docker" {}

resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "cap09-web"
  image = docker_image.web.image_id

  ports {
    internal = 80
    external = 8093
  }
}

resource "local_file" "dossier" {
  filename        = "${path.module}/dossier.txt"
  content         = <<-EOT
    container id : ${docker_container.web.id}
    internal ip  : ${docker_container.web.network_data[0].ip_address}
  EOT
  file_permission = "0644"
}

output "container_id" {
  value = docker_container.web.id
}

output "container_ip" {
  value = docker_container.web.network_data[0].ip_address
}
EOF

echo "== 1. The dossier: the declared unknown, then the discovery =="
"$TF" init -input=false >/dev/null
"$TF" plan -input=false -no-color > plan.out
grep -E '^ +\+ content += +\(known after apply\)' plan.out | head -1 | sed 's/^ */  plan says: /'
echo "  (the unknown is born in the container and travels the edge to the dossier)"
"$TF" apply -input=false -auto-approve >/dev/null
grep -E '^container id : [0-9a-f]{64}$' dossier.txt >/dev/null
grep -E '^internal ip  : [0-9.]+$' dossier.txt >/dev/null
sed 's/^/  /' dossier.txt
echo "  (real values, discovered at birth and put to work)"
echo

echo "== 2. The night team: a legitimate hand change =="
docker update --restart unless-stopped cap09-web >/dev/null
"$TF" plan -input=false -no-color > drift.out
grep -E 'will be updated in-place' drift.out | head -1 | sed 's/^ */  plan says: /'
grep -E '~ restart' drift.out | head -1 | sed 's/^ */  the drift: /'
echo "  (chapters 1-2 at work: the plan wants to converge reality back)"
echo

echo "== 3. The blind-eye contract: ignore_changes =="
sed -i 's|  ports {|  lifecycle {\n    ignore_changes = [restart]\n  }\n\n  ports {|' main.tf
"$TF" plan -input=false -no-color | grep -E 'No changes' | sed 's/^/  plan now: /'
actual=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' cap09-web)
test "$actual" = "unless-stopped"
echo "  reality check: restart policy is still '${actual}'"
echo "  (the drift is not gone — it is tolerated by contract, on that knob only)"
echo

echo "=== arguments in, attributes out — and one knob the model deliberately stopped watching ==="
