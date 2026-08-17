# Capitolo 20 — Soluzione

## Nome, UID e proprietà

L'inode memorizza 21001, non labcap20alice. Inizialmente la base utenti risolve quel numero al nome labcap20alice. Dopo usermod, 21001 non ha più una corrispondenza e stat mostra un proprietario sconosciuto o il numero. Quando labcap20replacement riceve 21001, lo stesso inode viene mostrato con il nuovo nome senza che chown abbia toccato il file.

## Volume condiviso

Il file creato nel primo container conserva UID 23001 e modo 0600 nel filesystem condiviso. Nel secondo container labcap20shared vale 24001: l'uguaglianza testuale del nome non concede alcun diritto, perché il kernel confronta i numeri. Una soluzione è allineare l'UID dell'identità che deve condividere il volume; un chown indiscriminato può invece rompere l'accesso dall'altro ambiente.

## Catena PAM

Una catena parte dal file del servizio e può continuare tramite include o substack. Le regole auth verificano l'identità, account applicano vincoli all'account, password gestiscono il cambio delle credenziali e session preparano o chiudono l'ambiente della sessione. I valori required, requisite, sufficient e optional determinano come ogni risultato contribuisce all'esito complessivo.

## Isolamento e cleanup

La soluzione avvia solo container con --rm e nomi labcap20. /etc/passwd e /etc/group modificati appartengono ai container e scompaiono alla loro uscita. Il trap rimuove eventuali container rimasti e la directory condivisa locale.

