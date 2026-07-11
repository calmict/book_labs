# Capitolo 16 — La sezione

**Livello:** Intermedio

Il playbook del capitolo 15 sa decidere e ripetere — ma è cresciuto: task, variabili,
template, handler, tutto ammucchiato in un file solo. Domani un secondo progetto vorrà la
stessa app: copi e incolli? Il **ruolo** è la risposta. È una **sezione** dell'orchestra:
un blocco autonomo, con dentro i suoi task, i suoi file, la sua accordatura predefinita, che
il direttore richiama con un nome — e che puoi riusare in qualsiasi concerto. In questo
capitolo trasformi quel playbook gonfio in un ruolo pulito, e il playbook torna a essere tre
righe.

## Obiettivi

- Il **problema**: il playbook che non smette di crescere (16.1).
- **Cos'è un ruolo**: una cartella con struttura precisa (16.2, 16.3).
- Il playbook che **diventa minuscolo** (16.4).
- **defaults contro vars**: il cuore della riusabilità (16.5).
- **files e templates**: niente più percorsi (16.6).
- **meta e dipendenze** (16.7); **include_role e import_role** (16.8).
- Lo scheletro con **ansible-galaxy init** (16.9); anatomia di un buon ruolo (16.10).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- Docker per un nodo. Rete alla prima accensione.
- Template, variabili e handler dei capitoli 12, 14, 15; la precedenza del capitolo 13.

## Lo scenario

Prendi la configurazione di una web app e la impacchetti nel ruolo **webapp**: una cartella
con task, template, file statico, handler, e due tipi di variabili. Il playbook che lo usa
sarà lungo tre righe. E scoprirai perché alcune variabili del ruolo si lasciano cambiare
dall'esterno e altre no.

## Consegna passo-passo

### Fase 0 — Accendi il nodo

    bash start/nodes.sh up

Un container (web1) con l'utente deploy.

### Fase 1 — Il problema, e cos'è un ruolo

Un ruolo è una **cartella con una struttura precisa**: ogni tipo di contenuto ha la sua
sotto-cartella, e ognuna ha un main.yml che Ansible carica da solo.

    roles/webapp/
    ├── defaults/main.yml      # variabili sovrascrivibili (le manopole)
    ├── vars/main.yml          # variabili interne (protette)
    ├── tasks/main.yml         # cosa fa il ruolo
    ├── handlers/main.yml      # i suoi handler
    ├── templates/app.conf.j2  # i suoi template
    ├── files/motd             # i suoi file statici
    └── meta/main.yml          # metadati e dipendenze

Non devi ricordarla a memoria: **ansible-galaxy init** te la crea (16.9):

    ansible-galaxy init roles/webapp

crea defaults/, files/, handlers/, meta/, tasks/, templates/, vars/ (e tests/), ognuna col
suo main.yml. Tu riempi i main.yml.

### Fase 2 — files e templates: niente più percorsi (TODO 2)

Ecco il primo regalo del ruolo. Completa il **TODO 2** in roles/webapp/tasks/main.yml: il
task che renderizza la config con **src senza percorso**:

    - name: Render the config
      ansible.builtin.template:
        src: app.conf.j2          # niente path: Ansible lo cerca in templates/
        dest: "{{ config_dir }}/app.conf"
      notify: reload webapp

    - name: Deploy the motd
      ansible.builtin.copy:
        src: motd                 # niente path: Ansible lo cerca in files/
        dest: "{{ config_dir }}/motd"

Dentro un ruolo, template cerca src in templates/ e copy lo cerca in files/,
**automaticamente**. Niente percorsi assoluti: sposti il ruolo dove vuoi e i riferimenti
continuano a funzionare — è la Domanda b. E l'handler reload webapp che notifichi vive in
handlers/main.yml: anche lui, trovato da solo.

### Fase 3 — defaults contro vars: il cuore della riusabilità (TODO 1)

Un ruolo riusabile deve offrire delle **manopole** — valori che chi lo usa può cambiare — e
proteggere i suoi **ingranaggi interni** — valori che non vanno toccati dall'esterno.
Ansible lo ottiene con due cartelle a *precedenza opposta* (cap. 13):

