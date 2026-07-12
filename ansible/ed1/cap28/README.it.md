# Capitolo 28 — Il teatro stabile

**Livello:** Cloud Architect

Il capitolo 27 ti ha dato il rilascio a ondate; il 26 la pipeline che lo lancia. Ma in tutti e due sei
ancora tu — o uno script — a battere un comando da un terminale, con inventari, credenziali e
"chi-può-fare-cosa" tenuti in testa o sparsi in file. Funziona per una persona. Non funziona per
un'**organizzazione**: dieci team, centinaia di playbook, migliaia di nodi, revisori e audit. A quel
punto il terminale non basta più — come una compagnia che gira di piazza in piazza non basta più
quando la città vuole una stagione stabile, con una sede, un botteghino, un organico e un archivio.
**AWX** (e la sua versione supportata, **Ansible Automation Platform**) è quel teatro stabile:
l'automazione smette di essere un gesto al terminale e diventa un **servizio** con una console, i suoi
permessi e la sua storia. Questo capitolo ne monta gli oggetti fondamentali — il **job template**, le
**credenziali con RBAC**, i **workflow** — non cliccando in una UI, ma definendoli **come codice**,
versionati e validati prima di entrare in scena. Perché il modo Cloud Architect di gestire la
piattaforma non è "clicca nella UI": è GitOps anche qui.

## Obiettivi

- Perché il **terminale non basta più** a scala di organizzazione (28.1).
- **AWX e Ansible Automation Platform**: chi è chi (28.2).
- Il concetto centrale: il **job template** (28.3).
- **Credenziali, RBAC e audit**: il governo dell'accesso (28.4).
- I **workflow**: incatenare i job con rami di successo e fallimento (28.5).
- Gli altri mattoni: **EE, scheduling, EDA** (28.6).
- Le **buone abitudini** con la piattaforma (28.7).

## Prerequisiti

- Il venv del capitolo 6 con **ansible-core** (in start/requirements.txt): non serve installare AWX —
  qui definisci e validi i suoi oggetti *come codice*, offline.
- Il **rilascio a ondate** del capitolo 27: i playbook che i job template eseguono sono proprio quel
  deploy (più smoke-test e rollback).
- I **lookup di segreti** del capitolo 19: la credenziale non *contiene* la chiave, la *riferisce*.
- La **pipeline** del capitolo 26: questo esercizio è il cancello che valida gli oggetti *prima*
  dell'import in AWX — GitOps applicato alla piattaforma stessa.

## Lo scenario

start/ ha due parti. project/ è ciò che in AWX si chiama **progetto**: i playbook veri che la
piattaforma eseguirà — deploy.yml, smoke.yml, rollback.yml. platform/objects.yml è il **grafo di
oggetti** di AWX definito come codice: progetti, inventari, credenziali, job template, concessioni RBAC
e un workflow. Nessun segreto vive qui: solo un riferimento a dove la piattaforma lo prenderà. Tre
lacune lasciano il grafo incompleto o insicuro; le colmi, e un **validatore pre-import** (quello che
gireresti in CI prima di caricare tutto in AWX) conferma che il grafo si risolve ed è sicuro.

Prepara l'ambiente:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Fase 1 — Perché il terminale non basta più (28.1)

Fin qui l'automazione è stata un atto individuale: apri un terminale, lanci un playbook. A scala di
organizzazione questo modello si rompe su quattro fronti. **Accesso**: chi può lanciare cosa, su quali
nodi? Un terminale non lo sa. **Segreti**: le credenziali finiscono sui portatili. **Tracciabilità**:
chi ha lanciato quel deploy, quando, con quale risultato? Nessuno lo sa. **Ripetibilità e
coordinamento**: incatenare deploy → test → rollback, su pianificazione, con approvazioni. Serve un
luogo dove l'automazione *vive* — con un organico (RBAC), un botteghino (chi entra), un archivio
(audit) e un cartellone (workflow, scheduling). Quel luogo è la piattaforma.

### Fase 2 — AWX e Ansible Automation Platform: chi è chi (28.2)

Sono lo stesso teatro, in due allestimenti. **AWX** è il progetto upstream, gratuito e community, dove
le funzionalità nascono per prime — l'edizione da sperimentare. **Ansible Automation Platform (AAP)** è
la versione commerciale e supportata di Red Hat, con SLA, contenuti certificati e gli Execution
Environment ufficiali — l'edizione per la produzione dell'organizzazione. Stesso modello a oggetti,
stessa API: job template, credenziali, workflow. Ciò che impari su uno vale sull'altro; qui lavori
sugli oggetti, che sono identici.

