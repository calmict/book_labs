# Capitolo 24 — Il palcoscenico usa-e-getta

**Livello:** Avanzato

Il capitolo 23 ti ha dato tre reti — syntax-check, lint, check mode — ma nessuna delle tre
*esegue* davvero il ruolo su un sistema vero. Un lint pulito e una prova a teatro vuoto dicono
che il playbook è *ben scritto* e cosa *cambierebbe*, non che il ruolo **funziona**: che parte
da zero, converge, è idempotente, e lascia il sistema nello stato giusto. Questo è il muro che
il capitolo 23 non supera. Molecule lo abbatte: monta un ambiente **vero ma usa-e-getta** (un
container), applica il ruolo, verifica idempotenza e risultato, e smonta tutto — un comando su,
un comando giù. È la prova sul palco vero, con la certezza di poterlo sempre ricostruire da capo.

## Obiettivi

- Il **muro del capitolo 23** e perché serve un collaudo che esegua davvero (24.1).
- **Che cos'è Molecule**: l'ambiente usa-e-getta come banco di prova (24.2).
- **Installazione e primo scenario** (24.3).
- **Anatomia di uno scenario**: driver, platforms, provisioner, verifier (24.4).
- Il **ciclo di vita**: create, converge, idempotence, verify, destroy (24.5).
- **Scrivere le verifiche** con Testinfra: un secondo paio d'occhi (24.6).
- **Lavorare a fasi** durante lo sviluppo (24.7).
- **Più scenari, più distribuzioni** (24.8).
- Le **buone abitudini** con Molecule (24.9).

## Prerequisiti

- Il venv del capitolo 6, più **molecule**, il driver **docker** e **testinfra** (in start/requirements.txt).
- Un **motore Docker** locale in funzione (Molecule crea e distrugge lì i suoi container, mai i tuoi).
- Le collezioni **community.docker** e **ansible.posix** (in start/requirements.yml): il driver le usa per parlare col demone.
- Un ruolo da collaudare: nel capitolo 16 hai imparato a *scrivere* un ruolo; qui impari a *provarlo*.

## Lo scenario

start/cap24_app/ è un piccolo ruolo che scrive una cartella e un file di configurazione e lascia
un marcatore di deploy. Attorno c'è uno **scenario Molecule** (la cartella molecule/default/)
quasi completo, ma con tre lacune. Le colmi facendo passare il ruolo per l'intero ciclo di
Molecule, finché "molecule test" è verde da cima a fondo.

Prepara l'ambiente:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    ansible-galaxy collection install -r start/requirements.yml
    cd start/cap24_app

### Fase 1 — Il muro del capitolo 23 (24.1–24.2)

Il capitolo 23 si ferma prima della verità. syntax-check e lint non eseguono; check mode *simula*
contro lo stato attuale, ma presuppone un sistema già esistente e non prova che il ruolo funzioni
**da zero, due volte di fila, davvero**. Molecule chiude il cerchio: prende un sistema pulito (un
container appena creato), ci applica il ruolo per davvero, ricontrolla applicandolo una seconda
volta (idempotenza), ispeziona il risultato con occhi indipendenti, e poi butta via tutto. Non è
una simulazione: è l'esecuzione reale, resa ripetibile dall'usa-e-getta.

### Fase 2 — Che cos'è Molecule (24.2)

Molecule orchestra il collaudo di un ruolo. Attorno al ruolo mette uno **scenario**: come nasce
il sistema di prova (il **driver**: qui Docker), quale ruolo applicare (il **provisioner**:
Ansible, con un playbook converge.yml), e come verificare il risultato (il **verifier**: qui
Testinfra). Un solo comando, "molecule test", esegue l'intera sequenza e garantisce la pulizia
finale.

### Fase 3 — Anatomia di uno scenario (24.4 — TODO 1)

Apri molecule/default/molecule.yml. Uno scenario ha quattro sezioni:

    driver:        # come nasce il sistema di prova (docker)
    platforms:     # QUALI sistemi: nome + immagine
    provisioner:   # chi applica il ruolo (ansible)
    verifier:      # chi controlla il risultato (testinfra)

