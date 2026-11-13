import os

import httpx


def settings():
    return {
        "url": os.environ.get("LLM_GATEWAY_URL", "http://localhost:4000").rstrip("/"),
        "key": os.environ.get("LLM_GATEWAY_KEY") or os.environ.get("LITELLM_MASTER_KEY", ""),
        "safe": private_safe_groups(),
    }


def private_safe_groups():
    raw = os.environ.get("PRIVATE_SAFE_GROUPS", "")
    return {g.strip() for g in raw.split(",") if g.strip()}


def check_private(group, private, safe_groups):
    if not private or group in safe_groups:
        return None
    return (
        f"Refused: private=True but group '{group}' is not listed in PRIVATE_SAFE_GROUPS. "
        "Free-tier providers may train on prompts, so private or work code is never sent to them by default. "
        "Add the group to PRIVATE_SAFE_GROUPS only if every deployment in it is safe for private data."
    )


def build_payload(prompt, group, system=None, max_tokens=None):
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})
    payload = {"model": group, "messages": messages}
    if max_tokens:
        payload["max_tokens"] = max_tokens
    return payload


def format_answer(data):
    text = data["choices"][0]["message"]["content"] or ""
    return f"{text}\n\n[answered by: {data.get('model', 'unknown')}]"


def _headers(key):
    return {"Authorization": f"Bearer {key}"} if key else {}


def _error(exc, url):
    if isinstance(exc, httpx.ConnectError):
        return f"Error: LiteLLM proxy not reachable at {url}. Start it with scripts/start-gateway.ps1."
    if isinstance(exc, httpx.HTTPStatusError):
        return f"Error: proxy returned {exc.response.status_code}: {exc.response.text[:500]}"
    return f"Error: {type(exc).__name__}: {exc}"


def ask(prompt, group="fast", system=None, max_tokens=None, private=False, client=None):
    cfg = settings()
    refusal = check_private(group, private, cfg["safe"])
    if refusal:
        return refusal
    payload = build_payload(prompt, group, system, max_tokens)
    try:
        http = client or httpx
        resp = http.post(
            f"{cfg['url']}/v1/chat/completions",
            json=payload,
            headers=_headers(cfg["key"]),
            timeout=120,
        )
        resp.raise_for_status()
        return format_answer(resp.json())
    except Exception as exc:
        return _error(exc, cfg["url"])


def groups(client=None):
    cfg = settings()
    try:
        http = client or httpx
        resp = http.get(f"{cfg['url']}/v1/models", headers=_headers(cfg["key"]), timeout=15)
        resp.raise_for_status()
        return sorted({m["id"] for m in resp.json()["data"]})
    except Exception as exc:
        return _error(exc, cfg["url"])
