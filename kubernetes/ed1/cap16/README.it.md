# Cap. 16 — L'anagrafe: nomi, ordine e dischi che sopravvivono

> Esercizio del **Capitolo 16 — StatefulSet e la gestione dello stato** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- toccare la differenza tra Pod fungibili e Pod con identità: la folla rinasce con nomi casuali, diary-1 rinasce diary-1;
- osservare l'ordinamento rigoroso (0 → 1 → 2 in salita, inverso in discesa) e il DNS prevedibile via headless Service;
- dimostrare che con volumeClaimTemplates ogni replica ha il SUO disco, e che il disco sopravvive al Pod — e perfino alla cancellazione dell'intero StatefulSet.

## Prerequisiti

- Cap. 15 completato; il cluster book-labs acceso (la StorageClass di default di kind/minikube basta e avanza).
- Il manifest di partenza start/diary.yaml coi TODO (serviceName, volumeClaimTemplates, mount).

## Consegna

1. La folla, per confronto. Crea un Deployment qualsiasi e guarda i nomi:

       kubectl create deployment crowd --replicas=3 --image=alpine:3 -- sleep infinity
       kubectl get pods -l app=crowd

   Nomi casuali, hash su hash: individui fungibili. Cancellane uno e guarda chi arriva al suo posto: un altro nome casuale. Nessuno sentirà la sua mancanza.

2. L'anagrafe. Completa start/diary.yaml: un headless Service "diary" (clusterIP: None, già nel file) e uno StatefulSet da 3 repliche che lo usa come serviceName; ogni replica scrive una riga di diario al risveglio (il comando è già nel file) su /data, montato da un volumeClaimTemplates da 10Mi (i TODO ti guidano). Applica con il watch acceso in un altro terminale:

       kubectl get pods -l app=diary -w
       kubectl apply -f diary.yaml

   Guarda i nomi e l'ordine: diary-0, POI diary-1 (solo quando 0 è Ready), POI diary-2. Niente hash: un'anagrafe.

3. La rinascita con lo stesso nome. Cancella il cittadino di mezzo:

       kubectl delete pod diary-1
       kubectl get pods -l app=diary

   La folla del passo 1 rimpiazzava; qui diary-1 rinasce come diary-1. E non è tornato a mani vuote — leggigli il diario:

       kubectl exec diary-1 -- cat /data/diary.txt

   Due righe: quella di prima di morire e quella del risveglio. Il disco è sopravvissuto al Pod.

4. Un disco a testa. Guarda i PVC creati dal template:

       kubectl get pvc

   data-diary-0, data-diary-1, data-diary-2: non un volume condiviso, ma un disco personale per ogni identità — è questo che un database pretende.

5. Il disco sopravvive perfino al controller. Cancella l'INTERO StatefulSet e verifica cosa resta:

       kubectl delete statefulset diary
       kubectl get pods -l app=diary
       kubectl get pvc

   Pod spariti (in ordine inverso, se sei stato veloce col watch), ma i PVC sono ancora tutti lì: i dati non si cancellano per sbaglio. Ora ricrea lo StatefulSet (riapplica diary.yaml) e rileggi il diario di diary-0: tutte le righe della sua vita precedente, più quella nuova. Ogni identità ha ritrovato il SUO disco.

6. L'indirizzo prevedibile. Dal cittadino 1, cerca il cittadino 0 per nome:

       kubectl exec diary-1 -- nslookup diary-0.diary.default.svc.cluster.local

   Risolve sull'IP del Pod: con l'headless Service ogni replica ha un nome DNS stabile — è così che i membri di un cluster con quorum (il cap. 8!) si trovano tra loro. (Il nome completo è d'obbligo: il piccolo resolver di busybox non applica i domini di ricerca.)

   Le domande per answers.md: (a) fungibile contro identità: usa le prove (nomi, rinascita, diario) e spiega perché un database non può vivere in un Deployment; (b) perché l'ordine 0→1→2 (e la discesa inversa) è vitale per i sistemi con quorum — collega al cap. 8; (c) il ciclo di vita dei dischi: perché i PVC sopravvivono alla cancellazione dello StatefulSet? Vantaggi, rischi (dischi orfani) e come si pulisce davvero.

7. Smonta tutto, dischi inclusi (stavolta la pulizia è in due tempi, e ora sai perché):

       kubectl delete statefulset diary
       kubectl delete service diary
       kubectl delete deployment crowd
       kubectl delete pvc data-diary-0 data-diary-1 data-diary-2

## Criteri di "fatto"

- [ ] Hai il confronto dei nomi: casuali nella folla, diary-N nell'anagrafe, con la nascita in ordine 0→1→2.
- [ ] diary-1 è rinato come diary-1 e il suo diario aveva la riga della vita precedente.
- [ ] Hai visto i 3 PVC personali, ancora vivi dopo la cancellazione dello StatefulSet, e il diario completo dopo la ricreazione.
- [ ] La nslookup del nome stabile risolve dall'interno.
- [ ] answers.md risponde alle tre domande e la pulizia include i PVC.
