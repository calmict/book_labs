# Cap. 26 — Vedere quello che nessuno ti dice

> Esercizio del **Capitolo 26 — System call, procfs e sysfs: guardare dentro** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- usare strace per trovare la system call che spiega un errore taciuto dal programma;
- riconoscere il buffering di stdio quando stdout è collegato a una pipe e correggerlo;
- leggere e modificare un sysctl di rete in un namespace isolato;
- distinguere una modifica immediata da una configurazione caricata all'avvio.

## Prerequisiti

- Un sistema Linux con Bash, Python 3, strace, iproute2 e procps.
- Privilegi amministrativi per creare il namespace di rete labcap26.
- Una macchina di prova riavviabile, solo per la verifica facoltativa della persistenza.

## Consegna

1. Entra nella directory start e avvia silent_failure.py indicando un file inesistente. Il programma termina con stato 1 senza stampare una diagnosi. Eseguilo di nuovo sotto strace, limita la traccia a openat e salvala in un file:

       python3 silent_failure.py /tmp/labcap26-missing.conf
       strace -f -e trace=openat -o /tmp/labcap26-strace.log \
         python3 silent_failure.py /tmp/labcap26-missing.conf
       grep 'labcap26-missing.conf' /tmp/labcap26-strace.log

   Annota la system call fallita, il valore di ritorno e il codice di errore.

2. Collega buffered_writer.py a una pipe che scrive in un file. Mentre il programma è ancora in pausa, controlla la dimensione del file. Ripeti con l'opzione -u di Python:

       python3 buffered_writer.py | cat > /tmp/labcap26-buffered.out &
       sleep 0.2
       wc -c < /tmp/labcap26-buffered.out
       wait

       python3 -u buffered_writer.py | cat > /tmp/labcap26-unbuffered.out &
       sleep 0.2
       wc -c < /tmp/labcap26-unbuffered.out
       wait

   Spiega perché la prima riga rimane nel buffer quando stdout non è un terminale. Prova anche una correzione nel sorgente con flush=True.

3. Crea il namespace labcap26, leggi net.ipv4.ip_forward, impostalo a 0 e poi a 1, verificando ogni valore. Non eseguire questi comandi nel namespace di rete dell'host:

       sudo ip netns add labcap26
       sudo ip netns exec labcap26 sysctl -w net.ipv4.ip_forward=0
       sudo ip netns exec labcap26 sysctl -n net.ipv4.ip_forward
       sudo ip netns exec labcap26 sysctl -w net.ipv4.ip_forward=1
       sudo ip netns exec labcap26 sysctl -n net.ipv4.ip_forward
       sudo ip netns del labcap26

4. Studia solution/99-labcap26.conf. Su una tua macchina di prova, non su un sistema condiviso, un file con quel contenuto installato come /etc/sysctl.d/99-labcap26.conf viene caricato durante l'avvio. Per la prova completa, installalo, riavvia la macchina di prova e verifica con:

       sysctl -n net.ipv4.ip_forward

   Il file dimostra il meccanismo di persistenza, ma non viene installato da alcuno script di questo laboratorio. Un file in /etc/sysctl.d appartiene al namespace iniziale della macchina; non sarebbe una prova sicura dentro un namespace temporaneo.

5. Esegui la soluzione automatica. Se non sei root, usa sudo. Lo script rimuove sempre namespace, processi e file temporanei:

       sudo ./solution/run.sh

## Criteri di "fatto"

- [ ] La traccia mostra openat con risultato -1 ENOENT per il file mancante.
- [ ] Hai osservato zero byte durante l'esecuzione bufferizzata e dati già visibili con output non bufferizzato.
- [ ] Hai verificato i valori 0 e 1 del sysctl esclusivamente dentro labcap26.
- [ ] Sai spiegare il ruolo del file in /etc/sysctl.d e hai eseguito l'eventuale prova di riavvio solo su una macchina sacrificabile.
- [ ] Il namespace labcap26 e i file temporanei sono stati rimossi.
