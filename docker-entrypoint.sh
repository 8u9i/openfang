#!/bin/sh
# Railway / Docker entrypoint for OpenFang.
#
# Responsibilities:
#   1. Resolve the listen address from OPENFANG_LISTEN or Railway-injected PORT.
#   2. Bootstrap a minimal config.toml if none exists (first-boot on a fresh volume).
#   3. Ensure data directories exist.
#   4. Export OPENFANG_LISTEN so the kernel picks it up even if config.toml pre-exists.
#   5. Exec the daemon â€” PID 1 receives signals correctly.
set -e

# â”€â”€ 1. Resolve listen address â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# OPENFANG_LISTEN wins if already set by the user.
# Otherwise derive from Railway-provided PORT, falling back to 4200.
LISTEN="${OPENFANG_LISTEN:-0.0.0.0:${PORT:-4200}}"
export OPENFANG_LISTEN="${LISTEN}"

# -- 2. Auto-detect default LLM provider from available API keys ----------------
# OPENFANG_PROVIDER/MODEL/MODEL_KEY_ENV are read by the kernel at boot and override
# whatever provider is stored in config.toml on the volume. This means the service
# always starts even if the volume has a stale or unconfigured provider.
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
  elif [ -n "${GEMINI_API_KEY:-}" ] || [ -n "${GOOGLE_API_KEY:-}" ]; then
    export OPENFANG_PROVIDER=gemini
    export OPENFANG_MODEL="${OPENFANG_MODEL:-gemini-2.5-flash}"
    export OPENFANG_MODEL_KEY_ENV="${GEMINI_API_KEY:+GEMINI_API_KEY}${GEMINI_API_KEY:-GOOGLE_API_KEY}"
  else
    # No cloud provider key set - fall back to Ollama (key_required=false, always boots).
    # Configure a real provider in the dashboard UI after first boot.
    export OPENFANG_PROVIDER=ollama
    export OPENFANG_MODEL="${OPENFANG_MODEL:-llama3.2}"
    export OPENFANG_MODEL_KEY_ENV=OLLAMA_API_KEY
    echo "[entrypoint] No LLM API key detected - defaulting to Ollama. Set GROQ_API_KEY or another provider key in Railway Variables."
  fi
  echo "[entrypoint] Provider: ${OPENFANG_PROVIDER} / ${OPENFANG_MODEL}"
fi

# â”€â”€ 2. Ensure home / data directories exist â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# HOME is set to /data in the Dockerfile so dirs::home_dir() returns /data.
# Config lives at /data/.openfang/config.toml â€” on the mounted Railway volume.
OPENFANG_DIR="${HOME:-/data}/.openfang"
mkdir -p "${OPENFANG_DIR}/data"
mkdir -p "${OPENFANG_DIR}/agents"
mkdir -p "${OPENFANG_DIR}/skills"

# â”€â”€ 3. Bootstrap config.toml on first boot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CONFIG="${OPENFANG_DIR}/config.toml"
if [ ! -f "${CONFIG}" ]; then
  echo "[entrypoint] No config.toml found â€” writing bootstrap config to ${CONFIG}"
  cat > "${CONFIG}" <<TOML
# OpenFang bootstrap config — auto-generated on first boot.
#
# api_listen is overridden at runtime by OPENFANG_LISTEN (set by this entrypoint).
# Configure your LLM provider, channels, and memory settings in the dashboard UI.
api_listen = "${LISTEN}"
api_key = "${OPENFANG_API_KEY:-}"
TOML
  echo "[entrypoint] Bootstrap config written."
fi

# â”€â”€ 4. Copy bundled agents into the volume if the agents dir is empty â”€â”€â”€â”€â”€â”€â”€â”€â”€
AGENTS_SRC="/opt/openfang/agents"
AGENTS_DST="${OPENFANG_DIR}/agents"
if [ -d "${AGENTS_SRC}" ] && [ -z "$(ls -A "${AGENTS_DST}" 2>/dev/null)" ]; then
  echo "[entrypoint] Seeding bundled agents into ${AGENTS_DST}"
  cp -r "${AGENTS_SRC}/." "${AGENTS_DST}/"
fi

echo "[entrypoint] Starting OpenFang — listening on ${LISTEN}"
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  echo "[entrypoint] Railway dashboard: https://${RAILWAY_PUBLIC_DOMAIN}/"
fi
exec openfang start
