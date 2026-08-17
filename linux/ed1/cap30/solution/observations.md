# Osservazioni / Observations

La shell isolata vede se stessa come PID 1, UID 0 e usa l'hostname labcap30-shell. Il suo namespace di rete è diverso da quello dell'host e contiene soltanto loopback.

The isolated shell sees itself as PID 1 and UID 0 and uses the labcap30-shell hostname. Its network namespace differs from the host network namespace and contains only loopback.

La riga di mappatura associa l'UID 0 interno a un singolo UID esterno: quello dell'utente che ha eseguito unshare. L'identità root vale quindi soltanto nel namespace utente e non concede privilegi amministrativi sull'host.

The mapping line associates internal UID 0 with one external UID: the UID of the user that ran unshare. Root identity therefore applies only inside the user namespace and grants no administrative privileges on the host.

Un processo nel nuovo namespace PID può vedere se stesso e i propri discendenti, ma non i processi del namespace PID antenato. nsenter crea un discendente dentro il namespace scelto, perciò conserva questa vista limitata.

A process in the new PID namespace can see itself and its descendants, but it cannot see processes in the ancestor PID namespace. nsenter creates a descendant in the selected namespace, so the restricted view is preserved.
