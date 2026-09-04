# Capitolo 19 — Il portone e il portiere

**Livello:** Intermedio

Dopo i Service del capitolo 18, il palazzo ha molti ingressi ma non sa ancora leggere il nome scritto
sulla richiesta HTTP. Qui separi le regole dichiarative da chi le realizza e osservi il routing L7.

## Obiettivi

- Distinguere il bilanciamento L4 dei Service dal routing per host e path dell'Ingress (19.1).
- Dichiarare due regole Ingress e constatare che senza controller restano inerti (19.2, 19.3).
- Installare ingress-nginx e seguire una richiesta fino al Service e al Pod corretti (19.3, 19.4).

## Prerequisiti

- Capitolo 18 completato; Docker, kind, kubectl, curl e accesso alla rete.
- Almeno 3 GiB liberi sul filesystem di Docker per il cluster dedicato.
- Una porta locale libera; run.sh ne sceglie una da 18081 in poi, oppure usa CAP19_PORT.

## Lo scenario

Due applicazioni condividono lo stesso IP e la stessa porta. Completa start/ingress.yaml colmando i
TODO 1..3: dichiara i due host, i path e i backend. Il test crea il cluster dedicato
book-labs-ingress, applica prima le regole senza controller e poi installa ingress-nginx.

    cd kubernetes/ed1/cap19/solution
    ./run.sh

### Fase 1 — Le regole senza portiere (19.2, 19.3)

Il primo controllo applica l'Ingress quando nessun controller è presente: la porta non risponde e
ADDRESS resta vuoto. È la controprova che l'oggetto dichiara un desiderio ma non lo realizza.

### Fase 2 — Una porta, due host (19.1, 19.2)

Ingress-nginx legge l'header Host e manda uno.labs.local a app-uno e due.labs.local a app-due. Un
host sconosciuto riceve il 404 del backend predefinito.

### Fase 3 — L'anatomia (19.4)

Il test cerca nei log del controller la richiesta appena inviata, collegando port mapping, controller,
decisione L7, Service e Pod.

## Criteri di "fatto"

- [ ] start/ingress.yaml contiene i tre TODO completati.
- [ ] Senza controller la regola è inerte; con il controller i due host raggiungono app diverse.
- [ ] run.sh stampa OK 1..6 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 dimostra che il cancello morde: senza controller non c'è routing e ADDRESS è vuoto.
- OK 2 verifica che ingress-nginx diventi Ready.
- OK 3 e OK 4 verificano i due host sullo stesso IP e porta.
- OK 5 verifica il 404 per un host sconosciuto.
- OK 6 trova la richiesta e l'upstream scelto nei log del controller.

## Domande di riflessione

**a.** Cosa vede un Service L4, cosa vede un Ingress L7 e perché il routing per host richiede L7?

**b.** Perché Kubernetes accetta un Ingress che nessun controller realizza? Come richiama il
reconciliation loop del capitolo 10?

**c.** Quali stazioni attraversa la richiesta dal curl al Pod di app-uno, e chi decide a ogni passo?

## Pulizia

run.sh elimina il cluster kind creato e ripristina il contesto kubectl precedente. Se il cluster
dedicato esisteva già, elimina soltanto i namespace usati dal laboratorio.

## Dove porta

Il routing ha collegato richieste e applicazioni; il capitolo 20 applica lo stesso disaccoppiamento
allo storage, separando ciò che un'app chiede dal volume reale che il cluster le assegna.
