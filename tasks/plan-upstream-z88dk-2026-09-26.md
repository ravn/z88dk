# z88dk upstream submission plan

_Prepared 2026-09-26. Mirrors the llvm-z80 upstream exercise (llvm-z80/llvm-z80 PRs #54-#63)._

## Repository state

| | SHA | Note |
|---|---|---|
| upstream/master | `56e3fb02a7` | Latest: 80cc-dec-fixes PR #3124 |
| origin/master | `c696fac3ec` | Our fork baseline |
| Current branch | `fix/zcc-revert-split-quad-flag` (`0ff6da0d9e`) | 7 commits ahead of origin/master |
| Merge-base | `d96cb77a3d` | Fork divergence point |
| Commits ahead | 221 total (non-merge) since merge-base | All local, none cherry-picked upstream |

The `fix/zcc-revert-split-quad-flag` branch (7 commits) must be merged into
`origin/master` before any upstream branching starts (Phase 0).

What is already upstream:
- `62641e9d25` (cpm: keep BSS out of .COM) — upstream PR #3009 merged only the
  testcase (`c7a5f73a2a`), not the fix. Fix is still local-only.
- `4720883486` (`__preserves_regs` no-op) — upstream has a different
  implementation for llvm19+sdcc (`ff697a4608`). Our version still local-only.
  See open question below.

All 16 candidate commits across Groups 1-3 confirmed LOCAL ONLY (ancestry check run
against upstream/master 2026-09-26).

---

## Phase 0 — Consolidate local tip (prerequisite, no upstream action)

Merge `fix/zcc-revert-split-quad-flag` -> `origin/master`.

The 7 commits (`d773d36de2` .. `0ff6da0d9e`) add direct `.asm` output from Clang,
drop `bridge_postproc.sh` and deprecate `LLVMZ80RULES`/`LLVMZ80POSTPROC`. These are
the current local tip and must land in master before upstreaming starts.

---

## Group 1 — Generic z88dk fixes (9 commits) — ravn/z88dk#64

No llvmz80 dependency. Low friction. One PR per fix.

| # | Commit | Title |
|---|---|---|
| 1a | `4658ca9c4a` | classic stdio: parse fopen mode `+`/`b` in any order |
| 1b | `79fc0d4646` | stdbool.h: don't redeclare bool/true/false under C23 |
| 1c | `fad6c14c85` | float.h: Use compiler IEEE-754 builtins when available |
| 1d | `0a1720f55c` | INFINITY/HUGE_VAL/NAN for clang backends (depends on 1c) |
| 1e | `fc4f5263a5` | test/suites/stdio: add missing `<string.h>` to scanf.c |
| 1f | `62641e9d25` | cpm: keep uninitialised BSS out of the .COM image (upstream #3008 fix) |
| 1g | `1a18b0b283` | appmake: make NO_GMP opt-in instead of hardcoded |
| 1h | `89fb583fa8` | zpragma -autoformat: suppress note when explicit pragma used |
| 1i | `c49e619e02` | zpragma -autoformat: diagnose non-literal printf/scanf format strings |

Upstream branches (each off upstream/master):

    upstream-z88dk-fopen-mode          (1a)
    upstream-z88dk-stdbool-c23         (1b)
    upstream-z88dk-float-ieee          (1c + 1d paired — 1d depends on 1c)
    upstream-z88dk-stdio-test-string-h (1e — trivial, may skip issue)
    upstream-z88dk-cpm-bss-fix         (1f — closes upstream #3008)
    upstream-z88dk-no-gmp-opt-in       (1g)
    upstream-z88dk-zpragma-autoformat  (1h + 1i paired)

Submission order: 1e (trivial) -> 1f (issue already open) -> 1a -> 1b ->
1c+1d -> 1g -> 1h+1i.

---

## Group 2 — zsdcc patches (4 commits) — ravn/z88dk#65

Three generic bugs go to SDCC upstream first, then z88dk. Peephole fix direct.

| # | Commit | Title | Target |
|---|---|---|---|
| 2a | `baae15ffc8` | zsdcc: fix `(uint16_t)X>>8` sign-extension | SDCC upstream -> z88dk |
| 2b | `57a9a8f250` | sdcc: preserve REGPARM across K&R parameter type merge | SDCC upstream -> z88dk |
| 2c | `d962a34fe3` | sdcc: fix 'Mac OS X ppc' banner on Apple Silicon | SDCC upstream -> z88dk |
| 2d | `ef747c325e` | sdcc_peeph: remove orphan jp after ret/jp | z88dk direct |

Order:
1. File 3 bugs at SDCC upstream (SourceForge). Reproducers are in `src/zsdcc/tests/`.
2. File z88dk PR for `2d` (independent peephole fix).
3. Reference SDCC ticket numbers in z88dk PRs for 2a/2b/2c when opened.

---

## Group 3 — ez80-clang fixes (3 commits) — ravn/z88dk#66

Natural extension of the existing upstream ez80-clang track.

| # | Commit | Title | Note |
|---|---|---|---|
| 3a | `4720883486` | clang: define `__preserves_regs(...)` as no-op | See open question |
| 3b | `d24e19d1e8` | clang_rules.1: translate CEdev v15.0 ez80-clang GNU-as output | Standalone |
| 3c | `2764dd857e` | zcc: fix ez80-clang db-string control-byte corruption | Bug fix |

Upstream branches:

    upstream-z88dk-ez80-preserves-regs  (3a — pending open question decision)
    upstream-z88dk-ez80-cdev-v15        (3b)
    upstream-z88dk-ez80-dbstring        (3c)

---

## Group 4 — RC700 platform — ravn/z88dk#68

Upstream issue z88dk/z88dk#3011 is open and assigned to ravn.

Commits (cherry-pick only RC700-specific files — platform/rc700/, appmake/, cpmdisk/):

- `b0e6e7183c`, `edb789e22d` — appmake RC700 disk formats (5"/8" DD, mixed-density Track 0)
- `02e785ed61` et al. — RC700 target: clock(), rs232, i8275 CRTC
- `9f0af60acc` — cpmdisk: RC-700/703 data-disk formats
- RC700 README + wiki documentation

Upstream branch: `upstream-z88dk-rc700-platform` (closes #3011)

Note: RC700 commits are interleaved with llvmz80 commits in the log.
Cherry-pick must be selective — only RC700-specific files.

---

## Group 5 — `-compiler=llvmz80` integration — ravn/z88dk#67

RFC-gated. No PR before maintainer go-ahead.

Current state: RFC issue z88dk/z88dk#3033 is open (7 comments). Last ravn
comment Aug 12, 2026: "I now have this working well with classic." No maintainer
response since. suborb confirmed Jul 25: focus on classic.

Known remaining issue: `runtime_intdiv.sh` at -O2 (___divmodsi4 assertion) is
the single FAIL in the test matrix. Should be resolved before submitting.

Actions:
1. Ping z88dk/z88dk#3033 with a status update: Groups 1-4 submitted as
   prerequisites; implementation complete; ready when maintainers are.
2. Wait for maintainer response before preparing any branch.
3. On go-ahead: cherry-pick full llvmz80 integration onto upstream/master as
   `upstream-z88dk-llvmz80`.

---

## Submission order / dependency graph

    Phase 0: merge fix/zcc-revert-split-quad-flag -> origin/master
        |
        v
    Group 1 (generic fixes)  ---+
    Group 2d (sdcc peephole) ---+-- parallel
    Group 3 (ez80-clang)     ---+
    Group 4 (RC700)          ---+
        |
        v  (after SDCC tickets filed)
    Group 2a/b/c (zsdcc — reference SDCC ticket numbers)
        |
        v  (after maintainer go-ahead on #3033)
    Group 5 (llvmz80 integration)

---

## Baseline branch

After all Group 1-4 branches are pushed (before PRs are accepted), create:

    test-combined-upstream-z88dk

= cherry-pick of all Group 1-4 commits onto upstream/master in dependency order.

Purpose: integration test — build z88dk from this branch and run full suite to
confirm no regressions before declaring the batch ready.

---

## Process per PR (same as llvm-z80 exercise)

1. File upstream issue at z88dk/z88dk (if none exists)
2. Create branch off upstream/master with cherry-picked commits
3. Push branch to origin (ravn/z88dk)
4. Open PR at z88dk/z88dk with `Fixes #N` in body
5. Update local tracking issues (ravn/z88dk#64-68) with the issue/PR mapping

---

## Open question — requires decision before Group 3 starts

**`__preserves_regs` (commit `4720883486`):**

Upstream has their own `__preserves_regs` for llvm19+sdcc (`ff697a4608`).
Our version makes it a no-op for llvmz80 specifically.

Options:
- A. Submit our version anyway — different target path, non-conflicting
- B. Skip upstream — not worth friction, upstream version covers the header include
- C. Check whether upstream's version already covers our use case first

Recommendation: C (verify before deciding).
