# syntax=docker/dockerfile:1

# Build stage
FROM golang:1.19-alpine AS builder

# Set working directory
WORKDIR /build

# Copy go module files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the greeter_server binary
# CGO_ENABLED=0 for static binary, -ldflags for smaller size
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -o greeter_server \
    ./greeter_server/main.go

# Runtime stage - using distroless for minimal secure base
FROM gcr.io/distroless/static-debian11:nonroot

# Copy binary from builder
COPY --from=builder /build/greeter_server /app/greeter_server

# Expose gRPC port (using port 80 as specified in deployment config)
EXPOSE 80

# Run the server on port 80
ENTRYPOINT ["/app/greeter_server"]
CMD ["-port=80"]
