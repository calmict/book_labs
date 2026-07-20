# Capitolo 11 — Il magazzino e la nave leggera

**Livello:** Intermedio

Sai costruire un'immagine; ora impari a costruirla **veloce** e a spedirla
**leggera**. Due tecniche fanno la differenza, e sono due facce dell'ordine. La
prima è la cache: Docker riusa uno strato finché l'istruzione che lo produce e
tutto ciò che sta sotto non cambiano — quindi l'ordine delle istruzioni decide
quanto lavoro rifai a ogni build. La seconda è il Multi-Stage: usi uno stage come
magazzino dove assembli con tutti gli attrezzi, e poi imbarchi sulla nave finale —
leggera — solo la merce finita. In questo laboratorio le combini: metti ciò che
cambia raramente prima di ciò che cambia spesso, e spedisci solo l'artefatto.

## Obiettivi

- Capire come la cache riusa gli strati e perché l'ordine delle istruzioni conta
  (11.1, 11.2).
- Usare un Multi-Stage Build: uno stage di build nominato e uno stage finale
  (11.3).
- Copiare dallo stage di build solo l'artefatto con COPY --from (11.4).
- Ottenere un'immagine finale leggera, priva degli attrezzi di build (11.5).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter
  usare Docker.
- Il capitolo 8 (i layer) e il capitolo 9 (COPY, l'ordine delle istruzioni): qui
  li usi per ottimizzare.

## Lo scenario

In start/ trovi un Dockerfile incompleto, deps.txt (le «dipendenze») e app.txt (la
«sorgente»). Il Dockerfile dovrebbe assemblare in uno stage di build e spedire solo
l'artefatto in uno stage finale leggero, con l'ordine giusto per la cache — ma lo
stage non è nominato, l'artefatto non viene copiato e le dipendenze non sono messe
prima della sorgente. Colmi tre lacune (TODO 1..3). Immagini usa-e-getta, nessun
privilegio, il demone condiviso non si tocca.

Prepara l'ambiente:

    cd docker/ed1/cap11/start

### Fase 1 — Come funziona la cache (11.1, 11.2)

Ogni istruzione è uno strato (capitolo 8); Docker riusa lo strato in cache se
quell'istruzione e tutte quelle sotto sono immutate. Cambiane una e invalidi il suo
strato e tutti quelli sopra, ma non quelli sotto. Da qui la regola: ciò che cambia
raramente (le dipendenze) va prima di ciò che cambia spesso (il tuo codice), così
modificare il codice non rifà l'installazione delle dipendenze.

### Fase 2 — Nominare il magazzino (11.3 — TODO 1)

Apri start/Dockerfile e completa il **TODO 1**: dai un nome allo stage di build,
così lo stage finale potrà pescarne l'artefatto.

    FROM busybox AS build

### Fase 3 — Imbarcare solo la merce finita (11.4 — TODO 2)

Completa il **TODO 2**: nello stage finale, copia dallo stage di build **solo**
l'artefatto — non gli attrezzi, non le dipendenze.

    COPY --from=build /out/app /app

### Fase 4 — Ordinare per la cache (11.2 — TODO 3)

Completa il **TODO 3**: copia e «installa» le dipendenze **prima** di copiare la
sorgente, così quando cambi solo la sorgente il passo costoso resta in cache.

    COPY deps.txt ./deps.txt
    RUN cat deps.txt > /out/deps-installed.txt

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- Lo stage di build è nominato con AS (TODO 1).
- Lo stage finale copia solo l'artefatto con COPY --from (TODO 2).
- Le dipendenze sono copiate e «installate» prima della sorgente (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh costruisce l'immagine e verifica, punto per punto:

- **OK 1** — l'immagine finale contiene l'artefatto: avviandola stampa il
  contenuto costruito dalla sorgente.
- **OK 2** — isolamento Multi-Stage: l'immagine finale NON contiene i file dello
  stage di build (deps.txt, l'artefatto delle dipendenze): è leggera e pulita.
- **OK 3** — cache strategica: modificando solo la sorgente e ricostruendo, il
  passo di installazione delle dipendenze resta CACHED, mentre la sorgente viene
  ricostruita.

## Domande di riflessione

**a.** La cache invalida uno strato e tutti quelli sopra, mai quelli sotto. Perché
allora conviene copiare prima il file delle dipendenze e installarle, e solo dopo
copiare il codice? Cosa succede alla cache se inverti l'ordine, e perché in un
progetto reale questo si traduce in minuti risparmiati a ogni build?

**b.** Nel Multi-Stage lo stage di build contiene compilatori, header, cache di
pacchetti; lo stage finale copia solo l'artefatto. Perché l'immagine finale è più
piccola e più sicura, e cosa NON viene spedito rispetto a un'immagine costruita in
un solo stage? Come si lega questo ai layer content-addressed del capitolo 8?

**c.** COPY --from può pescare da uno stage nominato ma anche da un'immagine
esterna. In che modo il Multi-Stage separa «come si costruisce» da «cosa gira in
produzione», e perché questo è un ponte verso le immagini di produzione del
capitolo 12?

## Pulizia

Niente da smontare a mano: le immagini di prova sono rimosse dallo script (docker
rmi, più un trap di sicurezza) a fine esecuzione; il test lavora in una cartella
temporanea che ripulisce da sé. L'immagine base busybox resta in cache (condivisa).
Nessun container persistente, il demone non viene mai riavviato.

## Dove porta

Hai reso la build veloce e l'immagine leggera. Il **capitolo 12** chiude la Parte 3
portando l'idea fino in fondo: immagini di produzione piccole, senza root e con la
minima superficie d'attacco — utente non privilegiato, base minimale, niente
attrezzi di troppo. Per il riferimento delle istruzioni, vedi le appendici del
volume.
