# Feature Specification: User Account Services

**Feature Branch**: `[001-user-account-services]`

**Created**: 2026-09-13

**Status**: Draft

**Input**: User description: "Make sure all files we create during the development process, creation of directories, or any file produced by the system in download directory / destination is ALWAYS created using current user account! We MUST start all servcies using systemctl --user space with full integration through proper setup / install / start / stop / status / restart and others bash scripts! All scripts MUST BE located under scripts directory, not in the root fo the project! All existing documentation and metrails MUST BE fully updated and extended, user guides and manulas as well (or created if they do not exist)! Once all is done, execute installation of new codebase, bootup all services (all of them MUST ALWAYS surview reboot of the system), perform full LIVE testing with exhaustive validation and verification fully deterministically with no false or faulty positives, no ai slop in any form, and no bluff of any kind or form! Once all is validated and verified completely release new version of the project with proper veriosn tag using GitHub and GitLab CLIs and properly written change and verison logs! All mandatory rules, guidelines and constraints, technology, or any extensions and additions from the constitution Submodule MUST BE fully incorporated, respected, followed and used with no avoiding or violations!"

## Clarifications

### Session 2026-09-13

- Q: What is the target environment for the system in terms of init system and operating system support? → A: Linux distributions with systemd only (do not support other init systems or non-Linux OS)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Proper File Ownership (Priority: P1)

As a developer or system operator, I want all files created by the system during development, directory creation, or any system processes to be owned by my current user account, so that I don't need to use sudo or change permissions manually after the fact, reducing security risks and permission-related errors.

**Why this priority**: This is foundational - incorrect file ownership leads to permission errors, security vulnerabilities, and operational friction that impacts every other aspect of the system.

**Independent Test**: Can be fully tested by creating a test directory and verifying that all files and subdirectories created within it are owned by the current user, not root or another user.

**Acceptance Scenarios**:

1. **Given** a development environment, **When** any file or directory is created by the system during normal operation, **Then** the file/directory is owned by the current user account (matching the UID/GID of the user running the process)
2. **Given** a download directory destination, **When** any file is produced by the system (e.g., downloaded video, metadata, thumbnail), **Then** the file is owned by the current user account
3. **Given** a script execution context, **When** the script creates temporary or permanent files, **Then** those files are owned by the current user account

### User Story 2 - Systemd User Services Management (Priority: P1)

As a system operator, I want to start, stop, and manage all services using systemctl --user space with proper setup, install, start, stop, status, and restart scripts, so that services run in the user context with appropriate permissions and integrate seamlessly with the user's session.

**Why this priority**: Service management is core to system operation - using systemctl --user ensures services run with correct permissions, survive user login/logout cycles appropriately, and follow Linux best practices for user services.

**Independent Test**: Can be fully tested by verifying that all services can be started, stopped, queried for status, and restarted using systemctl --user commands, and that they persist appropriately across user sessions.

**Acceptance Scenarios**:

1. **Given** a service definition, **When** I execute `systemctl --user start <service>`, **Then** the service starts successfully and runs in the user context
2. **Given** a running service, **When** I execute `systemctl --user stop <service>`, **Then** the service stops cleanly
3. **Given** a service, **When** I execute `systemctl --user status <service>`, **Then** I see accurate status information about the service
4. **Given** a service, **When** I execute `systemctl --user restart <service>`, **Then** the service stops and starts successfully
5. **Given** a service installation process, **When** I run the install script, **Then** the service is properly registered with systemctl --user

### User Story 3 - Scripts Relocation and Documentation (Priority: P2)

As a developer or contributor, I want all scripts to be located in the scripts directory (not project root) and all documentation to be fully updated and extended, so that the project maintains a clean, organized structure and provides clear guidance for users and contributors.

**Why this priority**: Project organization and documentation quality directly impact maintainability and usability - a well-organized project with good documentation reduces onboarding time and errors.

**Independent Test**: Can be fully tested by verifying that all executable scripts reside in the scripts directory, none remain in the project root, and that all user guides and manuals exist and are up-to-date.

**Acceptance Scenarios**:

1. **Given** the project structure, **When** I examine the project root directory, **Then** I find no executable scripts (only the scripts directory contains them)
2. **Given** a script that needs to be executed, **When** I look for it, **Then** I find it in the scripts directory
3. **Given** documentation needs, **When** I check the docs directory, **Then** I find comprehensive, up-to-date user guides and manuals
4. **Given** existing documentation, **When** I review it, **Then** I find it has been fully updated and extended to cover all current functionality

### User Story 4 - Full Lifecycle Management (Priority: P1)

As a system operator, I want to be able to install the codebase, boot up all services, verify they survive reboots, perform exhaustive live testing, and release new versions properly, so that the system is reliable, maintainable, and follows software release best practices.

**Why this priority**: Lifecycle management ensures the system can be reliably deployed, operated, and updated - critical for production use.

**Independent Test**: Can be fully tested by performing a complete install-boot-test-release cycle and verifying each step works as expected.

**Acceptance Scenarios**:

