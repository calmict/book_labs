# Cap. 12 — Il medico di bordo: probe, riavvii e il pod che resuscita da solo

> Esercizio del **Capitolo 12 — I componenti del nodo Worker** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- vedere il kubelet fare il medico: una liveness probe che fallisce e il container riavviato, con il conto dei riavvii e il back-off che cresce;
- distinguere i due destini: liveness (riavvio) contro readiness (fuori dal giro del traffico, senza riavvio) — osservando gli endpoint di un Service svuotarsi e ripopolarsi;
- dimostrare che il kubelet non ha bisogno di nessuno: uno static pod creato mettendo un file sul nodo, che risorge perfino se lo cancelli dall'API.

## Prerequisiti

- Cap. 7-11 completati; il cluster book-labs acceso.
- I manifest di partenza in start/ hanno i TODO sulle probe.
- Serve poter entrare nel nodo (con kind e minikube su driver Docker: docker exec <nome-nodo>).

## Consegna

1. L'app che mente. Completa start/pod-liar.yaml: il container crea /tmp/healthy, dorme venti secondi e poi lo cancella (continuando a girare); il TODO è la livenessProbe exec (cat /tmp/healthy, periodSeconds 5, initialDelaySeconds 5). Applica e osserva il medico al lavoro:

       kubectl apply -f pod-liar.yaml
       kubectl get pod liar -w

   Aspetta un paio di minuti: RESTARTS sale, e sale ancora. Ferma il watch e leggi la cartella clinica:

       kubectl describe pod liar

   Negli eventi: Unhealthy (la probe fallita), Killing (la cura), Started (la ricaduta), e col tempo Back-off (il medico che perde la pazienza: i riavvii si distanziano).

2. Il paziente lunatico. Completa start/pod-moody.yaml: container che crea /tmp/ready all'avvio, readinessProbe che lo controlla (test -f, periodSeconds 3, failureThreshold 2), più il Service già pronto nel file. Applica e guarda chi riceve il traffico:

       kubectl apply -f pod-moody.yaml
       kubectl get endpoints moody

   C'è l'IP del pod. (kubectl ti avvisa che Endpoints è deprecato a favore di EndpointSlice: per osservare il fenomeno va benissimo lo storico Endpoints, più leggibile; l'evoluzione la incontrerai col capitolo sui Service.) Ora fallo ammalare senza ucciderlo:

       kubectl exec moody -- rm /tmp/ready
       kubectl get pod moody
       kubectl get endpoints moody

   READY 0/1, endpoint vuoto — ma RESTARTS fermo: nessun riavvio. La readiness non cura, mette in panchina. Guariscilo:

       kubectl exec moody -- touch /tmp/ready
       kubectl get endpoints moody

   Di nuovo in campo. Due probe, due destini: annota la differenza.

3. Il kubelet non ha bisogno di nessuno. Trova il nodo ed entra nella sua cartella dei manifest statici:

       kubectl get nodes
       docker exec <nome-nodo> ls /etc/kubernetes/manifests

   Riconosci gli inquilini? apiserver, etcd, scheduler, controller-manager: il control plane stesso è fatto di static pod (ecco come nasce un cluster prima che esista l'API). Ora aggiungi il tuo:

       docker cp start/static-hello.yaml <nome-nodo>:/etc/kubernetes/manifests/
       kubectl get pods

   È comparso hello-static-<nome-nodo>: nessun kubectl apply, nessuno scheduler, nessun controller — il kubelet ha visto il file e ha agito.

4. La resurrezione senza controller. Prova a cancellarlo dall'API:

       kubectl delete pod hello-static-<nome-nodo>
       kubectl get pods

   È già tornato. Nel cap. 7 a resuscitare i pod era il ReplicaSet controller; qui non c'è nessun Deployment: quello che vedi nell'API è solo lo specchio (mirror pod) di ciò che il kubelet esegue per conto suo. Finché il file sta nella cartella, il pod esiste. Rimuovi il file e verifica che sparisca:

       docker exec <nome-nodo> rm /etc/kubernetes/manifests/static-hello.yaml
       kubectl get pods

5. Le domande per answers.md: (a) liveness contro readiness: descrivi i due destini osservati (riavvio vs panchina) e spiega perché una liveness scritta male è pericolosa (riavvii a catena di un'app solo lenta); (b) chi ha resuscitato hello-static, e in cosa differisce dalla resurrezione del cap. 7? Perché il control plane stesso è fatto di static pod? (c) l'eviction: cosa fa il kubelet quando il nodo è a corto di memoria, e perché è il fratello dell'OOM kill del cap. 3? (rifletti: risorsa incomprimibile, ma stavolta la difesa è del nodo intero)

6. Smonta il laboratorio:

       kubectl delete pod liar moody
       kubectl delete service moody

   (lo static pod è già sparito col suo file al passo 4)

## Criteri di "fatto"

- [ ] RESTARTS di liar è salito almeno due volte e negli eventi hai Unhealthy, Killing e il Back-off.
- [ ] Gli endpoint di moody si sono svuotati e ripopolati senza alcun riavvio del pod.
- [ ] hello-static è comparso senza apply, è risorto dopo il delete, ed è sparito rimuovendo il file dal nodo.
- [ ] answers.md risponde alle tre domande.
- [ ] Pod e Service di laboratorio rimossi.
