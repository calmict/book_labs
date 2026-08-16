# Cap. 1 — Le tracce della storia sulla tua macchina

> Esercizio del **Capitolo 1 — Da Unix a Linux: la storia che spiega il presente** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- leggere la release del kernel distinguendo la versione di base dal suffisso aggiunto dalla distribuzione;
- risalire da un comando al pacchetto che lo fornisce e alla licenza dichiarata nei metadati locali;
- riconoscere un sistema merged-/usr e spiegare perché /bin punta a /usr/bin.

## Prerequisiti

- Un sistema Linux con Bash e accesso a un terminale.
- I comandi uname, ls e readlink.
- Un gestore pacchetti RPM oppure dpkg con il relativo database locale disponibile.
- Nessun privilegio di amministratore, container o accesso alla rete: tutte le operazioni sono in sola lettura.

## Consegna

1. Apri start/history-traces.sh. Completa la funzione kernel_trace affinché esegua uname -r, separi la terna numerica iniziale dall'eventuale suffisso e descriva che cosa rappresentano le due parti. L'output deve anche ricordare che la stringa, da sola, non rivela tutte le correzioni retroportate dalla distribuzione.

2. Completa package_license. Per ciascuno dei comandi ls e uname, trova prima il percorso dell'eseguibile e poi il pacchetto che lo contiene. Su un sistema RPM usa:

       rpm -qf /percorso/del/comando
       rpm -q --qf '%{LICENSE}\n' nome-pacchetto

   Su Debian o Ubuntu usa dpkg-query -S per trovare il pacchetto, quindi leggi il primo campo License nel file /usr/share/doc/nome-pacchetto/copyright. Stampa sempre il percorso, il pacchetto, la licenza e la fonte consultata: il testo mostrato da comando --help non basta a stabilire la licenza del pacchetto installato.

3. Completa bin_trace. Mostra il risultato di ls -ld /bin e, se /bin è un collegamento simbolico, stampane destinazione e percorso risolto con readlink. Spiega nell'output sia la separazione storica tra /bin e /usr/bin sia la ragione pratica della loro unificazione nei sistemi moderni.

4. Elimina il messaggio INCOMPLETE e l'exit 1 finale, poi verifica la sintassi ed esegui lo script senza sudo:

       bash -n start/history-traces.sh
       ./start/history-traces.sh

   Leggi i risultati sulla tua macchina: i suffissi del kernel, la sintassi delle licenze e perfino la presenza del collegamento /bin possono variare fra distribuzioni.

## Criteri di "fatto"

- [ ] Lo script stampa la release restituita da uname -r, la terna numerica di base e l'eventuale suffisso della distribuzione o della build.
- [ ] L'output spiega che i numeri identificano una linea di release, ma non dimostrano da soli l'assenza o la presenza di correzioni retroportate.
- [ ] Per ls e uname compaiono percorso, pacchetto di appartenenza, licenza dichiarata e fonte locale consultata.
- [ ] Lo script mostra che cos'è /bin sulla macchina in uso e, quando è un collegamento, dove conduce.
- [ ] La spiegazione collega la vecchia necessità di avere /bin disponibile prima di montare /usr alla moderna unificazione in /usr/bin.
- [ ] Lo script termina senza errori, non richiede privilegi e non modifica il sistema.
