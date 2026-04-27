#!/bin/bash
#
# capture-freeze-diagnostics.sh
#
# One-shot snapshot of host + container state for triaging an
# unresponsive-host episode (the kind that prompts a hard reset).
#
# Captures into a timestamped directory under logs/freeze-<ts>/:
#   - podman-stats.txt        — current per-container CPU / mem / net / pids
#   - podman-ps.txt           — running + stopped containers, exit codes
#   - podman-images.txt       — image inventory + sizes (storage pressure)
#   - podman-system-df.txt    — reclaimable storage breakdown
#   - journal-kernel.txt      — kernel log since 30 min ago (OOM, hangs, taints)
#   - journal-system.txt      — full system journal since 30 min ago
#   - journal-suspend.txt     — any "will suspend" / "freezing user space"
#                               broadcasts (proves CONST-033 wasn't bypassed)
#   - dmesg.txt               — ring buffer (last 500 lines)
#   - meminfo.txt             — /proc/meminfo
#   - free.txt                — free -h
#   - pressure-cpu.txt        — /proc/pressure/cpu
#   - pressure-memory.txt     — /proc/pressure/memory
#   - pressure-io.txt         — /proc/pressure/io
#   - loadavg.txt             — uptime + /proc/loadavg
#   - top-cpu.txt             — top 25 processes by CPU
#   - top-mem.txt             — top 25 processes by RSS
#   - mounts.txt              — /proc/mounts (storage pressure clues)
#   - oom-score.txt           — oom_score for top-50 RSS processes
#   - host-power-state.txt    — current sleep target masks + logind config
#
# Usage:
#   bash scripts/capture-freeze-diagnostics.sh
#
# Run AS SOON AS the host becomes responsive again after a freeze.
# Diagnostics from an hour later are much less useful — kernel ring
# buffer rotates, journal cursor advances past the OOM event, etc.
#
# Safe to run repeatedly. Each run writes a new timestamped directory.
# No data is removed, no services touched, no host-power-state changes.
#
# CONST-033: NEVER call suspend/hibernate/poweroff/halt/reboot/kexec.
# This script is read-only against host state.

set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TS=$(date +%Y%m%d-%H%M%S)
OUT_DIR="$PROJECT_DIR/logs/freeze-$TS"
mkdir -p "$OUT_DIR"

# Container runtime (read-only detection — no fallthrough to docker
# without checking, podman is preferred per project policy).
if command -v podman >/dev/null 2>&1; then
    RT=podman
elif command -v docker >/dev/null 2>&1; then
    RT=docker
else
    RT=""
fi

_capture() {
    local name="$1"
    shift
    local out="$OUT_DIR/$name"
    echo "[capture] $name" >&2
    {
        echo "# $(date -Is)"
        echo "# command: $*"
        echo "----"
        "$@" 2>&1
    } > "$out" || echo "(command exited non-zero — output above is partial)" >> "$out"
}

# --- Container state ---
if [ -n "$RT" ]; then
    _capture "podman-stats.txt" "$RT" stats --no-stream --all
    _capture "podman-ps.txt"    "$RT" ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
    _capture "podman-images.txt" "$RT" images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.Created}}"
    _capture "podman-system-df.txt" "$RT" system df -v
fi

# --- Kernel + system journal ---
# `--since "30 min ago"` is enough to cover most freeze events without
# producing a 50 MB blob. Fall back to last 1000 lines if no since-window.
if command -v journalctl >/dev/null 2>&1; then
    _capture "journal-kernel.txt"  journalctl -k --since "30 min ago"
    _capture "journal-system.txt"  journalctl --since "30 min ago" -p warning
    _capture "journal-suspend.txt" journalctl --since "30 min ago" --grep "(will suspend|freezing user space|Freezing user|resume from|wakeup from)"
fi

# --- dmesg ring buffer (kernel taints, OOM, hangs) ---
if command -v dmesg >/dev/null 2>&1; then
    # `dmesg -T` may need CAP_SYSLOG. Fall back to plain dmesg.
    if dmesg -T 2>/dev/null >"$OUT_DIR/dmesg.txt.tmp"; then
        tail -n 500 "$OUT_DIR/dmesg.txt.tmp" > "$OUT_DIR/dmesg.txt"
    else
        dmesg 2>&1 | tail -n 500 > "$OUT_DIR/dmesg.txt" || true
    fi
    rm -f "$OUT_DIR/dmesg.txt.tmp"
fi

# --- Memory + pressure ---
_capture "meminfo.txt" cat /proc/meminfo
_capture "free.txt"    free -h
_capture "loadavg.txt" sh -c 'uptime; echo; cat /proc/loadavg'
[ -r /proc/pressure/cpu ]    && _capture "pressure-cpu.txt"    cat /proc/pressure/cpu
[ -r /proc/pressure/memory ] && _capture "pressure-memory.txt" cat /proc/pressure/memory
[ -r /proc/pressure/io ]     && _capture "pressure-io.txt"     cat /proc/pressure/io

# --- Top processes by CPU + RSS ---
_capture "top-cpu.txt" sh -c "ps -eo pid,user,pcpu,pmem,rss,comm --sort=-pcpu | head -n 26"
_capture "top-mem.txt" sh -c "ps -eo pid,user,pcpu,pmem,rss,comm --sort=-rss  | head -n 26"

# --- OOM scores for top RSS ---
_capture "oom-score.txt" sh -c '
  ps -eo pid,rss,comm --sort=-rss | head -n 51 | tail -n +2 |
  while read -r pid rss comm; do
    if [ -r "/proc/$pid/oom_score" ]; then
      score=$(cat "/proc/$pid/oom_score" 2>/dev/null || echo "?")
      printf "%6s  rss=%-10s  oom_score=%-5s  %s\n" "$pid" "$rss" "$score" "$comm"
    fi
  done
'

# --- Storage / mounts ---
_capture "mounts.txt" cat /proc/mounts

# --- CONST-033 host-power-state proof (defence-in-depth) ---
_capture "host-power-state.txt" sh -c '
  echo "## sleep target masks";  systemctl is-enabled sleep.target suspend.target hibernate.target hybrid-sleep.target 2>&1
  echo;  echo "## logind config";  ls -la /etc/systemd/logind.conf.d/ 2>&1
  echo;  cat /etc/systemd/logind.conf.d/*.conf 2>&1 || true
  echo;  echo "## sleep.conf drop-ins";  ls -la /etc/systemd/sleep.conf.d/ 2>&1
  cat /etc/systemd/sleep.conf.d/*.conf 2>&1 || true
'

# --- Index ---
{
    echo "# Freeze diagnostics — captured $(date -Is)"
    echo "# host: $(uname -a)"
    [ -n "$RT" ] && echo "# container runtime: $RT"
    echo
    echo "Files:"
    ls -la "$OUT_DIR"
} > "$OUT_DIR/INDEX.txt"

echo
echo "Captured to: $OUT_DIR"
echo "  $(ls "$OUT_DIR" | wc -l) files, $(du -sh "$OUT_DIR" | cut -f1) total"
