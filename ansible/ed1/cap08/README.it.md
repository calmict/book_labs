# Capitolo 8 — La rubrica

**Livello:** Fondamentale

Il direttore ha bacchetta (cap. 6) e regolamento (cap. 7), ma non sa ancora **chi**
sono i musicisti. L'**inventario** è la rubrica: i nomi degli host, i loro
indirizzi, i **gruppi** in cui suonano. È il file che trasforma "un container sulla
porta 2281" in **web1**, e "web1 e web2" in **web** — così da qui in poi dirai
*ansible web* e non un elenco di IP. In questo laboratorio la scrivi in INI, la
verifichi con gli attrezzi giusti, e alla fine il direttore chiama l'appello:
**ping su tutta la flotta, per nome**.

## Obiettivi

- Cos'è un inventario; il formato **INI** (host, gruppi, variabili) e l'equivalente
  **YAML**.
- **Gruppi di gruppi** con :children.
- I **pattern di host**: gruppi, esclusioni (web:!web2), combinazioni.
- I **range**: edge[01:03] — tre host in una riga.
- Variabili di host e di gruppo **nell'inventario**, e la forma ordinata: le
  cartelle **group_vars/** e **host_vars/**.
- I **gruppi magici** all e ungrouped; la verifica con **ansible-inventory**.

## Prerequisiti

- Il venv del capitolo 6 (o ricrealo con start/requirements.txt).
- Docker per i tre nodi. Rete alla prima accensione (apt sui nodi).

## Lo scenario

Tre musicisti: **web1** e **web2** (sezione web), **db1** (sezione db). Insieme
formano **prod**. In rubrica c'è anche una sezione **edge** di tre host *fittizi* —
serviranno a vedere i range e a capire che la rubrica si può leggere e interrogare
anche senza che gli host esistano.

## Consegna passo-passo

### Fase 0 — Accendi i nodi

    bash start/nodes.sh up

Tre container SSH (porte 2281, 2282, 2283), chiave effimera in /tmp/cap08-lab/key.
Sono i managed node del capitolo 2, tre volte.

### Fase 1 — TODO 1: i nomi e le sezioni

Apri start/inventory.ini. La sezione [db] è già scritta come esempio:

    [db]
    db1 ansible_port=2283

Completa il **TODO 1**: la sezione [web] con web1 (porta 2281) e web2 (porta 2282).
Nota la forma: **nome logico** + variabili per-host sulla stessa riga. Il nome
(web1) è come *tu* chiami l'host; dove sta davvero lo dicono le variabili (qui tutti
su 127.0.0.1, cambiano solo le porte — utente, chiave e opzioni SSH da laboratorio
stanno in [all:vars] in fondo al file, già pronti).

### Fase 2 — TODO 2: il gruppo dei gruppi

Completa il **TODO 2**: il gruppo **prod** che contiene web e db — non host,
*gruppi*:

    [prod:children]
    web
    db

:children dice "i membri di questo gruppo sono altri gruppi". È così che la rubrica
scala: domani aggiungi web3 a [web], e prod lo eredita gratis.

### Fase 3 — Verifica: l'albero e i pattern

Mai fidarsi di una rubrica non verificata. L'attrezzo è ansible-inventory:

    ansible-inventory -i inventory.ini --graph

    @all:
      |--@prod:
      |  |--@web:  web1, web2
      |  |--@db:   db1
      |--@edge: ...

L'albero dice tutto: chi sta dove, cosa eredita da cosa. Poi i **pattern** — il
bersaglio di ogni comando è un pattern, e --list-hosts te lo mostra *senza
connetterti*:

    ansible -i inventory.ini web --list-hosts         # un gruppo
    ansible -i inventory.ini 'web:!web2' --list-hosts  # web MENO web2
    ansible -i inventory.ini all --list-hosts          # tutti

L'esclusione :! è il pattern che userai il giorno in cui web2 è rotto e vuoi agire
su tutti gli altri.

### Fase 4 — I range: tre host in una riga

Guarda la sezione [edge] già scritta:

    [edge]
    edge[01:03].lab.internal

    ansible -i inventory.ini edge --list-hosts

Tre host: edge01, edge02, edge03. Non esistono davvero — e non importa: la rubrica è
un *documento*, la puoi scrivere e interrogare prima che le macchine nascano. I
range funzionano anche alfabetici ([a:c]) e sono il modo di dichiarare una flotta
numerata senza scrivere cento righe.

### Fase 5 — TODO 3: le variabili escono dalla rubrica

Le variabili per-riga (Fase 1) vanno bene per l'indirizzo; per tutto il resto
sporcano il file. La forma ordinata: accanto all'inventario, una cartella
**group_vars/** con un file per gruppo. Completa il **TODO 3**: crea
group_vars/web.yml con

    http_port: 8080
    greeting: hello from the web section

e verifica che web1 la *veda*:

    ansible -i inventory.ini web1 -m debug -a 'var=greeting'

Il modulo debug stampa la variabile: web1 l'ha **ereditata dal gruppo** web. Esiste
anche host_vars/ (un file per host). La regola d'ordine: nell'inventario solo *chi
sei e dove stai*; in group_vars/host_vars *come sei fatto*. (La precedenza fra
questi livelli è il capitolo 13.)

### Fase 6 — I gruppi magici

Due gruppi esistono sempre senza dichiararli: **all** (tutti) e **ungrouped** (chi
non sta in nessun gruppo tuo). Prova:

    ansible -i inventory.ini ungrouped --list-hosts

Zero host: tutti i tuoi stanno in una sezione. Aggiungi una riga solitaria in cima
al file (fuori da ogni sezione) e rilancia: eccolo in ungrouped. È il gruppo-spia
degli host dimenticati.

### Fase 7 — L'appello

Il momento per cui è nato tutto:

    ansible -i inventory.ini prod -m ping

    web1 | SUCCESS => "ping": "pong"
    web2 | SUCCESS => "ping": "pong"
    db1  | SUCCESS => "ping": "pong"

Tre pong. Ansible ha letto la rubrica, aperto tre SSH **in parallelo** (i forks del
cap. 7), eseguito il modulo col Python di ogni nodo (il viaggio del cap. 2) — e tu
hai chiamato la flotta **per nome**. Nota cosa NON hai fatto: nessun IP, nessuna
porta, nessun comando ssh scritto a mano.

## Criteri di "fatto"

- ansible-inventory --graph mostra **prod → web(web1,web2) + db(db1)** e edge coi 3
  host del range.
- I pattern rispondono: web → 2 host, 'web:!web2' → 1, ungrouped → 0.
- group_vars/web.yml esiste e debug stampa greeting su web1.
- **ansible prod -m ping → 3 SUCCESS**.

## Domande di riflessione

**a.** INI e YAML descrivono la stessa rubrica. Quando preferiresti l'uno o
l'altro? (Pensa a: file corti vs strutture profonde, e chi altro deve leggerlo.)

**b.** Perché i comandi si danno ai **gruppi** e non agli host? Cosa compra, il
giorno che la flotta passa da 3 a 300 host, aver scritto ansible web invece di
ansible web1,web2?

**c.** Le variabili possono stare sulla riga dell'host, in [gruppo:vars], o in
group_vars/. Perché la cartella è la forma che scala meglio — e quale problema
*nuovo* introduce avere la stessa variabile definita in più posti? (Anticipo del
capitolo 13.)

## Pulizia

    bash start/nodes.sh down

## Dove porta

La rubrica c'è e risponde all'appello. Al capitolo 9 arrivano gli **ordini
ad-hoc**: un comando, un modulo, tutta la flotta — ping era solo il primo. E
l'inventario che hai scritto qui è lo stesso che il capitolo 21 renderà *dinamico*:
generato dal cloud invece che scritto a mano.
