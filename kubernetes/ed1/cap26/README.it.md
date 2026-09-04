# Capitolo 26 — Il libro mastro e il revisore

**Livello:** Cloud Architect

Hai imparato a osservare il cluster; ora consegni ad ArgoCD un libro mastro e gli chiedi di correggere ogni divergenza.

## Obiettivi

- Usare Git come unica fonte di verità dichiarativa (26.1).
- Definire sorgente, destinazione e politica di una Application ArgoCD (26.2).
- Osservare sync, drift, self-heal e rollback con git revert (26.3, 26.4).

## Prerequisiti

- kind, Docker e kubectl disponibili; almeno 3 GB liberi nello storage Docker.
- Accesso Internet per scaricare il manifest ArgoCD e le immagini.
- Capitoli 15, 24 e 25 completati.

## Lo scenario

Un server Git interno ospita un Deployment a una replica. Completa i TODO 1..3 dell'Application; ArgoCD deve costruire il mondo dal libro, cancellare il drift e propagare un revert.

    cd kubernetes/ed1/cap26/solution
    ./run.sh

### Fase 1 — Affidare il libro al revisore (26.1, 26.2)

Definisci repository, revisione, percorso e namespace di destinazione.

### Fase 2 — Provocare il drift (26.3)

Scala il Deployment a mano: selfHeal deve riconoscere la divergenza e ripristinare una replica.

### Fase 3 — Correggere il libro (26.4)

Un commit porta le repliche a cinque; git revert riporta il desiderato a uno e ArgoCD lo propaga.

## Criteri di "fatto"

- [ ] I tre TODO sono completi e la Application è Synced e Healthy.
- [ ] Il drift manuale viene annullato.
- [ ] Il commit e il revert producono cinque e poi una replica.
- [ ] run.sh stampa OK 1..4 — o SKIP 1 motivato — e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 verifica cluster dedicato, ArgoCD e libro mastro.
- OK 2 verifica il primo sync e lo stato Healthy.
- OK 3 è il cancello che morde: tre repliche esistono davvero prima che selfHeal le riporti a una.
- OK 4 verifica che commit e revert governino lo stato live.

## Domande di riflessione

**a.** Perché Git è la fonte di verità e quali vantaggi dà il pull di ArgoCD rispetto al push da una pipeline?

**b.** Cosa significano Synced, OutOfSync e Healthy e perché la riconciliazione è continua?

**c.** Perché il rollback GitOps usa git revert e come differisce da helm rollback?

## Pulizia

run.sh elimina sempre il cluster dedicato book-labs-gitops e ripristina il contesto kubectl precedente.

## Dove porta

GitOps governa lo stato dichiarato. Il prossimo capitolo sposta sicurezza e instradamento fuori dalle applicazioni con un service mesh.
