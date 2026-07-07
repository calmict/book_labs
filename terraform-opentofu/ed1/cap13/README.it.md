# Capitolo 13 — Le porte tagliafuoco

**Livello:** Intermedio
**Tempo stimato:** 50–60 minuti
**Argomenti del manuale:** il problema del monolite di stato (13.1), che cos'è il blast radius (13.2), come si segrega: le linee di taglio (13.3), far comunicare gli stati: terraform_remote_state (13.4), tiriamo le fila della Parte 3 (13.5)

## L'idea

Un palazzo senza porte tagliafuoco brucia tutto insieme. Un progetto con un
solo stato, anche: in questo esercizio costruisci prima il *monolite* —
rete e applicazione nello stesso taccuino — e misuri il raggio
dell'esplosione: la squadra rete rinomina la propria rete, e il piano
mostra l'incendio che si propaga fino al container dell'app; nel frattempo,
un solo lucchetto mette in coda chiunque, qualunque cosa stia facendo.

Poi installi le porte tagliafuoco: due configurazioni, due taccuini (nel
Consul che conosci dal capitolo 12), e il canale ufficiale per farli
parlare — terraform_remote_state, il data source che legge gli *output* di
un altro stato. Chiudi con le due prove del contenimento: il comando più
distruttivo che esista, lanciato nella stanza dell'app, non vede nemmeno la
rete; e un apply lento dell'app non blocca più il plan della rete — due
code, due lucchetti, due squadre che lavorano davvero in parallelo.

## Obiettivi

Alla fine saprai:

- spiegare il problema del monolite: raggio dell'esplosione, lock unico,
  plan sempre più lenti;
- riconoscere le linee di taglio classiche (per componente, per ambiente)
  e il criterio per sceglierle;
- far comunicare due stati con terraform_remote_state, e dire perché il
  canale sono gli *output* (un contratto, non un accesso libero);
- dimostrare il contenimento: destroy-scope limitato alla stanza, lock
  indipendenti;
- tirare le fila della Parte 3: risorse, dati, stato — chi fa che cosa.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Porta libera: 8500 (Consul, come nel capitolo 12).
- I capitoli 10 (data source), 11 (stato) e 12 (backend e lock): questo
  capitolo li usa tutti e tre.

## Consegna

### Fase 0 — Il monolite (e il suo raggio)

Accendi la bacheca (il Consul del capitolo 12):

    docker run -d --name cap13-consul -p 127.0.0.1:8500:8500 \
      hashicorp/consul:1.20 agent -dev -client=0.0.0.0

In start/monolith/ trovi il palazzo senza porte: la rete della squadra
rete e il container della squadra app, *nello stesso file, nello stesso
stato*. Applicalo:

    cd start/monolith
    tofu init
    tofu apply

Ora interpreta la squadra rete: in main.tf rinomina la rete da
cap13-core-net a cap13-core-net-v2, e chiedi il piano:

    tofu plan

Leggi l'incendio: docker_network.core must be replaced — e, riga sotto,
docker_container.app must be replaced. La squadra rete ha toccato *la
propria* risorsa, e il piano brucia anche quella dell'app: dipendenza nel
grafo, stesso stato, stesso piano, stesso lucchetto — chiunque lavori qui
mette in coda tutti gli altri (capitolo 12), e ogni errore ha come raggio
massimo *l'intero taccuino*. Annulla la modifica e demolisci il monolite:

    tofu destroy

