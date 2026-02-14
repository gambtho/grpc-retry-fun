# Security Remediation Guide
## Quick Fix for grpc-retry-fun:1.0 Vulnerabilities

### Executive Summary
- **2 HIGH severity vulnerabilities** found in Go dependencies
- **5 MEDIUM severity vulnerabilities** found in Go dependencies
- **Estimated fix time:** 15-20 minutes
- **Risk level:** MEDIUM-HIGH (DoS vulnerabilities present)

---

## Immediate Actions Required

### Step 1: Update Go Dependencies

Edit `go.mod` or run these commands:

```bash
cd /home/runner/work/grpc-retry-fun/grpc-retry-fun

# Update vulnerable dependencies
go get golang.org/x/net@v0.38.0
go get google.golang.org/grpc@v1.57.1
go get google.golang.org/protobuf@v1.33.0

# Clean up and verify
go mod tidy
go mod verify
```

### Step 2: Rebuild the Image

```bash
# Rebuild with security fixes
docker build -t grpc-retry-fun:1.0-secure .

# Or rebuild with the same tag after testing
docker build -t grpc-retry-fun:1.0 .
```

### Step 3: Verify the Fix

```bash
# Save the new image
docker save grpc-retry-fun:1.0-secure -o /tmp/grpc-retry-fun-secure.tar

# Scan for vulnerabilities
trivy image --input /tmp/grpc-retry-fun-secure.tar --severity HIGH,CRITICAL

# Expected result: 0 HIGH, 0 CRITICAL vulnerabilities
```

---

## Detailed Vulnerability Information

### HIGH Severity Issues

#### 1. CVE-2023-39325 - HTTP/2 Rapid Reset DoS
- **Current Version:** golang.org/x/net v0.14.0
- **Fixed Version:** v0.17.0+ (recommend v0.38.0 for all fixes)
- **Risk:** Denial of Service through rapid HTTP/2 stream resets
- **CVSS:** HIGH

#### 2. GHSA-m425-mq94-257g - gRPC HTTP/2 Rapid Reset
- **Current Version:** google.golang.org/grpc v1.57.0
- **Fixed Version:** v1.57.1
- **Risk:** Service resource exhaustion and DoS
- **CVSS:** HIGH

### MEDIUM Severity Issues

All fixed by updating golang.org/x/net to v0.38.0:
- CVE-2023-44487 (HTTP/2 DDoS)
- CVE-2023-45288 (CONTINUATION frames DoS)
- CVE-2025-22870 (Proxy bypass)
- CVE-2025-22872 (XSS in HTML parser)
- CVE-2024-24786 (Protobuf infinite loop) - fixed by updating google.golang.org/protobuf to v1.33.0

---

## go.mod Changes

Replace these lines in your `go.mod`:

**Before:**
```go
require (
    golang.org/x/net v0.14.0
    google.golang.org/grpc v1.57.0
    google.golang.org/protobuf v1.31.0
)
```

**After:**
```go
require (
    golang.org/x/net v0.38.0
    google.golang.org/grpc v1.57.1
    google.golang.org/protobuf v1.33.0
)
```

---

## Testing After Remediation

### 1. Unit Tests
```bash
go test ./... -v
```

### 2. Build Test
```bash
go build -v ./greeter_server/main.go
```

### 3. Integration Test
```bash
# Start the server
./greeter_server/main &
SERVER_PID=$!

# Wait for startup
sleep 2

# Test with client (if available)
./greeter_client/main -name="Security Test"

# Clean up
kill $SERVER_PID
```

### 4. Container Test
```bash
# Run the container
docker run -d -p 50051:50051 --name grpc-test grpc-retry-fun:1.0-secure

# Test connectivity (requires grpcurl)
grpcurl -plaintext localhost:50051 list

# Stop and remove
docker stop grpc-test && docker rm grpc-test
```

---

## CI/CD Integration

### Add Security Scanning to GitHub Actions

Create or update `.github/workflows/security-scan.yml`:

```yaml
name: Security Scan

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    # Run weekly security scan
    - cron: '0 0 * * 0'

jobs:
  scan:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Build Docker image
      run: docker build -t grpc-retry-fun:${{ github.sha }} .
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: grpc-retry-fun:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'
        exit-code: '1'
    
    - name: Upload Trivy results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v3
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'
```

---

## Long-term Recommendations

### 1. Automated Dependency Updates

Add Dependabot configuration (`.github/dependabot.yml`):

```yaml
version: 2
updates:
  - package-ecosystem: "gomod"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

### 2. Security Policy

Create `SECURITY.md`:

```markdown
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

Please report security vulnerabilities to [security@example.com]
```

### 3. Regular Audits

Schedule monthly security reviews:
- Dependency updates
- Image scanning
- Configuration review
- Access control audit

---

## Verification Checklist

After applying fixes, verify:

- [ ] All HIGH/CRITICAL vulnerabilities resolved
- [ ] go.mod and go.sum updated
- [ ] Docker image rebuilds successfully
- [ ] Unit tests pass
- [ ] Container starts and serves requests
- [ ] Security scan shows 0 HIGH/CRITICAL issues
- [ ] Changes committed to version control

---

## Additional Resources

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [NIST CVE Database](https://nvd.nist.gov/)
- [Go Security Best Practices](https://go.dev/security/best-practices)
- [HTTP/2 Rapid Reset Attack](https://www.cisa.gov/news-events/alerts/2023/10/10/http2-rapid-reset-vulnerability-cve-2023-44487)

---

## Support

For questions or issues with remediation:
1. Check the full security report: `SECURITY_SCAN_REPORT.md`
2. Review vulnerability details: `SECURITY_SCAN_RESULTS.json`
3. Consult the project README: `README.md`

---

**Document Version:** 1.0  
**Last Updated:** 2026-02-14  
**Next Review:** After dependency updates
