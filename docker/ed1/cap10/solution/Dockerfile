# cap10 solution - ENTRYPOINT vs CMD and the startup process. ENTRYPOINT is the
# fixed executable (the captain), written in exec form so the script becomes
# PID 1 (chapter 7); CMD is the default argument list passed to ENTRYPOINT, which
# docker run arguments can override. CMD alone would be a fully overridable
# command; together, ENTRYPOINT stays and only its arguments change.
FROM busybox

# TODO 1 (10.3): the entrypoint script enters the image, executable.
COPY entry.sh /entry.sh

# TODO 2 (10.3): the fixed executable, in exec form -> the script is PID 1.
ENTRYPOINT ["/entry.sh"]

# TODO 3 (10.5): default arguments for ENTRYPOINT, overridable at run.
CMD ["default"]
