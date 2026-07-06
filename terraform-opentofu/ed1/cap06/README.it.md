# Capitolo 6 — La prima pietra

**Livello:** Fondamentale
**Tempo stimato:** 45–55 minuti
**Argomenti del manuale:** Terraform e OpenTofu: due binari, un linguaggio (6.1), installazione (6.2), la prima configurazione completa: blocco terraform, provider, resource (6.3), il ciclo di vita: init, plan, apply, destroy (6.4), i comandi accessori di ogni giorno (6.5), cosa abbiamo costruito (6.6)

## L'idea

Cinque capitoli di concetti e di esercizi guidati: adesso posi la prima
pietra tua. In questo esercizio scrivi da zero — riga per riga, non più a
segnaposto — la tua prima configurazione completa: il blocco terraform che
dichiara i traduttori, il blocco provider che li configura, le risorse, un
output. Il risultato non è un file su disco: è un servizio web vero,
raggiungibile col browser, acceso da codice.

E soprattutto vivi il ciclo di vita al rallentatore, guardando dove finora
sei passato di corsa: che cosa scarica *davvero* init (andrai a pesare il
binario del provider dentro .terraform: sorpresa), che cos'è un piano
salvato e perché eseguirlo non chiede conferma, quali domande quotidiane
trovano risposta in state list, show e output, e che cosa il destroy
demolisce — e che cosa invece lascia in piedi.

## Obiettivi

Alla fine saprai:

- spiegare "due binari, un linguaggio": dove finisce il binario che hai
  installato tu e dove cominciano i provider che installa init;
- scrivere una configurazione completa: terraform, provider, resource,
  output;
- usare il piano salvato (plan -out + apply del file) e dire perché non
  chiede conferma;
- rispondere alle tre domande quotidiane con state list, show e output;
- dire con precisione che cosa rimuove destroy e che cosa no.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione (come nel capitolo 3).
- La porta 8087 libera (se è occupata, scegline un'altra e tienila per
  tutto l'esercizio).

## Consegna

### Fase 0 — I due binari

Prima di costruire, guarda l'attrezzo:

    tofu version
    which tofu

Quel binario l'hai installato tu (capitolo 6.2 del manuale: pacchetto,
archivio o gestore che sia). È l'unica installazione manuale di tutto
l'ecosistema: i provider — i traduttori verso Docker, AWS, e il resto del
mondo — li installerà init, tra poco, da solo. E se al posto di tofu ci
fosse terraform, tutto ciò che segue sarebbe identico: stesso linguaggio,
stesso ciclo, stessi provider.

### Fase 1 — La prima configurazione completa (si scrive tutta)

In start/ trovi main.tf quasi vuoto: solo i commenti che ti fanno da guida.
Scrivi tu, blocco per blocco, validando a ogni passo (tofu validate):

Il blocco terraform — chi traduce:

    terraform {
      required_providers {
        docker = {
          source  = "kreuzwerker/docker"
          version = "~> 3.0"
        }
      }
    }

Il blocco provider — come parlargli (vuoto = il Docker locale di default):

    provider "docker" {}

Le risorse — che cosa deve esistere:

    resource "docker_image" "web" {
      name         = "nginx:1.27-alpine"
      keep_locally = true
    }

    resource "docker_container" "web" {
      name  = "cap06-web"
      image = docker_image.web.image_id

      ports {
        internal = 80
        external = 8087
      }
    }

L'output — che cosa esporre a chi guarda da fuori:

    output "url" {
      value = "http://localhost:8087"
    }

Nota, mentre scrivi, che stai usando tutta la grammatica del capitolo 5:
blocchi con etichette, blocchi annidati (ports, senza uguale), argomenti,
un riferimento che disegna un arco nel grafo del capitolo 4.

### Fase 2 — init, sotto la lente

    cd start
    tofu init

Stavolta non tirare dritto: guarda che cosa è comparso.

    ls -a
    find .terraform -name 'terraform-provider-*' -exec du -h {} \;
    cat .terraform.lock.hcl

Dentro .terraform c'è il binario del provider docker: pesalo — decine di
megabyte. *Questa* è l'installazione dei traduttori: il tuo binario da
qualche parte nel PATH, i provider qui, per cartella di lavoro. Il file
.terraform.lock.hcl è il registro delle versioni esatte scelte (è il
protagonista del capitolo 7: per ora sappi che esiste e che non si tocca).
Rilancia init una seconda volta: finisce in un lampo — è idempotente, come
tutto da queste parti.

