# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────
# Stage 1: Build
# Uses the official Go image (Debian-based) so no apk needed;
# all required CA certs and timezone data are already present.
# ──────────────────────────────────────────────
FROM golang:1.21 AS builder

WORKDIR /build

# Cache dependency downloads separately from the source build
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy the full source tree
COPY . .

# Build a statically-linked, stripped binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath \
    -ldflags="-s -w" \
    -o /out/greeter_server \
    ./greeter_server

# ──────────────────────────────────────────────
# Stage 2: Runtime
# gcr.io/distroless/static-debian12:nonroot is ~2 MB,
# contains CA certs + timezone data, no shell.
# ──────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot AS runtime

# Copy the compiled binary
# Note: gcr.io/distroless/static-debian12 already includes CA certs and
# timezone data, so no extra COPY needed for those.
COPY --from=builder /out/greeter_server /greeter_server

# gRPC server listens on 50051 by default
EXPOSE 50051

# Run as the built-in nonroot user (uid 65532)
USER nonroot:nonroot

ENTRYPOINT ["/greeter_server"]
