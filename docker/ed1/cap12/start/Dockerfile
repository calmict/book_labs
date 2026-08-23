FROM alpine:3.22 AS build
RUN adduser -D -u 10001 appuser && apk add --no-cache build-base
COPY app.c /src/app.c
COPY app.txt /app/app.txt
RUN cc -Os -static -s -o /appbin /src/app.c && chown -R appuser /app

FROM scratch
COPY --from=build /appbin /appbin
COPY --from=build --chown=10001:10001 /app/app.txt /app/app.txt
COPY --from=build /etc/passwd /etc/passwd

# TODO 1 (12.2): declare the dedicated non-root account: USER appuser
# TODO 2 (12.4): declare the real health probe:
#   HEALTHCHECK --interval=1s --timeout=1s --retries=5 CMD ["/appbin", "health"]
ENTRYPOINT ["/appbin"]
