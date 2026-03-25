# =============================================================================
# Stage 1 – Builder
# =============================================================================
# Pin to a specific Alpine patch version for reproducible builds.
FROM golang:1.19-alpine3.18 AS builder

# ca-certificates and git are pre-installed in the golang:alpine base image;
# no extra apk install needed. All modules are fetched via the Go module proxy.

WORKDIR /src

# Copy dependency manifests first so Docker can cache the download layer.
COPY go.mod go.sum ./

# Download then cryptographically verify every module against go.sum –
# this guards against supply-chain tampering.
RUN go mod download && go mod verify

# Copy the rest of the source tree.
COPY . .

# Build a fully static binary:
#   -mod=readonly  – fail if go.sum would need updating; ensures reproducibility
#   CGO_ENABLED=0  – pure-Go binary, no libc dependency
#   -trimpath      – strip local filesystem paths from the binary
#   -ldflags -s -w – strip debug symbols / DWARF to reduce image size
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -mod=readonly -trimpath -ldflags="-s -w" \
    -o /bin/greeter_server ./greeter_server

# =============================================================================
# Stage 2 – Runtime
# =============================================================================
# Upgraded from debian11 to debian12 (Bookworm) for the latest security patches.
FROM gcr.io/distroless/static-debian12:nonroot AS runtime

# OCI image labels for traceability.
LABEL org.opencontainers.image.source="https://github.com/gambtho/grpc-retry-fun"
LABEL org.opencontainers.image.description="gRPC greeter server (grpc-retry-fun)"

# Copy only the compiled binary – nothing else from the builder stage.
COPY --from=builder /bin/greeter_server /bin/greeter_server

# HTTP port used by the service and health probes.
EXPOSE 80

# Explicitly enforce non-root execution (distroless nonroot UID 65532).
USER nonroot:nonroot

ENTRYPOINT ["/bin/greeter_server"]
