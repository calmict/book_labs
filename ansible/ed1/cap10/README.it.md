# Capitolo 10 — Lo spartito scritto

**Livello:** Fondamentale

Al capitolo 9 il direttore dava cenni al volo: un modulo, un bersaglio, subito. Utili,
ma effimeri — nessuna traccia, niente da rivedere, niente da rieseguire con fiducia.
Ora scrivi la **partitura**: il **playbook**, un file YAML che mette gli stessi moduli
in ordine, con un nome, sotto controllo di versione. Questo è il cuore di Ansible — da
qui in poi quasi tutto è un playbook. Impari la struttura a strati (play → task →
modulo), scrivi il tuo primo playbook riga per riga, impari a leggerne l'output, e
riscopri la proprietà più importante di tutte: **rieseguirlo non fa danni** (la prova
del nove del cap. 5, ora su scala).

## Obiettivi

- Perché il playbook, e non il cenno: **ripetibile, versionato, rivedibile**.
- La **struttura a strati**: play (chi + lista di task) → task (nome + modulo +
  argomenti) → modulo.
- Il **primo playbook riga per riga**: ---, name, hosts, become, vars, tasks.
- **Eseguire e leggere l'output**: PLAY, TASK, Gathering Facts, PLAY RECAP e i suoi
  contatori.
- La **prova del nove**: rieseguire → changed=0 (idempotenza).
- **Più play** nello stesso file.
- Direttive utili subito: **vars**, **become_user**, **tag** (--tags / --skip-tags).
- **Buone abitudini** fin dalla prima riga.

## Prerequisiti

- Il venv del capitolo 6 (o ricrealo con start/requirements.txt).
- Docker per tre nodi. Rete alla prima accensione.
- I moduli copy e file del capitolo 9; l'inventario del capitolo 8.

## Lo scenario

Tre nodi: **web1** e **web2** (gruppo web), **db1** (gruppo db). Ti colleghi come
**deploy** (sudo senza password), così become funziona come al cap. 9. Un solo file,
site.yml, configura entrambi i livelli — il web e il database — in due play distinti.

## Consegna passo-passo

### Fase 0 — Accendi i nodi

    bash start/nodes.sh up

Tre container con l'utente deploy, sshd e python3.

### Fase 1 — Dal cenno allo spartito: l'anatomia

Il cap. 9 finiva con una domanda: cosa fai quando l'operazione va **ripetuta**, messa
in ordine, versionata, fatta rivedere da un collega? La risposta: uno spartito scritto.
Ecco la sua struttura a strati:

- un **play** dice *a chi* (hosts) e porta una **lista di task**;
- un **task** ha un **name** (in italiano leggibile), chiama **un solo modulo** e gli
  passa gli argomenti;
- il **modulo** è l'attrezzo del cap. 9 (copy, file, …), stavolta scritto, non digitato
  al volo.

Tre strati, dall'alto in basso: chi → cosa in ordine → con quale attrezzo.

### Fase 2 — Il primo playbook, riga per riga (TODO 1)

Apri start/site.yml. L'intestazione del primo play è già scritta:

    ---
    - name: Configure the web tier
      hosts: web
      become: true
      vars:
        app_dir: /etc/cap10.d
      tasks:

--- apre il documento (cap. 4). Il play è **una voce di lista** (il - davanti a name):
nome, bersaglio (hosts: web), i gradi da root per tutto il play (become: true), una
variabile di play (vars: app_dir), e poi tasks:.

Completa il **TODO 1**: il primo task, che deploya il motd con **copy** — lo stesso
modulo del cap. 9, ora in forma di task:

    - name: Deploy the message of the day
      ansible.builtin.copy:
        src: motd
        dest: /etc/motd
        mode: "0644"
      tags: [content]

Nota tre cose: il **name** in chiaro; il modulo scritto col nome completo
**ansible.builtin.copy** (buona abitudine, cap. 17); il **mode quotato** "0644" (cap. 4:
0644 senza virgolette diventa un intero ottale).

### Fase 3 — Una variabile e un task come root (TODO 2)

Completa il **TODO 2**: il task che assicura la cartella dell'app, usando la variabile
del play:

    - name: Ensure the app directory exists
      ansible.builtin.file:
        path: "{{ app_dir }}"
        state: directory
        mode: "0755"
      tags: [structure]

Le doppie graffe {{ app_dir }} sono Jinja2 (il motore del cap. 12): "metti qui il
valore della variabile". Il task successivo è già scritto e mostra **become_user**: il
play sale a root, ma un singolo task può precisare *quale* utente diventare:

    - name: Drop a marker owned by root
      ansible.builtin.copy:
        content: "web tier configured by Calm ICT\n"
        dest: "{{ app_dir }}/marker"
        mode: "0644"
      become_user: root

### Fase 4 — Eseguire, e leggere l'output

Il cenno si lanciava con ansible; lo spartito con **ansible-playbook**:

    ansible-playbook -i start/inventory.ini start/site.yml

