# Capitolo 18 — Le carte, non i palazzi

**Livello:** Avanzato
**Tempo stimato:** 55–65 minuti
**Argomenti del manuale:** il problema: l'indirizzo è l'identità (18.1), il blocco moved: rinominare in sicurezza (18.2), il blocco removed: dimenticare senza distruggere (18.3), import: adottare l'esistente (18.4), i comandi di stato: il bisturi manuale (18.5)

## L'idea

Il capitolo 17 si è chiuso con un tranello: incapsulando le risorse in un modulo
ne hai cambiato l'*indirizzo*, e il capitolo 15 ci aveva avvertiti che
l'indirizzo *è* l'identità. Rinomina una risorsa nel codice, e Terraform non vede
un cambio di targa: vede una risorsa sparita e una nuova nata — demolisce e
ricostruisce. Per un container è un fastidio; per un database in produzione è un
disastro.

Ma il taccuino del capitolo 11 — lo stato — è solo una *mappa* tra indirizzi nel
codice e oggetti reali. E una mappa si può correggere senza toccare il
territorio. Questo capitolo ti dà quattro modi per **cambiare le carte senza
toccare i palazzi**:

- **moved** — cambio la targa: "la risorsa che chiamavo app ora si chiama
  frontend". Stesso palazzo, nuovo nome sul registro;
- **removed** — strappo la pagina dal taccuino ma lascio il palazzo in piedi:
  Terraform smette di gestirlo, la realtà resta;
- **import** — aggiungo una pagina per un palazzo che qualcuno ha costruito a
  mano, mai registrato: lo adotto;
- **i comandi di stato** — il bisturi manuale (state list, show, mv, rm) per
  quando serve operare a mano sul taccuino.

Il filo di tutti e quattro: nessun palazzo viene demolito. Lo dimostrerai
controllando, a ogni passo, che il container non è stato ricreato — stesso ID,
sempre in piedi.

## Obiettivi

Alla fine saprai:

- spiegare perché rinominare una risorsa, ingenuamente, provoca distruzione e
  ricreazione (l'indirizzo è l'identità);
- rinominare in sicurezza con un blocco moved, e verificare che la risorsa non è
  stata toccata;
- smettere di gestire una risorsa senza distruggerla con un blocco removed;
- adottare una risorsa esistente, creata fuori da Terraform, con un blocco
  import;
- usare i comandi tofu state (list, show, mv, rm) come bisturi manuale, e sapere
  quando servono ancora.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Porta libera: 8110.
- I capitoli 11 (lo stato come mappa), 15 (l'indirizzo è identità) e 17 (i
  moduli): qui si saldano.

## Consegna

### Fase 0 — Il problema: l'indirizzo è l'identità (18.1)

In start/ trovi due container gestiti: app (sulla 8110) e cache. Applicali e
prendi nota degli ID reali — sono la prova del non-danno:

    cd start
    tofu init
    tofu apply
    docker inspect -f '{{.Id}}' cap18-app

Ora crea a mano un volume *orfano*, come lo lascerebbe un collega con un comando
veloce (ti servirà nella Fase 3):

    docker volume create cap18-data

Prova il tranello. In main.tf rinomina la risorsa da docker_container "app" a
docker_container "frontend" (solo l'etichetta Terraform, lascia
name = "cap18-app"), e chiedi il piano:

    tofu plan

Leggi il disastro: docker_container.app will be destroyed,
docker_container.frontend will be created. Non hai cambiato niente di reale —
solo la targa nel codice — e Terraform vuole demolire e ricostruire. Non
applicare: la Fase 1 lo rende sicuro.

### Fase 1 — moved: cambiare la targa (TODO 1)

Il TODO 1 ti chiede di aggiungere, accanto alla risorsa rinominata, un blocco
moved che dice al taccuino "sono lo stesso, ho solo cambiato nome":

    moved {
      from = docker_container.app
      to   = docker_container.frontend
    }

Richiedi il piano:

    tofu plan

Ora: docker_container.app has moved to docker_container.frontend, e
Plan: 0 to add, 0 to change, 0 to destroy. Nessuna ruspa: solo una riga corretta
nel registro. Applica e verifica che il container sia lo stesso di prima:

    tofu apply
    docker inspect -f '{{.Id}}' cap18-app

Stesso ID della Fase 0: il palazzo non è stato toccato.

### Fase 2 — removed: dimenticare senza distruggere (TODO 2)

La cache passa a un'altra squadra: vuoi che Terraform *smetta di gestirla*, ma
senza spegnerla. Il TODO 2 ti chiede di **togliere** la risorsa
docker_container "cache" dal codice e mettere al suo posto un blocco removed:

    removed {
      from = docker_container.cache
    }

Chiedi il piano e applica:

    tofu plan
    tofu apply

