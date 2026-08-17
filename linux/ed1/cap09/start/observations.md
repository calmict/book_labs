# Osservazioni / Observations

Completa questo foglio nella lingua in cui stai svolgendo il laboratorio.
Complete this worksheet in the language you are using for the lab.

## Processo vivo / Live process

- PID e PPID:
- Stato:
- File aperto trovato sotto fd:
- VmRSS da status:
- Rss da smaps_rollup:
- Collegamenti dei namespace:

## Zombie

- PID del padre:
- PID e stato del figlio:
- Risultato dopo waitpid:

## FIFO e segnali / FIFO and signals

- Stato osservato:
- Canale di attesa:
- Stato restituito da wait dopo SIGKILL:
- Il PID esiste ancora:
- Perché questa prova non dimostra lo stato D:

## dm-delay, stato D vero (opzionale, richiede sudo) / dm-delay, genuine D state (optional, needs sudo)

- STAT osservato durante il ritardo:
- State: da /proc/PID/status:
- Contatore di dmsetup status durante l'attesa:
- Perché una lettura bufferizzata (senza iflag=direct) rischia di non dimostrare nulla:
- Perché dmsetup create ha bisogno di --noudevsync su questa macchina:
- Perché la rimozione del device fallirebbe con "Device or resource busy" senza la regola udev temporanea, e perché il suo nome deve ordinarsi fra 10-dm.rules e 13-dm-disk.rules:
