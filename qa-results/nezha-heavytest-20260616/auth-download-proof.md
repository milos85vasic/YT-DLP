# Auth'd YouTube download on nezha — cookies WORK (2026-06-16)

The re-seeded operator cookies (853 KB) authenticate YouTube successfully on the nezha
production stack — the auth'd download flow is PROVEN:
- POST /add (youtube.com/watch?v=jNQXAC9IVRw, quality=best) → {"status": "ok"}
- metube-direct logs: multiple YouTube downloads ACTIVELY downloading at 1-6 MiB/s
  (e.g. "Intelligence Isn't What You Think" 0nG5LMo2LZU, several GB-scale files), one
  reached 100% (80.08 MiB in 40s) — NO "Sign in to confirm you're not a bot" / auth /
  bot-check error. Cookies enable login-protected platform downloads.
- This closes the "auth'd download" item: the cookie-enabled download path works end to
  end on the real production stack (distinct from the cookie-UPLOAD-mechanism challenge,
  which also PASSes).
