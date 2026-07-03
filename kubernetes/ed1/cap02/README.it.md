# Cap. 2 — Un container a mano, senza Docker

> Esercizio del **Capitolo 2 — Linux Namespaces: l'arte dell'illusione** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- costruire un "container" funzionante usando solo strumenti Linux di base (unshare, chroot), senza alcun container runtime;
- riconoscere i namespace come il vero ingrediente dell'illusione: PID 1, hostname privato, rete isolata;
- leggere e confrontare i file di /proc/[pid]/ns per dimostrare, inode alla mano, che due processi vivono in namespace diversi.

## Prerequisiti

- Aver completato il cap. 1 (il concetto di "stesso processo, due viste").
- Un host Linux con privilegi sudo; servono unshare (pacchetto util-linux) e wget o curl.
- Circa 10 MB di spazio disco per il mini-rootfs.
- Nota: a differenza del cap. 1, questo esercizio funziona anche su WSL2 senza accorgimenti — qui non serve alcun demone, si parla direttamente col kernel.

> 💡 **Niente sudo?** Puoi fare tutto anche da utente normale: togli sudo dal
> passo 2 e aggiungi le opzioni --user --map-root-user subito dopo unshare.
> È lo USER namespace del §2.2.6 in azione: ti dà un "root finto" valido solo
> dentro il container, ed è lo stesso meccanismo dei container rootless di
> Podman.

## Consegna

1. Prepara la cartella di lavoro e scarica il mini-rootfs Alpine (una qualsiasi versione recente va bene; qui ne fissiamo una per riproducibilità):

       mkdir -p ~/lab-cap02/rootfs && cd ~/lab-cap02
       wget https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-minirootfs-3.24.1-x86_64.tar.gz
       tar -xzf alpine-minirootfs-*.tar.gz -C rootfs

2. Crea il container a mano: nuovi namespace PID, mount, UTS, IPC e di rete, e radice del filesystem dentro rootfs:

       sudo unshare --pid --fork --mount --uts --ipc --net chroot rootfs /bin/sh

   Ti ritrovi in una shell "dentro" il container. Lasciala aperta: i prossimi passi si fanno da qui e da un secondo terminale sull'host.

3. Dentro il container, sistema il PATH (la chroot eredita quello dell'host, che potrebbe non includere le cartelle giuste di Alpine), monta /proc e guarda l'albero dei processi:

       export PATH=/usr/sbin:/usr/bin:/sbin:/bin
       mount -t proc proc /proc
       ps aux

   Annota cosa vedi: quanti processi ci sono, e che PID ha la tua shell?

4. Sempre dentro, cambia l'hostname e verifica l'isolamento UTS e di rete:

       hostname container-a-mano && hostname
       ip addr

   Dal secondo terminale sull'host verifica che l'hostname dell'host NON sia cambiato, e confronta ip addr: dentro c'è solo una loopback spenta, fuori la tua rete vera.

5. Ora dimostra, inode alla mano, che i due mondi vivono in namespace diversi (è il §2.5 del manuale reso tangibile). Dentro il container, dove la tua shell è il PID 1:

       for ns in pid uts net user; do echo "$ns: $(readlink /proc/$$/ns/$ns)"; done

   E dal secondo terminale sull'host, lo stesso identico comando:

       for ns in pid uts net user; do echo "$ns: $(readlink /proc/$$/ns/$ns)"; done

   Stesso comando, due risposte diverse: confronta i numeri di inode tra le due serie. Quali sono diversi? Ce n'è qualcuno uguale?

6. Rispondi per iscritto nel file answers.md che consegnerai: in cosa il tuo comando unshare è concettualmente equivalente al docker run del cap. 1? Cosa NON hai ottenuto rispetto a un vero container (immagini e layer, limiti di risorse, sicurezza)? Perché serve l'opzione --fork insieme a --pid?

7. Smonta il laboratorio: esci dalla shell del container (exit) e rimuovi la cartella:

       rm -rf ~/lab-cap02

## Criteri di "fatto"

- [ ] Dentro il container ps aux mostra la tua shell come PID 1 e un elenco processi quasi vuoto.
- [ ] L'hostname dentro è "container-a-mano" e quello dell'host è rimasto intatto.
- [ ] Hai il confronto degli inode di /proc/[pid]/ns: pid, uts e net diversi tra container e host. E hai notato il caso di user: uguale nella variante sudo (non l'abbiamo isolato), diverso nella variante rootless (è il namespace che rende possibili tutti gli altri senza root).
- [ ] Il file answers.md risponde alle tre domande del passo 6.
- [ ] La cartella di laboratorio è stata rimossa.
