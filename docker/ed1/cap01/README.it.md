# Capitolo 1 — Il container a mani nude

**Livello:** Fondamentale

Il viaggio comincia smontando la prima illusione: quella di aver acceso una piccola macchina. In questo
laboratorio costruisci un container **senza Docker**, con il solo comando unshare, e dimostri con i tuoi
occhi ciò che il capitolo annuncia — un container non è una nave a sé, è un normalissimo processo Linux
a cui il kernel ha raccontato una realtà ristretta. Prima di imbarcarti sul motore di Docker, tocca con
mano di cosa è fatta la stiva.

## Obiettivi

- Costruire un container a mani nude, senza Docker, con unshare (1.4).
- Dimostrare dall'interno di essere il processo numero 1 di un nuovo mondo (1.4).
- Isolare l'hostname con un UTS namespace, senza toccare quello dell'host (1.2, 1.4).
- Smascherare l'illusione dall'esterno: stesso kernel, namespace diverso (1.5).

## Prerequisiti

- Un Linux con il comando unshare (util-linux) e ps: nessun Docker richiesto per questo capitolo.
- Nessun privilegio di root: usiamo un USER namespace (--user --map-root-user) così l'esercizio gira
  senza sudo. È un anticipo del "root finto" del capitolo 2 e del rootless del capitolo 23.

## Lo scenario

In start/ trovi manibnude.sh: uno script che dovrebbe costruire un container a mani nude, ma è
volutamente incompleto. Così com'è apre solo un USER namespace e non isola nulla. Il tuo compito è
colmare tre lacune (TODO 1..3) perché il processo figlio nasca davvero in un mondo separato, e registri
la prova di esserlo.

Prepara l'ambiente:

    cd docker/ed1/cap01/start

### Fase 1 — Un processo mascherato (1.1)

Quando esegui docker run e vedi una shell che dice di essere in Ubuntu, la sensazione è di aver acceso
un computer nel computer. È falso: quel mondo condivide con la tua macchina lo stesso identico kernel.
Non c'è nessun secondo sistema operativo, nessun boot. C'è solo un processo a cui il kernel mostra una
versione ristretta della realtà. In questo laboratorio quel processo lo crei tu, a mano.

### Fase 2 — Le viste da isolare (1.4 — TODO 1)

Un container è un processo con una nuova istanza di alcuni "mondi" del kernel. Apri start/manibnude.sh e
completa il **TODO 1**: aggiungi al comando unshare i flag che creano l'isolamento —

    unshare --user --map-root-user --uts --pid --fork --mount-proc \
      bash -c '...' bash "$OUT"

Il flag --uts dà un hostname isolato; --pid --fork danno una nuova numerazione dei processi con la shell
come PID 1; --mount-proc rimonta /proc perché rifletta il nuovo PID namespace (altrimenti ps mostrerebbe
ancora i processi dell'host).

### Fase 3 — La prova dall'interno (1.4 — TODO 2)

Dentro il nuovo mondo, completa il **TODO 2**: cambia l'hostname in nave-cargo e registra la prova di
essere isolato — il tuo PID (che deve valere 1), il numero di processi visibili, e l'inode del tuo PID
namespace, letto da /proc/self/ns/pid.

### Fase 4 — Lo sguardo dall'host (1.5 — TODO 3)

Completa infine il **TODO 3**: prima di costruire il container, registra il punto di vista dell'host —
il suo hostname e l'inode del suo PID namespace. Sarà il metro di paragone: l'inode dell'host è diverso
da quello del container, la prova che i due vivono in mondi separati pur essendo lo stesso kernel.

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- manibnude.sh costruisce il container con i flag corretti (TODO 1).
- Dall'interno la shell è PID 1 e l'hostname è nave-cargo (TODO 2).
- Dall'host, l'hostname è intatto e l'inode del PID namespace è diverso da quello interno (TODO 3).
- run.sh stampa OK 1..4 e ALL CHECKS PASSED, incluso il controllo di contrasto: senza --pid il PID
  interno non è più 1.

## Come viene verificato

solution/run.sh costruisce il container a mani nude e verifica, punto per punto:

- **OK 1** — dall'interno la shell è il processo numero 1 del nuovo PID namespace.
- **OK 2** — l'hostname è isolato: nave-cargo dentro, l'host invariato fuori.
- **OK 3** — l'inode del PID namespace interno è diverso da quello dell'host: mondi separati.
- **OK 4** — il cancello morde: togliendo --pid non si crea alcun PID namespace, e il PID interno non è
  più 1. È la prova che l'isolamento dei processi è esattamente quel flag.

## Domande di riflessione

**a.** Dall'host, il container appena creato ha un PID normale e lo puoi terminare con un semplice kill.
Cosa ci dice questo sulla natura di un container? E cosa lo fa "sembrare" una macchina a sé, se non è
altro che un processo?

**b.** Dall'interno la shell è PID 1, dall'host ha un numero grande. Sono lo stesso processo o due
processi diversi? Spiega perché l'inode del PID namespace letto dall'interno coincide con quello che
l'host legge per quel PID, ma differisce dall'inode del namespace dell'host.

**c.** Togliendo il flag --pid, il PID interno non è più 1. Quale isolamento specifico hai perso? E cosa
ti dice questo sul fatto che l'isolamento di un container sia una cosa sola o la somma di più viste
indipendenti?

## Pulizia

Niente da smontare: il container a mani nude è un processo che termina da solo al termine dello script,
e il test lavora in una cartella temporanea che ripulisce da sé. Nessun container Docker, nessuna
risorsa lasciata sull'host.

## Dove porta

Hai costruito un container con un solo flag di isolamento e ne hai aperto uno soltanto per volta. Ma
--pid era la porta su un'intera famiglia di mondi. Il **capitolo 2** apre tutte le porte, una alla
volta: i namespace — PID, NET, MNT, UTS, IPC e il sorprendente USER, quello del "root finto" che qui hai
già usato senza saperlo per fare a meno di sudo.
