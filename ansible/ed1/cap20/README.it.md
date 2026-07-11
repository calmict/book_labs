# Capitolo 20 — L'arrangiatore

**Livello:** Avanzato

Finora hai *passato* i dati: una variabile qui, una lista lì, un dizionario in un template.
Ma i dati grezzi raramente hanno già la forma che ti serve: hai un elenco di servizi e ne
vuoi solo quelli attivi; hai una configurazione di base e un pacchetto di modifiche per
l'ambiente, e li vuoi fusi; hai una mappa e la vuoi scorrere riga per riga. Il capitolo 20 ti
dà l'**arrangiatore**: Jinja2 nella sua forma piena — i filtri che trasformano, i test che
interrogano, i lookup che pescano — e i template .j2 che, dai dati, scrivono la configurazione
*da soli*. Smetti di scrivere config a mano: la config diventa una *funzione* dei dati.

## Obiettivi

- Le **tre famiglie**: filtri, test, lookup (20.1).
- **default e mandatory**: la rete di sicurezza (20.2).
- Trasformare i dati: **map, select, selectattr** (20.3).
- Lavorare coi dizionari: **dict2items e combine** (20.4).
- I **test**: is defined, is version e gli altri (20.5).
- I **template .j2**: configurazioni che si scrivono da sole (20.6).
- I **lookup**, finalmente per intero (20.7).
- Le **buone abitudini** con Jinja2 (20.8).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- I template e le variabili del capitolo 12; la trappola dei dizionari del capitolo 13 (qui
  torna, con la cura: combine ricorsivo).
- (Nessun nodo: come al capitolo 13, tutto si risolve sul **control node** — connection:
  local. Jinja2 lavora dove sta Ansible.)

## Lo scenario

Hai i dati grezzi di una piccola flotta (start/data.yml): un elenco di servizi (nome,
ambiente, porta, se attivo), una configurazione di base e un pacchetto di override per
l'ambiente. Vuoi che ne esca, sola, una configurazione applicativa: la sezione impostazioni
fusa dagli override, un blocco per ogni servizio *attivo* (in ordine), e la lista delle porte
di produzione. Non la scrivi tu: la scrive l'arrangiatore, a partire dai dati.

## Consegna passo-passo

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

Si esegue node-less, passando il localhost implicito sulla riga di comando:

    ansible-playbook -i localhost, site.yml

### Fase 1 — Le tre famiglie (20.1)

Jinja2, dentro le doppie graffe, ti dà tre attrezzi diversi:

- **Filtri** (dopo la barra |): *trasformano* un valore. nome | upper, lista | sort, porte |
  join(',').
- **Test** (dopo is): *interrogano*, rispondono vero/falso. x is defined, versione is
  version('2.12','>=').
- **Lookup** (funzione lookup(...)): *pescano* un valore da fuori — ambiente, file, un comando,
  il caveau del capitolo 19.

Filtri per rimodellare, test per decidere, lookup per andare a prendere. Domanda a.

### Fase 2 — La rete di sicurezza: default e mandatory (20.2)

Una variabile che non c'è fa esplodere il template con "undefined". Due reti:

- **default**: un valore di ripiego. {{ region | default('eu-south-1') }} — se region manca,
  usa il ripiego. Con default('x', true) il ripiego scatta anche se la variabile è *vuota*, non
  solo se è indefinita.
- **mandatory**: il contrario. {{ api_key | mandatory }} — se manca, *fallisce apposta*,
  subito e con un messaggio chiaro ("Mandatory variable 'api_key' not defined"), invece di
  proseguire con un buco.

default per ciò che è opzionale, mandatory per ciò che è obbligatorio: rendi esplicito quale
delle due.

### Fase 3 — Trasformare i dati: map, select, selectattr (20.3 — TODO 1)

Qui l'arrangiatore lavora davvero. Filtri che concatenati fanno miracoli:

- **map(attribute='campo')**: da una lista di dizionari estrae *un* campo. Servizi → nomi.
- **select / selectattr**: *filtrano* la lista tenendo solo chi passa un test.
  selectattr('enabled') tiene gli attivi; selectattr('env','equalto','prod') tiene i prod.
  (reject/rejectattr fanno il contrario.)

Completa il **TODO 1** in start/site.yml: deriva la lista dei servizi attivi, che il template
userà —

    enabled_services: "{{ services | selectattr('enabled') | list }}"

Concatenali e leggi la potenza: i nomi dei prod attivi sono
services | selectattr('enabled') | selectattr('env','equalto','prod') | map(attribute='name') | list.

### Fase 4 — I dizionari: dict2items e combine (20.4 — TODO 2)

Due problemi ricorrenti coi dizionari:

- **Scorrere** un dizionario in un ciclo: non si può direttamente, ma **dict2items** lo
  trasforma in una lista di coppie {key, value} che *puoi* ciclare (e items2dict fa il
  ritorno).
- **Fondere** due dizionari: **combine**. Completa il **TODO 2**: fondi la base con gli
  override —

      effective_config: "{{ base_config | combine(env_overrides) }}"

