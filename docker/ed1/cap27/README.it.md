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
- Eseguire il backup di un volume e ripristinarlo in un volume nuovo con un
  container-utensile (27.3).
- Provare il ciclo tag, push, rimozione e pull con un registry privato locale (27.3).
- Inquadrare gli orizzonti: i limiti del singolo host e il ponte all'orchestrazione
  (27.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Tutto il volume: qui metti in ordine ciò che i capitoli precedenti hanno creato.

## Lo scenario

In start/ trovi maintenance.sh: uno script che crea un container fermo e un volume
inutilizzato, entrambi etichettati come tuoi, e dovrebbe recuperarli in sicurezza,
salvare e ripristinare un volume e provare un registry locale — ma cinque operazioni
mancano. Colmi cinque lacune (TODO 1..5). Tutte le risorse sono
etichettate e rimosse solo per ambito: il demone condiviso e le risorse altrui non si
toccano.

Prepara l'ambiente:

    cd docker/ed1/cap27/start

### Fase 1 — Reclamare i container fermi, per ambito (27.2 — TODO 1)

Apri start/maintenance.sh e completa il **TODO 1**: recupera i container fermi che
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

### Fase 4 — Backup e restore di un volume (27.3 — TODO 4)

Completa il **TODO 4**: scrivi un contenuto noto in un volume, poi usa un container
usa-e-getta per montarlo in sola lettura e creare un archivio nella cartella di lavoro.
Un secondo container ripristina l'archivio in un volume nuovo. Infine confronta il
testo ripristinato con l'originale: l'uguaglianza è deterministica.

    docker run --rm -v "$BACKUP_VOL:/data:ro" -v "$OUT:/backup" busybox tar czf "/backup/$(basename "$ARCHIVE")" -C /data .
    docker run --rm -v "$RESTORE_VOL:/data" -v "$OUT:/backup:ro" busybox tar xzf "/backup/$(basename "$ARCHIVE")" -C /data

### Fase 5 — Un registry privato locale (27.3 — TODO 5)

Completa il **TODO 5**: avvia registry:2 pubblicando la porta solo su 127.0.0.1 e
lascia che Docker scelga una porta host libera. Ritagga busybox con un nome cap27 verso
quel registry, esegui il push, rimuovi soltanto il tag appena creato e fai il pull.
Il digest letto subito dopo il push deve coincidere con quello del pull finale. Non
rimuovere busybox.

Una precisazione onesta sul pull: i layer di busybox restano nella cache locale, perché
il tag originale li usa ancora. Quello che il pull dimostra non è un nuovo scaricamento,
ma che il registry conserva il manifest e sa restituirtelo con lo stesso digest dopo che
il tag locale è sparito.

Docker consente un registry HTTP sul loopback senza configurare insecure-registries.
Un registry raggiunto tramite un vero indirizzo IP non gode di questa eccezione: lì
servono TLS oppure una configurazione esplicita del demone, che questo laboratorio non
modifica.

    docker run -d --name "$REGISTRY" --label "owner=$LABEL" -p 127.0.0.1::5000 registry:2 >/dev/null
    docker tag busybox "$REGISTRY_TAG"
    docker push "$REGISTRY_TAG"
    docker image rm "$REGISTRY_TAG"
    docker pull "$REGISTRY_TAG"

Quando i cinque TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- maintenance.sh recupera i propri container fermi con un prune filtrato per etichetta
  (TODO 1).
- Rimuove il proprio volume con nome (TODO 2).
- Riconta e conferma che nulla di suo resta (TODO 3).
- Ripristina in un volume nuovo il contenuto noto salvato nell'archivio (TODO 4).
- Completa il round trip di un tag attraverso il registry locale (TODO 5).
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — prima della pulizia esistono un container fermo e un volume etichettati
  come tuoi (gli orfani da recuperare).
- **OK 2** — dopo il prune filtrato per etichetta, il tuo container fermo è sparito.
- **OK 3** — dopo la rimozione per nome, il tuo volume è sparito: recupero completo,
  con ambito ristretto.
- **OK 4** — il volume ripristinato contiene esattamente il testo noto scritto prima
  del backup.
- **OK 5** — dopo push, rimozione del tag e pull dal registry locale, il tag esiste di
  nuovo con lo stesso digest letto subito dopo il push.

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

**d.** Perché il container che crea l'archivio monta il volume sorgente in sola lettura,
e perché il restore avviene in un volume nuovo invece di sovrascrivere l'originale? Quali
controlli aggiungeresti a una procedura di backup reale?

**e.** Perché il registry del laboratorio è legato soltanto a 127.0.0.1, e cosa cambia
quando lo si espone su un vero indirizzo IP? In produzione, perché TLS, autenticazione e
una politica di conservazione delle immagini sono parte del servizio e non dettagli
facoltativi?

## Pulizia

Lo script rimuove le proprie risorse per ambito, con un trap di sicurezza che ripulisce
comunque: i tre volumi cap27, il container registry, il tag verso il registry e l'archivio
di backup. I container-utensile sono usa-e-getta. L'immagine busybox originale resta in
cache. Nessuna risorsa altrui è toccata, il demone non viene mai riavviato e la porta
loopback viene liberata.

## Dove porta

Con questo capitolo il Manuale di Docker si chiude: dal processo mascherato del capitolo 1
alla nave in produzione, hai attraversato l'illusione dell'isolamento, il motore, le
immagini, la persistenza, le reti, l'orchestrazione locale e l'hardening. L'orizzonte è
l'orchestrazione su più host — e le appendici del volume ti accompagnano oltre: in
particolare l'appendice E, «Dal singolo host all'orchestratore», è il ponte esplicito
verso il Manuale di Kubernetes. Buona navigazione.
