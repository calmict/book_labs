# Capitolo 24 — Le chiavi giuste, non tutte

**Livello:** Cloud Architect

Nel capitolo 23 hai visto chi è root; ora vedi che root non è un blocco unico. I
poteri di root sono spezzati dal kernel in tante chiavi separate — le capabilities:
il permesso di aprire socket raw, di legare porte basse, di montare filesystem, di
cambiare proprietari. Un container non ha bisogno quasi mai di tutte. Il principio è
lo stesso di una cassaforte ben fatta: dai a ciascuno solo la chiave che gli serve. E
sopra le capabilities ci sono altri due strati — seccomp, che filtra le syscall, e
AppArmor o SELinux, che confinano cosa un processo può toccare. Difesa in profondità.
In questo laboratorio tocchi le capabilities con mano: togli tutto, e la stessa
operazione fallisce; ridai la chiave giusta, e riprende — senza restituire tutte le
altre.

## Obiettivi

- Vedere che root non è monolitico: i suoi poteri sono capabilities separate (24.1).
- Togliere tutte le capabilities con --cap-drop ALL e vedere un'operazione fallire
  (24.2).
- Ridare solo la capability necessaria con --cap-add: privilegio minimo (24.2).
- Inquadrare seccomp (24.3) e AppArmor/SELinux (24.4) come strati aggiuntivi.

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Il capitolo 23 (il modello dei privilegi): qui restringi non chi sei, ma cosa puoi
  fare.

## Lo scenario

In start/ trovi icapabilities.sh: uno script che dovrebbe provare la stessa operazione
(un ping, che richiede la capability NET_RAW) con tre insiemi di capabilities diversi,
ma le tre prove mancano. Colmi tre lacune (TODO 1..3). Container usa-e-getta (--rm);
il demone non si tocca.

Prepara l'ambiente:

    cd docker/ed1/cap24/start

### Fase 1 — Con le chiavi di default (24.1 — TODO 1)

Apri start/icapabilities.sh e completa il **TODO 1**: esegui un ping in un container
di default. Funziona: tra le capabilities che Docker concede per default c'è NET_RAW,
che serve per il socket raw del ping.

    default=$(docker run --rm busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

### Fase 2 — Tolte tutte le chiavi (24.2 — TODO 2)

Completa il **TODO 2**: rifai lo stesso ping ma con --cap-drop ALL. Il processo è
ancora root, ma senza NET_RAW non può aprire il socket raw: fallisce.

    dropall=$(docker run --rm --cap-drop ALL busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

### Fase 3 — Solo la chiave giusta (24.2 — TODO 3)

Completa il **TODO 3**: togli tutto e ridai solo NET_RAW. Il ping riprende, ma il
container ha esattamente una capability, non tutte — privilegio minimo.

    dropadd=$(docker run --rm --cap-drop ALL --cap-add NET_RAW busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- icapabilities.sh prova il ping con le capabilities di default (TODO 1).
- Lo riprova con --cap-drop ALL (TODO 2).
- Lo riprova con --cap-drop ALL --cap-add NET_RAW (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — con le capabilities di default il ping funziona (NET_RAW è concessa).
- **OK 2** — con --cap-drop ALL il ping fallisce: senza NET_RAW niente socket raw,
  pur essendo root.
- **OK 3** — con --cap-drop ALL --cap-add NET_RAW il ping riprende: al container è
  stata data solo la chiave necessaria.

## Domande di riflessione

**a.** root non è monolitico: il kernel spezza i suoi poteri in capabilities separate
(NET_RAW per i socket raw, NET_BIND_SERVICE per le porte basse, SYS_ADMIN per il
montaggio, e molte altre). Perché --cap-drop ALL seguito da --cap-add mirato è la
forma più pura del privilegio minimo, e perché Docker già di default ne toglie parecchie
al container?

**b.** seccomp è un secondo strato: un profilo che filtra quali syscall un container può
invocare, bloccando quelle pericolose (come keyctl, o ptrace verso altri processi) a
prescindere dalle capabilities. Perché è complementare alle capabilities e non
ridondante? E perché disattivarlo con --security-opt seccomp=unconfined è una scelta da
evitare, se non per debug consapevole?

**c.** AppArmor (Debian/Ubuntu) e SELinux (RHEL/Fedora — quello di questa macchina)
sono controlli di accesso obbligatori (MAC): confinano quali file e path un processo
può toccare, indipendentemente da uid e capabilities. Perché sono un terzo strato di
difesa in profondità, e come si combinano con capabilities e seccomp per ridurre la
superficie d'attacco complessiva di un container?

## Pulizia

Niente da smontare a mano: tutti i container sono usa-e-getta (--rm). L'immagine base
busybox resta in cache. Il demone non viene mai riavviato.

## Dove porta

Hai ristretto i privilegi di un container su tre livelli. La sicurezza però non è solo
prevenzione: quando qualcosa va storto, devi vederlo. Il **capitolo 25** apre il tema
dell'osservabilità — i log dei container, i driver di logging, le metriche — per
sapere cosa fa davvero un servizio in produzione. Per il riferimento, vedi le appendici
del volume.
