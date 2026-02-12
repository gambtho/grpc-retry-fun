# Multi-stage Dockerfile for gRPC Greeter Server
# Stage 1: Build the Go application
FROM golang:1.19-alpine AS builder

# Set working directory
WORKDIR /build

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the entire source code
COPY . .

# Build the server binary
# CGO_ENABLED=0 for static binary, GOOS=linux for Linux target
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o greeter_server ./greeter_server/main.go

# Stage 2: Create minimal runtime image using scratch for smallest size
FROM scratch

# Set working directory
WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /build/greeter_server /app/greeter_server

# Expose the gRPC port
EXPOSE 50051

# Run the server as the entrypoint
ENTRYPOINT ["/app/greeter_server"]
