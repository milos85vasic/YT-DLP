# DRAFT — §11.4.155 anchor for conductor application via the §11.4.26 pipeline

**Revision:** 1
**Last modified:** 2026-06-15T00:00:00Z
**Status:** DRAFT — reviewable, NOT yet applied. Do NOT edit the constitution files from this doc; the conductor applies it through the §11.4.26 Constitution-Submodule Update Workflow (fetch+pull first → apply → validate → commit+push to ALL upstreams → post-merge validation → bump pointer).
**Authority:** universal addition (§11.4.17) to the constitution submodule's canonical root files (§11.4.35).
**Origin:** operator mandate (2026-06-15, verbatim): "All recorded videos MUST START with prefix: the PROJECT NAME (ALWAYS USE THE PROJECT NAME). Project name MUST be obtained according to the constitution's own project-name resolution."

---

## 1. The §11.4.155 anchor text (Constitution.md full-form)

> Insert verbatim into `constitution/Constitution.md` immediately after §11.4.154, in the §11.4.153/§11.4.154 house style (heading + mandate body + Composes line + honest boundary + Classification + propagation/recommended gates + paired §1.1 mutation + Canonical authority + No-escape-hatch flag list). A condensed mirror (same content, mirror-form) lands in each consumer governance file per the Application checklist in §2.

### §11.4.155 — Project-name-prefixed feature/QA recording filenames (User mandate, 2026-06-15)

**Forensic anchor — verbatim user mandate (2026-06-15):** "All recorded videos MUST START with prefix: the PROJECT NAME (ALWAYS USE THE PROJECT NAME). Project name MUST be obtained according to the constitution's own project-name resolution."

Every recorded video the project produces — every feature/QA real-use recording (§11.4.153), every window-scoped capture (§11.4.154), every always-on device recording (§11.4.128), and every raw or curated recording artefact under the project-declared recording path (§11.4.35) and the committed `docs/qa/<run-id>/` evidence trail (§11.4.83) — MUST have a filename that STARTS WITH the PROJECT-NAME prefix, ALWAYS, with no exception. A recording filename that omits the project-name prefix is a §11.4.155 violation: a corpus spanning multiple projects/scopes on one host (a real condition under §11.4.128 always-on recording + §11.4.103 parallel streams) becomes un-greppable and un-attributable, and a reader cannot tell at a glance which project a recording belongs to — the same identify-and-grep failure §11.4.151 forbids on the release-tag axis, applied to the recording-corpus axis.

