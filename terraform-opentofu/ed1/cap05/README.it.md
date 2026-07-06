# Capitolo 5 — La scheda tecnica del grattacielo

**Livello:** Fondamentale
**Tempo stimato:** 45–55 minuti
**Argomenti del manuale:** che cos'è HCL e perché esiste (5.1), blocchi e argomenti (5.2), i tipi primitivi (5.3), i tipi complessi: list, map, set, object, tuple (5.4), stringhe, interpolazione e blocchi di testo (5.5), commenti, formattazione e fmt (5.6), sguardo d'insieme (5.7)

## L'idea

Nei primi quattro capitoli l'HCL l'hai *letto*, guidato dai commenti. Da
questo capitolo lo *scrivi*. Niente più torture all'infrastruttura: qui il
lavoro è da architetti a tavolino — compilare la scheda tecnica di un
grattacielo usando, uno per uno, tutti i tipi di dato del linguaggio: i
primitivi per l'anagrafica, la list per i materiali (dove un duplicato
volutamente infilato ti mostrerà la differenza col set), la map per le
superfici, l'object per l'indirizzo, la tuple per le coordinate. Poi
assembli tutto in un blocco di testo con l'interpolazione: la scheda vera e
propria, che l'apply deposita in un file.

Chiude il capitolo l'attrezzo più umile e più usato del mestiere: tofu fmt,
messo alla prova su un file scritto da un collega sciatto — valido ma
illeggibile. Scoprirai che cosa fmt sistema sempre (la forma) e che cosa non
tocca mai (il significato).

## Obiettivi

Alla fine saprai:

- distinguere a colpo d'occhio un blocco (tipo, etichette, corpo) da un
  argomento (nome = espressione), e riconoscere i blocchi annidati;
- scegliere il tipo giusto: list quando l'ordine conta e i duplicati sono
  ammessi, set quando no; map per chiavi omogenee, object per strutture
  miste, tuple per il posizionale;
- usare le quattro sintassi di accesso: local.x, local.obj.campo,
  local.mappa["chiave"], local.tupla[0];
- scrivere un heredoc con <<-EOT e riempirlo di interpolazioni;
- usare tofu fmt (-diff, -check) e dire esattamente che cosa può cambiare e
  che cosa no.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md. Solo provider local.
- I capitoli 1–4: qui si dà per acquisito il ciclo init/plan/apply/destroy.

## Consegna

### Fase 0 — L'anatomia, prima di scrivere

Apri start/main.tf e leggilo con occhi nuovi, da grammatico: tutto ciò che
vedi è fatto di due sole cose. I *blocchi* — un tipo (terraform, locals,
resource, output), eventuali etichette tra virgolette, un corpo tra graffe —
e gli *argomenti* — nome, segno di uguale, espressione. Nota il dettaglio
che li separa: i blocchi annidati (required_providers dentro terraform) non
hanno il segno di uguale. È tutta qui, la sintassi: il resto del capitolo è
imparare che cosa scrivere *a destra degli uguali*.

L'anagrafica del grattacielo è già compilata, coi tre primitivi: una string,
due number (nota: uno intero, uno decimale — per HCL sono lo stesso tipo),
un bool.

### Fase 1 — I tipi complessi (si scrive)

I TODO da 1 a 4 ti chiedono di compilare, al posto dei segnaposto vuoti:

- **TODO 1, la list dei materiali** — l'ordine di posa conta, e il
  capomastro ha inserito "steel" *due volte*: lascialo doppio, è voluto.
  Subito sotto trovi già scritta una riga che non devi toccare:
  unique_materials = toset(local.materials). È un'anteprima del capitolo 16
  (le funzioni): trasforma la tua list in un set. Il confronto tra i due
  arriva alla Fase 3.
- **TODO 2, la map delle superfici** — tre chiavi (basement, ground,
  tower), tre numeri. Stessa forma per tutti i valori: è questo che la fa
  map.
- **TODO 3, l'object dell'indirizzo** — street (string), number (number),
  historic (bool): tipi diversi sotto lo stesso tetto, è questo che lo fa
  object.
