# Capitolo 19 — Il cassetto o la stanza

**Livello:** Avanzato
**Tempo stimato:** 55–65 minuti
**Argomenti del manuale:** cosa significa davvero "ambiente" (19.1), prima strategia: i workspace (19.2), seconda strategia: le directory separate (19.3), Terragrunt: il direttore d'orchestra (19.4)

## L'idea

Dev, staging, prod: lo stesso progetto, tre città diverse. Copiare e incollare la
configurazione tre volte è la fotocopia che il capitolo 1 ci ha insegnato a
temere — ma un ambiente non è solo "lo stesso codice con un nome diverso". Un
ambiente è una *copia isolata* della stessa infrastruttura, con le sue
impostazioni e — soprattutto — **il suo stato**. E il capitolo 13 ce lo ha già
gridato: gli ambienti non devono mai condividere il raggio dell'esplosione. Un
errore in dev non deve poter mettere in coda, corrompere o distruggere la prod.

Questo capitolo mette a confronto le due strategie principali, e le fa toccare con
mano.

La prima è il **workspace**: un solo codice, un solo backend, ma più stati — uno
per workspace. È come tenere dev e prod in due *cassetti* dello stesso schedario:
cambi cassetto con un comando (workspace select) e lavori sull'uno o sull'altro.
DRY al massimo, ma con un rovescio: lo schedario è uno solo, e un apply lanciato
nel cassetto sbagliato colpisce l'ambiente sbagliato.

La seconda sono le **directory separate**: una cartella per ambiente (dev/,
prod/), ognuna col suo stato, che condividono lo stesso *modulo* (il prefabbricato
del capitolo 17). È come dare a ogni ambiente una *stanza* propria, con la stessa
pianta ma muri veri in mezzo: più esplicito, più codice di contorno, ma un
isolamento che i workspace non danno — distruggere dev non può sfiorare prod.

E chiuderai con **Terragrunt**, il direttore d'orchestra che tiene le stanze
separate *senza* farti copiare e incollare il contorno — lo vedrai come esempio
da leggere.

## Obiettivi

Alla fine saprai:

- dire che cos'è davvero un ambiente (impostazioni diverse, stato separato, raggi
  non condivisi);
- usare i workspace: terraform.workspace, workspace new/select/list, e capirne il
  rischio;
- usare le directory separate con un modulo condiviso, e dimostrarne
  l'isolamento;
- confrontare le due strategie su DRY contro isolamento, e scegliere con la testa;
- riconoscere il ruolo di Terragrunt (DRY *sopra* le directory separate).

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Porte libere: 8120, 8121 (workspace) e 8122, 8123
  (directory).
- I capitoli 13 (blast radius), 12 (backend e stato) e 17 (moduli): qui si
  combinano.

## Consegna

### Parte A — Il cassetto: i workspace (19.2)

In start/workspaces/ c'è una configurazione che nasce *mono-ambiente*: nome e
porta cablati. Il TODO 1 la rende *consapevole del workspace*. Completa i local
perché derivino l'ambiente da terraform.workspace e peschino le impostazioni da
una mappa:

    locals {
      settings = {
        dev  = { external_port = 8120 }
        prod = { external_port = 8121 }
      }
      env = terraform.workspace
      cfg = lookup(local.settings, terraform.workspace, local.settings["dev"])
    }

terraform.workspace è una variabile speciale: contiene il nome del workspace
corrente. Ora crea i due cassetti e applica in ciascuno:

    cd start/workspaces
    tofu init
    tofu workspace new dev
    tofu apply
    tofu workspace new prod
    tofu apply

Guarda i cassetti e i due container nati da un solo codice:

    tofu workspace list
    docker ps --filter name=cap19-

L'asterisco in workspace list segna quello corrente. Nota dove finisce lo stato:
in terraform.tfstate.d/dev/ e terraform.tfstate.d/prod/ — due stati, un solo
backend. Ed è qui il rischio: lo schedario è uno, il cassetto attivo è uno *stato
della CLI*. Se credi di essere in dev e sei in prod, il tuo apply colpisce la
prod. I workspace sono DRY ma **condividono codice e backend**: nessun muro tra
gli ambienti.

