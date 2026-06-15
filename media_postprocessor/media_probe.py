"""ffprobe-based media classification for media_postprocessor (Phase 1).

classify_target() is the pure extension+skip-rule classifier (§4, §10);
probe_media_kind() runs real ffprobe and is used by integration tests and
later phases to refine the decision.
"""

import json
import os
import re
import subprocess

VIDEO_EXTS = {".mp4", ".mkv", ".webm", ".avi", ".mov", ".m4v", ".flv", ".wmv", ".ts"}
AUDIO_EXTS = {".m4a", ".opus", ".flac", ".wav", ".aac", ".ogg", ".oga", ".wma"}

# yt-dlp intermediate per-format files: "<title>.f<format_id>.<ext>" where the
# format_id is digits (.f399) or protocol-prefixed (.fdash-video-5240, .fhls-…).
# yt-dlp MERGES these per-stream files then DELETES them before the final
# "<title>.<ext>" appears, so transcoding one races a vanishing/partial file
# (ffmpeg exit 254). Matches the trailing ".f<id>" of the name stem only — it
# does NOT match innocent names like "clip.final.mp4".
_YTDLP_INTERMEDIATE = re.compile(r"\.f(\d+|dash|hls|http|mhtml)[-_a-z0-9]*$")


def classify_target(path: str) -> str:
    """Return 'webready_video' | 'mp3_audio' | 'skip' from name rules (§4, §10).

    Skips derivative outputs: a 'webready-' basename prefix and any '.mp3'
    so we never derive from a derivative.
    """
    base = os.path.basename(path)
    lower = base.lower()
    if lower.startswith("webready-"):
        return "skip"
    ext = os.path.splitext(lower)[1]
    if ext == ".mp3":
        return "skip"
    # Skip yt-dlp intermediate per-format files (merged then deleted upstream).
    if _YTDLP_INTERMEDIATE.search(os.path.splitext(lower)[0]):
        return "skip"
    if ext in VIDEO_EXTS:
        return "webready_video"
    if ext in AUDIO_EXTS:
        return "mp3_audio"
    return "skip"


def probe_media_kind(path: str) -> str:
    """Run real ffprobe → 'video' | 'audio' | 'skip'.

    'video' if any video stream is present (excluding attached-pic cover art),
    'audio' if no video but an audio stream is present, else 'skip'.
    """
    proc = subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-of", "json", path],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        return "skip"
    try:
        streams = json.loads(proc.stdout).get("streams", [])
    except json.JSONDecodeError:
        return "skip"
    has_audio = False
    for s in streams:
        if s.get("codec_type") == "video" and s.get("disposition", {}).get(
            "attached_pic", 0
        ) != 1:
            return "video"
        if s.get("codec_type") == "audio":
            has_audio = True
    return "audio" if has_audio else "skip"
