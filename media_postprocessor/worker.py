"""Worker loop tying the jobs queue to the transcoder (Phase 4).

Implements the §3 worker-pool drain + the §5.3 / §11 resume contract:

  - process_one(conn, cfg) -> bool
        Claim the next queued job (→ running via jobs_db.claim_next_job),
        classify the source with media_probe.classify_target, derive the
        webready video or mp3, then mark the job done (with its output path)
        or failed (with the error string). Returns True if a job was
        processed, False if the queue was empty.

  - run_forever(conn, cfg, stop_event=None)
        Crash recovery first: jobs_db.requeue_running_on_startup re-queues any
        job left 'running' by a crashed worker (§5.3). Then drain the queue,
        sleeping briefly when it is empty, honoring a stop_event for clean
        shutdown. Single worker is fine for Phase 1 (§3); MP_MAX_CONCURRENCY is
        honored in a later phase.

The committed jobs_db API is keyed by the db_path string, so the worker's
`conn` argument carries that db_path (what jobs_db actually consumes) — the
committed modules are imported, never modified.
"""

import time

from media_postprocessor import jobs_db, media_probe, transcoder


_EMPTY_QUEUE_SLEEP_SECONDS = 0.2


def process_one(conn, cfg) -> bool:
    """Claim + derive + finalize one job. Returns True if one ran, else False.

    On any exception during classification/transcode the job is marked failed
    with the error string (never left 'running'); on success it is marked done
    with the produced output path. The atomic `.partial` -> os.replace +
    ffprobe-validate discipline lives in transcoder; here we only orchestrate
    the state machine queued -> running -> done|failed (§5.3).
    """
    job = jobs_db.claim_next_job(conn)
    if job is None:
        return False

    job_id = job["id"]
    src = job["source_path"]
    try:
        kind = media_probe.classify_target(src)
        if kind == "webready_video":
            output_path = transcoder.transcode_video(src)
        elif kind == "mp3_audio":
            output_path = transcoder.derive_mp3(src)
        else:
            raise ValueError(f"job {job_id}: source {src!r} classifies as {kind!r}")
        jobs_db.mark_done(conn, job_id, output_path)
    except Exception as err:  # noqa: BLE001 - any failure must mark the job failed
        jobs_db.mark_failed(conn, job_id, str(err))
    return True


def run_forever(conn, cfg, stop_event=None) -> None:
    """Resume on startup, then drain the queue until stop_event is set (§3, §5.3).

    Startup re-queues any job a crashed worker left 'running'
    (jobs_db.requeue_running_on_startup) so interrupted work resumes to a valid,
    complete output. The loop processes jobs back-to-back and sleeps briefly
    whenever the queue is empty so it does not busy-spin.
    """
    jobs_db.requeue_running_on_startup(conn)
    while stop_event is None or not stop_event.is_set():
        did_work = process_one(conn, cfg)
        if not did_work:
            if stop_event is not None and stop_event.wait(_EMPTY_QUEUE_SLEEP_SECONDS):
                break
            if stop_event is None:
                time.sleep(_EMPTY_QUEUE_SLEEP_SECONDS)
