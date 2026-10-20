import pytest

from app import kb
from app.llm import parse_json
from app.schema import Shot

SECTIONS = kb.load_sections()


def titles(heading, text="", overcast=False):
    return [s.title for s in kb.retrieve(kb.scene_tags(heading, text, overcast), SECTIONS)]


def test_every_section_loads_with_tags():
    assert len(SECTIONS) > 20
    assert all(s.tags and s.text for s in SECTIONS)


def test_core_always_included():
    picked = titles("INT. ROOM - DAY")
    assert "Allowed shot values" in picked
    assert "Frame rate and shutter" in picked


def test_sunset_walk_gets_golden_hour_and_walk_and_talk():
    picked = titles("EXT. SEA PROMENADE - SUNSET", "Meera walks alone as the tide comes in.")
    assert "Golden hour" in picked
    assert "Walk and talk" in picked
    assert "Loneliness and isolation" in picked
    assert "Interior night" not in picked


def test_day_exterior_uses_weather():
    assert "Overcast" in titles("EXT. FIELD - DAY", overcast=True)
    assert "Harsh midday sun" in titles("EXT. FIELD - DAY")


def test_parse_json_strips_fences():
    assert parse_json('```json\n{"shots": []}\n```') == {"shots": []}


def test_shot_validation():
    base = dict(name="X", size="cu", lens_mm=80, movement="push-in", light_plan="backlit",
                reason="r", best_window="w", stock_query="q",
                settings=dict(fps=24, shutter="1/50", iso=100, white_balance_k=5600,
                              nd="ND 0.6", aperture="f/2", profile="Log"))
    shot = Shot.model_validate(base)
    assert shot.size == "CU" and shot.lens_mm == 85
    with pytest.raises(ValueError):
        Shot.model_validate({**base, "movement": "drone-orbit"})
