# Capitolo 15 — La flotta: per numero o per nome

**Livello:** Intermedio
**Tempo stimato:** 50–60 minuti
**Argomenti del manuale:** count: moltiplicare per numero (15.1), la trappola di count: l'indice fragile (15.2), for_each: moltiplicare per identità — lista contro set (15.3), i condizionali: esistere o non esistere (15.4), i blocchi dynamic: generare blocchi annidati (15.5)

## L'idea

Finora ogni risorsa era un pezzo unico, scritto a mano. Ma un quartiere ha cento
case uguali, e nessuno le scrive una per una. Questo capitolo ti dà i due modi
per *moltiplicare* una risorsa — e ti mostra perché la scelta tra i due è una
delle più importanti che farai.

Il primo modo conta **per numero**: count. Dai un numero, e ottieni quella
quantità di copie, indicizzate [0], [1], [2]. Comodo, immediato — e con una
trappola nascosta. L'identità di ogni copia è la sua *posizione*: la casa numero
2. Togli una casa in mezzo alla fila, e tutte quelle dopo *scalano di numero*:
la 3 diventa la 2, la 4 diventa la 3. Terraform, che lega l'identità alla
posizione, crede che tu abbia rinominato mezza flotta — e la ricostruisce. Lo
vedrai col tuo piano: una sola rimozione, e l'incendio si propaga alla coda.

Il secondo modo conta **per nome**: for_each. Ogni copia ha un'identità
*stabile* — non la posizione, ma una chiave: ["alpha"], ["bravo"], ["charlie"].
Togli quella in mezzo, e sparisce solo lei: le altre non si accorgono di niente.
È la cura della trappola, e il motivo per cui for_each è quasi sempre la scelta
giusta.

Chiudi con due strumenti di contorno: il **condizionale**
(count = var.abilitato ? 1 : 0 — una risorsa che esiste o non esiste), e il
blocco **dynamic**, che genera blocchi annidati a partire da una collezione — la
stessa moltiplicazione, ma *dentro* una risorsa.

## Obiettivi

Alla fine saprai:

- moltiplicare una risorsa con count e leggere i suoi indirizzi indicizzati
  ([0], [1]…);
- spiegare e *dimostrare* la trappola dell'indice fragile: perché togliere un
  elemento in mezzo scatena una cascata di replace;
- moltiplicare per identità con for_each, e dire perché vuole un set o una mappa
  (non una lista) — di qui il toset();
- far esistere o sparire una risorsa con un condizionale (? 1 : 0);
- generare blocchi annidati con un blocco dynamic a partire da una collezione.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Nessuna porta host pubblicata: niente conflitti.
- I capitoli 3 (replace) e 14 (variabili, locals): qui li vedi moltiplicati.

## Consegna

### Fase 0 — La flotta contata per numero (count)

In start/ la flotta nasce *contata per numero*: la variabile fleet è una lista
(alpha, bravo, charlie) e il container usa count = length(var.fleet), con nome
cap15-${var.fleet[count.index]}. Applica:

    cd start
    tofu init
    tofu apply
    tofu state list

Guarda gli indirizzi: docker_container.web[0], [1], [2]. L'identità di ciascuno
è il suo *numero*.

### Fase 1 — La trappola dell'indice fragile

Ora togli la casa *in mezzo* — bravo — passando la lista senza di lei, e chiedi
il piano (non applicare):

    tofu plan -var 'fleet=["alpha","charlie"]'

Leggi l'incendio:

    # docker_container.web[1] must be replaced
    ~ name = "cap15-bravo" -> "cap15-charlie" # forces replacement
    # docker_container.web[2] will be destroyed

Una sola rimozione, due risorse sconvolte. Perché? count lega l'identità alla
*posizione*: l'indice 1 era bravo, ora è charlie, e per Terraform la risorsa [1]
va rinominata (e il nome forza il replace, eco del capitolo 3); l'indice 2 non
esiste più, distrutto. Solo alpha ([0]) si salva, perché sta prima del buco.
Questa è la trappola: **con count, cancellare in mezzo rimescola la coda.**

### Fase 2 — Contare per nome (TODO 1: for_each)

Il TODO 1 ti chiede di ri-contare la flotta *per identità*. Riscrivi la risorsa
web sostituendo count con for_each:

    resource "docker_container" "web" {
      for_each = toset(var.fleet)
      name     = "cap15-${each.key}"
      image    = docker_image.web.image_id
    }

