# Capitolo 14 — Il richiamo a fine prova

**Livello:** Intermedio

Cambi la configurazione di un servizio: ora va **ricaricato** perché la rilegga. Ma
ricaricarlo a *ogni* esecuzione del playbook — anche quando non hai toccato nulla — è
spreco e rischio: interruzioni inutili, connessioni cadute, per niente. Vuoi ricaricarlo
**solo se la config è cambiata davvero**. Ansible risolve questo con la coppia **notify /
handler**: un task lascia un *richiamo*, e a fine prova — solo se quel task ha riportato
changed — l'handler scatta. È il colore changed del capitolo 5 che smette di essere un
semplice segnale e diventa un **innesco**.

## Obiettivi

- Il **problema**: ricaricare solo quando serve (14.1).
- Il **motore**: lo stato changed (14.2).
- **notify e handler**: la coppia che risolve (14.3).
- Le **tre regole d'oro** degli handler (14.4).
- Più handler insieme, e il trucco di **listen** (14.5).
- Controllare a mano il changed con **changed_when** (14.6).
- Un **esempio reale**, dall'inizio alla fine (14.7).
- **Buone abitudini** con gli handler (14.8).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- Docker per due nodi. Rete alla prima accensione.
- Lo stato changed del capitolo 5; il playbook del capitolo 10; il command "campanello"
  del capitolo 9.

## Lo scenario

Due nodi nel gruppo **web** con una piccola app configurata in /etc/myapp. Ogni volta che
un file di config cambia, l'app va "ricaricata" — e noi lo dimostreremo in modo
**contabile**: l'handler accoda una riga a /var/log/myapp/reloads.log. Contando le righe
dopo ogni esecuzione, vedi *esattamente* quante volte il servizio è stato ricaricato — e
scopri che cresce solo quando deve.

## Consegna passo-passo

### Fase 0 — Accendi i nodi

    bash start/nodes.sh up

Due container (web1, web2) con l'utente deploy.

### Fase 1 — Il problema, e il motore

Un playbook idempotente (cap. 10) fa la cosa giusta: se la config è già a posto, non la
riscrive. Ma la config e il *processo in esecuzione* sono due cose diverse: cambiare
/etc/myapp/app.conf non ricarica da solo l'app. Potresti aggiungere un task "ricarica
l'app" in fondo — ma quello girerebbe **ogni volta**, anche quando la config non è
cambiata, riavviando il servizio per niente. Ti serve un innesco legato al **changed**: il
segnale del capitolo 5 che dice "questo task ha *davvero* modificato qualcosa". Ricarica
**se e solo se** changed.

### Fase 2 — notify e handler (TODO 1)

Il meccanismo è due pezzi. Un task normale aggiunge **notify** con il nome di un richiamo;
e nella sezione **handlers** del play definisci quel richiamo — un task come gli altri, ma
che gira solo se chiamato. Apri start/site.yml e completa il **TODO 1**: aggiungi notify ai
task che scrivono la config:

    - name: Deploy app.conf
      ansible.builtin.copy:
        content: "greeting = {{ greeting }}\n"
        dest: /etc/myapp/app.conf
      notify: "app config changed"

L'handler vero e proprio arriva nella Fase 4. L'idea: il task copia il file; **se** il file
cambia (changed), lascia il richiamo "app config changed"; a fine play il richiamo viene
raccolto ed eseguito.

### Fase 3 — Le tre regole d'oro

Gli handler seguono tre regole che spiegano ogni loro comportamento:

1. **Girano a fine play**, dopo *tutti* i task — non nel momento in cui li notifichi. Prima
   si fa tutto il lavoro, poi si reagisce.
2. **Girano solo se notificati da un task changed.** Nessun changed, nessun richiamo,
   nessuna reazione.
3. **Girano al massimo una volta per play**, per quante volte siano notificati. Due task
   che notificano lo stesso handler → l'handler scatta **una** volta sola (dedup).

La regola 3 la vedrai contando: due task notificano lo stesso richiamo, ma reloads.log
guadagna **una** riga, non due.

### Fase 4 — Più handler, e il trucco di listen (TODO 2)

Spesso un cambiamento deve far scattare *più* reazioni: ricaricare il servizio *e*
aggiornare una metrica. Invece di notificare due nomi, notifichi un **topic** e più handler
ci si iscrivono con **listen**. Completa il **TODO 2**: due handler che ascoltano lo stesso
topic:

    handlers:
      - name: reload app
        listen: "app config changed"
        ansible.builtin.shell: "date -Iseconds >> /var/log/myapp/reloads.log"

      - name: bump reload metric
        listen: "app config changed"
        ansible.builtin.shell: "echo reloaded >> /var/log/myapp/metrics.log"

