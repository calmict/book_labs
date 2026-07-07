# Capitolo 17 — Il prefabbricato

**Livello:** Intermedio
**Tempo stimato:** 50–60 minuti
**Argomenti del manuale:** che cos'è un modulo (17.1), anatomia di un modulo locale (17.2), i moduli remoti e il Registry (17.3), i moduli e i provider: il provider aliased (17.4)

## L'idea

Da sedici capitoli scrivi lo stesso schema: variabili in cima, risorse in mezzo,
output in fondo. E ogni volta lo riscrivi da capo, cartella dopo cartella.
L'architetto vero non ridisegna la stessa palazzina per ogni lotto: la progetta
una volta come **prefabbricato**, e poi la cala nella città quante volte serve,
ognuna con le sue rifiniture.

Il prefabbricato, qui, è il **modulo**: una cartella con dei file .tf, ma vista
come una *scatola con delle porte*. Le porte d'ingresso sono le sue variabili
(nome, ambiente, porta); il macchinario dentro sono le risorse (immagine e
container); le porte d'uscita sono i suoi output (l'URL dove risponde). Chi usa
la scatola non guarda dentro: passa gli input alle porte d'ingresso, e legge i
risultati dalle porte d'uscita. Sono esattamente le variabili e gli output del
capitolo 14 — ma promossi a *interfaccia* di un componente riusabile.

Costruirai il prefabbricato una volta, poi lo chiamerai dalla configurazione
radice con for_each (l'eredità del capitolo 15) per tirarne su due istanze
isolate — un blog in dev, un negozio in prod — da un solo progetto della scatola.
Noterai due cose che diventano capitoli: che il modulo *non* dichiara il proprio
provider (lo eredita dalla root, e questo apre il tema dei provider aliased), e
che infilare le risorse in una scatola ne cambia l'*indirizzo* — ed è proprio da
lì che riparte la Parte 5.

## Obiettivi

Alla fine saprai:

- dire che cos'è un modulo e riconoscere le sue tre parti (variabili = porte
  d'ingresso, risorse = macchinario, output = porte d'uscita);
- scrivere un modulo locale e chiamarlo dalla radice con un blocco module
  (source + input);
- istanziare lo stesso modulo più volte con for_each, ognuna isolata, e
  aggregarne gli output;
- spiegare perché un modulo eredita il provider dalla root, e quando invece va
  passato esplicito (il provider aliased, 17.4);
- riconoscere un modulo remoto dal Registry (source + version) e perché la
  versione va fissata.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Porte libere: 8101 e 8102.
- I capitoli 14 (variabili e output) e 15 (for_each): qui diventano l'interfaccia
  e il moltiplicatore di una scatola.

## Consegna

### Fase 0 — Anatomia della scatola (17.2)

Apri start/modules/webapp/main.tf: è il prefabbricato. Leggilo come una scatola
con tre parti:

- **porte d'ingresso** — le variabili name, environment (con la sua validation,
  eco del capitolo 14), external_port;
- **macchinario** — un docker_image e un docker_container, col nome derivato in
  un local (cap17-nome-ambiente);
- **porte d'uscita** — gli output url e container_name.

Nota una cosa che manca: dentro il modulo *non c'è* nessun blocco
provider "docker" {}. Il modulo dichiara solo, nel blocco terraform, di *aver
bisogno* del provider docker (required_providers) — ma la sua *configurazione* la
eredita da chi lo chiama. Un prefabbricato non si porta dietro la centrale
elettrica: si allaccia a quella del quartiere. Tienilo a mente per la Fase 5.

### Fase 1 — La porta d'uscita (TODO 1)

La scatola è quasi finita: manca una porta d'uscita. Il TODO 1, in
modules/webapp/main.tf, ti chiede di completare l'output url — ciò che la scatola
*promette* a chi la usa. Sostituisci il segnaposto:

    output "url" {
      value = "http://localhost:${var.external_port} (${var.environment})"
    }

È l'unica cosa che il mondo esterno leggerà del container: l'interfaccia, non
l'implementazione.

### Fase 2 — Calare il prefabbricato (TODO 2)

Ora la configurazione radice, in start/main.tf. La variabile apps è già lì: una
mappa di due applicazioni (blog in dev sulla 8101, shop in prod sulla 8102). Il
TODO 2 ti chiede il blocco module che chiama la scatola, una volta per
applicazione:

    module "webapp" {
      source   = "./modules/webapp"
      for_each = var.apps

      name          = each.key
      environment   = each.value.environment
      external_port = each.value.external_port
    }

