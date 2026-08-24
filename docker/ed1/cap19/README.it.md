# Capitolo 19 — Sulla banchina, e oltre l'orizzonte

**Livello:** Cloud Architect

Fin qui i container vivevano dietro il centralino: un IP privato, il NAT a fare da
filtro tra loro e la rete vera. Va bene per la maggior parte dei casi, ma a volte
serve altro: che il container appaia sulla rete fisica come una macchina a sé, con
un suo indirizzo e un suo MAC, senza mediazioni. È il driver macvlan — il container
sulla banchina, non più dietro il vetro. In questo laboratorio dai a due container un
indirizzo diretto sulla rete di un'interfaccia parent e verifichi che ciascuno ha il
suo MAC e che si parlano sullo stesso segmento. Poi tocchi con mano il prezzo di
questa scelta — il container non parla con il proprio host, nemmeno se l'host sta
sulla stessa sottorete — e cambi driver per vedere in cosa ipvlan è diverso. Infine
guardi oltre l'orizzonte del singolo host: overlay (la rete che attraversa più host),
il ponte verso l'orchestrazione.

## Obiettivi

- Dare a un container un indirizzo diretto sulla rete di un parent con macvlan
  (19.1).
- Verificare che ogni container ha il proprio MAC — una identità L2 a sé sul
  segmento (19.1).
- Verificare che due container macvlan sullo stesso parent si raggiungono a livello
  2 (19.1).
- Misurare il limite dell'hairpin: un figlio macvlan e il suo parent non si
  raggiungono, in nessuna delle due direzioni (19.2).
- Distinguere ipvlan da macvlan sul fatto che conta: i figli ipvlan condividono il
  MAC del parent (19.2).
