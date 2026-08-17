# Cap. 27 — Seguire un pacchetto

> Esercizio del **Capitolo 27 — Lo stack TCP/IP dentro il kernel** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- leggere la distribuzione per CPU delle interruzioni associate alla rete;
- provocare e riconoscere lo scarto dovuto al buffer di ricezione di una singola socket UDP;
- distinguere lo scarto della socket da quello registrato sull'interfaccia;
- verificare se net.netfilter.nf_conntrack_max è davvero isolato per namespace, e riconoscere il sintomo quando non lo è.

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

4. Attiva il tracciamento con una tabella nft innocua e una chain output con policy accept. Prova a portare nf_conntrack_max a 128 scrivendolo dentro labcap27, poi rileggi lo stesso valore sia da dentro il namespace sia dal namespace iniziale, prima di generare più flussi UDP distinti di quanti il presunto limite ne permetterebbe. A differenza di net.ipv4.ip_forward nel capitolo 26, net.netfilter.nf_conntrack_max compare in ogni namespace ma resta un'unica variabile del kernel: la scrittura dentro labcap27 non produce errore, ma non cambia nulla, e i 512 flussi vengono tracciati tutti senza perdita.

5. Esegui la soluzione automatica come root. Lo script rifiuta un namespace preesistente e lo elimina sempre alla fine:

       sudo ./solution/run.sh

## Criteri di "fatto"

- [ ] Hai riportato i contatori per CPU di almeno una sorgente di interruzioni di rete, oppure hai documentato che l'ambiente non ne espone.
- [ ] Hai fatto crescere Udp RcvbufErrors e i drop della socket senza attribuirli erroneamente a RX dropped dell'interfaccia.
- [ ] Hai riletto nf_conntrack_max sia dentro labcap27 sia dal namespace iniziale dopo averlo scritto a 128 nel namespace, e hai verificato che il valore non è cambiato.
- [ ] Hai verificato che tutti i flussi UDP inviati risultano tracciati e ricevuti, coerente con l'assenza di un tetto realmente applicato.
- [ ] Hai annotato perché nf_conntrack_max non è isolato per-namespace su questo kernel, a differenza di net.ipv4.ip_forward.
- [ ] labcap27, la sua tabella nft e ogni processo di prova sono stati rimossi.
