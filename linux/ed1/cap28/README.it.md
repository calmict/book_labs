# Cap. 28 — Costruire una rete con le proprie mani

> Esercizio del **Capitolo 28 — Interfacce, indirizzi, routing e socket** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- creare namespace di rete e spostare al loro interno le estremità di una coppia veth;
- configurare indirizzi e verificare la connettività tra due stack di rete isolati;
- costruire un segmento Ethernet con un bridge e tre endpoint;
- usare ip route get per prevedere interfaccia e indirizzo sorgente scelti dal kernel.

## Prerequisiti

- Un sistema Linux con Bash, iproute2, bridge e ping.
- Privilegi amministrativi per creare namespace, veth e bridge temporanei.
- Nessuna interfaccia esistente con un nome che inizi per labcap28.

## Consegna

1. Verifica prima di creare qualsiasi oggetto che i nomi scelti non esistano. Non riutilizzare un oggetto trovato:

       ip link show labcap28a0
       ip link show labcap28b0
       ip link show labcap28br
       ip netns list

2. Crea labcap28a e labcap28b, collegali con la coppia veth labcap28a0 e labcap28b0, assegna 10.28.1.1/30 e 10.28.1.2/30 e attiva le interfacce. Prima del ping, chiedi al kernel quale percorso userà:

       sudo ip netns exec labcap28a ip route get 10.28.1.2
       sudo ip netns exec labcap28a ping -c 2 -W 1 10.28.1.2

   Il risultato previsto contiene dev labcap28a0 e src 10.28.1.1.

3. Elimina il collegamento diretto. Crea labcap28c e labcap28fabric. Dentro labcap28fabric crea il bridge labcap28br. Collega ciascuno dei tre endpoint al bridge con una coppia veth dal nome prefissato labcap28. Configura gli endpoint con 10.28.2.11/24, 10.28.2.12/24 e 10.28.2.13/24.

4. Ispeziona bridge e forwarding database, quindi interroga il routing prima di generare traffico:

       sudo ip netns exec labcap28fabric bridge link show
       sudo ip netns exec labcap28fabric bridge fdb show br labcap28br
       sudo ip netns exec labcap28a ip route get 10.28.2.13
       sudo ip netns exec labcap28a ping -c 2 -W 1 10.28.2.13
       sudo ip netns exec labcap28c ping -c 2 -W 1 10.28.2.12

   Confronta la previsione di ip route get con interfaccia e sorgente effettivamente usate. Questa topologia riproduce il segmento che un runtime di container crea automaticamente.

5. Esegui la soluzione automatica come root. La cancellazione dei namespace elimina anche bridge e veth; lo script controlla inoltre gli eventuali estremi rimasti sull'host:

       sudo ./solution/run.sh

## Criteri di "fatto"

- [ ] I nomi labcap28 sono stati controllati prima della creazione.
- [ ] labcap28a raggiunge labcap28b sulla coppia veth diretta.
- [ ] Tre endpoint raggiungono gli altri attraverso labcap28br.
- [ ] Le decisioni mostrate da ip route get coincidono con i test di connettività.
- [ ] Tutti i namespace, il bridge e tutte le veth labcap28 sono stati rimossi.
