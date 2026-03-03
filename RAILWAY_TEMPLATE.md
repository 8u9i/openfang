# Deploy and Host OpenFang on Railway

OpenFang is an open-source **Agent Operating System** built in Rust. It runs autonomous agents 24/7 — on schedules, without prompting — capable of research, lead generation, social media management, web automation, and more. The entire system ships as a single ~32 MB binary.

## About Hosting OpenFang on Railway

Hosting OpenFang on Railway gives you a persistent, always-on agent daemon backed by a Railway volume for SQLite state and memory. The Dockerfile in the repo produces a multi-stage Rust build that copies the compiled binary and bundled agents into a lean Debian slim image. Railway mounts `/data` as a persistent volume, sets `OPENFANG_HOME=/data`, and exposes the dashboard/API on the Railway-provided `PORT`. At least one LLM provider API key is required before the daemon will start successfully.

## Common Use Cases

- Running autonomous background agents (researcher, lead generator, social media manager) without managing your own VPS
- Hosting an OpenAI-compatible API endpoint (`/v1/chat/completions`) for your existing tools
- Deploying a multi-channel bot gateway (Telegram, Discord, Slack, WhatsApp, etc.) with persistent memory and skill routing

## Dependencies for OpenFang Hosting

- **Railway Volume** — mounted at `/data` for SQLite databases, agent state, and configuration persistence
- **LLM Provider Account** — at least one of Anthropic, OpenAI, Groq, Gemini, DeepSeek, OpenRouter, or any OpenAI-compatible provider

### Deployment Dependencies

