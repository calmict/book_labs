# Capitolo 25 — Il tempo giusto

**Livello:** Cloud Architect

Finora hai orchestrato pochi nodi, e a pochi nodi ogni playbook sembra veloce. Ma la fascia Cloud
Architect comincia da una domanda diversa: cosa succede quando i nodi diventano **mille**? A quella
scala un secondo di troppo per host non è un secondo — è un'attesa che non finisce, moltiplicata per
mille, ripetuta a ogni deploy. Il collo di bottiglia non è più *cosa* fa il playbook, ma *come*
Ansible lo distribuisce sulla flotta. Questo capitolo ti dà le leve per stringere quel tempo: quanti
nodi guidare insieme (**forks**), se farli marciare in lock-step o lasciarli correre (**strategie**),
e come non pagare lavoro che non serve (**domare i fatti**). Le misuri su una flotta vera — dodici
nodi — e le vedi mordere: la stessa consegna passa da ~24 secondi a ~8.

## Obiettivi

- Perché a **larga scala** il problema cambia natura: non il task, ma la distribuzione (25.1).
- **forks**: quanti nodi Ansible guida in parallelo, e perché "a ondate" costa (25.2).
- **Strategie** — linear contro free: la barriera per-task e come toglierla (25.3).
- **Pipelining** e ControlPersist: meno round-trip SSH per task (25.4).
- **Domare i fatti**: gather_facts off, gather_subset, fact caching (25.5).
- **Mitogen**: il plugin di strategia che riscrive l'esecuzione — potente e impegnativo (25.6).
- **Misurare, non indovinare**: il callback profile_tasks (25.7).

## Prerequisiti

- Il venv del capitolo 6 con **ansible-core** (in start/requirements.txt): nient'altro, la flotta è
  fatta di host locali.
- L'**ansible.cfg** del capitolo 7 (qui è dove vive una delle tre leve) e le **strategie** come
  concetto: le hai sfiorate col parallelismo del capitolo 9.
- I **fatti** del capitolo 2 e le **variabili** del capitolo 12: qui decidi *quando* vale la pena
  raccoglierli.

## Lo scenario

