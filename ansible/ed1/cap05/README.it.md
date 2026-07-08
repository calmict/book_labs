# Capitolo 5 — L'interruttore e il campanello

**Livello:** Fondamentale

Al capitolo 1 hai visto la differenza tra "rilanciabile" e "convergente". Ora la
portiamo al cuore: l'**idempotenza**. Un interruttore della luce è idempotente — lo
porti su ON; se è già ON, non succede nulla, e la stanza è comunque illuminata. Un
campanello no: ogni pressione suona di nuovo. Ansible è fatto di **interruttori**:
gli dici lo *stato* voluto, lui agisce solo se serve, e ti dice di che **colore** è
stato il cambiamento. Prima di installarlo (capitolo 6), lo costruisci in piccolo
con le tue mani: un mini-motore idempotente in bash che riporta i colori e sa fare
la "prova a vuoto".

## Obiettivi

- L'**idempotenza** senza paura: applicare due volte = applicare una volta.
- **Interruttore vs campanello**; **dichiarativo vs imperativo**.
- I **colori** del cambiamento: ok (verde, niente da fare), changed (giallo, ho
  agito), failed (rosso).
- I **cigni neri**: operazioni non idempotenti per natura, e come giudicarle
  (changed_when).
- La **prova generale**: check mode (dry-run) e diff.

## Prerequisiti

- bash. Nient'altro — e per l'ultima volta **niente Ansible**: è il capitolo che
  chiude il "prima". Dal 6 lo installi.

## Lo scenario

Un piccolo motore che porta un pezzo di sistema allo **stato voluto** e ti dice, per
ogni operazione, di che colore è stata: verde se era già a posto, giallo se ha
dovuto agire.

## Consegna passo-passo

### Fase 1 — I colori, due volte

Il motore porta il sistema a uno stato (una riga in un file di configurazione).
Lancialo su uno stato vuoto e poi di nuovo:

    bash solution/ensure.sh /tmp/cap05-state
    bash solution/ensure.sh /tmp/cap05-state

Primo giro: tutto [changed] (giallo) — ha agito. Secondo giro: [ok] (verde) — niente
da fare. **Questa è l'idempotenza**: la seconda volta non fa nulla, e lo *dice*.
Un'automazione che sa dire "ok, era già così" è un'automazione che puoi rilanciare
mille volte senza paura.

### Fase 2 — TODO 1: l'interruttore

In start/ensure.sh manca il cuore di ensure_line. Implementa la logica
dell'interruttore: **se la riga c'è già → ok; altrimenti aggiungila → changed**.
Portare a ON due volte lascia ON:

    se la riga è già nel file:  report ok
    altrimenti:                 aggiungi la riga, report changed

### Fase 3 — Il campanello, per contrasto

Il motore ha anche append_line, che **aggiunge sempre**. Osserva la differenza
lanciandolo due volte: resta [changed] a ogni giro, il file cresce, non converge
mai. È un **campanello**: ogni pressione suona di nuovo. In una parola: append_line
dice *come* ("aggiungi"), ensure_line dice *cosa* ("assicurati che ci sia").
Imperativo contro dichiarativo.

### Fase 4 — TODO 2: la prova a vuoto (check mode)

Aggiungi a ensure_line il supporto a CHECK=1: in check mode deve riportare che
**cambierebbe** senza scrivere niente.

    bash solution/ensure.sh /tmp/cap05-fresh           # applica davvero
    CHECK=1 bash solution/ensure.sh /tmp/cap05-fresh2   # dice cosa FAREBBE, non tocca nulla

È il --check di Ansible: la prova generale a teatro vuoto. Vedi cosa cambierebbe
*prima* di cambiarlo.

### Fase 5 — TODO 3: il cigno nero e changed_when

Alcune operazioni girano **sempre** (rendere un template, lanciare un comando
shell): il loro "ha funzionato" (exit 0) non dice se qualcosa è davvero *cambiato*.
La funzione render esegue sempre la scrittura; completa la regola **changed_when**:
giudica "changed" confrontando il contenuto **prima** e **dopo**, non l'exit code.

    render esegue sempre la scrittura
    poi: se (prima == dopo)  report ok       # nulla è cambiato, anche se il comando è girato
         altrimenti          report changed

Così, con gli stessi input, il secondo giro è [ok] e non [changed]. Senza questa
regola, un cigno nero resterebbe eternamente giallo — un falso "changed" a ogni
esecuzione.

### Fase 6 — Il rosso, e failed_when

Il terzo colore è **failed** (rosso). Ma anche "fallito" a volte mente: grep esce
con 1 quando *non trova* — non è un errore, è una risposta. In Ansible, failed_when
ti fa ridefinire cosa conta come fallimento, esattamente come changed_when
ridefinisce cosa conta come cambiamento. La morale del capitolo: **l'exit code è un
indizio, non la verità** — sei tu (o il modulo ben scritto) a decidere il colore.

## Criteri di "fatto"

- ensure.sh completato: **1° giro tutto [changed], 2° giro [ok]** (idempotenza).
- Il campanello append_line resta [changed] a ogni giro (non converge).
- In **check mode** ensure_line dice [changed] WOULD ma **non scrive**.
- render con changed_when riporta [ok] al 2° giro con gli stessi input.

## Domande di riflessione

**a.** Definisci l'idempotenza con parole tue e spiega perché è ciò che rende
un'automazione **sicura da rilanciare** (collega al capitolo 1: ripetibile vs
convergente).

**b.** Perché un comando shell è un "**cigno nero**" per un motore idempotente, e
cosa gli dai con changed_when perché smetta di mentire sul colore?

**c.** Il check mode ha un limite: se il task B dipende dall'*effetto* del task A (A
crea qualcosa che B userà), in dry-run cosa **non** puoi prevedere del risultato di
B?

## Pulizia

    rm -rf /tmp/cap05-state /tmp/cap05-fresh /tmp/cap05-fresh2

## Dove porta

Al capitolo 6 installi Ansible e scopri che ogni **modulo** è già un interruttore:
riporta i colori, supporta --check, e ti dà changed_when/failed_when per i cigni
neri. Hai costruito a mano il motore; da qui in poi usi quello vero — e sai
esattamente cosa fa sotto.