Completa il **TODO 1**: dichiara la piattaforma e il verifier —

    platforms:
      - name: cap24-instance
        image: python:3.12-slim
        pre_build_image: true
    verifier:
      name: testinfra

La scelta dell'immagine non è casuale: il provisioner ha bisogno di **Python** dentro il
container (Ansible gira i moduli lì), quindi si parte da un'immagine che lo contiene già
(pre_build_image: true = "usa questa immagine così com'è, non costruirla"). Il nome cap24-instance
è come Molecule chiamerà il container: distinto, così non tocca mai i tuoi altri container.

### Fase 4 — Il ciclo di vita (24.5 — TODO 2)

Il cuore di Molecule è una sequenza di fasi:

    create       # crea il container
    converge     # applica il ruolo (converge.yml)
    idempotence  # applica il ruolo UNA SECONDA VOLTA: deve dare changed=0
    verify       # esegue le verifiche (testinfra)
    destroy      # distrugge il container

La fase **idempotence** è la più severa e la più onesta: riesegue converge e pretende **zero
cambiamenti**. È la prova del nove del capitolo 5, automatizzata: un ruolo corretto, applicato
due volte, la seconda non cambia niente.

Guarda tasks/main.yml del ruolo: l'ultimo task lascia un marcatore con un comando —

    - name: Stamp a deploy marker once
      ansible.builtin.command: touch /etc/cap24app/deployed

Un comando è un **campanello** (capitolo 5 e 9): risulta *changed* ogni volta. Alla seconda
applicazione, idempotence lo becca e fallisce, nominando il task colpevole. Completa il
**TODO 2**: rendi il task idempotente con la guardia **creates** —

    - name: Stamp a deploy marker once
      ansible.builtin.command: touch /etc/cap24app/deployed
      args:
        creates: /etc/cap24app/deployed

creates dice ad Ansible: "se questo file esiste già, salta il comando". Prima applicazione →
crea (changed); seconda → saltato (ok). Ora l'intero ciclo può chiudersi verde. Lancialo:

    molecule test