- [OpenFang GitHub Repository](https://github.com/8u9i/openfang)
- [OpenFang Documentation](https://openfang.sh/docs)
- [Railway Volumes](https://docs.railway.com/reference/volumes)
- [Railway Config as Code](https://docs.railway.com/config-as-code/reference)

### Implementation Details

**Critical: bind to Railway's `PORT`**

OpenFang defaults to listening on `127.0.0.1:4200`. On Railway the app must bind `0.0.0.0` on the Railway-provided `PORT`. Set the following variable in your Railway service so the kernel picks it up at start:

```
OPENFANG_LISTEN = 0.0.0.0:${{PORT}}
```

**Persistent volume**

Add a Railway volume and mount it at `/data`. The `OPENFANG_HOME=/data` env var (already set in the Dockerfile) tells OpenFang to store all config, databases, and agent files there so data survives redeployments.

**Minimal `config.toml` bootstrap**

OpenFang reads `$OPENFANG_HOME/config.toml`. If the file does not exist when the container starts, run `openfang init --provider groq --model llama-3.3-70b-versatile` (or equivalent) in a one-off command, or supply a config file via a Railway volume init script. The simplest working config:

```toml
# /data/config.toml — generated once at first boot
api_listen = "0.0.0.0:4200"   # overridden by OPENFANG_LISTEN at runtime

[default_model]
provider = "groq"
model    = "llama-3.3-70b-versatile"
api_key_env = "GROQ_API_KEY"

[memory]
decay_rate = 0.05
```

**Health check**

Railway's health check is pointed at `/api/health` (configured in `railway.json`). This endpoint is unauthenticated even when `OPENFANG_API_KEY` is set.

---

## Full Environment Variables

### Core / Required

| Variable          | Required | Set By     | Scope   | Example             | Purpose                                                                        |
| ----------------- | -------- | ---------- | ------- | ------------------- | ------------------------------------------------------------------------------ |
| `PORT`            | Yes      | Railway    | Runtime | `3000`              | Port the app must bind to. Set `OPENFANG_LISTEN=0.0.0.0:${{PORT}}` to wire it. |
| `OPENFANG_LISTEN` | Yes      | User       | Runtime | `0.0.0.0:${{PORT}}` | Overrides `api_listen` in config. Must be `0.0.0.0:<PORT>` on Railway.         |
| `OPENFANG_HOME`   | Yes      | Dockerfile | Runtime | `/data`             | Home directory for config, SQLite databases, agents. Pre-set in Dockerfile.    |

### LLM Provider Keys (set at least one)

| Variable             | Required   | Set By | Scope   | Example      | Purpose                                                                    |
| -------------------- | ---------- | ------ | ------- | ------------ | -------------------------------------------------------------------------- |
| `ANTHROPIC_API_KEY`  | Optional\* | User   | Runtime | `sk-ant-...` | Anthropic / Claude models. Required if `provider = "anthropic"` in config. |
| `OPENAI_API_KEY`     | Optional\* | User   | Runtime | `sk-...`     | OpenAI models. Required if `provider = "openai"`.                          |
| `GROQ_API_KEY`       | Optional\* | User   | Runtime | `gsk_...`    | Groq fast-inference (Llama). Recommended default for low latency.          |
| `GEMINI_API_KEY`     | Optional\* | User   | Runtime | `AIza...`    | Google Gemini models. Alias: `GOOGLE_API_KEY`.                             |
| `DEEPSEEK_API_KEY`   | Optional\* | User   | Runtime | `sk-...`     | DeepSeek provider.                                                         |
| `OPENROUTER_API_KEY` | Optional\* | User   | Runtime | `sk-or-...`  | OpenRouter — routes to many providers via one key.                         |
| `TOGETHER_API_KEY`   | Optional\* | User   | Runtime | `...`        | Together AI provider.                                                      |
| `MISTRAL_API_KEY`    | Optional\* | User   | Runtime | `...`        | Mistral AI provider.                                                       |
| `FIREWORKS_API_KEY`  | Optional\* | User   | Runtime | `...`        | Fireworks AI provider.                                                     |
| `PERPLEXITY_API_KEY` | Optional\* | User   | Runtime | `...`        | Perplexity provider (also used for web search).                            |

> \*At least one LLM key is required for the daemon to serve agent requests.

### API Security

| Variable           | Required | Set By | Scope   | Example         | Purpose                                                                                                                                           |
| ------------------ | -------- | ------ | ------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OPENFANG_API_KEY` | Optional | User   | Runtime | `my-secret-key` | When set, all API endpoints (except `/api/health`) require `Authorization: Bearer <key>`. Leave empty for local/dev use only. **Mark as secret.** |

### Web Search Keys

| Variable         | Required | Set By | Scope   | Example    | Purpose                                      |
| ---------------- | -------- | ------ | ------- | ---------- | -------------------------------------------- |
| `BRAVE_API_KEY`  | Optional | User   | Runtime | `BSA...`   | Brave Search API — used by web search tools. |
| `TAVILY_API_KEY` | Optional | User   | Runtime | `tvly-...` | Tavily Search API.                           |

### Local LLM Provider URLs (no API key needed)

| Variable            | Required | Set By | Scope   | Example                                | Purpose                                                                                |
| ------------------- | -------- | ------ | ------- | -------------------------------------- | -------------------------------------------------------------------------------------- |
| `OLLAMA_BASE_URL`   | Optional | User   | Runtime | `http://ollama.railway.internal:11434` | Override Ollama endpoint. Wire to a sidecar Ollama service via Railway private domain. |
| `VLLM_BASE_URL`     | Optional | User   | Runtime | `http://vllm.railway.internal:8000`    | Override vLLM endpoint.                                                                |
| `LMSTUDIO_BASE_URL` | Optional | User   | Runtime | `http://....:1234`                     | Override LM Studio endpoint.                                                           |

### Logging

| Variable   | Required | Set By | Scope   | Example | Purpose                                                                                                               |
| ---------- | -------- | ------ | ------- | ------- | --------------------------------------------------------------------------------------------------------------------- |
| `RUST_LOG` | Optional | User   | Runtime | `info`  | Log verbosity. Values: `error`, `warn`, `info`, `debug`, `trace`. Use `openfang=debug` to debug only OpenFang crates. |

### Channel Tokens (enable only the channels you use)

| Variable                      | Required | Set By | Scope   | Example                     | Purpose                                                                           |
| ----------------------------- | -------- | ------ | ------- | --------------------------- | --------------------------------------------------------------------------------- |
| `TELEGRAM_BOT_TOKEN`          | Optional | User   | Runtime | `123:ABC...`                | Telegram bot token from @BotFather. Enables Telegram channel adapter. **Secret.** |
| `DISCORD_BOT_TOKEN`           | Optional | User   | Runtime | `...`                       | Discord bot token. Enables Discord channel adapter. **Secret.**                   |
| `SLACK_APP_TOKEN`             | Optional | User   | Runtime | `xapp-...`                  | Slack app-level token for Socket Mode. **Secret.**                                |
| `SLACK_BOT_TOKEN`             | Optional | User   | Runtime | `xoxb-...`                  | Slack bot token for REST API. **Secret.**                                         |
| `WHATSAPP_TOKEN`              | Optional | User   | Runtime | `...`                       | WhatsApp Cloud API access token. **Secret.**                                      |
| `WHATSAPP_PHONE_ID`           | Optional | User   | Runtime | `...`                       | WhatsApp Cloud API phone number ID.                                               |
| `SIGNAL_CLI_PATH`             | Optional | User   | Runtime | `/usr/local/bin/signal-cli` | Path to the signal-cli binary inside the container.                               |
| `SIGNAL_PHONE_NUMBER`         | Optional | User   | Runtime | `+1...`                     | Phone number registered with Signal.                                              |
| `MATRIX_HOMESERVER`           | Optional | User   | Runtime | `https://matrix.org`        | Matrix homeserver URL.                                                            |
| `MATRIX_ACCESS_TOKEN`         | Optional | User   | Runtime | `syt_...`                   | Matrix homeserver access token. **Secret.**                                       |
| `EMAIL_IMAP_HOST`             | Optional | User   | Runtime | `imap.gmail.com`            | IMAP host for email channel.                                                      |
| `EMAIL_SMTP_HOST`             | Optional | User   | Runtime | `smtp.gmail.com`            | SMTP host for email channel.                                                      |
| `EMAIL_USERNAME`              | Optional | User   | Runtime | `you@example.com`           | Email account username.                                                           |
| `EMAIL_PASSWORD`              | Optional | User   | Runtime | `...`                       | Email account password or app-password for IMAP/SMTP. **Secret.**                 |
| `TEAMS_APP_PASSWORD`          | Optional | User   | Runtime | `...`                       | Azure Bot Framework app password for MS Teams. **Secret.**                        |
| `MATTERMOST_TOKEN`            | Optional | User   | Runtime | `...`                       | Mattermost bot token. **Secret.**                                                 |
| `TWITCH_OAUTH_TOKEN`          | Optional | User   | Runtime | `oauth:...`                 | Twitch OAuth token. **Secret.**                                                   |
| `DINGTALK_ACCESS_TOKEN`       | Optional | User   | Runtime | `...`                       | DingTalk webhook access token. **Secret.**                                        |
| `DINGTALK_SECRET`             | Optional | User   | Runtime | `...`                       | DingTalk signing secret. **Secret.**                                              |
| `GOOGLE_CHAT_SERVICE_ACCOUNT` | Optional | User   | Runtime | `{...}`                     | Google Chat service account JSON. **Secret.**                                     |
| `ROCKETCHAT_TOKEN`            | Optional | User   | Runtime | `...`                       | Rocket.Chat bot token. **Secret.**                                                |
| `ZULIP_API_KEY`               | Optional | User   | Runtime | `...`                       | Zulip bot API key. **Secret.**                                                    |

### Railway-Provided (auto-injected — do not set manually)

| Variable                    | Required | Set By  | Scope   | Example                     | Purpose                                                           |
| --------------------------- | -------- | ------- | ------- | --------------------------- | ----------------------------------------------------------------- |
| `PORT`                      | Yes      | Railway | Runtime | `3000`                      | Injected by Railway at deploy time. Wire via `OPENFANG_LISTEN`.   |
| `RAILWAY_PUBLIC_DOMAIN`     | —        | Railway | Runtime | `openfang.up.railway.app`   | Public domain assigned to the service.                            |
| `RAILWAY_PRIVATE_DOMAIN`    | —        | Railway | Runtime | `openfang.railway.internal` | Private network hostname within the project.                      |
| `RAILWAY_ENVIRONMENT_NAME`  | —        | Railway | Runtime | `production`                | Active environment name.                                          |
| `RAILWAY_SERVICE_NAME`      | —        | Railway | Runtime | `openfang`                  | Service name as set in Railway.                                   |
| `RAILWAY_VOLUME_MOUNT_PATH` | —        | Railway | Runtime | `/data`                     | Injected when a volume is attached. Should match `OPENFANG_HOME`. |

---

## Why Deploy OpenFang on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenFang on Railway, you get a persistent, always-on autonomous agent OS — with 40 channel adapters, 27 LLM providers, 53 built-in tools, and a full REST/WebSocket/SSE API — without managing a VPS, systemd service, or Docker installation yourself. Host your agent daemon, memory databases, and channel integrations on Railway with zero infrastructure overhead.

---

## Railway Setup Checklist

1. **Fork or connect** the [OpenFang repo](https://github.com/8u9i/openfang) to a Railway project.
2. **Add a Volume** in the Railway service settings → mount path `/data`.
3. **Set variables** in Railway → Variables:
   - `OPENFANG_LISTEN` = `0.0.0.0:${{PORT}}`
   - At least one LLM key (e.g. `GROQ_API_KEY`)
   - `OPENFANG_API_KEY` (recommended for production; mark as sealed/secret)
4. **Verify `railway.json`** is committed at the repo root — Railway uses it for the health check path and restart policy.
5. **Deploy** — Railway detects the `Dockerfile` and builds via multi-stage Rust compilation (~5–10 min cold build; subsequent builds are faster with layer caching).
6. **Bootstrap config** — on first boot the daemon may need a `config.toml`. Either:
   - Shell into the container and run `openfang init`, or
   - Write the minimal `config.toml` shown above to `/data/config.toml` via a Railway volume file mount.
7. **Verify health** at `https://<your-domain>/api/health` — should return `{"status":"ok"}`.
8. **Mark all secret variables** (API keys, bot tokens) as sealed in Railway to prevent accidental exposure.
