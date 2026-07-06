# Capitolo 8 — Un traduttore, due cantieri

**Livello:** Fondamentale
**Tempo stimato:** 45–55 minuti
**Argomenti del manuale:** l'architettura Core e Provider (8.1), il problema centrale: l'autenticazione (8.2), autenticazione su AWS: i ruoli (8.3), Azure e Google Cloud (8.4), il caso on-premise: vSphere (8.5), provider multipli e alias (8.6), la regola d'oro della sicurezza (8.7)

## L'idea

Nel capitolo 6 hai pesato il traduttore: un binario da decine di megabyte
dentro .terraform. Ma il binario da solo non basta: bisogna dirgli *con
quale mondo* parlare — e questo è il mestiere del blocco provider. Qui lo
scopri nel modo più concreto possibile: costruisci un **secondo datacenter
sulla tua macchina** (un Docker dentro Docker: un engine vero, separato,
raggiungibile via rete) e configuri *due istanze dello stesso traduttore* —
la linea di default verso il cantiere di Milano e una linea con alias verso
quello di Francoforte. Poi piazzi lo stesso nginx in entrambi, decidendo la
destinazione risorsa per risorsa con una sola riga: provider =.

La seconda metà del capitolo è da leggere, non da eseguire: una galleria di
blocchi provider veri — AWS coi ruoli, vSphere con la password nel posto
sbagliato e poi in quello giusto — per arrivare alla regola d'oro: il
codice dice *dove* e *come* connettersi, mai *chi sei*: i segreti vivono
fuori dal codice, sempre.

## Obiettivi

Alla fine saprai:

- distinguere il provider-binario (il traduttore installato da init) dal
  blocco provider (la linea configurata verso un sistema reale);
- dichiarare più istanze dello stesso provider con alias, e piazzare ogni
  risorsa col meta-argomento provider =;
- leggere un blocco provider AWS con assume_role e spiegare perché i ruoli
  battono le chiavi statiche;
- riconoscere al volo il peccato capitale (credenziali nel codice) e la
  sua correzione;
- dire che cosa distrugge tofu destroy in uno scenario multi-provider — e
  che cosa non tocca.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione, con la possibilità di lanciare un container
  privilegiato (serve al datacenter numero due).
- Porte libere: 8091, 8092 e 23750.

## Consegna

### Fase 0 — Il secondo datacenter

Il cantiere di Milano ce l'hai già: è il tuo Docker locale. Francoforte va
costruita — ed è un container privilegiato con dentro un intero engine
Docker, che esponi via rete sulla porta 23750:

    docker run -d --name cap08-frankfurt-dc --privileged \
      -e DOCKER_TLS_CERTDIR="" \
      -p 127.0.0.1:23750:2375 -p 127.0.0.1:8092:8092 \
      docker:27-dind

Dagli qualche secondo per avviarsi, poi verifica che i due mondi rispondano
e siano *davvero* separati:

    docker info --format '{{.ServerVersion}}'
    docker -H tcp://127.0.0.1:23750 info --format '{{.ServerVersion}}'
    docker -H tcp://127.0.0.1:23750 ps

