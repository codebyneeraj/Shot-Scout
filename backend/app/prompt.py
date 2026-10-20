from .schema import SuggestRequest

OUTPUT_SHAPE = """{
  "shots": [
    {
      "name": "BACKLIT SILHOUETTE",
      "size": "WS",
      "lens_mm": 24,
      "movement": "static",
      "light_plan": "silhouette",
      "reason": "One sentence: why this shot serves this scene in this light.",
      "best_window": "5:40 PM to 6:03 PM",
      "stock_query": "sunset silhouette beach",
      "settings": {
        "fps": 24, "shutter": "1/50", "iso": 100, "white_balance_k": 5600,
        "nd": "ND 0.9 (3 stops)", "aperture": "f/2.8", "profile": "Log, 4K, 16:9"
      }
    }
  ]
}"""


def build_image_query_prompt(scenes: list[tuple[str, str]]) -> str:
    listing = "\n\n".join(f"[{i}] {h}\n{t.strip() or '(no action lines)'}" for i, (h, t) in enumerate(scenes))
    return f"""For each film scene below, write one stock-photo search that would find a photo
of the scene's setting and mood, to use as the scene's cover image.

Rules:
- 3 to 6 plain words naming things a camera can see: the place, key objects, weather, light.
- Include the time of day or light (night, dawn, sunset, rain...) when the scene gives it.
- No character names, no camera terms, no abstract feelings.
- Example: "INT. KITCHEN - NIGHT / Rain hammers the window" -> "rainy kitchen window at night"

# Scenes
{listing}

Reply with JSON only, one query per scene in the same order:
{{"queries": ["...", "..."]}}"""


def build_prompt(req: SuggestRequest, knowledge: str) -> str:
    c = req.conditions
    # One user message (no system role): Gemma on the Gemini API does not
    # accept system instructions, and Groq models handle this fine too.
    return f"""You are ShotScout, an experienced cinematographer planning a shoot.
Recommend up to {req.max_shots} shots for the scene below, using ONLY the knowledge base and its
allowed vocabulary. Base every choice on the scene's mood and the real light on the day.

# Knowledge base
{knowledge}

# Scene
{req.heading}
{req.text.strip() or "(no action lines)"}

# Conditions
Date: {c.date}
Sunrise: {c.sunrise or "unknown"} · Sunset: {c.sunset or "unknown"}
Golden hour: {c.golden_hour or "unknown"} · Blue hour: {c.blue_hour or "unknown"}
Weather: {c.weather or "no forecast; assume seasonal norms"}

# Kit
{req.kit}
{f"# Style preset{chr(10)}{req.style}" if req.style else ""}

# Rules
- Only frame characters, objects and places that appear in the scene text. If no character
  appears, do not invent one: build the shots from the place, objects, light and weather.
- Aim for {req.max_shots} shots: a wide, a closer shot that holds the emotion, and at least one
  insert or movement shot. Go below {req.max_shots} only when the scene text gives too little to film.
- Order shots wide to tight, as they would be shot.
- best_window must use the times above; exterior shots must fit the light.
- Settings must follow the knowledge base (180° shutter, ND for bright light, manual white balance) and the kit.
- stock_query: 2-5 plain words to search stock footage for this kind of shot.
- Reply with JSON only, no markdown, exactly in this shape:
{OUTPUT_SHAPE}"""
