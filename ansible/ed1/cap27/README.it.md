# Capitolo 27 — Senza fermare la musica

**Livello:** Cloud Architect

Il capitolo 26 ti ha dato la macchina di scena che porta una modifica fino alla porta della
produzione. Ma il job di deploy era una riga di echo, e ora arriva la domanda vera: *come* si aggiorna
una flotta di mille nodi **senza spegnere il servizio**? Applicare a tutti insieme è un disservizio —
per qualche secondo o minuto, ogni backend è giù nello stesso momento. Un direttore d'orchestra non
ferma tutta l'orchestra per far cambiare l'arco a un violinista: fa entrare e uscire le sezioni una
alla volta, e la musica non si interrompe mai. Questo è l'**orchestrazione**: il rolling update.
Questo capitolo ti dà le leve — **serial** (aggiorna a ondate), **delegate_to** (di' al bilanciatore
di togliere il nodo dal giro prima di toccarlo), la **coreografia** pre_tasks/tasks/post_tasks (drena
→ aggiorna → ri-abilita), e **max_fail_percentage** (il freno d'emergenza che ferma tutto se un'ondata
va male) — e le vedi all'opera su una web-farm dove, in ogni istante, non più di un'ondata è fuori dal
giro.

## Obiettivi

- Dall'**automazione all'orchestrazione**: perché "applica a tutti" non basta più (27.1).
- La prima leva: **serial** e i rilasci a ondate (27.2).
- La seconda leva: **delegate_to** col bilanciatore (27.3).
- La **coreografia completa**: pre_tasks, tasks, post_tasks (27.4).
- Il **freno d'emergenza**: max_fail_percentage (27.5).
- Quando qualcosa va storto: **rollback e recupero** (27.6).
- Coordinare **più livelli e più gruppi** (27.7).
- Le **buone abitudini** con l'orchestrazione (27.8).

## Prerequisiti

- Il venv del capitolo 6 con **ansible-core** (in start/requirements.txt): niente altro, la flotta è
  locale.
- Le **pre_tasks/post_tasks** e i **gruppi** dell'inventario (cap08, cap10): qui diventano la
  coreografia del rilascio.
- L'idea di **check dopo il cambiamento** (cap14): un'ondata si valida prima di passare alla
  successiva.
- Nessun account cloud e nessun nodo remoto: la web-farm e il bilanciatore sono host locali; lo stato
  del pool è un file, così il rollout si vede.

## Lo scenario

start/ contiene un rilascio a ondate su una **web-farm di 6 nodi** (gruppo webfarm) dietro un
**bilanciatore** (host balancer) — tutti locali. Il pool del bilanciatore, che di solito è invisibile,
qui è un **file-registro**: ogni volta che un nodo esce dal giro (DRAIN), viene aggiornato (UPDATED) o
rientra (ENABLE), la riga finisce nel registro, con un timestamp. Così puoi *vedere* il rollout mentre
accade — e il test può verificarlo. Il playbook site.yml fa la coreografia, ma tre lacune lo lasciano
pericoloso: aggiorna tutti insieme, dimentica di rimettere i nodi nel giro, e non ha freno. Le colmi.

Prepara l'ambiente:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

E, per guardare il pool mentre gira:

    : > /tmp/cap27-pool.log       # svuota il registro
    ansible-playbook site.yml
    cat /tmp/cap27-pool.log       # le ondate, riga per riga

### Fase 1 — Dall'automazione all'orchestrazione (27.1)

Fin qui Ansible ha risposto a "porta N nodi allo stato desiderato". L'**orchestrazione** aggiunge una
dimensione: *in che ordine, con quali pause, con quali controlli tra un passo e l'altro*. La
differenza è quella tra "aggiorna i sei nodi" e "aggiorna due nodi, controlla che stiano bene, poi
altri due, poi gli ultimi due — e se un'ondata crolla, fermati". La prima è automazione; la seconda
tiene in piedi il servizio mentre lo cambi. A mille nodi non è un lusso: è l'unico modo di rilasciare
senza un buco di disservizio.

### Fase 2 — La prima leva: serial e i rilasci a ondate (27.2 — TODO 1)

Per default Ansible applica un play a **tutti** gli host del gruppo in parallelo (fino al limite dei
forks). Su una web-farm significa: tutti i backend giù nello stesso momento. **serial** spezza il play
in **ondate**: Ansible esegue l'intero play — pre_tasks, tasks, post_tasks — per un piccolo lotto di
host, poi passa al successivo. Completa il **TODO 1** sul play —

    serial: 2

