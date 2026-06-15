# Built for Podman (host has podman 5.x + ffmpeg 8.1.1; docker is absent).
FROM python:3.11-slim

# System ffmpeg + ffprobe (the transcode/probe engine — §6 native CLI).
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt /app/media_postprocessor/requirements.txt
RUN pip install --no-cache-dir -r /app/media_postprocessor/requirements.txt

# Copy the whole package dir into /app/media_postprocessor so that
# `python -m media_postprocessor.service` resolves `from media_postprocessor import ...`.
# Build context is ./media_postprocessor, so "." is the package contents.
COPY . /app/media_postprocessor

ENV PYTHONPATH=/app
ENV DOWNLOAD_DIR=/downloads
ENV MP_DB_PATH=/downloads/.media_postprocessor/jobs.db
ENV MP_PORT=8089
ENV MP_MAX_CONCURRENCY=1
EXPOSE 8089

CMD ["python", "-m", "media_postprocessor.service"]