1. **Given** a fresh environment, **When** I execute the installation process, **Then** the codebase is properly installed and ready for use
2. **Given** an installed codebase, **When** I boot up all services, **Then** all services start successfully and remain running
3. **Given** running services, **When** I reboot the system, **Then** all services automatically restart and continue operating correctly
4. **Given** a running system, **When** I perform exhaustive live testing with validation and verification, **Then** all tests pass deterministically with no false positives
5. **Given** a validated system, **When** I execute the release process, **Then** a new version is properly tagged using GitHub/GitLab CLIs with accurate changelogs and version logs

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST ensure all files created during development process, directory creation, or any system processes are owned by the current user account (matching the UID/GID of the executing user)
- **FR-002**: System MUST ensure all files produced in the download directory are owned by the current user account
- **FR-003**: System MUST provide setup, install, start, stop, status, and restart scripts for all services that integrate with systemctl --user
- **FR-004**: System MUST locate all scripts exclusively in the scripts directory (no scripts permitted in project root)
- **FR-005**: System MUST maintain fully updated and extended documentation, user guides, and manuals
- **FR-006**: System MUST support complete installation of the codebase
- **FR-007**: System MUST ensure all services boot up successfully and remain operational
- **FR-008**: System MUST ensure all services survive system reboots and automatically restart
- **FR-009**: System MUST support exhaustive live testing defined as executing the full test suite (unit, integration, scenario, error, dashboard, media services, real HTTP, chaos, VPN-smoke, dashboard-operations) with deterministic validation and verification, ensuring 100% test coverage for all modified code and no test dependencies on mutable state.
- **FR-010**: System MUST produce no false or faulty positives during testing
- **FR-011**: System MUST exclude AI slop, defined as any testing activity that relies on unverified AI-generated assertions, mocks across service boundaries, or synthetic-success as a stand-in for behavioral success, ensuring all validation is based on observable evidence and positive-evidence-only checks per constitution §7.1.
- **FR-012**: System MUST exclude bluff, defined as any validation that claims success without verifying the user-visible behavior it purports to cover, including status-only assertions, silent network short-circuits, or syntactic-success as a stand-in for behavioral success, adhering to constitution §7.1 (NO BLUFF — positive-evidence-only validation).
- **FR-013**: System MUST support releasing new versions with proper version tags following semantic versioning (MAJOR.MINOR.PATCH) using GitHub and GitLab CLIs, and MUST use the project's official commit wrapper (e.g., `scripts/commit_all.sh`) for any git operations, in accordance with constitution principle §2.
- **FR-014**: System MUST generate properly written changelogs and version logs during release process, following the format specified in the existing `CHANGES_SUMMARY.md` or `Keep a Changelog` guidelines.
- **FR-015**: System MUST ensure that every version tag created on the main repository is mirrored to every owned submodule, in accordance with constitution principle §4.
- **FR-016**: System MUST fully incorporate, respect, and follow all mandatory rules, guidelines, and constraints from the constitution submodule

### Key Entities

- **User Account**: The current executing user's account that should own all created files
- **Download Directory**: The destination directory where system-produced files (downloads, metadata, etc.) must be owned by current user
- **Services**: The set of services managed via systemctl --user, defined as those services listed in `docker-compose.yml` under the `vpn`, `no-vpn`, `vpn-cli`, and `docker` profiles (see `docker-compose.yml` for the current list).
- **Systemd User Service**: A service managed via systemctl --user that runs in the user context
- **Scripts Directory**: The designated location (/scripts) for all executable scripts
- **Documentation Set**: The collection of user guides, manuals, and technical documentation
- **Release Artifact**: The versioned output of the release process including tags, changelogs, and logs

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of files created by the system during normal operation are owned by the current user account (verified via file ownership audits)
- **SC-002**: 100% of services can be started, stopped, queried, and restarted using systemctl --user commands
- **SC-003**: 0 executable scripts reside in the project root directory (all located in scripts/)
- **SC-004**: All user guides and manuals are complete (covering every user-facing feature and CLI command), accurate (matching implemented behavior and configuration), and up-to-date with current functionality, verified via spot-check of critical user journeys (installation, service start/stop, download, cookie upload, dashboard navigation) and comparison against source code.
- **SC-005**: Successful completion of install-boot-test-release cycle with all services functioning correctly post-reboot
- **SC-006**: 0 false or faulty positives detected during exhaustive live testing
- **SC-007**: 0 instances of AI slop detected in testing validation processes, where AI slop is defined as any testing activity that relies on unverified AI-generated assertions, mocks across service boundaries, or synthetic-success as a stand-in for behavioral success.
- **SC-008**: 0 instances of bluff detected in testing validation processes, where bluff is defined as any validation that claims success without verifying the user-visible behavior it purports to cover, including status-only assertions, silent network short-circuits, or syntactic-success as a stand-in for behavioral success.
- **SC-009**: Successful version tagging using GitHub/GitLab CLIs with semantic versioning
- **SC-010**: Changelogs and version logs are complete (covering all changes since last version), accurate (matching actual changes), and follow established formats (as defined in `CHANGES_SUMMARY.md` or `Keep a Changelog` guidelines).
- **SC-011**: Full compliance with all mandatory rules from constitution submodule (verified via compliance checks)

## Assumptions

- The target environment is Linux distributions with systemd only (no support for other init systems or non-Linux OS)
- Users have appropriate permissions to manage systemd user services
- The project follows standard Linux filesystem hierarchy conventions
- Existing documentation structure can be extended and updated
- Git and GitHub/GitLab CLIs are available for version control and release operations
- The constitution submodule provides clear, accessible mandatory rules and guidelines
- Development and testing environments closely resemble production environments
- Users possess basic Linux administration knowledge for service management
