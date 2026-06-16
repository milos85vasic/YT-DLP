# Nezha heavy-test campaign — captured evidence (2026-06-16)

Full no-vpn ytdlp System distributed to nezha.local (amd64, Podman 5.7.1) and heavy-tested
against REAL running production services. Raw logs in this directory. Zero product bugs;
all non-passes environmental + classified. 6 issues root-caused + fixed (commits 5d15a64,
f10c727, acbed76, b96dc8f).

| Suite (log) | Result |
|---|---|
| run-tests scenario (1-scenario.log) | 17 pass / 0 fail |
| run-tests integration (2-integration.log) | 123 pass / 1 fail → 0 after VK-allowlist fix (env) |
| run-tests error (3-error.log) | 24 pass / 0 fail |
| container-restart-resilience (4-restart-resilience.log) | PASS |
| chaos (5-chaos.log) | 27 pass / 0 fail / 1 skip (host DNS) |
| memory-limits (6-memory-limits.log) | PASS (mem_limit + oom_score_adj on all) |
| restore + final status (7,8) | stack restored, all 5 HTTP health checks green |
| api_contract / form_reenables / landing_cookie_upload | PASS |
| no_vpn_direct_access / queue_lifecycle / queue_polling / retry_visible | PASS |
| test-dashboard (test-dashboard.log) | 34 pass / 1 fail (env: stale-cookie-size; re-seeded) |
| test-dashboard-operations | 5 pass / 0 fail |
| test-media-services | 16 pass / 1 fail → 0 after VK-allowlist fix |
| test-aborted-history | 9 pass / 0 fail |
| test-bulk-operations | 9 pass / 0 fail |

Also captured this session (not in this dir): smoke 22/0, contract 18/0,
integration-realhttp 22/0, postprocessor pytest 46pass/23skip(ffmpeg-less host)/0fail,
download_completes → real 111MB webready file on disk.
