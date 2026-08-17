#!/usr/bin/env bash
set -euo pipefail

destination=${1:?usage: manual-report.sh DESTINATION}
report-helper > "$destination"
