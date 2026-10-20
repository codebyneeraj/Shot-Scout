"""Cinematography knowledge base and tag-based retrieval (the "R" in RAG).

Knowledge lives in knowledge/*.md. Each `## ` section starts with a `tags:` line.
Sections tagged `core` are always sent; the rest are ranked by how many of their
tags match the scene. No embeddings: the KB is small, hand-written and tagged, so
keyword/tag matching is predictable and free. Swap in embeddings when it grows.
"""

import re
from dataclasses import dataclass
from pathlib import Path

KNOWLEDGE_DIR = Path(__file__).resolve().parent.parent / "knowledge"


@dataclass(frozen=True)
class Section:
    source: str
    title: str
    tags: frozenset[str]
    text: str

    @property
    def core(self) -> bool:
        return "core" in self.tags


def load_sections(directory: Path = KNOWLEDGE_DIR) -> list[Section]:
    sections = []
    for path in sorted(directory.glob("*.md")):
        for block in re.split(r"^## ", path.read_text(encoding="utf-8"), flags=re.M)[1:]:
            title, _, rest = block.partition("\n")
            m = re.match(r"\s*tags:\s*(.+)\n", rest)
            if not m:
                raise ValueError(f"{path.name}: section '{title}' has no tags: line")
            tags = frozenset(t.strip().lower() for t in m.group(1).split(","))
            body = re.split(r"^# ", rest[m.end():], flags=re.M)[0].strip()
            sections.append(Section(path.stem, title.strip(), tags, body))
    return sections


def scene_tags(heading: str, text: str, overcast: bool = False) -> set[str]:
    """Tags describing a scene, from its heading, its words and the weather."""
    h = heading.upper()
    tags = {"exterior"} if "EXT" in h else set()
    if "INT" in h and "EXT" not in h.split("INT")[0]:
        tags.add("interior")
    time_tags = {
        "NIGHT": ["night"], "DAWN": ["dawn", "blue_hour"], "DUSK": ["dusk", "blue_hour"],
        "TWILIGHT": ["blue_hour"], "SUNSET": ["sunset", "golden_hour"],
        "SUNRISE": ["sunrise", "golden_hour"], "MAGIC": ["golden_hour"],
        "DAY": ["day"], "MORNING": ["day"], "AFTERNOON": ["day"], "NOON": ["day", "noon"],
    }
    for word, ts in time_tags.items():
        if word in h:
            tags.update(ts)
    if "exterior" in tags and "day" in tags:
        tags.add("overcast" if overcast else "harsh_sun")
    words = set(re.findall(r"[a-z]+", f"{heading} {text}".lower()))
    tags.update(words)
    return tags


# Tags that only narrow context. They add a little score but cannot select a section alone.
BROAD = {"exterior", "interior", "day"}


def _matches(section_tags: frozenset[str], tags: set[str]) -> float:
    # Prefix match so "walks"/"walking" hit the tag "walk".
    hits = {t for t in section_tags if any(w == t or (len(t) > 3 and w.startswith(t)) for w in tags)}
    specific = len(hits - BROAD)
    return specific + 0.25 * len(hits & BROAD) if specific else 0


def retrieve(tags: set[str], sections: list[Section], max_sections: int = 7) -> list[Section]:
    core = [s for s in sections if s.core]
    scored = [(_matches(s.tags, tags), s) for s in sections if not s.core]
    ranked = [s for score, s in sorted(scored, key=lambda x: -x[0]) if score > 0]
    return core + ranked[:max_sections]


def render(sections: list[Section]) -> str:
    return "\n\n".join(f"### {s.title}\n{s.text}" for s in sections)
