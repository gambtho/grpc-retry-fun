# syntax=docker/dockerfile:1

# ── Stage 1: builder ──────────────────────────────────────────────────────────
FROM golang:1.19-alpine AS builder

WORKDIR /src

# Copy dependency manifests and vendored modules for offline, cache-friendly builds
COPY go.mod go.sum ./
COPY vendor/ vendor/

# Copy the rest of the source tree
COPY . .

# Build a fully-static server binary using vendored deps (no network required)
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -trimpath -ldflags="-s -w" \
    -o /app/greeter_server ./greeter_server

# ── Stage 2: runtime ─────────────────────────────────────────────────────────
FROM alpine:3.18

# Create non-root user/group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only the compiled binary from the builder stage
COPY --from=builder /app/greeter_server /app/greeter_server

# Ensure the binary is owned by the non-root user
RUN chown appuser:appgroup /app/greeter_server && chmod 550 /app/greeter_server

USER appuser

EXPOSE 50051

CMD ["/app/greeter_server"]
