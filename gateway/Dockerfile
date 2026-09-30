# ==============================================================================
# Multi-Stage Dockerfile for Bangkok Weather Resilience Go Gateway
# Ticket 05 / R5 | Feature F24
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build & Compilation
# ------------------------------------------------------------------------------
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Install build prerequisites
RUN apk --no-cache add ca-certificates

# Copy dependency manifests first to leverage Docker layer caching
COPY go.mod go.sum* ./
RUN go mod download || true

# Copy source code and static assets
COPY . .

# Compile statically linked binary with stripped symbols for minimal footprint (<25MB)
# -ldflags="-s -w" strips symbol table and DWARF debug information
# -trimpath removes absolute host file paths from compiled binary
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /app/gateway ./cmd/server

# ------------------------------------------------------------------------------
# Stage 2: Minimal & Hardened Production Runtime
# ------------------------------------------------------------------------------
FROM alpine:3.20

# Metadata labels
LABEL maintainer="Bangkok Weather Resilience Team"
LABEL description="Go API Gateway, LINE Webhook Receiver & Dispatcher"

# Install SSL root certificates for outbound HTTPS (LINE API) and tzdata for Bangkok local time
RUN apk --no-cache add ca-certificates tzdata

# Set Bangkok local timezone (+07:00)
ENV TZ=Asia/Bangkok

# Create unprivileged system user and group (UID/GID 10001) for least-privilege security
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S -G appgroup -h /app -s /sbin/nologin appuser

# Set working directory to /app (required for relative staticDir "static/liff" lookup)
WORKDIR /app

# Copy compiled gateway binary from builder with unprivileged ownership
COPY --from=builder --chown=appuser:appgroup /app/gateway /app/gateway

# CRITICAL: Copy static assets (LIFF web app) from builder so /liff/ endpoints do NOT 404
COPY --from=builder --chown=appuser:appgroup /app/static /app/static

# Switch to unprivileged non-root user
USER 10001:10001

# Expose Go Gateway HTTP service port
EXPOSE 8080

# Healthcheck monitoring the /health endpoint via BusyBox wget
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

# Execute Go Gateway service
ENTRYPOINT ["/app/gateway"]