### Fase 3 — Il piano salvato

Finora hai usato apply "interattivo": calcola il piano, te lo mostra, chiede
conferma. C'è un secondo modo, ed è quello dei sistemi seri:

    tofu plan -out=first.plan

Leggi il piano con calma: 2 to add, e accanto agli attributi non ancora
conoscibili la dicitura (known after apply). Poi eseguilo:

    tofu apply first.plan

Nessuna domanda. Non è sfrontatezza: un piano salvato è un contratto — apply
esegue *esattamente* ciò che è scritto nel file, né più né meno. Se nel
frattempo il mondo fosse cambiato, l'esecuzione fallirebbe piuttosto che
improvvisare. (Tienilo a mente: plan -out in revisione, apply del file
approvato — è il cuore delle pipeline del capitolo 22.)

La prima pietra è posata:

    curl http://localhost:8087

Benvenuto a casa tua: Welcome to nginx!, acceso da codice.

### Fase 4 — Le tre domande di ogni giorno

Tre comandi, tre domande quotidiane:

    tofu state list

"Che cosa sto gestendo?" — l'elenco delle risorse sotto contratto: le tue
due, niente di più (gli altri container che girano sulla stessa macchina
non ci sono: non sono roba tua).

    tofu show | head -20

"Com'è fatta, nel dettaglio, la realtà che gestisco?" — la fotografia
completa, attributo per attributo, compresi quelli che non hai mai scritto
(il provider ha riempito i default).

    tofu output
    tofu output -raw url

"Che cosa ho promesso di esporre?" — gli output, in forma leggibile o nuda
(-raw, perfetta per gli script).

### Fase 5 — Un cambiamento, per ripassare

Porta la porta esterna da 8087 a 8088 in main.tf, poi:

    tofu plan

Fermati: must be replaced, e accanto alla porta il marcatore # forces
replacement. È il capitolo 3 che bussa: la porta pubblicata è identità
contesa, non si cambia su un container vivo. Applica e verifica:

    tofu apply
    curl http://localhost:8088

### Fase 6 — La demolizione (e ciò che resta)

    tofu destroy
    tofu state list
    ls -a

Lo state è vuoto e il container non esiste più — ma .terraform, il lock
file e il tuo main.tf sono ancora lì. destroy demolisce l'infrastruttura,
non lo studio dell'architetto: il progetto, i traduttori installati e il
registro delle versioni restano, pronti per il prossimo apply.

### Pulizia

Già fatta: il destroy della Fase 6 era la pulizia. Le immagini nginx
restano sul disco (keep_locally); docker rmi se le vuoi togliere.

## Criteri di "fatto"

- Hai scritto tu l'intero main.tf, e tofu validate è passato dopo ogni
  blocco.
- Hai trovato e pesato il binario del provider dentro .terraform (decine di
  MB) e visto nascere .terraform.lock.hcl.
- tofu apply first.plan è partito senza chiedere conferma, e curl sulla
  8087 ha risposto con la pagina di benvenuto.
- Il cambio di porta ha prodotto un replace (marcatore # forces
  replacement), non un update.
- Dopo il destroy: state list vuoto, ma .terraform e lock file ancora
  presenti.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Due binari, un linguaggio — e due installazioni: che cosa hai
installato tu, e che cosa ha installato init (dove, e quanto pesa)? Perché
questa divisione — un core piccolo e traduttori scaricati per cartella — è
sensata? E che cosa cambierebbe, in tutto l'esercizio, usando terraform al
posto di tofu?

**b.** Il piano salvato: perché tofu apply first.plan non ha chiesto
conferma, mentre tofu apply da solo la chiede? Che cosa *è* quel file — e
perché "esegue esattamente ciò che è scritto" è una garanzia preziosa
quando tra il piano e l'esecuzione passano una revisione e un'approvazione?

**c.** Le tre domande quotidiane: associa state list, show e output alla
domanda a cui rispondono, e spiega perché state list NON mostra i container
altrui che girano sulla stessa macchina. Infine il destroy: che cosa ha
rimosso e che cosa ha lasciato, e perché questa asimmetria è esattamente
quello che vuoi?
