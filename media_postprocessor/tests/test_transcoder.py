"""Phase 2 integration tests for the ffmpeg derivation module.

§11.4.27 / §11.4 ARTIFACT rule: NO mocks — these run REAL ffmpeg 8.1.x against
the committed fixtures and ffprobe the REAL produced artifacts to prove
h264 + aac + faststart (video) and mp3 (audio). All outputs are written to
tmp dirs so nothing lands beside the committed fixtures.
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest

from media_postprocessor import transcoder


_FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")
_SAMPLE_VIDEO = os.path.join(_FIXTURES_DIR, "sample_video.mp4")
_SAMPLE_AUDIO = os.path.join(_FIXTURES_DIR, "sample_audio.m4a")


def _have(tool):
    return shutil.which(tool) is not None


def _ffprobe_streams(path):
    proc = subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-show_format",
         "-of", "json", path],
        capture_output=True, text=True, check=True,
    )
    return json.loads(proc.stdout)


_REQ = _have("ffmpeg") and _have("ffprobe")


@unittest.skipUnless(_REQ, "ffmpeg/ffprobe required")
class TestTranscodeVideo(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()

    def test_produces_webready_h264_aac_faststart(self):
        out = transcoder.transcode_video(_SAMPLE_VIDEO, dest_dir=self.tmp.name)

        # Naming + artifact existence (§4.1 / ARTIFACT rule).
        self.assertEqual(os.path.basename(out), "webready-sample_video.mp4")
        self.assertTrue(os.path.isfile(out))
        self.assertGreater(os.path.getsize(out), 1024)  # >1KB

        # ffprobe the REAL output: h264 video + aac audio.
        info = _ffprobe_streams(out)
        streams = info["streams"]
        video = [s for s in streams if s["codec_type"] == "video"]
        audio = [s for s in streams if s["codec_type"] == "audio"]
        self.assertTrue(video, "no video stream")
        self.assertTrue(audio, "no audio stream")
        self.assertEqual(video[0]["codec_name"], "h264")
        self.assertEqual(audio[0]["codec_name"], "aac")
        self.assertGreater(float(info["format"]["duration"]), 0)

        # faststart property proven by reading mp4 atom order.
        self.assertTrue(transcoder.has_faststart(out),
                        "moov must precede mdat (+faststart)")

    def test_video_only_source_produces_valid_webready_no_audio(self):
        # Regression (real-stack 2026-06-15): a video-only download (no audio
        # stream — common for silent clips / screen recordings) was wrongly
        # marked failed because _validate_webready unconditionally required an
        # aac stream. ffmpeg's `-map 0:a:0?` correctly produces a video-only
        # mp4; validation must NOT require audio when the source had none.
        src = os.path.join(self.tmp.name, "video_only.mp4")
        subprocess.run(
            ["ffmpeg", "-y", "-f", "lavfi", "-i", "testsrc=duration=1:size=320x240:rate=15",
             "-c:v", "libx264", "-pix_fmt", "yuv420p", src],
            capture_output=True, text=True, check=True,
        )
        # Sanity: the source genuinely has no audio stream.
        sinfo = _ffprobe_streams(src)
        self.assertFalse(
            [s for s in sinfo["streams"] if s["codec_type"] == "audio"],
            "test setup error: source should have no audio",
        )

        out = transcoder.transcode_video(src, dest_dir=self.tmp.name)

        info = _ffprobe_streams(out)
        streams = info["streams"]
        video = [s for s in streams if s["codec_type"] == "video"]
        self.assertTrue(video, "no video stream")
        self.assertEqual(video[0]["codec_name"], "h264")
        self.assertGreater(float(info["format"]["duration"]), 0)
        self.assertTrue(transcoder.has_faststart(out),
                        "moov must precede mdat (+faststart)")

    def test_no_partial_left_after_success(self):
        out = transcoder.transcode_video(_SAMPLE_VIDEO, dest_dir=self.tmp.name)
        self.assertFalse(os.path.exists(out + ".partial"))

    def test_bogus_input_fails_clean_no_partial_no_final(self):
        bogus = os.path.join(self.tmp.name, "not_media.mp4")
        with open(bogus, "wb") as fh:
            fh.write(b"this is not a media file at all")
        with self.assertRaises(transcoder.TranscodeError):
            transcoder.transcode_video(bogus, dest_dir=self.tmp.name)
        final_path = os.path.join(self.tmp.name, "webready-not_media.mp4")
        self.assertFalse(os.path.exists(final_path), "no final file on failure")
        self.assertFalse(os.path.exists(final_path + ".partial"),
                         "no .partial left behind on failure")


@unittest.skipUnless(_REQ, "ffmpeg/ffprobe required")
class TestDeriveMp3(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()

    def test_produces_valid_mp3(self):
        out = transcoder.derive_mp3(_SAMPLE_AUDIO, dest_dir=self.tmp.name)

        self.assertEqual(os.path.basename(out), "sample_audio.mp3")
        self.assertTrue(os.path.isfile(out))
        self.assertGreater(os.path.getsize(out), 1024)

        info = _ffprobe_streams(out)
        audio = [s for s in info["streams"] if s["codec_type"] == "audio"]
        self.assertTrue(audio, "no audio stream")
        self.assertEqual(audio[0]["codec_name"], "mp3")
        self.assertGreater(float(info["format"]["duration"]), 0)

    def test_no_partial_left_after_success(self):
        out = transcoder.derive_mp3(_SAMPLE_AUDIO, dest_dir=self.tmp.name)
        self.assertFalse(os.path.exists(out + ".partial"))

    def test_bogus_input_fails_clean_no_partial_no_final(self):
        bogus = os.path.join(self.tmp.name, "not_audio.m4a")
        with open(bogus, "wb") as fh:
            fh.write(b"definitely not audio bytes")
        with self.assertRaises(transcoder.TranscodeError):
            transcoder.derive_mp3(bogus, dest_dir=self.tmp.name)
        final_path = os.path.join(self.tmp.name, "not_audio.mp3")
        self.assertFalse(os.path.exists(final_path))
        self.assertFalse(os.path.exists(final_path + ".partial"))


@unittest.skipUnless(_REQ, "ffmpeg/ffprobe required")
class TestFaststartHelper(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()

    def test_faststart_true_for_faststart_mux_false_otherwise(self):
        fast = os.path.join(self.tmp.name, "fast.mp4")
        slow = os.path.join(self.tmp.name, "slow.mp4")
        subprocess.run(
            ["ffmpeg", "-y", "-f", "lavfi",
             "-i", "testsrc=duration=1:size=64x64:rate=10",
             "-pix_fmt", "yuv420p", "-movflags", "+faststart", fast],
            check=True, capture_output=True,
        )
        subprocess.run(
            ["ffmpeg", "-y", "-f", "lavfi",
             "-i", "testsrc=duration=1:size=64x64:rate=10",
             "-pix_fmt", "yuv420p", slow],
            check=True, capture_output=True,
        )
        self.assertTrue(transcoder.has_faststart(fast))
        self.assertFalse(transcoder.has_faststart(slow))


if __name__ == "__main__":
    unittest.main()
