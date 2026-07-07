# Capitolo 22 — Il nastro trasportatore

**Livello:** Cloud Architect
**Tempo stimato:** 55–65 minuti
**Argomenti del manuale:** cosa significano CI e CD (22.1), il flusso: dal commit alla produzione (22.2), GitOps: il repository come unica verità (22.3), OIDC: la fine delle credenziali statiche (22.4), gli strumenti e un cenno ad Atlantis (22.5)

## L'idea

Per ventuno capitoli hai lanciato tu i comandi: plan, apply, test. Questo capitolo
— l'ultimo — li toglie dalle tue mani e li mette su un **nastro trasportatore**.
Da un lato entra un commit; dall'altro esce infrastruttura in produzione. E lungo
il nastro, in automatico, scatta la piramide del capitolo 21: forma, coerenza,
sicurezza, comportamento. Nessuno applica a mano; nessuno dimentica un controllo.

Il nastro ha due tratti. Il primo è la **CI** (Continuous Integration): a ogni
*proposta* di modifica — una pull request — il nastro esegue i controlli e produce
un *plan*, la diffusione di ciò che cambierebbe. È il cancello: se un controllo
fallisce, la porta resta chiusa, e nessuno discute con la macchina. Il secondo è
la **CD** (Continuous Delivery/Deployment): quando la modifica viene *approvata e
unita* al ramo principale, il nastro fa l'apply. Proporre e consegnare diventano
due gesti separati e automatici — plan sulla PR, apply sul merge.

Sotto tutto c'è un principio, **GitOps** (22.3): il repository è l'*unica verità*.
Non è la realtà a dettare che cosa c'è; è git. Se qualcuno tocca l'infrastruttura
a mano, il prossimo passaggio del nastro se ne accorge e la *riporta* a ciò che
dice il codice. Lo vedrai coi tuoi occhi.

E un'ultima cosa che il nastro non deve portare con sé: le chiavi. Le credenziali
statiche — una chiave cloud incollata nei segreti della CI — sono la vecchia
maledizione. **OIDC** (22.4) le abolisce: il nastro non custodisce una chiave
permanente, mostra un *badge* valido per una sola corsa.

## Obiettivi

Alla fine saprai:

- distinguere CI e CD, e mappare "plan sulla PR / apply sul merge" sui due tratti;
- leggere e completare una pipeline (GitHub Actions) che automatizza la piramide
  del capitolo 21;
- spiegare GitOps e *dimostrare* la correzione del drift: la realtà riportata a
  git;
- dire perché OIDC sostituisce le credenziali statiche, e riconoscerne la forma
  nella pipeline;
- collocare gli strumenti (le pipeline, un cenno ad Atlantis) nel quadro.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Porta libera: 8140.
- Tutta la Parte 6, ma soprattutto il capitolo 21 (la piramide): qui la si mette
  sul nastro.

## Consegna

### Fase 0 — I due tratti del nastro (22.1, 22.2)

In start/ trovi la configurazione da consegnare (un container) e
pipeline.yml.example: una pipeline GitHub Actions con due job. Leggila come un
nastro:

- il job plan gira su ogni pull_request: è il *cancello* — controlla e propone;
- il job deploy gira solo sul push a main: è la *consegna* — applica.

Non la eseguirai su GitHub (sta nella cartella dell'esercizio, non in
.github/workflows/): è un modello da leggere, completare e adattare al tuo repo.
Il collaudo vero lo farai in locale, simulando gli stessi passi.

### Fase 1 — Il cancello: la piramide sul nastro (TODO 1)

Il job plan deve eseguire, in automatico, i controlli che nel capitolo 21
lanciavi a mano. Il TODO 1 ti chiede di completarne i passi: dopo il checkout e
l'installazione di tofu, aggiungi i gradini della piramide —

    - run: tofu fmt -check -recursive
    - run: tofu init -input=false
    - run: tofu validate
    - run: tofu plan -input=false -no-color

Questi quattro passi sono cap21 messo su nastro: girano a *ogni* proposta, prima
che una riga tocchi la produzione.

### Fase 2 — La consegna, e solo al momento giusto (TODO 2)

Il job deploy fa l'apply — ma applicare è un gesto che va fatto *solo* quando la
modifica è approvata e unita, mai su una semplice proposta. Il TODO 2 ti chiede di
mettere la guardia: il job deve girare solo su un push al ramo main.

    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

