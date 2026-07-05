# Capitolo 1 — Il fiocco di neve e la mandria

**Livello:** Fondamentale
**Tempo stimato:** 30–40 minuti
**Argomenti del manuale:** la crisi del click-ops e il server fiocco-di-neve (1.1), dagli script alla configurazione gestita (1.2), che cosa fa Terraform e che cosa non fa (1.3), animali da compagnia e capi di bestiame (1.4)

## L'idea

Prima di imparare la sintassi, devi *sentire* il problema. In questo esercizio
costruisci due "server" a mano, come si faceva (e purtroppo si fa ancora) col
click-ops: scoprirai che divergono subito. Poi li descrivi come codice: stessa
fotografia del risultato per entrambi. Da lì in poi torturi l'infrastruttura —
la modifichi a mano di notte, ne cancelli un pezzo, la radi al suolo — e ogni
volta un solo comando la riporta esattamente al modello. Alla fine il "server"
non è più un animale da compagnia con un nome e una storia: è un capo di
bestiame con un'etichetta, sostituibile in ogni momento.

I "server" qui sono semplici file di configurazione sul tuo disco: zero cloud,
zero costi, ma i concetti — drift, idempotenza, convergenza, immutabilità
dell'identità — sono esattamente gli stessi che incontrerai in produzione.

## Obiettivi

Alla fine saprai:

- riconoscere il drift configurativo e spiegare perché il click-ops lo produce
  inevitabilmente;
- distinguere l'approccio imperativo ("esegui questi passi") da quello
  dichiarativo ("questo è il risultato che voglio");
- osservare l'idempotenza in azione: applicare due volte non cambia nulla;
- vedere la convergenza: la realtà modificata a mano torna al modello;
- spiegare la differenza tra pet e cattle con un esempio concreto.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md nella cartella del manuale.
  I comandi qui sotto usano tofu; con terraform sono identici.
- Nessuna conoscenza di HCL richiesta: la sintassi arriva nei capitoli 5 e 6.
  Qui la leggi guidato dai commenti, non devi ancora saperla scrivere.

## Consegna

### Fase 0 — Il click-ops, come ai vecchi tempi

Sei l'amministratore del lunedì. Crea il primo server a mano:

    mkdir -p /tmp/clickops && cd /tmp/clickops
    printf 'hostname = web-01\npackages = nginx, openssl\nport = 8080\ndebug_mode = off\n' > server-a.conf

Martedì un collega deve creare il "gemello". Va di fretta, copia a memoria:

    printf 'hostname = web-02\npackages = nginx\nport = 8080\ndebug_mode = on\n' > server-b.conf

Confrontali:

    diff server-a.conf server-b.conf

Due server "identici" che identici non sono mai stati: manca un pacchetto, il
debug è rimasto acceso. Questo è il drift, ed è nato *alla creazione*, non
dopo mesi. Ogni server fatto a mano è un fiocco di neve: unico, fragile,
irripetibile.

### Fase 1 — Descrivi il risultato, non i passi

Entra nella cartella dell'esercizio e apri start/main.tf. Trovi lo stampo
(la configurazione d'oro, uguale per tutti) e il primo server già dichiarato.
Il TODO ti chiede di dichiarare il secondo server usando **lo stesso stampo**:
niente copia a memoria, niente drift possibile per costruzione.

Quando hai completato il TODO:

    cd start
    tofu init
    tofu apply

Leggi il piano che ti propone prima di confermare: è la differenza tra il
modello (due server) e la realtà (zero server). Poi verifica:

    diff servers/server-a.conf servers/server-b.conf

Nessuna differenza. Lo stampo è uno, le colate sono identiche.

### Fase 2 — L'idempotenza

Applica di nuovo, senza aver cambiato nulla:

    tofu apply

Osserva la risposta. Un secondo giro di uno script imperativo avrebbe
ri-eseguito tutti i passi (o sarebbe esploso); qui invece non succede nulla,
*perché non deve succedere nulla*: la realtà corrisponde già al modello.

### Fase 3 — Il sabotaggio notturno (drift)

Sono le 03:12 e qualcuno "sistema al volo" un server in produzione:

    printf 'debug_mode = on   # fix temporaneo, poi lo tolgo (bugia)\n' >> servers/server-b.conf

Chiedi il piano:

    tofu plan

Guarda con attenzione: il file modificato a mano non viene "corretto" — per
il provider quel mutante non è più la risorsa che gestiva, e il piano propone
di ricrearla dallo stampo. È l'immutabilità in miniatura: non si ripara il
fiocco di neve, si ricola dal modello. Convergi:

    tofu apply
    grep debug servers/server-b.conf

Il debug è di nuovo off. Il "fix temporaneo" delle 03:12 non sopravvive al
primo apply: la fonte di verità è il codice, non la memoria di chi è
intervenuto di notte.

### Fase 4 — La sparizione

Cancella del tutto un server:

    rm servers/server-a.conf
    tofu plan

Il piano propone di ricrearlo, identico. Applica e verifica.

### Fase 5 — La mandria

Prendi nota dell'etichetta della tua mandria:

    tofu output herd_tag

Poi radi tutto al suolo e ricostruisci:

    tofu destroy
    tofu apply
    tofu output herd_tag
    cat servers/server-a.conf

La configurazione è tornata identica in ogni riga che conta, ma l'etichetta è
diversa: è un altro capo di bestiame, e va benissimo così. Se web-01 fosse
stato un animale da compagnia — con anni di modifiche a mano non documentate —
questa operazione sarebbe stata una catastrofe irreversibile. Qui è un comando.

### Pulizia

    tofu destroy

## Criteri di "fatto"

- La Fase 2 risponde esattamente: No changes. Your infrastructure matches the
  configuration.
- Dopo il sabotaggio della Fase 3, un apply riporta debug_mode a off senza che
  tu abbia toccato il file a mano.
- Dopo destroy + apply (Fase 5) i due file esistono di nuovo, identici tra
  loro, con una herd_tag diversa da quella annotata prima.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

Rispondi con parole tue in answers.md (trovi il modello in start/):

**a.** Nella Fase 0 il drift è comparso alla *creazione* dei server, non dopo
mesi di vita. Perché il click-ops produce fiocchi di neve per sua natura, e
perché uno script imperativo di per sé non basta a eliminare il problema?

**b.** Che cosa hai *descritto* in main.tf, e che cosa invece *non* hai mai
scritto da nessuna parte? Alla luce di questo: che cosa fa lo strumento per
te, e che cosa resta fuori dal suo mestiere (pensa a cosa succede *dentro* un
vero server dopo che esiste)?

**c.** Nella Fase 5 la mandria è rinata con un'etichetta nuova e nessuno se
n'è preoccupato. Spiega la differenza tra pet e cattle usando proprio la
herd_tag come esempio: perché l'identità che cambia è un prezzo accettabile —
anzi, un vantaggio — per il bestiame, e perché per un pet non lo sarebbe?
