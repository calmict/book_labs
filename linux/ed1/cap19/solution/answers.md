# Capitolo 19 — Soluzione

## Dati sporchi

write può restituire dopo aver copiato i byte nella page cache. Dirty mostra pagine modificate che il kernel non ha ancora completato sul livello di memorizzazione. Il valore può salire dopo la scrittura e scendere durante il writeback o dopo sync. Poiché /proc/meminfo descrive l'intero host, altri processi e il writeback concorrente rendono la misura indicativa, non esclusiva del file di prova.

## Durata delle scritture

La scrittura senza fsync misura soprattutto copia e gestione della cache. conv=fsync richiede una sincronizzazione prima che dd termini e di solito aggiunge attesa. Cache, filesystem, dispositivo e carico rendono necessarie più ripetizioni per un confronto prestazionale serio.

## Sostituzione atomica e durevole

durable_replace.py ripete write finché tutti i byte sono stati accettati, esegue fsync sul descrittore del file temporaneo, lo chiude, usa replace per la rinomina atomica e infine esegue fsync sul descrittore della directory. La rinomina impedisce ai lettori di vedere una pubblicazione parziale; il fsync della directory rende persistente la modifica del nome.

## Verifica senza crash reale

dd conv=fsync, cmp e sha256sum verificano che la copia sia completa e che la richiesta di sincronizzazione sia stata eseguita prima del ritorno del comando. Non provano il recupero dopo una perdita improvvisa di alimentazione. Quel test richiede una macchina virtuale sacrificabile e il controllo del file dopo il riavvio forzato.

## Pila dei dispositivi

findmnt collega la directory a mount, sorgente e tipo di filesystem. lsblk mostra dispositivi, partizioni, volumi e relazioni parentali. La forma esatta dipende dall'host; entrambi i comandi sono usati in sola lettura.

