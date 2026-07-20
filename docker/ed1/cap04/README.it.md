# Capitolo 4 — L'overlay a mani nude

**Livello:** Intermedio

Ci resta un'ultima illusione da smontare, la più convincente: quando entri in un container e digiti ls,
vedi bin, etc, usr — sembra un'altra installazione Linux. Nel capitolo 2 hai intuito il come (un MNT
namespace con una radice diversa); qui monti a mano il pezzo che rende la cosa *efficiente*: il
Copy-on-Write con OverlayFS. Impilerai layer in sola lettura, ci scriverai sopra, e vedrai la magia —
si copia una sola pagina, solo quando la scrivi. Tutto rootless, dentro i namespace del capitolo 2.

## Obiettivi

- Montare un OverlayFS a mano: due lowerdir in sola lettura più un upperdir scrivibile (4.2, 4.3).
- Dimostrare il Copy-on-Write: scrivere un file "di sola lettura" lascia il lower intatto e copia
  nell'upper (4.3).
- Vedere che i lower condivisi rendono due container quasi gratuiti, con upper privati (4.4).
- Chiudere il cerchio del capitolo 2: l'overlay come radice dentro un MNT namespace (4.3).

## Prerequisiti

- Un Linux con OverlayFS nel kernel (standard) e unshare (util-linux): nessun Docker richiesto.
- Nessun root: montiamo dentro un USER + MNT namespace (i namespace del capitolo 2), che su kernel
  recenti permette il mount overlay senza sudo.
- Il MNT namespace del capitolo 2 e i cgroup del capitolo 3 come contesto: qui aggiungiamo lo storage.

## Lo scenario

In start/ trovi overlay.sh: uno script che dovrebbe montare un overlay e dimostrare il Copy-on-Write, ma
non monta nulla. Colmi tre lacune (TODO 1..3) perché l'overlay esista, il CoW si veda e due container
restino isolati.

Prepara l'ambiente:

    cd docker/ed1/cap04/start

### Fase 1 — Condividere senza copiare (4.1)

Cento container partono dalla stessa immagine di Ubuntu. Copiarla cento volte sprecherebbe disco. Serve
condividere tutto ciò che non cambia e copiare solo ciò che viene modificato: è il Copy-on-Write. Qui lo
costruisci con le tue mani, senza Docker.

### Fase 2 — Montare l'overlay (4.3 — TODO 1)

Apri start/overlay.sh e completa il **TODO 1**: monta container A — un overlay di due lower in sola
lettura (medio sopra basso) più un upper scrivibile —

    mount -t overlay overlay \
      -o lowerdir="$LAB/medio":"$LAB/basso",upperdir="$LAB/upperA",workdir="$LAB/workA" \
      "$LAB/mergedA"

Poi registra la vista fusa (merged_files): mergedA mostra a.txt (dal basso) e b.txt (dal medio), fusi.

### Fase 3 — La magia del Copy-on-Write (4.3 — TODO 2)

Completa il **TODO 2**: scrivi su a.txt in mergedA — ma a.txt vive nel lower in sola lettura. Registra
che il lower è intatto e che la modifica è finita nell'upper.

    echo "modificato dal container A" > "$LAB/mergedA/a.txt"

Il file originale in basso/a.txt non è toccato; upperA/a.txt contiene la "fotocopia" modificata.

### Fase 4 — Due container, upper privati (4.4 — TODO 3)

Completa il **TODO 3**: monta container B con gli *stessi* lower ma un upper diverso (upperB/workB in
mergedB), e registra cosa vede B per a.txt. Deve vedere l'originale, non la modifica di A: i lower sono
condivisi, gli upper privati.

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- overlay.sh monta container A e registra la vista fusa (TODO 1).
- Scrivendo su a.txt, il lower resta intatto e la modifica è nell'upper (TODO 2).
- Container B, con upper diverso, vede l'originale (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh monta l'overlay a mano e verifica, punto per punto:

- **OK 1** — la vista merged fonde i file di entrambi i lower (a.txt e b.txt).
- **OK 2** — Copy-on-Write: il lower è intatto, la modifica vive nell'upper.
- **OK 3** — un secondo container sugli stessi lower è isolato: vede l'originale, non la scrittura di A.

## Domande di riflessione

**a.** Perché il lower resta intatto quando scrivi su un file che gli appartiene? Descrivi cosa fa
OverlayFS al momento della scrittura, e perché questo è esattamente ciò che permette a un'immagine da un
gigabyte di far partire cento container quasi senza occupare disco in più.

**b.** Due container sugli stessi lower non si vedono a vicenda. Spiega, con i termini lowerdir e
upperdir, perché la modifica di A non arriva a B. A quale isolamento del capitolo 2 corrisponde, sul
piano dello storage?

**c.** Ciò che scrivi finisce nell'upper, che è costoso e volatile. Perché "costoso" e perché "volatile"?
E come da questa proprietà discendono due discipline del resto del libro — la cache dei layer (capitolo
11) e i volumi (parte 4)?

## Pulizia

Niente da smontare: l'overlay è montato dentro un MNT namespace che sparisce con lo script, portando via
i mount da solo, e le cartelle di lavoro sono in una directory temporanea che il test ripulisce. Nessun
container Docker, nessun mount lasciato sull'host.

## Dove porta

La teoria è chiusa, e non è più teoria: l'hai azionata con le mani. Un container è un processo (cap1); i
namespace decidono cosa vede (cap2); i cgroup quanto consuma (cap3); il Copy-on-Write come vede il
filesystem senza sprecare disco (cap4). Il **capitolo 5** apre il cofano dello strumento: il modello
client-server e la catena dockerd, containerd, shim, runc — che aziona in automatico proprio ciò che qui
hai montato a mano. Per il riferimento rapido, vedi le appendici del volume.
