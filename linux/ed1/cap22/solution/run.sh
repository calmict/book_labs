#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scratch_dir="$script_dir/.labcap22-scratch"

cleanup() {
    rm -rf -- "$scratch_dir"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

for command_name in setfacl getfacl getent; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Missing command: %s\n' "$command_name" >&2
        printf 'Install the acl package and try again.\n' >&2
        exit 1
    fi
done

writing_group=${WRITING_GROUP:-$(id -gn)}
reading_group=${READING_GROUP:-$(getent group | awk -F: -v current="$writing_group" '$1 != current { print $1; exit }')}
single_group_mode=${LABCAP22_SINGLE_GROUP_MODE:-0}

if ! getent group "$writing_group" >/dev/null; then
    printf 'The writing group does not exist.\n' >&2
    exit 1
fi
if [[ "$single_group_mode" != 1 ]] && { [[ -z "$reading_group" ]] || ! getent group "$reading_group" >/dev/null || [[ "$reading_group" == "$writing_group" ]]; }; then
    printf 'Two existing groups are required.\n' >&2
    exit 1
fi

mkdir -p -- "$scratch_dir/project" "$scratch_dir/copies"
chmod 700 "$scratch_dir/project"

if [[ "$single_group_mode" == 1 ]]; then
    setfacl -m "u::rwx,g::---,g:${writing_group}:rwx,m::rwx,o::---" "$scratch_dir/project"
    setfacl -m "d:u::rwx,d:g::---,d:g:${writing_group}:rwx,d:m::rwx,d:o::---" "$scratch_dir/project"
    printf 'Limited test mode: this user namespace maps only one group ID.\n'
    printf 'The distinct read-only group is not tested in this mode.\n'
else
    setfacl -m "u::rwx,g::---,g:${writing_group}:rwx,g:${reading_group}:r-x,m::rwx,o::---" "$scratch_dir/project"
    setfacl -m "d:u::rwx,d:g::---,d:g:${writing_group}:rwx,d:g:${reading_group}:r-x,d:m::rwx,d:o::---" "$scratch_dir/project"
fi

printf 'Writing group: %s; reading group: %s\n' "$writing_group" "$reading_group"
printf '\nDirectory ACL with defaults:\n'
getfacl -cp "$scratch_dir/project"

touch "$scratch_dir/project/plan.txt"
mkdir "$scratch_dir/project/docs"

printf '\nInherited file ACL:\n'
getfacl -cp "$scratch_dir/project/plan.txt"
printf '\nInherited subdirectory ACL:\n'
getfacl -cp "$scratch_dir/project/docs"

if ! getfacl -cp "$scratch_dir/project/plan.txt" | grep -E "^group:${writing_group}:rwx([[:space:]]|$)" >/dev/null; then
    printf 'The writing-group ACL was not inherited.\n' >&2
    exit 1
fi
if [[ "$single_group_mode" != 1 ]] && ! getfacl -cp "$scratch_dir/project/docs" | grep -Fx "default:group:${reading_group}:r-x" >/dev/null; then
    printf 'The default reading-group ACL was not inherited by the subdirectory.\n' >&2
    exit 1
fi

chmod 640 "$scratch_dir/project/plan.txt"
printf '\nAfter chmod 640, the mask limits named entries:\n'
getfacl -cp "$scratch_dir/project/plan.txt"

if ! getfacl -cp "$scratch_dir/project/plan.txt" | grep -Fx 'mask::r--' >/dev/null; then
    printf 'chmod did not produce the expected ACL mask.\n' >&2
    exit 1
fi

setfacl -m m::rwx "$scratch_dir/project/plan.txt"
printf '\nAfter restoring the mask:\n'
getfacl -cp "$scratch_dir/project/plan.txt"

printf 'project plan\n' > "$scratch_dir/project/plan.txt"
cp -a "$scratch_dir/project/plan.txt" "$scratch_dir/copies/archive-copy.txt"
cp --no-preserve=mode "$scratch_dir/project/plan.txt" "$scratch_dir/copies/unpreserved-copy.txt"
cat "$scratch_dir/project/plan.txt" > "$scratch_dir/copies/redirected-copy.txt"

printf '\nCopy comparison:\n'
for file_name in "$scratch_dir/project/plan.txt" "$scratch_dir/copies/archive-copy.txt" "$scratch_dir/copies/unpreserved-copy.txt" "$scratch_dir/copies/redirected-copy.txt"; do
    printf '%s\n' "$(basename -- "$file_name")"
    getfacl -cp "$file_name"
done

if ! getfacl -cp "$scratch_dir/copies/archive-copy.txt" | grep -F "group:${writing_group}:" >/dev/null; then
    printf 'cp -a did not preserve the named ACL.\n' >&2
    exit 1
fi
for file_name in "$scratch_dir/copies/unpreserved-copy.txt" "$scratch_dir/copies/redirected-copy.txt"; do
    if getfacl -cp "$file_name" | grep -F "group:${writing_group}:" >/dev/null; then
        printf 'A byte-only copy unexpectedly retained the named ACL: %s\n' "$file_name" >&2
        exit 1
    fi
done

printf '\nAll ACL checks passed. Cleanup runs on exit.\n'
