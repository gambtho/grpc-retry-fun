# Multi-stage Dockerfile for gRPC Greeter Server
# Stage 1: Build the Go application
FROM golang:1.19-alpine AS builder

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the server binary
# CGO_ENABLED=0 for static binary, compatible with scratch/distroless images
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o greeter_server ./greeter_server/main.go

# Stage 2: Create minimal runtime image
FROM gcr.io/distroless/static:nonroot

# Copy the binary from builder
COPY --from=builder /build/greeter_server /greeter_server

# Use non-root user (from distroless/static:nonroot)
USER nonroot:nonroot

# Expose gRPC port
EXPOSE 50051

# Run the server
ENTRYPOINT ["/greeter_server"]
