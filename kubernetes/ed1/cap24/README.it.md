# Capitolo 24 — Lo stampo e le colate

**Livello:** Cloud Architect

Hai coordinato a mano gli oggetti Kubernetes; ora un chart trasforma la loro forma comune in una release versionata.

## Obiettivi

- Confrontare manifest statici ripetuti con un chart riutilizzabile (24.1).
- Renderizzare template con dati della release e values (24.2).
- Installare, aggiornare, ispezionare e ripristinare una release (24.3, 24.4).

## Prerequisiti

- kubectl e helm disponibili, con un cluster raggiungibile.
- Capitolo 15 completato e familiarità con Deployment, Service e ConfigMap.

## Lo scenario

Confronta start/plain.yaml con il chart, poi completa i TODO 1..3: nomi derivati dalla release,
impostazioni guidate dai values e checksum della configurazione per rendere deterministico il rollout.

    cd kubernetes/ed1/cap24/solution
    ./run.sh

### Fase 1 — Costruire lo stampo (24.1, 24.2)

helm lint e helm template devono trasformare chart e valori predefiniti in manifest concreti senza toccare il cluster.

### Fase 2 — Due colate numerate (24.3)

Installa la revisione 1, poi aggiorna repliche e messaggio. Il checksum cambia il Pod template e causa un rollout reale.

### Fase 3 — Tornare alla colata precedente (24.3, 24.4)

Ripristina la revisione 1 e ispeziona le tre revisioni conservate come Secret nel namespace della release.

## Criteri di "fatto"

- [ ] I tre TODO sono completi e il chart viene renderizzato senza errori.
- [ ] L'upgrade cambia repliche e messaggio attraverso un rollout deterministico dei Pod.
- [ ] Il rollback ripristina la revisione uno e conserva tre voci di cronologia.
- [ ] run.sh stampa OK 1..4 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 verifica lint e rendering predefinito.
- OK 2 verifica stato installato e contenuto servito dalla revisione 1.
- OK 3 è il cancello che morde: il cambio di checksum sostituisce il vecchio Pod nella revisione 2.
- OK 4 verifica rollback coordinato e tre Secret di revisione memorizzati.

## Domande di riflessione

**a.** Cosa appartiene a template, values e dati della release e cosa mostra helm template prima dell'installazione?

**b.** Cosa sono release e revisioni e perché checksum/config causa un rollout mentre la sola modifica della ConfigMap no?

**c.** Cos'è un repository di chart e quando costruiresti un chart invece di installarne uno esistente?

## Pulizia

run.sh disinstalla greeter ed elimina il namespace helmlab, anche in caso di errore.

## Dove porta

Helm dà alla piattaforma pacchetti versionati. I prossimi capitoli installano e gestiscono componenti osservabili costruiti così.
