# Multi-stage build for Go gRPC server
# Stage 1: Build
FROM golang:1.19-alpine AS builder

WORKDIR /app

# Copy dependency files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the gRPC server binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags="-w -s" -o greeter_server ./greeter_server/main.go

# Stage 2: Runtime
FROM alpine:3.18

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/greeter_server .

# Expose port 80 (as per AKS configuration)
EXPOSE 80

# Run the server on port 80
CMD ["./greeter_server", "-port", "80"]