- **TODO 4, la tuple delle coordinate** — latitudine (number), longitudine
  (number), provincia (string): niente nomi, conta la posizione.

Dopo ogni TODO puoi lanciare tofu validate: il file resta sempre valido, i
segnaposto servono a questo.

### Fase 2 — La scheda (interpolazione e heredoc)

Il TODO 5 è la sintesi: il blocco di testo della scheda. La sintassi <<-EOT
apre un testo su più righe (il trattino permette di indentarlo senza
sporcare il risultato), e dentro ci infili le interpolazioni ${...} — una
per ogni sintassi di accesso:

    == ${local.name} ==
    floors     : ${local.floors}
    street     : ${local.address.street} ${local.address.number}
    ground area: ${local.floor_area["ground"]} sqm
    latitude   : ${local.coordinates[0]}
    materials  : ${join(", ", local.unique_materials)}

(la join è la seconda e ultima anteprima del cap. 16: incolla gli elementi
di una collezione in una stringa.)

### Fase 3 — L'apply che ti corregge il compito

    cd start
    tofu init
    tofu apply
    cat datasheet.txt

Leggi gli output con attenzione, perché contengono la lezione del capitolo:

- materials mostra "steel" *due volte*, nell'ordine in cui l'hai scritto:
  la list conserva tutto;
- unique_materials lo mostra *una volta sola*, in ordine alfabetico, ed è
  etichettato toset([...]): il set ha buttato il duplicato e dimenticato
  l'ordine;
- address e floor_area si somigliano ma non sono parenti: guarda i tipi dei
  valori;
- la scheda in datasheet.txt ha tutti i valori al posto giusto.

Riapplica senza cambiare nulla: No changes, come sempre da qui in avanti.

### Fase 4 — Il collega sciatto (fmt)

In start/messy.tf un collega ha scritto una manciata di locals validi ma
impaginati da incubo: uguali disallineati, indentazioni casuali, spazi a
caso. Prima guarda che cosa *farebbe* fmt, senza toccare nulla:

    tofu fmt -diff -check

Poi lascialo lavorare:

    tofu fmt
    tofu fmt -check

Riapri il file: uguali allineati in colonna, indentazione uniforme. Ora la
domanda importante: che cosa NON ha fatto? Non ha rinominato nulla, non ha
riordinato gli argomenti, non ha cambiato un solo valore. fmt è un
tipografo, non un correttore di bozze: sistema la forma, mai il significato.
(È anche il motivo per cui nei team si mette in CI: nessuna discussione
sullo stile, mai un cambio di comportamento.)

### Pulizia

    tofu destroy

## Criteri di "fatto"

- tofu validate è passato a ogni TODO completato (il file non è mai stato
  rotto).
- Negli output: "steel" compare due volte in materials e una sola in
  unique_materials, che è ordinato alfabeticamente ed etichettato toset.
- datasheet.txt contiene le righe attese, con i valori estratti da object,
  map e tuple con le rispettive sintassi di accesso.
- Il secondo apply risponde No changes.
- Dopo tofu fmt, tofu fmt -check non segnala più nulla.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** L'anatomia: scegli dal tuo main.tf un esempio di blocco con
etichette, uno di blocco annidato e uno di argomento, e spiega come li
riconosci (dove sta l'uguale, dove no). Poi il perché: HCL esiste perché
JSON non bastava — che cosa ti ha permesso questo file che in JSON sarebbe
stato impossibile o penoso? (Pensa ai commenti, e a ciò che sta a destra
degli uguali.)

**b.** I tipi: che fine ha fatto il secondo "steel", e che cosa ti dice
questo su quando scegliere list e quando set? Con quali criteri hai deciso
che le superfici erano una map e l'indirizzo un object? E perché per la
tuple non servono nomi di campo?

**c.** Le stringhe e la forma: a che cosa serve il trattino in <<-EOT, e che
cosa fa l'interpolazione ${...} dentro il testo? Poi fmt: elenca che cosa ha
cambiato nel file del collega e che cosa non cambierebbe mai — e perché
questa distinzione (forma sì, significato no) lo rende sicuro da mettere in
automatico in CI.
