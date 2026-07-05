# Capitolo 2 — La ricetta e la fotografia

**Livello:** Fondamentale
**Tempo stimato:** 40–50 minuti
**Argomenti del manuale:** il modello imperativo: pensare per passi (2.1), il modello dichiarativo: descrivere il risultato (2.2), idempotenza (2.3), convergenza (2.4), quando l'imperativo resta la scelta giusta (2.5), perché questa frattura prepara l'immutabilità (2.6)

## L'idea

Una ricetta elenca i passi: rompi le uova, scalda la padella, versa. Una
fotografia mostra il piatto finito. Nel capitolo 1 hai *sentito* il drift; qui
metti le mani sulla frattura che lo genera: scrivi davvero uno script
imperativo di provisioning, lo guardi esplodere al secondo giro, lo ripari
aggiungendo le guardie ("se esiste, salta") — e poi scopri il suo difetto
fatale: le guardie rendono lo script ri-eseguibile, ma *cieco*. Un file
vandalizzato passa la guardia indisturbato, perché la guardia controlla che il
file *esista*, non che sia *giusto*.

Poi fotografi la stessa flotta in un main.tf e la torturi da quattro punti di
partenza diversi — cantiere vuoto, mezzo costruito, vandalizzato, già finito —
sempre con lo stesso identico comando. I passi non li scrivi più tu: li
calcola lo strumento, ogni volta, confrontando la realtà con il modello.

## Obiettivi

Alla fine saprai:

- spiegare perché uno script di passi funziona solo dalla partenza che il suo
  autore aveva in mente;
- costruire a mano l'idempotenza con le guardie, e misurarne il costo;
- distinguere ri-eseguibilità e convergenza: la prima la ottieni con le
  guardie, la seconda no;
- osservare lo stesso comando produrre piani diversi da partenze diverse, e
  lo stesso risultato da tutte;
- riconoscere i compiti per cui la ricetta resta lo strumento giusto.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md. I comandi usano tofu;
  con terraform sono identici.
- Bash di base (sai cosa fanno mkdir e un if). L'HCL si legge guidati dai
  commenti, come nel capitolo 1.

## Consegna

### Fase 0 — La ricetta, primo giro

In start/ trovi provision.sh: dieci righe imperative che creano una flotta di
tre server (file di configurazione) e la registrano in un inventario. Leggilo:
è chiaro, ordinato, funziona.

    cd start
    ./provision.sh
    ls fleet/

Tutto lì: tre config e un inventory.txt. Ora rilancialo:

    ./provision.sh

Esplode al primo passo: la cartella esiste già. Lo script non è sbagliato — è
*imperativo*: descrive i passi da UNA partenza precisa (il vuoto). Da
qualsiasi altra partenza, i passi non hanno senso.

### Fase 1 — Le guardie (idempotenza fatta a mano)

Apri provision.sh: i TODO ti indicano i tre punti da proteggere. Rendi lo
script ri-eseguibile: la cartella va creata solo se manca, ogni config scritta
solo se non esiste, l'inventario registrato una volta sola. (Suggerimenti nei
commenti: mkdir -p, if [ -f ... ].)

Quando hai finito:

    ./provision.sh
    ./provision.sh

Due giri, zero errori: "already exists, skipping" dappertutto. Congratulazioni,
hai costruito l'idempotenza a mano. Nota quanto codice è servito: lo script è
quasi raddoppiato, e ogni nuova risorsa futura dovrà portarsi la sua guardia.

### Fase 2 — La guardia cieca

Sono di nuovo le 03:12, e qualcuno tocca un server a mano:

    sed -i 's/debug_mode = off/debug_mode = on/' fleet/server-2.conf

Rilancia lo script appena riparato:

    ./provision.sh
    grep debug fleet/server-2.conf

Guarda bene: "server-2 already exists, skipping" — e il debug è ancora on. La
guardia ha fatto esattamente il suo lavoro: il file *esiste*, quindi salta. Non
ha mai guardato *dentro*. Ri-eseguibile non vuol dire convergente: per
convergere davvero dovresti confrontare il contenuto di ogni file col
contenuto desiderato — cioè riscrivere in bash, a mano, quello che uno
strumento dichiarativo fa di mestiere.

### Fase 3 — La fotografia

Radi al suolo il cantiere della ricetta e passa al modello:

    rm -rf fleet

Apri main.tf: la stessa flotta, ma descritta come risultato — tre server
colati dallo stesso stampo e un inventario *derivato dal modello* (guarda la
join: la lista dei server scrive lei l'inventario, nessuno dei due può
scordarsi dell'altro). Il TODO ti chiede di dichiarare server_3, sul modello
dei primi due. Poi:

    tofu init
    tofu apply

### Fase 4 — Le quattro partenze, un solo comando

Adesso tortura la fotografia. Partenza vandalizzata:

    sed -i 's/debug_mode = off/debug_mode = on/' fleet/server-2.conf
    tofu plan
    tofu apply
    grep debug fleet/server-2.conf

Il drift che la guardia saltava qui viene visto (il piano propone di ricolare
il mutante) e riassorbito. Partenza mezzo costruita — esattamente lo stato in
cui la ricetta naive crashava:

    rm fleet/server-3.conf
    : > fleet/inventory.txt
    tofu plan
    tofu apply
    cat fleet/inventory.txt

Il piano stavolta dice due risorse, non una: ricrea solo ciò che manca o
devia. Partenza già completa:

    tofu apply

No changes. Quattro partenze, un comando identico, piani tutti diversi,
risultato sempre lo stesso: questo è convergere. I passi esistono ancora —
ma li calcola lo strumento, ogni volta, dal confronto tra realtà e modello.

### Pulizia

    tofu destroy

## Criteri di "fatto"

- Il provision.sh riparato regge due giri consecutivi senza errori.
- Dopo il sed della Fase 2, lo script con guardie LASCIA il debug a on (è il
  comportamento atteso: è la dimostrazione, non un bug).
- Dalla partenza mezzo costruita, tofu plan propone esattamente 2 risorse da
  ricreare, e dopo l'apply l'inventario contiene di nuovo i tre server.
- L'ultimo apply risponde: No changes.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Perché la ricetta naive è esplosa al secondo giro, e che cosa —
esattamente — le guardie hanno aggiunto e che cosa no? Usa il server-2
vandalizzato per distinguere *ri-eseguibilità* da *convergenza*.

**b.** Nelle quattro partenze il comando era sempre lo stesso, ma i piani
erano diversi (4 da creare, 1, 2, nessuno). Chi calcola i passi adesso, e da
quali *due* ingredienti? Che cosa hai smesso di dover sapere tu?

**c.** Quando la ricetta resta la scelta giusta? Fai due esempi concreti di
compiti che non descriveresti mai come fotografia (pensa a: un backup con
timestamp, una migrazione one-shot, un riavvio). E perché questa frattura
prepara l'immutabilità del capitolo 3 — nel capitolo 1 il mutante non è stato
riparato ma ricolato: quale dei due modelli rende naturale quel gesto?
