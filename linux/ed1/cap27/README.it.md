# Cap. 27 — Seguire un pacchetto

> Esercizio del **Capitolo 27 — Lo stack TCP/IP dentro il kernel** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- leggere la distribuzione per CPU delle interruzioni associate alla rete;
- provocare e riconoscere lo scarto dovuto al buffer di ricezione di una singola socket UDP;
- distinguere lo scarto della socket da quello registrato sull'interfaccia;
- riempire una tabella conntrack isolata e riconoscere contatore e sintomo applicativo.

## Prerequisiti

- Un sistema Linux con Bash, Python 3, iproute2, procps, nftables e conntrack-tools.
- Privilegi amministrativi per creare il namespace labcap27.
- Il modulo nf_conntrack disponibile nel kernel.

## Consegna

1. Leggi /proc/interrupts senza modificarlo. Trova le righe riconducibili alle interfacce di rete e confronta i contatori sotto CPU0, CPU1 e le CPU successive. Se la macchina non espone interruzioni di rete nominate, documenta il risultato invece di inventarlo:

       head -n 1 /proc/interrupts
       grep -Ei 'eth|enp|eno|ens|virtio|mlx|ixgbe|network' /proc/interrupts

2. Crea il namespace e attiva loopback. Tutto il traffico dei passi successivi deve rimanere in labcap27:

       sudo ip netns add labcap27
       sudo ip -n labcap27 link set lo up

3. Avvia socket_pressure.py come ricevitore nel namespace. Il programma richiede un buffer UDP piccolo e attende prima di leggere. Durante l'attesa invia una raffica con lo stesso programma in modalità send. Confronta prima e dopo Udp RcvbufErrors in /proc/net/snmp, il campo d mostrato da ss -u -a -m e RX dropped di loopback:

       sudo ip netns exec labcap27 python3 start/socket_pressure.py receive 27270 &
       sleep 0.1
       sudo ip netns exec labcap27 python3 start/socket_pressure.py send 27270 50000
       sudo ip netns exec labcap27 ss -u -a -n -m
       sudo ip -n labcap27 -s link show lo
       wait

   RcvbufErrors e il contatore della socket identificano una coda di ricezione piena. RX dropped dell'interfaccia descrive invece uno scarto a un altro livello del sistema.

4. Attiva il tracciamento con una tabella nft innocua e una chain output con policy accept, porta nf_conntrack_max a 128 soltanto nel namespace e genera più flussi UDP distinti del limite. Confronta nf_conntrack_count, conntrack -C e conntrack -S prima e dopo. Il contatore insert_failed crescente e un numero di datagrammi ricevuti inferiore a quelli inviati sono il sintomo della tabella piena.

5. Esegui la soluzione automatica come root. Lo script rifiuta un namespace preesistente e lo elimina sempre alla fine:

       sudo ./solution/run.sh

## Criteri di "fatto"

- [ ] Hai riportato i contatori per CPU di almeno una sorgente di interruzioni di rete, oppure hai documentato che l'ambiente non ne espone.
- [ ] Hai fatto crescere Udp RcvbufErrors e i drop della socket senza attribuirli erroneamente a RX dropped dell'interfaccia.
- [ ] Hai osservato nf_conntrack_count vicino al limite e insert_failed maggiore del valore iniziale.
- [ ] Hai collegato la pressione conntrack a una perdita osservabile dal ricevitore.
- [ ] labcap27, la sua tabella nft e ogni processo di prova sono stati rimossi.