- Inquadrare overlay (19.3) e capire quando serve (19.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- **Un'interfaccia parent.** macvlan si attacca a un'interfaccia reale; per non
  toccare la NIC della macchina usiamo un'interfaccia fittizia dedicata, creata una
  volta con sudo (reversibile). Prima di iniziare:

      sudo ip link add cap19dummy type dummy
      sudo ip link set cap19dummy up
      sudo ip addr add 192.168.190.1/24 dev cap19dummy

  Il terzo comando mette l'host sulla stessa sottorete dei container: serve alla
  Fase 4, altrimenti il ping dell'host uscirebbe dal gateway di casa e misureresti
  una rotta mancante invece dell'isolamento macvlan.

  A fine capitolo rimuovi tutto con: sudo ip link del cap19dummy
- Il capitolo 16 (namespace di rete) e i capitoli 17-18 (i driver): qui aggiungi il
  driver che mette il container direttamente sul segmento fisico.

## Lo scenario

In start/ trovi imacvlan.sh: uno script che, dato il parent cap19dummy, dovrebbe
creare una rete macvlan, avviarci due container e misurarne MAC e raggiungibilità —
ma le operazioni chiave mancano. Colmi cinque lacune (TODO 1..5): le prime tre
costruiscono la rete macvlan e la misurano, le ultime due mostrano il limite del
driver e il confronto con ipvlan. Reti e container usa-e-getta, rimossi alla fine; la
NIC reale e il demone non si toccano.

Prepara l'ambiente:

    cd docker/ed1/cap19/start

### Fase 1 — La rete macvlan (19.1 — TODO 1)

Apri start/imacvlan.sh e completa il **TODO 1**: crea una rete macvlan sul parent e
avvia due container, ciascuno con un IP sulla sottorete del parent. Con macvlan il
container non prende un IP privato dietro NAT: è indirizzato direttamente sul
segmento.

    docker network create -d macvlan --subnet 192.168.190.0/24 -o parent="$PARENT" "$NET" >/dev/null
    docker run -d --name "$A" --network "$NET" --ip 192.168.190.10 busybox sleep 60 >/dev/null
    docker run -d --name "$B" --network "$NET" --ip 192.168.190.11 busybox sleep 60 >/dev/null

### Fase 2 — Un MAC per ciascuno (19.1 — TODO 2)

Completa il **TODO 2**: leggi il MAC di eth0 di ciascun container. A differenza del
bridge, dove i container vivono dietro l'unico MAC del bridge, qui ognuno ha il suo
indirizzo hardware — appare come un dispositivo distinto sul segmento.

    a_mac=$(docker exec "$A" cat /sys/class/net/eth0/address)
    b_mac=$(docker exec "$B" cat /sys/class/net/eth0/address)

### Fase 3 — Sullo stesso segmento (19.1 — TODO 3)

Completa il **TODO 3**: verifica che i due container si raggiungono per IP. Sono
entrambi sul segmento del parent, adiacenti a livello 2: si parlano direttamente.

    reach=$(docker exec "$A" sh -c "ping -c1 -w2 192.168.190.11 >/dev/null 2>&1 && echo OK || echo FAIL")

### Fase 4 — Il limite dell'hairpin (19.2 — TODO 4)

Completa il **TODO 4**: misura le due direzioni che non funzionano. Il container non
raggiunge 192.168.190.1, che è l'host sulla sua stessa sottorete; e l'host non
raggiunge il container. Non è un guasto del segmento: il ping al fratello della Fase 3
è la controprova che il filo è vivo. È macvlan che isola per progetto un figlio dal
proprio parent — il limite dell'hairpin, la ragione per cui un container macvlan non
parla con il servizio che gira sull'host che lo ospita.

    a_to_host=$(docker exec "$A" sh -c "ping -c1 -w2 192.168.190.1 >/dev/null 2>&1 && echo OK || echo FAIL")
    host_to_a=$(ping -c1 -w2 192.168.190.10 >/dev/null 2>&1 && echo OK || echo FAIL)

### Fase 5 — L'altro driver: ipvlan (19.2 — TODO 5)

Completa il **TODO 5**: smonta la parte macvlan e crea sullo stesso parent una rete
ipvlan in modo L2, con due container. Lo smontaggio non è pignoleria: un parent
accetta un solo tipo di figlio per volta, e senza di quello l'aggancio ipvlan muore
con «device or resource busy». Poi leggi i MAC. Dove macvlan dava a ciascuno il suo,
ipvlan li fa condividere tutti quello del parent e li distingue per IP — e i due
container si raggiungono lo stesso.

    docker network create -d ipvlan --subnet 192.168.191.0/24 -o parent="$PARENT" -o ipvlan_mode=l2 "$IPVNET" >/dev/null
    parent_mac=$(cat "/sys/class/net/$PARENT/address")
    c_mac=$(docker exec "$C" cat /sys/class/net/eth0/address)

Quando i cinque TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- imacvlan.sh crea la rete macvlan e i due container (TODO 1).
- Legge il MAC di ciascun container (TODO 2).
- Verifica la raggiungibilità L2 tra i due (TODO 3).
- Misura le due direzioni bloccate tra figlio e parent (TODO 4).
- Crea la rete ipvlan e legge i MAC del parent e dei suoi figli (TODO 5).
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — indirizzo diretto: il container ha un IP sulla sottorete del parent
  (192.168.190.x), non un IP privato dietro NAT.
- **OK 2** — MAC proprio: i due container hanno MAC distinti — ciascuno una identità
  L2 a sé sul segmento.
- **OK 3** — stesso segmento: i due container macvlan si raggiungono per IP (adiacenti
  a livello 2).
- **OK 4** — limite dell'hairpin: con l'host indirizzato sulla stessa sottorete,
  container e host non si raggiungono in nessuna direzione, mentre il fratello sì.
- **OK 5** — l'altro driver: i due container ipvlan portano il MAC del parent e si
  raggiungono lo stesso, dove macvlan ne dava uno distinto a ciascuno.

## Domande di riflessione

**a.** Con macvlan il container ha un suo MAC e un IP sulla rete del parent, senza
NAT: appare come una macchina fisica a sé sulla LAN. Quali sono i vantaggi
(integrazione con reti e apparati esistenti, nessun port mapping) e i limiti (il
container di norma non parla con il proprio host, serve la modalità promiscua sulla
NIC, consumi indirizzi della LAN reale)?

**b.** ipvlan è la variante: invece di dare a ogni container un MAC nuovo, condivide
il MAC del parent e distingue per IP (modo L2) o instrada (modo L3). Perché in certi
ambienti — cloud, switch con port security che limitano i MAC per porta — ipvlan è
preferibile a macvlan?

**c.** overlay è un'altra cosa ancora: una rete che attraversa più host (incapsula il
traffico in VXLAN), e per questo richiede uno stato condiviso — swarm o un
orchestratore — che qui non abbiamo attivato per non toccare il demone. In che modo
questo è il ponte verso il Manuale di Kubernetes, dove il modello di rete (un IP per
pod, una rete piatta tra i nodi) generalizza proprio questa idea?

## Pulizia

Lo script rimuove i container e le due reti, macvlan e ipvlan (docker rm -f, docker
network rm, con un trap di sicurezza). L'interfaccia parent cap19dummy resta, con il
suo indirizzo: essendo stata creata con sudo, la rimuovi tu a mano quando hai finito
— il comando porta via anche l'indirizzo:

    sudo ip link del cap19dummy

Il demone non viene mai riavviato e la NIC reale non è mai toccata.

## Dove porta

Con questo capitolo la Parte 5 è completa: dal namespace di rete ai bridge, ai driver
host/none, fino al container direttamente sul segmento fisico e all'orizzonte
multi-host. La **Parte 6** cambia livello: non più un container alla volta ma
un'applicazione intera. Il **capitolo 20** apre Docker Compose — progettare
applicazioni multi-servizio dove la rete custom, i nomi di servizio e i volumi che hai
imparato si compongono in un unico file. Per il riferimento dei comandi, vedi le
appendici del volume.
