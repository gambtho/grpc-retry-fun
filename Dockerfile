# Build stage
FROM golang:1.19-bookworm AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the server binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -ldflags="-w -s" -o /greeter_server ./greeter_server

# Runtime stage
FROM gcr.io/distroless/static-debian11:nonroot

# Use nonroot user (UID 65532)
USER 65532:65532

WORKDIR /app

# Copy the binary from builder
COPY --from=builder --chown=65532:65532 /greeter_server /app/greeter_server

# Expose gRPC port
EXPOSE 50051

# Run the server
ENTRYPOINT ["/app/greeter_server"]
