# Multi-stage Dockerfile for gRPC Go application
# Stage 1: Build stage
FROM golang:1.19 AS builder

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the server binary
# CGO_ENABLED=0 for static binary
# -ldflags="-w -s" to strip debug info and reduce size
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o greeter_server \
    ./greeter_server/main.go

# Stage 2: Runtime stage using distroless
FROM gcr.io/distroless/static-debian11:nonroot

# Copy the binary from builder
COPY --from=builder /build/greeter_server /app/greeter_server

# Use non-root user (distroless nonroot variant uses UID 65532)
USER 65532:65532

# Expose gRPC port
EXPOSE 50051

# Set working directory
WORKDIR /app

# Run the server
ENTRYPOINT ["/app/greeter_server"]
CMD ["-port=50051"]
