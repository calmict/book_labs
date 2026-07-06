# Capitolo 7 — Il registro delle versioni

**Livello:** Fondamentale
**Tempo stimato:** 40–50 minuti
**Argomenti del manuale:** a cosa serve il blocco terraform (7.1), required_version: pinnare il binario (7.2), il versionamento semantico e i suoi operatori (7.3), required_providers: dichiarare i traduttori (7.4), il file di blocco .terraform.lock.hcl (7.5), tirando le fila (7.6)

## L'idea

Un cantiere serio ha un capitolato: quali norme si applicano, quali
fornitori sono ammessi, e un registro di *esattamente* quali materiali sono
stati scelti. Nel progetto, il capitolato è il blocco terraform — e in
questo esercizio lo metti alla prova rompendolo e riparandolo: un
required_version impossibile ti chiude il cancello in faccia (ed è un bene:
scoprirai da che cosa protegge), un pin esatto ti mostra la nascita del
lock file, e poi il gioco si fa sottile — allarghi il vincolo con
l'operatore ~> e scopri che *non cambia niente*, finché non sei tu a
chiederlo con init -upgrade.

È la divisione dei poteri che regge il lavoro in squadra: il *vincolo* nel
codice è il recinto (che cosa sarebbe accettabile), il *lock* è la scelta
(che cosa usiamo davvero, tutti, oggi). Chiude l'esercizio il collega di
luglio: cancella il registro, rilancia init, e ottiene un traduttore
diverso dal tuo — stesso codice, mesi dopo, provider diverso. È il drift
dei capitoli 1 e 2, risalito dal mondo dei server al mondo degli attrezzi.

## Obiettivi

Alla fine saprai:

- spiegare a che cosa serve il blocco terraform e da che cosa protegge
  required_version;
- leggere e scegliere gli operatori semver, e dire che cosa promette (e
  che cosa vieta) ~> 3.5;
- raccontare la divisione dei poteri: vincolo = recinto, lock = scelta;
- usare init -upgrade come gesto deliberato, e leggere l'errore di
  conflitto tra vincolo e lock;
- dire perché in un progetto vero il lock file va committato (e perché in
  questo repo di esercizi, eccezionalmente, è gitignorato).

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md. Provider random
  (piccolo: gli init ripetuti costano pochi secondi).
- Il capitolo 6: sai già che cosa fa init e dove vivono i provider.

## Consegna

### Fase 0 — Il cancello chiuso

Apri start/main.tf: stavolta è completo, ma il capitolato è rotto per
costruzione — required_version chiede un binario che non esiste più.
Prova:

    cd start
    tofu init

Errore: Unsupported OpenTofu Core version. Il cancello ha funzionato.
Fermati a pensare da che cosa ti ha appena protetto: non da te — dal
collega col binario vecchio di due anni, che senza questo controllo
applicherebbe il tuo codice con un motore che non lo capisce, fallendo a
metà o (peggio) riuscendo in modo diverso. Il TODO 1 ti chiede di aprire
il cancello a chiunque abbia un binario moderno:

    required_version = ">= 1.6.0"

(Vale per entrambi i binari: OpenTofu è nato dalla 1.6.)

### Fase 1 — Il pin esatto e la nascita del registro

Il provider random è pinnato alla versione esatta 3.5.1. Ora che il
cancello è aperto:

    tofu init
    cat .terraform.lock.hcl
    tofu apply

Nel lock file appena nato leggi tre cose: la versione scelta (3.5.1), il
vincolo che l'ha permessa, e una lista di hash — le impronte digitali del
pacchetto: ai prossimi init, un download che non corrisponde viene
rifiutato (integrità della filiera, non solo riproducibilità). L'apply ti
regala la mascotte del cantiere: un random_pet, vecchia conoscenza del
capitolo 1.

### Fase 2 — Il recinto si allarga, la scelta resta

Il TODO 2 ti chiede di sostituire il pin esatto con l'operatore
pessimistico:

    version = "~> 3.5"

