# Capitolo 28 — Il passaporto del portiere

**Livello:** Cloud Architect

Il viaggio si chiude dando al portiere assunto nel capitolo 19 un'identità verificabile. In questo
laboratorio costruisci una CA locale, chiedi a Cert-Manager di emettere il certificato e dimostri che
Ingress-Nginx serve il negozio in HTTPS senza chiavi o certificati creati a mano.

## Obiettivi

- Inquadrare acquisizione, scadenza e rinnovo dei certificati TLS (28.2).
- Osservare la catena SelfSigned, CA e certificato foglia gestita da Cert-Manager (28.3).
- Ottenere HTTPS automatico con annotazione e sezione tls dell'Ingress (28.4).
- Verificare autorità emittente, SAN e risposta applicativa attraverso Ingress-Nginx (28.1, 28.4).

## Prerequisiti

- Docker, kind, kubectl, OpenSSL e accesso alla rete.
- Almeno 3 GiB liberi nel filesystem usato da Docker; run.sh esegue il precheck prima di creare il
  cluster.
- Familiarità con Deployment, Service e Ingress, in particolare il capitolo 19.
- Il laboratorio usa il cluster dedicato usa-e-getta book-labs-tls. Non usa né modifica il cluster
  principale del manuale.

## Lo scenario

In start/ trovi l'autorità locale e il negozio già predisposti. start/ingress.yaml instrada il traffico
HTTP, ma gli mancano tre informazioni: quale autorità deve emettere il certificato, quale hostname deve
coprire e in quale Secret deve salvarlo.

### Fase 1 — L'autorità locale (28.3)

issuer.yaml crea un ClusterIssuer SelfSigned, il certificato della CA locale e il ClusterIssuer che
userà quella CA. In produzione al suo posto useresti un issuer ACME e un dominio verificabile
pubblicamente; la riconciliazione successiva resterebbe la stessa.

### Fase 2 — La richiesta automatica (28.4 — TODO 1)

In start/ingress.yaml completa il TODO 1 aggiungendo la mappa annotations e selezionando il
ClusterIssuer local-ca. È il segnale che chiede a Cert-Manager di procurare il certificato.

### Fase 3 — Identità e deposito (28.4 — TODO 2 e TODO 3)

Completa la sezione tls: nel TODO 2 inserisci shop.book-labs.local fra gli host, perché la SAN deve
corrispondere al nome visitato; nel TODO 3 indica shop-tls come secretName, punto d'incontro fra
Cert-Manager e Ingress-Nginx.

Confronta il risultato con solution/ingress.yaml, poi esegui il controllo completo:

    bash solution/run.sh

Lo script crea il cluster dedicato, installa le versioni fissate di ingress-nginx e Cert-Manager,
prova prima l'Ingress incompleto e poi applica la soluzione.

## Criteri di "fatto"

- I TODO 1..3 descrivono autorità, hostname TLS e Secret.
- La CA locale e il Certificate shop-tls risultano Ready.
- La chiamata HTTPS validata contro la CA locale restituisce secure shop.
- run.sh stampa OK 1..5 e ALL CHECKS PASSED, compresa la controprova senza annotazione e sezione tls.

## Come viene verificato

solution/run.sh verifica, punto per punto:

- **OK 1** — la catena SelfSigned produce un ClusterIssuer CA pronto.
- **OK 2** — il cancello morde: l'Ingress incompleto non produce né Certificate né Secret shop-tls.
- **OK 3** — l'Ingress completo fa creare a Cert-Manager un Certificate pronto e un Secret TLS.
- **OK 4** — Ingress-Nginx serve secure shop in HTTPS e il client si fida della CA locale.
- **OK 5** — il certificato contiene la SAN richiesta ed è firmato dalla CA locale.

## Domande di riflessione

**a.** Perché HTTPS richiede un certificato firmato da un'autorità fidata, perché la gestione manuale
diventa fragile al rinnovo e quale ruolo svolge Ingress-Nginx (28.1–28.2)?

**b.** Cosa crea Cert-Manager leggendo annotazione e sezione tls? Spiega la catena SelfSigned, CA e
foglia, poi indica quale verifica ACME richiederebbe in produzione (28.3).

**c.** Segui una richiesta HTTPS dal client al Pod: da dove proviene la SAN e cosa cambia passando a
un vero issuer ACME, senza cambiare il meccanismo dichiarativo (28.4)?

Le risposte modello sono in solution/answers.md.

## Pulizia

Il trap di run.sh cancella il cluster book-labs-tls anche in caso di errore e ripristina il precedente
contesto kubectl. Se svolgi i passaggi a mano, esegui:

    kind delete cluster --name book-labs-tls

## Dove porta

Hai chiuso il percorso dal Pod all'HTTPS automatico: Service, Ingress, controller, Certificate e Secret
formano ora un solo ciclo riconciliato. Le appendici del manuale diventano gli strumenti di consultazione
per applicare e diagnosticare questo quadro completo nella pratica quotidiana.
