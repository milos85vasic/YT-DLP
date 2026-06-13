#!/usr/bin/env bash
#
# meta-test-constitution-inheritance.sh — PAIRED MUTATION PROOF (§1.1 / CONST-034)
#
# Proves that tests/test-constitution-inheritance.sh is a REAL gate, not a bluff
# gate. For each inherited anchor / pointer, it: snapshots the file, strips the
# anchor, runs the gate, asserts the gate now FAILs (rc != 0), and restores the
# file byte-for-byte. If the gate still returns 0 after an anchor is removed, the
# gate is a BLUFF GATE and this meta-test FAILs.
#
# A global EXIT/INT/TERM trap restores every touched file from a backup dir, so a
# crash or Ctrl-C can never leave the constitution submodule or parent dirty.
#
# Mutation 1 (Constitution.md §11.4 anchor) is delegated to the constitution's own
# reference harness constitution/meta_test_inheritance.sh, invoked with THIS
# project's gate command — exactly as the runbook prescribes.
#
# Usage:  bash tests/meta-test-constitution-inheritance.sh

set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || ( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd ))"
GATE_CMD="bash ${ROOT}/tests/test-constitution-inheritance.sh"
CONST_META="${ROOT}/constitution/meta_test_inheritance.sh"

PASS=0
FAIL=0
BACKUP_DIR="$(mktemp -d)"

# --- Global safety net: restore everything, always ---------------------------
_restore_all() {
    local b name
    for b in "${BACKUP_DIR}"/*.bak; do
        [ -e "$b" ] || continue
        name="$(basename "$b" .bak)"
        # name encodes the path with '/' -> '__'
        local target="${ROOT}/${name//__//}"
        cp -- "$b" "$target" 2>/dev/null || true
    done
    rm -rf "${BACKUP_DIR}" 2>/dev/null || true
}
trap _restore_all EXIT INT TERM

_run_gate_rc() { eval "$GATE_CMD" >/dev/null 2>&1; echo $?; }

# _mutate_assert_fail <label> <relpath> <verbatim-line-substring>
_mutate_assert_fail() {
    local label="$1" rel="$2" needle="$3"
    local file="${ROOT}/${rel}"
    local key="${rel//\//__}"
    local bak="${BACKUP_DIR}/${key}.bak"

    if [ ! -f "$file" ]; then
        echo "META-FAIL: ${label} — target file missing: ${rel}"; FAIL=$((FAIL+1)); return
    fi
    if ! grep -qF "$needle" "$file"; then
        echo "META-FAIL: ${label} — sentinel not present BEFORE mutation in ${rel}"; FAIL=$((FAIL+1)); return
    fi

    cp -- "$file" "$bak"                       # snapshot (also covered by EXIT trap)
    grep -vF "$needle" "$bak" > "$file"        # mutate: strip the anchor line

    local rc; rc="$(_run_gate_rc)"             # run gate against mutated tree

    cp -- "$bak" "$file"; rm -f -- "$bak"      # restore immediately

    if ! grep -qF "$needle" "$file"; then
        echo "META-FAIL: ${label} — RESTORE FAILED, sentinel not back in ${rel}!"; FAIL=$((FAIL+1)); return
    fi
    if [ "$rc" -ne 0 ]; then
        echo "META-PASS: ${label} — gate FAILed (rc=${rc}) with anchor removed, file restored clean"; PASS=$((PASS+1))
    else
        echo "META-FAIL: ${label} — gate returned 0 despite removed anchor → BLUFF GATE"; FAIL=$((FAIL+1))
    fi
}

echo "================================================================"
echo " META-TEST: Constitution inheritance gate — false-positive immunity"
echo " gate: ${GATE_CMD}"
echo "================================================================"

# Sanity: the gate must PASS on the pristine tree first (else mutations prove nothing).
echo ""
echo "--- baseline: gate must PASS on pristine tree ---"
if [ "$(_run_gate_rc)" -eq 0 ]; then
    echo "META-PASS: baseline — gate PASSes on the un-mutated tree"; PASS=$((PASS+1))
else
    echo "META-FAIL: baseline — gate does NOT pass on pristine tree (fix the gate/inheritance first):"
    eval "$GATE_CMD" || true
    FAIL=$((FAIL+1))
fi

# Mutation 1 — Constitution.md §11.4 anchor, via the constitution's own harness.
echo ""
echo "--- mutation 1: Constitution.md §11.4 anchor (delegated to constitution/meta_test_inheritance.sh) ---"
if [ -x "$CONST_META" ] || [ -f "$CONST_META" ]; then
    if bash "$CONST_META" "$GATE_CMD"; then
        echo "META-PASS: Constitution.md §11.4 anchor — constitution harness confirms gate catches removal"; PASS=$((PASS+1))
    else
        echo "META-FAIL: Constitution.md §11.4 anchor — constitution harness reported the gate did NOT catch removal"; FAIL=$((FAIL+1))
    fi
else
    echo "META-FAIL: constitution/meta_test_inheritance.sh not found at ${CONST_META}"; FAIL=$((FAIL+1))
fi

# Mutations 2-4 — local anchors / pointers.
echo ""
echo "--- mutation 2: constitution/CLAUDE.md anti-bluff covenant anchor ---"
_mutate_assert_fail "constitution/CLAUDE.md anchor" \
    "constitution/CLAUDE.md" \
    '## MANDATORY ANTI-BLUFF COVENANT — END-USER QUALITY GUARANTEE'

echo ""
echo "--- mutation 3: constitution/AGENTS.md anti-bluff covenant anchor ---"
_mutate_assert_fail "constitution/AGENTS.md anchor" \
    "constitution/AGENTS.md" \
    '### Anti-bluff covenant — END-USER QUALITY GUARANTEE (§11.4)'

echo ""
echo "--- mutation 4: parent CLAUDE.md @constitution/CLAUDE.md inheritance pointer ---"
_mutate_assert_fail "parent CLAUDE.md inheritance pointer" \
    "CLAUDE.md" \
    '@constitution/CLAUDE.md'

# --- Summary -----------------------------------------------------------------
echo ""
echo "================================================================"
echo " META-TEST SUMMARY:  PASS=${PASS}  FAIL=${FAIL}"
echo "================================================================"

# Final cleanliness assertion: the constitution submodule must be clean again
# (every mutation restored). This itself is anti-bluff — proves we left no debris.
if git -C "${ROOT}/constitution" diff --quiet 2>/dev/null; then
    echo "✓ constitution submodule working tree is clean (all mutations restored)"
else
    echo "✗ constitution submodule is DIRTY after meta-test — restore failed!"
    FAIL=$((FAIL+1))
fi

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
