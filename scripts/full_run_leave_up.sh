#!/usr/bin/env bash
# One-shot: rebuild our images, boot the no-vpn stack, run all tests + challenges,
# write a results summary, and LEAVE THE STACK RUNNING for manual testing.
# Purpose: operator-requested full rebuild/boot/test/leave-up.
# Usage: nohup scripts/full_run_leave_up.sh & disown   (or run in background)
# Outputs: docs/qa/full-run-20260616/{RESULTS.md,run.log}
# Side-effects: rebuilds dashboard+media_postprocessor images, boots no-vpn stack
#   (media_postprocessor will backfill/transcode the existing library), LEAVES IT UP.
# Dependencies: podman, podman-compose, ffmpeg, python3, the project scripts.
set -uo pipefail
cd /Volumes/T7/Projects/ytdlp || exit 1
RUN="docs/qa/full-run-20260616"
mkdir -p "$RUN"
LOG="$RUN/run.log"; RES="$RUN/RESULTS.md"
: > "$LOG"
exec >>"$LOG" 2>&1

PC="podman-compose"
command -v podman-compose >/dev/null || PC="podman compose"

rec(){ echo "$1" >> "$RES"; echo ">>> $1"; }
sect(){ echo -e "\n## $1\n" >> "$RES"; echo "=== $1 ==="; }

echo "# Full run — rebuild + boot + tests + challenges (stack LEFT RUNNING)" > "$RES"
echo "_started: $(date -u +%Y-%m-%dT%H:%M:%SZ)_" >> "$RES"

sect "1. Rebuild (--no-cache, avoids restart-illusion)"
if $PC --profile no-vpn build --no-cache dashboard media_postprocessor; then
  rec "REBUILD dashboard + media_postprocessor: OK"
else
  rec "REBUILD: FAILED — see run.log"
fi

sect "2. Boot (no-vpn) + force-recreate our rebuilt services"
./start_no_vpn || rec "start_no_vpn returned non-zero (see log)"
$PC --profile no-vpn up -d --force-recreate dashboard media_postprocessor || true
sleep 6
podman ps --format '{{.Names}}\t{{.Status}}' > "$RUN/podman_ps.txt"
rec "Containers up: $(podman ps -q | wc -l | tr -d ' ')"
ok=0
for i in $(seq 1 48); do
  j=$(curl -s --max-time 5 http://localhost:9090/api/postprocess/status || true)
  if echo "$j" | grep -q '"healthy"'; then ok=1; echo "postprocess status: $j"; rec "postprocess /api/postprocess/status: $j"; break; fi
  sleep 5
done
[ $ok -eq 1 ] || rec "postprocess /api: NOT reachable after boot (see log + podman logs media-postprocessor)"

# MeTube-readiness wait BEFORE any test/challenge: the suite MUST NOT run until metube
# re-stabilizes after the --no-cache rebuild + force-recreate, or it produces false
# contract/smoke/challenge failures (run #1 showed contract 0/11 that was actually 18/0 once ready).
mt=0
for i in $(seq 1 36); do
  if curl -s --max-time 5 http://localhost:8088/history | grep -q '"done"' && \
     curl -s --max-time 5 http://localhost:9090/api/history | grep -q '"done"'; then
    mt=1; rec "MeTube ready (direct :8088 + dashboard proxy :9090 both serving /history)"; break
  fi
  sleep 5
done
[ $mt -eq 1 ] || rec "WARNING: MeTube NOT ready after 180s — test results below may be unreliable"

sect "3. Tests"
if [ ! -x /tmp/mpp_venv/bin/python ]; then python3 -m venv /tmp/mpp_venv && /tmp/mpp_venv/bin/pip install -q pytest watchdog; fi
rec "media_postprocessor pytest: $(/tmp/mpp_venv/bin/python -m pytest media_postprocessor/tests/ -q 2>&1 | tail -1)"
echo "--- run-tests.sh ---"
# tee the FULL output so failure NAMES are preserved (run #1 only kept the tail via $() — lost them)
timeout 1500 ./tests/run-tests.sh 2>&1 | tee "$RUN/runtests.log" | tail -8
RT_SUM=$(sed 's/\x1b\[[0-9;]*m//g' "$RUN/runtests.log" | grep -iE 'Total:|Passed:|Failed:|Skipped:' | tail -4)
RT_FAILS=$(sed 's/\x1b\[[0-9;]*m//g' "$RUN/runtests.log" | grep -E 'Running:.*\.\.\. *FAIL' | sed 's/\.\.\..*//;s/Running: *//' | head -25)
rec "run-tests.sh summary:"; echo '```' >> "$RES"; echo "$RT_SUM" >> "$RES"; echo "FAILED tests:" >> "$RES"; echo "$RT_FAILS" >> "$RES"; echo '```' >> "$RES"
if [ -f ./scripts/smoke-test.sh ]; then
  SM=$(timeout 400 ./scripts/smoke-test.sh 2>&1 | tail -4); rec "smoke-test (tail): $(echo "$SM" | tr '\n' ' / ')"
fi
if [ -f ./scripts/validate-contract.sh ]; then
  CO=$(timeout 180 ./scripts/validate-contract.sh 2>&1 | tail -4); rec "validate-contract (tail): $(echo "$CO" | tr '\n' ' / ')"
fi

sect "4. Challenges (anti-bluff; some may SKIP/FAIL for cookies/geo — reported honestly)"
for ch in challenges/scripts/download_completes_challenge.sh challenges/scripts/download_then_webready_challenge.sh; do
  if [ -f "$ch" ]; then
    O=$(timeout 700 bash "$ch" 2>&1 | tail -4); RC=$?
    rec "$(basename "$ch") (rc=$RC, tail): $(echo "$O" | tr '\n' ' / ')"
  fi
done
if [ -f tests/challenges/run-metube-challenges.sh ]; then
  O=$(timeout 700 bash tests/challenges/run-metube-challenges.sh 2>&1 | tail -5); rec "run-metube-challenges (tail): $(echo "$O" | tr '\n' ' / ')"
fi

sect "5. DONE — stack LEFT RUNNING for manual testing"
{
  echo "Manual-test URLs (stack is UP — do NOT stop it):"
  echo "- Dashboard:    http://localhost:9090"
  echo "- Landing:      http://localhost:8086"
  echo "- MeTube:       http://localhost:8088"
  echo "- Postprocess:  http://localhost:9090/api/postprocess/status"
  echo ""
  echo "Running containers:"
  podman ps --format '{{.Names}}  {{.Status}}'
  echo ""
  echo "_finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
} >> "$RES"
echo "DONE. Results: $RES (stack left running)."
