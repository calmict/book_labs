#!/usr/bin/env bash
set -euo pipefail

# These variables are consumed by run.sh after sourcing this file.
# shellcheck disable=SC2034
COUNT_QUERY='count(up==1)'
# shellcheck disable=SC2034
GAUGE_QUERY='node_memory_MemAvailable_bytes'
# shellcheck disable=SC2034
RATE_QUERY='sum(rate(prometheus_http_requests_total[1m]))'
