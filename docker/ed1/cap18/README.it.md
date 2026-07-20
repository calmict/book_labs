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

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Il capitolo 16 (network namespace) e il 17 (bridge): qui vedi cosa succede quando
  il namespace di rete è quello dell'host, oppure quando è vuoto.

## Lo scenario

In start/ trovi idriver.sh: uno script che avvia un container con ciascun driver e
dovrebbe leggere cosa ottiene — namespace e interfacce — ma le tre letture chiave
mancano. Colmi tre lacune (TODO 1..3). Container usa-e-getta (--rm); nessuna rete
viene creata, il demone non si tocca e non si riavvia. Il container host non fa che
leggere: non apre porte, non modifica nulla.

Prepara l'ambiente:

    cd docker/ed1/cap18/start

### Fase 1 — Attaccato alla presa: driver host (18.1 — TODO 1)

Apri start/idriver.sh e completa il **TODO 1**: leggi il network namespace di un
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

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- idriver.sh legge il namespace del container con driver host (TODO 1).
- Legge namespace ed eth0 del container con driver none (TODO 2).
- Legge namespace ed eth0 del container con bridge di default (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — host: il container condivide il network namespace dell'host (stesso
  inode) — nessun isolamento di rete.
- **OK 2** — none: il container ha un namespace suo (diverso dall'host) ma nessuna
  eth0 — nessuna connettività.
- **OK 3** — bridge: il container ha un namespace suo e una eth0 — isolato ma
  connesso.

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

Niente da smontare a mano: tutti i container sono usa-e-getta (--rm) e nessuna rete
viene creata. L'immagine base busybox resta in cache (condivisa). Il demone non
viene mai riavviato.

## Dove porta

Con questo capitolo hai il quadro dei driver «di casa». La Parte 5 si chiude
guardando oltre il singolo host: il **capitolo 19** — di livello Cloud Architect —
copre macvlan e ipvlan (dare al container un indirizzo sulla rete fisica, come fosse
una macchina a sé) e l'orizzonte overlay (una rete che attraversa più host), il ponte
verso l'orchestrazione e il Manuale di Kubernetes. Per il riferimento dei comandi,
vedi le appendici del volume.
