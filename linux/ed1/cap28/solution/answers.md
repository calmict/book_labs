# Observations

## Direct veth link

The route from labcap28a to 10.28.1.2 is directly connected through labcap28a0 and selects 10.28.1.1 as its source. No gateway is necessary because both addresses belong to 10.28.1.0/30.

## Bridged segment

labcap28fa, labcap28fb, and labcap28fc are ports of labcap28br inside labcap28fabric. The three endpoint addresses share 10.28.2.0/24, so each route lookup selects its local veth and its configured address. Traffic causes the bridge to learn source MAC addresses in its forwarding database.

## Cleanup

Deleting the four namespaces removes every interface after it has been moved out of the initial namespace. The cleanup also attempts to delete every temporary host-side veth name, covering a failure that occurs between veth creation and movement.
