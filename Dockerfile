# Build stage
FROM golang:1.19-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o greeter_server ./greeter_server/main.go

# Runtime stage
FROM gcr.io/distroless/static-debian11:nonroot

WORKDIR /

# Copy the binary from builder
COPY --from=builder /app/greeter_server /greeter_server

# Use non-root user
USER 65532:65532

# Expose port
EXPOSE 50051

# Run the application
ENTRYPOINT ["/greeter_server"]
