# syntax=docker/dockerfile:1

# ---- Build stage ----
# golang:1.21-alpine ships with ca-certificates; no extra apk install needed.
FROM golang:1.21-alpine AS builder

WORKDIR /src

# Cache dependency layer separately from source
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build the server binary; CGO disabled for a fully-static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/greeter_server ./greeter_server/

# ---- Runtime stage ----
FROM scratch

# Copy CA certs for outbound TLS (gRPC may need them)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Copy the compiled binary
COPY --from=builder /out/greeter_server /greeter_server

# Run as non-root UID (scratch has no user database; set numeric UID directly)
USER 65534:65534

EXPOSE 50051

# HEALTHCHECK is not supported in scratch-based images via HTTP;
# gRPC health checks require grpc-health-probe in the runtime image.
# Explicitly declare none to satisfy linting expectations.
HEALTHCHECK NONE

ENTRYPOINT ["/greeter_server"]
