# Capitolo 1 — Le tre crepe

**Livello:** Fondamentale

Il manuale si apre con una promessa: diventare il direttore d'orchestra della
tua infrastruttura. Ma prima di alzare la bacchetta bisogna capire *perché* lo
spartito scritto a mano — lo script Bash — si sbriciola quando i musicisti non
sono tre ma tremila. In questo primo laboratorio **non useremo ancora Ansible**:
lo installeremo al capitolo 6. Qui proverai con le tue mani il *problema* che
Ansible esiste per risolvere, così che tutto il resto del manuale abbia un senso.

Tre "server" (tre container), uno stato che vuoi mantenere identico su tutti, e
uno script che prova a imporlo. Lo script funzionerà. Poi lo rieseguirai, e si
aprirà la prima crepa.

## Obiettivi

- Vedere all'opera le **tre crepe** dello scripting imperativo: non è ripetibile,
  descrive *passi* e non uno *stato*, la divergenza è inevitabile.
- Distinguere due idee che sembrano la stessa cosa e non lo sono: **ripetibilità**
  (posso rilanciarlo senza che esploda) e **convergenza** (mi riporta allo stato
  voluto, qualunque fosse la partenza).
- Capire perché il salto da 3 a 3000 server non è quantitativo ma qualitativo, e
  cosa significano **push** e **pull**.

## Prerequisiti

- Un motore **Docker** in esecuzione (i tre container fanno da server). Verifica
  con: docker version
- Nient'altro. In particolare **niente Ansible**: qui è voluto — questo è il
  mondo *prima* dell'automazione.
- Nota: usiamo docker exec per lanciare comandi "sul server". Sta al posto
  dell'SSH che useresti su una macchina vera (l'SSH è il capitolo 3); la crepa
  che vedrai è identica.

## Lo scenario

Tre server nella tua flotta: cap01-server1, cap01-server2, cap01-server3. Su
ognuno vuoi lo **stesso stato**:

- esiste l'utente di servizio app;
- il file /etc/app.conf contiene esattamente version=1.0

Semplice. Lo scriviamo in Bash e lo lanciamo su tutti. Cosa può andare storto?

## Consegna passo-passo

### Fase 0 — Tira su la flotta

    docker run -d --name cap01-server1 debian:12 sleep infinity
    docker run -d --name cap01-server2 debian:12 sleep infinity
    docker run -d --name cap01-server3 debian:12 sleep infinity

Tre server accesi. (Su una macchina vera li raggiungeresti in SSH; qui con
docker exec.)

### Fase 1 — Lo script ingenuo, e la prima crepa

Apri start/provision.sh. Nella sua forma di partenza fa la cosa più naturale del
mondo: per ogni server, crea l'utente e scrive la config.

    for s in "${SERVERS[@]}"; do
      docker exec "$s" useradd app
      docker exec "$s" sh -c 'echo "version=1.0" > /etc/app.conf'
    done

Lancialo:

    bash start/provision.sh

Funziona: tre server configurati. Ora **rilancialo**:

    bash start/provision.sh

    useradd: user 'app' already exists

Lo script si spacca: useradd esce con errore perché l'utente c'è già. **Crepa 1
— non è ripetibile.** Uno script imperativo dà *ordini*, non chiede *com'è la
situazione*: ordina "crea l'utente" anche quando l'utente esiste. Nel mondo reale
questo significa che non puoi rilanciare in sicurezza il tuo script: la seconda
esecuzione è diversa dalla prima.

### Fase 2 — TODO 1: rendilo ripetibile (a mano)

Devi insegnare tu allo script a guardare prima di agire. Completa il **TODO 1**
in provision.sh: metti una guardia su ogni comando, così il secondo giro non
esploda.

- utente: crealo solo se non c'è già —

      docker exec "$s" sh -c 'id -u app >/dev/null 2>&1 || useradd app'

- config: nella forma di partenza il TODO ti fa scrivere una guardia
  **sull'esistenza del file** (è la scelta "ovvia": se il file c'è, non toccarlo) —

      docker exec "$s" sh -c 'test -f /etc/app.conf || echo "version=1.0" > /etc/app.conf'

Rilancia due volte: niente più errori. Sembra risolto. Hai appena riscritto a
mano un pezzo di quello che Ansible fa gratis — e stai per scoprire che l'hai
riscritto **sbagliato**.

### Fase 3 — Il sabotaggio notturno, e la crepa più insidiosa

Qualcuno entra su cap01-server2 e cambia la config a mano (un fix di emergenza,
una svista, non importa):

    docker exec cap01-server2 sh -c 'echo "version=9.9" > /etc/app.conf'

La flotta è ora **divergente**: due server a 1.0, uno a 9.9. È esattamente ciò
che nella realtà accade sempre, e ha un nome: **configuration drift**. Rilancia
il tuo script guardato — quello che "funziona":

    bash start/provision.sh
    docker exec cap01-server2 cat /etc/app.conf

    version=9.9

