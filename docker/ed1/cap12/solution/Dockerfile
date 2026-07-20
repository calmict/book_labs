# cap12 solution - a production image: small base, non-root, least privilege.
# A dedicated user runs the app; it owns only its app directory; and USER, written
# in the image config, makes every container start unprivileged. Combined with the
# Multi-Stage of chapter 11 (ship only the artifact) this is the production shape.
FROM busybox

# TODO 1 (12.2): a dedicated non-root user - the app never runs as root.
RUN adduser -D appuser

WORKDIR /app
COPY app.txt /app/app.txt

# TODO 2 (12.3): the user owns its app directory, and only that.
RUN chown -R appuser /app

# TODO 3 (12.2): drop to the non-root user for every container from this image.
USER appuser

CMD ["cat", "/app/app.txt"]
