# Capitolo 27 — Pulire la stiva, guardare il mare

**Livello:** Cloud Architect

Ogni viaggio lascia dei residui. Container fermati e mai rimossi, immagini vecchie che
nessuno usa più, volumi rimasti orfani quando il loro container è sparito: col tempo la
stiva si riempie e il disco si esaurisce. Il day-2 — la vita dopo il primo deploy — è
fatto anche di questo: sapere cosa occupa spazio e recuperarlo, ma con giudizio. Perché
su una macchina condivisa un docker system prune dato alla leggera cancella anche il
lavoro degli altri. In questo laboratorio pulisci in sicurezza — solo le risorse che
porti l'etichetta tua — e poi alzi lo sguardo: dove finisce Docker su un host solo, e
dove comincia l'orizzonte dell'orchestrazione.

## Obiettivi

- Riconoscere gli orfani: container fermi, volumi inutilizzati che occupano spazio
  (27.1).
- Recuperare spazio in sicurezza, con ambito ristretto (label, nomi), mai un prune
  globale su un host condiviso (27.2).
- Verificare che solo le tue risorse sono state rimosse (27.2).
- Inquadrare gli orizzonti: i limiti del singolo host e il ponte all'orchestrazione
  (27.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Tutto il volume: qui metti in ordine ciò che i capitoli precedenti hanno creato.

## Lo scenario

In start/ trovi imaint.sh: uno script che crea un container fermo e un volume
inutilizzato, entrambi etichettati come tuoi, e dovrebbe recuperarli in sicurezza — ma
le tre operazioni mancano. Colmi tre lacune (TODO 1..3). Tutte le risorse sono
etichettate e rimosse solo per ambito: il demone condiviso e le risorse altrui non si
toccano.

Prepara l'ambiente:

    cd docker/ed1/cap27/start

### Fase 1 — Reclamare i container fermi, per ambito (27.2 — TODO 1)

Apri start/imaint.sh e completa il **TODO 1**: recupera i container fermi che
appartengono a te, filtrando per la tua etichetta. È un prune con ambito: tocca solo i
tuoi, mai quelli degli altri.

    docker container prune -f --filter "label=owner=$LABEL" >/dev/null

### Fase 2 — Reclamare il volume, per nome (27.2 — TODO 2)

Completa il **TODO 2**: rimuovi il volume con nome che hai creato. Esplicito e mirato —
nessun prune di volumi generico che potrebbe prendere anche quelli di altri.

    docker volume rm "$VOL" >/dev/null

### Fase 3 — Verificare (27.2 — TODO 3)

Completa il **TODO 3**: riconta le tue risorse dopo la pulizia. Non deve restarne
nessuna delle tue — e nient'altro è stato toccato.

    con_after=$(docker ps -aq --filter "label=owner=$LABEL" | grep -c . || true)
    vol_after=$(docker volume ls -q --filter "label=owner=$LABEL" | grep -c . || true)

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- imaint.sh recupera i propri container fermi con un prune filtrato per etichetta
  (TODO 1).
- Rimuove il proprio volume con nome (TODO 2).
- Riconta e conferma che nulla di suo resta (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — prima della pulizia esistono un container fermo e un volume etichettati
  come tuoi (gli orfani da recuperare).
- **OK 2** — dopo il prune filtrato per etichetta, il tuo container fermo è sparito.
- **OK 3** — dopo la rimozione per nome, il tuo volume è sparito: recupero completo,
  con ambito ristretto.

## Domande di riflessione

**a.** Gli orfani nascono ovunque: container fermati senza --rm, immagini «dangling»
rimaste dopo un rebuild, volumi che nessuno cancella (capitolo 13). Perché docker system
prune dato senza pensarci è pericoloso su una macchina condivisa, e come lo rende sicuro
lavorare per ambito — filtri per etichetta, rimozioni per nome, mai «tutto»?

**b.** docker system df mostra dove va lo spazio: immagini, layer scrivibili dei
container, volumi, cache di build. Cosa consuma di più in un ambiente reale, e perché la
manutenzione dello spazio (rotazione dei log del capitolo 25 compresa) è una routine e non
un intervento d'emergenza?

**c.** Su un host solo Docker arriva a un limite: se la macchina cade, i container cadono
con lei; scalare significa avviare copie a mano; l'auto-riparazione non c'è. Perché questo
è il confine oltre il quale serve un orchestratore, e in che modo tutto ciò che hai
imparato — immagini, reti, volumi, Compose, healthcheck, sicurezza — è esattamente il
vocabolario con cui Kubernetes ragiona? È il ponte del Manuale di Kubernetes.

## Pulizia

Lo script rimuove le proprie risorse per ambito (prune filtrato per etichetta e rimozione
per nome), con un trap di sicurezza che ripulisce comunque. Nessuna risorsa altrui è
toccata, il demone non viene mai riavviato.

## Dove porta

Con questo capitolo il Manuale di Docker si chiude: dal processo mascherato del capitolo 1
alla nave in produzione, hai attraversato l'illusione dell'isolamento, il motore, le
immagini, la persistenza, le reti, l'orchestrazione locale e l'hardening. L'orizzonte è
l'orchestrazione su più host — e le appendici del volume ti accompagnano oltre: in
particolare l'appendice E, «Dal singolo host all'orchestratore», è il ponte esplicito
verso il Manuale di Kubernetes. Buona navigazione.
