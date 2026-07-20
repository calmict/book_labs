# cap11 start - strategic cache + Multi-Stage, to complete. Three gaps
# (TODO 1..3). As written the build stage is not named, the final image copies
# no artifact, and the dependencies are not placed before the source, so the
# test fails.
FROM busybox
WORKDIR /src
RUN mkdir -p /out

# TODO 3 (11.2): copy and "install" the dependencies BEFORE the source, so a
#   change to the source does not invalidate the (expensive) dependency step:
#     COPY deps.txt ./deps.txt
#     RUN cat deps.txt > /out/deps-installed.txt

COPY app.txt ./app.txt
RUN cat app.txt > /out/app

# --- final stage: only the finished artifact ships here ---
FROM busybox
# TODO 2 (11.4): copy ONLY the artifact from the build stage (needs TODO 1's name):
#     COPY --from=build /out/app /app
CMD ["cat", "/app"]

# TODO 1 (11.3): name the build stage above so the final stage can reference it -
#   change the first line to:  FROM busybox AS build
