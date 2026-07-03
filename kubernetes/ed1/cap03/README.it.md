# Cap. 3 — Limitare CPU e RAM a mano

> Esercizio del **Capitolo 3 — Cgroups: il contabile delle risorse** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- creare un cgroup v2 a mano e leggerne/scriverne i file di controllo, senza alcun runtime;
- mettere in gabbia un processo in esecuzione e osservare i due destini opposti: la CPU che viene rallentata (throttling) e la memoria che uccide (OOM kill);
- collegare cpu.max e memory.max a ciò che Kubernetes chiama requests/limits, e capire da dove nasce lo stato OOMKilled.

## Prerequisiti

- Aver completato il cap. 2 (namespaces: cosa vede un processo; qui: quanto consuma).
- Un host Linux con cgroup v2 (qualsiasi distro moderna) e privilegi sudo.

> ⚠️ **Nota WSL2:** se al passo 1 non ottieni cgroup2fs, la tua WSL monta
> ancora la gerarchia ibrida v1: aggiungi nel file %UserProfile%\\.wslconfig le
> righe [wsl2] e kernelCommandLine = cgroup_no_v1=all, poi wsl --shutdown e
> riprova.

> 💡 **Niente sudo?** systemd delega al tuo utente solo i controller memory e
> pids (verifica con: cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers).
> Puoi quindi fare la parte memoria senza root, così:
>
>     systemd-run --user --scope -p MemoryMax=64M -p MemorySwapMax=0 -- sh -c 'sleep 30; head -c 200M /dev/zero | tail'
>
> Durante i 30 secondi di attesa, da un secondo terminale trova il cgroup dello
> scope (systemd-cgls --user) e leggi a mano i suoi memory.max e memory.current;
> poi assisti all'uccisione. La parte CPU invece richiede root: il controller
> cpu non è delegato. E non provare a spostare a mano il PID della tua shell
> nel cgroup delegato: la regola del "common ancestor" di cgroup v2 te lo
> impedirà — è il motivo per cui qui si passa da systemd-run.

## Consegna

1. Verifica di essere su cgroup v2 e guarda quali controller esistono:

       stat -fc %T /sys/fs/cgroup
       cat /sys/fs/cgroup/cgroup.controllers

   Atteso: cgroup2fs, e un elenco che include cpu e memory.

2. Crea la tua gabbia e verifica quali controller ha ereditato:

       sudo mkdir /sys/fs/cgroup/lab-cap03
       cat /sys/fs/cgroup/lab-cap03/cgroup.controllers

3. **La CPU rallenta.** Avvia un processo che divora un core intero e misuralo da libero:

       sh -c 'while :; do :; done' &
       ps -o pid,%cpu,cmd -p $!

   Aspetta qualche secondo e rilancia il ps: dovrebbe viaggiare verso il 100%.
   Ora imponi il 20% di un core e trasloca il processo nella gabbia (usa il PID
   stampato da $!):

       echo "20000 100000" | sudo tee /sys/fs/cgroup/lab-cap03/cpu.max
       echo <PID> | sudo tee /sys/fs/cgroup/lab-cap03/cgroup.procs

   Riosserva il consumo dopo una decina di secondi — qui usa top -b -n1 -p <PID>,
   che è istantaneo, perché ps mostra la media dall'avvio — e leggi il contatore
   delle punizioni:

       grep -E 'nr_throttled|throttled_usec' /sys/fs/cgroup/lab-cap03/cpu.stat

   Il processo non è morto: è solo più lento. Annota i valori.

4. **La memoria uccide.** Imponi 64M di tetto (e niente swap di scampo), poi
   lancia un goloso che ne vorrebbe 200M, già dentro la gabbia:

       echo 64M | sudo tee /sys/fs/cgroup/lab-cap03/memory.max
       echo 0 | sudo tee /sys/fs/cgroup/lab-cap03/memory.swap.max
       sudo sh -c 'echo $$ > /sys/fs/cgroup/lab-cap03/cgroup.procs; head -c 200M /dev/zero | tail'

   Atteso: "Killed" nel giro di un secondo. Raccogli le prove dell'omicidio:

       cat /sys/fs/cgroup/lab-cap03/memory.events
       cat /sys/fs/cgroup/lab-cap03/memory.peak
       sudo dmesg | tail -5

5. **(Bonus) Il buttafuori dei fork.** Con pids.max a 5, una fork bomb diventa
   innocua:

       echo 5 | sudo tee /sys/fs/cgroup/lab-cap03/pids.max
       sudo sh -c 'echo $$ > /sys/fs/cgroup/lab-cap03/cgroup.procs; for i in 1 2 3 4 5 6 7 8; do sleep 30 & done'

   Conta quanti errori di fork ottieni e verifica pids.events.

6. Rispondi per iscritto nel file answers.md che consegnerai: perché il limite
   di CPU rallenta senza uccidere mentre quello di memoria uccide (risorsa
   comprimibile vs incomprimibile)? A cosa corrispondono cpu.max e memory.max
   nel mondo Kubernetes, e da dove nasce lo stato OOMKilled di un Pod? Cosa
   raccontano nr_throttled e oom_kill a chi fa troubleshooting?

7. Smonta il laboratorio: uccidi il loop del passo 3 (kill <PID>), lascia
   finire gli sleep del passo 5, poi:

       sudo rmdir /sys/fs/cgroup/lab-cap03

   (rmdir funziona solo a gabbia vuota: se protesta, dentro c'è ancora
   qualcuno — scopri chi con cat /sys/fs/cgroup/lab-cap03/cgroup.procs.)

## Criteri di "fatto"

- [ ] Hai visto lo stesso loop prima vicino al 100% di un core e poi inchiodato
      al 20%, con nr_throttled in crescita in cpu.stat.
- [ ] Il processo goloso è stato ucciso (Killed / exit 137) e memory.events
      registra oom_kill 1, con memory.peak fermo poco sopra i 64M.
- [ ] Il file answers.md risponde alle tre domande del passo 6.
- [ ] La gabbia è stata rimossa con rmdir e non restano processi di laboratorio
      in giro.
