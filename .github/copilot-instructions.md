# OpenFang — AI Agent Instructions

OpenFang is an **open-source Agent Operating System** written in Rust. 14 crates, 137K LOC, 1,767+ tests, zero Clippy warnings. Single `~32 MB` binary. HTTP daemon at `http://127.0.0.1:4200`.

---

## Build & Verify (Run All Three After Every Change)

```bash
cargo build --workspace --lib          # --lib avoids locking the .exe
cargo test --workspace                 # 1,767+ tests must pass
cargo clippy --workspace --all-targets -- -D warnings  # Zero warnings
```

> **Windows gotcha**: if `openfang.exe` is locked by a running daemon, use `--lib` to skip binary linking.

---

## Crate Map

| Crate                 | Responsibility                                                                             |
| --------------------- | ------------------------------------------------------------------------------------------ |
| `openfang-types`      | Core domain types: `AgentManifest`, `AgentEntry`, `KernelConfig`, `Message`, `Tool`        |
| `openfang-kernel`     | Central kernel: agent lifecycle, scheduling, triggers, workflows, metering, auth, registry |
| `openfang-runtime`    | Agent execution loop, LLM drivers, tool runner, WASM/Python sandboxes, MCP client          |
| `openfang-memory`     | Unified memory API: SQLite structured store + semantic search + knowledge graph            |
| `openfang-wire`       | OFP peer-to-peer networking protocol (JSON-RPC framed, agent discovery)                    |
| `openfang-api`        | HTTP/WebSocket daemon (`axum`), route handlers, Alpine.js dashboard                        |
| `openfang-channels`   | Channel adapters: Telegram, Discord, WhatsApp, email, Slack, Twilio                        |
| `openfang-skills`     | Skill registry & loader (TOML + Python/WASM/Node.js, FangHub marketplace)                  |
| `openfang-hands`      | Pre-built autonomous Hands (activate-not-chat, domain-complete packages)                   |
| `openfang-extensions` | Integration registry, one-click MCP setup, credential vault/OAuth2 PKCE                    |
| `openfang-cli`        | Interactive CLI REPL + daemon control — **do not modify unless asked**                     |
| `openfang-desktop`    | Tauri 2.0 native desktop wrapper                                                           |
| `openfang-migrate`    | Import agents from other frameworks                                                        |

---

## Adding a New API Endpoint (Exact Pattern)

1. **DTO** → `crates/openfang-api/src/types.rs`  
   Add `#[derive(serde::Serialize, serde::Deserialize)]` structs.

2. **Handler** → `crates/openfang-api/src/routes.rs`

   ```rust
   pub async fn my_handler(
       State(state): State<Arc<AppState>>,
       Json(req): Json<MyRequest>,
   ) -> impl IntoResponse {
       match state.kernel.my_operation() {
           Ok(v) => (StatusCode::OK, Json(json!(v))),
           Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": e.to_string()}))),
       }
   }
   ```

3. **Register route** → `crates/openfang-api/src/server.rs` inside `build_router()`

   ```rust
   .route("/api/myfeature", axum::routing::get(routes::my_handler))
   ```

4. **Kernel method** → `crates/openfang-kernel/src/kernel.rs` on `OpenFangKernel`  
   (Optional: add to `KernelHandle` trait in `crates/openfang-runtime/src/kernel_handle.rs` if agents need it.)

---

## Adding a Config Field

All in `crates/openfang-types/src/config.rs`:

1. Add field to `KernelConfig` struct with `#[serde(default)]`
2. Add default value to `impl Default for KernelConfig`
3. Add doc comment

> Fields missing from `Default` will fail to compile.

---

## Dashboard UI Pattern (Alpine.js SPA)

Files live in `crates/openfang-api/static/`:

```
index_head.html       ← <head> imports
index_body.html       ← Main Alpine.js app (x-data="app")
css/
js/
  app.js              ← Global store + hash router
  api.js              ← OpenFangAPI HTTP/WebSocket client
  pages/              ← One .js component per page/tab
vendor/               ← Alpine.js, marked.js, hljs, etc.
```

