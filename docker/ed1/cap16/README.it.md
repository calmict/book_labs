# Capitolo 16 — Il cavo e la centralina

**Livello:** Avanzato

Finora ogni container era un'isola di processi e di dati; ora scopri che è anche
un'isola di rete. La Parte 5 apre i labirinti del networking, e la prima verità è
che «dare la rete a un container» non è magia: Docker usa gli stessi mattoni del
kernel Linux. Ogni container riceve il proprio network namespace — uno stack di
rete tutto suo, con le sue interfacce, il suo IP, la sua tabella di routing — e
viene collegato al mondo da un cavo virtuale, la veth pair: un'estremità dentro il
container (eth0), l'altra sull'host, attaccata alla centralina condivisa, il bridge
docker0. In questo laboratorio prima lo osservi su due container reali, poi lo
ricostruisci a mano in un ambiente isolato e aggiungi il NAT verso una rete esterna
simulata.

## Obiettivi

- Vedere che un container ha il proprio network namespace, diverso da quello
  dell'host (16.1).
- Riconoscere che ogni container ha il suo eth0 e il suo indirizzo, distinto da
  quello degli altri (16.4).
- Capire che eth0 è un'estremità di una veth pair: il suo peer sta dall'altra parte,
  sull'host (16.2).
- Collegare il tutto al bridge docker0 come centralina condivisa (16.3).
- Costruire namespace, veth e bridge a mano senza privilegi reali.
- Applicare una regola MASQUERADE e provarla con traffico end-to-end verso una rete
  esterna simulata.
- Confrontare la topologia costruita con quella del bridge Docker reale, in sola
  lettura.

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Il capitolo 2 (i namespace): qui incontri quello di rete, il network namespace.
- I comandi unshare, ip, bridge, iptables, ping, sysctl, mount e umount.

## Lo scenario

In start/ trovi irete.sh: uno script che avvia due container e dovrebbe leggerne lo
stack di rete — namespace, indirizzo, cavo — ma le tre letture chiave mancano. Colmi
tre lacune (TODO 1..3). I due container girano contemporaneamente (così ciascuno
tiene il suo indirizzo) e sono rimossi alla fine; si usa il bridge di default, senza
crearne o toccarne altri; il demone non si tocca.

In start/ trovi anche ilcablaggio.sh. I TODO 4..6 ricostruiscono il percorso completo
in un user e network namespace effimero: nessuna interfaccia o regola viene creata
nella rete reale dell'host. La rete esterna è simulata localmente, perciò la prova
non dipende dall'accesso a Internet del lettore.

Prepara l'ambiente:

    cd docker/ed1/cap16/start

### Fase 1 — Uno stack di rete tutto suo (16.1 — TODO 1)

