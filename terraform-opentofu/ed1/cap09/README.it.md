# Capitolo 9 — Argomenti, attributi e l'arte di chiudere un occhio

**Livello:** Intermedio
**Tempo stimato:** 45–55 minuti
**Argomenti del manuale:** anatomia di una risorsa (9.1), argomenti e attributi: ingresso e uscita (9.2), il blocco lifecycle in dettaglio (9.3), i meta-argomenti (9.4), esempio esteso: rete e server su AWS (9.5), esempio esteso: una VM su vSphere (9.6), riepilogo (9.7)

## L'idea

La risorsa è il mattone di tutto, e questo capitolo la mette sul tavolo
operatorio. La prima scoperta è che ha due facce: gli *argomenti* — ciò che
scrivi tu, l'ingresso — e gli *attributi* — ciò che la risorsa ti
restituisce una volta nata, l'uscita: l'id, l'indirizzo IP che Docker le ha
assegnato, i valori che nessuno conosceva prima dell'apply. Costruisci un
dossier che consuma proprio quelle uscite, e nel piano vedi la scia che
lasciano: (known after apply), l'ignoto dichiarato che viaggia lungo il
grafo.

La seconda scoperta completa il lifecycle del capitolo 3 col suo pezzo più
sottile: ignore_changes. La squadra notturna cambia un'impostazione del tuo
container a mano; il piano — fedele ai capitoli 1 e 2 — vuole riconvergerla.
Ma stavolta il cambiamento è *legittimo*: quella manopola appartiene a un
altro processo. Firmerai il contratto dell'occhio chiuso, e imparerai quando
è saggezza e quando è solo una pezza.

## Obiettivi

Alla fine saprai:

- distinguere argomenti (ingresso) e attributi (uscita), e dire quando gli
  attributi nascono;
- leggere (known after apply) come un valore che esiste ma non è ancora
  conoscibile — e vederlo propagarsi lungo i riferimenti;
- usare ignore_changes per tollerare per contratto un drift specifico, e
  spiegarne i rischi;
- elencare i meta-argomenti già incontrati (provider, depends_on,
  lifecycle) e il mestiere di ciascuno;
- leggere gli esempi estesi AWS e vSphere riconoscendo ingressi, uscite e
  archi.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Porta libera: 8093.
- I capitoli 3 (lifecycle), 4 (grafo) e 8 (provider): qui si tirano i fili.

## Consegna

### Fase 0 — La risorsa sul tavolo

Apri start/main.tf e guarda il container con occhi da anatomista. Tutto ciò
che sta scritto — name, image, ports — è *ingresso*: argomenti che tu
imponi. Ma la risorsa, una volta viva, esporta molto di più: un id che
Docker conierà al momento della nascita, un indirizzo IP che nessuno può
prevedere, decine di valori calcolati. Sono gli *attributi*: l'uscita. Li
hai già usati senza nominarli — image = docker_image.web.image_id è
un'uscita dell'immagine che entra nel container.

### Fase 1 — Il dossier (TODO 1)

Il TODO 1 ti chiede di scrivere il dossier della risorsa: un local_file il
cui contenuto consuma due uscite del container —

    container id : ${docker_container.web.id}
    internal ip  : ${docker_container.web.network_data[0].ip_address}

Prima di applicare, guarda il piano:

    cd start
    tofu init
    tofu plan

Il content del dossier è (known after apply): non è un errore né una
lacuna — è l'ignoto *dichiarato*. Quei valori nasceranno solo con la
risorsa, e il piano lo sa: promette il file, ma confessa di non poterti
dire cosa conterrà. Nota che l'ignoto viaggia: nato nel container, si
propaga via riferimento fino al dossier (è l'arco del capitolo 4 che
trasporta valori). Ora:

    tofu apply
    cat dossier.txt
    tofu output

Id e IP veri, scoperti alla nascita e subito messi al lavoro.

### Fase 2 — La squadra notturna

Sono le 03:12 (di nuovo). Un operatore cambia la politica di riavvio del
tuo container, a mano:

    docker update --restart unless-stopped cap09-web
    tofu plan

