# ==============================================================================
# Bangkok Weather Resilience AI Engine Dockerfile (Phase 1, Ticket 05)
# Multi-Stage Build: Python 3.11-slim, Non-Root (UID 10001), Minimal C Runtime
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder (Wheel compilation & Virtualenv isolation)
# ------------------------------------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /build

# Install compiler tools strictly in builder stage (discarded in runner image)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create isolated Python virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies with layer caching
COPY engine/requirements.txt requirements.txt
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# ------------------------------------------------------------------------------
# Stage 2: Runtime (Hardened unprivileged runner)
# ------------------------------------------------------------------------------
FROM python:3.11-slim AS runner

# Create non-root unprivileged user and group (UID/GID 10001)
RUN groupadd -g 10001 appuser && \
    useradd -u 10001 -g appuser -s /bin/bash -m -d /home/appuser appuser

# Set standard Python and Timezone environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TZ=Asia/Bangkok \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH="/app:/app/engine"

# Install minimal runtime C dependencies (curl for healthcheck, tzdata, ca-certs, GEOS C library)
# Omits all C/C++ compilers, headers, and build tools to prevent image bloat
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    tzdata \
    libgeos-c1v5 \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy isolated virtual environment from builder stage
COPY --from=builder --chown=appuser:appuser /opt/venv /opt/venv

# Copy engine application source code and reference dataset
COPY --chown=appuser:appuser engine/ /app/engine/
COPY --chown=appuser:appuser data/ /app/data/

# Establish symlink so both `uvicorn main:app` and `uvicorn engine.main:app` execute identically
RUN ln -sf /app/engine/main.py /app/main.py && \
    chown -h appuser:appuser /app/main.py

# Switch to unprivileged non-root user
USER appuser

# Expose FastAPI application port
EXPOSE 8000

# Healthcheck targeting /health endpoint
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default ASGI entrypoint command
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