### Fase 3 — Il concetto centrale: il job template (28.3 — TODO 1)

Un **job template** è la ricetta di un lancio: quale **playbook**, preso da quale **progetto** (un repo
git), contro quale **inventario**, con quali **credenziali**. È l'oggetto che trasforma "un playbook
nel repo" in "un pulsante che qualcuno con i giusti permessi può premere". Apri platform/objects.yml:
il job template deploy è incompleto. Completa il **TODO 1**, legandolo agli oggetti che deve usare —

    job_templates:
      - name: deploy
        project: infra-playbooks
        inventory: production
        playbook: deploy.yml
        credentials: [deploy-ssh]
        limit: webfarm

Ogni riferimento deve **risolvere**: il progetto, l'inventario e la credenziale devono esistere fra gli
oggetti definiti, e il playbook deve esistere davvero nel progetto. Un template che punta a un
inventario inesistente o a un playbook mancante è un pulsante che, premuto, fallisce — ed è esattamente
ciò che il validatore rifiuta. Domanda a.

### Fase 4 — Credenziali, RBAC e audit: il governo dell'accesso (28.4 — TODO 2)

Qui la piattaforma guadagna il suo valore vero. Tre idee:

- **Credenziali**: il segreto (una chiave SSH, un token) **non è scritto nel grafo**. La credenziale lo
  *riferisce* — la piattaforma lo risolve a runtime da un gestore di segreti (capitolo 19). Guarda
  deploy-ssh: il campo secret è un lookup, non una chiave in chiaro. Il validatore rifiuta qualunque
  segreto in chiaro.
- **RBAC**: chi può fare cosa. Il principio è il **minimo privilegio**: dai il ruolo più stretto che
  basta, sulla risorsa più specifica. Il team deployers non deve amministrare l'organizzazione: deve
  poter **eseguire** il job template di deploy, e nient'altro.
- **Audit**: ogni lancio lascia una traccia — chi, quando, con quale esito. Non è un oggetto che
  definisci, è una proprietà che ottieni per il fatto stesso di passare dalla piattaforma invece che
  dal terminale.

Nel grafo la concessione RBAC è troppo ampia. Completa il **TODO 2**: restringila al minimo privilegio —

    rbac:
      - team: deployers
        role: execute
        resource: job_template:deploy

