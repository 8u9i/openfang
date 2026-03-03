#!/bin/sh
# Railway / Docker entrypoint for OpenFang.
# Resolves the listen address and bootstraps a minimal config on first boot.
# LLM provider and all other settings are configured in the dashboard UI.
set -e

LISTEN="${OPENFANG_LISTEN:-0.0.0.0:${PORT:-4200}}"
export OPENFANG_LISTEN="${LISTEN}"

OPENFANG_DIR="${HOME:-/data}/.openfang"
mkdir -p "${OPENFANG_DIR}/data" "${OPENFANG_DIR}/agents" "${OPENFANG_DIR}/skills"

CONFIG="${OPENFANG_DIR}/config.toml"
if [ ! -f "${CONFIG}" ]; then
  printf 'api_listen = "%s"\napi_key = "%s"\n\n[default_model]\nprovider = "ollama"\nmodel = "llama3.2"\napi_key_env = "OLLAMA_API_KEY"\n' \
    "${LISTEN}" "${OPENFANG_API_KEY:-}" > "${CONFIG}"
  echo "[entrypoint] Bootstrap config written to ${CONFIG}"
elif ! grep -q '^\[default_model\]' "${CONFIG}"; then
  printf '\n[default_model]\nprovider = "ollama"\nmodel = "llama3.2"\napi_key_env = "OLLAMA_API_KEY"\n' >> "${CONFIG}"
  echo "[entrypoint] Added missing [default_model] to ${CONFIG}"
fi

AGENTS_SRC=/opt/openfang/agents
AGENTS_DST="${OPENFANG_DIR}/agents"
if [ -d "${AGENTS_SRC}" ] && [ -z "$(ls -A "${AGENTS_DST}" 2>/dev/null)" ]; then
  cp -r "${AGENTS_SRC}/." "${AGENTS_DST}/"
  echo "[entrypoint] Bundled agents seeded."
fi

echo "[entrypoint] Starting OpenFang - listening on ${LISTEN}"
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  echo "[entrypoint] Dashboard: https://${RAILWAY_PUBLIC_DOMAIN}/"
fi
exec openfang start