Due dettagli. Primo: for_each non accetta una *lista*, vuole un *set* o una
*mappa* — perché la lista ha un ordine (posizioni), il set no (solo
appartenenza). toset() converte la lista in insieme di identità. Secondo: dentro
la risorsa non c'è più count.index, ma each.key — la chiave, cioè il nome.
Ri-applica e guarda gli indirizzi:

    tofu apply
    tofu state list

Ora sono docker_container.web["alpha"], web["bravo"], web["charlie"]:
indicizzati per *nome*. Rifai l'esperimento della Fase 1:

    tofu plan -var 'fleet=["alpha","charlie"]'

Stavolta: Plan: 0 to add, 0 to change, 1 to destroy — e l'unica toccata è
web["bravo"]. alpha e charlie non si muovono: la loro identità non dipende da
chi hanno accanto. La trappola è sparita.

### Fase 3 — Esistere o non esistere (TODO 2: il condizionale)

Il TODO 2 aggiunge un *canary* — un container che esiste solo quando lo accendi.
Completa il count con un'espressione condizionale:

    resource "docker_container" "canary" {
      count = var.canary_enabled ? 1 : 0
      name  = "cap15-canary"
      image = docker_image.web.image_id
    }

count = 0 significa *nessuna* copia: la risorsa è dichiarata ma non esiste. È il
modo idiomatico di rendere una risorsa opzionale. Provalo:

    tofu plan                          # canary_enabled=false: il canary non c'è
    tofu plan -var canary_enabled=true # 1 to add: appare

L'interruttore ? 1 : 0 è il pattern che incontrerai ovunque per accendere e
spegnere pezzi di infrastruttura.

### Fase 4 — Generare blocchi annidati (TODO 3: dynamic)

Fin qui hai moltiplicato *risorse*. Il blocco dynamic moltiplica *blocchi
dentro* una risorsa. Il TODO 3 genera un blocco labels per ogni voce della mappa
var.labels, dentro il container web:

    dynamic "labels" {
      for_each = var.labels
      content {
        label = labels.key
        value = labels.value
      }
    }

Il nome dopo dynamic ("labels") è il blocco da generare; dentro content descrivi
*una* iterazione, e labels.key/labels.value pescano dalla mappa. Applica e
verifica che le etichette siano atterrate davvero:

    tofu apply
    docker inspect -f '{{json .Config.Labels}}' cap15-alpha

Vedrai team:platform e tier:web. Cambia var.labels, e i blocchi si rigenerano da
soli: è la fine dei blocchi annidati copincollati a mano.

### Fase 5 — Il ponte (si riflette)

count conta per numero (fragile), for_each per nome (stabile), il condizionale
accende e spegne, dynamic moltiplica i blocchi. Tutti prendono una *collezione*
e la trasformano in risorse o blocchi — ma le collezioni vanno spesso
*preparate* prima (filtrare, trasformare, unire): è esattamente il capitolo 16,
le funzioni e le espressioni for.

### Pulizia

    tofu destroy

## Criteri di "fatto"

- Con count, gli indirizzi erano web[0], [1], [2]; togliere bravo produceva un
  replace + un destroy (la cascata).
- Dopo il TODO 1, gli indirizzi erano web["alpha"] ecc.; togliere bravo toccava
  *solo* bravo (0 add, 0 change, 1 destroy).
- Con il TODO 2, canary_enabled=true produceva 1 to add; false, nessun canary.
- Dopo il TODO 3, docker inspect su cap15-alpha mostrava le etichette team e
  tier.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** La trappola: spiega con parole tue perché, con count, togliere bravo ha
*sostituito* charlie e *distrutto* l'ultimo, mentre alpha si è salvato. Che cosa
lega count all'identità di ciascuna copia, e perché il nome che cambia ha
forzato un replace (quale capitolo)?

**b.** Lista contro set: perché for_each non accetta una lista ma vuole un set o
una mappa? Che cosa ha una lista che un for_each non deve avere, e che cosa fa
esattamente toset()? Dopo la conversione, perché togliere bravo non tocca più
alpha e charlie?

**c.** Le due moltiplicazioni: distingui count/for_each (moltiplicano *risorse*)
dal blocco dynamic (moltiplica *blocchi* dentro una risorsa) — con un esempio
tuo di quando serve ciascuno. E il condizionale ? 1 : 0: perché count = 0 è il
modo idiomatico per rendere opzionale una risorsa, invece di commentarla via?
