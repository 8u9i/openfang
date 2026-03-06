# syntax=docker/dockerfile:1
FROM rust:1-slim-bookworm AS builder
WORKDIR /build
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

ARG RUST_CACHE_BUST=1
RUN echo "cache-bust=${RUST_CACHE_BUST}"
COPY Cargo.toml Cargo.lock ./
COPY crates ./crates
COPY xtask ./xtask
COPY agents ./agents
COPY packages ./packages
RUN cargo build --release --bin openfang

FROM debian:bookworm-slim

# Install runtime dependencies (comments on separate lines)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    wget \
    libssl3 \
    libgcc-s1 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create persistent data directory
RUN mkdir -p /data/.openfang && chmod 755 /data

COPY --from=builder /build/target/release/openfang /usr/local/bin/
COPY --from=builder /build/agents /opt/openfang/agents

ARG CACHE_BUST=1
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/docker-entrypoint.sh \
    && sed -i 's/\r//' /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

ENV HOME=/data \
    OPENFANG_HOME=/data \
    PORT=4200

EXPOSE 4200

# Optional healthcheck for debugging
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4200/api/health || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]

