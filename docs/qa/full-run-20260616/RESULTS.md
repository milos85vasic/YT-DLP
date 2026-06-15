# Full run — rebuild + boot + tests + challenges (stack LEFT RUNNING)
_started: 2026-06-15T21:29:41Z_

## 1. Rebuild (--no-cache, avoids restart-illusion)

REBUILD dashboard + media_postprocessor: OK

## 2. Boot (no-vpn) + force-recreate our rebuilt services

Containers up: 15
postprocess /api/postprocess/status: {"healthy": true, "counts": {"queued": 0, "running": 0, "done": 1, "failed": 0, "canceled": 0}}

## 3. Tests

media_postprocessor pytest: 57 passed in 7.72s
run-tests.sh (tail):
```
[0;35m============================================[0m

Total:   196
Passed:  [0;32m186[0m
Failed:  [0;31m10[0m
Skipped: [1;33m0[0m

[0;34m[INFO][0m Cleaning up test environment...
```
smoke-test (tail): [0;34m============================================[0m Passed: [0;32m20[0m Failed: [0;31m2[0m [0;31mSMOKE TESTS FAILED — Do not deploy[0m 
validate-contract (tail): [0;34m============================================[0m Passed: [0;32m0[0m Failed: [0;31m11[0m [0;31mCONTRACT CHECKS FAILED — Update contracts/metube-api.openapi.yaml or fix API[0m 

## 4. Challenges (anti-bluff; some may SKIP/FAIL for cookies/geo — reported honestly)

download_completes_challenge.sh (rc=52, tail): download dir:   /run/media/milosvasic/DATA4TB/Projects/MeTube/downloads () timeout:        180s  [1/4] Submitting test URL… 
download_then_webready_challenge.sh (rc=52, tail): container runtime:podman timeout:          180s (download), 120s (webready)  [1/5] Submitting test URL (video)… 
run-metube-challenges (tail): [0;34mRunning MeTube Anti-Bluff Challenges...[0m  [0;36mBuilding Challenges runner...[0m [1;33mBuilding from source...[0m no Go files in /Volumes/T7/Projects/ytdlp/Challenges 

## 5. DONE — stack LEFT RUNNING for manual testing

Manual-test URLs (stack is UP — do NOT stop it):
- Dashboard:    http://localhost:9090
- Landing:      http://localhost:8086
- MeTube:       http://localhost:8088
- Postprocess:  http://localhost:9090/api/postprocess/status

Running containers:
helixcode-autoboot-postgres  Up 2 days (healthy)
helixcode-autoboot-redis  Up 2 days (healthy)
helixagent-postgres  Up 28 hours (healthy)
helixagent-redis  Up 28 hours (healthy)
helixagent-chromadb  Up 28 hours
helixagent-cognee  Up 26 seconds (starting)
helix_ollama_video  Up 11 hours
qbittorrent  Up 2 hours (healthy)
jackett  Up 2 hours (healthy)
boba-jackett  Up 2 hours (healthy)
qbittorrent-proxy  Up 2 hours (healthy)
metube-direct  Up 4 seconds
metube-landing  Up 5 minutes
media-postprocessor  Up 5 minutes
yt-dlp-dashboard  Up 4 minutes

_finished: 2026-06-15T21:37:14Z_