Con serial: 2 su una farm di 6, il rilascio procede in **tre ondate** da due. In ogni istante al
massimo due nodi sono fuori dal giro: la capacità non scende mai sotto 6 − 2 = 4. serial accetta anche
una lista (serial: [1, 2, "50%"]) per fare un'ondata piccola "canarino" e poi allargare. La regola
dietro la scelta di serial: quanti nodi puoi togliere senza scendere sotto la capacità di picco?
Quello è il tuo numero. Domanda a.

### Fase 3 — La seconda leva: delegate_to col bilanciatore (27.3)

Togliere un nodo dal giro non è un'azione che si fa **sul nodo**: si fa **sul bilanciatore**, che è
chi smista il traffico. Ma il play gira "sul nodo web" (è lì che aggiorni). **delegate_to** risolve
esattamente questo: esegue un singolo task su un *altro* host, tenendo il contesto del nodo corrente.
Guarda la pre_task già scritta —

    - name: Take the host out of the pool
      ansible.builtin.shell: 'echo "... DRAIN {{ inventory_hostname }} ..." >> {{ ledger }}'
      delegate_to: "{{ lb_host }}"

Il task riguarda inventory_hostname (il nodo web), ma **viene eseguito sul bilanciatore** (lb_host). È
il bilanciatore a dover smettere di mandare traffico lì prima che tu lo tocchi. Senza delegate_to,
"togli dal pool" verrebbe eseguito sul nodo che stai per spegnere — chiederesti al paziente di
operarsi da solo. Domanda c.

### Fase 4 — La coreografia completa: pre_tasks, tasks, post_tasks (27.4 — TODO 2)

Un rilascio sicuro ha tre movimenti, e con serial si ripetono a ogni ondata:

    pre_tasks:   drena     -> togli il nodo dal giro (delegate_to bilanciatore)
    tasks:       aggiorna  -> applica la nuova release sul nodo
    post_tasks:  ri-abilita -> rimetti il nodo nel giro (delegate_to bilanciatore)

Nel play trovi le prime due; manca la terza — la metà che tutti dimenticano. Se non rimetti il nodo
nel giro, ogni ondata lascia due backend fuori per sempre: a fine rollout la farm è in piedi ma serve
a metà capacità. Completa il **TODO 2**: aggiungi il blocco post_tasks che rimette il nodo nel pool,
speculare al drain —

    post_tasks:
      - name: Put the host back in the pool
        ansible.builtin.shell: 'echo "... ENABLE {{ inventory_hostname }} ..." >> {{ ledger }}'
        delegate_to: "{{ lb_host }}"
        changed_when: false

Ora la coreografia è chiusa: drena → aggiorna → ri-abilita, un'ondata alla volta, e il registro mostra
ogni nodo uscire e rientrare.

### Fase 5 — Il freno d'emergenza: max_fail_percentage (27.5 — TODO 3)

Un rilascio a ondate, senza freno, ha ancora un difetto: se la nuova release è rotta, la prima ondata
fallisce… e Ansible passa comunque alla seconda, e alla terza — propaghi il guasto su tutta la farm,
un'ondata alla volta. **max_fail_percentage** è il freno: se in un'ondata la quota di host falliti
supera la soglia, il play **si ferma** e non tocca il resto della flotta. Completa il **TODO 3** sul
play —

    max_fail_percentage: 25

Con ondate da due, un solo nodo fallito è il 50% dell'ondata: supera il 25%, e il rollout si arresta
lì — i nodi delle ondate successive non vengono nemmeno sfiorati. Il valore è una decisione di
rischio: 0 significa "un solo fallimento e fermati" (il più severo); una percentuale più alta tollera
qualche nodo difettoso prima di dare l'allarme. Domanda b.

### Fase 6 — Quando qualcosa va storto: rollback e recupero (27.6)

Il freno ferma la propagazione, ma lascia una ferita: **l'ondata in volo resta a metà**. Quando il
rollout si arresta, i nodi di quell'ondata sono già stati drenati (fuori dal giro) e magari aggiornati
a metà — ma non ri-abilitati. Il registro lo mostra: dopo un arresto, qualche nodo è DRAIN senza
ENABLE. Ecco perché serve un **recupero**. Le strade:

- **block/rescue/always** (cap22): metti drena/aggiorna in un block, e la ri-abilitazione in always,
  così un nodo viene rimesso nel giro *anche se* l'aggiornamento fallisce.
- **Un serial piccolo è già sicurezza**: meno nodi in volo, meno danno da riparare quando ci si ferma.
  Il raggio d'esplosione è limitato per costruzione.
- **Rollback vero**: una release precedente pronta, e un playbook di ritorno che ri-applica la
  versione buona alle ondate già toccate.

