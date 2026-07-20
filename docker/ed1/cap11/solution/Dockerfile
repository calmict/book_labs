# cap11 solution - strategic cache + Multi-Stage build. The build stage (the
# warehouse) assembles with all its tools; the final stage (the light ship)
# receives only the artifact via COPY --from. The dependencies are copied and
# "installed" before the source, so editing the source keeps the expensive
# dependency layer cached (chapter 8: a change invalidates only the layers above).
FROM busybox AS build
WORKDIR /src
RUN mkdir -p /out

# TODO 3 (11.2): dependencies first - rarely change, stay cached.
COPY deps.txt ./deps.txt
RUN cat deps.txt > /out/deps-installed.txt

# source last - changes often, rebuilds only from here up.
COPY app.txt ./app.txt
RUN cat app.txt > /out/app

# --- final stage: only the finished artifact ships here ---
FROM busybox
# TODO 2 (11.4): copy ONLY the artifact from the named build stage.
COPY --from=build /out/app /app
CMD ["cat", "/app"]
