"""LLM providers. Pick one with LLM_PROVIDER=gemini|groq; models are env-configurable."""

import json
import os
import re

import httpx


class LLMError(RuntimeError):
    def __init__(self, message: str, retryable: bool = False):
        super().__init__(message)
        self.retryable = retryable  # overloaded or rate-limited: worth trying the fallback


def _check(r: httpx.Response, name: str) -> None:
    if r.status_code != 200:
        raise LLMError(f"{name} {r.status_code}: {r.text[:300]}",
                       retryable=r.status_code == 429 or r.status_code >= 500)


def _gemini(prompt: str, model: str) -> str:
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key:
        raise LLMError("GEMINI_API_KEY is not set")
    config: dict = {"temperature": 0.4}
    if not model.startswith("gemma"):
        config["responseMimeType"] = "application/json"  # Gemma does not support JSON mode
    r = httpx.post(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        headers={"x-goog-api-key": key},
        json={"contents": [{"role": "user", "parts": [{"text": prompt}]}], "generationConfig": config},
        timeout=45,
    )
    _check(r, "Gemini")
    parts = r.json()["candidates"][0]["content"]["parts"]
    return "".join(p.get("text", "") for p in parts)


def _groq(prompt: str, model: str) -> str:
    key = os.environ.get("GROQ_API_KEY")
    if not key:
        raise LLMError("GROQ_API_KEY is not set")
    r = httpx.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {key}"},
        json={
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.4,
            "response_format": {"type": "json_object"},
        },
        timeout=60,
    )
    _check(r, "Groq")
    return r.json()["choices"][0]["message"]["content"]


PROVIDERS = {
    "gemini": (_gemini, "GEMINI_MODEL", "gemini-flash-lite-latest"),
    "groq": (_groq, "GROQ_MODEL", "llama-3.3-70b-versatile"),
}
FALLBACKS = {"gemini": ("GEMINI_FALLBACK_MODEL", "gemini-2.5-flash-lite"),
             "groq": ("GROQ_FALLBACK_MODEL", "llama-3.1-8b-instant")}


def active() -> tuple[str, str]:
    provider = os.environ.get("LLM_PROVIDER", "gemini").lower()
    if provider not in PROVIDERS:
        raise LLMError(f"Unknown LLM_PROVIDER {provider!r}; use gemini or groq")
    _, model_env, default = PROVIDERS[provider]
    return provider, os.environ.get(model_env, default)


def complete(prompt: str) -> tuple[dict, str, str]:
    provider, model = active()
    fn = PROVIDERS[provider][0]

    def call(p: str, m: str) -> str:
        try:
            return fn(p, m)
        except httpx.HTTPError as e:  # timeouts and network errors
            raise LLMError(f"{provider} {type(e).__name__}: {e}", retryable=True) from e

    try:
        return parse_json(call(prompt, model)), provider, model
    except LLMError as e:
        env, default = FALLBACKS[provider]
        fallback = os.environ.get(env, default)
        if not e.retryable or not fallback or fallback == model:
            raise
        return parse_json(call(prompt, fallback)), provider, fallback


def parse_json(raw: str) -> dict:
    """Models without JSON mode sometimes wrap the answer in ```json fences or prose."""
    m = re.search(r"\{.*\}", raw, re.S)
    if not m:
        raise LLMError(f"No JSON in model reply: {raw[:200]}")
    try:
        return json.loads(m.group(0))
    except json.JSONDecodeError as e:
        raise LLMError(f"Bad JSON from model: {e}") from e
