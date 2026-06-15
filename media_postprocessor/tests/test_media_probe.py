import unittest

from media_postprocessor import media_probe


class TestClassifyByExtension(unittest.TestCase):
    def test_video_extensions_map_to_webready_video(self):
        for name in ["clip.mp4", "movie.MKV", "vid.webm", "x.avi", "y.mov", "z.m4v"]:
            self.assertEqual(media_probe.classify_target(name), "webready_video", name)

    def test_audio_extensions_map_to_mp3_audio(self):
        for name in ["song.m4a", "track.opus", "x.flac", "y.wav", "z.aac", "w.ogg"]:
            self.assertEqual(media_probe.classify_target(name), "mp3_audio", name)

    def test_existing_mp3_is_skipped(self):
        self.assertEqual(media_probe.classify_target("track.mp3"), "skip")

    def test_webready_prefix_is_skipped(self):
        self.assertEqual(media_probe.classify_target("webready-clip.mp4"), "skip")
        self.assertEqual(
            media_probe.classify_target("/downloads/webready-clip.mp4"), "skip"
        )

    def test_unknown_extension_is_skipped(self):
        self.assertEqual(media_probe.classify_target("notes.txt"), "skip")
        self.assertEqual(media_probe.classify_target("archive.zip"), "skip")


import os
import shutil
import subprocess
import tempfile


def _have(tool):
    return shutil.which(tool) is not None


@unittest.skipUnless(_have("ffmpeg") and _have("ffprobe"), "ffmpeg/ffprobe required")
class TestProbeMediaKindReal(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.video = os.path.join(self.tmp.name, "sample.mp4")
        self.audio = os.path.join(self.tmp.name, "sample_audio.m4a")
        # Tiny AV sample: 1s testsrc video + 1s sine audio.
        subprocess.run(
            ["ffmpeg", "-y", "-f", "lavfi",
             "-i", "testsrc=duration=1:size=128x128:rate=10",
             "-f", "lavfi", "-i", "sine=frequency=1000:duration=1",
             "-shortest", "-pix_fmt", "yuv420p", self.video],
            check=True, capture_output=True,
        )
        # Audio-only sample.
        subprocess.run(
            ["ffmpeg", "-y", "-f", "lavfi",
             "-i", "sine=frequency=440:duration=1", "-vn", self.audio],
            check=True, capture_output=True,
        )

    def tearDown(self):
        self.tmp.cleanup()

    def test_fixtures_exist_and_nonempty(self):
        # ARTIFACT rule: stat the real generated files (§11.4 ARTIFACT).
        self.assertGreater(os.path.getsize(self.video), 0)
        self.assertGreater(os.path.getsize(self.audio), 0)

    def test_probe_detects_video(self):
        self.assertEqual(media_probe.probe_media_kind(self.video), "video")

    def test_probe_detects_audio(self):
        self.assertEqual(media_probe.probe_media_kind(self.audio), "audio")


_FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")


@unittest.skipUnless(_have("ffprobe"), "ffprobe required")
class TestProbeMediaKindCommittedFixtures(unittest.TestCase):
    """§11.4 ARTIFACT: run real ffprobe on the real, committed fixture files
    (generated with ffmpeg lavfi and stored under tests/fixtures/)."""

    def setUp(self):
        self.video = os.path.join(_FIXTURES_DIR, "sample_video.mp4")
        self.audio = os.path.join(_FIXTURES_DIR, "sample_audio.m4a")

    def test_committed_fixtures_exist_and_nonempty(self):
        self.assertTrue(os.path.isfile(self.video), self.video)
        self.assertTrue(os.path.isfile(self.audio), self.audio)
        self.assertGreater(os.path.getsize(self.video), 0)
        self.assertGreater(os.path.getsize(self.audio), 0)

    def test_committed_video_fixture_probes_as_video(self):
        self.assertEqual(media_probe.probe_media_kind(self.video), "video")

    def test_committed_audio_fixture_probes_as_audio(self):
        self.assertEqual(media_probe.probe_media_kind(self.audio), "audio")


if __name__ == "__main__":
    unittest.main()


def test_classify_skips_ytdlp_intermediate_files():
    """yt-dlp '<title>.f<id>.<ext>' / '.fdash-*' intermediates are merged+deleted
    upstream -> classify as skip so the worker never races a vanishing file
    (observed live: ffmpeg exit 254 on .f399.mp4 / .fdash-video-5240.mp4)."""
    from media_postprocessor import media_probe as mp
    assert mp.classify_target("Watchtower of Turkey.fdash-video-5240.mp4") == "skip"
    assert mp.classify_target("Spinoza's God.f399.mp4") == "skip"
    assert mp.classify_target("song.f140.m4a") == "skip"
    assert mp.classify_target("/downloads/x.fhls-1080.webm") == "skip"
    # final merged files + innocent names must NOT be skipped
    assert mp.classify_target("Watchtower of Turkey.mp4") == "webready_video"
    assert mp.classify_target("clip.final.mp4") == "webready_video"
    assert mp.classify_target("track.m4a") == "mp3_audio"