### Parte B — La stanza: le directory separate (19.3)

In start/directories/ la struttura è diversa: un modulo condiviso (modules/webapp/,
il prefabbricato del capitolo 17) e una cartella per ambiente. dev/ è già
completa: chiama il modulo con le impostazioni di sviluppo. Il TODO 2 ti chiede di
completare prod/main.tf sullo stesso modello, con le impostazioni di produzione
(porta 8123):

    module "app" {
      source        = "../modules/webapp"
      environment   = "prod"
      external_port = 8123
    }

Applica i due ambienti, ognuno dalla sua cartella:

    cd ../directories/dev  && tofu init && tofu apply
    cd ../prod             && tofu init && tofu apply

Ogni cartella ha il *suo* stato, il *suo* backend, il *suo* init. Ora la prova
dell'isolamento — distruggi dev e guarda prod:

    cd ../dev  && tofu destroy
    cd ../prod && tofu plan

Dev sparisce, ma il container di prod resta vivo, e il plan di prod dice No
changes: dalla cartella prod non si *vede* nemmeno dev. Muri veri: nessun comando
lanciato in una stanza può raggiungere l'altra. È il capitolo 13 applicato agli
ambienti — raggi separati, per costruzione.

### Parte C — Il direttore d'orchestra: Terragrunt (19.4, si legge)

Le directory separate isolano benissimo, ma un prezzo lo pagano: il *contorno* —
il blocco terraform, il provider, la configurazione del backend — si ripete in
ogni cartella. Terragrunt è lo strumento che toglie quel copia-incolla tenendo
l'isolamento. In start/directories/terragrunt.hcl.example trovi un esempio da
leggere: un file radice che *genera* la configurazione del backend (una chiave di
stato diversa per ambiente) e definisce provider comuni una volta sola, e cartelle
per ambiente che fanno solo include del radice più i propri inputs. Una sola fonte
di verità per il contorno, stanze ancora separate. Non è OpenTofu né Terraform: è
un livello *sopra*, un direttore che li dirige.

### Parte D — Scegliere con la testa (19.5, si riflette)

Nessuna delle due strategie è "giusta" in assoluto. I workspace sono imbattibili
per DRY e per varianti effimere (un ambiente di test usa e getta, un branch); ma
condividono codice e backend, e per dev/prod veri quel muro mancante è un rischio.
Le directory separate costano un po' di contorno (Terragrunt lo recupera), ma
danno l'isolamento che la produzione merita. La regola pratica del manuale:
workspace per varianti *dello stesso* deploy, directory separate per ambienti che
devono *non potersi toccare*.

### Pulizia

    # workspaces
    cd start/workspaces
    tofu workspace select dev  && tofu destroy
    tofu workspace select prod && tofu destroy
    tofu workspace select default
    # directories
    cd ../directories/prod && tofu destroy

## Criteri di "fatto"

- Con i workspace, terraform.workspace guidava il nome, e dev/prod avevano stati
  separati in terraform.tfstate.d/.
- workspace list mostrava default, dev, prod, con l'asterisco sul corrente.
- Con le directory separate, dev e prod avevano ognuno il proprio stato e il
  proprio init.
- Distruggendo dev, il container di prod restava vivo e il plan di prod diceva No
  changes.
- Hai riconosciuto, nell'esempio, che cosa genera Terragrunt (backend
  per-ambiente + contorno comune).
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Che cos'è un ambiente: elenca le tre cose che distinguono davvero dev da
prod (non solo il nome). Perché lo *stato separato* è la più importante, e quale
capitolo aveva già posto il principio (gli ambienti non condividono il raggio)?

**b.** Il cassetto contro la stanza: descrivi il rischio concreto dei workspace
(perché è facile colpire l'ambiente sbagliato) e che cosa esattamente le directory
separate mettono tra dev e prod che i workspace non mettono. In che senso il tuo
destroy di dev ha *dimostrato* l'isolamento?

**c.** Terragrunt e la scelta: quale problema delle directory separate risolve
Terragrunt, e quale *non* risolve (che cosa resta separato)? E infine: per un
ambiente di test effimero legato a un branch, sceglieresti il cassetto o la
stanza — perché?