Senza questa riga, una qualsiasi pull request applicherebbe in produzione:
proporre e consegnare tornerebbero un gesto solo. La guardia tiene separati il
cancello e la consegna.

### Fase 3 — Il nastro in locale: dal commit alla produzione

Ora simula il nastro sulla tua macchina, con gli stessi comandi della pipeline.
Prima il cancello (la PR):

    cd start
    tofu fmt -check && tofu init && tofu validate
    tofu plan -out tfplan

Se tutto passa, il cancello si apre. Poi la consegna (il merge):

    tofu apply tfplan
    curl -s localhost:8140 | grep -o '<title>.*</title>'

Hai appena percorso il nastro a mano: gli stessi identici passi che, in CI,
scattano da soli a ogni commit.

### Fase 4 — GitOps: chi ha ragione, git o la realtà? (22.3)

Ora la prova del principio. Qualcuno tocca l'infrastruttura a mano — cancella il
container di soppiatto:

    docker rm -f cap22-app

La realtà si è allontanata da git. Rilancia il nastro:

    tofu plan

Il piano non dice "va bene così": dice Plan: 1 to add. Il nastro *sa* che la
realtà ha derivato, e propone di riportarla al codice. Applica:

    tofu apply
    curl -s localhost:8140 | grep -o '<title>.*</title>'

Il container è tornato. Questo è GitOps: la modifica a mano non ha vinto — ha
vinto il repository. La realtà insegue git, non il contrario. Il capitolo 11 ci
aveva mostrato lo stato come *memoria*; GitOps fa un passo oltre: il codice
versionato è la *volontà*, e il nastro la impone di continuo.

### Fase 5 — Il badge, non la chiave: OIDC (22.4, si legge)

Guarda in pipeline.yml.example il job deploy e la riga permissions: id-token:
write, con l'esempio (commentato) di configure-aws-credentials che assume un
ruolo. È OIDC: invece di incollare una chiave cloud permanente nei segreti della
CI — che se trapela vale per sempre — il nastro chiede al cloud un *token a vita
brevissima*, valido per quella singola corsa, legato a quel repository e a quel
workflow. Nessuna chiave da custodire, nessuna chiave da revocare. È l'ultimo
pezzo del capitolo 20 sulla sicurezza dei segreti, portato nella pipeline: la
credenziale migliore è quella che non esiste a riposo.

### Fase 6 — La fine del viaggio (22.6)

Ventidue capitoli fa, un'infrastruttura era un insieme di clic irripetibili — il
fiocco di neve del capitolo 1. Ora è codice: descritto, versionato, validato,
testato, cifrato, e consegnato da un nastro che nessuno tocca a mano. Hai chiuso
il cerchio. Da qui in poi la città digitale la progetti tu — e il nastro la
costruisce.

### Pulizia

    tofu destroy
    docker rm -f cap22-app 2>/dev/null

## Criteri di "fatto"

- Hai completato, in pipeline.yml.example, i quattro passi del job plan (TODO 1) e
  la guardia del job deploy (TODO 2).
- In locale, la sequenza fmt/init/validate/plan passava, e apply consegnava il
  container su 8140.
- Cancellando il container a mano, tofu plan diceva 1 to add, e apply lo riportava
  (correzione del drift).
- Hai riconosciuto, nella pipeline, permissions: id-token e il ruolo assunto via
  OIDC (nessuna chiave statica).
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** CI e CD sul nastro: perché il plan sta sulla pull request e l'apply sul
merge, e non entrambi insieme? Che cosa protegge, in pratica, la separazione tra
il cancello (proporre) e la consegna (applicare) — e perché il capitolo 21 è il
contenuto naturale del primo tratto?

**b.** GitOps e il drift: nella Fase 4 hai cancellato il container a mano e il
nastro l'ha riportato. Spiega in che senso "il repository è l'unica verità": chi
vince tra una modifica manuale e il codice versionato, e perché è una proprietà
*desiderabile* e non una limitazione? Collega allo stato del capitolo 11 (memoria)
e al plan del capitolo 6 (codice contro realtà).

**c.** Il badge contro la chiave: perché una credenziale statica incollata nei
segreti della CI è pericolosa, e in che modo OIDC risolve il problema alla radice
(che cosa rende un token OIDC diverso da una chiave)? E, chiudendo il manuale: dei
ventidue capitoli, quale principio porteresti come primo comandamento nel tuo
prossimo progetto reale — e perché?
