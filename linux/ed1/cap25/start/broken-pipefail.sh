#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
python3 "$script_dir/sigpipe-producer.py" | head -n 1 >/dev/null
printf 'This line is unreachable because the pipeline fails.\n'
