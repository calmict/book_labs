# Capitolo 13 — Ciò che resta a terra

**Livello:** Fondamentale

Un container è una nave: parte, fa il suo viaggio, e prima o poi viene demolita.
Tutto ciò che scrivi nella sua stiva — lo strato scrivibile che hai conosciuto nel
capitolo 8 — va giù con lei quando la rimuovi. È la sorpresa che coglie tutti la
prima volta: fai girare un database, lo popoli, rimuovi il container per aggiornarlo
e i dati non ci sono più. La Parte 4 risponde a questa domanda — se il container è
effimero, dove vivono i dati? — e la risposta è: a terra. In questo laboratorio vedi
con mano che lo strato del container muore con lui, e che un volume, custodito dal
demone a terra, sopravvive alla nave.

## Obiettivi

- Vedere che lo strato scrivibile del container è effimero: un container nuovo non
  vede i file scritti dal precedente (13.1, 13.2).
- Creare un volume con nome e scriverci dentro (13.3).
- Verificare che il volume sopravvive alla rimozione del container che l'ha scritto
  (13.3).
- Capire che il volume è un oggetto di prima classe, con un ciclo di vita proprio,
  indipendente da qualsiasi container (13.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter
  usare Docker.
- Il capitolo 8 (i layer): qui scopri che lo strato scrivibile in cima non è un
  posto dove tenere i dati.

## Lo scenario

In start/ trovi aterra.sh: uno script che dovrebbe mettere a confronto due destini —
un file scritto nello strato del container e uno scritto in un volume — ma la parte
del volume non è ancora fatta. Colmi tre lacune (TODO 1..3). Container usa-e-getta
(--rm) e un volume con nome unico, rimosso alla fine: il demone condiviso non si
tocca.

Prepara l'ambiente:

    cd docker/ed1/cap13/start

### Fase 1 — Lo strato del container è effimero (13.1, 13.2)

Lo script avvia un container, scrive un file nel suo filesystem e lo rimuove.
Poi un container nuovo, dalla stessa immagine, cerca quel file: non c'è. Lo strato
scrivibile è privato del container e viene buttato quando il container sparisce —
non è un posto dove tenere qualcosa che deve durare.

### Fase 2 — Creare un volume (13.3 — TODO 1)

Apri start/aterra.sh e completa il **TODO 1**: crea un volume con nome. È un'area
gestita dal demone, fuori dallo strato di qualsiasi container.

    docker volume create "$VOL" >/dev/null

### Fase 3 — Scrivere nel volume (13.3 — TODO 2)

Completa il **TODO 2**: avvia un container che monta il volume su /data e ci scrive
un file. Poi il container viene rimosso (--rm), ma il file è nel volume, non nello
strato del container.

    docker run --rm -v "$VOL:/data" busybox sh -c 'echo hi > /data/persisted.txt'

### Fase 4 — Rileggere dopo la rimozione (13.3 — TODO 3)

Completa il **TODO 3**: un container nuovo monta lo stesso volume e rilegge il file.
Se persiste, lo strato del container non c'entra: il dato vive nel volume.

    persisted=$(docker run --rm -v "$VOL:/data" busybox sh -c 'cat /data/persisted.txt 2>/dev/null || echo GONE')

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- aterra.sh crea il volume con nome (TODO 1).
- Scrive un file nel volume da un container usa-e-getta (TODO 2).
- Rilegge il file da un container nuovo che monta lo stesso volume (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — lo strato del container è effimero: il file scritto nel filesystem del
  container non è visibile a un container nuovo (risultato GONE).
- **OK 2** — il volume persiste: il file scritto nel volume viene riletto da un
  container nuovo, dopo che il primo è stato rimosso (risultato hi).
- **OK 3** — il volume ha un ciclo di vita proprio: esiste ancora, elencato dal
  demone, pur senza alcun container che lo usi.

## Domande di riflessione

**a.** Perché lo strato scrivibile in cima all'immagine (capitolo 8) non è il posto
dove tenere i dati? Cosa succede esattamente a quello strato quando fai docker rm,
e perché questo rende «effimero» tutto ciò che un container scrive fuori da un
volume?

**b.** Un volume è gestito dal demone e vive indipendentemente dai container: perché
questo permette di aggiornare l'immagine o ricreare il container senza perdere i
dati? E perché due container possono montare lo stesso volume, mentre non
condividono i rispettivi strati scrivibili?

**c.** Se il volume sopravvive alla rimozione del container, chi lo rimuove? Cosa
comporta questo per lo spazio su disco (i volumi «orfani») e per i dati sensibili
lasciati in un volume che nessuno cancella?

## Pulizia

Niente da smontare a mano: i container sono usa-e-getta (--rm) e il volume con nome
è rimosso dallo script (docker volume rm, più un trap di sicurezza) a fine
esecuzione. L'immagine base busybox resta in cache (condivisa). Il demone non viene
mai riavviato.

## Dove porta

Hai visto la differenza tra ciò che muore con il container e ciò che resta a terra.
Il **capitolo 14** entra nei modi concreti di tenere i dati a terra e di
condividerli con l'host: bind mount, volumes e tmpfs — quando usare l'uno o l'altro,
e cosa cambia tra un dato gestito dal demone e una cartella dell'host montata dentro.
Per il riferimento dei comandi, vedi le appendici del volume.
