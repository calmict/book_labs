# Cap. 6 — Collega due network namespace a mano (veth, bridge e un ping)

> Esercizio del **Capitolo 6 — Networking Linux dalle fondamenta** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- creare network namespace, cavi virtuali (veth) e uno switch virtuale (bridge), e cablarli come farebbe un container runtime;
- seguire un ping che attraversa il tuo switch e leggerne le prove (tabella ARP, inoltro del bridge);
- riconoscere in docker0 lo stesso identico schema che hai appena costruito a mano.

## Prerequisiti

- Aver completato i cap. 1-5 (in particolare il cap. 2: qui il network namespace smette di essere un vicolo cieco e diventa una rete).
- Un host Linux con iproute2 (comando ip) e privilegi sudo.
- Docker serve solo per il confronto finale del passo 6.

> 💡 **Niente sudo?** L'intero laboratorio funziona anche da utente normale,
> dentro uno user namespace:
>
>     unshare -Urnm
>     mount -t tmpfs tmpfs /run
>
> e da lì in poi tutti i comandi della consegna senza sudo. Bonus di sicurezza:
> lavori in una rete-giocattolo del tutto separata da quella vera — impossibile
> rompere qualcosa. Uscendo dalla shell sparisce tutto da solo (salta pure il
> passo 7).

## Consegna

1. Crea i due "computer" (namespace di rete) e guarda dove vivono:

       sudo ip netns add blue
       sudo ip netns add red
       ip netns list
       ls /run/netns

   I file in /run/netns sono maniglie sugli stessi oggetti namespace che hai incontrato nel cap. 2 sotto /proc/[pid]/ns.

2. Guarda dentro un namespace appena nato:

       sudo ip netns exec blue ip addr

   Solo una loopback spenta: è la stessa desolazione che vedevi dal container del cap. 2 — ora sai da dove viene.

3. Costruisci lo switch (bridge) e i due cavi (veth pair): ogni cavo ha due estremità, una va infilata nel suo namespace e l'altra nello switch:

       sudo ip link add br-lab type bridge
       sudo ip link set br-lab up
       sudo ip link add veth-blue type veth peer name veth-blue-br
       sudo ip link set veth-blue netns blue
       sudo ip link set veth-blue-br master br-lab up
       sudo ip link add veth-red type veth peer name veth-red-br
       sudo ip link set veth-red netns red
       sudo ip link set veth-red-br master br-lab up

4. Dai un indirizzo a ciascuna estremità interna e accendi tutto:

       sudo ip netns exec blue ip addr add 10.42.0.2/24 dev veth-blue
       sudo ip netns exec blue ip link set veth-blue up
       sudo ip netns exec blue ip link set lo up
       sudo ip netns exec red ip addr add 10.42.0.3/24 dev veth-red
       sudo ip netns exec red ip link set veth-red up
       sudo ip netns exec red ip link set lo up

5. Il momento della verità:

       sudo ip netns exec blue ping -c 3 10.42.0.3

   Se il primo pacchetto va perso non è un errore: è l'ARP che sta imparando gli indirizzi. Poi raccogli le prove del viaggio — il MAC del vicino imparato da blue e le porte su cui il bridge ha imparato a inoltrare:

       sudo ip netns exec blue ip neigh
       sudo bridge fdb show br br-lab

6. Il déjà vu finale: guarda la rete di Docker con gli stessi occhiali.

       ip addr show docker0
       docker run -d --name lab-cap06 alpine:3 sleep infinity
       ip link show master docker0

   È comparso un veth attaccato a docker0: bridge + cavi veth, esattamente lo schema che hai appena costruito, solo con nomi meno leggibili. Rimuovi il container: docker rm -f lab-cap06.

   Le tre domande per answers.md: (a) perché un veth ha DUE estremità, e perché una sta nel namespace e l'altra sul bridge? (b) descrivi il viaggio del ping (veth-blue → br-lab → veth-red e ritorno) e spiega cosa raccontano ip neigh e la fdb del bridge; (c) il namespace blue può pingare red ma non internet: cosa gli manca? (rifletti su default route e NAT — è l'argomento del §6.2 del manuale).

7. Smonta il laboratorio:

       sudo ip netns del blue
       sudo ip netns del red
       sudo ip link del br-lab

   (le estremità veth spariscono da sole: metà stavano nei namespace cancellati, e l'altra metà muore quando muore il compagno di coppia)

## Criteri di "fatto"

- [ ] Il ping da blue a red risponde attraverso il bridge.
- [ ] ip neigh dentro blue mostra il MAC di red, e la fdb di br-lab mostra su quali porte ha imparato gli indirizzi.
- [ ] Hai riconosciuto lo schema bridge+veth in docker0 (o hai fatto tutto nella variante rootless).
- [ ] answers.md risponde alle tre domande.
- [ ] Namespace e bridge rimossi, nessuna interfaccia veth orfana (ip link | grep veth non mostra le tue).