**Prefix resolution order (closed-set, deterministic — §11.4.6 no-guessing; IDENTICAL to §11.4.151's prefix resolution):** the project-name prefix MUST be resolved, never guessed, by the constitution's own project-name resolution: (1) `HELIX_RELEASE_PREFIX` from the project's `.env` — authoritative when set; `.env` is git-ignored per §11.4.30 and the variable is documented in the tracked `.env.example` (a §11.4.77 re-obtain mechanism, never committed); (2) fallback = the lowercased snake_case form of the project root directory name (no spaces) per §11.4.29 — used whenever the env var is unset/empty, so a prefix is ALWAYS resolvable from the checkout with zero operator input. The SAME resolved prefix is used for EVERY recording the project produces in a given checkout, so a single `ls '<PREFIX>---'*` (or `find . -name '<PREFIX>---*'`) enumerates the whole recording corpus for that project. Canonical filename form: `<PREFIX>---<feature-or-scope>---<run-id>.<ext>` (the `---` triple-hyphen separator keeps the prefix unambiguously delimited from a feature/scope name that may itself contain hyphens). The prefix MUST be the SAME value §11.4.151 resolves for release tags in the same checkout — a recording prefix and a release-tag prefix diverging in one checkout is itself a §11.4.155 violation (one project, one resolved name).

Honest boundary (§11.4.6): the project-name prefix guarantees a recording is attributable + greppable to its project, NOT that the recording's CONTENT is valid — content validity still rests on the §11.4.107 liveness battery, the §11.4.137 content-correctness oracle, and the §11.4.153 video-analysis remediation loop; the prefix is a naming/attribution discipline that composes with, never replaces, those evidence layers. The prefix also does NOT relax §11.4.154's window-scoped-capture + fresh-corpus-rotation invariants (rotation removes the agent's OWN prior in-scope `<PREFIX>---*` recordings first; a foreign-prefix or operator-authored file is surfaced, never deleted, per §11.4.122 + §9.2).

Classification: universal (§11.4.17) — a platform-neutral recording-attribution discipline reusable by ANY project that produces recordings; the consuming project supplies its concrete prefix value + the `HELIX_RELEASE_PREFIX` env var + its recording path per §11.4.35. Composes §11.4.151 (the SAME prefix-resolution order + the same identify-and-grep purpose, applied to recordings instead of release tags) / §11.4.128 (every always-on device recording filename carries the prefix) / §11.4.153 (the per-feature real-use video's confirmation path is prefixed) / §11.4.154 (window-scoped + fresh-corpus rotation operate on prefixed filenames) / §11.4.111 (the prefix is a stable-identity name, not an enumeration index) / §11.4.83 (committed `docs/qa/<run-id>/` recording evidence carries the prefix) plus §11.4.6 / §11.4.29 / §11.4.30 / §11.4.35 / §11.4.77 / §11.4.86. Propagation gate `CM-COVENANT-114-155-PROPAGATION` (literal `11.4.155` across the consumer fleet) + recommended gate `CM-RECORDING-PROJECT-NAME-PREFIX` (every recording filename at the project's recording path + every committed `docs/qa/<run-id>/` recording artefact starts with the resolved `<PREFIX>---` prefix, identical to the §11.4.151-resolved prefix for the checkout) + paired §1.1 meta-test mutation (strip the literal → propagation gate FAILs; write a recording with no project-name prefix, or a prefix differing from the §11.4.151-resolved value → `CM-RECORDING-PROJECT-NAME-PREFIX` FAILs; gate-code = separate work item).

**Canonical authority:** constitution submodule [`Constitution.md`](Constitution.md) §11.4.155. Non-compliance is a release blocker. No escape hatch — no `--no-recording-prefix`, `--recording-without-project-name`, `--unprefixed-recording`, `--prefix-optional-for-recording`, `--differing-recording-prefix` flag.

---

## 2. Application checklist (per the §11.4.26 pipeline)

The conductor applies this anchor to the FIVE canonical governance files (constitution-submodule canonical root per §11.4.35 — the universal addition lands here; the consumer-root mirrors restate the literal `11.4.155` so propagation gates pass):

1. `constitution/Constitution.md` — insert the full-form §11.4.155 text from §1 of this draft, immediately after §11.4.154.
2. `constitution/CLAUDE.md` — insert the condensed mirror-form (same content, mirror style) after the §11.4.154 mirror; update the `Status summary` revision line.
3. `constitution/AGENTS.md` — insert the condensed mirror-form after the §11.4.154 mirror.
4. `constitution/QWEN.md` — insert the condensed mirror-form after the §11.4.154 mirror.
5. `constitution/GEMINI.md` — insert the condensed mirror-form after the §11.4.154 mirror.

Each of the five `.md` files needs its synchronized `.html` / `.pdf` siblings regenerated per §11.4.65 (the §11.4.153 DOCX add-on applies to the feature-Status doc class only, NOT to these governance files — they stay HTML+PDF). The §11.4.26 step order is binding: fetch+pull the submodule to upstream tip FIRST → apply (classify universal per §11.4.17) → validate (no conflict markers, cross-references consistent) → commit staging ONLY the governance files + their regenerated siblings (NEVER `git add -A` in the submodule, §11.4.30) → push to ALL upstreams via merge-onto-latest-main (§11.4.113, NEVER force-push) → post-merge cascade validation → bump the consuming project's `.gitmodules` constitution pointer in the same commit as cascade work.

---

## 3. §11.4.17 classification line

Classification: **universal** (§11.4.17) — a project-name-prefixed recording-filename discipline is platform-neutral and reusable by any project that produces recordings, references no particular hardware/vendor/region, and reuses the existing §11.4.151 project-name resolution, so it belongs in the constitution submodule's canonical root rather than the consumer layer.

---

## 4. Concrete example for THIS project

For THIS project the prefix resolves via the §11.4.151 / §11.4.155 order:
- `HELIX_RELEASE_PREFIX` is NOT set in `.env`, so the resolution falls through to the fallback;
- fallback = lowercased snake_case of the project root directory name = `ytdlp` (root dir = `ytdlp`).

Therefore every recording for this project starts with `ytdlp`, e.g.:

```
ytdlp---<feature>---<run-id>.mp4
```

(Concrete instance: `ytdlp---dashboard-add-download---20260615T101500Z.mp4`.) The same `ytdlp` prefix is what §11.4.151 resolves for this checkout's release tags, satisfying the "one project, one resolved name" cross-axis requirement.