Il punto: l'orchestrazione non è solo "andare avanti bene", è "**fermarsi bene**" — sapere in che
stato ti lascia un arresto e avere il modo di rientrare.

### Fase 7 — Coordinare più livelli e più gruppi (27.7)

Un'applicazione reale non è un solo gruppo: web, database, cache, bilanciatori. L'ordine tra i livelli
conta — di solito il database prima delle web, i bilanciatori per ultimi. Si esprime con **più play
nello stesso playbook**, uno per gruppo, nell'ordine giusto; con **run_once** per le azioni che vanno
fatte una sola volta (una migrazione di schema, non su ogni nodo); e con **delegate_to** per agire su
un livello mentre se ne aggiorna un altro. Stesso vocabolario — serial, delegate_to, pre/post —
orchestrato su più sezioni invece che una.

### Fase 8 — Le buone abitudini (27.8)

- **Mai tutti insieme**: serial sempre, su qualunque flotta che serve traffico. Il default (tutti) è
  per i lab, non per la produzione.
- **Drena e ri-abilita, sempre in coppia**: un nodo che esce dal giro deve rientrarci; la
  ri-abilitazione va dove non la salti (post_tasks o always).
- **Il freno prima del rilascio**: max_fail_percentage impostato *prima*, non aggiunto dopo il primo
  incidente.
- **Fermarsi bene**: sappi in che stato ti lascia un arresto e abbi il recupero pronto (rescue/always,
  rollback).
- **Ondata canarino**: serial: [1, ...] — un nodo solo per primo, così un guasto si vede sul minimo
  danno possibile.

## Criteri di "fatto"

- Il play ha serial: 2 (TODO 1): il rilascio procede a ondate, mai tutta la farm insieme.
- Il play ha le post_tasks che ri-abilitano il nodo (TODO 2): ogni nodo drenato rientra nel giro.
- Il play ha max_fail_percentage: 25 (TODO 3): un'ondata che fallisce ferma il rollout.
- Il registro del pool lo conferma: ogni nodo esce e rientra, e **in ogni istante non più di un'ondata
  (2) è fuori dal giro**.

## Come viene verificato

solution/run.sh lo dimostra, tutto in locale e senza rete:

1. **La coreografia rolling**: esegue il rilascio sano e ricostruisce dal registro che tutti e 6 i
   nodi sono stati drenati, aggiornati e ri-abilitati, e che **mai più di 2** (serial) erano fuori dal
   pool nello stesso momento.
2. **Il freno d'emergenza**: esegue il rilascio con un nodo che fallisce l'aggiornamento e pretende
   che il rollout si **fermi** dopo la prima ondata — i nodi del resto della farm non vengono mai
   toccati.
3. **Perché le ondate contano**: allarga l'ondata all'intera farm e mostra che l'intero pool (6 nodi)
   va giù nello stesso istante — il disservizio che serial esiste per evitare.

## Domande di riflessione

**a.** serial: 2 su una farm di 6 tiene sempre almeno 4 nodi nel giro. Come scegli il numero su una
flotta vera? Se la farm regge il picco solo con almeno l'80% dei nodi attivi, qual è il serial massimo
che puoi usare — e cosa cambia se lo esprimi come percentuale invece che come numero fisso mentre la
farm cresce?

**b.** Il freno ferma la propagazione ma lascia l'ondata in volo a metà (drenata, non ri-abilitata).
Perché un serial **piccolo** è già di per sé una forma di sicurezza per il recupero? E perché mettere
la ri-abilitazione in un always (o rescue) invece che in normali post_tasks cambia cosa succede quando
un aggiornamento fallisce a metà?

**c.** Il drain e l'enable usano delegate_to verso il bilanciatore. Cosa si romperebbe, concretamente,
se togliessi delegate_to e la "rimozione dal pool" venisse eseguita sul nodo web che stai per
aggiornare? Perché l'azione sul bilanciatore è l'unica che ha senso?

## Pulizia

Niente da smontare: nessun nodo remoto, nessun container, nessun account cloud. Il registro è solo un
file:

    rm -f /tmp/cap27-pool.log
    deactivate

## Dove porta

Sai rilasciare su una flotta senza spegnere il servizio: a ondate, con il bilanciatore nel giro, con
un freno e un recupero (cap27). Ma finora sei tu — o la tua pipeline — a lanciare, e a tenere in testa
inventari, credenziali, chi-può-fare-cosa. All'ultimo gradino Cloud Architect, il **capitolo 28**
porta tutto questo dentro una piattaforma: **AWX e Automation Platform** — il job template, RBAC e
audit, i workflow, gli Execution Environment — perché a scala di organizzazione l'automazione stessa
diventa un servizio con la sua console, i suoi permessi e la sua storia.