Il piano dice: docker_container.cache will be removed from the OpenTofu state but
will not be destroyed. Dopo l'apply, la cache non è più nel taccuino (tofu state
list non la elenca) — ma il container è ancora vivo:

    docker inspect -f '{{.State.Status}}' cap18-cache

Pagina strappata dal registro, palazzo in piedi.

> **Nota OpenTofu vs Terraform.** È uno dei rari punti in cui la sintassi
> diverge. In OpenTofu il blocco removed *dimentica* e basta. In Terraform devi
> essere esplicito con un lifecycle interno:
>
>     removed {
>       from = docker_container.cache
>       lifecycle {
>         destroy = false
>       }
>     }
>
> Stesso effetto (dimentica senza distruggere); solo due dialetti.

### Fase 3 — import: adottare l'esistente (TODO 3)

Resta il volume orfano che hai creato a mano nella Fase 0: esiste nella realtà,
ma Terraform non lo conosce. Il TODO 3 lo adotta con un blocco import più la
risorsa che lo descrive:

    import {
      to = docker_volume.data
      id = "cap18-data"
    }

    resource "docker_volume" "data" {
      name = "cap18-data"
    }

L'id è l'identificatore reale che il provider capisce — per un volume, il suo
nome. Chiedi il piano e applica:

    tofu plan
    tofu apply

Il piano dice docker_volume.data will be imported, e
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy: adottato senza modifiche,
perché la risorsa che hai scritto combacia con la realtà. Rilancia tofu plan: No
changes. Il palazzo costruito a mano è ora sul registro, senza essere stato
ricostruito.

### Fase 4 — Il bisturi manuale (18.5)

I blocchi moved/removed/import sono la via *dichiarativa*, moderna e verificabile
in un piano. Ma esiste anche il bisturi imperativo, i comandi tofu state — utile
per operazioni al volo o che un blocco non esprime. Guarda e prova:

    tofu state list
    tofu state show docker_container.frontend

state list è l'indice del taccuino; state show apre una pagina. E per le
operazioni chirurgiche a mano ci sono state mv (l'equivalente imperativo di
moved) e state rm (che dimentica dallo state — come removed, ma senza lasciare
traccia in un blocco). Provane uno, poi rimetti a posto:

    tofu state mv docker_container.frontend docker_container.web_front
    tofu state list
    tofu state mv docker_container.web_front docker_container.frontend

Bisturi potente e senza rete: nessun piano lo annuncia, nessuna revisione lo
rivede. I blocchi dichiarativi esistono proprio per rendere questi tagli visibili
in un piano — usa i comandi solo quando servono davvero.

### Fase 5 — Le fila della Parte 5 (si riflette)

Hai imparato a far evolvere il codice senza che l'infrastruttura ne paghi il
prezzo: la mappa si corregge, il territorio resta. È il tema della Parte 5, la
manutenzione. Il prossimo passo è gestire *più ambienti* insieme — dev, staging,
prod — senza copiare e incollare, e senza che un errore in dev sfiori la prod: il
capitolo 19.

### Pulizia

    tofu destroy
    docker rm -f cap18-cache
    docker volume rm cap18-data

(La cache e il volume, non più gestiti o adottati dopo il destroy, vanno rimossi
a mano: sono l'eco del confine tra ciò che Terraform gestisce e ciò che no.)

## Criteri di "fatto"

- Nella Fase 0, il rename ingenuo produceva un piano con destroy + create.
- Con moved (TODO 1), il piano era 0 to add, 0 to change, 0 to destroy, e l'ID
  del container restava invariato.
- Con removed (TODO 2), la cache spariva dallo state ma il container restava in
  stato running.
- Con import (TODO 3), il volume orfano entrava nello state (1 to import) e il
  piano successivo diceva No changes.
- Hai usato tofu state list/show e provato un state mv andata e ritorno.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** L'indirizzo è l'identità: spiega perché, senza moved, rinominare
docker_container.app in docker_container.frontend distrugge e ricrea, anche se il
container reale (name, immagine, porta) è identico. Che cosa confronta davvero
Terraform quando decide destroy+create — il nome reale o l'indirizzo nel
taccuino? Collega al capitolo 11 (che cosa mappa lo stato).

**b.** removed contro un destroy: qual è la differenza tra togliere una risorsa
dal codice *senza* un blocco removed e toglierla *con* il blocco removed? In
quale caso il container si spegne e in quale resta vivo? E perché la sintassi
differisce tra OpenTofu e Terraform, pur ottenendo lo stesso risultato?

**c.** import e il bisturi: perché il piano dell'import diceva 0 to change
(nessun drift), mentre importare un container fatto a mano spesso costringe a un
replace? Che cosa ci dice sul rapporto tra la risorsa che scrivi e l'oggetto che
adotti? E infine: perché i blocchi moved/removed/import sono preferibili ai
comandi tofu state mv/rm, pur facendo cose simili — che cosa ti dà un piano che
un comando a mano non dà?
