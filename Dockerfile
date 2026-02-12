# Multi-stage build for Go gRPC greeter_server
# Stage 1: Build stage
FROM golang:1.19-bullseye AS builder

# Set working directory
WORKDIR /build

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the entire source code
COPY . .

# Build the greeter_server binary
# CGO_ENABLED=0 for static binary, -ldflags for smaller binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o greeter_server ./greeter_server/main.go

# Stage 2: Runtime stage using distroless for minimal attack surface
FROM gcr.io/distroless/static-debian11:nonroot

# Set working directory
WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /build/greeter_server /app/greeter_server

# Expose gRPC port
EXPOSE 50051

# Run the greeter_server as non-root user (distroless nonroot user)
ENTRYPOINT ["/app/greeter_server"]
CMD ["--port=50051"]
