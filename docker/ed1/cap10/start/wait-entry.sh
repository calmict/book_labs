#!/bin/sh
set -eu

# The variables become active when TODO 5 is completed.
# shellcheck disable=SC2034
host=${WAIT_HOST:-127.0.0.1}
# shellcheck disable=SC2034
port=${WAIT_PORT:-18080}
# shellcheck disable=SC2034
delay=${DEPENDENCY_DELAY:-2}
# shellcheck disable=SC2034
timeout=${WAIT_TIMEOUT:-6}

# TODO 5 (10.4): start the delayed local listener, then poll host and port with
# nc -z until it answers. Stop with a clear error when timeout expires.

# TODO 6 (10.4): replace the script with the application and preserve all its
# arguments, so the application inherits the entrypoint process PID:
#   exec "$@"