Apri start/irete.sh e completa il **TODO 1**: leggi il network namespace del primo
container (l'inode di /proc/self/ns/net). Confrontato con quello dell'host, è
diverso: il container non condivide lo stack di rete della macchina, ne ha uno suo.

    c1_ns=$(docker exec "$C1" readlink /proc/self/ns/net)

### Fase 2 — Un indirizzo per ciascuno (16.4 — TODO 2)

Completa il **TODO 2**: leggi l'IP di eth0 di entrambi i container. Girando insieme
sullo stesso bridge, ricevono due indirizzi diversi — la prova che ogni stack è
indipendente.

    c1_ip=$(docker exec "$C1" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
    c2_ip=$(docker exec "$C2" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')

### Fase 3 — Il cavo virtuale: veth (16.2 — TODO 3)

Completa il **TODO 3**: eth0 è un'estremità di una veth pair. Leggi l'indice locale
(ifindex) e quello del peer (iflink): sono diversi, perché l'altra estremità del
cavo sta in un'altra rete — sull'host, attaccata a docker0.

    c1_ifindex=$(docker exec "$C1" cat /sys/class/net/eth0/ifindex)
    c1_iflink=$(docker exec "$C1" cat /sys/class/net/eth0/iflink)

### Fase 4 — Cablaggio manuale (16.1+16.2 — TODO 4)

In start/ilcablaggio.sh crea il namespace contenitore, il bridge br-cap16 e una
coppia veth. Sposta un capo nel namespace, rinominalo eth0, assegna 10.16.0.2/24 e
collega l'altro capo al bridge con indirizzo 10.16.0.1/24. Porta su interfacce e
loopback e aggiungi la route predefinita del contenitore.

### Fase 5 — Un mondo esterno controllato (16.3 — TODO 5)

Crea un secondo namespace collegato al router isolato sulla subnet 192.0.2.0/24.
Abilita l'inoltro IPv4 solo dentro l'ambiente effimero e aggiungi una regola
POSTROUTING MASQUERADE limitata alla sorgente 10.16.0.0/24 e all'interfaccia esterna.
Non usare Internet e non scrivere regole sull'host reale.

### Fase 6 — Prova e confronto (TODO 6)

Invia un ping da 10.16.0.2 a 192.0.2.2. Registra l'appartenenza della veth al bridge
e il contatore della regola MASQUERADE dopo il traffico: deve essere maggiore di
zero. Il test osserva inoltre docker0 e bridge link sull'host in sola lettura per
confrontare bridge, veth e subnet privata; non prova a leggere le regole iptables
di Docker, che richiederebbero privilegi reali.

Quando i sei TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- irete.sh legge il network namespace del container (TODO 1).
- Legge l'IP di eth0 di entrambi i container (TODO 2).
- Legge gli indici della veth (ifindex e iflink) (TODO 3).
- ilcablaggio.sh costruisce namespace, veth e bridge dentro unshare -Urnm (TODO 4).
- Il traffico raggiunge la rete esterna simulata attraverso MASQUERADE (TODO 5).
- La struttura viene confrontata con docker0 senza modificare la rete reale (TODO 6).
- run.sh stampa OK 1..6 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — network namespace proprio: l'inode del namespace di rete del container
  è diverso da quello dell'host.
- **OK 2** — indirizzo proprio: i due container hanno due IP distinti sul bridge,
  ciascuno il suo stack.
- **OK 3** — veth pair: l'indice locale di eth0 e quello del peer differiscono —
  eth0 è un'estremità di un cavo la cui altra estremità sta sull'host.
- **OK 4** — cablaggio manuale: eth0 del namespace è collegata tramite veth al
  bridge privato br-cap16.
- **OK 5** — NAT end-to-end: il ping raggiunge il namespace esterno e incrementa il
  contatore della regola MASQUERADE realmente attraversata.
- **OK 6** — confronto Docker: docker0 è visibile in sola lettura e presenta lo
  stesso modello concettuale di bridge, veth e subnet privata.

## Domande di riflessione

**a.** Un network namespace dà al container uno stack di rete completo: interfacce,
tabella di routing, regole. Perché eth0 del container non compare tra le interfacce
dell'host, e cosa significa che due container non si vedono i rispettivi stack?
Collega la risposta ai namespace del capitolo 2.

**b.** Una veth pair è come un cavo con due estremità: scrivi da una parte, esce
dall'altra. Perché ifindex e iflink di eth0 sono numeri diversi, e cosa rappresenta
il peer che sta «dall'altra parte», sull'host, attaccato a docker0? Cosa succederebbe
al container se quel cavo venisse staccato?

**c.** Il bridge docker0 è la centralina: i container attaccati allo stesso bridge si
parlano tra loro, e per uscire verso Internet il traffico viene mascherato (NAT
masquerade) con l'indirizzo dell'host. In che modo questo prepara i capitoli 17
(bridge di default e custom) e 18 (host, none e la scelta del driver)?

## Pulizia

Niente da smontare a mano: i due container sono rimossi dallo script (docker rm -f,
più un trap di sicurezza). Il secondo script elimina esplicitamente namespace,
bridge, veth e mount temporaneo con un trap; l'intero cablaggio vive comunque in un
user, mount e network namespace effimero. docker0 viene soltanto osservato. L'immagine
base busybox resta in cache e il demone non viene mai riavviato.

## Dove porta

Hai visto il meccanismo: namespace, cavo, centralina. Il **capitolo 17** entra nel
bridge come rete: la differenza tra il bridge di default e un bridge custom — perché
su un bridge definito da te i container si risolvono per nome, e come si isola una
rete dall'altra. Per il riferimento dei comandi, vedi le appendici del volume.
