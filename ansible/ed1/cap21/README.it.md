# Capitolo 21 — L'appello

**Livello:** Avanzato

Al capitolo 8 hai scritto la rubrica a mano: un file con i nodi, uno per riga. Funziona finché
la flotta sta ferma. Ma nel mondo reale la flotta *si muove da sola*: macchine che nascono
quando il carico sale e muoiono quando scende, nel cloud, mentre tu dormi. Una rubrica scritta
a mano è vecchia nel momento in cui la salvi. La risposta è ribaltare il meccanismo: invece di
*elencare* i nodi, li fai **presentare all'appello** — Ansible chiede a chi la flotta la conosce
davvero (il provider) "chi c'è adesso?", e costruisce l'inventario *sul momento*. Qui il
provider è il demone Docker, e la flotta sono container che vanno e vengono; ma AWS, Azure, GCP
funzionano identici.

## Obiettivi

- Statico contro dinamico: il **cambio di mentalità** (21.1).
- Il meccanismo: i **plugin di inventario** (21.2).
- Il primo inventario dinamico su **AWS** (21.3, galleria).
- La vera magia: raggruppare con **keyed_groups** (21.4).
- **groups e compose**: i filtri Jinja2 al lavoro (21.5).
- Nomi leggibili e prestazioni: **hostnames e cache** (21.6).
- Le **buone abitudini** con gli inventari dinamici (21.7).

## Prerequisiti

- Il venv del capitolo 6, più le librerie docker e requests (in start/requirements.txt).
- La collezione community.docker (la installi tu, come al capitolo 17).
- I filtri Jinja2 del capitolo 20: qui tornano, a dare forma all'inventario.
- Docker: la flotta vive in un **motore Docker isolato** (docker-in-docker), così il plugin
  vede *solo* i nodi del lab e mai altri container della macchina.

## Lo scenario

Lo script nodes.sh accende un motore Docker isolato — il nostro "cloud" — e dentro ci mette tre
container con delle **etichette** (role=web/db, env=prod/staging): sono le macchine della
flotta, e le etichette sono i *tag* del cloud. Tu scrivi un file di inventario che non elenca
nessun nodo: dice solo *come chiederli*. Ansible interroga il motore, scopre i tre container, e
li raggruppa da solo per etichetta — poi ci parli senza SSH, via la connessione docker.

Prima accendi la flotta ed esporta l'indirizzo del motore isolato (lo stampa nodes.sh):

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    ansible-galaxy collection install -r start/requirements.yml
    cd start
    ./nodes.sh up
    export DOCKER_HOST=tcp://127.0.0.1:23751

### Fase 1 — Statico contro dinamico (21.1)

Guarda le due rubriche affiancate:

    ansible-inventory -i inventory.ini --graph          # statica: i nodi che HAI SCRITTO
    ansible-inventory -i inventory.docker.yml --graph   # dinamica: i nodi che CI SONO

La prima elenca ciò che hai messo tu, e resta identica anche se un nodo è morto un'ora fa. La
seconda non elenca nulla: *va a chiedere*, e ti restituisce la flotta viva in questo istante.
Statico = una fotografia; dinamico = uno specchio. Domanda a.

### Fase 2 — Il meccanismo: i plugin di inventario (21.2)

Il file dinamico non è un elenco, è la **configurazione di un plugin**. La prima riga dice
quale:

    plugin: community.docker.docker_containers
    docker_host: tcp://127.0.0.1:23751

Il plugin (uno per fonte: docker, aws_ec2, azure_rm, gcp_compute...) sa come interrogare
*quella* fonte e trasformare la risposta in host, gruppi e variabili. Tu passi il file a -i come
faresti con una rubrica statica: Ansible riconosce che è la config di un plugin e lo esegue. (Il
plugin va *abilitato*: lo trovi in ansible.cfg, sezione [inventory].)

### Fase 3 — AWS, il caso reale (21.3, galleria)

Nel mondo vero la fonte è spesso AWS. In start/gallery/aws_ec2.yml.example trovi la forma —
plugin: amazon.aws.aws_ec2, regioni, filtri, raggruppamenti per tag — che *non* eseguiamo (serve
un account AWS), ma è identica nel disegno a quella docker: cambia il plugin e la fonte, non
l'idea. Quello che impari qui vale lì.

### Fase 4 — La vera magia: keyed_groups (21.4 — TODO 1)

Scoprire i nodi è metà; l'altra metà è **raggrupparli da soli**. keyed_groups crea gruppi *a
partire da un dato* di ogni host — qui, le etichette del container (i tag del cloud). Completa
il **TODO 1** in inventory.docker.yml:

    keyed_groups:
      - key: docker_config.Labels['role'] | default('none')
        prefix: role
      - key: docker_config.Labels['env'] | default('none')
        prefix: env

Ora, senza scrivere un solo nome, esistono i gruppi role_web, role_db, env_prod, env_staging — e
si popolano da soli man mano che i container nascono. Aggiungi un container con role=web e
comparirà in role_web al prossimo appello. Domanda b.

    ansible-inventory -i inventory.docker.yml --graph

