#!/bin/sh
# cap15 - entrypoint della soluzione 3 (15.3). Parte come root, sistema i
# permessi di cio' che trova sul mount condiviso, poi CEDE il posto all'utente
# non privilegiato con exec: da quel momento il processo non e' piu' root, e
# tutto cio' che scrive sul mount nasce con l'UID giusto. Su una base completa
# questo passaggio si scrive con gosu (Debian) o su-exec (Alpine); qui la base e'
# busybox e il gesto e' lo stesso: exec su, che sostituisce il processo invece di
# restargli sopra - il comando resta PID 1, come nel capitolo 10.
set -e
TARGET_UID="${TARGET_UID:?TARGET_UID non impostato}"

chown -R "$TARGET_UID" /data
adduser -D -u "$TARGET_UID" app 2>/dev/null || true

exec su app -c "$*"