Ma attenzione alla trappola già vista al capitolo 13: combine, di default, sui dizionari
*annidati* **sostituisce** invece di fondere. Se base ha server: {host, port} e override ha
server: {port}, il combine semplice *perde host*. La cura è combine(over, recursive=true), che
scende dentro e fonde davvero:

    shallow   = {'server': {'port': 8443}, 'tls': False}                    # host perso!
    recursive = {'server': {'host': '0.0.0.0', 'port': 8443}, 'tls': False} # host salvo

Il playbook te lo mostra affiancato — Domanda b.

### Fase 5 — I test (20.5)

I test rispondono vero/falso e vivono dopo is:

- **is defined / is undefined**: la variabile esiste?
- **is version('2.12','>=')**: confronto *semantico* di versioni (non stringhe: sa che 2.12 >
  2.9). Il playbook lo usa per rifiutarsi di girare su un ansible troppo vecchio.
- e ancora is match / is search (regex), is in, is truthy. I test si usano nelle graffe *e*
  nelle condizioni when (senza graffe, cap. 15).

### Fase 6 — Il template che si scrive da solo (20.6 — TODO 3)

Ora l'arrangiatore compone. Il template start/templates/app.conf.j2 ha già la sezione
impostazioni (un ciclo su effective_config con dict2items) e la riga delle porte prod. Manca
il cuore: un blocco per ogni servizio attivo. Completa il **TODO 3** —

    {% for s in enabled_services | sort(attribute='name') %}

    [{{ s.name }}]
    port = {{ s.port }}
    env = {{ s.env }}
    {% endfor %}

Rendi (il playbook lo fa con il modulo template) e leggi il risultato: una config completa,
ordinata, coi soli servizi attivi — nata *dai dati*, non scritta a mano. Cambi un dato,
rilanci, la config si riscrive; ed è **idempotente**: se i dati non cambiano, changed=0.

    [settings]
    workers = 4
    timeout = 60
    loglevel = debug

    [api-01]
    port = 9090
    env = staging
    ...
    # allowed prod ports: 8080,8081,5432

### Fase 7 — I lookup, per intero (20.7)

Il lookup(...) pesca un valore da *fuori*, e lo hai già incontrato (env al cap. 19, il caveau).
Ora il catalogo:

- **env**: una variabile d'ambiente. **file**: il contenuto di un file. **pipe**: l'output di
  un comando. **template**: rende un altro .j2. **password**: genera (e salva) una password.
  **url**: scarica. **first_found**: il primo file che esiste tra tanti.

Il lookup gira **sul control node**, una volta, quando la riga viene valutata — non sul nodo
gestito. È il modo di *portare dentro* dati che non stanno nelle variabili.

### Fase 8 — Le buone abitudini (20.8)

- **Non esagerare in una riga sola.** Una catena di sei filtri è illeggibile: spezzala in
  variabili intermedie con nomi parlanti (enabled_services, effective_config).
- **Metti le reti**: default per l'opzionale, mandatory per l'obbligatorio; non lasciare che un
  undefined ti esploda in faccia in produzione.
- **combine ricorsivo** quando i dizionari sono annidati (cap. 13).
- **La logica sta nei dati e nel template**, non sparsa in venti task: un template che si
  scrive da solo è più facile da leggere di venti set_fact.

## Criteri di "fatto"

- enabled_services (TODO 1) tiene solo i servizi con enabled vero.
- effective_config (TODO 2) fonde base e override (timeout 60, loglevel debug).
- app.conf reso contiene la sezione [settings] cogli override, un blocco per api-01/db-01/web-01
  (in ordine, **non** web-02 che è disattivo), e "allowed prod ports: 8080,8081,5432".
- Rieseguendo → changed=0 (il template è idempotente).
- Il playbook gira in connection: local, senza nodi.

## Domande di riflessione

**a.** Le tre famiglie di Jinja2 — filtri, test, lookup — fanno cose diverse: trasformare,
interrogare, andare a prendere. Per ciascuna, un esempio dallo scenario, e perché non sono
intercambiabili (perché selectattr non è un test, perché is version non è un filtro)?

**b.** Al capitolo 13 hai visto che un livello di precedenza più alto *sostituisce* l'intero
dizionario. Qui combine, di default, fa lo stesso sui dizionari annidati. Perché
combine(recursive=true) è la cura, cosa perderesti senza, e in cosa è *diverso* dal problema
della precedenza?

**c.** Il template rende una config "che si scrive da sola" a partire dai dati. Cosa guadagni
rispetto a scrivere app.conf a mano — quando aggiungi un servizio, quando cambi un valore per
tutti, quando devi rendere lo stesso schema per dieci ambienti? E dove sta il limite (quando un
template diventa troppo intelligente)?

## Pulizia

Niente da smontare: nessun nodo, nessun container. La config resa finisce in
/tmp/cap20-lab/app.conf (o dove punti CAP20_OUT); cancellala se vuoi.

## Dove porta

Sai dare forma ai dati e farne nascere configurazioni. Ma finora i dati della flotta li hai
*scritti tu*, a mano, nell'inventario. Nel mondo reale la flotta cambia da sola: macchine che
nascono e muoiono nel cloud. Il **capitolo 21** apre gli **inventari dinamici** — l'inventario
non più scritto a mano, ma *generato* interrogando chi le macchine le conosce davvero (il cloud
provider), e i filtri di oggi serviranno a dargli forma.
