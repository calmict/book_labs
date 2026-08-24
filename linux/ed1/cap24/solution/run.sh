#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scratch_dir="$script_dir/.labcap24-scratch"

cleanup() {
    rm -rf -- "$scratch_dir"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

mkdir -p -- "$scratch_dir/files"
printf 'first log\n' > "$scratch_dir/files/one.log"
printf 'second log\n' > "$scratch_dir/files/two.log"
printf 'quarterly result\n' > "$scratch_dir/files/quarterly report.txt"

printf 'Quoted values stay single arguments:\n'
message='two words'
"$script_dir/print-args.sh" one "$message" '*.log'

printf '\nUnquoted wildcard expands before execution:\n'
(
    cd "$scratch_dir/files"
    # shellcheck disable=SC2035  # the bare glob is the subject of the exercise
    "$script_dir/print-args.sh" *.log
)

printf '\nQuoted wildcard remains literal:\n'
(
    cd "$scratch_dir/files"
    "$script_dir/print-args.sh" '*.log'
)

file_name='quarterly report.txt'
set +e
unquoted_error=$(
    cd "$scratch_dir/files"
    # shellcheck disable=SC2086  # the unquoted expansion is the subject of the exercise
    cat $file_name 2>&1
)
unquoted_status=$?
set -e
printf '\nUnquoted file name status: %s\n%s\n' "$unquoted_status" "$unquoted_error"
if [[ $unquoted_status -eq 0 ]] || [[ "$unquoted_error" != *quarterly* ]] || [[ "$unquoted_error" != *report.txt* ]]; then
    printf 'The unquoted expansion did not reproduce the expected split.\n' >&2
    exit 1
fi

printf '\nQuoted file name content:\n'
quoted_content=$(cd "$scratch_dir/files" && cat "$file_name")
printf '%s\n' "$quoted_content"
[[ "$quoted_content" == 'quarterly result' ]]

printf '\nManual environment with helper on PATH:\n'
PATH="$script_dir:$PATH" "$script_dir/manual-report.sh" "$scratch_dir/manual-report.txt"
cat "$scratch_dir/manual-report.txt"

set +e
minimal_error=$(cd / && env -i PATH=/usr/bin:/bin "$script_dir/manual-report.sh" "$scratch_dir/minimal-report.txt" 2>&1)
minimal_status=$?
set -e
printf '\nMinimal environment, original script status: %s\n%s\n' "$minimal_status" "$minimal_error"
if [[ $minimal_status -eq 0 ]] || [[ "$minimal_error" != *report-helper* ]]; then
    printf 'The original script did not expose its PATH dependency.\n' >&2
    exit 1
fi

printf '\nMinimal environment, corrected script:\n'
(cd / && env -i PATH=/usr/bin:/bin "$script_dir/cron-safe-report.sh" "$scratch_dir/safe-report.txt")
cat "$scratch_dir/safe-report.txt"
grep -F 'report generated at ' "$scratch_dir/safe-report.txt" >/dev/null

printf '\nAll shell expansion and minimal-environment checks passed. Cleanup runs on exit.\n'
