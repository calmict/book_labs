# Capitolo 21 — Il segnale di via libera

**Livello:** Avanzato

Nel capitolo 20 hai fatto partire web dopo db con depends_on. Ma «partito» non è
«pronto»: il container di un database può essere avviato mentre il database dentro
sta ancora caricando, e web che si connette in quell'istante trova la porta chiusa.
depends_on, da solo, aspetta che il container esista, non che il servizio sia pronto
ad accettare traffico. Serve un segnale di via libera. In Docker quel segnale è
l'healthcheck: il servizio dichiara come si capisce che è davvero pronto, e chi
dipende da lui può aspettare quel via libera invece di indovinare con uno sleep. In
questo laboratorio dai a db un healthcheck che diventa verde solo dopo un ritardo, e
fai aspettare web finché db non è healthy — non solo partito.

## Obiettivi

- Distinguere «partito» (started) da «pronto» (healthy) (21.1).
- Dichiarare un healthcheck su un servizio: come Docker capisce che è pronto (21.2).
- Far dipendere web da db con condition: service_healthy — aspettare la prontezza
  (21.3).
- Vedere che l'ordine di avvio segue la prontezza, non un tempo arbitrario (21.4).

## Prerequisiti

- Un Linux con Docker Engine attivo e il plugin Docker Compose (vedi SETUP.md). Il
  tuo utente deve poter usare Docker.
- Il capitolo 20 (Compose, depends_on): qui lo rendi consapevole della prontezza.

## Lo scenario

In start/ trovi compose.yaml: db non segnala la prontezza e non ha un healthcheck, e
web aspetta solo che db sia partito. Così il cancello della prontezza non morde.
Colmi tre lacune (TODO 1..3). Il progetto Compose ha un nome unico e viene rimosso
alla fine (down); il demone non si tocca e non si riavvia.

Prepara l'ambiente:

    cd docker/ed1/cap21/start

### Fase 1 — L'healthcheck (21.2 — TODO 1)

Apri start/compose.yaml e completa il **TODO 1**: dai a db un healthcheck. È il
comando con cui Docker verifica, a intervalli, se il servizio è pronto — qui, se
esiste il file di prontezza.

    healthcheck:
      test: ["CMD-SHELL", "test -f /tmp/ready"]
      interval: 1s
      timeout: 2s
      retries: 10
      start_period: 1s

### Fase 2 — La prontezza ritardata (21.1 — TODO 2)

Completa il **TODO 2**: fai in modo che db segnali la prontezza solo dopo un ritardo,
come un servizio reale che ci mette un po' a essere pronto. Il file /tmp/ready compare
dopo alcuni secondi.

    command: ["sh", "-c", "sleep 4; touch /tmp/ready; sleep 3600"]

### Fase 3 — Aspettare il via libera (21.3 — TODO 3)

Completa il **TODO 3**: fai aspettare a web che db sia HEALTHY, non solo partito. Con
la condizione service_healthy, Compose non avvia web finché l'healthcheck di db non
passa.

    depends_on:
      db:
        condition: service_healthy

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- db ha un healthcheck (TODO 1) e diventa pronto solo dopo un ritardo (TODO 2).
- web aspetta che db sia healthy con condition: service_healthy (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh porta su l'applicazione e verifica, punto per punto:

- **OK 1** — db ha un healthcheck e raggiunge lo stato healthy.
- **OK 2** — web è in esecuzione e dichiara depends_on db con condition
  service_healthy (aspetta la prontezza, non solo l'avvio).
- **OK 3** — il cancello morde: docker compose up ha atteso che db fosse healthy
  prima di avviare web (l'up ha impiegato il tempo della prontezza, non un istante).

## Domande di riflessione

**a.** depends_on con la condizione di default (service_started) aspetta solo che il
container esista. Perché per un database non basta, e cosa dichiara invece un
healthcheck — a cosa servono test, interval, retries e start_period?

**b.** Un servizio con healthcheck attraversa gli stati starting → healthy (o
unhealthy). Come li usano Docker e Compose, e cosa succede se l'healthcheck non passa
mai — i retries si esauriscono e la condizione service_healthy non è mai soddisfatta?
Come lo vedresti in docker compose up?

**c.** Healthcheck più depends_on: condition realizzano un ordine di avvio basato
sulla PRONTEZZA, non sul tempo — niente più «sleep 10» sperando che basti. Perché
questo è più robusto, e come anticipa le probe di readiness e liveness di Kubernetes,
dove l'orchestratore usa lo stesso segnale per decidere quando mandare traffico a un
pod?

## Pulizia

Niente da smontare a mano: run.sh chiude il progetto con docker compose down (rimuove
container e rete d'app), con un trap di sicurezza. L'immagine base busybox resta in
cache. Il demone non viene mai riavviato.

## Dove porta

Sai far partire i servizi nell'ordine giusto e alla prontezza giusta. Resta di
configurarli: un'applicazione reale ha variabili d'ambiente, file .env e segreti che
non vanno scritti nel compose in chiaro. Il **capitolo 22** chiude la Parte 6 con la
configurazione — variabili, .env e secrets — prima del salto all'hardening. Per il
riferimento di Compose, vedi le appendici del volume.
