# Capitolo 12 — Un solo taccuino, con lucchetto

**Livello:** Intermedio
**Tempo stimato:** 45–55 minuti
**Argomenti del manuale:** backend: la risposta alla domanda «dove» (12.1), configurare un backend: init e migrazione dello stato (12.2), i backend remoti più diffusi (12.3), il lucchetto: lo state locking (12.4), riepilogo e ponte (12.5)

## L'idea

Il capitolo 11 si è chiuso su un incidente: due colleghi, due taccuini, una
realtà contesa. La soluzione ha un nome — backend — ed è la risposta alla
domanda "dove vive lo stato?". In questo esercizio la risposta la
costruisci: la squadra piattaforma (sempre tu, col casco) accende la
bacheca di cantiere — un Consul in container, un backend remoto vero — e tu
*trasferisci* il tuo taccuino lì dentro con la manovra ufficiale: il blocco
backend più init -migrate-state. Andrai a verificare di persona che il file
locale si è svuotato e che lo stato ora abita nel backend (con dentro,
sempre in chiaro, quello che sai dal capitolo 11: la casa è cambiata, le
regole di custodia no).

Poi il collega torna in scena — e stavolta la storia è diversa: si aggancia
allo stesso backend e il suo primo plan dice No changes: *vede le tue
risorse*, perché legge la tua stessa memoria. E il gran finale: mentre un
tuo apply è in corso, lui prova a lavorare — e il lucchetto glielo
impedisce, per nome e cognome: Error acquiring the state lock, con scritto
chi lo tiene e per quale operazione. Il caos del capitolo 11 è diventato
una coda ordinata.

## Obiettivi

Alla fine saprai:

- spiegare che cosa decide il blocco backend (dove vive lo stato, chi può
  leggerlo, come si serializzano le scritture);
- migrare uno stato locale in un backend remoto con init -migrate-state, e
  verificare l'esito da entrambi i lati;
- agganciare un secondo collaboratore allo stesso stato e dimostrare che
  l'incidente del capitolo 11 non può più accadere;
- leggere l'errore di lock (ID, path, operazione, chi) e sapere che esiste
  force-unlock come vetro da rompere in emergenza;
- orientarti tra i backend diffusi (s3, azurerm, gcs, consul, pg, http).

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione (per la bacheca Consul). Porta libera: 8500.
- Il capitolo 11: questo esercizio ne è il secondo tempo.

## Consegna

### Fase 0 — La bacheca di cantiere

Col casco della piattaforma, accendi il servizio che ospiterà il taccuino
condiviso:

    docker run -d --name cap12-consul -p 127.0.0.1:8500:8500 \
      hashicorp/consul:1.20 agent -dev -client=0.0.0.0

(Modalità dev, in chiaro, su localhost: da laboratorio — in produzione
questa bacheca avrebbe TLS, ACL e repliche.) Poi, nei tuoi panni, un mondo
piccolo con stato *locale*:

    cd start
    tofu init
    tofu apply
    ls -la terraform.tfstate

Il taccuino è lì, accanto al codice, come sempre. Per l'ultima volta.

### Fase 1 — Il trasloco (TODO 1)

Il TODO 1 aggiunge al blocco terraform la risposta alla domanda «dove»:

    backend "consul" {
      address = "127.0.0.1:8500"
      scheme  = "http"
      path    = "book-labs/cap12"
    }

Nota che cosa NON dice: nulla sulle risorse, nulla sul provider. Il backend
è pura logistica dello stato. Ora la manovra ufficiale:

    tofu init -migrate-state

Rispondi yes alla domanda di copia e poi verifica il trasloco, da entrambi
i lati:

    tofu state list
    ls -la terraform.tfstate*
    curl -s http://127.0.0.1:8500/v1/kv/book-labs/cap12 | head -c 300

