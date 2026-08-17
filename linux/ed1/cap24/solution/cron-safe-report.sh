#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
destination=${1:?usage: cron-safe-report.sh DESTINATION}
"$script_dir/report-helper" > "$destination"
