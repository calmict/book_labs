# Capitolo 27 — La scorta

**Livello:** Cloud Architect

Dopo aver affidato lo stato a un revisore, affidi ogni chiamata a una scorta che applica identità, cifratura e rotta senza cambiare l'applicazione.

## Obiettivi

- Osservare sidecar, data plane e control plane (27.1, 27.2).
- Imporre mTLS automatico e identità workload (27.3).
- Dirigere un canary 80/20 e collegare il mesh all'osservabilità (27.4, 27.5).

## Prerequisiti

- kind, Docker, kubectl e istioctl disponibili; almeno 3 GB liberi nello storage Docker.
- Accesso Internet per le immagini; capitoli 22 e 25 completati.

## Lo scenario

Completa i TODO 1..3: abilita l'injection, imponi STRICT e assegna i pesi 80/20. Il test usa il cluster dedicato book-labs-mesh perché Istio installa CRD e webhook cluster-wide.

    cd kubernetes/ed1/cap27/solution
    ./run.sh

### Fase 1 — Affiancare la scorta (27.1, 27.2)

L'etichetta del namespace fa nascere ogni workload con applicazione e istio-proxy.

### Fase 2 — Verificare identità e cifratura (27.3)

Confronta la chiamata plaintext prima e dopo PeerAuthentication STRICT; il client nel mesh continua a passare.

### Fase 3 — Comandare il traffico (27.4, 27.5)

DestinationRule definisce le versioni e VirtualService ripartisce le richieste 80/20 senza modificare l'app.

## Criteri di "fatto"

- [ ] I tre TODO sono completi e tutti i workload hanno il sidecar.
- [ ] STRICT rifiuta plaintext ma consente il traffico nel mesh.
- [ ] Il canary raggiunge entrambe le versioni.
- [ ] run.sh stampa OK 1..4 — o SKIP 1 motivato — e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 verifica cluster dedicato e control plane.
- OK 2 conta due container in ciascuno dei tre workload.
- OK 3 è il cancello che morde: plaintext passa prima di STRICT e viene rifiutato dopo, mentre mTLS passa.
- OK 4 invia sessanta richieste e verifica che entrambi i subset ricevano traffico.

## Domande di riflessione

**a.** Cosa cambia spostando la logica di rete nei sidecar e come si dividono data plane e control plane?

**b.** Da dove arrivano identità e certificati mTLS e come completano le NetworkPolicy?

**c.** Come applica il mesh canary, retry, circuit breaking e osservabilità senza cambiare il codice?

## Pulizia

run.sh elimina sempre il cluster dedicato book-labs-mesh e ripristina il contesto kubectl precedente.

## Dove porta

Il service mesh chiude il percorso operativo: stato, sicurezza, traffico e segnali sono governati dalla piattaforma; le appendici raccolgono i riferimenti per continuare.
