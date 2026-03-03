#!/bin/sh
# Railway / Docker entrypoint for OpenFang.
# 1. Auto-detect LLM provider from env vars (no config edit needed).
# 2. Resolve listen address from PORT.
# 3. Bootstrap minimal config.toml on first boot.
# 4. Seed bundled agents if volume is empty.
set -e

# -- 1. Resolve listen address -----------------------------------------------
LISTEN="${OPENFANG_LISTEN:-0.0.0.0:${PORT:-4200}}"
export OPENFANG_LISTEN="${LISTEN}"

# -- 2. Auto-detect default LLM provider from whichever API key is set --------
# OPENFANG_PROVIDER / OPENFANG_MODEL / OPENFANG_MODEL_KEY_ENV are read by the
# kernel at boot and override whatever is stored in config.toml on the volume.
if [ -z "${OPENFANG_PROVIDER:-}" ]; then
  if [ -n "${GROQ_API_KEY:-}" ]; then
    export OPENFANG_PROVIDER=groq
    export OPENFANG_MODEL="${OPENFANG_MODEL:-llama-3.3-70b-versatile}"
    export OPENFANG_MODEL_KEY_ENV=GROQ_API_KEY
  elif [ -n "${OPENAI_API_KEY:-}" ]; then
    export OPENFANG_PROVIDER=openai
    export OPENFANG_MODEL="${OPENFANG_MODEL:-gpt-4o-mini}"
    export OPENFANG_MODEL_KEY_ENV=OPENAI_API_KEY
  elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    export OPENFANG_PROVIDER=anthropic
    export OPENFANG_MODEL="${OPENFANG_MODEL:-claude-haiku-4-20250514}"
    export OPENFANG_MODEL_KEY_ENV=ANTHROPIC_API_KEY
  elif [ -n "${DEEPSEEK_API_KEY:-}" ]; then
    export OPENFANG_PROVIDER=deepseek
    export OPENFANG_MODEL="${OPENFANG_MODEL:-deepseek-chat}"
    export OPENFANG_MODEL_KEY_ENV=DEEPSEEK_API_KEY
  elif [ -n "${OPENROUTER_API_KEY:-}" ]; then
    export OPENFANG_PROVIDER=openrouter
    export OPENFANG_MODEL="${OPENFANG_MODEL:-openai/gpt-4o-mini}"
    export OPENFANG_MODEL_KEY_ENV=OPENROUTER_API_KEY
  elif [ -n "${GEMINI_API_KEY:-}" ]; then
    export OPENFANG_PROVIDER=gemini
    export OPENFANG_MODEL="${OPENFANG_MODEL:-gemini-2.5-flash}"
    export OPENFANG_MODEL_KEY_ENV=GEMINI_API_KEY
  elif [ -n "${GOOGLE_API_KEY:-}" ]; then
    export OPENFANG_PROVIDER=gemini
    export OPENFANG_MODEL="${OPENFANG_MODEL:-gemini-2.5-flash}"
    export OPENFANG_MODEL_KEY_ENV=GOOGLE_API_KEY
  else
    export OPENFANG_PROVIDER=ollama
    export OPENFANG_MODEL="${OPENFANG_MODEL:-llama3.2}"
    export OPENFANG_MODEL_KEY_ENV=OLLAMA_API_KEY
    echo "[entrypoint] No LLM API key found - using Ollama. Set GROQ_API_KEY in Railway Variables."
  fi
  echo "[entrypoint] Provider: ${OPENFANG_PROVIDER} / ${OPENFANG_MODEL}"
fi

# -- 3. Ensure data directories exist ----------------------------------------
OPENFANG_DIR="${HOME:-/data}/.openfang"
mkdir -p "${OPENFANG_DIR}/data"
mkdir -p "${OPENFANG_DIR}/agents"
mkdir -p "${OPENFANG_DIR}/skills"

# -- 4. Bootstrap config.toml on first boot ----------------------------------
CONFIG="${OPENFANG_DIR}/config.toml"
if [ ! -f "${CONFIG}" ]; then
  echo "[entrypoint] Writing bootstrap config to ${CONFIG}"
  printf 'api_listen = "%s"\napi_key = "%s"\n' "${LISTEN}" "${OPENFANG_API_KEY:-}" > "${CONFIG}"
  echo "[entrypoint] Bootstrap config written."
fi

# -- 5. Seed bundled agents if volume is empty --------------------------------
AGENTS_SRC=/opt/openfang/agents
AGENTS_DST="${OPENFANG_DIR}/agents"
if [ -d "${AGENTS_SRC}" ] && [ -z "$(ls -A "${AGENTS_DST}" 2>/dev/null)" ]; then
  echo "[entrypoint] Seeding bundled agents into ${AGENTS_DST}"
  cp -r "${AGENTS_SRC}/." "${AGENTS_DST}/"
fi

echo "[entrypoint] Starting OpenFang - listening on ${LISTEN}"
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  echo "[entrypoint] Dashboard: https://${RAILWAY_PUBLIC_DOMAIN}/"
fi
exec openfang start
