"""ffmpeg derivation engine for media_postprocessor (Phase 2).

Implements the evidence-locked derivation recipes from the design spec:

  - transcode_video()  -> webready-<base>.mp4   (§4.1 H.264 + AAC, faststart)
  - derive_mp3()       -> <base>.mp3            (§4.2 320 kbps CBR)

Both write to a `<final>.partial` temp file in the destination directory and
`os.replace()` it onto the final path ONLY on ffmpeg exit 0 (§5.4 atomic,
cross-FS-safe), then ffprobe-validate the output before returning (§5.5
anti-bluff). A failed/interrupted run never leaves a `.partial` and never
leaves a final file: any partial is removed on every failure path.
"""

import json
import os
import subprocess


class TranscodeError(RuntimeError):
    """Raised when ffmpeg fails or the produced output fails ffprobe validation."""


# --- ffprobe helpers -------------------------------------------------------

def _ffprobe_json(path: str) -> dict:
    """Run ffprobe and return parsed streams+format JSON (raises on failure)."""
    proc = subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-show_format",
         "-of", "json", path],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise TranscodeError(f"ffprobe failed on {path}: {proc.stderr.strip()}")
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise TranscodeError(f"ffprobe emitted invalid JSON for {path}: {exc}") from exc


def _source_audio_is_aac_le2ch(src_path: str) -> bool:
    """True if the source's first audio stream is AAC with <=2 channels (§4.1).

    Such a track is copied losslessly (`-c:a copy`) instead of re-encoded.
    """
    try:
        info = _ffprobe_json(src_path)
    except TranscodeError:
        return False
    for s in info.get("streams", []):
        if s.get("codec_type") == "audio":
            codec = s.get("codec_name", "")
            channels = s.get("channels", 0) or 0
            return codec == "aac" and 0 < channels <= 2
    return False


def has_faststart(path: str) -> bool:
    """Return True if the mp4's moov atom appears before its mdat atom (§5.5).

    A `+faststart` mux relocates the moov (index) ahead of the mdat (media
    payload) so playback can begin before the whole file is downloaded. We
    read the top-level atom order directly from the file header rather than
    trusting any status string.
    """
    moov_off = -1
    mdat_off = -1
    with open(path, "rb") as fh:
        offset = 0
        while True:
            header = fh.read(8)
            if len(header) < 8:
                break
            size = int.from_bytes(header[:4], "big")
            atom = header[4:8]
            if atom == b"moov" and moov_off < 0:
                moov_off = offset
            elif atom == b"mdat" and mdat_off < 0:
                mdat_off = offset
            if size == 0:
                # Atom extends to EOF.
                break
            if size == 1:
                # 64-bit extended size follows the 8-byte header.
                ext = fh.read(8)
                if len(ext) < 8:
                    break
                size = int.from_bytes(ext, "big")
                if size < 16:
                    break
            elif size < 8:
                break
            offset += size
            fh.seek(offset)
            if moov_off >= 0 and mdat_off >= 0:
                break
    return moov_off >= 0 and mdat_off >= 0 and moov_off < mdat_off


def _validate_webready(path: str) -> None:
    """Assert the webready output is H.264 video + AAC audio + non-zero
    duration + faststart, or raise TranscodeError (§5.5)."""
    info = _ffprobe_json(path)
    streams = info.get("streams", [])
    has_h264 = any(
        s.get("codec_type") == "video" and s.get("codec_name") == "h264"
        for s in streams
    )
    has_aac = any(
        s.get("codec_type") == "audio" and s.get("codec_name") == "aac"
        for s in streams
    )
    if not has_h264:
        raise TranscodeError(f"webready output {path} has no h264 video stream")
    if not has_aac:
        raise TranscodeError(f"webready output {path} has no aac audio stream")
    duration = float(info.get("format", {}).get("duration", 0) or 0)
    if duration <= 0:
        raise TranscodeError(f"webready output {path} has non-positive duration")
    if not has_faststart(path):
        raise TranscodeError(f"webready output {path} is not faststart (moov after mdat)")


def _validate_mp3(path: str) -> None:
    """Assert the output is a valid mp3 with non-zero duration, or raise (§5.5)."""
    info = _ffprobe_json(path)
    streams = info.get("streams", [])
    has_mp3 = any(
        s.get("codec_type") == "audio" and s.get("codec_name") == "mp3"
        for s in streams
    )
    if not has_mp3:
        raise TranscodeError(f"mp3 output {path} has no mp3 audio stream")
    duration = float(info.get("format", {}).get("duration", 0) or 0)
    if duration <= 0:
        raise TranscodeError(f"mp3 output {path} has non-positive duration")