source dice *dove* sta la scatola (un path locale); for_each la istanzia una
volta per voce della mappa; le tre righe passano gli input alle porte
d'ingresso. Un modulo va *installato*, come un provider:

    cd start
    tofu init

Leggi "Initializing modules... webapp in modules/webapp": init ora installa anche
i moduli, non solo i provider.

### Fase 3 — Le porte d'uscita aggregate (TODO 3)

Il TODO 3, sempre nella radice, raccoglie gli URL delle due istanze in un solo
output. Sostituisci il segnaposto:

    output "urls" {
      value = { for k, m in module.webapp : k => m.url }
    }

module.webapp è la collezione delle istanze; m.url legge la porta d'uscita di
ciascuna. Applica e guarda:

    tofu apply
    tofu state list
    tofu output urls

Negli indirizzi vedi il namespace del modulo:
module.webapp["blog"].docker_container.this, module.webapp["shop"]... — le
risorse ora vivono *dentro* la scatola. E l'output aggregato dà blog → 8101
(dev), shop → 8102 (prod).

### Fase 4 — Una scatola, tante istanze

Prova il riuso all'opera. Le due applicazioni sono isolate: togli il negozio
dalla mappa e chiedi il piano (non applicare):

    tofu plan -var 'apps={ blog = { environment = "dev", external_port = 8101 } }'

Solo module.webapp["shop"].* viene distrutto: blog non si muove. È il for_each
del capitolo 15, ma su un intero modulo — ogni istanza ha la sua identità, e il
prefabbricato è uno solo. Verifica anche che i due container rispondano:

    curl -s localhost:8101 | grep -o '<title>.*</title>'
    curl -s localhost:8102 | grep -o '<title>.*</title>'

### Fase 5 — Registry, provider aliased, e il ponte (si legge)

Due cose che il manuale mostra e che qui trovi come esempi da leggere in
start/examples/:

- **registry-module.tf.example** (17.3): lo stesso blocco module, ma con source
  che punta al *Registry* (terraform-aws-modules/vpc/aws) e una version fissata.
  I moduli remoti sono prefabbricati di altri: la version è il tuo lucchetto
  (capitolo 7), perché non vuoi che la scatola cambi sotto i piedi.
- **aliased-provider.tf.example** (17.4): come *passare* un provider a un modulo.
  Di default il modulo eredita il provider di default della root (Fase 0); ma se
  vuoi che le sue risorse nascano nel secondo datacenter del capitolo 8, glielo
  passi esplicito con providers = { docker = docker.frankfurt }.

E il ponte: infilando le risorse nella scatola, il loro *indirizzo* è cambiato —
da docker_container.this a module.webapp["blog"].docker_container.this. Ma il
capitolo 15 ci ha insegnato che l'indirizzo *è* l'identità: spostare una risorsa
dentro un modulo, di norma, la distruggerebbe e ricostruirebbe. La Parte 5 si
apre esattamente qui — il capitolo 18 insegna a cambiare indirizzo *senza*
distruggere (il blocco moved).

### Pulizia

    tofu destroy

## Criteri di "fatto"

- Il modulo non aveva un blocco provider "docker" {}: ereditava il provider
  dalla radice.
- Dopo il TODO 2, tofu init stampava "webapp in modules/webapp".
- Gli indirizzi in state avevano il prefisso module.webapp["blog"]/["shop"].
- tofu output urls dava blog → 8101 (dev) e shop → 8102 (prod).
- Togliendo shop dalla mappa, il piano distruggeva solo l'istanza shop.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** La scatola e le sue porte: mappa le tre parti del modulo (variabili,
risorse, output) sui tre ruoli (porte d'ingresso, macchinario, porte d'uscita),
e spiega perché gli output sono l'*interfaccia* e non un dettaglio — che cosa può
cambiare l'autore del modulo senza rompere chi lo usa, e che cosa no?

**b.** L'eredità del provider: perché il modulo non dichiara un blocco
provider "docker" {} e lo eredita dalla root? Che cosa cambia se vuoi che le sue
risorse nascano in un provider *aliased* (capitolo 8), e con quale riga glielo
dici? Perché è una scelta di chi *chiama* il modulo, non di chi lo scrive?

**c.** Il Registry e il ponte: in un modulo remoto (source verso il Registry),
perché fissare la version è importante quanto il lock file del capitolo 7? E
infine: incapsulare le risorse nel modulo ne ha cambiato l'indirizzo — perché
questo è un problema (che cosa dice il capitolo 15 sull'indirizzo come identità),
e quale capitolo della Parte 5 lo risolve?
