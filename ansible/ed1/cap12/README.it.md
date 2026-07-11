# Capitolo 12 — Le annotazioni sullo spartito

**Livello:** Intermedio

Lo spartito del capitolo 10 era rigido: /etc/motd, porta 80, quei valori scritti dentro
il playbook. Ma web1 e web2 non sono identici — porte diverse, limiti diversi — e
riscrivere il playbook per ciascuno sarebbe la crepa del capitolo 1 che ritorna. Le
**variabili** sono le annotazioni a matita sullo spartito: un valore con un **nome**,
scritto una volta e riusato ovunque, che può arrivare da tante fonti — il gruppo, il
singolo host, la riga di comando, i fatti che Ansible scopre da solo. In questo capitolo
vedi che forma hanno (i tipi), come si usano (le doppie graffe di Jinja2), **dove
vivono**, come catturare al volo un risultato, e come tenerle in ordine.

## Obiettivi

- **Perché** le variabili: un playbook, molti nodi (12.1).
- I **tipi** di valore: stringa, intero, booleano, lista, dizionario (12.2).
- Le **doppie graffe** di Jinja2: usarle, accedere a liste e dizionari (12.3).
- **Dove vivono**: play, inventario (group_vars/host_vars), riga di comando -e (12.4).
- I **fatti**: le variabili che Ansible scopre da solo (12.5).
- **Catturare i risultati**: register e set_fact (12.6).
- Le **reti di sicurezza**: i valori di default (12.7).
- **Mettere ordine**: dove conviene definire cosa (12.8).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- Docker per due nodi. Rete alla prima accensione.
- Il playbook del capitolo 10; i group_vars del capitolo 8; il YAML del capitolo 4.

## Lo scenario

Due nodi nel gruppo **web**. Un unico template, config.j2, viene renderizzato in
/etc/myapp/config.ini su ciascuno — ma il file **non** è identico: web1 gira sulla porta
8080, web2 sulla 8081, e ogni nodo dichiara il proprio hostname e il proprio numero di
worker. Un solo spartito, due esecuzioni diverse, tutto guidato dalle variabili.

## Consegna passo-passo

### Fase 0 — Accendi i nodi

    bash start/nodes.sh up

Due container (web1, web2) con l'utente deploy.

### Fase 1 — Perché, e che forma hanno

Senza variabili scriveresti un playbook per web1 e uno per web2: due file quasi uguali
che divergono nel tempo (la crepa del cap. 1). Con le variabili scrivi **un** playbook e
cambi solo i valori. E i valori hanno una **forma** — i tipi del cap. 4, ora al lavoro:

- **stringa**: app_name: orchestra
- **intero**: port: 8080
- **booleano**: debug_mode: false
- **lista**: features: [metrics, tracing, healthcheck]
- **dizionario**: limits: { max_connections: 200, timeout_seconds: 30 }

(Ricorda il cap. 4: false è un booleano, non la stringa "false"; renderizzato in un file
diventa il False di Python. Se ti serve la stringa minuscola, in Jinja2 c'è | lower.)

### Fase 2 — Le doppie graffe di Jinja2 (TODO 2)

Una variabile si *usa* dentro **{{ }}**: Ansible sostituisce il nome col valore. Apri
start/config.j2 e completa il **TODO 2** — le righe che pescano dalle variabili, incluso
l'accesso a una **lista** e a un **dizionario**:

    # {{ app_name }} config, rendered on {{ ansible_hostname }}
    port = {{ port }}
    features = {{ features | join(', ') }}
    max_connections = {{ limits.max_connections }}
    log_level = {{ log_level | default('info') }}

Nota tre gesti di Jinja2: **{{ features | join(', ') }}** trasforma la lista in una riga
(il | è un *filtro*, il cap. 20 ne è pieno); **{{ limits.max_connections }}** entra nel
dizionario col punto; **{{ ansible_hostname }}** non l'hai definita tu — è un **fatto**
(Fase 4).

### Fase 3 — Dove vivono le variabili (TODO 1)

La stessa variabile può stare in posti diversi. Completa il **TODO 1** in
start/group_vars/web.yml, aggiungendo la lista features e il dizionario limits. Poi guarda
le quattro fonti in gioco:

- **group_vars/web.yml**: valgono per *tutto* il gruppo web (app_name, port, features,
  limits).
- **host_vars/web2.yml**: valgono per *quel solo* host — qui port: 8081, che **vince**
  sul group_vars per web2.
- **vars: del play** (config_dir: /etc/myapp): locali a questo play.
- **riga di comando -e**: la più forte di tutte. Prova:

      ansible-playbook -i start/inventory.ini start/site.yml -e app_name=canary

  Nel file renderizzato app_name è canary su *entrambi* i nodi: l'extra var ha battuto il
  group_vars. (Perché -e vinca su group_vars c'è una regola precisa — sono le 22 del
  capitolo 13. Qui basti sapere che la riga di comando comanda.)

### Fase 4 — I fatti: le variabili che Ansible scopre da solo

{{ ansible_hostname }} funziona senza che tu l'abbia definita: è un **fatto**, raccolto
dal Gathering Facts all'inizio del play (l'intervista del cap. 2). Ansible ne scopre
centinaia — ansible_hostname, ansible_distribution, ansible_default_ipv4.address,
ansible_processor_vcpus… — e li mette sotto ansible_facts. Sono la miniera da cui il
config si adatta *alla macchina* senza che tu scriva un valore a mano.

