# Cap. 20 — Il matrimonio combinato (PV, PVC, StorageClass)

> Esercizio del **Capitolo 20 — Storage: PV, PVC, StorageClass e CSI** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- combinare un matrimonio statico: un PV creato a mano, un PVC che lo chiede, il binding 1:1 — e la zitella che resta Pending quando i PV finiscono;
- scatenare il provisioning dinamico: un PVC con la StorageClass e un PV che nasce dal nulla, firmato dal provisioner;
- leggere le reclaim policy nei fatti: il PV dinamico che muore col suo claim (Delete) e quello manuale che resta vedovo ma custodisce la dote (Retain, stato Released).

## Prerequisiti

- Cap. 16 completato (i PVC li hai già incontrati dal lato StatefulSet).
- Il cluster book-labs acceso; accesso al nodo con docker exec (per verificare la dote sul disco).
- Tre manifest in start/: marriage.yaml (il PV e il writer sono dati, il PVC "bride" ha i TODO), spinster.yaml (dato) e dynamic.yaml (TODO sul claim).

## Consegna

1. Il matrimonio combinato. In start/marriage.yaml il PV "manual-pv" è dato (50Mi, hostPath, storageClassName manual, reclaim Retain — leggilo bene); completa il PVC "bride" (chiede 30Mi della classe manual) e applica:

       kubectl apply -f marriage.yaml
       kubectl get pv,pvc

   bride è Bound a manual-pv: il claim ha trovato un volume che soddisfa richiesta, accessModes e classe. Nel file c'è anche un pod "writer" che monta la sposa e scrive la dote (/data/dote.txt): verifica che sia Running.

2. La zitella. Applica il secondo claim, identico al primo:

       kubectl apply -f spinster.yaml
       kubectl get pvc

   Pending, per sempre: il binding è 1:1 e i PV della classe manual sono finiti. "PVC chiede, PV esiste" — e quando non esiste, si aspetta.

3. Il sensale automatico. Completa start/dynamic.yaml: un PVC "cloud" da 30Mi SENZA storageClassName (userà la classe di default); nel file c'è anche un pod "tenant" che lo monta — serve davvero: guarda la colonna VOLUMEBINDINGMODE della classe. Applica e osserva:

       kubectl apply -f dynamic.yaml
       kubectl get pvc cloud
       kubectl get pv
       kubectl get storageclass

   Un PV nuovo, nome pvc-<uid>, creato dal provisioner della StorageClass di default (su kind: rancher.io/local-path): nessun amministratore l'ha preparato — un controller (cap. 10, sempre lui) ha visto il claim e ha esaudito. E con WaitForFirstConsumer il sensale aspetta di sapere DOVE serve il volume prima di crearlo: senza il tenant, cloud resterebbe Pending. Confronta le colonne RECLAIM POLICY dei due PV: Retain il manuale, Delete il dinamico.

4. Due morti diverse. Cancella i pod e tutti i claim, poi guarda i destini dei volumi:

       kubectl delete pod writer tenant
       kubectl delete pvc bride spinster cloud
       kubectl get pv

   Il PV dinamico è sparito (Delete: morto col suo claim). manual-pv invece è in stato Released: vedovo, non risposabile (il claimRef del defunto resta inciso), ma con la dote intatta. Verificala sul nodo:

       NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
       docker exec $NODE cat /tmp/manual-pv/dote.txt

   La scrittura del writer è ancora lì: Retain ha mantenuto la promessa.

5. Le domande per answers.md: (a) il matrimonio: con quali criteri il binder sposa un PVC a un PV, perché è 1:1, e cosa aspettava la zitella? (b) le reclaim policy nei fatti: racconta le due morti del passo 4 — quando vuoi Retain, qual è il rischio del default Delete, e cosa serve per rendere di nuovo Available un PV Released? (c) i tre contratti di estensione: CSI sta allo storage come CRI (cap. 5) sta al runtime e CNI (cap. 6) alla rete — perché Kubernetes definisce interfacce invece di implementazioni, e dove hai visto all'opera il pattern provisioner-come-controller?

6. Smonta il laboratorio (il PV Released va rimosso a mano — ora sai perché):

       kubectl delete pv manual-pv
       docker exec $NODE rm -rf /tmp/manual-pv

## Criteri di "fatto"

- [ ] bride Bound a manual-pv, writer Running, spinster Pending per sempre.
- [ ] cloud Bound a un PV pvc-<uid> nato dal provisioner, con RECLAIM POLICY Delete contro il Retain del manuale.
- [ ] Dopo la strage dei claim: PV dinamico sparito, manual-pv Released, e la dote ancora leggibile sul nodo.
- [ ] answers.md risponde alle tre domande.
- [ ] PV Released e cartella sul nodo rimossi a mano.
