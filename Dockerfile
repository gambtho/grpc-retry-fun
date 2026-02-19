# Build stage
FROM golang:1.19-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o greeter_server ./greeter_server

# Runtime stage
FROM gcr.io/distroless/static-debian11@sha256:1dbe426d60caed5d19597532a2d74c8056cd7b1674042b88f7328690b5ead8ed

WORKDIR /

# Copy the binary from builder
COPY --from=builder /app/greeter_server /greeter_server

# Expose the gRPC port
EXPOSE 80

# Run the server
ENTRYPOINT ["/greeter_server", "-port=80"]
