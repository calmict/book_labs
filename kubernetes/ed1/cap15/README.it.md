# Cap. 15 — Il rilascio, il disastro e il ritorno (rollout e rollback)

> Esercizio del **Capitolo 15 — ReplicaSet e Deployment** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- leggere la divisione dei compiti: il ReplicaSet guardiano del numero, il Deployment orchestratore dei ReplicaSet — e i vecchi ReplicaSet a zero repliche come memoria storica;
- eseguire un rolling update senza downtime e osservarlo pod per pod (maxSurge 1, maxUnavailable 0);
- sopravvivere a un rilascio rotto: il rollout si blocca ma il servizio resta su, e kubectl rollout undo riporta indietro in un istante — capendo che non è magia, è ancora il reconciliation loop.

## Prerequisiti

- Cap. 13-14 completati; il cluster book-labs acceso.
- Il manifest di partenza start/shop.yaml con i TODO (repliche, strategia, immagine).

## Consegna

1. Apri il negozio. Completa start/shop.yaml: Deployment "shop", 3 repliche di alpine:3.19 (container sleeper, sleep infinity), e la strategia che promette zero downtime: RollingUpdate con maxSurge 1 e maxUnavailable 0. Applica e annota la prima revisione:

       kubectl apply -f shop.yaml
       kubectl annotate deployment/shop kubernetes.io/change-cause="opening: alpine 3.19"
       kubectl rollout status deployment/shop

2. Chi comanda davvero. Guarda cosa possiede il Deployment:

       kubectl get replicaset -l app=shop
       kubectl get pods -l app=shop

   Un ReplicaSet col suffisso-hash, tre pod col suo prefisso: il Deployment non tocca mai i pod — comanda ReplicaSet (la catena del cap. 13). Annota il nome del ReplicaSet.

3. Il rilascio. In un terminale osserva (kubectl get pods -l app=shop -w), dall'altro aggiorna:

       kubectl set image deployment/shop sleeper=alpine:3.20
       kubectl annotate deployment/shop kubernetes.io/change-cause="release: alpine 3.20"
       kubectl rollout status deployment/shop

   Nel watch: un pod nuovo nasce (il surge), uno vecchio muore, e così via — mai meno di 3 attivi. A fine giro:

       kubectl get replicaset -l app=shop
       kubectl rollout history deployment/shop

   DUE ReplicaSet: il nuovo con 3, il vecchio tenuto a 0. Non è spazzatura: è la memoria su cui viaggia il rollback.

4. Il disastro. Rilascia una versione che non esiste:

       kubectl set image deployment/shop sleeper=alpine:3.99
       kubectl annotate deployment/shop kubernetes.io/change-cause="release: alpine 3.99 (oops)"
       kubectl rollout status deployment/shop --timeout=30s
       kubectl get pods -l app=shop

   Il rollout si pianta (ImagePullBackOff sul pod di avanscoperta) ma guarda bene: i 3 pod della 3.20 sono ancora Running. Il negozio non ha mai chiuso — maxUnavailable 0 ha impedito di toccare i vecchi finché i nuovi non fossero pronti. Annota lo stato.

5. Il ritorno. Un solo comando:

       kubectl rollout undo deployment/shop
       kubectl rollout status deployment/shop
       kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
       kubectl rollout history deployment/shop

   Di nuovo alpine:3.20, in secondi (i pod non sono nemmeno stati ricreati: il ReplicaSet della 3.20 era ancora lì). Nota la history: la revisione 2 è "rinata" con un numero nuovo, e le change-cause raccontano tutta la storia. Bonus: prova a tornare all'apertura con kubectl rollout undo --to-revision=1 e verifica l'immagine.

6. Le domande per answers.md: (a) la divisione dei compiti: cosa fa il ReplicaSet e cosa SOLO il Deployment sa fare? Perché i vecchi ReplicaSet restano a 0 invece di sparire? (b) il disastro del passo 4: perché il servizio non è mai andato giù, e cosa sarebbe cambiato con maxUnavailable 1? Chi si sarebbe accorto del problema in produzione (rifletti: rollout status, il progressDeadline, gli eventi)? (c) cosa fa DAVVERO rollout undo? (niente magia: descrivi la mossa in termini di ReplicaSet scalati, e spiega perché è ancora il reconciliation loop del cap. 7)

7. Chiudi il negozio:

       kubectl delete deployment shop

## Criteri di "fatto"

- [ ] Hai visto il rolling update pod per pod, mai sotto 3 attivi.
- [ ] Dopo il rilascio hai due ReplicaSet (3 e 0) e la history con le change-cause.
- [ ] Nel disastro: rollout bloccato in ImagePullBackOff ma i 3 pod della versione precedente Running.
- [ ] Dopo l'undo l'immagine è tornata alpine:3.20 e la revisione è rinata con numero nuovo.
- [ ] answers.md risponde alle tre domande e il Deployment è stato rimosso.
