# Build stage
FROM golang:1.19-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the greeter_server binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags="-w -s" -o /app/greeter_server ./greeter_server/main.go

# Runtime stage - use scratch for minimal image
FROM scratch

# Copy CA certificates from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy binary from builder
COPY --from=builder /app/greeter_server /greeter_server

# Expose gRPC port
EXPOSE 50051

# Run the server
ENTRYPOINT ["/greeter_server"]
CMD ["--port=50051"]
