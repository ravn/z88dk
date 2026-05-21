# zsdcc regression tests

Tests that exercise the ravn/z88dk-specific patches applied to upstream
SDCC in `../sdcc-*-z88dk.patch`.  Run via:

```
./run-all-tests.sh
```

or individually:

```
./test_macos_aarch64_banner.sh
./run_test_kr_regparm.sh
```

## Test inventory

| script | issue | what it covers |
|---|---|---|
| `test_macos_aarch64_banner.sh` | ravn/z88dk#15 | `--version` banner says "macOS aarch64", not "Mac OS X ppc" (cosmetic; skips on non-Darwin-arm64 hosts). |
| `run_test_kr_regparm.sh` | ravn/z88dk#5 + #14 (+ K&R correctness half of #6) | K&R-style function definition + ANSI prototype in another TU under `--sdcccall 1 + --nogcse` → must agree on register-args ABI.  Two-TU minimal repro derived from the AES-256 corpus deep-dive (session 73l). |

## How the tests skip vs fail

- All scripts return 0 on PASS and >0 on FAIL.
- Missing prerequisites (zcc, zsdcc, z88dk-ticks, wrong host platform) cause
  `SKIP` output and exit 0 — so the suite doesn't break on partial installs.

## What's NOT covered

- ravn/z88dk#6 size aspect (`-clib=sdcc_ix` is 33% larger than `sdcc_iy`):
  this is a code-quality concern, not a correctness regression; needs a
  size-comparison test rather than a behaviour test.  Deferred.
- Upstream SDCC's own regression suite at `src/sdcc-build/support/regression/`
  is unchanged.  These ravn-specific tests live alongside the patches so
  they ship with the fork.
