from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    base_url: str = "http://localhost:8696"
    day_start_hour: int = 4
    target_hours: int = 12


def load_settings() -> Settings:
    return Settings(
        base_url=os.getenv("PERSONALE_BASE_URL", Settings.base_url),
        day_start_hour=int(
            os.getenv("PERSONALE_DAY_START_HOUR", str(Settings.day_start_hour))
        ),
        target_hours=int(os.getenv("PERSONALE_TARGET_HOURS", str(Settings.target_hours))),
    )
