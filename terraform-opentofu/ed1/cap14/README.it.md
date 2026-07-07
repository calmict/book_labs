# Capitolo 14 — Le tre porte

**Livello:** Intermedio
**Tempo stimato:** 45–55 minuti
**Argomenti del manuale:** le variabili di input (14.1), la validazione degli input (14.2), gli output (14.3), i locals: la cucina interna (14.4), le tre porte insieme (14.5)

## L'idea

Finora hai scritto configurazioni con i valori *cablati* dentro: il nome del
container, la porta, tutto fisso nel file. Funziona per un palazzo solo. Ma lo
stesso progetto deve servire dev, staging e prod — e riscrivere il file per
ognuno è la fotocopia che il capitolo 1 ci ha insegnato a temere.

Questo capitolo installa **tre porte** nella configurazione. La porta
d'ingresso — le *variabili* — lascia entrare i valori dall'esterno: chi usa il
modulo decide environment e external_port senza toccare il codice. La porta di
servizio — gli *output* — mostra all'esterno solo ciò che promette: qui, l'URL
dove risponde il servizio. E la cucina interna — i *locals* — non ha porta sul
mondo: è dove il nome del container si *deriva* una volta sola
(cap14-web-${var.environment}) e si riusa ovunque.

In mezzo c'è un buttafuori. Una variabile può pretendere un valore (nessun
default) e può rifiutare quello sbagliato: la validation blocca
environment = "banana" prima ancora del piano. E scoprirai che lo stesso valore
può entrare da tre porte diverse — riga di comando, variabile d'ambiente, file
tfvars — con una precedenza precisa quando litigano.

## Obiettivi

Alla fine saprai:

- dichiarare variabili di input con type, description e default, e distinguere
  una variabile *obbligatoria* (senza default) da una opzionale;
- mettere un buttafuori sull'input con un blocco validation (condizione +
  messaggio d'errore);
- passare un valore da tre sorgenti — -var, TF_VAR_, terraform.tfvars — e
  prevedere quale vince quando confliggono;
- derivare valori interni con locals e spiegare perché non sono variabili;
- esporre un risultato con output, e dire perché l'output è l'unica porta di
  servizio (il contratto del capitolo 13 nasce qui).

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Porta libera: 8095.
- Il capitolo 3 (in-place vs replace) e il capitolo 9 (argomenti e attributi):
  qui li rivedi all'opera.

## Consegna

### Fase 0 — La porta chiusa (una variabile che pretende)

In start/ trovi un main.tf con le tre porte da completare. La prima variabile,
environment, è dichiarata *senza default*: è obbligatoria. Provalo — chiedi il
piano senza dare nulla:

    cd start
    tofu init
    tofu plan

Ti blocca subito: *No value for required variable*. Nessun default significa
nessun valore di comodo: chi usa questa configurazione **deve** dichiarare
l'ambiente. È una scelta di progetto, non un difetto.

### Fase 1 — Il buttafuori (TODO 1: la validazione)

Il TODO 1 ti chiede di completare il blocco validation su environment: sono
ammessi solo dev, staging, prod. La variabile external_port, poco più sotto,
ha già la sua validazione completa: usala come modello. Completa la condizione:

    validation {
      condition     = contains(["dev", "staging", "prod"], var.environment)
      error_message = "The environment must be one of: dev, staging, prod."
    }

Poi prova a forzare la porta:

    tofu plan -var environment=banana

Il piano non parte nemmeno: *Invalid value for variable*, con il tuo messaggio.
La validazione è un buttafuori che controlla il biglietto **prima** che il
grafo del capitolo 4 si costruisca — l'errore sbagliato viene fermato sulla
soglia, non a metà apply.

### Fase 2 — Le tre porte d'ingresso, e chi vince

Lo stesso valore può entrare da tre sorgenti. Provale una a una.

Dalla riga di comando:

    tofu plan -var environment=dev

Dall'ambiente (stesso effetto, senza -var):

    TF_VAR_environment=staging tofu plan

