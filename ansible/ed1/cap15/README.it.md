# Capitolo 15 — Se, e per ciascuno

**Livello:** Intermedio

Finora ogni task faceva una cosa, una volta, sempre. Ma la realtà si adatta: dev e prod
non sono uguali, certe feature sono opzionali, certe azioni vanno ripetute su venti
elementi. Servono due nuovi poteri. **when** dà al task la capacità di *decidere*: agisci
solo *se* una condizione è vera. **loop** gli dà quella di *ripetere*: un solo task, molti
elementi. Con questi due — e con la trappola delle graffe che li accompagna — un playbook
smette di essere una lista fissa e diventa una procedura intelligente.

## Obiettivi

- Il **problema**: un playbook che si adatta (15.1).
- **when**: il task che decide se agire (15.2), e la **trappola delle graffe** (15.3).
- **register + when**: condizioni sull'esito di un task (15.4).
- **Condizioni composte**: and, or, la lista AND (15.5); e **is defined** (15.6).
- **loop**: un task, molti elementi (15.7), anche liste di **dizionari** (15.8).
- **loop + register** e **loop_control** (15.9, 15.10); i vecchi **with_*** (15.11).
- Le **graffe, una volta per tutte** (15.13).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- Docker per un nodo. Rete alla prima accensione.
- Le variabili e Jinja2 del capitolo 12; lo stato changed del capitolo 5.

## Lo scenario

Un nodo, **web1**, che provisioni in modo **adattivo**: crea gli utenti dell'app e le
cartelle delle feature (ripetizione), ma piazza il marcatore di produzione solo in prod,
abilita le metriche solo se richieste, applica il tuning solo se glielo passi (decisione).
Un solo playbook che si comporta diversamente a seconda di come lo chiami.

## Consegna passo-passo

### Fase 0 — Accendi il nodo

    bash start/nodes.sh up

Un container (web1) con l'utente deploy.

### Fase 1 — Il problema

Un playbook rigido fa *sempre* le stesse cose. Ma tu vuoi che lo *stesso* file configuri
dev e prod, crei tre cartelle senza scrivere tre task, e salti del tutto un'azione quando
non serve. Ti servono un interruttore per decidere e un moltiplicatore per ripetere: when e
loop.

### Fase 2 — when, e la trappola delle graffe

**when** aggiunge a un task una condizione: il task agisce solo se è vera, altrimenti
compare skipping. Guarda il task del marcatore di produzione, già scritto:

    - name: Drop the production marker (prod only)
      ansible.builtin.copy:
        content: "PROD\n"
        dest: /srv/app/PRODUCTION
      when: app_env == 'prod'

Con app_env=dev, l'output dice skipping: [web1] e il file non nasce. Con -e app_env=prod, il
task agisce.

**La trappola delle graffe (15.3):** in un modulo scrivi "{{ app_env }}" per *inserire* il
valore; in when scrivi app_env == 'prod' **senza** graffe. Perché when è *già*
un'espressione Jinja2: Ansible la valuta da sola. Se ci metti le graffe — when: "{{ app_env
== 'prod' }}" — funziona ma ti becchi il WARNING "conditional statements should not include
jinja2 templating". Regola: dentro when, espressioni nude.

(Nota: la variabile si chiama app_env, non environment — quest'ultimo è un nome *riservato*
di Ansible.)

### Fase 3 — loop: un task, molti elementi (TODO 1)

La cartella delle feature è già ripetuta con **loop** su una lista semplice:

    - name: Create the feature directories
      ansible.builtin.file:
        path: "/srv/app/{{ item }}"
        state: directory
      loop: "{{ feature_dirs }}"       # [logs, cache, run]

Dentro il loop, ogni elemento è **item**. Completa il **TODO 1**: crea gli utenti dell'app
con un loop su una **lista di dizionari** (15.8), dove ogni item ha più campi:

    - name: Create the application users
      ansible.builtin.user:
        name: "{{ item.name }}"
        shell: "{{ item.shell }}"
        create_home: false
      loop: "{{ app_users }}"
      loop_control:
        label: "{{ item.name }}"

item.name e item.shell entrano nel dizionario col punto. E **loop_control: label** (15.10)
tiene pulito l'output: invece di stampare l'intero dizionario a ogni giro, mostra solo il
nome. (loop_control offre anche loop_var, per rinominare item nei loop annidati, e
index_var.)

