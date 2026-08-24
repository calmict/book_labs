# Capitolo 18 — Attaccato o staccato

**Livello:** Avanzato

Bridge di default, bridge custom: finora ogni container aveva il suo stack di rete,
isolato e connesso. Ma non è l'unico modo. Ci sono due estremi, e sceglierli è una
decisione di progetto. Da un lato il driver host: il container non ha una rete sua,
è attaccato direttamente alla presa dell'host — condivide il suo stack, le sue
interfacce, le sue porte. Nessun isolamento, nessun NAT, massima velocità, massima
esposizione. Dall'altro il driver none: il container ha il suo namespace ma è
staccato — solo loopback, nessun cavo verso il mondo. In questo laboratorio tocchi
i tre driver a confronto e vedi cosa cambia: chi condivide lo stack dell'host, chi
non ha rete affatto, e il bridge nel mezzo.

## Obiettivi

- Vedere che il driver host fa condividere al container il network namespace
  dell'host — nessun isolamento (18.1).
- Vedere che il driver none dà al container un namespace suo ma senza eth0 —
  nessuna connettività (18.2).
- Confrontare col bridge di default: namespace proprio e una eth0 — isolato ma
  connesso (18.4).
- Capire come si sceglie il driver e perché host è potente ma delicato (18.3).
- Dimostrare che host occupa direttamente le porte dell'host e ignora -p (18.1).
- Confrontare qualitativamente i percorsi host e bridge verso lo stesso servizio,
  misurando la latenza senza usarla come asserzione (18.3).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Il capitolo 16 (network namespace) e il 17 (bridge): qui vedi cosa succede quando
  il namespace di rete è quello dell'host, oppure quando è vuoto.

## Lo scenario

In start/ trovi drivers.sh: uno script che avvia un container con ciascun driver e
dovrebbe leggere cosa ottiene — namespace e interfacce — e confrontare porte e
percorsi, ma le cinque parti chiave mancano. Colmi cinque lacune (TODO 1..5).
Container usa-e-getta (--rm); nessuna rete viene creata, il demone non si tocca e
non si riavvia. Per pochi secondi tre piccoli server HTTP effimeri restano in
ascolto su porte alte dell'host: lo script sceglie porte libere prima di partire e
una trap le libera sempre, anche se il test si interrompe a metà.

Prepara l'ambiente:

    cd docker/ed1/cap18/start

### Fase 1 — Attaccato alla presa: driver host (18.1 — TODO 1)

Apri start/drivers.sh e completa il **TODO 1**: leggi il network namespace di un
container avviato con --network host. È lo stesso dell'host: il container non ha uno
stack suo, usa quello della macchina.

    host_driver_ns=$(docker run --rm --network host busybox readlink /proc/self/ns/net)

### Fase 2 — Staccato: driver none (18.2 — TODO 2)

