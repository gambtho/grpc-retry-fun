# Stage 1: Build the Go binary
FROM golang:1.19-alpine AS builder

# Install build dependencies
# ca-certificates needed for downloading Go modules over HTTPS
RUN apk add --no-cache ca-certificates

# Set working directory
WORKDIR /build

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies and verify them
RUN go mod download && go mod verify

# Copy the entire source code
COPY . .

# Build the server binary with optimizations
# CGO_ENABLED=0: Build a static binary without CGO
# -ldflags="-w -s": Strip debug symbols to reduce binary size
#   -w: Omit DWARF symbol table
#   -s: Omit symbol table and debug information
# -trimpath: Remove file system paths from the binary
# -a: Force rebuilding of packages that are already up-to-date
# -installsuffix cgo: Ensure the output is statically linked
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -a \
    -installsuffix cgo \
    -ldflags="-w -s -extldflags '-static'" \
    -trimpath \
    -o server \
    ./greeter_server/main.go

# Stage 2: Create minimal runtime image
FROM gcr.io/distroless/static-debian11:nonroot

# Add metadata labels
LABEL maintainer="grpc-retry-fun" \
      description="gRPC Greeter Server with retry capabilities" \
      version="1.0" \
      org.opencontainers.image.source="https://github.com/runner/grpc-retry-fun" \
      org.opencontainers.image.title="gRPC Retry Fun" \
      org.opencontainers.image.description="gRPC server demonstrating retry patterns"

# Copy binary from builder with proper ownership
# Using --chown to avoid running chown as a separate layer
COPY --from=builder --chown=nonroot:nonroot /build/server /app/server

# Set working directory
WORKDIR /app

# Expose gRPC port (documentation only in distroless)
EXPOSE 50051

# Use nonroot user (UID 65532) - already set as default in distroless:nonroot
# Explicitly setting it for clarity and security audits
USER nonroot:nonroot

# Health check would go here if we had a health endpoint
# distroless doesn't have curl/wget, so this would need a custom implementation

# Run the server binary
# Note: distroless doesn't have shell, so use exec form
ENTRYPOINT ["/app/server"]

# Default arguments (can be overridden at runtime)
CMD ["-port=50051"]
