# llm-gateway

A local gateway that lets Claude Code hand cheap or mechanical work (drafts, summaries, boilerplate, long-document reading) to free-tier models from several providers through one entry point, instead of spending Claude usage on it.

It is a module of ai-config and lives in `~/.claude/ai-config/llm-gateway`. All commands below run from that folder unless stated otherwise.

## Expected benefits

What this module is meant to bring:

- Stretch Claude usage. Mechanical work (first drafts, summaries, boilerplate, bulk reading of long logs or documents, a second opinion on a regex or a snippet) goes to free-tier models, so Claude's own quota is kept for reasoning and editing.
- One entry point and one config for every provider. Claude Code sees two tools, `ask_model` and `list_models`, and `litellm/config.yaml` lists every model. There is no separate CLI or key setup per provider.
- Automatic fallback. When one provider's free quota runs out or it rate limits, the proxy retries another deployment of the same group, and `fast` and `code` fall back to each other.
- A privacy guard. Requests marked `private=True` are refused unless the group is explicitly approved, so private or work code does not reach a free tier by accident.
- Reuse outside Claude Code. Any OpenAI-compatible tool can point at the same proxy and the same keys.

These benefits are expected, not measured. No real completion has been run yet (see "Status and limits"), and the quality, rate limits and availability of free-tier models vary and change. To measure the benefit later, count the `ask_model` calls made in a period and the tokens the gateway served (the `usage` field of each proxy response, or LiteLLM's spend logs), and compare them with the Claude usage those tasks would otherwise have taken.

## How to use

The short path from clone to first answer. Each step points to the detailed section further down.

1. Install: `~/.claude/ai-config/install.sh llm-gateway` from Git Bash creates `.venv`, installs the dependencies and creates `.env` from `.env.example`. Doing it by hand is described in "Install".
2. Keys: put a master key and at least one provider key in `.env`. See "Getting API keys" and "Configuration".
3. Start: `.\scripts\start-gateway.ps1` in its own PowerShell window. See "Running and checking".
4. Check: `.\scripts\check-gateway.ps1` in another window; it should list `fast`, `code` and `long-context`.
5. Register: run the `claude mcp add` command from "Registering with Claude Code" once, restart Claude Code, and confirm with `/mcp`.
6. First prompts: ask Claude Code to "call list_models", then "use ask_model with the fast group to ..." for a small task. See "Usage" for the tool parameters and more example prompts.

## Overview

The gateway has two parts:

- A LiteLLM proxy (LiteLLM is an open-source router that exposes many providers behind one OpenAI-compatible API) listening on `http://localhost:4000`. It defines three model groups, `fast`, `code` and `long-context`. Each group is a list of deployments (a specific model at a specific provider). If one fails or is rate limited, LiteLLM tries another.
- An MCP server (MCP is the Model Context Protocol, the way Claude Code loads extra tools) that runs over stdio and gives Claude Code two tools, `ask_model` and `list_models`. It also contains a privacy guard that refuses to send requests marked private to groups you have not explicitly approved.

Other OpenAI-compatible clients can call the proxy directly.

## Architecture

```
Claude Code
    |  stdio (MCP)
    v
MCP server  (mcp_server/server.py: ask_model, list_models, privacy guard)
    |  HTTP, OpenAI-compatible, Bearer master key
    v
LiteLLM proxy  http://localhost:4000   (litellm/config.yaml)
    |  groups: fast, code, long-context  (retry, cooldown, fallback)
    v
Gemini | Groq | Cerebras | OpenRouter ":free" models
```

Claude Code starts the MCP server itself when it needs it. The proxy is a separate process that you start with a script and leave running. A diagram is in `docs/architecture.excalidraw`; open it at https://excalidraw.com or with the Excalidraw VS Code extension.

## Prerequisites

- Windows 11 with PowerShell.
- Python 3.10 or newer (tested with Python 3.12).
- Claude Code installed, for the MCP integration.
- At least one provider API key (see "Getting API keys"). The proxy starts without any, but no request will succeed.

## Install

The quickest way is the ai-config installer, from Git Bash:

```sh
~/.claude/ai-config/install.sh llm-gateway
```

It creates `.venv` if it does not exist, installs the dependencies if they are missing, creates `.env` from `.env.example` if there is none, and prints the next steps. It does not register anything with Claude Code. Running it again is safe. It falls back to the `--without-pip` route below on its own.

By hand, in PowerShell:

```powershell
cd $HOME\.claude\ai-config\llm-gateway
python -m venv .venv
.\.venv\Scripts\python -m pip install "litellm[proxy]" "mcp>=2" httpx pytest
```

If `python -m venv .venv` fails with an ensurepip error (some Python installs ship without the bundled pip wheel), delete the partial `.venv`, create it without pip and install into it with the system pip:

```powershell
Remove-Item -Recurse -Force .venv
python -m venv --without-pip .venv
python -m pip --python .\.venv\Scripts\python.exe install "litellm[proxy]" "mcp>=2" httpx pytest
```

The package list matches `pyproject.toml`, but `pip install .` from the project file is not documented here: `pyproject.toml` has no build configuration, and the project is a set of scripts, not an installable package.

`mcp` must be version 2 or newer. The current LiteLLM proxy does not start with mcp 1.x.

If you installed by hand, create your settings file (the installer already did this), then open it:

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
```

## Getting API keys

Each provider's key is created on its own site. You only need the providers you want to use; deployments without a key are skipped at call time.

- Gemini (Google AI Studio): https://aistudio.google.com/apikey (redirects to Google sign-in, as expected)
- Groq: https://console.groq.com/keys
- Cerebras: https://cloud.cerebras.ai/ (sign in, then create a key in the dashboard)
- OpenRouter: https://openrouter.ai/settings/keys

Also choose a master key: any long random string. It is the password for your own proxy, not a provider key. You can generate one with:

```powershell
"sk-" + [guid]::NewGuid().ToString("N")
```

## Configuration

Settings live in `.env` (ignored by git). `scripts\start-gateway.ps1` and `scripts\check-gateway.ps1` read it; lines with an empty value are skipped. Lines starting with `#` are ignored and surrounding double quotes are removed from values; single quotes are kept as part of the value, so do not wrap keys in single quotes.

| Variable | Used by | Meaning |
| --- | --- | --- |
| `LITELLM_MASTER_KEY` | proxy, scripts | Required. Key clients must send to the proxy. The start script refuses to run without it. |
| `GEMINI_API_KEY` | proxy | Google AI Studio key. |
| `GROQ_API_KEY` | proxy | Groq key. |
| `CEREBRAS_API_KEY` | proxy | Cerebras key. |
| `OPENROUTER_API_KEY` | proxy | OpenRouter key. |
| `LLM_GATEWAY_URL` | MCP server, check script | Proxy address. Defaults to `http://localhost:4000`. |
| `LLM_GATEWAY_KEY` | MCP server, check script | Key the MCP server sends. Falls back to `LITELLM_MASTER_KEY` if empty. Set it to the master key. |
| `PRIVATE_SAFE_GROUPS` | MCP server | Comma-separated groups that may receive `private=True` requests. Empty by default. See "Privacy guard". |

Important: Claude Code starts the MCP server, and the MCP server does not read `.env`. Its three variables (`LLM_GATEWAY_URL`, `LLM_GATEWAY_KEY`, `PRIVATE_SAFE_GROUPS`) are passed at registration time, see below.

## Running and checking

Start the proxy in its own PowerShell window and leave it open. It binds to 127.0.0.1:4000 only. The first start can be slow: it took about three minutes in testing before the proxy answered, so wait for the startup output before running the check.

```powershell
.\scripts\start-gateway.ps1
```

In another window, check it. This calls the liveness endpoint and lists the model groups:

```powershell
.\scripts\check-gateway.ps1
```

Run the unit tests (8 tests; they use fake HTTP responses and need no network or keys):

```powershell
.\.venv\Scripts\python -m pytest -q
```

## Registering with Claude Code

Run this yourself, once, in PowerShell. Replace `<master key>` with your `LITELLM_MASTER_KEY` value. The paths assume the documented clone location `~/.claude/ai-config`; PowerShell expands `$HOME` inside the double quotes, so Claude Code stores absolute paths.

```powershell
$key = "<master key>"
claude mcp add llm-gateway --scope user -e LLM_GATEWAY_URL=http://localhost:4000 -e LLM_GATEWAY_KEY=$key -e PRIVATE_SAFE_GROUPS= -- "$HOME\.claude\ai-config\llm-gateway\.venv\Scripts\python.exe" "$HOME\.claude\ai-config\llm-gateway\mcp_server\server.py"
```

`--scope user` makes the server available in every project. Drop it to register for the current project only.

File-based alternative: copy `.mcp.json.example` to `.mcp.json` in the project where you want the tools, and replace `your-litellm-master-key`. Its paths use `${USERPROFILE}`, which Claude Code expands from the environment when it reads `.mcp.json`; edit them if your clone is not in `~/.claude/ai-config`. Do not commit that file with a real key.

Restart Claude Code after registering, then run `/mcp` to confirm `llm-gateway` is listed.

## Usage

The proxy must be running. Claude Code gets two tools:

- `ask_model(prompt, group="fast", system=None, max_tokens=None, private=False)`
  - `prompt`: the text to send.
  - `group`: `fast`, `code` or `long-context`.
  - `system`: optional system prompt.
  - `max_tokens`: optional cap on the reply length.
  - `private`: if true, the request is refused unless the group is in `PRIVATE_SAFE_GROUPS`.
  - The reply ends with `[answered by: <model>]`, naming the deployment that actually answered.
- `list_models()`: returns the model group names the proxy exposes, one per line.

Example prompts to give Claude Code:

- "Call list_models and tell me which groups are available."
- "Use ask_model with the code group to draft a regex that validates ISO 8601 dates, with five test strings. Then review the answer before using it."
- "Use ask_model with the long-context group to summarise this 4,000-line log file into ten bullet points." (Claude must paste the content into the prompt, so only do this for non-sensitive text.)
- "Use ask_model with the fast group to rename these 30 variables to snake_case and return only the list."

Answers come from small free models and can be wrong. Treat them as drafts.

## Model groups

Defined in `litellm/config.yaml`. Routing within a group is `simple-shuffle` (random pick among available deployments).

| Group | Provider | Model ID | Free-tier note (checked 2026-11-13) |
| --- | --- | --- | --- |
| `fast` | Gemini | `gemini-3.5-flash-lite` | Listed as free of charge on the AI Studio pricing page; rate limits not obtained. |
| `fast` | Groq | `llama-3.1-8b-instant` | Model ID exists; whether the free plan covers it is unconfirmed. Check your Groq account. |
| `fast` | Cerebras | `gpt-oss-120b` | Free tier is a $5 trial credit that expires after 30 days; paid afterwards. |
| `fast` | OpenRouter | `google/gemma-4-31b-it:free` | ID confirmed in the live model listing. |
| `code` | Groq | `openai/gpt-oss-120b` | Model ID exists; free-plan coverage unconfirmed. |
| `code` | Cerebras | `qwen-3.8-27b` | $5 trial credit, expires after 30 days. |
| `code` | OpenRouter | `cohere/north-mini-code:free` | ID confirmed in the live model listing. |
| `code` | Gemini | `gemini-3.6-flash` | Listed as free of charge on the AI Studio pricing page; rate limits not obtained. |
| `long-context` | Gemini | `gemini-3.6-flash` | As above. |
| `long-context` | OpenRouter | `thinkingmachines/inkling-2-small:free` | ID confirmed in the live model listing. |
| `long-context` | OpenRouter | `nvidia/nemotron-3-ultra-550b-a55b:free` | ID confirmed in the live model listing. |
| `long-context` | OpenRouter | `baidu/ernie-5.5-flash-preview:free` | ID confirmed in the live model listing. |

The three OpenRouter models in `long-context` were listed with context windows of about one million tokens on 2026-11-13; the Gemini window was not checked, so confirm each model's limit before sending very large inputs. OpenRouter `:free` models are themselves rate limited and may change or disappear.

Not included:

- GitHub Models: retired on 2026-07-30 according to GitHub's documentation.
- Mistral: no current free API tier could be confirmed.
- DeepSeek and Kimi: no free variants on OpenRouter at the time of checking, and their own APIs are paid. You can add them as paid deployments, see "Changing or adding models and providers".

## How fallback works

- Within a group: if a deployment fails or is rate limited, LiteLLM retries (`num_retries: 2`) and moves to another deployment of the same group. A failing deployment is put in cooldown for 60 seconds (`cooldown_time: 60`, `allowed_fails: 1`).
- Across groups: `fast` falls back to `code`, and `code` falls back to `fast`. `long-context` has no cross-group fallback.
- Per-request timeout at the proxy is 60 seconds; the MCP server waits up to 120 seconds.
- A deployment whose provider key is missing does not stop the proxy from starting. It fails at call time and the router moves on. With no keys at all, a call returns a "Missing credentials" error.

The `[answered by: ...]` line on every reply shows which deployment answered, including after a fallback.

## Privacy guard

Free tiers often allow the provider to train on your prompts. To keep private or work code away from them, `ask_model(private=True)` is refused unless the requested group is listed in `PRIVATE_SAFE_GROUPS`. The variable is empty by default, so every private request is refused. A refused call sends nothing to the proxy.

Warning: do not put `fast` or `code` in `PRIVATE_SAFE_GROUPS`. They contain free-tier deployments and fall back into each other, so a "private" request could still reach a free provider.

The safe way is a dedicated group that contains only providers whose terms exclude training on prompts (typically paid tiers), with no fallback into other groups. Example for `litellm/config.yaml`; the model and key name are placeholders to replace with a provider you have verified:

```yaml
model_list:
  - model_name: private
    litellm_params:
      model: PROVIDER/PLACEHOLDER-MODEL
      api_key: os.environ/PRIVATE_PROVIDER_API_KEY
```

Do not add `private` to `router_settings.fallbacks`, and do not make another group fall back to it unless that is intended. Add the key to `.env`, restart the proxy, then re-register the MCP server with `-e PRIVATE_SAFE_GROUPS=private` and call `ask_model` with `group="private"` and `private=True`. Read the provider's data terms yourself; this project does not verify them.

## Changing or adding models and providers

Edit `litellm\config.yaml`, then restart `start-gateway.ps1`.

- To change a model, edit the `model:` line of a deployment. The format is `provider/model-id`, for example `groq/openai/gpt-oss-120b`.
- To add a deployment to a group, add another `model_list` entry with the same `model_name`.
- To add a provider, add an entry with its LiteLLM prefix, and an environment variable for its key in `.env`. For a paid provider such as DeepSeek or Mistral:

```yaml
  - model_name: code
    litellm_params:
      model: PROVIDER/MODEL-ID
      api_key: os.environ/PROVIDER_API_KEY
```

  Look up the exact prefix and model ID in LiteLLM's provider list: https://docs.litellm.ai/docs/providers . Paid deployments cost money and, in a group that falls back to others, may be used instead of free ones, so consider a separate group.
- New group names work in `ask_model` straight away; `list_models` shows them after the proxy restarts.

## Using the proxy from other OpenAI-compatible clients

Settings for any client:

- Base URL: `http://localhost:4000/v1`
- API key: your `LITELLM_MASTER_KEY`
- Model: a group name (`fast`, `code`, `long-context`)

PowerShell example:

```powershell
$key = "<master key>"
$body = @{ model = "fast"; messages = @(@{ role = "user"; content = "Say hello in five words." }) } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri http://localhost:4000/v1/chat/completions -Method Post -Headers @{ Authorization = "Bearer $key" } -ContentType "application/json" -Body $body
```

curl example (use `curl.exe`, because `curl` in PowerShell is an alias):

```powershell
curl.exe http://localhost:4000/v1/chat/completions -H "Authorization: Bearer <master key>" -H "Content-Type: application/json" -d '{\"model\":\"fast\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'
```

Direct calls bypass the privacy guard, which exists only in the MCP server.

## Troubleshooting

- Proxy not reachable (`LiteLLM proxy not reachable at ...`): the proxy is not running. Start `.\scripts\start-gateway.ps1` and confirm with `.\scripts\check-gateway.ps1`.
- 401 from the proxy: the key sent does not match `LITELLM_MASTER_KEY`. The MCP server uses the `LLM_GATEWAY_KEY` given at registration, which is separate from `.env`. Fix it with `claude mcp remove llm-gateway` and register again.
- "Missing credentials": the deployments tried have no API key. Add keys to `.env` and restart the proxy.
- Port 4000 in use: find the process with `netstat -ano | findstr :4000` and stop it, or change `--port` in `start-gateway.ps1` and set `LLM_GATEWAY_URL` to match.
- mcp version error when the proxy or server starts: mcp is 1.x. Run `python -m pip --python .\.venv\Scripts\python.exe install -U "mcp>=2"`.
- `python -m venv .venv` fails with an ensurepip error: the Python install has no bundled pip wheel. Delete the partial `.venv` and use the `--without-pip` route described in "Install" (`install.sh llm-gateway` does this on its own).
- `Refused: private=True ...`: working as designed, see "Privacy guard".
- `start-gateway.ps1` cannot run scripts: run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once, or start it with `powershell -ExecutionPolicy Bypass -File .\scripts\start-gateway.ps1`.

## Status and limits

Verified: the 8 unit tests pass; `start-gateway.ps1` refuses to run without `LITELLM_MASTER_KEY` and, with it set, starts the proxy on 127.0.0.1:4000 with no provider keys; the liveness endpoint and `/v1/models` respond; `check-gateway.ps1` lists the three groups when the proxy is up and exits with an error when it is down; a private request is refused by the guard; a call with no provider keys returns a "Missing credentials" error instead of crashing; the MCP server answers `initialize` over stdio.

Not verified, because no API keys were available: any real completion, real fallback and cooldown behaviour, and Claude Code actually loading the server. The registration command has not been run.

Other limits: free-tier rate limits and availability are unknown or can change; model IDs were checked on 2026-11-13 and may go stale; the Cerebras and Groq entries may not be free for you.

First-run checklist:

1. Put `LITELLM_MASTER_KEY` and at least one provider key in `.env`.
2. Run `.\scripts\start-gateway.ps1`.
3. Run `.\scripts\check-gateway.ps1` and confirm the three groups are listed.
4. Run the registration command and restart Claude Code.
5. Ask Claude Code to call `list_models`, then `ask_model` with a short prompt and the `fast` group. Check the `[answered by: ...]` line.
6. Optionally stop one provider's key (blank it, restart the proxy) to see the fallback in action.

## Project layout

Inside the ai-config clone:

```
llm-gateway/
  README.md
  pyproject.toml           dependency list and pytest settings
  .gitignore               keeps .env, .venv, caches and logs out of git
  .env.example             template for .env
  .mcp.json.example        file-based Claude Code registration
  litellm/config.yaml      model groups, retries, fallback, master key
  mcp_server/server.py     MCP server exposing ask_model and list_models
  mcp_server/gateway.py    HTTP calls to the proxy and the privacy guard
  scripts/start-gateway.ps1  loads .env and starts the proxy on 127.0.0.1:4000
  scripts/check-gateway.ps1  liveness and model group check
  tests/test_gateway.py    unit tests
  docs/architecture.excalidraw  architecture diagram
```
