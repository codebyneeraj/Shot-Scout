"""Live check of shot suggestions against real scenes (calls the LLM; not part of pytest).

Run: python -m tests.eval_scenes
Flags shots whose reason or name mentions a person when the scene has no character.
"""

import re

from fastapi.testclient import TestClient

from app.main import app

SCENES = [
    ("EXT. RAILWAY PLATFORM - DAWN", "Mist over empty tracks. A single lamp still burns.", False),
    ("INT. ABANDONED HOUSE - NIGHT", "Wind rattles a broken window. Dust drifts through a beam of moonlight.", False),
    ("EXT. SEA PROMENADE - SUNSET", "Meera walks alone as the tide comes in.", True),
    ("INT. TEA STALL - DAY", "A stranger asks Meera for directions to the station. She hesitates.", True),
]
PERSON = re.compile(r"\b(character|actor|her|his|she|he|face|eyes|person|protagonist|someone)\b", re.I)


def main() -> None:
    client = TestClient(app)
    failures = 0
    for heading, text, has_character in SCENES:
        r = client.post("/suggest-shots", json={"heading": heading, "text": text,
                                                "conditions": {"date": "2026-10-23", "sunrise": "6:36 AM",
                                                               "sunset": "6:12 PM"}})
        data = r.json()
        print(f"\n{heading}  [{data.get('model')}]")
        for s in data.get("shots", []):
            invented = not has_character and PERSON.search(f"{s['name']} {s['reason']}")
            failures += bool(invented)
            print(f"  {'INVENTED PERSON ' if invented else ''}{s['name']} | {s['size']} {s['lens_mm']}mm | {s['reason']}")
        if r.status_code != 200:
            failures += 1
            print("  ERROR", data)
    print(f"\n{failures} problem(s)")


if __name__ == "__main__":
    main()