Completa il **TODO 2**: avvia un container con --network none e leggi il suo
namespace e se ha una eth0. Ha un namespace tutto suo (diverso dall'host) ma nessuna
eth0: solo loopback, nessuna via verso il mondo.

    none_ns=$(docker run --rm --network none busybox readlink /proc/self/ns/net)
    none_eth0=$(docker run --rm --network none busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

### Fase 3 — Nel mezzo: il bridge (18.4 — TODO 3)

Completa il **TODO 3**: avvia un container col bridge di default e leggi namespace ed
eth0. Namespace suo (isolato dall'host) e una eth0 (connesso): la via di mezzo.

    bridge_ns=$(docker run --rm busybox readlink /proc/self/ns/net)
    bridge_eth0=$(docker run --rm busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

### Fase 4 — La porta dell'host è una sola (18.1 — TODO 4)

Lo script ti avvia già tre server usa-e-getta: uno in modalità host sulla porta
scelta (con un -p che la modalità host ignorerà), uno in modalità host su una porta
libera, uno sul bridge di default che pubblica una porta. Completa il **TODO 4**:
riprova lo stesso ascolto in modalità host sulla porta già occupata — deve fallire
con address already in use — e leggi la controprova sulla porta libera, che invece
è in esecuzione. Poi confronta cosa dice docker port nei due casi: in modalità host
nessuna mappatura, sul bridge sì.

    set +e
    conflict_output=$(docker run --rm --network host -v "$OUT:/www:ro" busybox httpd -f -p "$PORT" -h /www 2>&1)
    conflict_status=$?
    set -e
    free_running=$(docker inspect -f '{{.State.Running}}' "$FREE_SERVER")
    host_port_output=$(docker port "$HOST_SERVER")
    bridge_port_output=$(docker port "$BRIDGE_SERVER" 80/tcp)

### Fase 5 — Due percorsi verso lo stesso servizio (18.3 — TODO 5)

Completa il **TODO 5**: interroga lo stesso server host prima da un container host
attraverso 127.0.0.1, poi da un container bridge. Nel bridge 127.0.0.1 è il loopback
del container e deve fallire; l'indirizzo del gateway, ricavato dalla route di
default, deve funzionare.

    host_loopback=$(docker run --rm --network host busybox wget -q -O /dev/null "http://127.0.0.1:$PORT" && echo yes || echo no)
    bridge_loopback=$(docker run --rm busybox wget -q -T 1 -O /dev/null "http://127.0.0.1:$PORT" 2>/dev/null && echo yes || echo no)
    bridge_gateway=$(docker run --rm busybox sh -c 'gateway=$(ip route | awk '\''/default/ { print $3; exit }'\''); wget -q -O /dev/null "http://$gateway:'"$PORT"'" && echo yes || echo no')

Misura infine cento richieste sequenziali sui due percorsi, cronometrandole DENTRO
il container con time, così l'avvio di docker run resta fuori dal numero. I due
tempi vengono solo stampati, mai asseriti — e quasi sempre escono comparabili: è
esattamente ciò che dice il 18.3, l'overhead del NAT è trascurabile per la
stragrande maggioranza dei carichi. La differenza vera fra i due driver non è la
velocità, è quali percorsi esistono.

Quando i cinque TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- drivers.sh legge il namespace del container con driver host (TODO 1).
- Legge namespace ed eth0 del container con driver none (TODO 2).
- Legge namespace ed eth0 del container con bridge di default (TODO 3).
- Dimostra il conflitto di porta host e -p ignorato, con le rispettive controprove
  positive (TODO 4).
- Confronta i percorsi host-loopback, bridge-loopback e bridge-gateway verso lo
  stesso servizio e stampa le due misure di latenza (TODO 5).
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — host: il container condivide il network namespace dell'host (stesso
  inode) — nessun isolamento di rete.
- **OK 2** — none: il container ha un namespace suo (diverso dall'host) ma nessuna
  eth0 — nessuna connettività.
- **OK 3** — bridge: il container ha un namespace suo e una eth0 — isolato ma
  connesso.
- **OK 4** — host: la stessa porta produce un conflitto e una porta libera funziona;
  -p è ignorato in host ma produce una mappatura sul bridge.
- **OK 5** — stesso servizio: il loopback host funziona; il loopback bridge fallisce
  e il gateway bridge funziona. I tempi dei due percorsi vengono solo stampati.

## Domande di riflessione

**a.** Col driver host il container condivide lo stack di rete dell'host: le sue
porte si aprono direttamente sull'host, senza -p e senza NAT. Quali sono i vantaggi
(prestazioni, nessuna traduzione) e i rischi (nessun isolamento, conflitti di porta,
un servizio compromesso ha la rete dell'host)? Quando lo useresti davvero?

**b.** Col driver none il container ha un namespace di rete ma nessuna interfaccia
verso il mondo, solo loopback. A cosa serve un container senza rete — pensa a un job
batch che elabora un volume, o alla massima riduzione della superficie d'attacco. E
come potresti aggiungergli una rete più tardi, se servisse?

**c.** Tre driver, tre compromessi: bridge (isolato e connesso, il default), host
(veloce ma esposto), none (nessuna rete). Come scegli, e perché la potenza del driver
host — nessun namespace di rete separato — è esattamente ciò che lo rende da
maneggiare con cura in produzione?

## Pulizia

Niente da smontare a mano: una trap ferma il server HTTP e gli altri container
cap18 anche se il test si interrompe, liberando le porte alte; i container sono
usa-e-getta (--rm) e nessuna rete viene creata. L'immagine base busybox resta in
cache (condivisa). Il demone non viene mai riavviato.

## Dove porta

Con questo capitolo hai il quadro dei driver «di casa». La Parte 5 si chiude
guardando oltre il singolo host: il **capitolo 19** — di livello Cloud Architect —
copre macvlan e ipvlan (dare al container un indirizzo sulla rete fisica, come fosse
una macchina a sé) e l'orizzonte overlay (una rete che attraversa più host), il ponte
verso l'orchestrazione e il Manuale di Kubernetes. Per il riferimento dei comandi,
vedi le appendici del volume.
