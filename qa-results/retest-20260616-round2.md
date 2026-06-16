# ytdlp retest — Round 2 (2026-06-16, parallel subagents §11.4.103)

Captured results from the Round-2 parallel subagent sweep. SAFE tests only — no
container-lifecycle suites (would destabilize the live `ytdlp-1.4.0` stack). Live stack
verified identical before/after.

## Angular dashboard unit tests — 63/63 SUCCESS, 0 FAILED
- Command: `cd dashboard && CHROME_BIN=<Google Chrome 149> npx ng test --watch=false`
  (project karma launcher `ChromeHeadlessCI`, `singleRun: true`).
- Final: `Chrome Headless 149.0.0.0 (Mac OS): Executed 63 of 63 SUCCESS` → `TOTAL: 63 SUCCESS`.
- Spec files: `cookies.component.spec.ts`, `download-form.component.spec.ts`,
  `history.component.spec.ts`, `queue.component.spec.ts`, `metube.service.spec.ts`,
  `metube.service.bulk.spec.ts`.
- Noise (still PASS): 3 Jasmine "no expectations" WARNs on QueueComponent; deliberate
  simulated 500/502 console errors asserted by error-path specs.

## Pure-shell unit tests — 17/17 PASS, 0 FAIL
- Suite: `tests/test-unit.sh` via a read-only `/tmp` harness calling `run_unit_tests`
  directly (the orchestrator `run-tests.sh main()` was AVOIDED because it calls
  `pre_suite_drain` which POSTs to live MeTube = mutates operator state).
- Passed: container_runtime_detection, compose_command_detection, color_output,
  env_loading, env_variable_validation, path_validation, directory_creation,
  file_permissions, string_functions, vpn_config_parsing, vpn_auth_file_creation,
  docker_compose_syntax, service_definitions, profile_definitions, script_syntax,
  port_configuration, port_availability.
- `tests/test-cookie-validator.sh`: ENVIRONMENTAL self-SKIP ("flask/requests not
  importable from host python3") — not a failure, not a regression.

## Local vision empirical validation — VIABLE (~20 s/frame, grounded)
- Apple M3 Pro, no CUDA. `mlx-vlm` 0.6.3 + `mlx-community/Qwen2.5-VL-3B-Instruct-4bit`
  (Metal). Input: `ytdlp---dashboard---20260616T091827Z.png` downscaled to 1024px.
- Measured ~20.3 s/frame (model cached); named the real nav tabs, form fields,
  "Add to Queue" button, all 16 platforms correctly. Occasionally fabricates plausible
  dropdown values (good-not-flawless). See `docs/research/vision-path/CPU_VISION_RESEARCH.md`.

## Round-2 verdict
189 tests green this session across 5 suites (69 pytest + 22 smoke + 18 contract +
63 Angular + 17 shell), 0 real regressions; 4/4 UI surfaces re-recorded PASS; local
vision proven viable. No code defects found; all "discovered issues" were proven
not-bugs. SAFE subset only — lifecycle/integration suites intentionally not run.
