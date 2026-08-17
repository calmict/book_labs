# Expected observations

## Inheritance

The project directory has access ACL entries for both named groups and a second set of default entries. A newly created file receives access entries derived from those defaults. A new subdirectory receives both access entries and default entries so that inheritance can continue below it. The creation mode can restrict the resulting mask; it cannot add permissions that the program did not request.

## The mask

For a file with an extended ACL, the group mode bits represent the ACL mask. Therefore chmod 640 sets the mask to r--. The owning group and every named user or group entry are limited by that mask, even when their stored entry still says rwx or r-x. Running setfacl -m m::rwx restores the effective rights without rebuilding the named entries.

## Copies

GNU cp -a explicitly preserves metadata and retains the named ACL. GNU cp --no-preserve=mode creates a copy without cloning the source ACL. Redirecting cat also copies bytes rather than inode metadata, so it does not clone the source ACL. Always verify the result with getfacl because filesystems and non-GNU copy tools can have different capabilities.

## Cleanup

The demonstration script installs an EXIT trap and removes its scratch directory whether it succeeds or fails.
