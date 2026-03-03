# Deploy and Host OpenFang on Railway

OpenFang is an open-source **Agent Operating System** built in Rust. It runs autonomous agents 24/7 — on schedules, without prompting — capable of research, lead generation, social media management, web automation, and more. The entire system ships as a single ~32 MB binary.

## About Hosting OpenFang on Railway

Hosting OpenFang on Railway gives you a persistent, always-on agent daemon backed by a Railway volume for SQLite state and memory. The Dockerfile in the repo produces a multi-stage Rust build that copies the compiled binary and bundled agents into a lean Debian slim image. Railway mounts `/data` as a persistent volume, sets `OPENFANG_HOME=/data`, and exposes the dashboard on the Railway-provided `PORT`. Configure your LLM provider and integrations in the dashboard UI after first boot.

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

**Bind address — auto-configured**

The Docker entrypoint automatically derives the listen address from Railway's injected `PORT`, so no `OPENFANG_LISTEN` variable is needed. The binary binds `0.0.0.0:$PORT` on every start.

**Persistent volume**

Add a Railway volume and mount it at `/data`. The `OPENFANG_HOME=/data` env var (already set in the Dockerfile) tells OpenFang to store all config, databases, and agent files there so data survives redeployments.

**`config.toml` bootstrap**

If `/data/.openfang/config.toml` does not exist on first boot, the entrypoint writes a minimal config (listen address + api_key only). All other settings — LLM provider, model, channel integrations, memory — are configured through the **OpenFang dashboard UI** after deployment. No manual config file editing required.

**Health check**

Railway's health check is pointed at `/api/health` (configured in `railway.json`). This endpoint is unauthenticated even when `OPENFANG_API_KEY` is set.

---

## Environment Variables

OpenFang on Railway requires **only one variable** to be set manually. Everything else is either auto-provided by Railway or configured in the OpenFang dashboard UI after first boot.

### The Only Variable You Need to Set

| Variable           | Required    | Example                      | Purpose                                                                                                                                        |
| ------------------ | ----------- | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `OPENFANG_API_KEY` | Recommended | `my-secret-key` (any string) | Secures the dashboard and API with Bearer auth. Leave empty to run without auth (dev/internal use only). **Mark as sealed/secret in Railway.** |

Generate a strong key: in any terminal run `openssl rand -base64 32`.

### Auto-Provided by Railway (do not set)

| Variable                | Purpose                                                                  |
| ----------------------- | ------------------------------------------------------------------------ |
| `PORT`                  | Injected at deploy time. Entrypoint binds `0.0.0.0:$PORT` automatically. |
| `RAILWAY_PUBLIC_DOMAIN` | Public hostname. Used in CORS and printed in startup logs.               |

### Everything Else → Configure in the UI

LLM provider keys, channel tokens (Telegram, Discord, Slack, …), web search keys, memory settings, and Ollama/vLLM endpoints are all configured through the **OpenFang dashboard** at `https://<your-domain>/` after the service is running.

No need to add them as Railway Variables.

### Optional Railway Variables (advanced / sidecar setups)

If you need to wire a **sidecar service** (Ollama, vLLM, etc.) on Railway's private network, you can still set these:

| Variable          | Example                                           | Purpose                                        |
| ----------------- | ------------------------------------------------- | ---------------------------------------------- |
| `OLLAMA_BASE_URL` | `http://${{ollama.RAILWAY_PRIVATE_DOMAIN}}:11434` | Point to a sidecar Ollama service.             |
| `RUST_LOG`        | `info`                                            | Log verbosity (`error`/`warn`/`info`/`debug`). |

---

## Why Deploy OpenFang on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenFang on Railway, you get a persistent, always-on autonomous agent OS — with 40 channel adapters, 27 LLM providers, 53 built-in tools, and a full REST/WebSocket/SSE API — without managing a VPS, systemd service, or Docker installation yourself. Host your agent daemon, memory databases, and channel integrations on Railway with zero infrastructure overhead.

---

## Railway Setup Checklist

1. **Fork or connect** the [OpenFang repo](https://github.com/8u9i/openfang) to a Railway project.
2. **Add a Volume** in the Railway service settings → mount path `/data`.
3. **Set variables** in Railway → Variables:
   - `OPENFANG_API_KEY` = any strong random string (recommended; mark as sealed)
   - That's it — no other variables required.
4. **Verify `railway.json`** is committed at the repo root — Railway uses it for the health check path and restart policy.
5. **Deploy** — Railway detects the `Dockerfile` and builds via multi-stage Rust compilation (~5–10 min cold build; subsequent builds are faster with layer caching).
6. **Open the dashboard** at `https://<your-domain>/` and configure your LLM provider, model, and any integrations (channels, search keys, etc.) through the UI.
7. **Verify health** at `https://<your-domain>/api/health` — should return `{"status":"ok"}`.
