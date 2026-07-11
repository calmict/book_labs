#!/usr/bin/env bash
# cap19 - the platform. Two containers:
#   - cap19-web1: the managed node reached as 'secops' (sudo with a password),
#     same shape as chapter 18;
#   - cap19-vault: a HashiCorp Vault dev server, the caveau that holds the
#     secret.
# nodes.sh also DEPOSITS the secret and prepares an AppRole machine identity.
# In real life someone populates the vault out of band; here the script does it
# for you, so the exercise is self-contained.
set -euo pipefail

NODE=cap19-web1
VAULT=cap19-vault
PORT=2372
LAB=/tmp/cap19-lab
IMAGE=debian:12
VAULT_IMAGE=hashicorp/vault
ROOT_TOKEN=lab-root-token

vault_exec() {
  docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" \
    "$VAULT" "$@"
}

up() {
  mkdir -p "$LAB"
  if [ ! -f "$LAB/key" ]; then
    ssh-keygen -t ed25519 -N '' -f "$LAB/key" -q
  fi
  local pub
  pub=$(cat "$LAB/key.pub")

  # --- managed node: secops, sudo WITH password ---
  docker rm -f "$NODE" >/dev/null 2>&1 || true
  docker run -d --name "$NODE" -p "$PORT:22" "$IMAGE" sleep infinity >/dev/null
  docker exec "$NODE" bash -c '
    set -e
    apt-get update -qq >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      openssh-server python3 sudo >/dev/null
    mkdir -p /run/sshd
    useradd -m -s /bin/bash secops
    echo "secops:secops-pw" | chpasswd
    echo "secops ALL=(ALL) ALL" > /etc/sudoers.d/secops
    chmod 440 /etc/sudoers.d/secops
    mkdir -p /home/secops/.ssh
    echo "'"$pub"'" > /home/secops/.ssh/authorized_keys
    chown -R secops:secops /home/secops/.ssh
    chmod 700 /home/secops/.ssh
    chmod 600 /home/secops/.ssh/authorized_keys
    /usr/sbin/sshd
  '

  # --- the caveau: HashiCorp Vault dev server ---
  docker rm -f "$VAULT" >/dev/null 2>&1 || true
  docker run -d --name "$VAULT" --cap-add=IPC_LOCK \
    -e VAULT_DEV_ROOT_TOKEN_ID="$ROOT_TOKEN" \
    -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
    -p 8200:8200 "$VAULT_IMAGE" >/dev/null

  # wait until the caveau answers
  for _ in $(seq 1 30); do
    if vault_exec vault status >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  # deposit the secrets (KV v2): the sudo password and an app credential
  vault_exec vault kv put secret/myapp \
    become_password=secops-pw db_password=app-db-pw >/dev/null

  # machine identity: an AppRole with a read-only policy on that one secret
  vault_exec vault auth enable approle >/dev/null 2>&1 || true
  printf 'path "secret/data/myapp" {\n  capabilities = ["read"]\n}\n' | \
    docker exec -i -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" \
    "$VAULT" vault policy write myapp-read - >/dev/null
  vault_exec vault write auth/approle/role/myapp token_policies=myapp-read >/dev/null
  vault_exec vault read -field=role_id auth/approle/role/myapp/role-id > "$LAB/role_id"
  vault_exec vault write -f -field=secret_id auth/approle/role/myapp/secret-id > "$LAB/secret_id"

  echo "$NODE up on port $PORT (user secops, sudo with password)"
  echo "$VAULT up on http://127.0.0.1:8200 (the caveau)"
  echo "reach the caveau with:"
  echo "    export VAULT_ADDR=http://127.0.0.1:8200"
  echo "    export VAULT_TOKEN=$ROOT_TOKEN"
  echo "AppRole identity written to $LAB/role_id and $LAB/secret_id"
}

down() {
  docker rm -f "$NODE" "$VAULT" >/dev/null 2>&1 || true
  rm -rf "$LAB"
  echo "$NODE and $VAULT down"
}

case "${1:-up}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 [up|down]" >&2; exit 2 ;;
esac
