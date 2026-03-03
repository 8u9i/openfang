# syntax=docker/dockerfile:1
FROM rust:1-slim-bookworm AS builder
WORKDIR /build
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
COPY Cargo.toml Cargo.lock ./
COPY crates ./crates
COPY xtask ./xtask
COPY agents ./agents
COPY packages ./packages
RUN cargo build --release --bin openfang

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates wget && rm -rf /var/lib/apt/lists/*
COPY --from=builder /build/target/release/openfang /usr/local/bin/
COPY --from=builder /build/agents /opt/openfang/agents
# Bust Railway's build cache when entrypoint or config changes (bump value to force rebuild).
ARG CACHE_BUST=1
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/docker-entrypoint.sh \
    && sed -i 's/\r//' /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

# HOME=/data ensures dirs::home_dir() resolves to the mounted Railway volume,
# so config.toml and SQLite databases land on persistent storage at /data/.openfang/.
# OPENFANG_LISTEN is read by the kernel at boot and overrides api_listen in config.
# PORT is injected by Railway; the entrypoint derives OPENFANG_LISTEN from it.
ENV HOME=/data \
    OPENFANG_HOME=/data \
    PORT=4200

EXPOSE 4200
ENTRYPOINT ["docker-entrypoint.sh"]
