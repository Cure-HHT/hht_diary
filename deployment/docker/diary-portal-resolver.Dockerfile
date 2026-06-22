FROM golang:1.23-bookworm AS build
WORKDIR /src
COPY apps/diary-portal-resolver/ ./apps/diary-portal-resolver/
WORKDIR /src/apps/diary-portal-resolver
# Static, stripped binary so it runs on a distroless base with minimal size.
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/diary-portal-resolver .

# Distroless static (nonroot): no shell / package manager, runs as uid 65532,
# ~2 MB base. The service makes no outbound calls, so it needs no OS at all —
# minimal attack surface for a key-verifying endpoint, and a small image means a
# faster Cloud Run cold start (scale-to-zero, min-instances=0).
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/diary-portal-resolver /app/diary-portal-resolver
USER nonroot:nonroot
EXPOSE 8086
ENTRYPOINT ["/app/diary-portal-resolver"]
