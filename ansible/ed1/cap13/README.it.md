# Capitolo 13 — La catena di comando

**Livello:** Intermedio

Al capitolo 12 hai visto la riga di comando battere il group_vars, quasi senza pensarci.
Non era magia: era **precedenza**. Ansible ti lascia definire una variabile in *tanti*
posti — comodità enorme — ma il prezzo è che, quando due posti dichiarano lo stesso nome
con valori diversi, qualcuno deve vincere. Ansible ha una **catena di comando** rigida:
**22 livelli**, dal più debole (i default di ruolo) al più forte (-e). Questo capitolo
non ti fa costruire infrastruttura: ti fa *indagare*. Provochi scontri reali fra
variabili, guardi chi vince, impari i tre principi che spiegano quasi tutto, i due
trabocchetti che sorprendono tutti, e come progettare per non litigare mai.

## Obiettivi

- **Perché** esistono così tanti livelli (13.1).
- I **tre principi** che spiegano quasi tutto (13.2).
- La **lista completa**, dal più debole al più forte (13.3).
- **Scontri reali**: vederla in azione (13.4).
- Gli **strumenti** per non perdersi (13.5).
- I **due trabocchetti**: i dizionari che non si fondono, i fatti (13.6).
- **Progettare** per non combattere (13.7).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- Le variabili del capitolo 12: group_vars, host_vars, -e, set_fact.
- (Nessun nodo da accendere: la precedenza si risolve sul **control node**, prima che
  qualcosa tocchi una macchina. I due host del lab sono locali.)

## Lo scenario

Due host, web1 e web2, con connessione **local** — non serve SSH: stiamo studiando *come
Ansible sceglie un valore*, e quella scelta avviene tutta a casa, sul control node.
Definirai lo stesso nome di variabile in più punti e userai il modulo debug per stampare
**chi ha vinto**.

## Consegna passo-passo

### Fase 1 — Perché 22 livelli

Il capitolo 12 ti ha dato la libertà di mettere una variabile nel gruppo, nell'host, nel
play, sulla riga di comando, nei fatti… Ogni posto esiste per una buona ragione: un
valore di squadra sta nel group_vars, un'eccezione di un host nel suo host_vars, un
override di una sera in -e. Ma "tanti posti" significa "tanti modi di dire la stessa cosa
in disaccordo". Ansible non tira a indovinare: ordina *ogni* possibile sorgente in una
scala fissa, e quando due si contraddicono, vince quella più in alto. I posti sono 22,
quindi i livelli sono 22.

### Fase 2 — I tre principi che spiegano quasi tutto

Non serve memorizzare 22 righe. Tre principi ti portano al 90%:

1. **Gli estremi sono assoluti.** -e (extra vars) vince su *tutto*; i default di ruolo
   (role defaults) perdono contro *tutto*. Nessuna eccezione, mai.
2. **In mezzo, più sei specifico più sei forte** (di norma). host batte group; un gruppo
   più specifico batte uno più generico; una variabile di play, ruolo o task batte quella
   d'inventario. Ottima intuizione — ma *non* è una legge senza eccezioni (Fase 6).
3. **A parità di livello, l'ultimo definito vince.** E per i gruppi che si sovrappongono,
   l'ordine (priorità del gruppo o, in mancanza, alfabetico) decide chi ha l'ultima parola.

### Fase 3 — La lista completa, dal più debole al più forte

Quando l'intuizione non basta, questa è la verità (ansible-core 2.15), dal più debole (1)
al più forte (22):

    1  command line -u/... (connessione, non variabili)
    2  role defaults
    3  inventory: group vars nel file
    4  inventory group_vars/all
    5  playbook group_vars/all
    6  inventory group_vars/<gruppo>
    7  playbook group_vars/<gruppo>
    8  inventory: host vars nel file
    9  inventory host_vars/<host>
    10 playbook host_vars/<host>
    11 fatti / set_facts in cache
    12 play vars
    13 play vars_prompt
    14 play vars_files
    15 role vars (role/vars/main.yml)
    16 block vars
    17 task vars
    18 include_vars
    19 set_fact / variabili registrate
    20 parametri di role / include_role
    21 parametri di include
    22 extra vars (-e)  <-- vince sempre

### Fase 4 — Scontri reali (TODO 1)

Apri start/host_vars/web2.yml e completa il **TODO 1**: dai a web2 le sue variabili in
conflitto (winner, bad_limits, limits_override). Poi esegui e leggi il primo scontro, la
**scala di specificità**:

    ansible-playbook -i start/inventory.ini start/site.yml

    web1: winner = group_vars(web)     # web1 prende il valore di gruppo (livello 6)
    web2: winner = host_vars(web2)     # web2, più specifico, vince (livello 9)

Ora la clava del livello 22:

    ansible-playbook -i start/inventory.ini start/site.yml -e winner=EXTRA

    web1: winner = EXTRA
    web2: winner = EXTRA               # -e batte perfino l'host var

Hai visto il principio 1 e il principio 2 dal vivo: host batte group, -e batte tutto.

