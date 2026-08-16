# Cap. 11 — Vedere lo scheduler decidere

> Esercizio del **Capitolo 11 — Lo scheduler: chi gira, e per quanto** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- osservare come più processi CPU-bound si dividono una quota limitata di CPU;
- misurare l'effetto di nice sulla CPU e distinguerlo dalla priorità delle operazioni di I/O;
- riconoscere un carico alto con CPU quasi scariche leggendo insieme load average, processi eseguibili e utilizzo CPU.

## Prerequisiti

- Un host Linux con Bash, Docker funzionante e permesso di avviare container.
- L'immagine alpine:3.20 disponibile localmente oppure accesso per scaricarla.
- Familiarità con ps, nice, dd, /proc/loadavg e docker stats.

Tutti i carichi sono confinati in container effimeri con quota CPU, limite di memoria, limite di processi e durata esplicita. Non eseguire i generatori di carico direttamente sull'host.

## Consegna

1. Copia start/container_lab.sh in una directory di lavoro e completa le quattro modalità. Ogni modalità deve fermare i processi in background anche in caso di errore o segnale.

2. Avvia quattro processi CPU-bound in un container limitato a due CPU e misura, dopo quattro secondi, i tick CPU accumulati da ciascuno:

       timeout --signal=TERM --kill-after=2s 15s docker run --rm \
         --name labcap11-cpu --cpus=2 --memory=128m --pids-limit=64 \
         --network none -v "$PWD/container_lab.sh:/lab/container_lab.sh:ro" \
         alpine:3.20 sh /lab/container_lab.sh cpu

   I valori non saranno identici, ma devono mostrare che i quattro processi hanno ricevuto porzioni confrontabili delle sole due CPU disponibili.

3. Ripeti il carico CPU su una sola CPU, assegnando nice 0 a un processo e nice 15 all'altro. Confronta i tick accumulati:

       timeout --signal=TERM --kill-after=2s 15s docker run --rm \
         --name labcap11-nice --cpus=1 --memory=128m --pids-limit=64 \
         --network none -v "$PWD/container_lab.sh:/lab/container_lab.sh:ro" \
         alpine:3.20 sh /lab/container_lab.sh nicecpu

   In presenza di contesa CPU, il processo con nice 0 deve ricevere sensibilmente più tempo di quello con nice 15.

4. Avvia in parallelo due scritture dd identiche, una con nice 0 e una con nice 15, esclusivamente su file interni al container:

       timeout --signal=TERM --kill-after=2s 20s docker run --rm \
         --name labcap11-io --cpus=2 --memory=192m --pids-limit=64 \
         --network none -v "$PWD/container_lab.sh:/lab/container_lab.sh:ro" \
         alpine:3.20 sh /lab/container_lab.sh io

   Confronta tempi e velocità. Non aspettarti un ordine stabile: nice regola la contesa CPU, non assegna direttamente la priorità I/O. Il risultato dipende anche dallo scheduler I/O, dal filesystem, dalla cache e dallo storage sottostante. Annota lo scheduler dei dispositivi dell'host leggendo i file queue/scheduler sotto /sys/block.

5. Avvia dodici processi eseguibili in un container limitato a un quarto di CPU. Il limite lascia quasi tutte le CPU dell'host libere, mentre i processi in attesa fanno salire il carico:

       docker run -d --rm --name labcap11-load --cpus=0.25 --memory=128m \
         --pids-limit=64 --network none \
         -v "$PWD/container_lab.sh:/lab/container_lab.sh:ro" \
         alpine:3.20 sh /lab/container_lab.sh load
       sleep 5
       docker exec labcap11-load cat /proc/loadavg
       docker stats --no-stream labcap11-load
       timeout --signal=TERM --kill-after=2s 15s docker wait labcap11-load

   Leggi insieme il numero di processi eseguibili in /proc/loadavg e la percentuale CPU limitata mostrata da docker stats. Un load elevato non equivale automaticamente a tutte le CPU fisiche occupate.

6. Rimuovi gli eventuali container rimasti e registra misure e interpretazione in observations.md:

       docker rm -f labcap11-cpu labcap11-nice labcap11-io labcap11-load

   La soluzione automatizza l'intera prova:

       ./solution/run.sh

## Criteri di "fatto"

- [ ] Ogni comando docker run contiene un limite --cpus esplicito e termina entro pochi secondi.
- [ ] Hai osservato quattro processi dividersi due CPU e registrato i tick di ciascuno.
- [ ] Sotto contesa CPU, il processo con nice 0 ha accumulato più tick di quello con nice 15.
- [ ] Il confronto dd documenta che nice da solo non garantisce la priorità I/O e identifica le altre variabili rilevanti.
- [ ] Hai riconosciuto molti processi eseguibili insieme a un utilizzo CPU confinato a circa un quarto di core.
- [ ] Nessun container labcap11 è rimasto in esecuzione.
