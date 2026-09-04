# Capitolo 23 — Il re di cartone

**Livello:** Cloud Architect

Il confine di rete è chiuso; ora riduci ciò che un processo può fare attraverso il kernel condiviso con l'host.

## Obiettivi

- Ispezionare uid, capabilities, modalità seccomp e scrivibilità del filesystem (23.1, 23.2).
- Applicare un SecurityContext restricted e verificare ogni difesa (23.2, 23.3).
- Applicare i Pod Security Standards a un intero namespace (23.5).

## Prerequisiti

- kubectl disponibile e un cluster raggiungibile con Pod Security admission attivo.
- Capitoli 4 e 22 completati per capabilities, kernel condiviso ed enforcement delle policy.

## Lo scenario

Completa i TODO 1..3 in start/hardened.yaml: identità non-root, riduzione dei privilegi e della superficie
scrivibile, e seccomp RuntimeDefault. run.sh crea il namespace throne e confronta il Pod hardened con king.

    cd kubernetes/ed1/cap23/solution
    ./run.sh

### Fase 1 — Il re senza armatura (23.1, 23.2)

Ispeziona il container predefinito e prova che è uid 0, conserva capabilities, non ha un filtro seccomp
e può scrivere il proprio filesystem root.

### Fase 2 — Togliere la corona (23.2, 23.3)

Applica il SecurityContext completato e verifica utente non-root, capabilities effettive azzerate,
seccomp in modalità filtro e filesystem root in sola lettura.

### Fase 3 — La guardia del namespace (23.5)

Attiva l'enforcement restricted, osserva che l'admission non è retroattivo, rifiuta un nuovo Pod semplice
e ammette quello blindato.

## Criteri di "fatto"

- [ ] I tre TODO sono completi.
- [ ] Ogni difesa sul processo è osservata nel Pod in esecuzione.
- [ ] run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 stabilisce il riferimento insicuro.
- OK 2 verifica gli effetti delle cinque impostazioni del SecurityContext.
- OK 3 prova che l'admission non espelle un Pod esistente.
- OK 4 è il cancello che morde: restricted rifiuta il Pod non corretto.
- OK 5 prova che il Pod corretto supera lo stesso cancello.

## Domande di riflessione

**a.** Perché root nel container è pericoloso col kernel condiviso e quale confine aggiunge ogni impostazione?

**b.** In cosa seccomp differisce da AppArmor o SELinux e cosa offre RuntimeDefault?

**c.** Come differiscono livelli e modalità dei Pod Security Standards e perché warn o audit dovrebbero precedere enforce?

## Pulizia

run.sh elimina il namespace throne e tutti i Pod contenuti, anche in caso di errore.

## Dove porta

Ora sai proteggere i workload singolarmente e all'admission. Il Capitolo 24 impacchetta oggetti coordinati in release.
