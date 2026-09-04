# Capitolo 22 — La cassaforte e il corridoio

**Livello:** Avanzato

RBAC ha chiuso il confine dell'API; ora chiudi i percorsi tra i workload con un contratto di rete.

## Obiettivi

- Osservare il default allow e invertirlo con un default deny (22.1, 22.2).
- Ammettere solo un client etichettato sulla porta TCP 8080 (22.3).
- Negare l'egress e verificare che il CNI applichi la policy (22.3, 22.4).

## Prerequisiti

- Capitoli 18 e 21 completati, kubectl disponibile e un cluster raggiungibile.
- Un CNI che supporti NetworkPolicy. run.sh misura l'enforcement prima di fidarsene.

## Lo scenario

Completa i TODO 1..3 in start/: default deny ingress, eccezione per label e deny egress.
Il test crea il namespace vault e tre Pod: safe, app e guest.

    cd kubernetes/ed1/cap22/solution
    ./run.sh

### Fase 1 — Il corridoio aperto (22.1, 22.2)

Entrambi i client raggiungono la cassaforte prima delle policy. L'insieme vuoto di permessi ingress deve poi bloccarli.

### Fase 2 — La porta con la targhetta (22.3)

L'eccezione additiva ammette role=app solo su TCP 8080; il guest senza label resta fuori.

### Fase 3 — Nessuna chiamata dalla cassaforte (22.3, 22.4)

La policy egress blocca una chiamata per IP grezzo da safe, senza confondere il percorso verificato con il DNS.

## Criteri di "fatto"

- [ ] I tre TODO sono completi.
- [ ] Default allow, deny ingress, allow per label e deny egress si comportano come descritto.
- [ ] run.sh stampa OK 1..4 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 prova il default allow con due richieste riuscite.
- OK 2 è il primo cancello: il default deny blocca entrambi e prova l'enforcement del CNI.
- OK 3 prova l'eccezione per label e porta mantenendo il deny del guest.
- OK 4 è il secondo cancello: safe non può iniziare la richiesta in uscita.

## Domande di riflessione

**a.** Perché una rete piatta è rischiosa, cosa seleziona un podSelector vuoto e perché le policy sono additive?

**b.** Chi può parlare con chi, su quale porta, e come cambierebbe il contratto rietichettando guest?

**c.** Chi trasforma NetworkPolicy in filtri reali e perché nelle policy egress reali va considerato il DNS?

## Pulizia

run.sh elimina il namespace vault e tutti i suoi oggetti, anche in caso di errore.

## Dove porta

Il confine di rete è chiuso. Il Capitolo 23 restringe ciò che ogni container può chiedere al kernel condiviso.
