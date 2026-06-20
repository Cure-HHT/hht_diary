FROM golang:1.23-bookworm AS build
WORKDIR /src
COPY apps/sponsor-discovery/ ./apps/sponsor-discovery/
COPY contract/ ./contract/
WORKDIR /src/apps/sponsor-discovery
RUN CGO_ENABLED=0 go build -o /out/discovery .

FROM debian:12-slim
RUN useradd -r -s /bin/false appuser
COPY --from=build /out/discovery /app/discovery
USER appuser
EXPOSE 8086
ENTRYPOINT ["/app/discovery"]