Vedrai la sequenza: create, converge (changed), idempotence (changed=0, "Idempotence completed
successfully"), verify, destroy. Domanda b.

### Fase 5 — Scrivere le verifiche (24.6 — TODO 3)

converge ti dice che Ansible *crede* di aver messo a posto le cose (i suoi ok/changed). Ma è
Ansible che giudica sé stesso. **Testinfra** è un secondo paio d'occhi: ispeziona il sistema
**reale** — file, permessi, contenuti, servizi — indipendentemente da ciò che Ansible ha
riportato. Le verifiche vivono in molecule/default/tests/test_default.py e sono normali test
pytest.

Completa il **TODO 3**: scrivi le asserzioni sul risultato del ruolo —

    testinfra_hosts = ["all"]

    def test_config_directory(host):
        d = host.file("/etc/cap24app")
        assert d.is_directory
        assert d.mode == 0o755

    def test_config_file(host):
        f = host.file("/etc/cap24app/app.conf")
        assert f.exists
        assert f.mode == 0o644
        assert "workers = 4" in f.content_string

L'oggetto host è la lente: host.file(...), host.user(...), host.package(...), host.service(...).
Se un'asserzione è falsa — il file manca, il permesso è largo, il contenuto è sbagliato — verify
fallisce. È la differenza tra "Ansible dice di averlo fatto" e "il sistema conferma che è fatto".
Domanda c.

### Fase 6 — Lavorare a fasi (24.7)

"molecule test" distrugge sempre alla fine: perfetto per la CI, scomodo mentre sviluppi. Durante
lo sviluppo lavori a fasi, riusando lo stesso container:

    molecule create      # crea una volta
    molecule converge    # applica il ruolo (ripeti a ogni modifica: veloce)
    molecule login       # entra nel container a curiosare
    molecule verify      # esegui solo le verifiche
    molecule destroy     # butta via quando hai finito

Il ciclo stretto è converge → modifica → converge: nessuna attesa per ricreare il container.
"molecule test" resta il giudice finale, quello che parte da zero e garantisce la pulizia.

### Fase 7 — Più scenari, più distribuzioni (24.8)

Un ruolo serio va provato su più sistemi. Due strade:

- **Più piattaforme** nello stesso scenario: aggiungi voci sotto platforms e Molecule crea più
  container, applicando e verificando su tutti. Attenzione: distribuzioni diverse hanno esigenze
  diverse — un'immagine Alpine, per esempio, non ha bash e va tenuta viva con un comando
  esplicito:

      - name: cap24-alpine
        image: python:3.12-alpine
        pre_build_image: true
        command: /bin/sh

- **Più scenari**: cartelle sorelle sotto molecule/ (molecule/default/, molecule/hardening/),
  ognuna col suo molecule.yml, converge.yml e verifiche. Le selezioni con
  "molecule test -s hardening". Uno scenario per ogni modo d'uso del ruolo.

### Fase 8 — Le buone abitudini (24.9)

- **Idempotenza sempre nel ciclo**: è la verifica che smaschera i campanelli travestiti da
  interruttori (comandi senza creates/changed_when).
- **Verifica indipendente**: Testinfra guarda il sistema, non il resoconto di Ansible. Un ruolo
  "converged" senza verifiche è una promessa non mantenuta.
- **A fasi mentre sviluppi, test intero prima di consegnare**: converge veloce per iterare,
  "molecule test" da zero come giudice.
- **Container usa-e-getta, mai i tuoi**: Molecule gestisce solo le istanze che nomina; il teardown
  è garantito, non lascia residui.
- **Più distribuzioni** se il ruolo deve girare su più di una: meglio scoprire le differenze qui
  che in produzione.

## Criteri di "fatto"

- molecule.yml dichiara la piattaforma e il verifier testinfra (TODO 1).
- Il task del marcatore ha la guardia creates (TODO 2): la fase **idempotence** passa (changed=0).
- Le verifiche testinfra sono scritte (TODO 3) e la fase **verify** passa.
- "molecule test" è verde dall'inizio alla fine: create, converge, idempotence, verify, destroy —
  e non lascia container in giro.

## Domande di riflessione

**a.** Il capitolo 23 ti dava lint e check mode; Molecule crea un sistema vero e ci esegue il
ruolo davvero. In che senso questo *prova* qualcosa che lint e check mode non possono provare?
Cosa aggiunge il fatto che l'ambiente sia creato **da zero** e poi **distrutto**?

**b.** La fase idempotence riapplica il ruolo e pretende changed=0. Perché "applicalo due volte,
la seconda non deve cambiare niente" è la prova più forte — e più economica — della correttezza
di un ruolo? Cosa costa, concretamente, un task non idempotente (un comando senza creates) che
sfugge a questa fase?

**c.** converge riporta ok/changed: è Ansible che giudica sé stesso. Testinfra ispeziona il
sistema reale. Perché una verifica **indipendente** coglie errori che il resoconto di converge
non può cogliere? Fai un esempio di ruolo che converge "verde" ma lascia il sistema sbagliato.

## Pulizia

Molecule smonta da sé alla fine di "molecule test". Se hai lavorato a fasi, chiudi con:

    molecule destroy

Nessun residuo: i container usa-e-getta muoiono col teardown, i tuoi container restano intatti.

## Dove porta

Sai scrivere un ruolo (cap16), tenerlo pulito (cap23) e ora **provarlo** su un sistema vero,
ripetutamente, da zero (cap24). Chiude la fascia Avanzato. Ma finora hai orchestrato pochi nodi:
cosa succede quando diventano **mille**? Il **capitolo 25** apre la fascia Cloud Architect con le
**prestazioni su larga scala** — fork, strategie, pipelining, come domare i fatti — perché a mille
nodi anche un secondo di troppo per host diventa un'attesa che non finisce.
