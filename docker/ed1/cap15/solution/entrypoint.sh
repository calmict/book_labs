#!/bin/sh
set -eu
chown "$TARGET_UID:$TARGET_GID" /data
exec su-exec "$TARGET_UID:$TARGET_GID" "$@"
