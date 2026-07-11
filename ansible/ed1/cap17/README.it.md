# Capitolo 17 — Il repertorio condiviso

**Livello:** Intermedio

Il ruolo del capitolo 16 è tuo, scritto in casa. Ma migliaia di persone hanno già scritto e
condiviso ruoli e moduli per ogni compito immaginabile: gestire firewall, database, provider
cloud, servizi di sistema. Non devi ricomporre ciò che esiste già — puoi attingere al
**repertorio condiviso**. Il luogo è **Ansible Galaxy**; l'unità di distribuzione è la
**collezione**; e il modo di citare con precisione ogni pezzo è il **nome puntato completo**,
l'FQCN. Questo capitolo — l'ultimo della fascia Intermedio — ti insegna a stare sulle spalle
dei giganti senza perdere la riproducibilità.

## Obiettivi

- **Sulle spalle dei giganti**, e dai ruoli alle **collezioni** (17.1, 17.2).
- Il mistero dei nomi puntati: l'**FQCN** (17.3).
- **Installare** una collezione (17.4) e dichiararla in **requirements.yml** (17.5).
- **Dove finiscono** le collezioni e come tenerle **col progetto** (17.6).
- **Usarla** in un playbook (17.7).
- **Automation Hub** e i repository privati (17.8); **pubblicare** (17.9).
- Le **buone abitudini** con Galaxy e le collezioni (17.10).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- Rete: scaricheremo una collezione da galaxy.ansible.com (come pip da PyPI).
- I ruoli del capitolo 16; il lock/pin del capitolo 7; l'FQCN ansible.builtin già intravisto.
- (Nessun nodo: questo capitolo lavora sul **control node** — installare e usare una
  collezione avviene a casa.)

## Lo scenario

Vuoi gestire un file INI. C'è già un modulo che lo fa benissimo — **community.general.ini_file**
— ma non è tra quelli sempre presenti: vive nella grande collezione della comunità. Lo
installi, lo dichiari come dipendenza pinnata, lo tieni dentro il progetto, e lo usi. Nessuna
macchina remota: tutto sul control node.

## Consegna passo-passo

### Fase 1 — Dai ruoli alle collezioni, e l'FQCN

Un ruolo (cap. 16) impacchetta *una* capacità. Una **collezione** impacchetta *molte* cose —
moduli, ruoli, filtri, plugin — sotto un **namespace**. Ne usi una da sempre senza saperlo:
**ansible.builtin**, la collezione integrata, è quella da cui vengono copy, file, template.
Un'altra, enorme, è **community.general**.

Ecco perché i nomi sono **puntati** (17.3): l'**FQCN** — Fully Qualified Collection Name — ha
tre parti, *namespace.collezione.modulo*:

    ansible.builtin.copy          # namespace ansible, collezione builtin, modulo copy
    community.general.ini_file    # namespace community, collezione general, modulo ini_file

Perché tanto formalismo? Perché due collezioni diverse potrebbero avere un modulo con lo
stesso nome breve (ini_file): l'FQCN dice *esattamente* quale, senza ambiguità — Domanda a.

### Fase 2 — Installare e dichiarare: requirements.yml (TODO 1)

Non scarichi le collezioni a mano una per una: le **dichiari**. Completa il **TODO 1** in
start/requirements.yml:

    ---
    collections:
      - name: community.general
        version: "8.6.0"

e installi tutto con un comando:

    ansible-galaxy collection install -r requirements.yml

Nota la **versione fissata** ("8.6.0"): è lo stesso principio del pin del capitolo 7 (tofu).
Senza, prenderesti "l'ultima disponibile" — e domani sarebbe un'altra, con il rischio di un
playbook che cambia comportamento da solo.

### Fase 3 — Dove finiscono, e tenerle col progetto (TODO 2)

Di default le collezioni vanno in **~/.ansible/collections**: globali, condivise da tutti i
tuoi progetti, alla versione che capita. Per un progetto serio non basta: vuoi che chi lo
clona ottenga le *stesse* collezioni alle *stesse* versioni. La soluzione è tenerle **dentro
il progetto**. Completa il **TODO 2** in start/ansible.cfg:

    [defaults]
    collections_path = ./collections

