# target_io suite under -compiler=llvmz80 — thorough investigation + plan (2026-08-03)

Step-back re-investigation requested by user ("træd tilbage på target_io og
undersøg grundigt og lav så en plan"). No fix implemented here — this is the plan.

## Reproduction / environment
```
export PATH=/Users/ravn/z80/z88dk/bin:$PATH
export ZCCCFG=/Users/ravn/z80/z88dk/lib/config
export LLVMZ80EXE=/Users/ravn/z80/llvm-z80/build-macos/bin/clang
cd test/suites/target_io
make COMPILER={llvmz80,sdcc,sccz80} test_cpm_z80.com
```
Suite = serial (printf/sscanf/scanf) + CP/M disk (creat/write/close/read/lseek/
multi/fopen), 8 tests, run under z88dk-ticks in `+cpm` `.com` mode.

## Verified findings (each observed, not inferred)

1. **The recipe is RED for ALL compilers — a harness/exit-code bug, not a
   compiler bug.** `make COMPILER=sccz80 test_cpm_z80.com` runs the suite to
   `8 run, 8 passed, 0 failed` (all four files a.dat/b.dat/fopen.dat/suite.dat
   created) yet the make target STILL fails with "cpm/z80 target_io failure /
   Error 1". Cause: z88dk-ticks returns process exit code 1 for a `+cpm` program
   that terminates via CP/M warm-boot (jp 0), regardless of the suite result, and
   the recipe's `... | $(MACHINE) $@ || { echo failure; exit 1; }` trusts that
   exit code. The other suites (string/math/md5) are green only because they use
   the `+test -b msx` `runtest` path, which halts cleanly (ticks exit 0). This is
   why target_io never shows green even where the test content passes.

2. **Content correctness under the native compiler is fine.** sccz80 = 8/8 pass.
   So the suite itself and the ticks `+cpm` BDOS disk emulation both work; the
   disk path is fully exercised.

3. **sdcc completes only 4/8** here: creat/write/close passes (suite.dat, 128 B
   extent-padded, is created) but tests 5-8 (read-back/lseek/multi/fopen) do not
   complete — only suite.dat exists afterwards. Separate sdcc-side issue, not in
   scope for the llvmz80 goal; noted for honesty (target_io disk tests are not a
   clean pass under sdcc in this ticks setup).

4. **llvmz80 has two REAL content failures on the disk tests** (independent of
   finding 1):
   a. **open() regression** from the recent md5sum `include/fcntl.h` `__LLVMZ80`
      fix (commit e8612ac2e4). That fix declares reversed-arg `__smallc`
      open/read/write entries and is correct for the `+test` host-SYSCALL STACK
      workers (libsrc/target/test/fcntl/*.asm), but it is gated only on
      `__LLVMZ80`, so it ALSO rewrites the call ABI for the `+cpm` classic-clib
      workers (libsrc/target/cpm/fcntl/*.c, compiled sccz80-ABI) where it is
      wrong -> `open()` returns fd<0 (io_tests.c:88). VERIFIED by header A/B swap:
      the pre-fix (default `__ZPROTO3`) header makes +cpm open() work; the current
      header regresses it.
      FIX-DIRECTION VERIFIED: gating the fcntl.h `__LLVMZ80` branches to
      `#if defined(__LLVMZ80) && !defined(__CPM)` keeps md5 (+test) GREEN and
      un-regresses +cpm open() — the failure then moves from :88 (open) to :92
      (read length). `__CPM` is defined under `+cpm` and not under `+test`
      (confirmed via emitted-asm marker), so it is a valid discriminator.
   b. **write()/read() wrong counts** = the HL-vs-DE return-register + arg ABI
      mismatch of the sccz80-built `cpm_clib` called from clang. Already filed as
      OPEN issue ravn/z88dk#23 ("CP/M clib returns int in HL but clang reads DE"),
      umbrella ravn/z88dk#26 (complete register-ABI clang bridges). This is the
      deep half and is NOT header-only fixable.

## Plan (ordered; do NOT bundle — Step 3 needs a go-ahead per explain-before-filing)

- **Step 1 — harness fix (compiler-independent, safe, high value).** Change the
  target_io `+cpm` recipes so a passing suite is green: instead of trusting
  ticks' process exit code, capture stdout and pass iff it contains
  "0 failed" and not "XPASS". This makes sccz80 8/8 GREEN immediately and gives a
  truthful gate for every compiler. No compiler/library change. (Same style as
  parsing the suite summary line the other suites already print.)

- **Step 2 — llvmz80 open() regression fix (small, recommended regardless).**
  Gate the `include/fcntl.h` `__LLVMZ80` open/read/write branch to
  `!defined(__CPM)` so the md5sum (+test) fix is preserved but stops corrupting
  the +cpm open() path. Re-verify: md5 suite GREEN, +cpm open() works (regression
  cleared). Add/extend a runtime oracle. This repairs a regression the md5sum fix
  introduced into the +cpm path.

- **Step 3 — residual +cpm return-ABI (deep, coupled to #23/#26; needs
  go-ahead).** The remaining +cpm write/read wrong-count failures require the
  classic cpm_clib register-ABI bridges (HL->DE return + reversed-arg stack
  entries) for open/creat/close/read/write/lseek. Large; already filed as #23/#26.
  Until that lands, mark the +cpm disk tests XFAIL under `__LLVMZ80` (using the
  XFAIL framework already added to test/framework/test.{c,h}), referencing #23 —
  mirroring the math32 pow/fmod XFAIL approach — so the suite is
  green-with-known-gaps rather than a false green.

## Recommendation
Do Step 1 + Step 2 now (both safe / un-regressing), then Step 3-lite (XFAIL the
residual disk tests under llvmz80, ref #23). That yields a truthful green target_io
under llvmz80 without touching the deep cpm_clib ABI and without hiding real gaps.
Hold the full #23/#26 bridge work for a dedicated go-ahead. Do NOT file a new issue
for the +cpm fd-layer — it is already #23.

## Constraints any fix must respect
- md5 suite (+test) must stay GREEN (it depends on the fcntl.h fix).
- committed `include/fcntl.h` must not be left modified without re-verifying md5.
- No push / no PR unless asked; commit locally with the Co-authored-by trailer.
