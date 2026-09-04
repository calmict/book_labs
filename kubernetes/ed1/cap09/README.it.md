# Capitolo 9 — Bussa alle quattro porte: l'API server a mani nude

**Livello:** Fondamentale

Etcd custodisce la verità, ma solo l'API server può toccarla. Qui usi curl per vedere le porte che
una richiesta attraversa e lo stream che notifica ogni cambiamento.

## Obiettivi

- Esplorare gruppi, versioni e risorse REST senza l'interpretazione di kubectl (9.1).
- Distinguere autenticazione, autorizzazione e admission dalle loro risposte (9.2-9.3).
- Osservare eventi ADDED e DELETED su una connessione watch (9.4).

## Prerequisiti

- Un cluster raggiungibile con kubectl e i capitoli 7-8 completati.
- curl e base64. Il controllo sceglie una porta locale libera a partire da 8001.

## Lo scenario

Completa start/api-lab.sh. Apri kubectl proxy, ma usa curl per parlare con /api, /apis e con il
server HTTPS reale.

### Fase 1 — L'API REST (9.1 — TODO 1)

Leggi /api e /apis attraverso il proxy e riconosci il gruppo core v1 e il gruppo apps.

### Fase 2 — Le porte (9.2-9.3 — TODO 2)

Confronta quattro richieste: con token non valido, con certificati del kubeconfig, impersonando il ServiceAccount
default e creando un secondo Pod oltre quota. Conserva codice HTTP e messaggio di ciascuna risposta.

### Fase 3 — Lo stream (9.4 — TODO 3)

Apri un watch dei namespace, crea e cancella watch-lab e individua gli eventi ADDED e DELETED sulla
stessa connessione. Esegui il controllo automatico:

    bash kubernetes/ed1/cap09/solution/run.sh

## Criteri di "fatto"

- Hai esplorato /api e /apis con curl.
- Hai distinto 401 di autenticazione, accesso certificato, Forbidden RBAC e quota superata.
- run.sh stampa OK 1..7 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 controlla i gruppi REST; OK 2 il rifiuto 401 di un token non valido; OK 3 l'accesso certificato.
- OK 4 è il cancello di autorizzazione; OK 5 è il cancello di admission per quota.
- OK 6 richiede gli eventi ADDED e DELETED nello stesso watch.
- OK 7 controlla namespace, processi locali e credenziali temporanee.

## Domande di riflessione

**a.** A quale porta corrisponde ciascuna delle quattro risposte raccolte?

**b.** Cosa dicono di diverso HTTP 401 e 403, e perché una richiesta priva di credenziali può apparire come system:anonymous?

**c.** Perché LIST più WATCH è più efficiente del polling e come alimenta la riconciliazione?

## Pulizia

Il controllo chiude proxy e watch, cancella i certificati temporanei e rimuove quota-lab e watch-lab.
Per la prova manuale elimina gli stessi namespace e termina i due processi con Ctrl-C.

## Dove porta

Hai visto come il cambiamento entra nel cluster e come viene notificato. Il capitolo 10 apre i
controller che ricevono quei segnali e riconciliano la realtà.
