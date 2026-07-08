# Capitolo 4 — Lo spartito che mente

**Livello:** Fondamentale

YAML è lo spartito su cui scriverai ogni playbook e ogni inventario. Sembra banale
— ed è proprio questa la trappola: un valore scritto come lo pensi può essere
**letto dal parser come tutt'altro**. NO diventa Falso, 1.20 diventa 1.2, 22:30
diventa 1350. In questo laboratorio impari l'anatomia di YAML e, soprattutto, a non
farti mentire dallo spartito. Nessun container, niente Ansible ancora: solo file
YAML e **lo stesso parser che Ansible usa sotto il cofano** (PyYAML).

## Obiettivi

- Le tre strutture — **scalare, lista, dizionario** — e l'annidamento per
  indentazione.
- Le trappole **silenziose** (Norway Problem, tipi impliciti, zeri iniziali, base
  60) e quelle **rumorose** (due punti, indentazione).
- **Quoting**: quando e perché mettere le virgolette.
- **Block scalar**: il pipe | (literal) e il maggiore > (folded).
- **Ancore e merge** << per il riuso (DRY).
- **yamllint** come rete di sicurezza.

## Prerequisiti

- python3 con **PyYAML** (arriva insieme ad Ansible). Verifica:
  python3 -c "import yaml"
- yamllint è opzionale (in CI c'è, in locale può mancare).
- **Niente container, niente Ansible**: siamo ancora nel "prima".

## Lo scenario

Un file di configurazione di deploy che *sembra* corretto. Lo dai in pasto al
parser e scopri che diverse righe non significano quello che credevi. Poi lo
aggiusti — quotando ciò che è ambiguo e togliendo la duplicazione con le ancore.

## Consegna passo-passo

### Fase 1 — Guarda cosa legge DAVVERO il parser

    python3 solution/inspect.py start/config.yml

Lo strumento stampa ogni valore con il **tipo** che il parser gli ha dato. Guarda
le sorprese:

    'country':   False   (bool)     <- hai scritto NO, la sigla della Norvegia
    'version':   1.2     (float)    <- hai scritto 1.20
    'file_mode': 420     (int)      <- hai scritto 0644
    'window':    1350    (int)      <- hai scritto 22:30

Lo spartito mente: NO l'hai messo per "Norvegia", il parser ha capito "falso". È il
**Norway Problem**, e con lui tutta la famiglia dei **tipi impliciti**: YAML
*indovina* il tipo, e a volte indovina male.

### Fase 2 — Le trappole rumorose (che almeno urlano)

Non tutte le trappole sono silenziose. Prova a far caricare al parser un valore con
i due punti non quotato, e un'indentazione sbagliata:

    printf 'note: value with: a colon\n' | python3 -c 'import sys,yaml; yaml.safe_load(sys.stdin)'
    printf 'a: 1\n  b: 2\n'              | python3 -c 'import sys,yaml; yaml.safe_load(sys.stdin)'

Entrambe falliscono con un errore. Meglio così: la trappola **rumorosa** la vedi
subito e la correggi. La silenziosa della Fase 1 — quella che carica benissimo e
significa la cosa sbagliata — è quella che ti frega in produzione.

### Fase 3 — TODO 1: quota ciò che è ambiguo

Apri start/config.yml. Metti tra **virgolette** i valori che il parser
mis-interpreta, perché restino ciò che intendevi (stringhe). Il campo build è già
fatto come esempio:

    build: "1.10"

Fai lo stesso per country, maintenance, version, file_mode, device_id, window. Poi
rilancia:

    python3 solution/inspect.py start/config.yml

Ora country è "NO", version è "1.20", tutto stringa. Regola d'oro: **in caso di
dubbio, quota** — soprattutto sigle di due lettere, numeri di versione, permessi
con lo zero davanti, orari.

### Fase 4 — Block scalar: | tiene gli a-capo, > li fonde

Il campo motd usa il **literal** |, che conserva le righe così come sono:

    motd: |
      welcome to web
      authorized use only

inspect.py te lo mostra con i \n dentro. Se usassi il **folded** >, le righe si
fonderebbero in una sola separata da spazi. Il primo serve per file di
configurazione e chiavi; il secondo per testi lunghi da mandare a capo comodamente.

### Fase 5 — TODO 2: togli la duplicazione con ancore e merge

Nel blocco hosts, web e db ripetono le stesse impostazioni. Dai al blocco condiviso
un'**ancora** e **fondilo** in ogni host con <<, sovrascrivendo solo ciò che cambia
(db ha bisogno di un timeout più lungo):

    defaults: &defaults
      retries: 3
      timeout: 30
      healthcheck: /healthz
    hosts:
      web:
        <<: *defaults
        role: frontend
      db:
        <<: *defaults
        timeout: 60
        role: database

Rilancia inspect.py: web e db **ereditano** i defaults, e db mantiene il suo
override a 60. (Nota: << è una comodità di YAML 1.1; utile da riconoscere, ma per il
riuso serio arriveranno i ruoli, capitolo 16.)

### Fase 6 — La rete di sicurezza: yamllint

L'occhio umano non basta: NO e "NO" sembrano identici. **yamllint** legge lo
spartito con la severità del parser e segnala proprio queste cose — la regola
truthy urla su no/NO/off/yes — *prima* che Ansible le interpreti male:

    yamllint start/config.yml

È l'ultima difesa del capitolo: non fidarti dell'occhio, fai passare ogni YAML dal
correttore.

## Criteri di "fatto"

- inspect.py su start/config.yml mostra i valori **mis-tipati** (country bool,
  version float, file_mode int…).
- Dopo il TODO 1, gli stessi valori sono **stringhe**.
- Dopo il TODO 2, web e db **condividono** &defaults via << e db **sovrascrive**
  solo il timeout.
- Sai spiegare la differenza fra una trappola rumorosa e una silenziosa, e perché
  la seconda è peggio.

## Domande di riflessione

**a.** Perché la trappola **silenziosa** (NO → False) è più pericolosa di quella
**rumorosa** (errore di parse)? Cosa succede a un task che riceve il booleano False
dove ti aspettavi la stringa "NO"?

**b.** version: 1.20 diventa 1.2 e perde lo zero finale. Per un numero di versione
perché è un disastro, e qual è la **regola generale** su quando quotare un valore?

**c.** Le ancore con merge tolgono la duplicazione, ma introducono un costo: quale,
per chi legge e mantiene il file mesi dopo? E in che modo i **ruoli** (capitolo 16)
affronteranno lo stesso bisogno di riuso in modo più strutturato?

## Pulizia

Nessuna: questo capitolo è fatto solo di file, nessun container.

## Dove porta

Ogni playbook, inventario e file di variabili che scriverai è YAML — e ora sai che
lo spartito va sempre riletto con l'occhio del parser. Al capitolo 8 (inventari) e
al 12 (variabili) queste trappole diventano bug veri: quotale prima che mordano.
