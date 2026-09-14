# Implementation Plan: User Account Services

**Branch**: `[001-user-account-services]` | **Date**: 2026-09-13 | **Spec**: [link to spec.md](spec.md)
**Input**: Feature specification from `specs/001-user-account-services/spec.md`

## Summary

Ensure all system-created files are owned by the current user account, manage services via systemctl --user, relocate all scripts to the scripts directory, fully update documentation, and support full lifecycle management (install, boot, survive reboot, test, release) while complying with the project constitution.

## Technical Context

**Language/Version**: Bash 5.x, Python 3.11, TypeScript 5.x (consistent with existing project)
**Primary Dependencies**: systemd (for user services), Podman/Docker (existing container runtime)
**Storage**: N/A (no new storage introduced)
**Testing**: Bash test framework (using existing test-*.sh scripts)
**Target Platform**: Linux server with systemd
**Project Type**: CLI/tooling and project infrastructure
**Performance Goals**: N/A (feature focuses on correctness and operational excellence)
**Constraints**: Must support both Podman and Docker runtimes, must not break existing functionality, must comply with all constitution principles

## Constitution Check

*GATE: Must pass before proceeding. Re-check after design phase.*

| Principle | Status | Notes |
|-----------|--------|-------|
| 1. Test coverage is mandatory for every change | PASS | Plan includes testable success criteria; will add tests for file ownership, service management, script location, and documentation completeness. |
| 2. Commit and push mechanics — single entrypoint, locked | PASS | Will use existing `scripts/commit_all.sh` or similar for any changes; no direct git commits/pushes. |
| 3. Submodule changes propagate through submodule commits first | PASS | No submodule changes planned for this feature; if any arise, will follow this principle. |
| 4. Every tag on the main repo MUST be mirrored on every owned submodule | PASS | Will follow tagging procedures via GitHub/GitLab CLIs as specified in success criteria. |
| 5. Changelog discipline and multi-format export | PASS | Will generate proper changelogs and version logs during release process (SC-010). |
| 6. Documentation up to the nano-details | PASS | Feature explicitly requires fully updated and extended documentation, user guides, and manuals (FR-005, SC-004). |
| 7. Making false-success results literally impossible | PASS | Success criteria are deterministic and verifiable; testing will ensure no false positives (SC-006, SC-007, SC-008). |
| §8. Bleeding-edge ultra-perfection quality bar | PASS | Feature aims for deterministic validation with no false positives, no AI slop, no bluff (FR-009-FR-012). |
| §9. Absolute codebase and data safety — zero risk, zero loss | PASS | File ownership ensures proper permissions; services designed to survive reboots; no data loss introduced. |
| §10. Enforcement | PASS | Constitution compliance is a functional requirement (FR-015) and success criterion (SC-011). |
| §11. End-user quality covenant | PASS | Focus on user value: correct file ownership, easy service management, clear documentation, reliable lifecycle. |

## Project Structure

### Documentation (this feature)

```text
specs/001-user-account-services/
├── spec.md              # Feature specification
├── plan.md              # This file
├── tasks.md             # Task breakdown (/speckit.superspec.tasks output)
└── checklist-*.md       # Generated checklists
```

### Source Code (repository root)

```text
scripts/
├── setup/               # Installation and setup scripts
├── service/             # Service management scripts (start, stop, status, restart)
├── lifecycle/           # Lifecycle scripts (boot, test, release)
├── utils/               # Utility scripts (file ownership checks, etc.)
└── [existing scripts moved here]/

docs/
├── user-guides/         # Updated user guides
├── manuals/             # Updated manuals
└── [existing documentation moved here]/

# Root directory should contain no executable scripts (only the scripts directory)
```

**Structure Decision**: Adopt a modular script organization under `scripts/` with subdirectories by function (setup, service, lifecycle, utils). This keeps the project root clean, improves discoverability, and aligns with the requirement that all scripts reside under `scripts/`. Documentation is similarly organized under `docs/` for clarity.

## Execution Strategy

### TDD Requirements

- [x] File ownership verification: Complex logic with edge cases (e.g., subuid handling, tmpfs detection) requires TDD.
- [x] Service management scripts: Ensuring correct systemd --user integration and error handling.
- [x] Documentation validation: Checking completeness and accuracy of guides/manuals.
- [x] Lifecycle scripts: Install-boot-test-release cycle must work reliably.

### Parallel Execution Opportunities

- [x] Script relocation and documentation updates can proceed in parallel after initial analysis.
- [x] Service script development (start, stop, status, restart) can be parallelized per service type.
- [x] Lifecycle script components (install, boot, test, release) can be developed independently then integrated.

### Human Checkpoints

1. After script reorganization — verify project root has no executable scripts and all scripts are in `scripts/`.
2. After service management script implementation — verify each service can be started/stopped/queried/restarted via systemctl --user.
3. After documentation update — verify user guides and manuals are complete and accurate.
4. After lifecycle script implementation — perform full install-boot-test-release cycle.
5. Before merge — final review against spec and constitution.

### Review Gates

- [x] Script ownership and permission logic: Review before implementing service scripts.
- [x] Systemd service unit files (if any): Review before integration.
- [x] Documentation completeness: Review before finalizing user guides/manuals.
- [x] Lifecycle script safety: Review before allowing execution on production-like environments.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | All constitution principles can be satisfied with straightforward approach. | N/A |

