# Cap. 23 — Fermare root con una politica

> Esercizio del **Capitolo 23 — Mandatory Access Control e hardening** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Avanzato

## Obiettivi

Al termine di questo laboratorio saprai:

- riconoscere un diniego SELinux che si manifesta come risposta HTTP 403;
- correggere l'etichetta di un contenuto senza allargare i permessi Unix;
- usare una modalità permissiva limitata a un solo dominio per la diagnosi;
- dimostrare che gli argomenti di un processo non sono un posto sicuro per i segreti.

## Prerequisiti

- Rocky Linux con SELinux in modalità Enforcing.
- Privilegi amministrativi per chcon, runcon e semanage.
- Python 3, curl e i pacchetti policycoreutils e policycoreutils-python-utils.
- Docker o Podman per la prova isolata con due utenti.

Non usare setenforce. Non modificare configurazioni persistenti, servizi di sistema o permessi Unix durante la correzione del 403.

## Consegna

1. Copia il modello delle risposte e registra stato e contesto iniziali:

       cp start/answers.md answers.md
       getenforce
       id -Z
       ls -Zd .

2. Esamina solution/selinux-lab.sh. Lo script crea un server HTTP effimero su una porta non privilegiata, assegna il dominio httpd_t soltanto al processo del laboratorio con runcon e prepara un file con etichetta non leggibile da quel dominio. Non avvia né riavvia servizi reali.

3. Esegui la prova SELinux con privilegi amministrativi:

       sudo ./solution/selinux-lab.sh

   Registra il codice 403, il contesto del processo e l'etichetta del file. Verifica che i bit di modo del file non cambino quando chcon assegna httpd_sys_content_t e la richiesta passa a 200.

4. Osserva la fase diagnostica dello stesso script. Il file torna all'etichetta errata, ma semanage permissive -a httpd_t rende permissivo soltanto quel tipo. La richiesta riesce e l'AVC resta diagnosticabile. Lo script rimuove subito l'eccezione con semanage permissive -d httpd_t. Non sostituire questi comandi con un toggle globale.

5. Esegui la seconda prova:

       ./solution/proc-arguments-lab.sh

   In un container effimero, un utente avvia un processo con labcap23-demo-secret fra gli argomenti. Un altro utente legge /proc/PID/cmdline e stampa lo stesso valore. Spiega perché password, token e chiavi non devono essere passati sulla riga di comando.

6. Puoi eseguire entrambe le verifiche con:

       sudo ./solution/run.sh

   Lo script segnala esplicitamente un ambiente incompatibile invece di dichiarare verificata una prova non eseguita.

## Criteri di "fatto"

- [ ] Hai riprodotto un 403 causato dall'etichetta e un 200 dopo chcon, senza chmod.
- [ ] Hai diagnosticato il diniego rendendo permissivo soltanto httpd_t e hai poi rimosso l'eccezione.
- [ ] Un secondo utente nel container ha letto il segreto da /proc/PID/cmdline.
- [ ] Nessun server o container di laboratorio è rimasto attivo e la directory scratch è stata rimossa.
- [ ] answers.md contiene contesti, codici HTTP e spiegazioni richieste.
