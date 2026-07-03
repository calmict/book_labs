# Cap. 1 — Un container è solo un processo (verificalo con i tuoi occhi)

> Esercizio del **Capitolo 1 — Il problema che i container risolvono** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:
- distinguere cosa isola davvero un container rispetto a una macchina virtuale;
- osservare un processo "containerizzato" contemporaneamente dall'host e dall'interno del container, per toccare con mano che si tratta dello stesso processo Linux visto da due angolazioni diverse;
- collegare l'osservazione pratica al concetto teorico del capitolo: isolamento di processi vs virtualizzazione dell'hardware.

## Prerequisiti

- Un host Linux (nativo o VM) con accesso a un terminale.
- Docker o Podman installati e funzionanti (prova con "docker run hello-world" o equivalente).

> ⚠️ **Nota per WSL2 / Docker Desktop:** con Docker Desktop il demone gira in una
> VM separata, quindi al passo 3 il PID restituito da docker inspect **non
> esiste** nella tua distro WSL e il comando ps del passo 3 fallirà. Su WSL2 usa
> **Podman** (che gira nella tua distro), oppure esegui i comandi del passo 3
> dentro la distro docker-desktop.
- Nessun cluster Kubernetes richiesto: questo capitolo lavora sotto Kubernetes, non dentro Kubernetes.
- Familiarità minima con la riga di comando (ps, grep).

## Consegna

1. Sull'host, avvia un container di lunga durata:

       docker run -d --name lab-cap01 alpine:3 sleep infinity

   (o l'equivalente comando che avvii un processo "sleep infinity" in un container).

2. Dall'host, trova il PID del processo sleep così come lo vede il kernel:

       docker inspect --format '{{.State.Pid}}' lab-cap01

3. Ispeziona quel PID direttamente dall'host, senza passare da docker exec:

       ps -p <PID> -o pid,ppid,cmd
       cat /proc/<PID>/status | head -5

4. Ora entra nel container ed esamina lo stesso identico processo dal suo punto di vista:

       docker exec lab-cap01 ps aux

   Annota il PID che il processo vede di sé stesso da dentro.

5. Confronta i due numeri di PID (host vs container) e rispondi per iscritto, in un file answers.md che consegnerai: perché sono diversi pur trattandosi dello stesso identico processo? Cosa ti dice questo sul significato di "isolamento" contrapposto a "virtualizzazione"?

6. Ripeti il confronto osservando anche l'hostname (comando hostname sull'host, poi "docker exec lab-cap01 hostname") e l'elenco processi completo (ps aux sull'host e dentro al container).

7. Ferma e rimuovi il container di laboratorio:

       docker rm -f lab-cap01

## Criteri di "fatto"

- [ ] Hai il PID del processo così come appare sull'host e così come appare dentro il container, e sono numeri diversi.
- [ ] Il file answers.md contiene una spiegazione (anche breve, 4-6 righe) del perché lo stesso processo ha due PID diversi, collegandola al concetto di "processo Linux visto attraverso una finestra diversa" piuttosto che "macchina separata".
- [ ] Hai verificato che l'hostname visto da dentro il container è diverso da quello dell'host.
- [ ] Il container di laboratorio è stato rimosso a fine esercizio.
