# Capitolo 10 — Il catasto

**Livello:** Intermedio
**Tempo stimato:** 40–50 minuti
**Argomenti del manuale:** che cos'è una sorgente dati (10.1), perché sono fondamentali (10.2), leggere risorse esistenti non gestite da Terraform (10.3), una piccola galleria di sorgenti dati comuni (10.4), noto al plan o noto solo all'apply? (10.5), riepilogo e ponte verso lo Stato (10.6)

## L'idea

Nessun cantiere parte su un terreno vergine: c'è la rete del quartiere,
l'acquedotto, il catasto che registra ciò che esiste. Finora ogni cosa nel
tuo modello la creavi tu; in questo capitolo impari a *consultare* —
leggere ciò che esiste, appartiene ad altri, e non è affar tuo gestire.

La squadra piattaforma ha creato una rete Docker (a mano: Fase 0, sei tu a
interpretarla). Tu la leggi con un blocco data — le spie annunciate nella
galleria del capitolo 9 — e ci appoggi il tuo container: costruisci *su* ciò
che non possiedi. Lungo la strada scopri il rovescio del capitolo 9: gli
attributi del data source sono noti *già al plan* — l'esistente si consulta
subito, non c'è nulla da aspettare — tranne quando il data dipende da una
risorsa che deve ancora nascere: allora la lettura slitta all'apply, e
l'ignoto torna. Vedrai i due casi fianco a fianco, nello stesso piano. E al
destroy, la prova che chiude il capitolo: ciò che leggi non è tuo — la rete
della piattaforma sopravvive intatta.

## Obiettivi

Alla fine saprai:

- scrivere un blocco data e spiegare in che cosa differisce da una resource
  (leggere vs possedere);
- costruire risorse tue sopra oggetti altrui, senza gestirli;
- prevedere quando un data source viene letto al plan e quando slitta
  all'apply — e riconoscere i due casi nel piano;
- dire che cosa compare in state list con prefisso data. e che fine fa al
  destroy;
- citare qualche sorgente dati classica dei mondi veri (la galleria).

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Nessuna porta richiesta stavolta.
- I capitoli 9 (attributi, known after apply) e 4 (archi): qui si
  capovolgono.

## Consegna

### Fase 0 — Il mondo che esiste già

Indossa il casco della squadra piattaforma e crea la loro rete, a mano:

    docker network create --subnet 172.28.0.0/16 cap10-platform-net

Da questo momento in poi torni nei tuoi panni: quella rete esiste, ha un
proprietario, e *non sei tu*. Il tuo modello non dovrà mai crearla, né
modificarla, né distruggerla — solo usarla.

### Fase 1 — Consultare il catasto (TODO 1)

Il TODO 1 ti chiede il primo blocco data della tua carriera:

    data "docker_network" "platform" {
      name = "cap10-platform-net"
    }

Stessa grammatica della resource — tipo, etichetta, corpo — ma mestiere
opposto: la resource *impone* (crea ciò che descrive), il data *interroga*
(cerca ciò che descrivi e ne esporta gli attributi). Insieme al data,
scommenta la sua scheda catastale (netcard): un local_file che ne consuma
id, driver e scope. Ora la mossa importante — guarda il piano *prima* di
applicare:

    cd start
    tofu init
    tofu plan

Due cose da notare, entrambe in controtendenza col capitolo 9. Primo: in
testa al piano, data.docker_network.platform: Reading... e Read complete —
la lettura è avvenuta *durante il plan*. Secondo: il content della netcard
è *già risolto* — id vero, driver vero, nessun (known after apply).
L'esistente non ha nulla da aspettare: si consulta, e i valori sono lì.

### Fase 2 — Costruire su suolo altrui (TODO 2)

Il TODO 2 aggancia il tuo container alla rete della piattaforma:

    networks_advanced {
      name = data.docker_network.platform.name
    }

Applica e verifica:

    tofu apply
    docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}: {{$v.IPAddress}}{{end}}' cap10-web
    cat netcard.txt

Il tuo container vive nella loro rete (IP nella 172.28.x): hai costruito
sopra un oggetto che non gestisci, e l'arco del grafo stavolta parte da un
data — l'ordine resta garantito (prima si legge, poi si costruisce).

### Fase 3 — L'ignoto che torna (il caso differito)

In fondo a main.tf trovi già scritto il blocco B dell'esperimento: una rete
*tua* (docker_network "ours") e un secondo data che la legge — ma quella
rete nascerà solo all'apply. Chiedi il piano e confronta le due schede:

    tofu plan

La netcard (Fase 1) è risolta; la freshcard è (known after apply). Stesso
tipo di data, due destini: se ciò che il data descrive esiste ed è
indipendente da questo run, la lettura avviene al plan; se dipende da una
risorsa che deve ancora nascere, slitta all'apply — e l'ignoto dichiarato
del capitolo 9 ricompare a valle. È la regola del 10.5 in un solo piano.

    tofu apply
    cat freshcard.txt

### Fase 4 — Leggere non è possedere

    tofu state list

Le voci data. stanno nell'elenco: lo strumento *ricorda* ciò che ha letto
(dove lo ricorda? nel state — ed è il ponte verso il capitolo 11). Ma ora
la prova regina:

    tofu destroy
    docker network ls

Il container, la rete tua, le schede: spariti. La rete della piattaforma:
*intatta*. Il destroy demolisce ciò che possiedi, mai ciò che consulti —
il catasto non brucia quando demolisci la casa.

### Fase 5 — La piccola galleria (si legge)

I data source che incontrerai per primi nei mondi veri: aws_ami con
most_recent = true (l'ultima immagine che rispetta i filtri — il classico
assoluto), aws_availability_zones e aws_caller_identity (chi sono io, dove
posso costruire), e i quattro vsphere_* che hai già letto nella galleria
del capitolo 9 — che ora sai nominare: erano data source, e adesso sai
esattamente che cosa fanno e quando vengono letti.

### Pulizia

La rete della piattaforma l'hai creata a mano interpretando un'altra
squadra — e a mano va tolta:

    docker network rm cap10-platform-net

## Criteri di "fatto"

- Nel piano della Fase 1: Read complete durante il plan, e il content della
  netcard già risolto (nessun known after apply).
- Il container risulta agganciato a cap10-platform-net con IP nella
  172.28.x.
- Nello stesso piano della Fase 3: netcard risolta E freshcard (known after
  apply) — sai spiegare la differenza.
- Dopo il destroy: le tue 5 risorse sparite, cap10-platform-net ancora in
  docker network ls.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Leggere vs possedere: stessa grammatica, mestiere opposto — definisci
la differenza tra resource e data con gli esempi di questo esercizio. Che
cosa è comparso in state list col prefisso data., e che cosa è successo a
quelle voci (e agli oggetti che descrivono) al destroy?

**b.** Il 10.5 in un piano solo: perché la netcard era risolta al plan e la
freshcard no? Enuncia la regola generale (quando un data viene letto al
plan, quando slitta all'apply) e spiega perché questa differenza è
importante quando *revisioni* un piano prima di approvarlo.

**c.** Il ponte: lo strumento "ricorda" ciò che i data hanno letto — dove?
E se la squadra piattaforma cambiasse la propria rete tra un plan e il
successivo, che cosa ti aspetti che faccia il prossimo plan con quel data?
(Non serve la risposta perfetta: è l'apertura del capitolo 11 — le tre
fonti di verità.)
