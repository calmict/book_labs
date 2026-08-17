# Cap. 30 — Costruire un'illusione

> Esercizio del **Capitolo 30 — Namespaces: le illusioni del kernel** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Avanzato

## Obiettivi

Al termine di questo laboratorio saprai:

- creare insieme namespace user, PID, rete, UTS e mount senza privilegi amministrativi;
- confrontare PID, hostname e rete osservati dall'host con quelli visibili nella shell isolata;
- entrare dall'esterno nei namespace di un processo con nsenter;
- interpretare la mappatura che rende un utente root nel namespace senza renderlo root sull'host.

## Prerequisiti

- Un host Linux con Bash, util-linux e procps.
- La creazione di namespace utente non privilegiati deve essere abilitata.
- Nessun accesso sudo è richiesto o deve essere usato.

## Consegna

1. Copia la directory start in una directory di lavoro e completa observations.md.
2. Avvia una shell isolata usando obbligatoriamente questi namespace nello stesso comando:

       unshare --user --map-root-user --pid --net --uts --mount --propagation private --fork /bin/sh

3. Nella shell imposta l'hostname a labcap30-shell. Registra PID, UID, hostname, collegamento del namespace di rete e contenuto di /proc/self/uid_map.
4. Monta una nuova vista proc nella shell, poi dall'host individua il PID reale della shell. Confronta PID, UID, hostname e namespace di rete con i valori interni. Verifica inoltre che la rete isolata mostri soltanto l'interfaccia di loopback.
5. Dall'host usa nsenter sul PID della shell ed entra nei suoi namespace user, mount, UTS, rete e PID. Esegui una nuova shell che mostri PID, UID, hostname e namespace di rete.
6. Spiega in observations.md perché UID 0 dentro il namespace corrisponde al tuo UID ordinario sull'host e perché il nuovo processo avviato con nsenter non vede i processi dell'host.
7. Termina la shell isolata e verifica che non rimangano processi o risorse del laboratorio.

La directory solution contiene una soluzione eseguibile e cronometrata:

    ./solution/run.sh

## Criteri di "fatto"

- [ ] La shell usa contemporaneamente namespace user, PID, rete, UTS e mount con propagazione privata.
- [ ] PID, hostname e namespace di rete interni sono diversi da quelli osservati sull'host.
- [ ] nsenter avvia dall'esterno un processo che osserva la stessa vista isolata.
- [ ] /proc/self/uid_map dimostra che root interno è mappato all'UID non privilegiato dell'host.
- [ ] La rete isolata contiene soltanto loopback e la shell non vede i processi dell'host.
- [ ] Tutti i processi e le risorse temporanee sono stati rimossi.
