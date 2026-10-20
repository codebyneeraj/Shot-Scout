from pathlib import Path

from dotenv import load_dotenv

# Load backend/.env before anything reads API keys. Real environment variables win.
ENV_FILE = Path(__file__).resolve().parent.parent / ".env"
# On Render the keys come from a secret file mounted here instead of the repo.
if not ENV_FILE.exists() and Path("/etc/secrets/.env").exists():
    ENV_FILE = Path("/etc/secrets/.env")
load_dotenv(ENV_FILE)

from fastapi import FastAPI, HTTPException  # noqa: E402
from pydantic import ValidationError  # noqa: E402

from . import kb, llm, stock  # noqa: E402
from .prompt import build_image_query_prompt, build_prompt  # noqa: E402
from .schema import SceneImagesRequest, Shot, SuggestRequest, SuggestResponse  # noqa: E402

import os  # noqa: E402

from fastapi import Request  # noqa: E402
from fastapi.responses import JSONResponse  # noqa: E402

app = FastAPI(title="ShotScout backend")


@app.middleware("http")
async def require_app_key(request: Request, call_next):
    """When APP_KEY is set (in production), only the app may call the API, so a
    leaked URL can't burn the AI and photo quotas. /health stays open for wake-ups."""
    key = os.environ.get("APP_KEY")
    if key and request.url.path != "/health" and request.headers.get("x-app-key") != key:
        return JSONResponse({"detail": "Missing or wrong app key"}, status_code=401)
    return await call_next(request)
SECTIONS = kb.load_sections()


@app.get("/health")
def health():
    provider, model = llm.active()
    return {"ok": True, "provider": provider, "model": model, "knowledge_sections": len(SECTIONS),
            "stock": stock.configured()}


@app.get("/stock/image")
def stock_image(q: str):
    """One landscape photo for a search like "sea promenade sunset", with its credit."""
    load_dotenv(ENV_FILE)  # pick up stock keys added after startup, without a restart
    if not stock.configured():
        raise HTTPException(503, "No stock API key set (UNSPLASH_ACCESS_KEY, PEXELS_API_KEY or PIXABAY_API_KEY)")
    hit = stock.search_image(q)
    if not hit:
        raise HTTPException(404, f"No photo found for {q!r}")
    return hit


# AI-written photo searches, keyed by scene heading and text. They never change for
# the same scene, so this saves an AI call every time a scene list is reopened.
_QUERY_CACHE: dict[tuple[str, str], str] = {}


def _fallback_query(heading: str) -> str:
    """Place plus time of day from the heading, e.g. "railway platform dawn"."""
    h = heading.split(".", 1)[-1]
    place, _, when = h.partition(" - ")
    return f"{place} {when}".strip().lower()


def _image_queries(scenes: list[tuple[str, str]]) -> list[str]:
    todo = [s for s in dict.fromkeys(scenes) if s not in _QUERY_CACHE]
    if todo:
        try:
            data, _, _ = llm.complete(build_image_query_prompt(todo))
            queries = data.get("queries", [])
        except llm.LLMError:
            queries = []
        for i, scene in enumerate(todo):
            q = queries[i] if i < len(queries) and isinstance(queries[i], str) and queries[i].strip() else None
            if q:
                _QUERY_CACHE[scene] = " ".join(q.split()[:8])
    return [_QUERY_CACHE.get(s) or _fallback_query(s[0]) for s in scenes]


@app.post("/scene-images")
def scene_images(req: SceneImagesRequest):
    """A cover photo per scene. One AI call writes all the photo searches."""
    load_dotenv(ENV_FILE)
    scenes = [(s.heading, s.text) for s in req.scenes]
    queries = _image_queries(scenes)
    has_stock = bool(stock.configured())
    return {"images": [
        {"query": q, **(stock.search_image(q) or {})} if has_stock else {"query": q}
        for q in queries
    ]}


@app.post("/suggest-shots", response_model=SuggestResponse)
def suggest_shots(req: SuggestRequest):
    tags = kb.scene_tags(req.heading, f"{req.text} {req.style or ''}", req.conditions.overcast)
    picked = kb.retrieve(tags, SECTIONS)
    prompt = build_prompt(req, kb.render(picked))
    try:
        data, provider, model = llm.complete(prompt)
    except llm.LLMError as e:
        raise HTTPException(502, str(e)) from e

    # Keep shots that fit the vocabulary; drop the rest instead of failing the request.
    shots, rejected = [], 0
    for raw in data.get("shots", [])[: req.max_shots]:
        try:
            shots.append(Shot.model_validate(raw))
        except ValidationError:
            rejected += 1
    if not shots:
        raise HTTPException(502, "Model returned no valid shots")

    return SuggestResponse(
        shots=shots,
        provider=provider,
        model=model,
        knowledge_used=[f"{s.source}: {s.title}" for s in picked],
        rejected=rejected,
    )