### Fase 5 — Gli strumenti per non perdersi

Quando "perché vince quel valore?" ti fa impazzire, due strumenti:

- **ansible-inventory --host web2**: ti mostra le variabili che l'*inventario* attribuisce
  a web2 (group_vars + host_vars fusi), senza eseguire nulla.

      ansible-inventory -i start/inventory.ini --host web2

- **debug** dove la usi: {{ }} risolto al momento giusto è la verità finale. Stampare la
  variabile *nel punto* in cui la usi batte ogni ragionamento astratto.

E ricorda: -vvv sul playbook mostra da dove arriva ciascun valore.

### Fase 6 — I due trabocchetti (TODO 2, TODO 3)

**Trabocchetto 1 — i dizionari non si fondono.** In group_vars, bad_limits ha due chiavi;
in host_vars, web2 ne ridefinisce *una sola*. Cosa succede a web2?

    web1: bad_limits keys = ['max_connections', 'timeout_seconds']
    web2: bad_limits keys = ['max_connections']     # timeout_seconds SPARITO

Il livello più alto **sostituisce l'intero dizionario**, non lo fonde: la chiave che non
hai ripetuto è persa. È il bug silenzioso più comune con le variabili strutturate. La cura
è **combine**. Completa il **TODO 2** nel playbook — invece di sovrascrivere bad_limits,
tieni l'override in una variabile a parte (limits_override) e fondila esplicitamente:

    merged = {{ limits | combine(limits_override | default({})) }}

    web1: merged = {'max_connections': 200, 'timeout_seconds': 30}
    web2: merged = {'max_connections': 500, 'timeout_seconds': 30}   # timeout salvo

**Trabocchetto 2 — i fatti tirano da due parti opposte.** I fatti *raccolti* (Gathering
Facts) stanno al livello 11: **deboli**, una qualsiasi play var con lo stesso nome li batte
in silenzio. Ma i **set_fact** stanno al livello 19: **fortissimi**. Completa il **TODO
3**: fissa mode con set_fact e prova a "abbassarlo" con un task var (livello 17):

    web2: mode = set_fact_value     # il task var è ignorato: 19 batte 17

Stesso meccanismo apparente ("un fatto"), estremi opposti della scala: è qui che il
principio "più specifico vince" ti tradisce, e devi tornare alla lista.

### Fase 7 — Progettare per non combattere

La precedenza migliore è quella che non devi mai risolvere:

- **Un solo posto per ogni valore.** Se un nome vive in un punto solo, non c'è scontro da
  vincere.
- **-e con parsimonia.** È il martello del livello 22: vince su tutto, quindi maschera
  qualsiasi altra impostazione. Ottimo per un override d'emergenza, pessimo come abitudine.
- **Nomi distinti** per cose distinte: metà degli scontri nascono da due variabili diverse
  che, per sbaglio, si chiamano uguale.
- **combine per i dizionari** che vuoi davvero fondere; mai fidarti della fusione
  automatica (non esiste, se non con hash_behaviour=merge, sconsigliata).
- **Non appoggiarti ai trucchi di livello**: "tanto il mio task var vincerà" è una
  scommessa che il set_fact di un collega ti farà perdere.

## Criteri di "fatto"

- **winner**: web1 = group_vars(web), web2 = host_vars(web2); con **-e** → EXTRA su
  entrambi.
- **bad_limits**: web1 ha 2 chiavi, web2 ne ha 1 (il dizionario è stato sostituito, non
  fuso).
- **combine**: il merge dà a web2 {max_connections: 500, timeout_seconds: 30} (timeout
  salvo).
- **set_fact**: mode resta set_fact_value anche con un task var (19 batte 17).

## Domande di riflessione

**a.** I tre principi portano lontano, ma il set_fact (livello 19) batte il task var
(livello 17), rompendo "il più specifico vince". Perché in ultima analisi comanda la
*lista*, non l'intuizione? Racconta un caso in cui fidarsi solo dell'intuizione ti farebbe
sbagliare la diagnosi.

**b.** Ansible **sostituisce** i dizionari invece di fonderli. Perché questo comportamento
è più prevedibile della fusione automatica (che pure esiste come hash_behaviour=merge,
sconsigliata)? Elenca le vie per fondere *davvero* due dizionari e di' quale preferisci.

**c.** -e vince sul livello 22, sopra ogni altra cosa. Perché usarlo con parsimonia, e non
come scorciatoia quotidiana? E qual è l'unica regola di progetto che, da sola, elimina la
maggior parte delle domande "perché vince *quel* valore?".

## Pulizia

Niente da smontare: questo capitolo non accende nodi.

## Dove porta

Sai chi vince quando le variabili litigano — e come non farle litigare. Il capitolo 14
cambia argomento e torna all'azione: **task, handler e notifiche**. Lì il colore *changed*
del capitolo 5 diventa un segnale che *scatena* qualcosa — un servizio che si riavvia solo
se la sua configurazione è davvero cambiata — con notify e listen.
