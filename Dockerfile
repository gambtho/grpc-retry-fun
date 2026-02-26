# syntax=docker/dockerfile:1

# ─────────────────────────────────────────────
# Stage 1 – Build
# ─────────────────────────────────────────────
FROM golang:1.19-alpine AS builder

# golang:1.19-alpine ships with ca-certificates and git pre-installed;
# no extra apk step needed (and avoids any CDN reachability issues at build time).

WORKDIR /src

# Copy dependency manifests first for layer-cache efficiency
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source tree
COPY . .

# FIX 1: Create /app explicitly before writing the binary there, so the
#         output path is guaranteed to exist regardless of base-image defaults.
# Build a fully-static binary; no CGO, targeting Linux
RUN mkdir -p /app && \
    CGO_ENABLED=0 GOOS=linux go build \
      -trimpath \
      -ldflags="-s -w" \
      -o /app/greeter_server \
      ./greeter_server

# ─────────────────────────────────────────────
# Stage 2 – Runtime (distroless, non-root)
# ─────────────────────────────────────────────
# FIX 2: Upgraded from distroless/static-debian11 to debian12 — debian11 is
#         approaching end-of-life; debian12 receives active security patches.
FROM gcr.io/distroless/static-debian12:nonroot

# nonroot tag runs as uid 65532 (nonroot) by default – no extra USER directive needed.

# FIX 3: HEALTHCHECK is intentionally omitted. distroless/static contains no
#         shell, curl, or wget, so a Dockerfile HEALTHCHECK cannot execute.
#         Health-checking for this gRPC server is handled at the Kubernetes
#         layer via liveness/readiness/startup probes (grpc or exec probes).

# Copy CA certificates from the builder so gRPC TLS works if needed
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the compiled binary
COPY --from=builder /app/greeter_server /greeter_server

EXPOSE 50051

ENTRYPOINT ["/greeter_server"]
