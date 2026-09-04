# Capitolo 6 — Collega due network namespace a mano

**Livello:** Fondamentale

I namespace del capitolo 2 erano stanze chiuse. Ora posi i cavi: due veth e un bridge trasformano due
viste di rete isolate in una piccola rete, senza mai modificare quella dell'host.

## Obiettivi

- Creare namespace, veth pair e un bridge come farebbe un runtime (6.1).
- Seguire un ping e leggere la risoluzione ARP nella tabella dei vicini (6.1).
- Leggere nella FDB il forwarding appreso dal bridge (6.1).

## Prerequisiti

- Un host Linux con Docker, unshare, mount, ip, bridge e ping.
- User namespace non privilegiati abilitati; non serve sudo.
- Il test monta una directory /run privata e non cambia la rete dell'host.

## Lo scenario

In start/network-lab.sh nascono blue e red, ma mancano switch, cablaggio e prove. Lo script deve essere
eseguito nella rete giocattolo preparata dal verificatore.

    cd kubernetes/ed1/cap06/start

### Fase 1 — Lo switch e i cavi (6.1 — TODO 1)

Crea br-lab e due veth pair. Sposta veth-blue e veth-red nei rispettivi namespace; collega i peer
veth-blue-br e veth-red-br al bridge e attivali.

### Fase 2 — Indirizzi e link (6.1 — TODO 2)

Assegna 10.42.0.2/24 a blue e 10.42.0.3/24 a red. Attiva le due interfacce e le loopback: un indirizzo
su un link spento non trasporta traffico.

### Fase 3 — Le tracce del viaggio (6.1 — TODO 3)

Invia tre echo request da blue a red. Salva il risultato, ip neigh di blue e bridge fdb di br-lab.
Avvia poi un container Docker temporaneo e riconosci su docker0 lo stesso schema bridge più veth:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- Il ping attraversa il bridge senza perdita finale.
- La tabella dei vicini e la FDB contengono il MAC di red.
- Entrambi i peer esterni sono porte di br-lab.
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 controlla il ping da blue a red.
- OK 2 correla il MAC appreso via ARP con la FDB del bridge.
- OK 3 controlla i peer di br-lab e riconosce lo stesso schema bridge più veth su docker0.
- OK 4 è il cancello: lasciando spento veth-red, il ping deve fallire.
- OK 5 conferma che nessun oggetto della rete giocattolo è sfuggito nell'host.

## Domande di riflessione

**a.** Perché un veth ha due estremità, una nel namespace e una sul bridge?

**b.** Qual è il viaggio del ping e che cosa ricordano la tabella dei vicini e la FDB?

**c.** Perché blue raggiunge red ma non internet? Quali ruoli hanno route predefinita e NAT (6.2)?

## Pulizia

Ogni esecuzione vive in uno user e network namespace usa-e-getta. Il trap interno cancella namespace e
bridge; la fine di unshare elimina comunque l'intera rete giocattolo.

## Dove porta

Hai cablato a mano ciò che un runtime ripete per ogni container. La parte successiva porta questi
meccanismi nel cluster, dove Kubernetes delega il cablaggio ai plugin di rete.