Il piano la vede: ~ restart "unless-stopped" -> "no", update in-place. È
il riflesso condizionato dei capitoli 1 e 2: la realtà devia dal modello,
il piano propone di riconvergerla. Fin qui, tutto già visto — tranne un
dettaglio: *stavolta l'operatore aveva ragione*. Quella policy la governa
il team di esercizio, non il tuo modello. Se applicassi, annulleresti una
scelta legittima; se aggiornassi il modello a ogni loro cambio, faresti il
segretario di un'altra squadra.

### Fase 3 — Il contratto dell'occhio chiuso (TODO 2)

Il TODO 2 aggiunge al container il pezzo mancante del lifecycle:

    lifecycle {
      ignore_changes = [restart]
    }

Rileggi il piano:

    tofu plan
    docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' cap09-web

No changes — e l'inspect conferma che la realtà è rimasta unless-stopped.
Il drift non è sparito: è stato *tollerato per contratto*, su quella
manopola e solo su quella. È lo strumento giusto quando un attributo
appartiene legittimamente a un altro processo (un autoscaler che regola i
repliche, un sistema che ruota i tag); è una pezza pericolosa quando lo
usi per nascondere drift che andrebbe governato — ogni voce di
ignore_changes è una manopola su cui il tuo modello abdica, per sempre e
in silenzio.

### Fase 4 — Il ripasso dei meta-argomenti

Riguarda il main.tf completo: senza accorgertene hai già collezionato i
meta-argomenti del 9.4 — provider (capitolo 8: il piazzamento), depends_on
(capitolo 4: l'arco dichiarato a mano), lifecycle (capitolo 3 e oggi: le
regole di sostituzione e tolleranza). Sono argomenti che parlano *allo
strumento* anziché al provider: nessuno di loro finisce nell'API di
Docker. Mancano all'appello count e for_each: capitolo 15, e vedrai che
meritano un capitolo intero.

### Fase 5 — La galleria dei cantieri veri (si legge)

In start/examples/ trovi i due esempi estesi del manuale, da leggere con
gli occhiali di oggi:

- **aws-network-server.tf.example** — la filiera rete→server: la VPC
  esporta un id che entra nella subnet, la subnet nel server; tre risorse,
  due archi, e l'ignoto che alla prima apply attraversa tutto il grafo.
- **vsphere-vm.tf.example** — la VM on-premise: e qui noterai dei blocchi
  che *non sono* resource — non creano nulla, *interrogano* l'esistente
  (il datastore, la rete del vCenter). Sono le spie del capitolo 10.

### Pulizia

    tofu destroy

## Criteri di "fatto"

- Nel piano della Fase 1 il content del dossier era (known after apply);
  dopo l'apply dossier.txt contiene id e IP reali.
- Il piano della Fase 2 mostrava ~ restart "unless-stopped" -> "no".
- Dopo il TODO 2: plan risponde No changes E docker inspect mostra ancora
  unless-stopped (il drift c'è, il contratto lo tollera).
- Sai indicare nel tuo main.tf almeno tre argomenti e tre attributi.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Ingressi e uscite: definisci argomento e attributo usando esempi
*tuoi* dal main.tf. Perché il content del dossier era (known after apply)
e che cosa lo ha sbloccato? Che cosa ti dice questo sul momento in cui gli
attributi nascono — e sul perché il piano resta onesto invece di inventare
valori?

**b.** L'occhio chiuso: perché il comportamento della Fase 2 (riconvergere)
era *giusto* secondo i capitoli 1 e 2, e che cosa cambia esattamente il
contratto ignore_changes? Dopo il piano "No changes", la realtà era
cambiata o no? Dai un esempio in cui ignore_changes è saggezza e uno in cui
è una pezza — e spiega il costo silenzioso di ogni voce in quella lista.

**c.** I meta-argomenti e la galleria: elenca i tre meta-argomenti che hai
già usato e il mestiere di ciascuno (e a chi parlano, se non al provider).
Poi nell'esempio AWS: individua un attributo che viaggia da una risorsa
all'altra e descrivi l'arco che disegna. Infine nel vsphere: che cosa NON è
una resource, che cosa fa invece di creare, e perché è l'annuncio perfetto
del capitolo 10?