Ora ansible-galaxy install scarica in ./collections, accanto al codice. Progetto +
requirements.yml (il pin) + collections_path (il posto) = riproducibilità: come il lock file
del capitolo 7 — Domanda b. (La cartella ./collections **non** si versiona: si rigenera da
requirements.yml, come si fa con le dipendenze scaricate.)

### Fase 4 — Usarla nel playbook (TODO 3)

Ora il modulo della collezione è a portata. Completa il **TODO 3** in start/site.yml: il task
che gestisce l'INI, chiamato col suo **FQCN**:

    - name: Manage an INI key with a collection module
      community.general.ini_file:
        path: "{{ conf_path }}"
        section: server
        option: port
        value: "8080"
        mode: "0644"

Il resto del playbook usa i moduli di **ansible.builtin** (file, slurp, debug) — il contrasto
è tutto qui: builtin senza pensieri, la collezione la citi per intero. Esegui e leggi:

    [server]
    port = 8080

### Fase 5 — Automation Hub, repository privati, e pubblicare

- Galaxy è il repertorio **pubblico** della comunità. In azienda spesso si usa **Automation
  Hub** (17.8): collezioni *certificate* da Red Hat, o un repository **privato** interno, per
  avere contenuti garantiti e sotto controllo. Il meccanismo è lo stesso: dichiari, pinni,
  installi — solo la fonte cambia.
- E puoi **dare indietro** (17.9): impacchettare le tue collezioni e pubblicarle, perché il
  prossimo stia sulle *tue* spalle.

### Fase 6 — Buone abitudini

- **Sempre l'FQCN**: nei playbook seri, community.general.ini_file, non ini_file. Nessuna
  ambiguità, e si legge da dove viene ogni modulo.
- **Pinna le versioni** in requirements.yml: riproducibilità, non sorprese.
- **Tieni le collezioni col progetto** (collections_path); rigenerale da requirements.yml.
- **Non fidarti ciecamente**: un ruolo o una collezione di terzi gira **coi tuoi privilegi**
  (become, cap. 11). Leggi cosa fa prima di eseguirlo da root — Domanda c.

## Criteri di "fatto"

- requirements.yml installa **community.general** (versione pinnata) in **./collections**
  (dentro il progetto).
- Il playbook usa **community.general.ini_file** via FQCN e scrive [server] port = 8080
  nell'INI.
- Rieseguendo → **changed=0** (il modulo della collezione è idempotente come i builtin).
- ansible-galaxy collection list mostra la versione pinnata, dal path del progetto.

## Domande di riflessione

**a.** Perché scrivi community.general.ini_file per intero, e non solo ini_file? Cosa risolve
il nome puntato completo (FQCN) il giorno in cui due collezioni diverse offrono entrambe un
modulo chiamato ini_file?

**b.** Le collezioni potrebbero stare comodamente in ~/.ansible, condivise fra tutti i
progetti. Perché invece conviene tenerle *dentro il progetto* (collections_path) e fissarne
la versione in requirements.yml? Collega la risposta al lock file del capitolo 7 e al
concetto di riproducibilità.

**c.** Installare una collezione di terzi significa eseguire codice scritto da altri — e i
tuoi playbook girano spesso con become (cap. 11), cioè da root. Perché non è saggio installare
il primo ruolo che trovi e lanciarlo, e cosa controlli *prima* di dargli i tuoi privilegi?

## Pulizia

Niente da smontare: questo capitolo non accende nodi. Se vuoi, cancella la cartella
./collections (si rigenera da requirements.yml).

## Dove porta

Chiudi la fascia Intermedio: sai scrivere ruoli e attingere al repertorio del mondo. Resta un
conto aperto dal capitolo 11 — la password di sudo lasciata *in chiaro*. Il capitolo 18 apre
la fascia Avanzato e la mette finalmente in cassaforte: **Ansible Vault**, la cifratura dei
segreti dentro i tuoi file.