Leggi l'output dall'alto:

    PLAY [Configure the web tier] **************
    TASK [Gathering Facts] ********************      # l'intervista del cap. 2, in automatico
    ok: [web1]
    TASK [Deploy the message of the day] ******
    changed: [web1]
    ...
    PLAY RECAP ********************************
    web1 : ok=4  changed=3  unreachable=0  failed=0  ...

Ogni **PLAY** è un'intestazione, ogni **TASK** una riga per nodo, coi colori del cap. 5
(ok verde, changed giallo). Il **Gathering Facts** è l'intervista del cap. 2 che Ansible
fa da solo all'inizio del play. Il **RECAP** finale è il bilancio per nodo: quanti ok,
quanti changed, quanti irraggiungibili, quanti falliti.

### Fase 5 — La prova del nove: rieseguire

Rilancia lo **stesso** comando. Guarda il recap:

    web1 : ok=4  changed=0  unreachable=0  failed=0

**changed=0.** Nulla è cambiato perché nulla *doveva* cambiare: copy e file sono
interruttori (cap. 5), controllano lo stato e restano fermi se è già quello giusto. È
la proprietà che rende un playbook affidabile: lo puoi rieseguire cento volte e converge
sempre allo stesso stato. (Se qui avessi usato command invece di copy — un campanello
del cap. 9 — vedresti changed a ogni giro, e perderesti la prova del nove: è la Domanda
a.)

### Fase 6 — Più play nello stesso file (TODO 3)

Un file può contenere **più play**. Completa il **TODO 3**: un secondo play che
configura il database, con lo stesso schema del primo ma bersaglio db:

    - name: Configure the database tier
      hosts: db
      become: true
      tasks:
        - name: Ensure the data directory exists
          ansible.builtin.file:
            path: /etc/cap10-db.d
            state: directory
            mode: "0755"
          tags: [structure]

Rilancia: ora vedi **due** intestazioni PLAY, e nel recap compare anche db1. Un solo
file, un solo comando, due livelli dell'infrastruttura configurati in ordine.

### Fase 7 — I tag: eseguire una parte sola

I **tag** etichettano i task perché tu ne esegua un sottoinsieme. Prova:

    ansible-playbook -i start/inventory.ini start/site.yml --tags structure
    ansible-playbook -i start/inventory.ini start/site.yml --skip-tags content
    ansible-playbook -i start/inventory.ini start/site.yml --list-tags

--tags structure esegue **solo** i task etichettati structure (le cartelle);
--skip-tags content salta i copy; --list-tags te li elenca senza eseguire. Utile quando
lo spartito è lungo e vuoi rieseguire solo un movimento. (Il Gathering Facts non è un
task tuo: gira comunque.)

### Fase 8 — Buone abitudini fin dalla prima riga

- **name su ogni task**: l'output diventa leggibile e puoi ripartire da un punto preciso
  (--start-at-task) — è la Domanda b.
- **un modulo per task**: un task fa una cosa sola.
- **nome completo del modulo** (ansible.builtin.copy): niente ambiguità (cap. 17).
- **quota i valori ambigui** del cap. 4 ("0644", "yes").
- prima di eseguire, **--syntax-check**: legge lo spartito senza toccare i nodi.

## Criteri di "fatto"

- ansible-playbook site.yml mostra **due play** e un recap con web1/web2 (**ok=4
  changed=3**) e db1 (**ok=2 changed=1**).
- **Rieseguendo → changed=0** su tutti e tre (idempotenza).
- **--tags structure** esegue solo i task delle cartelle; **--skip-tags content** salta
  i copy.
- **--syntax-check** passa.

## Domande di riflessione

**a.** Rieseguire il playbook dà changed=0: perché questa è la proprietà più importante
di tutte? E se il primo task usasse command "echo ... > /etc/motd" invece di copy, cosa
vedresti al secondo giro — e cosa avresti perso? (Collega al campanello del cap. 9.)

**b.** Ogni task ha un name in italiano leggibile. È solo cosmesi per l'output, o compra
qualcosa di concreto quando il playbook cresce, fallisce a metà, o finisce in un log di
audit? (Pensa a --start-at-task e a chi legge l'esito fra sei mesi.)

**c.** become: true sta sul play, ma become_user: root sta su un singolo task. Chi
diventa chi, e perché conviene **dichiarare** il privilegio nello spartito invece di
passarlo a mano a ogni comando come al cap. 9? (Anteprima del cap. 11.)

## Pulizia

    bash start/nodes.sh down

## Dove porta

Hai scritto lo spartito e lo rieseguì senza paura. Finora però il privilegio era un
interruttore acceso in blocco (become: true). Il capitolo 11 apre quella scatola:
**become in profondità** — sudoers, la password con -K, diventare utenti diversi da
root, e i metodi oltre sudo. Il primo vero passo nella fascia Intermedio.