start/ contiene una consegna che *funziona* ma è inutilmente lenta. inventory.ini descrive una
**flotta di 12 nodi**, tutti locali (ansible_connection=local, così l'esercizio non costa nulla), ma
ciascuno con un carico diverso: t1 e t2 sono i secondi che i due passi della consegna impiegano su
quel nodo. Lo squilibrio è il punto — alcuni nodi sono rapidi, altri lenti, e un nodo lento non deve
tenere in ostaggio quelli rapidi.

deploy.yml fa scorrere due passi (una "sleep" fa da lavoro reale per host) sulla flotta. Così com'è
gira a ondate, in lock-step, e raccoglie fatti che nessuno usa. Tre lacune la rallentano; le colmi e
misuri il guadagno.

Prepara l'ambiente:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Fase 1 — Il problema cambia natura (25.1)

Con tre nodi non ti accorgi di niente. Con mille, l'aritmetica domina. Se Ansible guida i nodi a
ondate, il tempo totale non è quello del nodo più lento: è quello del più lento **moltiplicato per il
numero di ondate**. Se ogni play aspetta che tutti finiscano un task prima che qualcuno cominci il
successivo, i nodi rapidi stanno fermi a ogni passo. Se ogni play raccoglie fatti che non guarda,
paghi un giro di setup su mille nodi per niente. Nessuno di questi costi si vede a scala piccola;
tutti diventano dominanti a scala grande. Le leve di questo capitolo tolgono, una a una, questi
sprechi. Prima misura il punto di partenza:

    time ansible-playbook deploy.yml

Tieni il numero a mente: è il metro contro cui misurerai ogni miglioramento.

### Fase 2 — forks (25.2 — TODO 1)

forks è **quanti nodi Ansible guida contemporaneamente**. Non rende ogni nodo più veloce: decide in
quante ondate serve la flotta. Dodici nodi a forks=4 sono tre ondate, e la corsa non può durare meno
del nodo più lento moltiplicato per il numero di ondate, per quanto banale sia il lavoro. Apri
start/ansible.cfg: forks è basso di proposito. Completa il **TODO 1** portandolo alla dimensione
della flotta —

    [defaults]
    inventory = inventory.ini
    forks = 12

Ora le ondate collassano in una: la corsa è limitata dal singolo nodo più lento, non dalla dimensione
della flotta. È la vittoria più economica a scala, la prima leva da toccare. Con una cautela che il
manuale sottolinea: ogni fork è lavoro, memoria e una connessione SSH sul **control node**, quindi su
flotte vere forks si alza con criterio, non all'infinito.

### Fase 3 — Strategie: linear contro free (25.3 — TODO 2)

La strategia predefinita è **linear**, e linear mette una **barriera a ogni task**: nessun nodo
comincia il task N+1 finché *tutti* non hanno finito il task N. Su una flotta con carichi diversi
significa che i nodi rapidi restano fermi a ogni barriera ad aspettare il più lento — e pagano questa
tassa una volta per task. La strategia **free** toglie la barriera: ogni nodo scorre la propria lista
di task il più in fretta che può, e il play finisce quando l'ultimo nodo ha finito. Completa il
**TODO 2** in deploy.yml —

    strategy: free

Il guadagno cresce con lo squilibrio e col numero di task — esattamente la forma di una consegna
reale. Il compromesso, e il motivo per cui linear è il default, è che free rinuncia alla garanzia del
lock-step: con free non puoi più assumere che tutta la flotta abbia superato un passo prima che un
nodo vada oltre. Quando l'ordine conta — le consegne orchestrate — serve il controllo del capitolo 27.

### Fase 4 — Pipelining (25.4)

Le prime due leve riducono l'attesa; il pipelining riduce il **numero di operazioni SSH** per task.
Senza, un modulo è la copia di un file sul nodo seguita da una sua esecuzione separata: più round-trip
a task. Col pipelining Ansible passa il modulo sulla connessione già aperta — un round-trip solo per
task. Unito a ControlPersist (la connessione SSH riusata del capitolo 3) è un grosso guadagno su
flotte vere. Si abilita in ansible.cfg:

    [ssh_connection]
    pipelining = True

Due avvertenze: richiede **requiretty spento** nei sudoers del target (altrimenti sudo rifiuta lo
stdin), e non fa nulla per le connessioni locali — ecco perché questa flotta node-less lo lascia come
lettura e misura invece forks, strategia e fatti.

### Fase 5 — Domare i fatti (25.5 — TODO 3)

Ogni play, per default, raccoglie i fatti: prima del primo task Ansible esegue un **setup** implicito
su ogni nodo — un giro completo — per apprenderne le variabili. Giustissimo quando quei fatti li usi,
puro spreco quando non li usi. Questa consegna non ne referenzia nemmeno uno, quindi l'intera raccolta
è costo senza beneficio. Completa il **TODO 3** in deploy.yml —

    gather_facts: false

Rilancia con profile_tasks (fase 7) e vedrai la riga "Gathering Facts" **sparire**. Quando un task più
avanti *ha* bisogno di un fatto, non riaccendi la raccolta sull'intera flotta a ogni run: la **cachi**
(fact caching) così il setup si paga una volta e si riusa, o la limiti con gather_subset. Off di
default più caching è la scelta scalabile; raccogli-tutto-ogni-volta è l'abitudine da disimparare.

### Fase 6 — Mitogen (25.6)

Quando le leve integrate sono spese e non basta, resta **Mitogen**: un plugin di strategia di terze
parti che riscrive il modo in cui Ansible spedisce ed esegue il codice sul target, spesso più volte
più veloce. È genuinamente potente e genuinamente un impegno maggiore: una dipendenza esterna, legata
a versioni precise di Ansible, che cambia la semantica di esecuzione. Il manuale lo presenta come
l'ultima risorsa deliberata e misurata, dopo che le leve di questo capitolo sono state usate — non
come prima mossa.

### Fase 7 — Misurare, non indovinare (25.7)

Tutto questo si decide sui numeri, non sulle sensazioni. **profile_tasks** è un callback integrato che,
attivato, stampa quanto è costato ogni task: leggi quali task pesano davvero, poi accorda quelli.

    ANSIBLE_CALLBACKS_ENABLED=profile_tasks ansible-playbook deploy.yml

Confronta il profilo del punto di partenza con quello della versione accordata: la riga "Gathering
Facts" c'è nel primo e sparisce nel secondo, e i due passi non si sommano più in lock-step. Domanda a.

## Criteri di "fatto"

- ansible.cfg porta **forks = 12** (TODO 1): la flotta gira in una sola ondata.
- deploy.yml usa **strategy: free** (TODO 2): niente barriera per-task.
- deploy.yml usa **gather_facts: false** (TODO 3): niente setup inutile.
- La consegna accordata è **nettamente più veloce** di quella di partenza (qui ~8s contro ~24s) e
  profile_tasks lo conferma: la raccolta fatti sparisce, i passi non marciano più in lock-step.

## Domande di riflessione

**a.** forks, strategia e fatti attaccano tre sprechi diversi. Descrivi, per ciascuno, *quale* attesa
elimina — e perché nessuno dei tre si nota a tre nodi ma tutti dominano a mille. Se potessi toccarne
**una sola** su una flotta con carichi molto sbilanciati, quale sceglieresti e perché?

**b.** free è più veloce di linear ma rinuncia al lock-step. Descrivi una consegna in cui questa
rinuncia è **pericolosa** — dove ti serve la garanzia che tutta la flotta abbia superato un passo
prima che qualsiasi nodo vada oltre. (Il capitolo 27 costruisce proprio quel controllo.)

**c.** gather_facts: false qui è puro guadagno perché la consegna non usa fatti. Ma un task più avanti
potrebbe averne bisogno. Perché la risposta scalabile è il **fact caching** e non "riaccendi la
raccolta a ogni run"? Cosa cambia, in termini di costo, tra pagare il setup una volta e pagarlo ogni
volta su mille nodi?

## Pulizia

Niente da smontare: la flotta è fatta di host locali, non ci sono container né nodi remoti. Chiudi il
venv con:

    deactivate

## Dove porta

Hai le leve per servire mille nodi in fretta (cap25). Ma la velocità da sola non basta a mandare in
produzione con serenità: serve che ogni modifica passi da un **controllo di versione** e da una
**pipeline** che la validi prima che tocchi un server. Il **capitolo 26** porta l'automazione dentro
il **CI/CD** — GitHub Actions, il gate di produzione — perché a questa scala non è più una persona a
lanciare il playbook: è la pipeline.