state list funziona come prima (la risorsa c'è) — ma il file locale è
rimasto a zero byte (con un .backup di cortesia), e nel KV di Consul c'è un
Value in base64 che comincia per eyJ2ZXJzaW9uIjo0: è il tuo stato,
version 4, trasferito armi e bagagli. Custodia inclusa: chi può leggere
quella chiave legge anche i segreti del capitolo 11 — cambiare casa non
cambia le regole (accessi ristretti, cifratura: e ricorda l'asso di
OpenTofu, capitolo 20).

### Fase 2 — Il collega, secondo tempo

Rifai la scena del capitolo 11, con la variante che cambia tutto: il
collega clona codice *che ora contiene il blocco backend*.

    mkdir ../colleague
    cp main.tf ../colleague/
    cd ../colleague
    tofu init
    tofu state list
    tofu plan

Niente migrazione stavolta (il suo locale è vuoto: si limita ad
*agganciarsi*), e leggi il risultato: state list elenca LE TUE risorse, e
il plan dice No changes. Stesso codice, stessa memoria, stessa realtà: le
tre fonti sono tornate una catena sola, per chiunque cloni il progetto.

### Fase 3 — Il lucchetto (TODO 2)

Resta l'ultimo pericolo: due apply *contemporanei* sullo stesso taccuino.
Il TODO 2 aggiunge al modello un lavoro lento (un time_sleep da 20 secondi:
il capitolo 4 torna utile), così puoi orchestrare la collisione. Ricorda di
copiare il main.tf aggiornato anche al collega, poi da te:

    tofu apply        # parte e resta occupato ~20s

Mentre gira, dal terminale del collega:

    tofu plan

Error acquiring the state lock — e sotto, il cartellino completo: ID del
lock, path, Operation (OperationTypeApply), Who (utente@macchina). Non è
un guasto: è il lucchetto che fa il suo mestiere — una scrittura alla
volta, gli altri aspettano *sapendo chi c'è dentro*. Quando il tuo apply
finisce, il suo plan passa. (Esiste anche tofu force-unlock <ID>: è il
martelletto rompi-vetro per i lock orfani di un processo morto — si usa
leggendo prima il cartellino, mai per impazienza.)

### Fase 4 — La galleria dei backend (si legge)

Dove vivono i taccuini nel mondo reale: s3 (+ lock nativo o DynamoDB),
azurerm e gcs (lock incluso), consul (quello che hai appena usato), pg
(PostgreSQL, lock advisory), http (un'API su misura), e i servizi gestiti
(HCP Terraform / i remote backend). Il criterio di scelta è sempre lo
stesso trittico: durabilità, controllo degli accessi, locking.

### Pulizia

    tofu destroy      # da una qualunque delle due cartelle: il taccuino è uno
    docker rm -f cap12-consul

## Criteri di "fatto"

- Dopo la migrazione: state list ok, terraform.tfstate locale a zero byte,
  e la chiave book-labs/cap12 presente nel KV di Consul.
- Il collega si è agganciato senza migrazione e il suo primo plan ha detto
  No changes vedendo le tue risorse.
- Durante il tuo apply lento, il suo plan è fallito con Error acquiring
  the state lock e il cartellino (ID, Operation, Who).
- A apply concluso, il suo plan è tornato a funzionare.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** La domanda «dove»: che cosa governa esattamente il blocco backend, e
perché la sua modifica richiede init (e non apply)? Nella migrazione: che
cosa è stato copiato, che cosa è rimasto (il .backup), e perché il blocco
backend non può contenere nulla sulle risorse?

**b.** Il secondo tempo del collega: confronta punto per punto con
l'incidente del capitolo 11 — che cosa vedeva allora il suo plan, che cosa
vede ora, e quale delle tre fonti di verità è cambiata di casa per
ottenere questo effetto? Perché l'aggancio non ha chiesto migrazione?

**c.** Il lucchetto: che cosa proteggerebbe esattamente da due apply
simultanei (pensa a che cosa succederebbe alla memoria con due scritture
intrecciate)? Leggi il cartellino del lock: a che cosa servono ID e Who
nella pratica di squadra? E quando è legittimo force-unlock — e quando è
solo un modo per trasformare una coda ordinata di nuovo in caos?
