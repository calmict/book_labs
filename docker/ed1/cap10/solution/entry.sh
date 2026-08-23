#!/bin/sh
# Stampa il proprio PID e gli argomenti ricevuti. In forma exec l'ENTRYPOINT
# rende questo script il processo di avvio, quindi self_pid vale 1; args mostra
# come ENTRYPOINT e CMD (o gli argomenti di docker run) si combinano.
echo "self_pid=$$"
echo "args=$*"

# Con l'argomento "serve" lo script resta vivo e installa un gestore di SIGTERM.
# Serve a cronometrare l'arresto e a vedere chi riceve davvero il segnale: se il
# processo di avvio e' questo script, il segnale arriva e l'uscita e' immediata.
if [ "${1:-}" = "serve" ]; then
  trap 'echo "sigterm=received"; exit 0' TERM
  while true; do sleep 1; done
fi