- **defaults/** è il livello **2**, quasi il più debole: qualsiasi cosa lo sovrascrive. Ci
  metti le manopole.
- **vars/** è il livello **15**, alto: batte inventario, group_vars, host_vars, play. Ci
  metti gli ingranaggi.

Completa il **TODO 1** in roles/webapp/defaults/main.yml con le manopole:

    app_name: myapp
    port: 8080
    features: [logs, cache]

E guarda vars/main.yml (già scritto), l'ingranaggio interno:

    config_dir: /etc/webapp

Ora la prova. Nel group_vars/web.yml del lab c'è un tentativo di cambiare *entrambe*:

    app_name: webfromgroup     # group_vars (livello 6)
    config_dir: /etc/WRONG      # group_vars (livello 6)

Esegui e leggi la config renderizzata:

    app_name = webfromgroup      # il group_vars (6) ha BATTUTO il default (2): manopola girata
    config_dir = /etc/webapp     # il vars del ruolo (15) ha VINTO su group_vars (6): ingranaggio protetto

/etc/WRONG non nasce nemmeno. Questa è la regola d'oro dei ruoli: **le manopole del lettore
in defaults, le costanti interne in vars** — Domanda a.

### Fase 4 — Il playbook diventa minuscolo (TODO 3)

Tutta la logica è nel ruolo. Completa il **TODO 3**: il playbook che lo usa, tre righe:

    - name: Configure the web tier
      hosts: web
      become: true
      roles:
        - webapp

Esegui: Ansible carica tasks/main.yml, gli handler, le variabili, e risolve i path — tutto
perché la cartella si chiama webapp e ha la struttura giusta. Il playbook non sa *come* si
configura la web app: sa solo *chi* chiamare. Se domani un altro progetto vuole la stessa
app, sono di nuovo tre righe.

### Fase 5 — meta, dipendenze, e i due modi di includere

- **meta/main.yml** (già scritto) porta i metadati (autore, licenza, versione minima di
  Ansible) e, sotto dependencies, gli **altri ruoli** che questo richiede: Ansible li esegue
  *prima*. È come dire "la sezione archi ha bisogno che gli ottoni siano già accordati".
- Oltre a roles:, puoi tirare dentro un ruolo *a metà play* in due modi (16.8): **import_role**
  è **statico** (Ansible lo espande quando *legge* il playbook, prima di partire);
  **include_role** è **dinamico** (lo risolve *durante* l'esecuzione). La differenza conta
  quando lo metti dentro un loop o sotto un when che dipende da una variabile decisa a
  runtime: lì serve include_role — Domanda c.

### Fase 6 — Anatomia di un buon ruolo

- **Una responsabilità sola**: un ruolo configura *una* cosa (la web app), non "tutto il
  server".
- **defaults documentati**: sono l'interfaccia pubblica; chi usa il ruolo legge lì cosa può
  cambiare.
- **Nessun percorso assoluto**: sfrutta files/ e templates/.
- **Idempotente**: come ogni playbook (cap. 10), rieseguirlo non deve fare danni.
- **Nome chiaro**: il ruolo si invoca per nome — che il nome dica cosa fa.

## Criteri di "fatto"

- ansible-galaxy init crea lo scheletro; i main.yml sono riempiti.
- Config renderizzata: **app_name = webfromgroup** (group_vars batte defaults), **config_dir
  = /etc/webapp** (vars del ruolo batte group_vars; /etc/WRONG non esiste).
- template (app.conf.j2) e file (motd) risolti **senza percorsi**, dalle cartelle del ruolo.
- L'handler **reload webapp** scatta (da handlers/main.yml del ruolo).
- Il playbook è di **tre righe** (roles: - webapp); rieseguendo → **changed=0**.

## Domande di riflessione

**a.** app_name sta in defaults, config_dir in vars. Perché? Cosa comprano, in termini di
riusabilità, i due livelli di precedenza opposti (2 contro 15) — e cosa andrebbe storto se
mettessi config_dir in defaults, o app_name in vars?

**b.** Nel ruolo scrivi src: app.conf.j2 senza percorso, e Ansible lo trova. Come fa, e
perché questa auto-risoluzione è ciò che rende un ruolo *portabile* (spostabile e
condivisibile) mentre un percorso assoluto lo inchioderebbe a una macchina?

**c.** import_role è statico, include_role è dinamico. Descrivi la differenza nel *momento*
in cui i due vengono risolti, e porta un caso concreto in cui devi usare include_role perché
import_role non funzionerebbe (pensa a un loop, o a un when su una variabile nota solo a
runtime).

## Pulizia

    bash start/nodes.sh down

## Dove porta

Hai un ruolo pulito e riusabile — a casa tua. Il capitolo 17 lo apre al mondo: **Ansible
Galaxy e le collezioni** — scaricare ruoli scritti da altri, dichiarare le dipendenze in
requirements.yml, e i nomi completi (FQCN) come ansible.builtin.copy che hai già visto, ma
ora spiegati fino in fondo.
