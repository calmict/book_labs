# Cap. 21 — Cancellare un file che non puoi leggere

> Esercizio del **Capitolo 21 — Permessi, setuid e capabilities** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- collegare creazione e cancellazione ai permessi della directory anziché a quelli del file;
- distinguere il permesso di attraversamento da quello di elencazione;
- confrontare un eseguibile setuid root con lo stesso eseguibile dotato della sola capability necessaria;
- verificare privilegi effettivi e cleanup senza modificare binari o account dell'host.

## Prerequisiti

- Un host Linux con Bash, coreutils e un compilatore C.
- Docker funzionante e un'immagine rockylinux:9 disponibile localmente o scaricabile per la prova con un utente non privilegiato.
- Supporto del kernel per le file capabilities.
- Nessun dato importante nella directory solution/labcap21-work: lo script la ricrea e la elimina.

## Consegna

1. In una directory di prova di tua proprietà, crea un file e rimuovi ogni suo permesso. Verifica che cat fallisca ma rm riesca quando la directory concede scrittura e attraversamento.

       mkdir labcap21-delete
       printf 'segreto\n' > labcap21-delete/unreadable.txt
       chmod 000 labcap21-delete/unreadable.txt
       cat labcap21-delete/unreadable.txt
       rm labcap21-delete/unreadable.txt

2. Ricrea il file. Togli prima la scrittura dalla directory mantenendo l'attraversamento, poi togli l'attraversamento mantenendo la scrittura. In entrambi i casi rm deve fallire. Ripristina sempre il modo 0700 prima del cleanup.

       chmod 500 labcap21-delete
       rm labcap21-delete/unreadable.txt
       chmod 600 labcap21-delete
       rm labcap21-delete/unreadable.txt
       chmod 700 labcap21-delete

3. Crea una seconda directory con un file leggibile dal nome noto. Assegna alla directory il solo permesso di attraversamento, modo 0111. Verifica che cat sul percorso noto riesca mentre ls sulla directory fallisca: leggere una voce nota e ottenere l'elenco completo sono operazioni diverse.

       chmod 111 labcap21-traverse
       cat labcap21-traverse/known.txt
       ls labcap21-traverse

4. Compila raw_socket_probe.c, un piccolo programma che apre un socket ICMP raw e non invia pacchetti. Avvia un container effimero con un utente labcap21user e copia il programma in una directory scratch isolata. Non applicare mai setuid o setcap al file sorgente, a un binario di sistema o a un file fuori dalla scratch.

5. Come labcap21user, verifica che la copia senza privilegi non possa aprire il socket. Imposta temporaneamente proprietario root e bit setuid soltanto sulla copia e verifica che funzioni con EUID 0. Rimuovi quindi setuid e assegna la sola cap_net_raw:

       chown root:root raw-socket-probe
       chmod 4755 raw-socket-probe
       runuser -u labcap21user -- ./raw-socket-probe
       chmod u-s raw-socket-probe
       setcap cap_net_raw=ep raw-socket-probe
       getcap raw-socket-probe
       runuser -u labcap21user -- ./raw-socket-probe

   La seconda esecuzione deve aprire il socket mantenendo EUID non privilegiato. La capability concede la specifica operazione di rete richiesta, mentre setuid consegna al processo l'intera identità root.

6. Rimuovi il container, la scratch e tutte le directory di prova anche se un passo fallisce. Registra gli output in answers.md oppure esegui la soluzione:

       ./solution/run.sh

## Criteri di "fatto"

- [ ] Hai cancellato un file illeggibile grazie a scrittura e attraversamento sulla directory.
- [ ] Hai osservato rm fallire sia senza scrittura sia senza attraversamento sulla directory.
- [ ] Il percorso noto è accessibile in una directory modo 0111, ma l'elenco con ls è negato.
- [ ] Setuid e setcap sono stati applicati soltanto alla copia nella scratch isolata del container.
- [ ] La prova setuid funziona con EUID 0; la prova cap_net_raw funziona mantenendo l'EUID dell'utente labcap21user.
- [ ] Nessun account, attributo di sicurezza, container o file di prova rimane sull'host.

