from app import main


def test_fallback_query_uses_place_and_time():
    assert main._fallback_query("EXT. RAILWAY PLATFORM - DAWN") == "railway platform dawn"
    assert main._fallback_query("INT. KITCHEN") == "kitchen"


def test_image_queries_batch_once_and_cache(monkeypatch):
    calls = []

    def fake_complete(prompt):
        calls.append(prompt)
        return {"queries": ["rainy kitchen window at night", "  "]}, "test", "test"

    monkeypatch.setattr(main.llm, "complete", fake_complete)
    main._QUERY_CACHE.clear()
    scenes = [("INT. KITCHEN - NIGHT", "Rain."), ("EXT. BEACH - DAY", "")]

    assert main._image_queries(scenes) == ["rainy kitchen window at night", "beach day"]
    assert len(calls) == 1
    # The kitchen query is cached; only the beach (blank answer) is asked again.
    main._image_queries(scenes)
    assert len(calls) == 2
    assert "[0] EXT. BEACH - DAY" in calls[1] and "[1]" not in calls[1]