Significa: >= 3.5.0 e < 4.0.0 — accetto patch e minor (correzioni,
aggiunte compatibili), rifiuto il major (dove semver autorizza le
rotture). Ora rilancia:

    tofu init

Leggi bene: Reusing previous version of hashicorp/random from the
dependency lock file. Hai allargato il recinto fino a 3.9.x, e non è
cambiato *niente*: la 3.5.1 resta. È il momento più importante del
capitolo: il vincolo dice che cosa sarebbe accettabile, il lock dice che
cosa si usa — e nessun init ordinario cambia la scelta alle tue spalle.

### Fase 3 — Il gesto deliberato

Aggiornare si può: ma è un gesto, non un caso.

    cp .terraform.lock.hcl lock.before
    tofu init -upgrade
    diff lock.before .terraform.lock.hcl

Ora sei sull'ultima 3.x, e il diff del lock mostra la nuova versione e i
nuovi hash. In squadra, questo diff finirebbe nel commit: "aggiornato il
provider random", revisionabile come ogni altra modifica.

### Fase 4 — Il conflitto (e l'errore che ti guida)

Torna al pin esatto di prima, senza toccare il lock:

    version = "3.5.1"

e rilancia init. L'errore è di quelli fatti bene: locked provider ...
does not match configured version constraint ... must use tofu init
-upgrade. Vincolo e registro si contraddicono, e lo strumento *si rifiuta
di scegliere da solo*: niente downgrade silenzioso, niente upgrade
silenzioso — ti dice qual è il conflitto e qual è il gesto per risolverlo.
Rimetti ~> 3.5 e prosegui.

### Fase 5 — Il collega di luglio

A gennaio il tuo lock diceva 3.5.1. A luglio un collega clona il progetto
— ma il lock non c'è (qualcuno non l'ha committato). Simulalo:

    rm .terraform.lock.hcl
    rm -rf .terraform
    tofu init

Installing hashicorp/random v3.9.x: l'ultima che il recinto consente.
Stesso codice, data diversa, traduttore diverso — il drift è tornato, e
stavolta non sui server: sugli attrezzi. Il rimedio è uno solo: *il lock
file si committa*, e chiunque cloni ottiene la stessa identica scelta.

Nota di onestà: in *questo* repo di esercizi il lock è gitignorato — serve
a lasciarti fare esattamente le prove che hai appena fatto. È l'eccezione
che conferma la regola: in un progetto vero, il registro va in git.

### Pulizia

    tofu destroy

## Criteri di "fatto"

- L'init della Fase 0 è fallito con Unsupported OpenTofu Core version, e
  dopo il TODO 1 è passato.
- Nel lock file hai individuato versione, vincolo e hash.
- Dopo il TODO 2 (~> 3.5), init ha risposto Reusing previous version ...
  from the dependency lock file, restando su 3.5.1.
- Dopo init -upgrade il diff del lock mostra la versione nuova.
- Il conflitto della Fase 4 ha prodotto l'errore con l'indicazione must
  use tofu init -upgrade.
- Senza lock (Fase 5), init ha installato direttamente l'ultima 3.x.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Il cancello: da quale scenario di squadra ti protegge
required_version, e perché scatta a init e non ad apply? E perché il
vincolo sul core e i vincoli sui provider sono due cose separate (che cosa
pinna l'uno, che cosa pinnano gli altri)?

**b.** La divisione dei poteri: nelle Fasi 2–4, chi ha cambiato che cosa?
Spiega vincolo-recinto e lock-scelta con gli eventi che hai visto: perché
allargare il recinto non ha mosso nulla, perché -upgrade sì, e perché nel
conflitto lo strumento ha preferito fermarsi con un errore piuttosto che
decidere da solo. Che cosa promette esattamente ~> 3.5, e perché il major
resta fuori dal recinto?

**c.** Il collega di luglio: che cosa gli è successo, e quale singola
azione l'avrebbe evitato? Che cosa aggiungono gli hash alla semplice
riproducibilità? E sapresti spiegare perché questo repo di esercizi
gitignora il lock mentre il tuo prossimo progetto vero dovrà committarlo?
