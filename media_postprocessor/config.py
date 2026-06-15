"""Environment-driven configuration for media_postprocessor (Phase 1)."""

from dataclasses import dataclass
from typing import Mapping


@dataclass(frozen=True)
class Config:
    download_dir: str
    db_path: str
    port: int
    max_concurrency: int

    @classmethod
    def from_env(cls, env: Mapping[str, str]) -> "Config":
        download_dir = env.get("DOWNLOAD_DIR", "/downloads")
        db_path = env.get(
            "MP_DB_PATH", f"{download_dir}/.media_postprocessor/jobs.db"
        )
        try:
            port = int(env.get("MP_PORT", "8089"))
            max_concurrency = int(env.get("MP_MAX_CONCURRENCY", "1"))
        except ValueError as exc:
            raise ValueError(f"invalid integer config value: {exc}") from exc
        return cls(
            download_dir=download_dir,
            db_path=db_path,
            port=port,
            max_concurrency=max_concurrency,
        )
