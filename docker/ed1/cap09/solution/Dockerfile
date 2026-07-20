# cap09 solution - the fundamental Dockerfile instructions. From a base (FROM),
# a working directory (WORKDIR), a build-time step (RUN) that creates a layer,
# the app loaded from the build context (COPY), an environment variable (ENV)
# and the default command (CMD). Each filesystem-changing instruction is one of
# the layers counted in chapter 8; CMD is metadata, not a layer.
FROM busybox
WORKDIR /app
RUN echo "built" > /app/built.txt

# TODO 1 (9.3): the app enters the image from the build context.
COPY greet.sh /app/greet.sh

# TODO 2 (9.4): the greeting lives in the image config, for every container.
ENV GREETING=ciao

# TODO 3 (9.5): the default command, run at startup with no arguments.
CMD ["sh", "/app/greet.sh"]