Il validatore rifiuta i ruoli ampi (admin, amministratore di sistema) e le concessioni su interi ambiti
(un'organizzazione, non una risorsa): pretende un ruolo stretto su una risorsa precisa che esiste.
Domanda b.

### Fase 5 — I workflow: incatenare i job (28.5 — TODO 3)

Un singolo job template lancia un playbook. Un **workflow** ne incatena diversi in un grafo, con rami
distinti per il **successo** e per il **fallimento**. È la coreografia del capitolo 27 portata al
livello della piattaforma: fai il deploy; se va bene, lancia lo smoke-test; se il deploy o lo smoke
falliscono, lancia il rollback. Nel grafo i nodi ci sono ma gli archi mancano. Completa il **TODO 3**:
collega i nodi —

    workflows:
      - name: release
        nodes:
          - id: n_deploy
            job_template: deploy
            success_nodes: [n_smoke]
            failure_nodes: [n_rollback]
          - id: n_smoke
            job_template: smoke-test
            failure_nodes: [n_rollback]
          - id: n_rollback
            job_template: rollback

Il validatore controlla che sia un **DAG ben formato**: ogni nodo esegue un job template esistente,
ogni arco punta a un nodo esistente, c'è una sola radice, non ci sono cicli — e c'è un **ramo di
fallimento che porta al rollback**. Un workflow che sa solo andare avanti, senza una via d'uscita
quando qualcosa si rompe, è metà del lavoro.

### Fase 6 — Gli altri mattoni: EE, scheduling, EDA (28.6)

La piattaforma è più larga di così. Gli **Execution Environment (EE)** sono immagini container con
Python, ansible-core e le collezioni: il job non gira in un venv improvvisato ma in un ambiente
**riproducibile e versionato** — la stessa idea del capitolo 24, standardizzata per tutta
l'organizzazione. Lo **scheduling** lancia i job template su un calendario (la compliance ogni notte).
L'**EDA (Event-Driven Ansible)** ribalta il verso: non più "una persona lancia", ma "un evento lancia"
— un allarme, un webhook, una riga di log fanno partire un rulebook. Sono i mattoni che trasformano il
teatro da "si alza il sipario quando qualcuno lo decide" a "la stagione va avanti da sé".

### Fase 7 — Le buone abitudini con la piattaforma (28.7)

- **Configuration as Code**: gli oggetti della piattaforma (template, credenziali, workflow) vivono in
  git e si caricano con import automatici, non a mano nella UI. È ciò che hai fatto qui, ed è ciò che
  permette a un validatore di fermare un errore *prima* dell'import (capitolo 26).
- **Minimo privilegio, sempre**: il ruolo più stretto, sulla risorsa più specifica. L'RBAC largo è
  comodo oggi e un incidente domani.
- **Il segreto si riferisce, non si scrive**: mai una chiave nel grafo; sempre un lookup a un gestore
  di segreti (capitolo 19).
- **Ambienti riproducibili**: EE versionati, non venv improvvisati sul nodo di controllo.
- **Ogni lancio lascia traccia**: passa dalla piattaforma, non dal terminale, così l'audit esiste per
  costruzione.

## Criteri di "fatto"

- Il job template deploy è completo e ogni suo riferimento risolve (TODO 1): progetto, inventario,
  credenziale esistono e il playbook è nel progetto.
- La concessione RBAC è al minimo privilegio (TODO 2): un ruolo stretto (execute) su una risorsa
  precisa (il job template), non admin su un'organizzazione.
- Il workflow è un DAG ben formato con un ramo di fallimento verso il rollback (TODO 3).
- Il validatore pre-import accetta il grafo: i riferimenti si risolvono, i segreti sono riferiti non
  scritti, l'accesso è scoped, il workflow è valido.

## Come viene verificato

solution/run.sh è il **cancello pre-import**, tutto in locale e senza rete (nessun AWX richiesto):

1. **I playbook del progetto sono veri**: syntax-check su deploy.yml, smoke.yml, rollback.yml — i job
   template puntano a playbook che esistono e sono ben formati.
2. **Il grafo è valido e sicuro**: il validatore accetta il grafo completo — riferimenti risolti,
   nessun segreto in chiaro, RBAC scoped, workflow un DAG con ramo di fallimento.
3. **I controlli mordono davvero**: run.sh introduce, una alla volta, un riferimento pendente, una
   concessione RBAC troppo ampia, un segreto in chiaro e un workflow senza ramo di fallimento — e
   pretende che il validatore **rifiuti** ciascuno. È esattamente ciò che AWX (o la tua revisione)
   rifiuterebbe.

## Domande di riflessione

**a.** Un job template lega un playbook a un progetto, un inventario e una credenziale. Perché questo
"impacchettamento" è ciò che permette a un non-esperto di lanciare in sicurezza un'automazione che non
capisce fino in fondo — e cosa si perderebbe a dare a quella persona, invece, l'accesso al terminale
con lo stesso playbook?

**b.** Il minimo privilegio dice: ruolo più stretto, risorsa più specifica. Dai un esempio concreto di
incidente che una concessione execute-sul-singolo-template previene ma un ruolo admin-sull'organizzazione
no. Perché l'audit (chi-ha-fatto-cosa) perde gran parte del suo valore se tutti hanno ruoli larghi?

**c.** Il workflow ha un ramo di fallimento verso il rollback. Perché un workflow che sa solo "andare
avanti in caso di successo" è pericoloso quanto il rilascio senza freno del capitolo 27? Che rapporto
c'è tra il failure_nodes → rollback qui e il block/rescue/always di un playbook?

## Pulizia

Niente da smontare: nessun AWX, nessun container, nessun nodo remoto. Il grafo è solo file di testo.
Chiudi il venv con:

    deactivate

## Dove porta

Con il capitolo 28 l'automazione ha una casa: gli oggetti della piattaforma definiti come codice,
l'accesso governato, i job incatenati in workflow con una via d'uscita. **Chiude la fascia Cloud
Architect e chiude il manuale**: dai tre modi di rompersi del capitolo 1, sei arrivato a orchestrare
mille nodi da una piattaforma con la sua governance. Il direttore d'orchestra ora ha il suo teatro
stabile. Da qui in poi non ci sono nuovi concetti da imparare, ma un mestiere da affinare: le
**appendici** ti danno gli strumenti da tavolo — il cheat sheet dei comandi, i filtri Jinja2
essenziali, la mappa della precedenza delle variabili, il glossario, il troubleshooting, e le risorse
per la certificazione — perché il teatro, una volta costruito, si tiene aperto ogni sera.