Due note utili: registrare un loop (15.9) — register su un task con loop — ti dà un
risultato la cui .results è una **lista**, un elemento per iterazione, da scorrere per
ispezionare ogni giro. E i vecchi **with_items**, with_dict… (15.11) sono la forma storica
di loop: funzionano ancora, ma la nuova è loop — usa quella.

### Fase 4 — register + when: agire sull'esito (TODO 3)

A volte la condizione dipende da *com'è il nodo adesso*. Prima lo interroghi (register),
poi decidi (when). Il task che cerca la sentinella è già scritto:

    - name: Look for the first-run sentinel
      ansible.builtin.stat:
        path: /srv/app/.provisioned
      register: sentinel

Completa il **TODO 3**: il task di primo avvio deve girare *solo* se la sentinella non c'è
ancora:

    - name: First-time provisioning
      ansible.builtin.copy:
        content: "first run\n"
        dest: /srv/app/firstrun.txt
      when: not sentinel.stat.exists

Alla prima esecuzione la sentinella manca → il task gira. Poi un ultimo task scrive
/srv/app/.provisioned; alla riesecuzione la sentinella c'è → il task di primo avvio
**salta**. Hai reso idempotente "a mano" un'azione che va fatta una volta sola — Domanda c.

### Fase 5 — Condizioni composte e is defined (TODO 2)

Una condizione può combinare più test. Il modo più leggibile è una **lista sotto when**,
che significa **AND** (tutte vere). Completa il **TODO 2**: abilita le metriche solo in prod
*e* solo se richieste:

    - name: Enable metrics (prod AND enabled)
      ansible.builtin.file:
        path: /srv/app/metrics.enabled
        state: touch
      when:
        - app_env == 'prod'
        - enable_metrics | bool

Servono *entrambe*: con -e app_env=prod ma enable_metrics falso, il task salta. Puoi
scrivere anche and/or in linea (when: a and b), ma la lista AND è più leggibile. E per le
variabili che *potrebbero non esistere* (15.6), il test è **is defined**: il task del tuning
gira solo se glielo passi:

    when: tuning_profile is defined

Senza -e tuning_profile=..., salta — senza esplodere per "variabile non definita".

### Fase 6 — Le graffe, una volta per tutte

La regola che chiude ogni dubbio:

- **Con** le graffe {{ }}: quando *inserisci* un valore — negli argomenti dei moduli, nei
  template, nelle stringhe.
- **Senza** le graffe: quando scrivi un'*espressione* che Ansible valuta già come Jinja —
  **when**, changed_when, failed_when, until, assert.
- L'unica eccezione: quando un intero valore *è* una variabile (var: "{{ x }}").

## Criteri di "fatto"

- **loop**: gli utenti websvc (/bin/bash) e batchsvc (/usr/sbin/nologin) sono creati; le
  cartelle logs, cache, run esistono.
- **dev** (default): PRODUCTION, metrics.enabled e tuning.conf **non** esistono (tre skip);
  firstrun.txt sì.
- **Riesecuzione**: il task di primo avvio **salta** (sentinella).
- **-e app_env=prod -e enable_metrics=true -e tuning_profile=fast**: i tre file compaiono.
- **-e app_env=prod** da solo: metrics.enabled **non** compare (l'AND vuole entrambe).

## Domande di riflessione

**a.** Negli argomenti di un modulo scrivi "{{ app_env }}", ma in when scrivi app_env ==
'prod' senza graffe. Perché questa differenza, cosa succede (e cosa vedi) se metti le graffe
in when, e qual è l'unica eccezione alla regola?

**b.** Il loop sugli utenti gira su una *lista di dizionari* (item.name, item.shell), non su
una lista semplice. Perché è più potente che fare due loop separati (uno per i nomi, uno per
le shell), e a cosa serve loop_control: label?

**c.** La sentinella (register + when: not sentinel.stat.exists) rende idempotente "a mano"
il primo avvio. Ma il modulo user e il modulo file sono *già* idempotenti da soli (cap. 5 e
10). Quando devi costruire l'idempotenza con register + when, e quando è meglio — e più
sicuro — lasciarla fare al modulo?

## Pulizia

    bash start/nodes.sh down

## Dove porta

Il tuo playbook ora decide e ripete: è diventato lungo e capace. Il capitolo 16 gli dà una
casa: i **ruoli** — la struttura che impacchetta task, variabili, file e handler in un
componente riusabile, così il playbook torna minuscolo e la logica vive in un posto
ordinato.
