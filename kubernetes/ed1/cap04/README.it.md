# Cap. 4 — Smonta un'immagine a mano (anatomia di un container)

> Esercizio del **Capitolo 4 — Anatomia di un container** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- aprire un'immagine OCI e riconoscerne i tre ingredienti: manifest, config e layer (che sono semplici tarball di filesystem);
- montare un OverlayFS a mano e osservare il copy-on-write: dove finiscono le modifiche, come muore un file (whiteout), perché il layer di un container è usa-e-getta;
- dimostrare che root nel container non è root sull'host (capabilities) e che il kernel è uno solo, condiviso.

## Prerequisiti

- Aver completato i cap. 1-3 (processo, namespaces, cgroups: qui si aggiunge l'ultimo pezzo, il filesystem).
- Docker o Podman funzionanti, privilegi sudo per il mount del passo 4.
- Circa 30 MB di spazio disco.

## Consegna

1. Procurati un'immagine e mettila a nudo con docker save (che esporta il formato che viaggia tra i registry):

       mkdir -p ~/lab-cap04 && cd ~/lab-cap04
       docker pull alpine:3
       docker save alpine:3 -o alpine.tar
       mkdir image && tar -xf alpine.tar -C image
       find image -type f

   Niente magia dentro: qualche JSON e uno o più blob. Annota i nomi.

2. Leggi il manifest e segui la catena: quale blob è la config e quale il layer?

       cat image/manifest.json

   Apri anche la config (il JSON grosso): riconosci Env, Cmd e la sezione rootfs con i diff_ids. Annota il percorso del layer.

3. Il layer è solo un tarball di filesystem: estrailo e guardaci dentro.

       mkdir layer && tar -xf image/<PERCORSO-DEL-LAYER> -C layer
       ls layer

   (con le versioni vecchie di docker save il layer si chiama layer.tar dentro una sottocartella: il concetto non cambia)
   Ti ritrovi bin, etc, usr... un intero filesystem radice. Questo — più i JSON del passo 2 — È l'immagine.

4. Ora monta un OverlayFS usando il layer appena estratto come piano di sotto, e osserva il copy-on-write:

       mkdir upper work merged
       sudo mount -t overlay overlay -o lowerdir=layer,upperdir=upper,workdir=work merged
       ls merged
       echo "modificato dal container" | sudo tee merged/etc/motd
       sudo rm merged/etc/hostname
       ls -l upper/etc/
       cat layer/etc/motd; ls layer/etc/hostname

   Osserva: la modifica sta SOLO in upper (il "container layer"), il file cancellato è diventato in upper un character device speciale (il whiteout), e il layer di sotto è rimasto intatto. È così che cento container condividono la stessa immagine senza pestarsi i piedi.

> 💡 **Niente sudo?** Su kernel recenti puoi montare l'overlay dentro uno user
> namespace: unshare -Urm ti dà una shell da "root finto" (cap. 2!) in cui il
> comando mount del passo 4 funziona senza sudo. Il mount sparisce da solo
> quando esci dalla shell.

5. Root nel container non è root sull'host. Confronta le capabilities effettive e prova un'azione da vero root:

       docker run --rm alpine:3 grep CapEff /proc/self/status
       grep CapEff /proc/1/status
       docker run --rm alpine:3 date -s "2000-01-01"

   Le due maschere sono diverse (quella del container ha molti meno bit), e il date -s fallisce: manca CAP_SYS_TIME, anche se dentro sei "root".

6. L'ultima illusione da sfatare: il kernel è uno solo.

       uname -r
       docker run --rm alpine:3 uname -r

   Identici. Rispondi per iscritto nel file answers.md che consegnerai: cosa contiene davvero un'immagine OCI (segui la catena manifest → config → layer)? Dove sono finite la modifica e la cancellazione del passo 4, e perché questo rende i container usa-e-getta? Perché "root" nel container non può cambiare l'ora di sistema, e cosa c'entra il fatto che uname -r sia identico dentro e fuori?

7. Smonta il laboratorio:

       sudo umount merged
       cd ~ && rm -rf ~/lab-cap04

## Criteri di "fatto"

- [ ] Hai individuato nel manifest il percorso della config e quello del layer, e dentro il layer estratto c'è un filesystem radice completo.
- [ ] La modifica del passo 4 esiste solo in upper, la cancellazione ha prodotto un whiteout, e il layer originale è rimasto intatto.
- [ ] Hai le due maschere CapEff (diverse) e il fallimento di date -s nel container.
- [ ] uname -r dentro e fuori coincidono, e answers.md risponde alle tre domande.
- [ ] Overlay smontato e cartella di laboratorio rimossa.
