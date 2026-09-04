# Capitolo 25 — Il lettore dei contatori

**Livello:** Cloud Architect

Dopo aver impacchettato la piattaforma con Helm, le dai occhi: un lettore visita i contatori e trasforma misure grezze in domande verificabili.

## Obiettivi

- Osservare il modello pull e le metriche esposte da node-exporter (25.1, 25.2).
- Dichiarare uno scrape statico e il suo equivalente ServiceMonitor (25.3).
- Interrogare gauge e counter con PromQL e collegarli ad alert e Grafana (25.4, 25.5).

## Prerequisiti

- kubectl disponibile e cluster book-labs raggiungibile.
- Capitolo 24 completato e familiarità con Deployment, Service e ConfigMap.

## Lo scenario

Completa i TODO 1..3 nel giro del lettore, nella dichiarazione per l'operator e nelle query. La soluzione usa tre Pod leggeri, senza operator, storage persistente o Grafana.

    cd kubernetes/ed1/cap25/solution
    ./run.sh

### Fase 1 — Montare il contatore (25.1, 25.2)

node-exporter espone carico e memoria come testo HTTP. Prometheus deve andare a prenderli.

### Fase 2 — Scrivere il giro (25.1–25.3)

Aggiungi il job node allo scrape config e completa il ServiceMonitor equivalente per bersagli dinamici.

### Fase 3 — Interrogare il registro (25.4, 25.5)

Completa le query per contare i target sani, leggere un gauge e calcolare il rate di un counter.

## Criteri di "fatto"

- [ ] I tre TODO sono completi.
- [ ] node-exporter espone metriche reali e Prometheus vede entrambi i target.
- [ ] Le tre query PromQL restituiscono risultati.
- [ ] run.sh stampa OK 1..4 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 verifica le metriche HTTP del nodo.
- OK 2 è il cancello che morde: senza il job manca il target node; aggiungendolo, up passa da uno a due target.
- OK 3 confronta ServiceMonitor e Service tramite label e porta nominata.
- OK 4 esegue count, gauge e rate tramite l'API di Prometheus.

## Domande di riflessione

**a.** Perché Prometheus usa il pull, cosa misura up e quale ruolo svolge un exporter?

**b.** Cosa aggiunge ServiceMonitor allo scrape config scritto a mano e perché l'operator scala meglio?

**c.** Come differiscono gauge e counter, perché serve rate e come usano PromQL alert e Grafana?

## Pulizia

run.sh elimina il namespace monitoring, anche in caso di errore.

## Dove porta

Ora il cluster è osservabile. Il prossimo capitolo rende Git la fonte di verità e affida la riconciliazione ad ArgoCD.
