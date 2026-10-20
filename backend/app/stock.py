"""Stock photos from Unsplash (preferred), Pexels or Pixabay, with the credit each site requires.

Keys stay on the backend. Results are cached per query for 24 hours, as Pixabay asks.
"""

import logging
import os
import time

import httpx

log = logging.getLogger("uvicorn.error")
# httpx logs full request URLs at INFO, and Pixabay takes its key in the URL.
logging.getLogger("httpx").setLevel(logging.WARNING)

_CACHE: dict[str, tuple[float, dict | None]] = {}
_TTL = 24 * 3600


_UTM = "utm_source=shotscout&utm_medium=referral"


def _unsplash(query: str, key: str) -> dict | None:
    headers = {"Authorization": f"Client-ID {key}", "Accept-Version": "v1"}
    r = httpx.get(
        "https://api.unsplash.com/search/photos",
        params={"query": query, "per_page": 1, "orientation": "landscape", "content_filter": "high"},
        headers=headers,
        timeout=10,
    )
    r.raise_for_status()
    results = r.json().get("results") or []
    if not results:
        return None
    p = results[0]
    # Unsplash guidelines: report each photo we show via its download_location.
    try:
        httpx.get(p["links"]["download_location"], headers=headers, timeout=5)
    except httpx.HTTPError:
        pass
    return {
        # Hotlinked, as Unsplash requires; "regular" is 1080px wide.
        "url": p["urls"]["regular"],
        "credit": f"Photo by {p['user']['name']} on Unsplash",
        "link": f"{p['links']['html']}?{_UTM}",
        "source": "unsplash",
    }


def _pexels(query: str, key: str) -> dict | None:
    r = httpx.get(
        "https://api.pexels.com/v1/search",
        params={"query": query, "per_page": 1, "orientation": "landscape"},
        headers={"Authorization": key},
        timeout=10,
    )
    r.raise_for_status()
    photos = r.json().get("photos") or []
    if not photos:
        return None
    p = photos[0]
    return {
        "url": p["src"]["large"],
        "credit": f"Photo by {p['photographer']} on Pexels",
        "link": p["url"],
        "source": "pexels",
    }


def _pixabay(query: str, key: str) -> dict | None:
    r = httpx.get(
        "https://pixabay.com/api/",
        params={"key": key, "q": query, "image_type": "photo", "orientation": "horizontal",
                "per_page": 3, "safesearch": "true"},
        timeout=10,
    )
    r.raise_for_status()
    hits = r.json().get("hits") or []
    if not hits:
        return None
    h = hits[0]
    return {
        "url": h["largeImageURL"],
        "credit": f"Image by {h['user']} on Pixabay",
        "link": h["pageURL"],
        "source": "pixabay",
    }


# Tried in this order; the first with a key and a match wins.
_PROVIDERS = (
    ("unsplash", _unsplash, "UNSPLASH_ACCESS_KEY"),
    ("pexels", _pexels, "PEXELS_API_KEY"),
    ("pixabay", _pixabay, "PIXABAY_API_KEY"),
)


def configured() -> list[str]:
    return [name for name, _, env in _PROVIDERS if os.environ.get(env)]


def search_image(query: str) -> dict | None:
    query = " ".join(query.lower().split())[:100]
    hit = _CACHE.get(query)
    if hit and time.time() - hit[0] < _TTL:
        return hit[1]

    result, failed = None, False
    for name, fn, env in _PROVIDERS:
        key = os.environ.get(env)
        if not key:
            continue
        try:
            result = fn(query, key)
        except httpx.HTTPError as e:
            # Fall through to the next provider, but say why (a bad key looks like this).
            status = getattr(getattr(e, "response", None), "status_code", type(e).__name__)
            log.warning("%s photo search failed (%s); trying the next provider", name, status)
            failed = True
            continue
        if result:
            break
    # Cache only clean answers, so fixing a broken key takes effect straight away.
    if not failed:
        _CACHE[query] = (time.time(), result)
    return result
