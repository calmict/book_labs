# Capitolo 21 — La piramide dei collaudi

**Livello:** Cloud Architect
**Tempo stimato:** 50–60 minuti
**Argomenti del manuale:** la piramide della validazione (21.1), la base: fmt e validate (21.2), le scansioni di sicurezza: policy as code (21.3), terraform test: verificare il comportamento (21.4)

## L'idea

Un architetto non consegna un progetto perché "sembra giusto": lo fa passare per
una scala di collaudi, dai più economici e frequenti ai più costosi e rari. È la
**piramide della validazione**, e ha quattro piani.

Alla *base*, larga e istantanea, ci sono due controlli che lanci di continuo:
**fmt** verifica che il disegno sia leggibile (la forma), **validate** che sia
internamente coerente (i riferimenti tornano, i tipi combaciano). Costano
millisecondi, li fai a ogni salvataggio.

Al piano di mezzo, le **scansioni di sicurezza** — la *policy as code*: regole
scritte una volta che bocciano automaticamente le configurazioni pericolose
(un'immagine non pinnata, una porta aperta al mondo, un segreto in chiaro). Non
chiedono di applicare nulla: leggono il piano e dicono sì o no.

In *cima*, stretta e più lenta, la verifica del **comportamento**: tofu test. Non
"il codice è ben scritto?", ma "il codice fa la cosa giusta?". Dai degli input, e
controlli che gli output, le risorse pianificate, perfino i *rifiuti* delle
validazioni siano quelli attesi. È il collaudo vero — e come tutti i collaudi
veri, lo scrivi tu.

La regola della piramide: tanti controlli economici alla base, pochi collaudi
costosi in cima. In questo capitolo li percorri tutti, e scrivi i tuoi primi test
di infrastruttura.

## Obiettivi

Alla fine saprai:

- descrivere la piramide della validazione e perché ha quella forma;
- usare fmt e validate come rete di sicurezza istantanea (la base);
- riconoscere una regola di policy as code e che cosa boccia (il piano di mezzo);
- scrivere test di comportamento con tofu test: run, assert, expect_failures;
- vedere un test *bocciare* una regressione — la ragione per cui i test esistono.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Porta libera: 8130.
- I capitoli 14 (validazione delle variabili) e 6 (fmt, validate): qui diventano
  una piramide.

## Consegna

### Fase 0 — La base: fmt e validate (21.2)

In start/ c'è la configurazione da collaudare: un container con una variabile
environment validata e qualche output derivato. Parti dai due controlli della
base:

    cd start
    tofu init
    tofu fmt -check
    tofu validate

fmt -check non cambia niente: ti dice solo se la forma è a posto (silenzio =
tutto formattato). validate controlla la coerenza interna senza toccare la
realtà: riferimenti, tipi, argomenti. Sono i due gradini che costano meno e
prendono più errori sciocchi: lanciali sempre, per primi.

### Fase 1 — Il piano di mezzo: policy as code (21.3, si legge)

Sopra la base ci sono le scansioni di sicurezza. Strumenti come tfsec, trivy,
checkov o conftest/OPA leggono il tuo piano e lo confrontano con regole scritte
una volta per tutte — la *policy as code*. In start/policy.rego.example trovi un
esempio da leggere: una regola che boccia le immagini non pinnate (nginx:latest
invece di nginx:1.27-alpine), perché un tag mobile rende il tuo deploy non
riproducibile. La configurazione di start passa quella regola (l'immagine è
pinnata); il punto è che la regola gira *da sola*, in CI, e ferma chi non la
rispetta senza bisogno di una revisione umana. Non c'è uno scanner installato in
questo laboratorio: la Fase è di lettura, ma il concetto — regole eseguibili, non
convenzioni sperate — è il cuore del piano di mezzo.

### Fase 2 — La cima: scrivere i test (21.4, TODO 1 e 2)

Ora il collaudo vero. In start/tests.tftest.hcl c'è lo scheletro di una suite di
test. Un file .tftest.hcl è fatto di blocchi run, ognuno un caso: fissa delle
variabili, esegue un command (plan o apply) e verifica delle assert. Completa i
due TODO.

Il TODO 1 è dentro run "plan_defaults": completa l'assert che controlla l'output
url. Con environment = dev e la porta di default, deve valere:

    assert {
      condition     = output.url == "http://localhost:8130"
      error_message = "the url output should use the default port"
    }

Il TODO 2 è un caso più sottile: verificare che la validation del capitolo 14
*bocci* un input sbagliato. Non si controlla un output — si controlla che il
piano *fallisca*, sulla variabile giusta. Completa il blocco
run "rejects_bad_environment":

    run "rejects_bad_environment" {
      command = plan
      variables {
        environment = "banana"
      }
      expect_failures = [
        var.environment,
      ]
    }

expect_failures rovescia la logica: il test passa *perché* il piano fallisce,
sulla variabile attesa. Lancia la suite:

    tofu test

Leggi la piramide in azione: ogni run "... pass", e in fondo Success! N passed, 0
failed. Il terzo run, plan_defaults a parte, applica davvero e controlla il nome
del container reale — il collaudo che tocca la realtà.

### Fase 3 — Perché i test esistono: bocciare una regressione

Un test che passa sempre non prova niente. Cambia una riga della configurazione
per introdurre un bug — per esempio, in main.tf, fai derivare il nome da qualcosa
di sbagliato (cambia il local container_name in "cap21-fisso"). Rilancia:

    tofu test

Ora il collaudo boccia: Test assertion failed, e ti mostra il valore reale contro
quello atteso, poi Failure! Il test ha fatto il suo mestiere — ha fermato una
modifica che rompeva il comportamento, prima che arrivasse in produzione. Rimetti
a posto la riga e verifica che torni verde.

### Fase 4 — Il ponte (si riflette)

Hai quattro piani di collaudo: forma (fmt), coerenza (validate), sicurezza
(policy), comportamento (test). Da soli valgono poco: il loro posto è *automatico*,
a ogni commit, prima che il codice tocchi la produzione. È esattamente il capitolo
22 — CI/CD e GitOps: la piramide che scatta da sola, e il repository come unica
verità.

### Pulizia

    # tofu test pulisce da sé le risorse che crea; per sicurezza:
    docker rm -f cap21-dev 2>/dev/null

## Criteri di "fatto"

- fmt -check e validate passavano sulla configurazione di start.
- Hai riconosciuto, nell'esempio di policy, quale configurazione verrebbe bocciata
  (immagine non pinnata) e perché.
- Dopo i TODO 1 e 2, tofu test dava Success! con tutti i run verdi, incluso quello
  con expect_failures.
- Rompendo il nome nella Fase 3, tofu test bocciava con Test assertion failed, e
  tornava verde una volta ripristinato.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** La forma della piramide: perché fmt e validate stanno alla base (tanti,
spesso) e tofu test in cima (pochi, rari)? Che cosa prende ciascuno dei quattro
piani che quello sotto non prende — fai un esempio di errore che *solo* un test di
comportamento può cogliere.

**b.** expect_failures: nel TODO 2 il test passa *perché* il piano fallisce.
Perché testare che qualcosa venga *rifiutato* è importante quanto testare che
qualcosa funzioni? Collega alla validation del capitolo 14: che cosa dimostri,
esattamente, con quel run?

**c.** Policy as code e il ponte: qual è la differenza tra una *convenzione*
("ricordati di pinnare le immagini") e una *policy as code* (la regola Rego
dell'esempio)? Perché la piramide dà il meglio solo quando gira in automatico a
ogni commit — che cosa cambia rispetto a lanciarla a mano?
