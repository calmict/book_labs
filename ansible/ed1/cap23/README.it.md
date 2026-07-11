# Capitolo 23 — La prova generale

**Livello:** Avanzato

Il capitolo 22 ti ha insegnato a *reagire* agli errori. Ma il modo migliore di gestire un errore
è non commetterlo — o almeno scoprirlo *prima* di toccare la produzione. Prima di un concerto
nessuna orchestra sale sul palco alla cieca: rilegge le parti (c'è un errore di stampa?), fa la
prova generale a teatro vuoto (suona tutto, senza pubblico), e solo allora apre le porte. Ansible
ti dà la stessa rete di sicurezza, a tre livelli sempre più ricchi: --syntax-check (la lettura
veloce), ansible-lint (il revisore esperto), e il **check mode** con --diff (la prova generale
che ti mostra cosa cambierebbe senza cambiarlo). Meglio un errore rosso sul tuo terminale che un
guasto silenzioso su mille nodi.

## Obiettivi

- **Tre livelli di rete**, dal più economico al più ricco (23.1).
- Il primo gradino: **--syntax-check** (23.2).
- **ansible-lint**: la saggezza della community in un comando — profili, falsi positivi (23.3).
- Il **check mode**: la prova generale a teatro vuoto, con --diff (23.4).
- I **limiti** del check mode, e come aggirarli (23.5).
- Mettere tutto in fila: il **flusso di validazione** (23.6).
- Le **buone abitudini** con la validazione (23.7).

## Prerequisiti

- Il venv del capitolo 6, più **ansible-lint** (in start/requirements.txt).
- Un playbook che "funziona ma è sciatto": lo ripulisci facendolo passare per i tre livelli.
- (Nessun nodo: tutto sul control node — connection: local — il check mode e il lint lavorano
  dove sta Ansible.)

## Lo scenario

start/site.yml è un playbook che *gira*, ma è pieno di piccole trascuratezze: play e task senza
nome, moduli chiamati col nome breve, un mode ottale scritto male, comandi che non dichiarano se
cambiano qualcosa. Lo fai passare per la rete a tre livelli e sistemi ciò che ogni livello
segnala — finché è pulito, prevedibile, e sicuro da mandare in scena.

Prepara l'ambiente:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Fase 1 — Tre livelli di rete (23.1)

Tre reti, dalla più economica alla più ricca:

1. **--syntax-check**: legge il playbook e verifica che sia *strutturalmente* valido. Istantaneo,
   non tocca niente. Prende gli errori di battitura, non quelli di giudizio.
2. **ansible-lint**: applica centinaia di regole di stile e best-practice della community. Non
   esegue nulla, ma sa *tantissimo*.
3. **check mode (--check --diff)**: la prova generale — Ansible *simula* l'esecuzione e ti dice
   cosa cambierebbe, senza cambiarlo.

Più sali, più la rete costa e più cattura. Si usano *in quest'ordine*: fermati al primo che
fallisce. Domanda a.

### Fase 2 — Il primo gradino: --syntax-check (23.2)

    ansible-playbook --syntax-check -i localhost, site.yml

Legge la struttura senza connettersi a nessun nodo: parentesi, indentazione, chiavi note. È la
lettura veloce prima delle prove — gratis, e prende gli errori grossolani in un istante.

### Fase 3 — ansible-lint: il revisore esperto (23.3 — TODO 1 e TODO 3)

    ansible-lint site.yml

Sul playbook sciatto piovono i cartellini rossi: name[play] (il play non ha nome), name[missing]
(task senza nome), fqcn (usa ansible.builtin.copy, non copy), risky-octal (mode: 644 è ambiguo →
"0644"), no-changed-when (un comando deve dire se cambia qualcosa). Completa il **TODO 1**:
sistema il playbook finché ansible-lint passa.

**I profili** (23.3) sono la manopola della severità: min, basic, safety, moderate, shared,
production — dal "solo l'essenziale" al "pronto per la produzione". Completa il **TODO 3**: crea
un file .ansible-lint che fissa il profilo del progetto —

    profile: production

Così chiunque lanci ansible-lint (anche la CI) applica *lo stesso* livello.

**I falsi positivi** capitano: a volte una regola sbaglia sul tuo caso. Non si zittisce tutto — si
mette a tacere *quella riga, con motivazione*: # noqa: <regola> in coda al task, o skip_list nel
.ansible-lint. Silenziare per pigrizia è peggio del problema.

### Fase 4 — Il check mode: la prova generale (23.4 — --diff)

    ansible-playbook -i localhost, --check --diff site.yml

Con **--check** Ansible fa la prova a teatro vuoto: valuta ogni task, dice se sarebbe changed, ma
*non scrive niente*. Con **--diff** ti mostra le righe esatte che cambierebbero:

    --- before
    +++ after
    @@ -0,0 +1,2 @@
    +mode = production
    +workers = 4

changed: [localhost] — eppure il file non esiste ancora sul disco. È la differenza tra sapere
cosa farà un playbook e scoprirlo *dopo*. Domanda b.

### Fase 5 — I limiti del check mode, e check_mode: false (23.5 — TODO 2)

La prova generale ha un limite: alcune cose non si possono *simulare*. Un comando (command/shell)
in check mode viene **saltato** — Ansible non sa cosa farebbe, quindi non lo esegue. Ma se quel
comando serve solo a *leggere* uno stato (e il suo risultato guida i task dopo), saltarlo rende la
prova bugiarda: la variabile register resta vuota, e i task che dipendono da lei si comportano
male.

Il rimedio è dire "questo task è sicuro, eseguilo anche in prova": completa il **TODO 2** sul task
di lettura —

    - name: Read the current config (read-only, safe in check mode)
      ansible.builtin.command: cat {{ conf }}
      register: current
      changed_when: false
      check_mode: false

check_mode: false lo fa girare *sempre*: legge davvero (non cambia niente), così il check mode a
valle è accurato. Altri limiti restano — un task che dipende dall'effetto *reale* di uno
precedente (che in check non è avvenuto) può ingannare: il check mode è una prova, non la realtà.

### Fase 6 — Il flusso di validazione (23.6)

Messi in fila, i tre livelli sono un imbuto:

    ansible-playbook --syntax-check -i localhost, site.yml   # 1. struttura (istantaneo)
    ansible-lint site.yml                                     # 2. stile e best-practice
    ansible-playbook -i localhost, --check --diff site.yml    # 3. cosa cambierebbe
    ansible-playbook -i localhost, site.yml                   # 4. ...e solo ora, per davvero

In CI è la stessa scala: i primi tre girano a ogni push (non toccano niente), il quarto solo dopo
l'approvazione. È il "gate di produzione" del capitolo 26.

### Fase 7 — Le buone abitudini (23.7)

- **Dal basso verso l'alto**: syntax-check prima (gratis), lint poi, check per ultimo. Non
  arrivare al costoso se il gratuito già ti ferma.
- **Un profilo dichiarato** (.ansible-lint): la severità è una decisione di progetto, non un
  capriccio di chi lancia il comando.
- **Falsi positivi con motivazione**: # noqa mirato, mai un skip globale a tappeto.
- **Il check mode è una prova, non una garanzia**: usa check_mode: false per i task di lettura, e
  ricorda che ciò che dipende da effetti reali può mentire in prova.

## Criteri di "fatto"

- --syntax-check passa su site.yml.
- ansible-lint passa su site.yml (TODO 1) al profilo production dichiarato in .ansible-lint
  (TODO 3); e *fallisce* sul playbook sciatto di partenza.
- Il task di lettura ha check_mode: false (TODO 2): gira anche in --check.
- --check --diff mostra la diff di conf.txt ma *non* scrive il file; l'esecuzione reale lo scrive;
  rieseguendo → changed=0.

## Domande di riflessione

**a.** I tre livelli (syntax-check, lint, check mode) costano e catturano in modo crescente.
Perché ha senso usarli *in quest'ordine* e fermarsi al primo che fallisce, invece di lanciare
subito il più ricco? Cosa prende ciascuno che il precedente non può prendere?

**b.** Il check mode dice "changed" ma non scrive niente. In che senso è più di un semplice "dry
run che stampa i comandi"? Cosa ti dà --diff che il solo esito changed/ok non ti darebbe, e perché
"vedere le righe che cambierebbero" cambia il modo in cui rivedi un playbook?

**c.** ansible-lint incorpora "la saggezza della community" in regole. Ma a volte una regola è un
falso positivo sul tuo caso. Perché la risposta giusta è un # noqa *mirato e motivato* e non
disattivare la regola per tutto il progetto? Che cosa perdi il giorno in cui zittisci una regola a
tappeto per far tacere un solo task?

## Pulizia

Niente da smontare: nessun nodo. Il conf.txt reso finisce in /tmp/cap23-lab (o dove punti
CAP23_LAB); cancellalo se vuoi.

## Dove porta

Sai *rileggere* e *provare* un playbook prima di eseguirlo. Ma un lint pulito e una prova a teatro
vuoto non provano che il ruolo *funzioni* davvero su un sistema vero, ripetutamente, da zero. Il
**capitolo 24** apre **Molecule**: la prova con vero pubblico e vera scena — crea un ambiente
usa-e-getta, applica il ruolo, verifica l'idempotenza e il risultato, e smonta tutto. Dal
rileggere le parti, al collaudo completo.
