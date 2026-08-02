# z88dk × llvmz80 (classic clib) — resume note 2026-08-02

Context: making clang-z80 (`ravn/llvm-z80`) a first-class external z88dk backend on
the **classic** clib path. Work is driven by z88dk's upstream `test/suites`,
parametrized `make COMPILER=llvmz80`. Failures were bucketed into **Group A**
(compile/link) and **Group B** (runtime hang / "in setup").

## Environment (set for every build/run)
```
export PATH=/Users/ravn/z80/z88dk/bin:$PATH \
       ZCCCFG=/Users/ravn/z80/z88dk/lib/config/ \
       LLVMZ80EXE=/Users/ravn/z80/llvm-z80/build-macos/bin/clang \
       NTVCM=/Users/ravn/z80/ntvcm/ntvcm
```
- Native clang: `/Users/ravn/z80/llvm-z80/build-macos/bin/clang` (rebuild
  `ninja -C build-macos clang`, ~8s incremental; `ninja -C build-macos llc`).
- ntvcm: `/Users/ravn/z80/ntvcm/ntvcm`; bounded run `ntvcm -m:80 x.com`
  (80 = 80M cycles). macOS has **no `timeout`** — use ntvcm's `-m:` instead.
- Quick app build: `zcc +cpm -compiler=llvmz80 f.c -o f -create-app` → `f.com`.
- Suite compile+link WITHOUT the 30s runtime watchdog:
  `cd test/suites/<suite> && make COMPILER=llvmz80 test.bin`. The make's final RUN
  step hits a 30s watchdog and returns Error 1 EVEN WHEN compile+link succeeded —
  so a Group-A pass = **`test.bin` exists**, not make exit code.
- HARD RULE: never search/traverse outside `/Users/ravn/z80/`.

## GROUP A — DONE (6/6 items, all runtime-verified where correctness could be silent)

### Backend fix (llvm-z80) — the qsort/bsearch blocker
- **`Z80RemoveJumpToNext.cpp`**: this pass ran AFTER BranchRelaxation and did
  `removeBranch()+insertBranch()`; `Z80InstrInfo::insertBranch` re-materializes
  conditionals in SHORT `JR_cc` form, so a range-widened `JP_C_nn` got clobbered
  back to an out-of-range `jr c` (qsort.c: `integer range: -$ac` = -172). Fix:
  in the "conditional + trailing unconditional-to-fall-through" branch, erase
  ONLY the trailing unconditional terminator (`getLastNonDebugInstr()` →
  `eraseFromParent()` iff `isUnconditionalBranch()`), never remove+reinsert.
  Preserves the conditional opcode (JP stays JP).
- Lit test updated: `llvm/test/CodeGen/Z80/remove-jump-to-next.mir`
  (`cond_then_fallthrough` now asserts `JP_C_nn %bb.2` preserved + `CHECK-NOT: JR_C_e`).
  Full Z80 lit suite: 209 pass / 5 XFAIL / 0 unexpected.
- Bug writeup: `/Users/ravn/z80/llvm-z80/tasks/bug-2026-08-02-remove-jump-to-next-narrows-jp-cc.md`.
- **General lesson:** any Z80 MI peephole after BranchRelaxation MUST preserve the
  chosen branch opcode via surgical `eraseFromParent`, never remove+reinsert
  (insertBranch always emits short JR).
- The pass was AI-authored; **hbf (`Z80HighByteFirstBranch.cpp`) is NOT the bug** and
  is pristine — do not re-touch it for this.

### z88dk-side Group A fixes (all GREEN)
1. **qsort/bsearch** — comparators MUST be `__smallc` (= sdcccall(0) for clang; no-op
   for sccz80/sdcc) because classic qsort/bsearch call the comparator via a
   stack-marshalling thunk. `stdlib.h` qsort/bsearch MUST stay reversing **macros**
   (a real C `qsort` symbol collides with lib `_qsort` → infinite recursion). Files:
   `include/stdlib.h` (kept macros), `test/suites/stdlib/{qsort,bsearch}.c`.
   Runtime oracles: `test/clang/runtime_qsort.sh`, `runtime_bsearch.sh`.
2. **strnchr/strncat/stricmp** — `include/string.h` (strnchr `#elif __LLVMZ80`
   forwarder; strncat return `char *`), `test/suites/string/stricmp.c`
   (func-ptr convention guard).
3. **`___mulsi3` (fixedbench)** — bridge `libsrc/l/llvmz80/__mulsi3.asm` → core
   `l_mulu_32_32x32` (low 32 bits identical signed/unsigned). Registered in
   `libsrc/l/llvmz80.lst`. Runtime oracle `test/clang/runtime_mulsi3.{c,sh}` PASS.
4. **`___memmove_rt` (md5)** — clang `Z80LegalizerInfo.cpp` lowers unknown-direction
   `memmove` to a `Z80_AllReg` helper `__memmove_rt` (dst=HL, src=DE, size=BC, no
   frame, nothing callee-saved). New bridge `libsrc/l/llvmz80/__memmove_rt.asm` →
   `asm_memmove` (one `ex de,hl` + tail `jp`), in `llvmz80.lst`. Oracle
   `test/clang/runtime_memmove_rt.{c,sh}` (fwd/bwd overlap + non-overlap) PASS.
5. **`sbrk` (regex)** — TEST-SOURCE bug, not a compiler bug: `regex.c:66` passed int
   `50000` to a `void*` param → clang `-Wint-conversion` hard error. Fixed to
   `sbrk((void *)50000, 10000);` unconditionally (portable cast).
6. **`sbrk_far` (far)** — far pointers unsupported by llvmz80. `test/suites/Makefile`
   excludes `far` from `SUBDIRS` for `COMPILER=llvmz80`; `test/suites/far/Makefile`
   also prints `SKIP:`+exit 0 under llvmz80. sccz80 still builds/passes.

