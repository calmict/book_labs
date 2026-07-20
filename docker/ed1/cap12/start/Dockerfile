# cap12 start - a production image, to complete. Three gaps (TODO 1..3). As
# written the image works but runs as ROOT: no user, no ownership, no dropped
# privileges. The test fails.
FROM busybox

# TODO 1 (12.2): create a non-root user to run the app:
#     RUN adduser -D appuser

WORKDIR /app
COPY app.txt /app/app.txt

# TODO 2 (12.3): give that user ownership of its app directory (least privilege):
#     RUN chown -R appuser /app

# TODO 3 (12.2): drop privileges - run as the non-root user, written in the image:
#     USER appuser

CMD ["cat", "/app/app.txt"]
