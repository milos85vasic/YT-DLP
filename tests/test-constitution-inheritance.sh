#!/usr/bin/env bash
#
# test-constitution-inheritance.sh — Constitution-submodule inheritance gate.
#
# Verifies that this project REALLY inherits the Helix Universal
# Constitution shipped as the `constitution/` git submodule — not that a
# pointer was merely typed somewhere. Every invariant asserts a concrete,
# verbatim anchor string or filesystem fact, so deleting the implementation
# (the submodule, an anchor, or a parent pointer) makes this gate FAIL.
#
# DUAL MODE:
#   • Executed standalone  ->  runs all invariants, prints PASS/FAIL per
#     invariant, exits 0 iff every invariant passes. Used by
#     scripts/dev-check.sh (pre-push) and the paired meta-test.
#   • Sourced by tests/run-tests.sh -> defines run_constitution_tests(),
#     which routes each invariant through the project's run_test() counter.
#
# ANTI-BLUFF (Constitution §1.1 / CONST-034): the paired mutation harness
# tests/meta-test-constitution-inheritance.sh proves this gate FAILs when any
# inherited anchor is stripped. A gate without that paired proof is itself a
# Constitution violation.
#
# NOTE: deliberately NO `set -e` — failures are tallied explicitly, matching
# tests/run-tests.sh (abort-on-first-fail would defeat the per-invariant report).

# --- Resolve repo root regardless of CWD -------------------------------------
_ci_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null && return 0
    ( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )
}
CI_ROOT="$(_ci_repo_root)"
CI_CONST="${CI_ROOT}/constitution"

# --- Real, VERIFIED anchor sentinels (grepped verbatim — never paraphrase) ---
# Sourced from the pinned submodule revision 6445733; confirmed present at:
#   constitution/Constitution.md:454, constitution/CLAUDE.md:137,
#   constitution/AGENTS.md:163.
CI_ANCHOR_CONSTITUTION='### §11.4 End-user quality guarantee — forensic anchor (User mandate, 2026-04-28)'
CI_ANCHOR_CLAUDE='## MANDATORY ANTI-BLUFF COVENANT — END-USER QUALITY GUARANTEE'
CI_ANCHOR_AGENTS='### Anti-bluff covenant — END-USER QUALITY GUARANTEE (§11.4)'

# --- Invariants (each echoes a reason on failure, returns 0/1) ----------------

_ci_inv_submodule_present() {
    [ -d "$CI_CONST" ] || { echo "FAIL: constitution/ submodule dir missing ($CI_CONST)"; return 1; }
    [ -f "$CI_CONST/Constitution.md" ] || { echo "FAIL: constitution/Constitution.md missing — submodule not populated (run: git submodule update --init)"; return 1; }
    grep -qF 'path = constitution' "$CI_ROOT/.gitmodules" 2>/dev/null || { echo "FAIL: .gitmodules has no 'constitution' submodule entry"; return 1; }
    return 0
}

_ci_inv_constitution_anchor() {
    grep -qF "$CI_ANCHOR_CONSTITUTION" "$CI_CONST/Constitution.md" 2>/dev/null \
        || { echo "FAIL: §11.4 forensic anchor missing from constitution/Constitution.md"; return 1; }
    return 0
}

_ci_inv_claude_anchor() {
    grep -qF "$CI_ANCHOR_CLAUDE" "$CI_CONST/CLAUDE.md" 2>/dev/null \
        || { echo "FAIL: anti-bluff covenant anchor missing from constitution/CLAUDE.md"; return 1; }
    return 0
}

_ci_inv_agents_anchor() {
    grep -qF "$CI_ANCHOR_AGENTS" "$CI_CONST/AGENTS.md" 2>/dev/null \
        || { echo "FAIL: anti-bluff covenant anchor missing from constitution/AGENTS.md"; return 1; }
    return 0
}

_ci_inv_helpers() {
    local rc=0
    [ -x "$CI_CONST/install_upstreams.sh" ] || { echo "FAIL: constitution/install_upstreams.sh missing or not executable"; rc=1; }
    [ -x "$CI_CONST/find_constitution.sh" ] || { echo "FAIL: constitution/find_constitution.sh missing or not executable"; rc=1; }
    return $rc
}

_ci_inv_parent_refs() {
    local rc=0
    grep -qF '@constitution/CLAUDE.md' "$CI_ROOT/CLAUDE.md" 2>/dev/null \
        || { echo "FAIL: parent CLAUDE.md does not reference @constitution/CLAUDE.md"; rc=1; }
    grep -qF 'constitution/AGENTS.md' "$CI_ROOT/AGENTS.md" 2>/dev/null \
        || { echo "FAIL: parent AGENTS.md does not reference constitution/AGENTS.md"; rc=1; }
    grep -qF 'constitution/Constitution.md' "$CI_ROOT/CONSTITUTION.md" 2>/dev/null \
        || { echo "FAIL: parent CONSTITUTION.md does not reference constitution/Constitution.md"; rc=1; }
    return $rc
}

_ci_inv_nested_inheritance() {
    # Recursive child-submodule inheritance: every OWNED nested submodule that
    # carries CLAUDE.md/AGENTS.md must point back at the Helix Constitution.
    local rc=0 f
    for f in Challenges/CLAUDE.md Challenges/AGENTS.md; do
        if [ -f "$CI_ROOT/$f" ]; then
            grep -qF 'Helix Constitution' "$CI_ROOT/$f" 2>/dev/null \
                || { echo "FAIL: $f present but missing 'Helix Constitution' inheritance pointer"; rc=1; }
        else
            echo "FAIL: nested submodule inheritance pointer missing: $f"; rc=1
        fi
    done
    return $rc
}

# --- Invariant registry: "human name|function" -------------------------------
# NOTE: names must not contain '/' — run_test() writes a per-test log at
# "$TEST_LOGS_DIR/<name>.log", so a slash would point into a missing subdir.
_CI_INVARIANTS=(
    "constitution submodule present and populated|_ci_inv_submodule_present"
    "Constitution.md carries the §11.4 forensic anchor|_ci_inv_constitution_anchor"
    "constitution CLAUDE.md carries anti-bluff covenant anchor|_ci_inv_claude_anchor"
    "constitution AGENTS.md carries anti-bluff covenant anchor|_ci_inv_agents_anchor"
    "constitution helper scripts present and executable|_ci_inv_helpers"
    "parent CLAUDE, AGENTS, CONSTITUTION reference the submodule|_ci_inv_parent_refs"
    "nested Challenges submodule inherits the constitution|_ci_inv_nested_inheritance"
)

# --- Sourced mode: integrate with run-tests.sh counters ----------------------
run_constitution_tests() {
    local entry name func
    for entry in "${_CI_INVARIANTS[@]}"; do
        name="${entry%%|*}"; func="${entry##*|}"
        run_test "constitution_inheritance — ${name}" "$func"
    done
}

# --- Standalone mode: self-contained gate ------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fails=0; total=0
    echo "=== Constitution inheritance gate (root: ${CI_ROOT}) ==="
    for entry in "${_CI_INVARIANTS[@]}"; do
        name="${entry%%|*}"; func="${entry##*|}"
        total=$((total + 1))
        if "$func"; then
            echo "PASS: ${name}"
        else
            echo "FAIL: ${name}"
            fails=$((fails + 1))
        fi
    done
    echo "=== inheritance gate: $((total - fails))/${total} invariants PASS ==="
    [ "$fails" -eq 0 ] && exit 0 || exit 1
fi
