#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scratch_dir="$script_dir/.labcap23-selinux"
document_dir="$scratch_dir/document"
secret_file="$document_dir/secret.txt"
runtime_file="$scratch_dir/server-runtime"
server_program="$scratch_dir/http_server.py"
port=${LABCAP23_PORT:-8008}
server_pid=
original_context=
permissive_added=0

cleanup() {
    if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    if [[ "$permissive_added" == 1 ]]; then
        semanage permissive -d httpd_t >/dev/null 2>&1 || true
    fi
    if [[ -d "$scratch_dir" && -n "$original_context" ]]; then
        chcon -R "$original_context" "$scratch_dir" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$scratch_dir"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

if [[ $(getenforce 2>/dev/null || true) != Enforcing ]]; then
    printf 'SKIP: SELinux is not Enforcing in this execution environment.\n' >&2
    exit 77
fi
if [[ $EUID -ne 0 ]]; then
    printf 'SKIP: the SELinux demonstration requires administrative privileges.\n' >&2
    exit 77
fi
for command_name in chcon curl getenforce python3 runcon semanage; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'SKIP: missing required command: %s\n' "$command_name" >&2
        exit 77
    fi
done
if semanage permissive -l | grep -Eq '^[[:space:]]*httpd_t[[:space:]]*$'; then
    printf 'SKIP: httpd_t is already permissive; the enforcing phase would be invalid.\n' >&2
    exit 77
fi
if ps -eZ 2>/dev/null | awk '$1 ~ /:httpd_t:/ { found=1 } END { exit !found }'; then
    printf 'SKIP: another httpd_t process is running; refusing to relax its domain.\n' >&2
    exit 77
fi

mkdir -p -- "$document_dir"
original_context=$(ls -Zd "$scratch_dir" | awk '{print $1}')
printf 'labcap23 protected content\n' > "$secret_file"
chmod 0644 "$secret_file"
cp --dereference -- "$(command -v python3)" "$runtime_file"
cp -- "$script_dir/http_server.py" "$server_program"
chmod 0755 "$runtime_file"

chcon -R -t httpd_sys_content_t "$scratch_dir"
chcon -t httpd_exec_t "$runtime_file"
chcon -t user_home_t "$secret_file"
mode_before=$(stat -c %a "$secret_file")

runcon -u system_u -r system_r -t httpd_t -- "$runtime_file" "$server_program" "$port" "$document_dir" >"$scratch_dir/server.log" 2>&1 &
server_pid=$!

for attempt in {1..30}; do
    if kill -0 "$server_pid" 2>/dev/null; then
        http_code=$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/" || true)
        [[ "$http_code" != 000 ]] && break
    else
        printf 'The lab HTTP process failed to start.\n' >&2
        cat "$scratch_dir/server.log" >&2
        exit 1
    fi
    sleep 0.1
done

printf 'Process context: '
ps -o label= -p "$server_pid"
printf 'Incorrect file label: '
ls -Z "$secret_file"
printf 'Mode before repair: %s; HTTP status: %s\n' "$mode_before" "$http_code"
[[ "$http_code" == 403 ]]

chcon -t httpd_sys_content_t "$secret_file"
mode_after=$(stat -c %a "$secret_file")
http_code=$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/")
printf 'Corrected file label: '
ls -Z "$secret_file"
printf 'Mode after repair: %s; HTTP status: %s\n' "$mode_after" "$http_code"
[[ "$mode_before" == "$mode_after" && "$http_code" == 200 ]]

chcon -t user_home_t "$secret_file"
semanage permissive -a httpd_t
permissive_added=1
http_code=$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/")
printf 'HTTP status with only httpd_t permissive: %s\n' "$http_code"
[[ "$http_code" == 200 ]]
if command -v ausearch >/dev/null 2>&1; then
    printf 'Recent AVC evidence, when available:\n'
    ausearch -m AVC -ts recent 2>/dev/null | tail -5 || true
fi
semanage permissive -d httpd_t
permissive_added=0
printf 'Type-specific permissive exception removed.\n'
