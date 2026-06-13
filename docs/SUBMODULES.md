# Git Submodules

This repository depends on two pinned git submodules. They are not optional:
the constitution inheritance gate (`tests/test-constitution-inheritance.sh`,
wired into `tests/run-tests.sh` and `scripts/dev-check.sh` Gate 5c) fails hard
if the `constitution/` submodule is missing or empty. A fresh clone is not
fully usable until the submodules are checked out.

## The two submodules

Defined in `.gitmodules` at the repo root:

| Path | Upstream | Pinned to | Role |
|---|---|---|---|
| `constitution/` | `git@github.com:HelixDevelopment/HelixConstitution.git` | SHA `6445733e` (on `main`) | The Helix Universal Constitution this project inherits. Supplies `constitution/Constitution.md`, `constitution/CLAUDE.md`, `constitution/AGENTS.md` and the upstream templates/tests that the inheritance gate verifies against. |
| `Challenges/` | `git@github.com:vasic-digital/Challenges.git` | pinned SHA | Shared anti-bluff challenge scripts and supporting assets. |

Notes:

- **There is no release tag upstream for the constitution.** It is pinned to a
  specific commit SHA (`6445733e`) on the `main` branch — there is no `vX.Y.Z`
  tag to track. Updating means moving the pin to a newer commit (see
  [Updating a submodule](#updating-a-submodule)).
- The parent `CLAUDE.md`, `AGENTS.md`, and `CONSTITUTION.md` at the repo root
  carry inheritance pointers into `constitution/`. Authority order is
  `Constitution.md` > `CLAUDE.md` > `AGENTS.md` (see the root `CLAUDE.md`).

## Cloning with submodules

Clone and check out submodules in one step:

```bash
git clone --recursive git@github.com:<owner>/<repo>.git
```

`--recursive` (equivalently `--recurse-submodules`) checks out both
`constitution/` and `Challenges/` at their pinned SHAs as part of the clone.

## Recovering an already-cloned repo

If the repo was cloned **without** `--recursive`, the submodule directories
exist as empty stubs and the inheritance gate will fail. Populate them with:

```bash
git submodule update --init --recursive
```

This is idempotent — running it when the submodules are already present is
harmless. Run it again any time `git status` shows a submodule as modified to
unexpected content or after a `git pull` that moved a submodule pin.

## How `./init` self-heals

You usually do not need to run the submodule command by hand. `./init` detects
a missing checkout and repairs it automatically. From `init` (around line 80):

```bash
if git rev-parse --git-dir >/dev/null 2>&1; then
    if [ ! -f constitution/Constitution.md ]; then
        echo "Initializing git submodules (constitution, Challenges)..."
        if git submodule update --init --recursive; then
            echo "✓ Submodules initialized"
        else
            echo "WARNING: submodule init failed — run manually:"
            echo "  git submodule update --init --recursive"
        fi
    else
        echo "✓ Git submodules already initialized"
    fi
fi
```

The probe is the presence of `constitution/Constitution.md`. If that file is
absent, `./init` runs `git submodule update --init --recursive` for you and
reports the result; if the file is present it confirms the submodules are
already initialized and moves on. If the automatic init fails (for example, no
SSH access to the upstreams), `./init` prints the exact manual command to run
rather than failing silently.

## How to verify

Confirm both submodules are checked out at the expected SHAs:

```bash
git submodule status
```

Expected (the leading character is blank for a clean checkout; `-` means not
initialized, `+` means the checkout differs from the pinned SHA):

```
 6445733e20c0ceaa6d68fa43de6ef5e093a2a06d constitution (heads/main)
 f85bf3501a6118c41456a54878d82cb8ea868cd4 Challenges  (...)
```

Then run the inheritance gate, which is the real source of truth — it asserts
7 invariants and is paired with a mutation proof:

```bash
bash ./tests/test-constitution-inheritance.sh        # 7 invariants
bash ./tests/meta-test-constitution-inheritance.sh   # mutation proof of the gate
```

The same gate also runs as part of the normal suites:

```bash
./tests/run-tests.sh -p unit       # invokes run_constitution_tests
./tests/run-tests.sh               # all phases — also invokes run_constitution_tests
make dev-check                     # Gate 5c runs test-constitution-inheritance.sh
```

## Updating a submodule

To move the constitution pin to a newer upstream commit:

```bash
cd constitution
git fetch origin
git checkout <new-sha>      # or: git pull origin main  (then note the resulting SHA)
cd ..
git add constitution
git commit -m "chore: bump constitution submodule to <new-sha>"
```

The same procedure applies to `Challenges/`. After bumping, re-run the
verification steps above — a newer constitution commit can change the upstream
templates the inheritance gate checks against, so the gate must still pass
before you commit the new pin. Because there is no upstream release tag, always
record the resulting SHA in the commit message.

## Troubleshooting

**`constitution/Constitution.md: No such file or directory`** (or the
inheritance gate / Gate 5c failing with the constitution dir empty)

The `constitution/` submodule has not been initialized. Fix it with either:

```bash
git submodule update --init --recursive
# or simply:
./init
```

Then re-run `bash ./tests/test-constitution-inheritance.sh` to confirm.

**`git submodule status` shows a leading `-` next to a submodule**

Not initialized — same fix as above.

**`git submodule status` shows a leading `+` next to a submodule**

The checked-out commit differs from the pinned SHA (someone moved it, or a
local edit changed it). To return to the pinned commit:

```bash
git submodule update --recursive
```

If you intended to update the pin, see [Updating a submodule](#updating-a-submodule)
instead and commit the new SHA.

**Automatic init failed during `./init` (e.g. SSH/permission error)**

`./init` cannot reach the upstreams. Verify your SSH access to
`github.com:HelixDevelopment/HelixConstitution.git` and
`github.com:vasic-digital/Challenges.git`, then run
`git submodule update --init --recursive` manually.