# --- internal runner -------------------------------------------------------

def _run_atomic(cmd_for_partial, final_path: str, validate) -> str:
    """Run ffmpeg writing to `<final>.partial`, os.replace on exit 0, validate.

    `cmd_for_partial` is a callable taking the partial path and returning the
    full ffmpeg argv. On any failure (ffmpeg non-zero OR validation raise) the
    partial is removed and no final file is left behind (§5.4 + §5.5).
    """
    partial_path = final_path + ".partial"
    # Never inherit a stale partial from an earlier interrupted run.
    if os.path.exists(partial_path):
        os.remove(partial_path)

    proc = subprocess.run(cmd_for_partial(partial_path), capture_output=True, text=True)
    if proc.returncode != 0:
        if os.path.exists(partial_path):
            os.remove(partial_path)
        raise TranscodeError(
            f"ffmpeg failed (exit {proc.returncode}) for {final_path}: "
            f"{proc.stderr.strip()[-500:]}"
        )

    # ffmpeg exit 0 -> atomic rename in the same directory (§5.4).
    os.replace(partial_path, final_path)

    try:
        validate(final_path)
    except Exception:
        # A produced-but-invalid output is a failure: leave nothing behind.
        if os.path.exists(final_path):
            os.remove(final_path)
        raise
    return final_path


def _dest_path(src_path: str, dest_dir, name: str) -> str:
    out_dir = dest_dir if dest_dir is not None else os.path.dirname(os.path.abspath(src_path))
    os.makedirs(out_dir, exist_ok=True)
    return os.path.join(out_dir, name)


# --- public API ------------------------------------------------------------

def transcode_video(src_path: str, dest_dir=None) -> str:
    """Build the spec §4.1 webready derivative `webready-<base>.mp4`.

    H.264 (libx264 -preset slow -crf 18 -profile:v high -level:v 4.1
    -pix_fmt yuv420p), scale-capped to 1080p with even dims, CFR, faststart.
    Audio is `-c:a copy` when the source audio is already AAC <=2ch, else
    re-encoded to `aac -b:a 192k -ac 2`.

    Writes atomically (`.partial` -> os.replace on exit 0) and ffprobe-
    validates h264 + aac + non-zero duration + faststart before returning.
    Returns the path to the produced webready file.
    """
    base = os.path.splitext(os.path.basename(src_path))[0]
    final_path = _dest_path(src_path, dest_dir, f"webready-{base}.mp4")

    if _source_audio_is_aac_le2ch(src_path):
        audio_args = ["-c:a", "copy"]
    else:
        audio_args = ["-c:a", "aac", "-b:a", "192k", "-ac", "2"]

    def build(partial_path):
        return [
            "ffmpeg", "-y", "-i", src_path,
            "-map", "0:v:0", "-map", "0:a:0?",
            "-c:v", "libx264", "-preset", "slow", "-crf", "18",
            "-profile:v", "high", "-level:v", "4.1", "-pix_fmt", "yuv420p",
            "-vf",
            "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease,"
            "scale=trunc(iw/2)*2:trunc(ih/2)*2",
            "-fps_mode", "cfr",
            *audio_args,
            "-movflags", "+faststart",
            "-f", "mp4",
            partial_path,
        ]

    return _run_atomic(build, final_path, _validate_webready)


def derive_mp3(src_path: str, dest_dir=None) -> str:
    """Build the spec §4.2 audio derivative `<base>.mp3` at 320 kbps CBR.

    `ffmpeg -i src -vn -map 0:a:0 -map_metadata 0 -c:a libmp3lame -b:a 320k
    -id3v2_version 3 <base>.mp3`, written atomically and ffprobe-validated
    (mp3 + non-zero duration). Returns the path to the produced mp3.
    """
    base = os.path.splitext(os.path.basename(src_path))[0]
    final_path = _dest_path(src_path, dest_dir, f"{base}.mp3")

    def build(partial_path):
        return [
            "ffmpeg", "-y", "-i", src_path,
            "-vn", "-map", "0:a:0", "-map_metadata", "0",
            "-c:a", "libmp3lame", "-b:a", "320k", "-id3v2_version", "3",
            "-f", "mp3",
            partial_path,
        ]

    return _run_atomic(build, final_path, _validate_mp3)
