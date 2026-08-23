# cap09 solution - the fundamental Dockerfile instructions. From a base (FROM),
# a working directory (WORKDIR), build-time steps (RUN) that create layers, the
# app loaded from the build context (COPY), a build-time parameter (ARG), an
# environment variable (ENV) and the default command (CMD). Each filesystem-
# changing instruction is one of the layers counted in chapter 8; ARG and CMD are
# metadata, not layers. The payload RUN cleans up inside the same instruction, so
# its layer weighs nothing: Dockerfile.naive splits it in two and pays for it.
FROM busybox
WORKDIR /app
RUN echo "built" > /app/built.txt

# TODO 1 (9.2): created and deleted in the same RUN, so the layer stays empty.
RUN dd if=/dev/urandom of=/tmp/payload.bin bs=1M count=8 2>/dev/null && rm -f /tmp/payload.bin

# TODO 2 (9.3): the app enters the image from the build context.
COPY greet.sh /app/greet.sh

# TODO 3 (9.4): a build-time parameter. It does not survive into the container,
# but the value stays readable in the image metadata: never pass secrets here.
ARG BUILD_TOKEN=changeme
RUN echo "token=$BUILD_TOKEN" >> /app/built.txt

# TODO 4 (9.4): the greeting lives in the image config, for every container.
ENV GREETING=ciao

# TODO 5 (9.5): the default command, run at startup with no arguments.
CMD ["sh", "/app/greet.sh"]
