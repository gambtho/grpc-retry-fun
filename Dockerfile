# syntax=docker/dockerfile:1

# ── Stage 1: builder ──────────────────────────────────────────────────────────
FROM golang:1.19-alpine AS builder

WORKDIR /src

# Copy dependency manifests first for layer-cache efficiency
COPY go.mod go.sum ./

# Download dependencies (uses module cache layer)
RUN go mod download

# Copy the full source tree
COPY . .

# Build a fully-static server binary
# CGO_ENABLED=0 produces a self-contained binary with no libc dependency
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" \
    -o /app/greeter_server ./greeter_server

# ── Stage 2: runtime ─────────────────────────────────────────────────────────
# Use the non-debug, root-default distroless image so the server can bind to
# port 80 (a privileged port) without requiring CAP_NET_BIND_SERVICE.
# The pod security context sets runAsNonRoot: false to match this.
FROM gcr.io/distroless/static-debian12

WORKDIR /app

# Copy only the compiled binary from the builder stage
COPY --from=builder /app/greeter_server /app/greeter_server

# The Kubernetes manifests set targetPort: 80 so the gRPC server is started
# on port 80 to keep the container port and service targetPort aligned.
EXPOSE 80

CMD ["/app/greeter_server", "-port", "80"]
