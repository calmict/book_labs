# Cap. 22 — Due gruppi, una cartella

> Esercizio del **Capitolo 22 — ACL e permessi estesi** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- concedere diritti diversi a due gruppi sulla stessa cartella;
- impostare ACL predefinite che si propagano ai nuovi contenuti;
- interpretare la mask e l'effetto di chmod sulle ACL estese;
- verificare quali metodi di copia conservano le ACL.

## Prerequisiti

- Un host Linux con un filesystem che supporti le ACL POSIX.
- I comandi setfacl e getfacl, forniti dal pacchetto acl.
- Due gruppi già presenti nel sistema. Per la dimostrazione automatica sono preferibili due gruppi elencati da id -Gn.

Verifica i requisiti prima di iniziare:

    command -v setfacl getfacl
    findmnt -T . -no FSTYPE,OPTIONS
    getent group | head

Tutte le prove avvengono in una cartella scratch locale all'esercizio. Non creare utenti o gruppi sull'host.

## Consegna

1. Copia il modello delle risposte e scegli due gruppi esistenti, uno con ruolo di scrittura e uno con ruolo di sola lettura:

       cp start/answers.md answers.md
       id -Gn
       getent group

2. Crea una cartella scratch e rendila inizialmente accessibile soltanto al proprietario:

       mkdir -p labcap22-scratch/project
       chmod 700 labcap22-scratch/project

3. Con setfacl assegna rwx al gruppo di scrittura e r-x al gruppo di lettura. Imposta anche ACL predefinite equivalenti sulla cartella. Mantieni a --- il gruppo proprietario e gli altri utenti.

4. Crea nella cartella un file plan.txt e una sottocartella docs. Usa getfacl per dimostrare che entrambi hanno ereditato le voci previste. Spiega perché l'ACL predefinita della cartella diventa ACL di accesso sui nuovi oggetti.

5. Sul file plan.txt esegui un chmod distratto:

       chmod 640 labcap22-scratch/project/plan.txt

   Esamina di nuovo il file. Individua la mask, le annotazioni effective e il motivo per cui i gruppi nominati non hanno più i diritti attesi. Ripristina la mask con setfacl senza ricreare tutte le voci.

6. Aggiungi al file un'ACL nominata evidente, poi produci tre copie:

   - una con cp -a;
   - una con cp --no-preserve=mode;
   - una tramite redirezione dell'output di cat.

   Confronta getfacl sui quattro file e annota quali copie conservano le voci nominate. La redirezione crea un nuovo inode secondo umask e ACL predefinite della cartella di destinazione, non clona i metadati del file sorgente.

7. Confronta i tuoi risultati con solution/answers.md oppure esegui la dimostrazione automatica:

       ./solution/run.sh

8. Elimina answers.md e la cartella scratch quando hai terminato.

## Criteri di "fatto"

- [ ] La cartella assegna diritti differenti a due gruppi oltre ai nove bit tradizionali.
- [ ] Un file e una sottocartella nuovi ereditano le ACL predefinite.
- [ ] Hai osservato chmod modificare la mask e hai ripristinato i diritti con setfacl.
- [ ] Hai confrontato una copia che conserva le ACL con due copie che non clonano l'ACL nominata.
- [ ] Hai compilato answers.md e rimosso la cartella scratch.