Due engine, due inventari, due versioni potenzialmente diverse. (Nota
onesta: la 23750 è in chiaro, senza TLS, legata a 127.0.0.1 — una
scorciatoia da laboratorio. In produzione quella linea sarebbe cifrata:
tcp+TLS o ssh://.)

### Fase 1 — Le due linee (TODO 1)

Apri start/main.tf: il blocco terraform dichiara il traduttore docker — uno
solo, e init ne installerà uno solo. Le *linee* verso i due mondi sono
un'altra cosa, e la seconda la scrivi tu:

    provider "docker" {}

    provider "docker" {
      alias = "frankfurt"
      host  = "tcp://127.0.0.1:23750"
    }

Stesso tipo, due configurazioni: la prima (senza alias) è la linea di
default; la seconda ha un nome, e chi vuole usarla dovrà chiederla per
nome. Il blocco provider è questo: non il traduttore, ma il suo telefono —
con scritto quale numero chiamare.

### Fase 2 — Lo stesso nginx, in due mondi (TODO 2)

Le risorse di Milano sono già scritte: guardale, sono il capitolo 6. Il
TODO 2 ti chiede le gemelle di Francoforte: stessa immagine, stesso
container (porta 8092), più UNA riga che cambia tutto:

    provider = docker.frankfurt

È il meta-argomento di piazzamento: senza, la risorsa va sulla linea di
default; con, va dove dici tu. Nota che serve su *entrambe* le risorse di
Francoforte — anche l'immagine va scaricata *in quel* datacenter: i due
engine non condividono nulla, nemmeno la cache delle immagini.

    tofu init
    tofu apply

### Fase 3 — Chi vede che cosa

    tofu state list
    docker ps
    docker -H tcp://127.0.0.1:23750 ps
    curl http://127.0.0.1:8091
    curl http://127.0.0.1:8092

Quattro risorse in un solo state — ma Milano vede solo il suo container, e
Francoforte solo il suo. Il piazzamento non è un contesto implicito (una
variabile d'ambiente, un "docker context" attivo): è *scritto nel codice*,
risorsa per risorsa, e sopravvive a chiunque esegua l'apply da qualunque
terminale. Entrambi i curl rispondono: benvenuto nella multi-region da
tavolo.

### Fase 4 — La galleria dell'autenticazione (si legge, non si esegue)

Con Docker la connessione era un socket o un URL. Coi cloud la domanda
diventa: *chi sei tu per fare queste chiamate?* In start/examples/ trovi
due file .tf.example (l'estensione li rende invisibili a tofu: sono da
leggere):

- **aws.tf.example** — la scala della fiducia: nel blocco provider non
  c'è NESSUNA credenziale (arrivano da fuori: variabili d'ambiente o
  profilo), e il gradino sopra è assume_role — chiavi personali che
  ottengono credenziali *temporanee* di un ruolo, con permessi delimitati
  e scadenza. Azure e Google seguono lo stesso principio con le rispettive
  identità (Managed Identity / service account, o la CLI aziendale).
- **vsphere.tf.example** — il caso on-premise, in due versioni: quella col
  peccato capitale (username e password *scritti nel .tf*, destinati a
  finire in git per sempre) e quella corretta (il blocco dice solo il
  server; le credenziali arrivano da variabili d'ambiente).

La regola d'oro, che vale da Docker a AWS: il codice dichiara dove e come
connettersi; l'identità e i segreti vivono fuori — ambiente, file
ignorati, vault. Un segreto committato è compromesso per sempre: la
history di git non dimentica.

### Fase 5 — La demolizione asimmetrica

    tofu destroy
    docker ps
    docker -H tcp://127.0.0.1:23750 ps -a

I quattro oggetti sono spariti — da *entrambi* i mondi, ciascuno tramite la
sua linea. Ma il datacenter di Francoforte è ancora lì: l'hai creato a
mano, e tofu (capitolo 6) demolisce solo ciò che ha costruito lui. La
simmetria la chiudi tu:

    docker rm -f cap08-frankfurt-dc

### Pulizia

Fatta nella Fase 5 (destroy + rimozione del dind). Le immagini nginx
restano (keep_locally, solo lato Milano); docker rmi se le vuoi togliere.

## Criteri di "fatto"

- I due engine rispondevano separatamente (docker info locale e via
  tcp://127.0.0.1:23750).
- tofu state list mostrava 4 risorse; docker ps ne vedeva una per engine
  (più il dind, lato Milano).
- Entrambi i curl (8091 e 8092) rispondevano con la pagina di nginx.
- Dopo il destroy: engine di Francoforte vuoto, ma container
  cap08-frankfurt-dc ancora vivo — rimosso poi a mano.
- Hai letto i due .tf.example e sai indicare il peccato capitale e la sua
  correzione.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Traduttore e telefoni: che cosa ha installato init (quanti binari?)
e che cosa hanno configurato i due blocchi provider? Perché l'immagine di
Francoforte aveva bisogno anche lei di provider = docker.frankfurt — che
cosa ti dice questo su ciò che i due mondi (non) condividono? E che cosa
sarebbe successo a una risorsa senza meta-argomento provider?

**b.** La scala della fiducia: nel blocco AWS della galleria non c'è
nessuna credenziale — da dove arrivano? Che cosa aggiunge assume_role
rispetto alle chiavi statiche (pensa a durata, perimetro e revoca), e
perché "la password nel .tf" di vSphere è un danno *permanente* e non solo
un errore di stile?

**c.** La demolizione asimmetrica: elenca che cosa ha rimosso il destroy
(e attraverso quali linee) e che cosa ha lasciato. Perché il confine
"distruggo solo ciò che ho creato" è la scelta giusta anche qui? E la
scorciatoia del laboratorio — la 23750 in chiaro — che cosa richiederebbe
in produzione?
