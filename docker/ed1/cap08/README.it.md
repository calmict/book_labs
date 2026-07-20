# Capitolo 8 — La lista di carico

**Livello:** Intermedio

Chiusa l'architettura del motore, comincia l'artigianato: le immagini. E la prima
sorpresa è che un'immagine non è un blocco monolitico ma una **pila di strati**
più una **lista di carico** che li elenca — proprio come una nave non è un guscio
pieno alla rinfusa, ma container impilati e un manifesto che dice cosa c'è e in
che ordine. In questo laboratorio dissezioni un'immagine a mani nude: ne conti i
layer, ne leggi il digest sha256 che la sigilla, e dimostri perché due immagini
diverse condividono gli stessi strati senza copiarli.

## Obiettivi

- Vedere che un'immagine è una config più uno stack di layer, e che ogni
  istruzione che tocca il filesystem aggiunge un layer (8.1, 8.2).
- Leggere l'image ID come **digest sha256 della config**: l'immagine è
  identificata dal suo contenuto, quindi immutabile e verificabile (8.3).
- Riconoscere i layer come diff **content-addressed** (ognuno un digest) (8.2).
- Dimostrare lo **sharing**: un'immagine costruita sopra un'altra riusa gli stessi
  layer, senza duplicarli — la base della cache e del pull per digest (8.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter
  usare Docker.
- La Parte 2 come contesto: sai chi esegue un container e secondo quali regole;
  qui vedi da dove nasce il rootfs che runc monta.

## Lo scenario

In start/ trovi lanatomia.sh: uno script che costruisce una piccola immagine
(busybox più due istruzioni che scrivono un file) e dovrebbe registrarne
l'anatomia, ma le tre misure chiave non sono ancora prese. Colmi tre lacune
(TODO 1..3) usando immagini usa-e-getta, senza mai toccare il demone condiviso.

Prepara l'ambiente:

    cd docker/ed1/cap08/start

### Fase 1 — Un'immagine è una pila di strati (8.1, 8.2)

Lo script costruisce l'immagine con un Dockerfile minimale: da busybox, due
istruzioni RUN che scrivono un file ciascuna. Ogni istruzione che cambia il
filesystem produce un nuovo layer sopra i precedenti. La base busybox è un solo
strato: l'immagine finale ne avrà uno per lo strato base più due per le due RUN.

### Fase 2 — Contare gli strati (8.2 — TODO 1)

Apri start/lanatomia.sh e completa il **TODO 1**: registra il numero di layer
dell'immagine e della base, leggendoli dalla config con docker image inspect
(il campo rootfs.diff_ids è esposto come .RootFS.Layers) —

    layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG")
    base_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$BASE")

### Fase 3 — Il digest che sigilla (8.3 — TODO 2)

Completa il **TODO 2**: registra l'image ID (il digest sha256 della config) e il
digest del layer in cima. Sono entrambi indirizzi di contenuto: cambia un byte e
cambia il digest.

    image_id=$(docker image inspect -f '{{.Id}}' "$TAG")
    top_layer=$(docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | tail -1)

### Fase 4 — Lo sharing degli strati (8.4 — TODO 3)

Completa il **TODO 3**: costruisci una seconda immagine a partire dalla prima
(una RUN in più), poi conta quanti layer della prima ricompaiono identici nella
seconda. Il content-addressing fa sì che gli strati condivisi non vengano
duplicati.

    docker build -q -t "$TAG-child" - >/dev/null <<EOF
    FROM $TAG
    RUN echo three > /three.txt
    EOF
    child_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG-child")
    docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | sort > "$OUT/.p"
    docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG-child" | grep '^sha256' | sort > "$OUT/.c"
    shared=$(comm -12 "$OUT/.p" "$OUT/.c" | grep -c .)

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- lanatomia.sh registra numero di layer dell'immagine e della base (TODO 1).
- Registra l'image ID e il digest del layer in cima (TODO 2).
- Costruisce l'immagine figlia e conta i layer condivisi (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh costruisce le immagini e verifica, punto per punto:

- **OK 1** — l'immagine ha uno strato per la base più uno per ciascuna delle due
  RUN: layer = base_layers + 2.
- **OK 2** — l'image ID è un digest sha256 (della config) e il layer in cima è a
  sua volta un digest sha256: l'immagine è content-addressed.
- **OK 3** — l'immagine figlia ha esattamente un layer in più della prima e ne
  riusa tutti gli strati (shared = layer della prima): gli strati sono condivisi,
  non copiati.

## Domande di riflessione

**a.** Perché ogni istruzione che cambia il filesystem crea un nuovo layer, e in
che senso un layer è un «diff»? Collega la risposta alla cache di build: perché
cambiare un'istruzione invalida quel layer e tutti quelli sopra, ma non quelli
sotto?

**b.** L'image ID è il digest sha256 della config, e la config elenca i digest
degli strati (rootfs.diff_ids) più la history e i metadati (env, entrypoint).
Perché questo rende l'immagine immutabile e verificabile, e perché «taggare»
un'immagine non la cambia?

**c.** L'immagine figlia riusa tutti gli strati della prima. Perché il
content-addressing permette di condividere i layer su disco e in rete (pull e
push scaricano solo i digest mancanti)? E come si lega questo alla cache
strategica del capitolo 11?

## Pulizia

Niente da smontare a mano: le due immagini di prova sono rimosse dallo script
(docker rmi, più un trap di sicurezza) a fine esecuzione; il test lavora in una
cartella temporanea che ripulisce da sé. L'immagine base busybox resta in cache
(è condivisa, e serve ai capitoli successivi). Nessun container avviato, il
demone non viene mai riavviato.

## Dove porta

Hai smontato un'immagine nei suoi pezzi: config, digest, stack di layer. Il
**capitolo 9** fa il percorso inverso e te la fa **costruire** con intenzione —
le istruzioni fondamentali del Dockerfile, e come ognuna diventa uno degli strati
che qui hai contato. Per il riferimento rapido su Dockerfile e comandi, vedi le
appendici del volume.
