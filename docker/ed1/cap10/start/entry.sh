#!/bin/sh
# Stampa il proprio PID e gli argomenti ricevuti. In forma exec l'ENTRYPOINT
# rende questo script il processo di avvio, quindi self_pid vale 1; args mostra
# come ENTRYPOINT e CMD (o gli argomenti di docker run) si combinano.
echo "self_pid=$$"
echo "args=$*"
