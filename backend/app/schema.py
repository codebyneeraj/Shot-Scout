from pydantic import BaseModel, Field, field_validator

SIZES = {"EWS", "WS", "MWS", "MS", "MCU", "CU", "ECU", "INSERT", "OTS", "POV", "TWO-SHOT"}
LENSES = {14, 18, 24, 28, 35, 50, 85, 100, 135}
MOVEMENTS = {"static", "pan", "tilt", "push-in", "pull-out", "tracking", "handheld",
             "gimbal", "crane", "dolly-zoom", "whip-pan"}
LIGHT_PLANS = {"natural", "backlit", "silhouette", "side-light", "soft-overcast", "low-key",
               "high-key", "practical", "motivated-window", "negative-fill", "bounce-fill"}


class Conditions(BaseModel):
    date: str
    sunrise: str | None = None
    sunset: str | None = None
    golden_hour: str | None = None
    blue_hour: str | None = None
    weather: str | None = None
    overcast: bool = False


class SuggestRequest(BaseModel):
    heading: str
    text: str = ""
    conditions: Conditions
    kit: str = "Phone with Blackmagic Camera app"
    style: str | None = None
    max_shots: int = Field(4, ge=1, le=8)


class SceneText(BaseModel):
    heading: str
    text: str = ""


class SceneImagesRequest(BaseModel):
    scenes: list[SceneText] = Field(..., min_length=1, max_length=30)


class CameraSettings(BaseModel):
    fps: int
    shutter: str
    iso: int
    white_balance_k: int
    nd: str
    aperture: str
    profile: str


class Shot(BaseModel):
    name: str
    size: str
    lens_mm: int
    movement: str
    light_plan: str
    reason: str
    best_window: str
    stock_query: str
    settings: CameraSettings

    @field_validator("size")
    @classmethod
    def _size(cls, v: str) -> str:
        v = v.upper()
        if v not in SIZES:
            raise ValueError(f"size {v!r} not in vocabulary")
        return v

    @field_validator("lens_mm")
    @classmethod
    def _lens(cls, v: int) -> int:
        # Snap to the nearest allowed focal length rather than reject.
        return min(LENSES, key=lambda x: abs(x - v))

    @field_validator("movement")
    @classmethod
    def _movement(cls, v: str) -> str:
        v = v.lower()
        if v not in MOVEMENTS:
            raise ValueError(f"movement {v!r} not in vocabulary")
        return v

    @field_validator("light_plan")
    @classmethod
    def _light(cls, v: str) -> str:
        v = v.lower()
        if v not in LIGHT_PLANS:
            raise ValueError(f"light_plan {v!r} not in vocabulary")
        return v


class SuggestResponse(BaseModel):
    shots: list[Shot]
    provider: str
    model: str
    knowledge_used: list[str]
    rejected: int = 0