Da file — copia l'esempio fornito e riempilo:

    cp terraform.tfvars.example terraform.tfvars
    # dentro: environment = "dev"
    tofu plan

Ora falle litigare. Con environment = "dev" dentro terraform.tfvars, lancia:

    tofu plan -var environment=prod

Vince prod: la **riga di comando batte il file**. E il file batte l'ambiente.
La precedenza (dalla più forte): -var sulla CLI, poi terraform.tfvars, poi
TF_VAR_. Regola pratica: più il valore è vicino al comando che stai lanciando,
più pesa.

Una nota che tornerà utile: .gitignore esclude i file tfvars. Per questo start/
ti dà un terraform.tfvars.example, non un tfvars vero. I tfvars sono il posto
dove finiscono i valori per-ambiente — spesso credenziali, chiavi, segreti — e
non vanno mai committati. Nel repo viaggia solo l'*esempio*, versione innocua
da copiare.

### Fase 3 — La cucina interna (TODO 2: i locals)

Il nome del container serve in più punti e deve dipendere dall'ambiente. Non è
un input (nessuno lo passa da fuori) e non è un output (nessuno lo legge da
fuori): è un valore *interno*, derivato. Il posto giusto è un local. Completa
il TODO 2:

    locals {
      container_name = "cap14-web-${var.environment}"
    }

e usalo nel container: name = local.container_name. Un local si calcola una
volta e si riusa: cambia environment, e il nome cambia dappertutto senza
toccare altro. Non è una variabile perché non entra dall'esterno — è la cucina,
non la porta.

### Fase 4 — La porta di servizio (TODO 3: l'output)

Il TODO 3 espone il risultato. Completa l'output:

    output "url" {
      description = "Where the service answers."
      value       = "http://localhost:${var.external_port} (${var.environment})"
    }

Applica per davvero con l'ambiente che vuoi:

    tofu apply -var environment=dev

A fine apply, tofu stampa url = "http://localhost:8095 (dev)". Aprilo:
*Welcome to nginx!*. L'output è l'unica cosa che il mondo esterno vede di
questa stanza — è esattamente la porta che nel capitolo 13 diventava il
*contratto* tra squadre (terraform_remote_state legge gli output, ricordi?).
Il contratto nasce qui.

### Fase 5 — L'eco del capitolo 3

Cambia solo la porta d'ingresso — l'ambiente — e chiedi il piano:

    tofu plan -var environment=prod

Il container **must be replaced**:
~ name = "cap14-web-dev" -> "cap14-web-prod" # forces replacement. Un valore
entrato da una porta ha attraversato il local, ha cambiato il nome, e il
capitolo 3 ha fatto il resto: name è un attributo che forza la sostituzione. Le
tre porte non sono decorazione — muovono il grafo.

### Pulizia

    tofu destroy -var environment=dev

## Criteri di "fatto"

- Il piano senza environment si fermava con *No value for required variable*.
- -var environment=banana veniva respinto dalla validation con il tuo messaggio.
- Avevi visto lo stesso valore entrare da -var, TF_VAR_ e terraform.tfvars, e
  previsto chi vince (-var, poi file, poi env).
- apply stampava url = "http://localhost:8095 (<env>)", e la pagina rispondeva.
- Cambiare environment produceva un replace del container (# forces
  replacement).
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Le tre porte: assegna environment, container_name e url alla porta
giusta (ingresso / servizio / cucina interna) e spiega in una frase perché
container_name non è né una variabile né un output.

**b.** La precedenza: hai environment = "dev" in terraform.tfvars,
TF_VAR_environment=staging nell'ambiente, e lanci
tofu apply -var environment=prod. Quale ambiente viene applicato, e qual è la
regola generale? Perché ha senso che la CLI vinca?

**c.** I tfvars e il segreto: perché .gitignore esclude i file tfvars e nel
repo viaggia solo il .example? Collega la risposta al capitolo 11 (che cosa
custodisce lo stato *in chiaro*) — quale filo comune lega i due?