### Fase 5 — Catturare i risultati: register e set_fact (TODO 3)

A volte il valore non lo sai in anticipo: lo scopri eseguendo qualcosa sul nodo. Due
strumenti:

- **register** cattura l'esito di un task in una variabile:

      - name: How many CPUs does this node have?
        ansible.builtin.command: nproc
        register: nproc_result
        changed_when: false

  Ora nproc_result.stdout contiene il numero di CPU.

- **set_fact** crea una *nuova* variabile calcolata. Completa il **TODO 3**:

      - name: Derive the worker count (2 per CPU)
        ansible.builtin.set_fact:
          worker_count: "{{ nproc_result.stdout | int * 2 }}"

Il | int converte la stringa in numero, poi * 2. Nel config comparirà workers = 8 (su una
macchina a 4 CPU) — un valore che si **adatta al nodo**, non scolpito a mano.

### Fase 6 — Reti di sicurezza: i default

Nel template c'è {{ log_level | default('info') }}, ma log_level non è definita da nessuna
parte. Senza il filtro **default**, Ansible fallirebbe con "'log_level' is undefined". Con
| default('info'), la variabile mancante scivola su un valore ragionevole. È la rete di
sicurezza per le variabili opzionali: il playbook non si rompe se qualcuno dimentica di
impostarla.

### Fase 7 — Mettere ordine: dove conviene definire cosa

La libertà di mettere una variabile ovunque diventa caos se non hai una regola. La
convenzione:

- vale per **tutto un gruppo** → group_vars/<gruppo>.yml
- vale per **un solo host** → host_vars/<host>.yml
- serve **solo a questo play** → vars: nel play
- override **una tantum a runtime** → -e sulla riga di comando

Regola d'oro: nell'inventario *chi sei e dove abiti*, nei group_vars/host_vars *di cosa
sei fatto*. Meno posti diversi tocchi per lo stesso valore, meno sorprese avrai — e le
sorprese, quando lo stesso nome è definito in due punti che litigano, sono l'argomento del
capitolo 13.

## Criteri di "fatto"

- config.ini renderizzato contiene tutti i tipi: stringa (app_name), intero (port),
  booleano (debug), lista (features), dizionario (max_connections/timeout).
- **web1 port=8080** (group_vars), **web2 port=8081** (host_vars vince).
- **-e app_name=canary** → canary su entrambi (extra var vince).
- workers viene da **set_fact** (nproc × 2); log_level viene dal **default** (info).
- Rieseguendo → **changed=0** (idempotenza).

## Domande di riflessione

**a.** debug_mode: false è un booleano e nel file renderizzato diventa False (di Python).
Collega al cap. 4: perché false/no/yes sono trappole, e quando metteresti un valore fra
virgolette per tenerlo una stringa? Cosa cambierebbe scrivendo {{ debug_mode | lower }}?

**b.** register e set_fact catturano valori "a runtime". Qual è la differenza fra i due, e
perché calcolare worker_count da nproc con set_fact è meglio che scrivere workers = 8 a
mano nel group_vars? (Pensa a un nodo con 8 CPU invece di 4.)

**c.** app_name è in group_vars, ma -e app_name=canary l'ha battuto. Dove conviene definire
una variabile "stabile del gruppo" e dove una "override di una sera"? E quando lo stesso
nome è impostato in *due* posti che non concordano, chi decide chi vince — e perché ci
vuole un intero capitolo (il 13) per rispondere?

## Pulizia

    bash start/nodes.sh down

## Dove porta

Hai visto una variabile vivere in quattro posti, e la riga di comando battere il
group_vars. Non è stato un caso: Ansible ha una gerarchia di **22 livelli di precedenza**,
dal più debole (i default di ruolo) al più forte (-e). Il capitolo 13 li mette in fila
tutti e ti insegna a non farti sorprendere dal valore che "misteriosamente" vince.