### Fase 5 — groups e compose: Jinja2 al lavoro (21.5 — TODO 2)

Due strumenti in più, ed è qui che rientrano i filtri del capitolo 20:

- **groups**: crea un gruppo se una *condizione* Jinja2 è vera. Completa il **TODO 2**: un gruppo
  production per i soli nodi con env=prod —

      groups:
        production: "docker_config.Labels['env'] | default('') == 'prod'"

- **compose**: costruisce *variabili host* da espressioni Jinja2. Nel file è già dato l'uso
  essenziale: compose imposta ansible_connection alla connessione docker (così parli ai container
  senza SSH), e ricava service_role dall'etichetta:

      compose:
        ansible_connection: "'community.docker.docker'"
        service_role: "docker_config.Labels['role'] | default('unknown')"

keyed_groups raggruppa, groups decide, compose arricchisce — i tre modi di dare *senso* ai nodi
grezzi che arrivano dalla fonte.

### Fase 6 — Nomi leggibili e cache (21.6)

- **hostnames**: da cosa prendere il *nome* dell'host. Un id Docker è illeggibile; nel file è
  dato hostnames: [docker_name], così vedi cap21-web1, non 3f9a2c... . Su AWS sceglieresti il
  tag Name o l'IP privato.
- **cache**: interrogare il provider a ogni comando costa (su AWS, chiamate API a migliaia di
  istanze). La **cache** salva la risposta per un po', così i comandi successivi sono immediati.
  È un'opzione del plugin (cache: true + un plugin di cache); comodissima in produzione, la citi
  tra le buone abitudini.

### Fase 7 — Usare i gruppi dinamici (TODO 3)

Un inventario serve per *agire*. Completa il **TODO 3** in site.yml: fai puntare il play al
gruppo che keyed_groups ha creato per il tier web —

    hosts: role_web

Esegui:

    ansible-playbook -i inventory.docker.yml site.yml

Il play tocca *solo* web1 e web2 (non db1), scrive il marker, ed è idempotente (rieseguendo,
changed=0). Non hai nominato un solo host: hai detto "il tier web", e l'appello ha fatto il
resto.

### Fase 8 — Le buone abitudini (21.7)

- **Non fidarti dei nomi, fidati dei tag.** In un inventario dinamico gli host vanno e vengono:
  targettizza per gruppo (role_web, production), mai per nome fisso.
- **Attiva la cache** quando la fonte è lenta o grande, ma ricordati che *può mentire* (mostra
  l'ultima foto): svuotala quando serve il dato fresco.
- **hostnames leggibili** e keyed_groups parlanti: un inventario dinamico si legge bene solo se
  lo progetti bene.
- **La stessa mentalità per ogni cloud**: imparato il meccanismo (plugin + keyed_groups +
  compose), cambi solo il plugin per passare da docker ad AWS, Azure, GCP.

## Criteri di "fatto"

- L'inventario dinamico scopre i tre container della flotta (cap21-web1/web2/db1) senza che tu ne
  scriva i nomi.
- keyed_groups (TODO 1) crea role_web (web1, web2), role_db (db1), env_prod (web1, db1),
  env_staging (web2).
- groups (TODO 2) crea production con web1 e db1 (i soli env=prod).
- compose rende ogni nodo raggiungibile via connessione docker: ansible role_web -m ping → pong.
- site.yml (TODO 3) su role_web tocca solo web1 e web2; rieseguendo → changed=0.

## Domande di riflessione

**a.** Un inventario statico (cap. 8) e uno dinamico descrivono la stessa flotta. Perché il primo
è "una fotografia" e il secondo "uno specchio", e cosa succede a ciascuno quando alle 3 di notte
l'autoscaler aggiunge dieci macchine e ne toglie cinque? Quando lo statico va ancora benissimo?

**b.** keyed_groups crea gruppi da un dato dell'host (qui l'etichetta, su AWS il tag). Perché è
più robusto targettizzare "il gruppo role_web" invece di elencare a mano web1, web2, web3? Cosa
non devi più fare quando nasce web4, e perché targettizzare per nome fisso è un errore in un
mondo dinamico?

**c.** compose costruisce variabili host con Jinja2, e nel lab lo usi per impostare la connessione
(docker invece di SSH) e per ricavare service_role dall'etichetta. In che senso questo è "lo
stesso arrangiatore del capitolo 20" applicato all'inventario invece che a un file di config? E
cosa ti permette di fare compose che i dati grezzi della fonte, da soli, non ti darebbero?

## Pulizia

    ./nodes.sh down        # rimuove il motore isolato e con lui tutta la flotta

Il motore docker-in-docker è isolato: spento lui, i tre container spariscono con lui, e nessun
altro container della tua macchina è stato mai toccato.

## Dove porta

Sai scoprire la flotta invece di elencarla. Ma finora hai dato per scontato che ogni task vada a
buon fine: e quando un nodo, tra i mille dell'appello, non risponde, o un comando fallisce a
metà? Il **capitolo 22** apre la **gestione degli errori** — block/rescue/always, until/retries,
assert/fail — per orchestrare una flotta dove qualcosa, prima o poi, andrà storto.
