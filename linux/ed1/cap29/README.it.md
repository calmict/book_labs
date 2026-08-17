# Cap. 29 — Un firewall minimo, e la prova che filtra dove credi

> Esercizio del **Capitolo 29 — nftables e il firewall** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- costruire un ruleset con policy predefinita drop ed eccezioni esplicite;
- distinguere i percorsi input e forward osservando contatori nominati;
- pubblicare un servizio interno con DNAT;
- riconoscere indirizzo e porta prima e dopo la traduzione.

## Prerequisiti

- Un sistema Linux con Bash, Python 3, iproute2, nftables e conntrack-tools.
- Privilegi amministrativi per creare namespace e veth temporanei.
- Supporto del kernel per forwarding, conntrack, nftables e NAT.

## Consegna

1. Verifica che labcap29, labcap29client e labcap29server non esistano, poi creali. Collega il client al firewall sulla rete 10.29.1.0/24 e il server sulla rete 10.29.2.0/24. labcap29 deve possedere 10.29.1.1 e 10.29.2.1; abilita ip_forward soltanto al suo interno.

2. Leggi start/labcap29.nft. Le chain input, forward e output hanno policy drop. Le sole eccezioni consentono loopback, risposte a connessioni esistenti e il servizio TCP interno sulla porta 8080 proveniente dal lato client.

3. Prima del caricamento mostra il ruleset vuoto di labcap29. Carica il file e mostra subito dopo lo stesso ruleset. Non omettere mai ip netns exec labcap29 da un comando nft:

       sudo ip netns exec labcap29 nft list ruleset
       sudo ip netns exec labcap29 nft -f start/labcap29.nft
       sudo ip netns exec labcap29 nft list ruleset

4. Avvia il servizio in labcap29server su 10.29.2.2:8080. Dal client collegati a 10.29.1.1:18080, cioè l'indirizzo pubblicato sul lato client. Confronta i contatori nominati:

       sudo ip netns exec labcap29 nft list counter inet labcap29filter labcap29_input_seen
       sudo ip netns exec labcap29 nft list counter inet labcap29filter labcap29_forward_web

   Il contatore forward deve crescere, mentre input deve restare a zero: dopo DNAT la decisione di routing inoltra il pacchetto verso il server, non verso un processo locale del firewall.

5. Osserva il log del server e la voce conntrack nel namespace del firewall:

       sudo ip netns exec labcap29 conntrack -L -p tcp

   Il client usa 10.29.1.1:18080, mentre il server accetta la connessione su 10.29.2.2:8080. Questa differenza rende visibile la riscrittura della destinazione. Prova anche 10.29.2.2:9090 e verifica che la policy drop non lo lasci passare.

6. Esegui la soluzione automatica come root. Non eseguire comandi nft nel namespace iniziale della macchina. La cancellazione di labcap29 rimuove anche il suo ruleset:

       sudo ./solution/run.sh

## Criteri di "fatto"

- [ ] Il ruleset ha policy drop ed espone soltanto le eccezioni richieste.
- [ ] Il collegamento pubblicato incrementa labcap29_forward_web ma non labcap29_input_seen.
- [ ] Il servizio è raggiungibile tramite 10.29.1.1:18080 e il server registra 10.29.2.2:8080 come destinazione locale.
- [ ] Un collegamento non autorizzato verso 10.29.2.2:9090 fallisce.
- [ ] I tre namespace, le veth, i processi e il ruleset isolato sono stati rimossi.
