# Capitolo 17 — Il centralino privato

**Livello:** Avanzato

Nel capitolo 16 hai visto la centralina condivisa: il bridge docker0, dove ogni
container ha un numero (un IP) ma nessun nome. Va bene per capire il meccanismo,
male per costruirci sopra: gli IP cambiano a ogni riavvio, e tutti i container
finiscono sullo stesso centralino pubblico. La soluzione è aprire un centralino
privato — una rete bridge definita da te. Lì Docker aggiunge due cose che cambiano
tutto: una rubrica (un DNS integrato, così i container si chiamano per nome) e una
linea isolata (i container di una rete non vedono quelli di un'altra). In questo
laboratorio confronti i due mondi: sul bridge di default i nomi non funzionano, sul
tuo bridge sì, e chi è fuori dalla rete resta fuori.

## Obiettivi

- Vedere che su una rete bridge definita da te i container si risolvono per nome
  (DNS integrato) (17.2).
- Verificare che sul bridge di default la risoluzione per nome non funziona (17.1).
- Constatare l'isolamento: chi non è sulla rete non raggiunge i suoi container,
  neppure per IP (17.3).
- Capire perché una rete per-applicazione è la scelta giusta (17.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Il capitolo 16 (namespace di rete, veth, bridge): qui il bridge diventa una rete
  con un nome e delle regole.

## Lo scenario

In start/ trovi irete.sh: uno script che crea una rete custom, avvia dei container
su di essa e sul bridge di default, e dovrebbe misurare risoluzione per nome e
isolamento — ma le tre prove chiave mancano. Colmi tre lacune (TODO 1..3). Rete con
nome unico e container usa-e-getta, entrambi rimossi alla fine; il bridge di default
non si tocca e non si riavvia il demone.

Prepara l'ambiente:

    cd docker/ed1/cap17/start

### Fase 1 — La rubrica: nomi sul bridge custom (17.2 — TODO 1)

Apri start/irete.sh e completa il **TODO 1**: sulla rete custom, fai raggiungere al
container A il container B **per nome**. Il DNS integrato della rete risolve il nome
del container: ping per nome funziona.

    custom_name=$(docker exec "$A" sh -c "ping -c1 -w2 $B >/dev/null 2>&1 && echo OK || echo FAIL")

### Fase 2 — Nessuna rubrica sul default (17.1 — TODO 2)

Completa il **TODO 2**: sul bridge di default, prova a raggiungere per nome un altro
container. Non c'è DNS integrato: il nome non si risolve, e il ping fallisce.

    default_name=$(docker exec "$DA" sh -c "ping -c1 -w2 $DB >/dev/null 2>&1 && echo OK || echo FAIL")

### Fase 3 — La linea isolata (17.3 — TODO 3)

Completa il **TODO 3**: prendi l'IP di B (sulla rete custom) e prova a raggiungerlo
da un container che NON è su quella rete. È bloccato: le reti sono isolate, neppure
l'IP passa.

    b_ip=$(docker exec "$B" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
    isolation=$(docker exec "$DA" sh -c "ping -c1 -w2 $b_ip >/dev/null 2>&1 && echo REACHED || echo BLOCKED")

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- irete.sh verifica la risoluzione per nome sulla rete custom (TODO 1).
- Verifica che sul bridge di default il nome non si risolve (TODO 2).
- Verifica che un container fuori dalla rete non raggiunge B, neppure per IP
  (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — DNS della rete: sulla rete custom, A raggiunge B per nome (risultato
  OK).
- **OK 2** — niente DNS sul default: sul bridge di default, il nome non si risolve
  (risultato FAIL).
- **OK 3** — isolamento: un container fuori dalla rete custom non raggiunge B
  neppure per IP (risultato BLOCKED).

## Domande di riflessione

**a.** Sul bridge di default i container non si risolvono per nome, su una rete
definita da te sì: cosa fa la differenza? Dove vive il DNS integrato (l'indirizzo
127.0.0.11 dentro il container) e perché il vecchio meccanismo --link è deprecato in
suo favore?

**b.** Due reti custom, o una custom e il default, non si parlano di default: quali
regole del demone realizzano questo isolamento, e perché è una proprietà di
sicurezza e non solo di ordine? Come faresti, di proposito, a collegare un container
a più reti (docker network connect)?

**c.** In un'applicazione multi-servizio (il web che parla col database), perché
conviene una rete custom dedicata all'app invece del bridge di default? Come si lega
questo ai nomi di servizio stabili di Docker Compose (capitolo 20), dove non usi mai
gli IP?

## Pulizia

Niente da smontare a mano: i container sono rimossi dallo script (docker rm -f) e la
rete custom con nome unico è rimossa (docker network rm), il tutto con un trap di
sicurezza. Il bridge di default non è mai toccato. L'immagine base busybox resta in
cache. Il demone non viene mai riavviato.

## Dove porta

Hai due modi di collegare i container: il centralino pubblico e il tuo privato, con
rubrica e isolamento. Restano i casi limite: e se un container non volesse alcun
isolamento di rete, o al contrario nessuna rete affatto? Il **capitolo 18** copre gli
altri driver — host (il container condivide lo stack dell'host, senza namespace suo)
e none (un namespace senza cavo) — e come si sceglie. Per il riferimento dei comandi,
vedi le appendici del volume.
