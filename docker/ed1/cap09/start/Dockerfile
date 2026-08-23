# cap09 start - a Dockerfile with the fundamental instructions, to complete.
# Five gaps (TODO 1..5). As written the image builds, but it never proves the
# same-layer cleanup, does not load the app, declares no build parameter, sets no
# greeting and has no default command: the test fails.
FROM busybox
WORKDIR /app
RUN echo "built" > /app/built.txt

# TODO 1 (9.2): create the temporary payload and delete it IN THE SAME RUN, so
# the layer never carries it. Dockerfile.naive does the same work in two RUNs,
# and there the payload stays in the image forever even though it was deleted:
#     RUN dd if=/dev/urandom of=/tmp/payload.bin bs=1M count=8 2>/dev/null && rm -f /tmp/payload.bin

# TODO 2 (9.3): COPY the app script from the build context into the WORKDIR:
#     COPY greet.sh /app/greet.sh

# TODO 3 (9.4): declare the build-time parameter that the RUN below stamps:
#     ARG BUILD_TOKEN=changeme
RUN echo "token=$BUILD_TOKEN" >> /app/built.txt

# TODO 4 (9.4): set the default greeting as an environment variable:
#     ENV GREETING=ciao

# TODO 5 (9.5): declare the default command that runs the app at runtime:
#     CMD ["sh", "/app/greet.sh"]
