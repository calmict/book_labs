# Capitolo 6 — La ricetta OCI

**Livello:** Intermedio

Nel capitolo 5 hai visto una catena fatta di anelli distinti. Ma perché tanta frammentazione? La risposta
è una parola: standard. In questo laboratorio scendi all'ultimo anello e costruisci ed esegui un container
OCI a mani nude con runc — senza Docker nel ciclo. Genererai il config.json, la ricetta esatta in cui
tutta la Parte 1 si condensa, e vedrai che runc non fa altro che eseguirla alla lettera. Cambierai la
ricetta e il container cambierà: perché il config.json è il container.

## Obiettivi

- Costruire un bundle OCI a mani nude ed eseguirlo con runc, senza Docker nel ciclo (6.3).
- Leggere nel config.json i meccanismi della Parte 1 elencati come dati (namespace) (6.3).
- Dimostrare che runc è un esecutore fedele: cambiando la ricetta cambia il container (6.3).
- Capire perché lo standard OCI rende i pezzi intercambiabili (6.4).

## Prerequisiti

- Un Linux con runc (parte di Docker Engine) e python3. Docker serve solo a costruire il rootfs minimale
  (esportando busybox): da lì in poi runc lavora da solo, senza Docker.
- Nessun root: usiamo uno spec --rootless (USER namespace e mappatura degli UID), quindi niente sudo.
- La Parte 1 come contesto: qui la ritrovi scritta come ricetta.

## Lo scenario

In start/ trovi laricetta.sh: uno script che dovrebbe generare la ricetta OCI ed eseguirla, ma non genera
nulla e non esegue nulla. Colmi tre lacune (TODO 1..3) perché la ricetta esista, runc la esegua, e una
sua modifica si rifletta nel container.

Prepara l'ambiente:

    cd docker/ed1/cap06/start

### Fase 1 — Il problema che gli standard risolvono (6.1)

Agli inizi, ogni strumento aveva il suo formato e il suo modo di eseguire: un'immagine costruita per uno
non girava sull'altro. Era il rischio del lock-in. L'Open Container Initiative scrisse regole comuni —
non un programma, delle specifiche — e da lì i pezzi diventarono intercambiabili.

### Fase 2 — Generare la ricetta (6.3 — TODO 1)

Lo script prepara un rootfs minimale da busybox. Apri start/laricetta.sh e completa il **TODO 1**: genera
la ricetta runtime-spec, rootless, e registra i namespace che elenca —

    runc spec --rootless
    python3 -c "import json;print('namespaces='+','.join(n['type'] for n in json.load(open('config.json'))['linux']['namespaces']))" > "$OUT/oci.txt"

Uno spec --rootless aggiunge un USER namespace e una mappatura degli UID, così runc gira senza sudo.

### Fase 3 — Modificare la ricetta (6.3 — TODO 2)

Dentro la funzione run_recipe, completa il **TODO 2**: modifica la ricetta — imposta il comando (echo del
parametro) e spegni il terminale, così l'output è catturato su stdout.

    python3 - "$1" <<'PY'
    import json, sys
    c = json.load(open('config.json'))
    c['process']['args'] = ['/bin/echo', sys.argv[1]]
    c['process']['terminal'] = False
    json.dump(c, open('config.json', 'w'))
    PY

### Fase 4 — Eseguire con runc (6.3 — TODO 3)

Completa il **TODO 3**: esegui il bundle con runc, che legge il config.json e lo esegue.

    runc --root "$BUNDLE/state" run "oci-$1"

Lo script esegue la ricetta due volte con parole diverse: se runc è fedele, l'output segue la ricetta.

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- laricetta.sh genera la ricetta e registra i namespace (TODO 1).
- run_recipe modifica il config.json (comando + terminale) (TODO 2) ed esegue con runc (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED: la ricetta elenca i namespace della Parte 1, runc la esegue,
  e cambiando la ricetta cambia l'output.

## Come viene verificato

solution/run.sh costruisce ed esegue il bundle OCI e verifica, punto per punto:

- **OK 1** — la ricetta config.json elenca i namespace della Parte 1 come dati (pid, mount, user, …).
- **OK 2** — runc esegue la ricetta: il container stampa la parola indicata.
- **OK 3** — cambiando la ricetta il container segue: il config.json è il container.

## Domande di riflessione

**a.** Un container su disco è una cartella rootfs più un file config.json. Guardando il config.json,
quali meccanismi della Parte 1 ritrovi elencati come dati? Cosa fa quindi runc, esattamente, e perché
questo significa che «sotto il cofano» non c'è nulla di nuovo?

**b.** Hai cambiato gli args nel config.json e il container ha stampato la parola nuova: il config.json è
il container. Perché questo è il senso stesso dello standard runtime-spec? E perché ti permette di
sostituire runc con crun, o di eseguire lo stesso bundle sotto Docker, Podman o Kubernetes?

**c.** L'intercambiabilità dei pezzi è la tua polizza contro il lock-in. In che modo? E perché è anche il
ponte verso il Manuale di Kubernetes — cosa orchestra Kubernetes, e attraverso quale anello della catena
del capitolo 5?

## Pulizia

Niente da smontare: ogni runc run termina con il processo del container e lo stato vive in una cartella
temporanea che il test ripulisce; il rootfs è costruito e cancellato nella stessa cartella effimera.
Nessun container Docker persistente, nessuna risorsa lasciata sull'host.

## Dove porta

Hai capito perché la catena del capitolo 5 è fatta di pezzi separati: perché ogni giunzione è uno standard
pubblico. Il **capitolo 7** chiude la Parte 2 seguendo un container lungo tutta la sua vita — gli stati,
i segnali POSIX, le responsabilità di PID 1 — e ripaga il debito del PID 1 «a mani nude» del capitolo 1.
