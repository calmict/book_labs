# Capitolo 2 — Le sei stanze

**Livello:** Fondamentale

Nel capitolo 1 hai staccato un processo dall'elenco degli altri con un solo flag, e quel processo si è
ritrovato PID 1 di un mondo tutto suo. Ma quel flag era una porta su un'intera famiglia di isolamenti.
In questo laboratorio le apri quasi tutte insieme — hostname, processi, mount, rete, e la mappatura
degli utenti — e dimostri, stanza per stanza, che l'isolamento di un container non è una parete unica,
ma la somma di più viste che il kernel accetta di non far vedere.

## Obiettivi

- Costruire un processo isolato in più namespace contemporaneamente, senza Docker e senza sudo (2.1).
- Dimostrare ogni stanza con la sua prova: PID (PID 1), UTS (hostname), MNT (mount privato), NET (stack
  quasi muto), USER (root finto) (2.2-2.7).
- Usare l'inode in /proc/self/ns come metro: inode diverso = mondo separato (2.1).
- Vedere che togliere un flag toglie una sola stanza, non tutte (2.5).

## Prerequisiti

- Un Linux con unshare (util-linux), ip e mount: nessun Docker richiesto.
- Nessun root: usiamo il USER namespace (--user --map-root-user), che è a sua volta una delle sei
  stanze — quella che ci fa essere root dentro senza esserlo fuori. Il container a mani nude del
  capitolo 1 è il punto di partenza.

## Lo scenario

In start/ trovi lestanze.sh: uno script che dovrebbe costruire un processo isolato in più namespace, ma
apre solo il USER namespace e non isola altro. Colmi tre lacune (TODO 1..3) perché il figlio nasca in
un mondo separato su più fronti e registri la prova di ciascuno.

Prepara l'ambiente:

    cd docker/ed1/cap02/start

### Fase 1 — Che cos'è un namespace (2.1)

Un namespace partiziona la vista di una risorsa: non crea hardware nuovo, cambia solo ciò che un
processo percepisce. L'appartenenza di un processo a ciascun namespace è leggibile in
/proc/<pid>/ns come inode: due processi con lo stesso inode condividono quel mondo, con inode diverso
vivono in mondi separati. È il metro che useremo per ogni stanza.

### Fase 2 — Aprire le stanze (2.2-2.5 — TODO 1)

Apri start/lestanze.sh e completa il **TODO 1**: aggiungi al comando unshare i flag che aprono una
stanza ciascuno —

    unshare --user --map-root-user --uts --pid --fork --mount-proc --mount --net \
      bash -c '...' bash "$OUT"

Il flag --uts isola l'hostname; --pid --fork danno la numerazione dei processi con la shell come PID 1;
--mount-proc rimonta /proc; --mount dà una tabella di mount privata; --net dà uno stack di rete privato
e quasi muto (solo loopback).

### Fase 3 — La prova del mount privato (2.4 — TODO 2)

Dentro il figlio, completa il **TODO 2**: monta un tmpfs privato su /mnt e scrivici dentro un file
marker. Quel mount vive nel MNT namespace del processo: l'host non lo vedrà mai, e il test lo verifica.

    mount -t tmpfs tmpfs /mnt && echo mounted > /mnt/marker

### Fase 4 — Il metro dell'host (2.1 — TODO 3)

Completa infine il **TODO 3**: prima di costruire il processo isolato, registra gli inode dei namespace
dell'host (uts, pid, mnt, net). Saranno il termine di paragone: per ogni stanza, l'inode interno
diverso da quello dell'host è la prova che la stanza esiste.

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- lestanze.sh apre i namespace corretti (TODO 1) e crea il mount privato (TODO 2).
- host.txt registra gli inode dell'host (TODO 3).
- Dall'interno: PID 1, hostname sei-stanze, marker presente, rete con la sola loopback, uid 0.
- run.sh stampa OK 1..6 e ALL CHECKS PASSED, incluso il contrasto: senza --net il processo torna a
  condividere la rete dell'host.

## Come viene verificato

solution/run.sh costruisce il processo e verifica una stanza per controllo:

- **OK 1** — PID: dall'interno la shell è il processo numero 1.
- **OK 2** — UTS: hostname isolato (sei-stanze) e inode uts diverso dall'host.
- **OK 3** — MNT: il mount privato esiste dentro ed è invisibile all'host.
- **OK 4** — NET: stack di rete privato e quasi muto (inode diverso, solo loopback).
- **OK 5** — USER: root (uid 0) dentro, pur essendo un utente non privilegiato fuori.
- **OK 6** — il cancello morde: togliendo --net il processo condivide di nuovo la rete dell'host. La
  prova che l'isolamento è la somma delle singole stanze, non un interruttore unico.

## Domande di riflessione

**a.** Ogni namespace attacca una vista diversa. Descrivi, per ciascuna stanza che hai aperto, cosa
isola esattamente — e spiega perché l'inode in /proc/<pid>/ns è la prova che quel singolo mondo è
separato, mentre tutto il resto (il kernel per primo) resta condiviso.

**b.** Sei root dentro (uid 0) ma non hai usato sudo. Quale namespace lo rende possibile, e come? Perché
questo stesso meccanismo è alla base sia del rootless del capitolo 23 sia del problema dei "file scritti
come root" del capitolo 15?

**c.** Togliendo --net il processo torna a condividere la rete dell'host, ma mantiene PID, UTS e MNT
propri. Cosa ci dice questo sul fatto che l'isolamento di un container sia una cosa sola o la somma di
più viste indipendenti? A quale modalità di rete di Docker corrisponde "aprire cinque stanze e lasciarne
una condivisa"?

## Pulizia

Niente da smontare: il processo isolato termina da solo al termine dello script, il mount privato vive
solo nel suo MNT namespace e sparisce con lui, e il test lavora in una cartella temporanea che ripulisce
da sé. Nessun container Docker, nessuna risorsa lasciata sull'host.

## Dove porta

Hai aperto le stanze che decidono *cosa* un processo vede. Ma manca l'altra metà dell'isolamento: *quanto*
può consumare. Il **capitolo 3** apre la seconda scatola del kernel, i cgroup — il contatore e il
limitatore — e ti farà imporre a mano un tetto di memoria fino a vedere l'OOM killer intervenire dal
vivo.
