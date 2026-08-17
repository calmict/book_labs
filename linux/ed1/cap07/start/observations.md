# Capitolo 7 — Osservazioni

## Parte 1 — Initramfs dell'host

- Kernel in esecuzione:
- Percorso e dimensione della copia:
- Versione di dracut indicata da lsinitrd:
- Moduli funzionali di dracut rilevanti:
- Moduli kernel per controller e disco:
- Moduli kernel per il filesystem della radice:
- Dispositivo e filesystem restituiti da findmnt:
- Perché questi driver sono presenti e altri non lo sono:

## Hook e passaggio alla radice vera

- Hook reale che attende o prepara il dispositivo root:
- Estratto rilevante letto con lsinitrd -f:
- Unità o script che effettua lo switch-root:
- Relazione fra /sysroot, initramfs e radice vera:

## Parte 2 — Avvio rotto nell'overlay

- Verifica del backing file:
- Dispositivo root prima della modifica:
- Opzione di omissione dichiarata da dracut --help nel guest:
- Verifica che virtio_blk sia assente dall'immagine alterata:
- Messaggio letterale del fallimento:
- Prove dalla shell dracut:

## Riparazione

- Initramfs sano usato temporaneamente da GRUB:
- Comando di ricostruzione senza omissioni:
- Verifica che virtio_blk sia tornato:
- Prova del mount della radice e del prompt di login:

## Pulizia e conclusione

- Verifica del processo QEMU:
- Verifica della rimozione dell'overlay:
- Perché questa modifica è sicura nell'overlay ma pericolosa sull'host:
