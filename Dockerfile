# Multi-stage build for gRPC server
# Stage 1: Build the Go application
FROM golang:1.21-alpine AS builder

# Set working directory
WORKDIR /build

# Copy go mod files first for better layer caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the greeter_server binary
# CGO_ENABLED=0 for static binary, compatible with distroless
# -ldflags="-w -s" strips debug info to reduce binary size
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -a -installsuffix cgo \
    -o greeter_server \
    ./greeter_server/main.go

# Stage 2: Create minimal runtime image
FROM gcr.io/distroless/static-debian11:nonroot

# Copy the binary from builder
COPY --from=builder /build/greeter_server /app/greeter_server

# Use non-root user (distroless nonroot user has UID 65532)
USER 65532:65532

# Set working directory
WORKDIR /app

# Expose gRPC port
EXPOSE 50051

# Set environment variables
ENV PORT=50051

# Health check metadata (distroless doesn't support HEALTHCHECK, handled by K8s)
LABEL org.opencontainers.image.title="grpc-retry-fun" \
      org.opencontainers.image.description="gRPC Greeter Server with retry functionality" \
      org.opencontainers.image.version="1.0" \
      org.opencontainers.image.source="https://github.com/thgamble/grpc-retry-fun"

# Run the server
ENTRYPOINT ["/app/greeter_server"]
CMD ["--port=50051"]
