# Cap. 5 — Risali la catena dei runtime (e lancia un container con il solo runc)

> Esercizio del **Capitolo 5 — La guerra dei runtime: Docker, containerd, CRI-O** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- risalire la catena reale dei processi di un container in esecuzione e scoprire chi c'è davvero (e chi NON c'è) tra lui e init;
- interrogare containerd direttamente, scavalcando Docker, per toccare con mano che il comando docker è solo un client;
- leggere un bundle OCI (il config.json che containerd prepara per runc) e riconoscervi namespaces, cgroups e capabilities dei capitoli 2-4;
- avviare un container con il solo runc: niente demoni, niente API, solo la spec e un rootfs.

## Prerequisiti

- Aver completato i cap. 1-4 (tutti i pezzi che qui si vedono assemblati in catena).
- Docker funzionante; runc e ctr sono già sul sistema (arrivano con il pacchetto containerd di Docker: verifica con command -v runc ctr).
- Privilegi sudo per i passi 4 e 5.

> 💡 **Usi Podman?** Vedrai una storia diversa, ed è il punto del §5.5: niente
> demone, il padre del container è conmon. I passi 2-5 non tornano uguali, ma
> rifarli su Podman e confrontare le due catene è un ottimo esercizio extra.
> Il passo 6 (runc puro) funziona identico.

## Consegna

1. Avvia il container di laboratorio:

       docker run -d --name lab-cap05 alpine:3 sleep infinity

2. Risali la catena dei padri, dal processo del container fino a PID 1, leggendo /proc a mano (il quarto campo di /proc/[pid]/stat è il padre):

       PID=$(docker inspect --format '{{.State.Pid}}' lab-cap05)
       P=$PID; while [ "$P" -ne 1 ]; do ps -o pid=,comm= -p "$P"; P=$(awk '{print $4}' /proc/$P/stat); done

   Annota la catena. Sorpresa: tra il tuo sleep e init c'è UN solo anello, il containerd-shim. Conferma con pstree -s -p $PID.

3. E i due pezzi grossi? Verifica che dockerd e containerd girano eccome:

       ps -e -o pid,comm | grep -E 'dockerd|containerd'

   Girano, ma NON sono antenati del tuo container. Prima domanda da annotare: perché il shim ha come padre PID 1 e non containerd? Cosa succederebbe ai container, al riavvio del demone, se la catena fosse dockerd → containerd → processo?

4. Docker è solo un client: parla direttamente con containerd e ritrova il tuo container:

       sudo ctr --namespace moby task ls

   Eccolo: lo gestisce containerd, docker lo ha soltanto chiesto. Il namespace "moby" è il nome con cui Docker si presenta a containerd (e non c'entra nulla con i namespace del kernel del cap. 2: qui è solo un cassetto logico di containerd).

5. L'OCI Runtime Spec in carne e ossa. Il "bundle" che containerd ha preparato per runc è su disco:

       ID=$(docker inspect --format '{{.Id}}' lab-cap05)
       sudo ls /run/containerd/io.containerd.runtime.v2.task/moby/$ID/
       sudo cat /run/containerd/io.containerd.runtime.v2.task/moby/$ID/config.json

   Nel JSON (è lungo: scorri con calma, o aprilo con less) ritrova i tre capitoli precedenti: la sezione namespaces (cap. 2), le resources del cgroup (cap. 3), capabilities e il rootfs (cap. 4). Questo file È il contratto standard: chiunque lo rispetti può fare da runtime.

6. Il gran finale: un container con il solo runc, senza alcun demone. Prepara un bundle tuo (docker export appiattisce il filesystem del container in un solo tar: nota la differenza da docker save del cap. 4, che conserva i layer):

       mkdir -p ~/lab-cap05/bundle/rootfs && cd ~/lab-cap05/bundle
       docker create --name lab-cap05-exp alpine:3
       docker export lab-cap05-exp | tar -x -C rootfs
       docker rm lab-cap05-exp
       runc spec --rootless
       runc run demo

   Sei dentro una shell del container (prompt nuovo, hostname "runc"): guardati intorno con ps aux — di nuovo PID 1! — poi esci con exit. Il container muore con la shell: runc è un esecutore one-shot, non un demone.

7. Rispondi nel file answers.md che consegnerai (domande sotto), poi smonta il laboratorio:

       docker rm -f lab-cap05
       cd ~ && rm -rf ~/lab-cap05

   Le tre domande per answers.md: (a) chi è il padre diretto del processo del container, perché né dockerd né containerd compaiono nella catena, e a cosa serve il shim? (b) ricostruisci chi chiama chi quando digiti docker run (CLI → dockerd → containerd → shim → runc → processo) e spiega cosa dimostra il "cassetto" moby visto con ctr; (c) nel config.json, dove hai ritrovato gli ingredienti dei cap. 2-4? E che fine fa runc dopo aver avviato il container?

## Criteri di "fatto"

- [ ] Hai la catena dei padri annotata: processo → containerd-shim → PID 1, con dockerd e containerd vivi ma fuori dalla catena.
- [ ] Hai visto il tuo container elencato da ctr nel namespace moby, senza passare da docker.
- [ ] Nel config.json hai individuato le sezioni namespaces, resources (cgroup) e capabilities.
- [ ] Il container lanciato con runc run è partito, ci sei entrato (PID 1) e l'hai chiuso con exit.
- [ ] answers.md risponde alle tre domande e il laboratorio è smontato.