### CRITICAL build mechanic (bit us on __mulsi3)
`libsrc/classic/z80_crt0s/Makefile` uses **stamp files** (`obj/z80-crt0`); a plain
`make TARGETS=z80` says "Nothing to be done" and does NOT pick up a new
`l/llvmz80.lst` entry. To rebuild bridge objects into the clib:
```
cd libsrc/classic/z80_crt0s && rm -f obj/z80-crt0 && make
cd ../..                     && rm -f z80_crt0.lib && make z80_crt0.lib
```
Then verify + sync the installed lib zcc actually links:
```
z88dk-z80nm libsrc/z80_crt0.lib | grep ___SYMBOL
cp lib/clibs/z80_crt0.lib lib/clibs/z80_crt0.lib.bak.$(date +%s)   # backup
cp libsrc/z80_crt0.lib lib/clibs/z80_crt0.lib                       # sync
```
(`lib/clibs/z80_crt0.lib` can go stale vs the build-tree copy.)

### Bridge ABI cheat-sheet (clang compiler-rt ↔ z88dk cores)
- clang 32-bit ABI: one operand in HL:DE (HL=hi, DE=lo); other pushed on stack (lo
  word then hi, caller-cleaned); IX=frame ptr (preserve); result in HL:DE.
- z88dk cores use DE:HL (DE=hi), compute `dehl OP dehl'` (main × alt bank), TRASH IX.
  One `ex de,hl` converts each way. Pattern reference: `libsrc/l/llvmz80/__divsi3.asm`.
- Verify clang's mangled symbol name with `clang --target=z80 -S` before choosing the
  asm `PUBLIC` (compiler-rt helpers get 3 leading underscores, e.g. `___mulsi3`).

## GROUP B — NOT FIXED. Root cause now EVIDENCED (was previously a guess). Plan below.

### Evidence (2026-08-02 probes, llvmz80 classic, ntvcm)
- P1 `printf` → **WORKS** (`HELLO_PRINTF`).
- P3 indirect call via `void(*)(void)` function pointer → **WORKS** (`PTR_CALLED`).
- **P2 setjmp/longjmp → BROKEN.** Program:
  ```c
  if (setjmp(jb)==0){ printf("A_SETJMP0\n"); stage=1; longjmp(jb,1); }
  else               { printf("B_AFTER_LONGJMP stage=%d\n",stage); }
  printf("C_DONE\n");
  ```
  Expected: `A_SETJMP0` / `B_AFTER_LONGJMP stage=1` / `C_DONE`.
  Actual:   `B_AFTER_LONGJMP stage=0` / `C_DONE`.
  → `setjmp()` returns **non-zero on its initial direct call**, so the `==0` branch
  is skipped entirely (no A, stage never set, longjmp never runs).

### Why this is the shared Group-B root cause
`test/framework/test.c:54` runs every test as `if (setjmp(jmpbuf)==0){ setup; test; }
else { ...print "(in setup) failed"... }`. If setjmp returns non-zero on the direct
call, EVERY test immediately falls into the failure path → the "(in setup)" symptom
across ~all Group-B suites. printf and function pointers are fine, so setjmp is the
single shared breakage.

### Most-likely mechanism (hypothesis, NOT yet confirmed at asm level)
Same **HL↔DE 16-bit return-register mismatch** class already documented in CLAUDE.md
for variadic stdio: z88dk classic `setjmp` returns its value in one register, clang
`sdcccall(1)` reads another → clang sees garbage ≠ 0. Alternative: `jmp_buf`
layout/frame mismatch. Must be confirmed in trin 1 before any fix.

### PLAN (report-first discipline: do NOT fix without confirming trin 1)
- **Trin 0 — baseline.** Run all ~18 Group-B suites, log each as "(in setup)" / HALT
  / other. Record the fail-set for later delta.
- **Trin 1 — confirm root cause.** Disassemble classic `setjmp`/`longjmp`
  (`libsrc/.../setjmp`) → which register holds the return value. `clang --target=z80
  -S` on P2 → which register clang reads. Confirm HL-vs-DE (or jmp_buf-layout)
  mismatch and decide which side is wrong.
- **Trin 2 — fix on the right layer (prefer classic-clib, avoid backend).**
  If pure return-register mismatch: add a `__LLVMZ80`-guarded setjmp/longjmp
  decl/bridge (pattern like the variadic-stdio fix in `include/sys/compiler.h`, or an
  HL/DE adapter in `libsrc/l/llvmz80/`). Only touch the backend if trin 1 proves clang
  itself emits a wrong setjmp call.
- **Trin 3 — oracle (test-before-fix).** `test/clang/runtime_setjmp.{c,sh}` asserting
  `A_SETJMP0 / stage=1 / B / C`; confirm it FAILS now, PASSES after fix. Add a lit test
  if the fix touches the backend.
- **Trin 4 — re-run all Group B** vs baseline; expect most "(in setup)" suites to go
  green from the one fix. Treat any residual HALT/hangs as separate smaller cases.
- **Risks:** some HALT-at-30s suites may have a distinct cause (not setjmp) — trin 4
  reveals them. Keep blast radius on classic clib, not backend, if possible.

## Constraints (standing)
- Do NOT push/PR or rewrite git history unless explicitly asked. Changes currently
  UNCOMMITTED (Group A) — left for user review.
- `stdlib.h` qsort/bsearch MUST stay macros. Do NOT re-touch hbf. Every new bridge
  MUST be runtime-verified under ntvcm (a wrong asm silently corrupts math).
- `store_memory` is unavailable for this repo → durable notes live in-project
  (this file; backend bug writeup under `llvm-z80/tasks/`).
