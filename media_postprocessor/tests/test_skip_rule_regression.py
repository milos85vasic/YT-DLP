"""§11.4.135 regression guard for media_probe.classify_target skip-rule coverage.

Incident (2026-06-16): the live postprocess jobs.db showed 11 `failed` jobs whose
sources were yt-dlp intermediate per-format files (`.f399`/`.f398`/`.f251.webm`/
`.fdash-video-5240`/`.fhls-*`). Investigation (systematic-debugging §11.4.102)
established these were PRE-FIX stale entries — all created 2026-06-15T21:35..22:01Z,
BEFORE the skip-rule commit fd3e2c2 (2026-06-15T23:21Z) — and that the current
classify_target() correctly returns "skip" for every one of those patterns. This
guard locks that behaviour in: if a future change lets any of these intermediate /
already-produced patterns be enqueued for transcode again, it RED-fails here.

Imports the REAL module; the code's current behaviour is the oracle. Complements the
broader class coverage in test_media_probe.py with the exact incident literals.
"""

import pytest

from media_postprocessor.media_probe import classify_target


# --- yt-dlp intermediate per-format files MUST be skipped (the incident set) ---
@pytest.mark.parametrize(
    "name",
    [
        "X.f399.mp4",              # digit format id
        "X.f398.mp4",              # digit format id
        "X.f251.webm",             # digit format id, webm container
        "X.fdash-video-5240.mp4",  # protocol-prefixed dash
        "X.fhls-audio-3.mp4",      # protocol-prefixed hls
    ],
)
def test_ytdlp_intermediate_files_are_skipped(name):
    assert classify_target(name) == "skip", name


# --- already-produced derivative outputs MUST be skipped ---
def test_webready_prefix_is_skipped():
    assert classify_target("webready-X.mp4") == "skip"


def test_mp3_output_is_skipped():
    assert classify_target("X.mp3") == "skip"


# --- non-vacuous positive cases: normal media must classify, not skip ---
@pytest.mark.parametrize("name", ["X.mp4", "X.webm", "X.mkv"])
def test_normal_video_maps_to_webready_video(name):
    assert classify_target(name) == "webready_video", name


def test_audio_source_maps_to_mp3_audio():
    # .m4a is a yt-dlp audio source that will be transcoded to mp3.
    assert classify_target("X.m4a") == "mp3_audio"