(Demolire per ricostruire è la via del laboratorio: il capitolo 18 ti
insegnerà a fare questo taglio *senza* demolire, spostando le risorse da
uno stato all'altro a caldo.)

### Fase 1 — Il taglio

In start/ trovi le due stanze già pronte come struttura: network/ e app/.
La stanza network è completa: la stessa rete di prima, più un *output* —
network_name. Guardalo bene: è la porta ufficiale della stanza, l'unica
cosa che il mondo esterno potrà vedere. Applica:

    cd ../network
    tofu init
    tofu apply

Nota i path nel backend: book-labs/cap13/network e (tra poco)
book-labs/cap13/app — due chiavi diverse nella stessa bacheca: due
taccuini. Le linee di taglio nel mondo reale seguono due assi: per
*componente* (rete / dati / applicazione — è quello che stai facendo) e
per *ambiente* (dev / staging / prod — mai un taccuino solo per tutti).

### Fase 2 — Il citofono tra le stanze (TODO 1 e 2)

Nella stanza app, il TODO 1 ti chiede il data source che legge l'altro
taccuino:

    data "terraform_remote_state" "network" {
      backend = "consul"
      config = {
        address = "127.0.0.1:8500"
        scheme  = "http"
        path    = "book-labs/cap13/network"
      }
    }

E il TODO 2 lo mette al lavoro nel container:

    networks_advanced {
      name = data.terraform_remote_state.network.outputs.network_name
    }

Fermati sulla parola outputs: il remote_state non ti dà accesso alle
*risorse* dell'altro stato — solo ai suoi output. È un contratto: la
squadra rete decide che cosa esporre (network_name), e tutto il resto del
suo taccuino resta affar suo. Applica:

    cd ../app
    tofu init
    tofu plan
    tofu apply

Nel piano, nota il capitolo 10 al lavoro: Reading... Read complete, e il
nome della rete già risolto — l'altro stato esiste, si consulta al plan.

### Fase 3 — Le due prove del contenimento

Prova uno: il comando peggiore, nella stanza giusta.

    tofu plan -destroy

Due risorse: il container e l'immagine. La rete *non compare*: non è in
questo taccuino, e nessun comando lanciato da questa stanza può toccarla.
Il raggio massimo dell'esplosione è la stanza stessa.

Prova due: due code, due lucchetti. Il TODO 3 aggiunge all'app il lavoro
lento (time_sleep da 15 secondi, il trucco del capitolo 12). Poi:

    tofu apply        # nell'app: parte e resta occupato

e mentre gira, dalla stanza network:

    tofu plan

No changes — *passa subito*. Nel capitolo 12 questo plan sarebbe rimasto
fuori dalla porta con l'errore di lock; ora i lucchetti sono due, uno per
taccuino: la squadra rete lavora mentre l'app applica. Il monolite metteva
tutti in fila; le porte tagliafuoco danno a ogni squadra la sua stanza *e
la sua coda*.

### Fase 4 — Le fila della Parte 3 (si riflette)

Cinque capitoli, un impianto: le risorse impongono (9), i data consultano
(10), lo stato lega codice e realtà e custodisce troppo (11), il backend
gli dà una casa condivisa col lucchetto (12), la segregazione gli dà
confini che contengono gli errori (13). La domanda c ti chiede di
ricomporli.

### Pulizia

Due stanze, due destroy — nell'ordine giusto (chi consuma prima di chi
espone):

    tofu destroy                  # nella stanza app
    cd ../network && tofu destroy
    docker rm -f cap13-consul

## Criteri di "fatto"

- Nel monolite, il rename della rete produceva un piano con DUE replace
  (rete e container).
- Il plan dell'app mostrava la lettura del remote_state (Read complete) e
  il nome rete già risolto.
- tofu plan -destroy nella stanza app elencava solo container e immagine.
- Il plan della rete è passato (No changes) MENTRE l'apply lento dell'app
  era in corso.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Il monolite: elenca i tre costi che hai osservato o dedotto (raggio
del piano, lucchetto unico, e che cosa succederebbe ai tempi di plan con
500 risorse). Nel piano dell'incendio: perché il container bruciava
*insieme* alla rete — quale capitolo della Parte 1 lo spiega?

**b.** Il citofono: perché terraform_remote_state espone solo gli output e
non le risorse dell'altro stato? Ragiona in termini di contratto tra
squadre: che cosa può cambiare la squadra rete senza avvisare nessuno, e
che cosa invece è una promessa? E il rovescio: che cosa NON contiene il
raggio (se la squadra rete demolisce davvero la rete, alla tua app che
succede)?

**c.** Le fila della Parte 3: componi in cinque frasi il viaggio dello
stato — dal file accanto al codice (11) alla casa condivisa (12) alle
stanze separate (13) — e chiudi con la linea di taglio che sceglieresti
per un progetto vero con dev e prod, due squadre e un database: quanti
taccuini, e perché?
