# Capitolo 21 — Soluzione

## Cancellazione e directory

rm rimuove un nome dalla directory. Con write e search sulla directory, il proprietario può rimuovere quella voce anche se il file ha modo 000 e non può essere letto. Senza write non può modificare l'elenco; senza search non può risolvere la voce da rimuovere. Lo sticky bit, gli ACL e altri controlli potrebbero aggiungere ulteriori vincoli in ambienti diversi.

## Attraversamento senza elenco

Il permesso x su una directory consente di cercare un nome già noto e proseguire nel percorso. Il permesso r consente di leggere l'elenco dei nomi. Con modo 0111, cat può aprire known.txt grazie al nome noto e ai permessi del file, mentre ls non può leggere l'elenco della directory.

## Da setuid a capability

Senza privilegi, raw_socket_probe non può aprire un socket ICMP raw. Con setuid root il processo ottiene EUID 0 e l'operazione riesce, ma anche tutto il resto del codice gira con l'identità root. Dopo aver rimosso setuid, cap_net_raw consente la stessa apertura lasciando invariato l'EUID non privilegiato e limita l'autorità alla classe di operazioni di rete necessaria.

## Isolamento e cleanup

Il programma compilato viene montato in sola lettura nel container e copiato su una scratch tmpfs effimera. setuid e setcap interessano solo quella copia. labcap21user, la copia e i relativi attributi scompaiono con il container --rm; il trap elimina inoltre il container per nome e i file ordinari creati nella directory dell'esercizio.