Il drift **è sopravvissuto**. La tua guardia controllava se il file *esiste*, non
*cosa contiene*: il file c'è, quindi lo script l'ha saltato, lasciando 9.9.
**Crepa 3 — la divergenza è inevitabile**, e uno script ripetibile non basta a
curarla. Qui la lezione centrale del capitolo: **ripetibile non vuol dire
convergente**. Rilanciarlo senza errori è una cosa; riportare la realtà allo
stato voluto è un'altra, molto più difficile.

### Fase 4 — TODO 2: dalla ripetibilità alla convergenza

Completa il **TODO 2**: la guardia sul file non deve chiedere "esisti?" ma "sei
come devi essere?". La forma più semplice che converge sempre è riscrivere lo
stato voluto ad ogni giro (idempotente per costruzione: scrivere version=1.0
mille volte lascia version=1.0):

    docker exec "$s" sh -c 'echo "version=1.0" > /etc/app.conf'

Sabota di nuovo server2, rilancia, e osserva:

    docker exec cap01-server2 cat /etc/app.conf

    version=1.0

Adesso converge: qualunque fosse lo stato di partenza, il server torna a 1.0. Ma
fermati a guardare cosa ti è costato: per **una** riga di config hai dovuto
ragionare su esistenza, contenuto, ripetibilità e convergenza — e riscrivere la
guardia due volte. Moltiplica per ogni pacchetto, file, servizio e permesso di un
server vero. Questo lavoro, fatto bene e per te, è esattamente ciò che chiamiamo
**configuration management** — ed è il mestiere di Ansible.

### Fase 5 — Le crepe che non servono le mani per vedere

Due osservazioni chiudono il quadro, senza altro codice.

**Crepa 2 — passi, non stato.** Rileggi provision.sh: è una lista di *comandi*.
Se un collega ti chiede "che stato dovrebbe avere server2?", non puoi rispondere
leggendo lo script — puoi solo *eseguirlo con la mente*. Uno strumento
dichiarativo rovescia la cosa: gli descrivi lo *stato voluto* e lui calcola i
passi. Lo script dice *come*; Ansible ti farà dire *cosa*.

**Tre, trenta, tremila.** Il tuo for è **seriale** e **push** (tu, dal centro,
spingi comandi verso i server). Con tre server regge. Con tremila: nessun
parallelismo, e se server1743 è irraggiungibile lo script si ferma lì — senza
dirti quali dei precedenti erano già a posto e quali no. Provalo:

    docker stop cap01-server3
    bash start/provision.sh    # osserva dove si ferma e cosa NON ti dice
    docker start cap01-server3

È il salto qualitativo di 1.1: a tremila server servono parallelismo, gestione
degli errori per-host, e un modo di *descrivere* lo stato invece di *ordinarlo*.
È anche la scelta **push contro pull**: qui il centro spinge; nel modello pull
ogni server andrebbe da solo a prendersi la sua configurazione a intervalli.
Ansible è push — e i capitoli seguenti ti daranno tutto ciò che allo script manca.

## Criteri di "fatto"

- Lo script di partenza **fallisce al secondo giro** con l'errore di useradd
  (crepa 1 vista).
- Con le guardie del TODO 1 lo script **si rilancia senza errori**, ma dopo il
  sabotaggio il drift su server2 **sopravvive** con la guardia cieca (crepa 3
  vista).
- Con il TODO 2 (guardia sul contenuto) server2 **torna a version=1.0** dopo il
  sabotaggio (convergenza).
- Sai spiegare a parole tue perché *ripetibile* non è *convergente*, e perché a
  3000 server lo script imperativo non basta.

## Domande di riflessione

**a.** Il tuo script guardato del TODO 1 si rilanciava "senza errori", eppure
lasciava passare il drift. Cosa distingue la *ripetibilità* dalla *convergenza*,
e perché la seconda è quella che conta davvero in produzione?

**b.** Guardando provision.sh, potresti dire a un collega qual è lo *stato voluto*
di un server senza eseguire lo script? Cosa cambierebbe se, invece di una lista
di comandi, avessi una *descrizione* dello stato?

**c.** A tremila server, elenca almeno tre cose che al tuo for seriale mancano.
Poi: in cosa il modello *pull* affronterebbe diversamente il problema del drift
rispetto al *push* di questo script?

## Pulizia

    docker rm -f cap01-server1 cap01-server2 cap01-server3

## Dove porta

Hai toccato con mano le tre crepe. Dal capitolo 6 installerai Ansible; dal 10
scriverai il primo playbook — dove idempotenza e convergenza non le riscrivi a
mano ad ogni riga, ma te le regala il modulo. Questo capitolo è il "prima": il
dolore che giustifica tutto il resto.
