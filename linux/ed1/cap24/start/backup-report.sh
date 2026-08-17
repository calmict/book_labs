#!/usr/bin/env bash
set -euo pipefail

destination=${1:?usage: backup-report.sh DESTINATION}
report-helper > "$destination"
