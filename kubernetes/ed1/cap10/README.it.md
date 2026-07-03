# Cap. 10 — Scrivi il tuo controller in venti righe (e scopri perché ne serve uno solo)

> Esercizio del **Capitolo 10 — Controller Manager e il reconciliation loop** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- riconoscere il battito del cuore dei controller veri: le Lease della leader election in kube-system;
- scrivere in prima persona un controller funzionante (observe–diff–act in venti righe di shell) e vederlo riparare i tuoi sabotaggi;
- scoprirne i due difetti strutturali — il polling e il duello tra copie — e capire perché client-go risponde con informer e leader election.

## Prerequisiti

- Cap. 7 e 9 completati; il cluster book-labs acceso (kubectl get nodes deve rispondere).
- Il file start/minictl.sh fornito, da completare: è il primo esercizio della collana con un vero file di partenza da riempire.

## Consegna

1. Prima i professionisti. Guarda chi detiene i lock del control plane e il loro battito:

       kubectl get leases -n kube-system
       kubectl get lease kube-controller-manager -n kube-system -o yaml

   Annota holderIdentity e renewTime; riesegui dopo dieci secondi: il renewTime è avanzato. Il leader dimostra di essere vivo rinnovando la sua lease.
   (Nota: su minikube questa lease non esiste — il suo control plane mononodo gira con --leader-elect=false. Per questo passo serve kind; il resto dell'esercizio funziona ovunque.)

2. Ora tocca a te. Copia start/minictl.sh in una cartella di lavoro e aprilo: è un controller monco, con la struttura observe–diff–act e tre TODO. Completalo: OSSERVA (conta i pod con etichetta app=minictl, ignorando quelli in Terminating), CONFRONTA con il desiderato (2), AGISCI (creane uno se mancano; se abbondano cancellane uno — scegliendo una vittima non già morente). Venti righe, non serve altro.

3. Rendilo eseguibile e avvialo in un terminale:

       chmod +x minictl.sh
       ./minictl.sh

   Al primo giro crea i due pod. Ora sabota dal secondo terminale, come al cap. 7:

       kubectl delete pod <uno-dei-due>

   Il tuo controller nota la differenza e ripara. Prova anche l'eccesso: crea un terzo pod a mano con l'etichetta app=minictl e guardalo venire potato. Sei tu, adesso, il controller-manager.

4. Primo difetto: il polling. Il tuo script interroga l'API ogni due secondi, anche quando non cambia nulla — moltiplicalo per mille controller e l'apiserver affoga. Il vero controller-manager usa la connessione watch del cap. 9 (passo 6) più una cache locale: sono gli informer di client-go. Annota la differenza per le domande finali.

5. Secondo difetto: il duello. Ferma il controller, cancella i pod rimasti e avvia DUE copie di minictl.sh in due terminali, il più possibile nello stesso istante (così i loro tick restano allineati). Quando i due pod sono su, cancellane uno e osserva il pasticcio: entrambe le copie vedono il buco, entrambe agiscono, i pod diventano 3, poi entrambe tagliano — magari lo stesso pod. Due termostati sullo stesso termosifone. (Se al primo colpo non collidono, è la fortuna dei tempi: ferma tutto e riparti insieme.) Ferma le copie e rifletti.

6. La soluzione dei professionisti l'hai già vista al passo 1: prima di agire, ogni copia prova ad acquisire la lease; una sola ci riesce e le altre restano in panchina. Un solo termostato attivo per volta, il subentro solo se il titolare smette di rinnovare.

   Le tre domande per answers.md: (a) indica le righe observe, diff e act del tuo script e mappale su ciò che ha fatto il ReplicaSet controller nel cap. 7; (b) perché il polling non scala, e cosa cambiano informer e cache di client-go? (c) descrivi il duello del passo 5 e come la leader election lo previene: chi rinnova la lease, e cosa succede se smette di farlo?

7. Smonta il laboratorio: ferma gli script (Ctrl-C) e:

       kubectl delete pods -l app=minictl

## Criteri di "fatto"

- [ ] Hai visto il renewTime della lease del controller-manager avanzare.
- [ ] Il tuo minictl.sh ricrea il pod cancellato senza intervento umano e pota gli eccessi.
- [ ] Hai provocato e descritto il duello tra due copie.
- [ ] answers.md risponde alle tre domande.
- [ ] Nessun pod app=minictl residuo e script fermati.