**Adding a tab** requires changes to three files:

1. `js/pages/mypage.js` — Alpine component function
2. `index_body.html` — `<template x-if="currentPage === 'mypage'">` block
3. `index_body.html` — Sidebar nav `<button @click="currentPage = 'mypage'">`

---

## Agent System

**agent.toml** key fields (see `agents/hello-world/agent.toml` for a full example):

```toml
name = "my-agent"
module = "builtin:chat"      # or wasm/python path

[model]
provider = "default"         # groq | openai | ollama | "" (global default)
model = "default"

[capabilities]
tools = ["file_read", "web_search"]
memory_write = ["self.*"]
agent_spawn = false
```

**Lifecycle**: `POST /api/agents` → kernel spawns Tokio task → `run_agent_loop()` → tool calls → repeat.

---

## Memory System (Three Backends)

| Backend         | API                                                          | Storage                           |
| --------------- | ------------------------------------------------------------ | --------------------------------- |
| Structured      | `store(key, value)` / `recall(key)`                          | SQLite key-value                  |
| Semantic        | `semantic_store(ns, text)` / `semantic_search(ns, query, k)` | Text LIKE index → Phase 2: Qdrant |
| Knowledge Graph | `knowledge_add_entity` / `knowledge_query`                   | SQLite nodes + edges              |

Entry point: `MemorySubstrate::new(data_dir)` in `crates/openfang-memory/src/substrate.rs`.

---

## PeerRegistry Gotcha

`PeerRegistry` is `Option<PeerRegistry>` on `OpenFangKernel` but must be `Option<Arc<PeerRegistry>>` on `AppState`:

```rust
peer_registry: kernel.peer_registry.as_ref().map(|r| Arc::new(r.clone()))
```

---

## Live Integration Testing (Required for New Endpoints)

Unit tests pass even for dead code. Always run end-to-end after wiring a new feature:

```bash
# 1. Kill any running daemon (Windows)
taskkill /PID <pid> /F

# 2. Build + start
cargo build --release -p openfang-cli
GROQ_API_KEY=<key> target/release/openfang.exe start &
Start-Sleep -Seconds 6
curl -s http://127.0.0.1:4200/api/health

# 3. Probe new endpoint
curl -s http://127.0.0.1:4200/api/<your-endpoint>

# 4. Verify side effects (budget, memory, etc.)
curl -s http://127.0.0.1:4200/api/budget

# 5. Verify dashboard HTML has new component
(Invoke-WebRequest http://127.0.0.1:4200/).Content | Select-String "myComponent"
```

Daemon command is `start` (not `daemon`). On Windows use `//F` if running via Git Bash for `taskkill`.

---

## Key API Endpoints Reference

| Endpoint                   | Method     | Purpose                     |
| -------------------------- | ---------- | --------------------------- |
| `/api/health`              | GET        | Health check                |
| `/api/agents`              | GET / POST | List / spawn agents         |
| `/api/agents/{id}/message` | POST       | Send message (triggers LLM) |
| `/api/budget`              | GET / PUT  | Global budget               |
| `/api/budget/agents`       | GET        | Per-agent cost ranking      |
| `/api/network/status`      | GET        | OFP network status          |
| `/api/peers`               | GET        | Connected OFP peers         |
| `/api/a2a/agents`          | GET        | External A2A agents         |
| `/api/a2a/discover`        | POST       | Discover external A2A agent |
| `/api/a2a/send`            | POST       | Send task to external A2A   |

---

## Common Gotchas

- **Never modify `openfang-cli`** — the interactive CLI is actively in development.
- `AgentLoopResult` response field is `.response`, not `.response_text`.
- New routes need registering in **both** `server.rs` (router) **and** `routes.rs` (handler).
- `KernelConfig` `Default` impl must stay in sync with the struct — missing fields = compile error.
- Integration tests use `tempfile::tempdir()` for isolation; always `KernelConfig::default()` as base.
- Dashboard is a pure SPA — no SSR. Static files are embedded in the binary at compile time.