Ora notify: "app config changed" fa scattare **entrambi**. listen disaccoppia il *nome del
richiamo* dai *nomi degli handler*: i task notificano un'intenzione ("la config è
cambiata"), non un elenco di azioni — e domani aggiungi un terzo handler senza toccare un
solo task.

### Fase 5 — Controllare a mano il changed (TODO 3)

Un command è un **campanello** (cap. 9): riporta changed a *ogni* giro, perché non sa cosa
ha fatto. Se un command notifica un handler, l'handler scatterebbe ogni volta — falso
allarme. **changed_when** ti ridà il controllo. Completa il **TODO 3** sul task che forza il
reload:

    - name: Force a reload on demand
      ansible.builtin.command: "echo force={{ force_reload }}"
      register: forced
      changed_when: force_reload | bool
      notify: "app config changed"

Con changed_when: force_reload | bool, il task è "changed" *solo* quando tu lo decidi. Prova
su un sistema con la config invariata:

    ansible-playbook -i start/inventory.ini start/site.yml -e force_reload=true

Gli handler scattano lo stesso — non perché un file è cambiato, ma perché changed_when ha
detto "changed". È l'altra faccia del cap. 9: lì changed_when serviva a *silenziare* un
command read-only (changed_when: false), qui serve a *innescare* di proposito.

### Fase 6 — L'esempio reale, contato riga per riga

Metti tutto in fila e guarda reloads.log crescere solo quando deve:

    # 1. prima esecuzione: la config nasce -> handler scatta
    ansible-playbook ... start/site.yml                         # reloads.log: 1 riga
    # 2. rieseguo, nulla cambia -> handler NON scatta (regola 2)
    ansible-playbook ... start/site.yml                         # reloads.log: ancora 1
    # 3. cambio la config -> handler scatta
    ansible-playbook ... start/site.yml -e greeting=ciao        # reloads.log: 2 righe
    # 4. config invariata ma forzo -> changed_when innesca
    ansible-playbook ... start/site.yml -e greeting=ciao -e force_reload=true   # 3 righe

Quattro esecuzioni, tre reload: esattamente quelli che servivano. Nessun riavvio a vuoto.

### Fase 7 — Buone abitudini (e un trabocchetto serio)

- **Nomi e topic chiari**: notify un'intenzione ("app config changed"), non un comando.
- **Handler idempotenti** anch'essi: un reload va bene, un "cancella e ricrea" no.
- **Il trabocchetto del play fallito**: se un task notifica un handler e poi il play
  **fallisce prima della fine**, l'handler *non* gira (regola 1: scatta a fine play). Al run
  successivo il task trova la config già a posto → changed=no → non notifica più →
  **l'handler non scatta mai**: config nuova, servizio mai ricaricato. È la Domanda c. Il
  rimedio: **--force-handlers** (esegue gli handler notificati anche se un task successivo
  fallisce) o **meta: flush_handlers** per scaricarli a un punto sicuro.

## Criteri di "fatto"

- Prima esecuzione: reloads.log e metrics.log hanno **1 riga** ciascuno (due task
  notificano, due handler via listen, ognuno gira **una** volta).
- Rieseguendo senza modifiche: i log **restano a 1** (regola 2).
- Con **-e greeting=ciao**: la config cambia → i log salgono a **2**.
- Con **-e force_reload=true**: pur senza modifiche ai file, changed_when innesca → i log
  salgono ancora.

## Domande di riflessione

**a.** Gli handler girano a *fine* play e *solo* su changed. Perché queste due regole
insieme sono ciò che rende il pattern utile? Cosa andrebbe storto se un handler scattasse
*immediatamente* a ogni notifica, e cosa se scattasse *sempre*, changed o no?

**b.** Un command riporta changed a ogni giro (campanello, cap. 9). Perché, se quel command
notifica un handler, changed_when diventa indispensabile — e cosa vedresti *senza*?
Descrivi anche l'uso opposto, changed_when: false, e quando serve.

**c.** Un task notifica il reload, poi un task successivo **fallisce** e il play si ferma.
L'handler non è girato. Rilanci: il task della config ora non cambia nulla (è già a posto),
quindi non notifica, e l'handler resta a terra — con la config nuova e il servizio mai
ricaricato. Perché accade, ed è pericoloso? Come lo previeni?

## Pulizia

    bash start/nodes.sh down

## Dove porta

Hai fatto reagire i tuoi task al cambiamento. Il capitolo 15 dà loro un'altra forma di
intelligenza: **decidere** e **ripetere** — la logica condizionale (when, senza le graffe)
e i cicli (loop). Lì un solo task potrà agire su venti file, o saltare del tutto se una
condizione non è soddisfatta.
