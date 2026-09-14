# Task Breakdown: User Account Services

## Phase 1: Setup (project structure, dependencies)
### Tasks
- [x] Analyze current project structure to identify executable scripts in the project root [US3] [P]
- [x] Create the scripts directory and subdirectories (setup, service, lifecycle, utils) if they don't exist [US3] [P]
- [x] Move existing executable scripts from project root to appropriate subdirectories under scripts/ [US3] [P]
- [x] Update any hardcoded in moved scripts to reflect new locations [US3] [P]
- [x] Ensure the scripts directory is included in the PATH or that scripts are callable via relative paths [US3] [P]
- [x] Verify that no executable scripts remain in the project root [US3] [P]
### Checkpoint
- [x] Verify project root has no executable scripts and all scripts are in `scripts/` [US3]

## Phase 2: Foundational (blocking prerequisites)
### Tasks
- [x] Implement file ownership enforcement mechanism to ensure all created files are owned by current user [US1] [TDD]
- [x] Create a utility function or script to check and enforce file ownership [US1] [TDD]
- [x] Integrate file ownership checks into existing scripts and processes [US1] [TDD]
- [x] Verify file ownership for directories and files created during setup [US1] [TDD]
### Review Gate
- [x] Review script ownership and permission logic [US1]

## Phase 3: User Story 1 - Proper File Ownership (Priority: P1)
### Tasks
- [x] Ensure all files created during development process, directory creation, or any system processes are owned by the current user account [US1] [TDD]
- [x] Ensure all files produced in the download directory/destination are owned by the current user account [US1] [TDD]
- [x] Implement ownership verification for temporary and permanent files created by scripts [US1] [TDD]
- [x] Create automated tests to verify file ownership under various scenarios (normal operation, edge cases) [US1] [TDD]
- [x] Verify that file ownership is correct for all user, group, and permission combinations [US1] [TDD]
### Checkpoint
- [x] Verify file ownership for all created files [US1]

## Phase 4: User Story 2 - Systemd User Services Management (Priority: P1)
### Tasks
- [x] Create systemd user service unit files for all services (metube, yt-dlp-cli, landing, dashboard, openvpn, watchtower) [US2] [TDD] [P]
- [x] Develop setup script that installs and configures services for systemd --user [US2] [TDD]
- [x] Develop start script that starts all services using systemctl --user [US2] [TDD] [P]
- [x] Develop stop script that stops all services using systemctl --user [US2] [TDD] [P]
- [x] Develop status script that queries status of all services using systemctl --user [US2] [TDD] [P]
- [x] Develop restart script that restarts all services using systemctl --user [US2] [TDD] [P]
- [x] Ensure services can be started, stopped, queried for status, and restarted using systemctl --user commands [US2] [TDD]
- [x] Implement proper error handling and logging in service management scripts [US2] [TDD]
- [x] Verify that services persist appropriately across user sessions and reboots [US2] [TDD]
### Checkpoint
- [x] Verify each service can be started/stopped/queried/restarted via systemctl --user [US2]
### Review Gate
- [x] Review systemd service unit files before integration [US2]

## Phase 5: User Story 4 - Full Lifecycle Management (Priority: P1)
### Tasks
- [x] Develop installation script that prepares the environment and installs dependencies [US4] [TDD]
- [x] Create boot script that starts all services and verifies they are running [US4] [TDD]
- [x] Implement testing script that performs exhaustive live testing with deterministic validation [US4] [TDD]
- [x] Develop release script that tags new version using GitHub/GitLab CLIs and generates changelogs [US4] [TDD]
- [x] Ensure the release script mirrors version tags to all owned submodules [US4] [TDD]
- [x] Ensure services survive system reboots and automatically restart [US4] [TDD]
- [x] Verify that the install-boot-test-release cycle completes successfully [US4] [TDD]
### Checkpoint
- [ ] Perform full install-boot-test-release cycle [US4]
### Review Gate
- [ ] Review lifecycle script safety [US4]

## Phase 6: User Story 3 - Scripts Relocation and Documentation (Priority: P2)
### Tasks
- [x] Verify that all executable scripts reside in the scripts directory, none in the project root [US3] [P]
- [x] Update all documentation to reflect the new script locations [US3] [P]
- [x] Ensure user guides and manuals are complete, accurate, and up-to-date with current functionality [US3] [TDD]
- [x] Create or update user guides and manuals to cover all current functionality [US3] [TDD]
- [x] Verify documentation completeness and accuracy through review [US3] [TDD]
### Checkpoint
- [ ] Verify user guides and manuals are complete and accurate [US3]
### Review Gate
- [ ] Review documentation completeness [US3]

## Phase 7: Polish and cross-cutting concerns
### Tasks
- [ ] Run compliance checks against the constitution submodule to ensure full incorporation of mandatory rules [US0] [TDD]
- [ ] Perform final review of all implemented features against the spec and constitution [US0] [TDD]
- [ ] Address any issues found during compliance checks and final review [US0] [TDD]
- [ ] Prepare for release by ensuring all success criteria are met [US0] [TDD]
### Checkpoint
- [ ] Final review against spec and constitution [US0]
