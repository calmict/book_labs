#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

printf 'Pipe capacity and backpressure:\n'
python3 "$script_dir/pipe-capacity.py"

count=0
printf '%s\n' one two three | while IFS= read -r line; do
    count=$((count + 1))
done
printf '\nCount after pipeline loop: %s\n' "$count"
if [[ $count -ne 0 ]]; then
    printf 'The pipeline loop unexpectedly changed the parent variable.\n' >&2
    exit 1
fi

count=0
# shellcheck disable=SC2034  # the loop counts lines, it does not read them
while IFS= read -r line; do
    count=$((count + 1))
done < <(printf '%s\n' one two three)
printf 'Count after process-substitution loop: %s\n' "$count"
if [[ $count -ne 3 ]]; then
    printf 'The corrected loop did not count all input lines.\n' >&2
    exit 1
fi

set +e
python3 "$script_dir/sigpipe-producer.py" | head -n 1 >/dev/null
pipeline_statuses=("${PIPESTATUS[@]}")
set -e
producer_status=${pipeline_statuses[0]}
consumer_status=${pipeline_statuses[1]}
pipeline_status=$producer_status
printf '\nProducer status: %s; consumer status: %s; pipefail status: %s\n' "$producer_status" "$consumer_status" "$pipeline_status"
if [[ $producer_status -ne 141 || $consumer_status -ne 0 || $pipeline_status -ne 141 ]]; then
    printf 'The expected SIGPIPE status was not observed.\n' >&2
    exit 1
fi

printf 'Status 141 is 128 plus SIGPIPE signal 13.\n'
printf 'All pipe checks passed; all producers and consumers have exited.\n'
