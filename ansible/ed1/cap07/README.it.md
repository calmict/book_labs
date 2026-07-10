# Capitolo 7 — Il leggio più vicino

**Livello:** Fondamentale

Il direttore ha la bacchetta (capitolo 6); ora serve il **regolamento
d'orchestra**: ansible.cfg, il file dove vivono le regole di come Ansible lavora —
quanti musicisti in parallelo, con che chiave entrare, se chiedere il permesso. La
cosa più importante da capire non è *cosa* c'è scritto, ma **quale copia del
regolamento viene letta**: Ansible guarda quattro leggii in ordine fisso e usa **il
primo che trova, per intero** — niente fusioni. E c'è una trappola di sicurezza: se
il leggio è in una stanza dove chiunque può scriverci, Ansible **si rifiuta di
leggerlo**.

## Obiettivi

- La **gerarchia di ricerca**: ANSIBLE_CONFIG → ./ansible.cfg → ~/.ansible.cfg →
  /etc/ansible/ansible.cfg; il primo trovato **vince tutto** (non si fondono).
- La struttura del file e la sezione **[defaults]** (inventory, forks,
  host_key_checking).
- **[privilege_escalation]** (become) e **[ssh_connection]** (pipelining — il
  ControlMaster del capitolo 3 diventa impostazione).
- Gli attrezzi di **ansible-config**: list, view, e il prezioso
  **dump --only-changed**.
- La **trappola** della cartella world-writable: il cfg nella cwd è comodo e
  pericoloso.

## Prerequisiti

- Il venv del capitolo 6 con ansible-core (o ricrealo: python3 -m venv .venv e
  pip install -r start/requirements.txt).
- Nessun container: il capitolo è tutto su configurazione e ispezione.

## Consegna passo-passo

### Fase 1 — Quale regolamento sta leggendo?

Chiediglielo — la risposta è nella prima schermata:

    ansible --version | grep 'config file'

Se non hai nessun cfg tuo, vedrai quello di sistema (/etc/ansible/ansible.cfg) o
None. Ora spostati nella cartella dell'esercizio, dove c'è start/ansible.cfg, e
richiedi:

    cd start/
    ansible --version | grep 'config file'

Adesso legge **./ansible.cfg**: il leggio più vicino. L'ordine completo, dal più
forte:

1. **ANSIBLE_CONFIG** (variabile d'ambiente) — l'ordine esplicito
2. **./ansible.cfg** — la cartella corrente (il progetto)
3. **~/.ansible.cfg** — la tua home
4. **/etc/ansible/ansible.cfg** — il sistema

Provalo con la variabile:

    ANSIBLE_CONFIG=/tmp/altro.cfg ansible --version | grep 'config file'

Regola d'oro: **il primo trovato vince per intero**. Se il cfg di progetto
dimentica una riga che c'era in quello di sistema, quella riga *non esiste più* —
non viene ereditata.

### Fase 2 — TODO 1: la sezione [defaults]

Apri start/ansible.cfg: la struttura è INI (sezioni tra parentesi quadre).
Completa il **TODO 1** nella sezione [defaults]:

    [defaults]
    inventory = ./inventory.ini
    forks = 10
    host_key_checking = False

- **inventory**: dove sta la rubrica (capitolo 8) — così smetti di passarla a ogni
  comando;
- **forks**: quanti host in parallelo (il "tre, trenta, tremila" del capitolo 1 —
  di default sono solo 5);
- **host_key_checking**: la conosci dal capitolo 3 — nel lab False, in produzione
  mai.

### Fase 3 — Gli attrezzi: ansible-config

Tre comandi per non lavorare alla cieca:

    ansible-config list             # TUTTE le impostazioni possibili, documentate
    ansible-config view             # il file attivo, così com'è
    ansible-config dump --only-changed

L'ultimo è il gioiello: mostra **solo ciò che differisce dai default**, e per ogni
valore **da quale file** arriva. È la risposta alla domanda "ma quale regola sta
usando davvero?":

    DEFAULT_FORKS(/percorso/ansible.cfg) = 10
    HOST_KEY_CHECKING(/percorso/ansible.cfg) = False

### Fase 4 — TODO 2: permessi e velocità

Completa le altre due sezioni:

    [privilege_escalation]
    become = True
    become_method = sudo

    [ssh_connection]
    pipelining = True

- **become**: chiedere i gradi di amministratore (il capitolo 11 ci va a fondo);
  qui impari che il *default* di questo comportamento vive nel cfg;
- **pipelining**: meno andirivieni SSH per ogni task — il fratello del
  ControlMaster del capitolo 3; il capitolo 25 misurerà quanto vale.

Verifica con dump --only-changed: compare DEFAULT_BECOME. E pipelining? Non c'è —
perché è un'impostazione del *connection plugin*, non del core. Il dump base mostra
solo il core; per vedere anche i plugin di connessione:

    ansible-config dump --only-changed -t all

Ora compare anche pipelining(...) = True. Dettaglio piccolo ma prezioso: quando
"l'ho impostato ma nel dump non c'è", prova con -t all prima di dare la colpa al
file.

### Fase 5 — La trappola: il leggio nella stanza aperta

Il cfg nella cartella corrente è comodo — e per questo pericoloso: se lavori in
una cartella dove **chiunque può scrivere**, un altro utente potrebbe mettertici un
ansible.cfg avvelenato (che so, un inventory suo o un plugin path malevolo), e tu
lo eseguiresti senza saperlo. Ansible lo sa, e si difende:

    mkdir -p /tmp/stanza-aperta && chmod 777 /tmp/stanza-aperta
    cp ansible.cfg /tmp/stanza-aperta/
    cd /tmp/stanza-aperta && ansible --version

    [WARNING]: Ansible is being run in a world writable directory ...
    config file = /etc/ansible/ansible.cfg

Il tuo cfg è lì, ma Ansible **lo ignora** e ricade sul leggio di sistema. Non è un
capriccio: è la stessa filosofia dei permessi della chiave privata (capitolo 3) —
un file che decide *cosa viene eseguito* dev'essere scrivibile solo da chi lo
possiede.

### Fase 6 — Il regolamento di produzione

Leggi solution/ansible.cfg: è un cfg **di produzione commentato riga per riga** —
cosa tenere, cosa non mettere mai (host_key_checking = False resta roba da
laboratorio), e perché ogni valore. È il 7.5 del manuale in forma eseguibile.

## Criteri di "fatto"

- Sai dire **quale** cfg è attivo e perché (i quattro leggii in ordine).
- start/ansible.cfg completato: dump --only-changed mostra **forks,
  host_key_checking, become, pipelining** col percorso del tuo file.
- Hai visto la **trappola**: nella cartella world-writable il cfg viene ignorato
  col WARNING.
- Sai spiegare perché la gerarchia **non fonde** i file, e cosa comporta.

## Domande di riflessione

**a.** Il collega dice: "ho messo forks = 50 in ~/.ansible.cfg ma non cambia
niente". Nella cartella del progetto c'è un ansible.cfg. Spiegagli cosa succede e
come verificarlo in un comando.

**b.** Perché Ansible ignora il cfg in una cartella world-writable invece di
limitarsi a un warning? Cosa potrebbe fare un attaccante con un ansible.cfg
avvelenato?

**c.** host_key_checking = False e become = True nel cfg di progetto: comodi nel
lab, rischiosi in produzione. Per ciascuno, di' *quale* rischio introduce come
**default silenzioso** e dove preferiresti dichiararlo invece che nel cfg.

## Pulizia

    rm -rf /tmp/stanza-aperta

## Dove porta

Il regolamento c'è, ma dice inventory = ./inventory.ini — un file che ancora non
esiste. Al capitolo 8 scrivi la **rubrica** (l'inventario): nomi, gruppi e
indirizzi dei musicisti. Al 9, il primo ordine vero via SSH.
