#!/bin/sh
# App di esempio: stampa un saluto letto dalla variabile d'ambiente GREETING,
# impostata nell'immagine con ENV. Serve a dimostrare COPY (il file finisce
# nell'immagine), ENV (il valore) e CMD (parte come comando di default).
echo "$GREETING mondo"
