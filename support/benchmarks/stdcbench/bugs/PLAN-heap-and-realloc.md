# Plan: make full stdcbench (c90base + c90lib) work under llvmz80, incl. heap + realloc/free

Status date: 2026-08-04. Author: Copilot (AI), for @ravn.

## Goal (user directive)

"Alt skal virke med llvmz80" for the WHOLE stdcbench program set, explicitly
INCLUDING dynamic memory: `malloc`, `calloc`, `realloc`, and `free`. Other
compilers' issues are out of scope.

## What is already fixed this session (verified)

1. **z80asm `.asciz` overflow** (c90lib-peep.c) — FIXED in
   `z88dk/lib/llvmz80/splitascii.pl` (now splits `.asciz` too, preserving the
   single trailing NUL). c90lib-peep.c assembles clean. Byte-verified split
   (48+48+34 = 130 bytes -> DEFM×3 + one DEFB 0x00).
2. **clang `-O2` segfault** (c90lib-lnlc.c) — FIXED in
   `llvm-z80/llvm/lib/Transforms/AggressiveInstCombine/TruncInstCombine.cpp`.
   Root cause: use-after-free in the fork's synthetic `(and X, MASK)` trunc-root
   injection when X's def-use chain CYCLES back through that same `and` (i16
   induction recurrence `p = (p & 0xff) + 1`). getBestTruncatedType records the
   `and` in InstInfoMap; injection erased it BEFORE ReduceExpressionGraph, which
   then dereferenced the freed pointer. Fix bails when `InstInfoMap.count(And)`.
   Lit test `trunc-narrow-and-mask-root-cycle.ll` added; Z80 codegen suite green
   (209 pass + 5 XFAIL); full AggressiveInstCombine suite 46/46.

## The remaining blocker: dynamic memory (this plan)

### Symptom (verified, reproducible)

Linking the full module set (`MODULES=all`) fails on every lane with
`undefined symbol: _heap` (from malloc-classic calloc/free/malloc/realloc).
c90lib uses `malloc/calloc/realloc/free` (via `<stdlib.h>` -> `<malloc.h>`);
the benchmark port never sets up a heap (c90base needed none).

With `-DAMALLOC` (CRT auto-heap) the link succeeds and, via `<stdlib.h>`:
- `malloc`  -> works (non-null)
- `calloc`  -> works AND zero-initialised (verified `calloc_zero=1`)
- `free`    -> works (reaches program end)
- `realloc` -> **BROKEN**: loses the old contents (`a=0xff`,
  `REALLOC_LOSTDATA`), and the program then HANGS at exit (very likely heap
  metadata corrupted by the mis-executed realloc).

### Known facts (verified from source / probes)

- `__STDC_ABI_ONLY` is NOT defined for `+cpm -compiler=llvmz80` -> the
  `#ifndef __STDC_ABI_ONLY` branch of `include/malloc.h` is active, i.e.
  `#define realloc(a,b) realloc_callee(a,b)` with
  `realloc_callee(...) __smallc __z88dk_callee` (sdcccall(0)+callee, a form
  clang honours). So the *declaration* looks ABI-correct, yet data is lost.
- `include/malloc.h` already carries an `__LLVMZ80` fix that routed
  `malloc`/`free`/`calloc` to the register-ABI (`*_fastcall` / `*_callee`)
  entries; **`realloc` was never given the same treatment** — it is the one
  alloc call still misbehaving.
- The classic `malloc-classic` library routes malloc/calloc/realloc/free/
  malloc_fastcall/mallinit/sbrk all through a SINGLE `_heap`, so one heap set-up
  serves everything (no two-heap split once routing is consistent).
- `heapinit()` macro is unusable as-is under llvmz80: it expands to
  `mallinit(); sbrk_callee(heap+4,a);` and `sbrk_callee` fails to declare on the
  path we hit (ABI-branch mismatch) -> "call to undeclared function".

### Root-cause hypotheses to confirm in Phase 1 (NOT yet proven)

H1 (most likely): `realloc_callee`'s `__smallc __z88dk_callee` 2-arg ABI is not
   actually lowered correctly by clang here (wrong arg order/stack cleanup ->
   realloc gets a bogus old-ptr and/or size, allocates fresh, copies from the
   wrong address -> old data lost). This mirrors the documented malloc/free ABI
   bug that the header already worked around for the OTHER three calls.
H2: `realloc_callee` is ABI-fine but incompatible with the AMALLOC auto-heap
   specifically (heap header layout mismatch), while malloc/calloc/free happen
   to tolerate it.
H3: The exit hang is a SEPARATE defect (CP/M exit path) unmasked only when the
   heap is populated, not a downstream effect of the realloc corruption.

Confirm by: build a 1-call realloc repro, `zcc ... -S`/disassemble the call
site, inspect how (ptr,size) reach `realloc_callee`, and compare against a
known-good `calloc_callee` call (same `__smallc __z88dk_callee` shape). Also
test realloc under an EXPLICIT `_heap` (mallinit+sbrk) to separate H1 from H2.
For H3, test a malloc-only (no realloc) program under AMALLOC and see if it too
hangs at exit.

## Plan (phased)

### Phase 0 — Baseline + oracle (before any change)
- [x] Reproduce `_heap` link failure (done).
- [x] Reproduce realloc data-loss + exit hang via `<stdlib.h>` + AMALLOC (done:
      `bugs/` oracle `a=0xff REALLOC_LOSTDATA` + TIMEOUT).
- [ ] Commit a tiny standalone alloc oracle (`malloc+calloc+realloc+free`,
      content + zero-init + preserve-on-grow checks, prints an OK/FAIL line)
      under `z80-utils/test-runner/testcases/clang/` so realloc correctness is a
      CI-gated runtime fixture, not an ad-hoc probe.

### Phase 1 — Root-cause realloc (decide H1 vs H2 vs H3)
- [ ] Minimal realloc repro; disassemble the `realloc_callee` call under
      llvmz80; verify (ptr,size) passing vs the ABI the .asm expects.
- [ ] Repeat under an explicit `_heap` (see Phase 2 option B) to isolate
      heap-model from arg-ABI.
- [ ] malloc-only-under-AMALLOC exit test to classify the hang (H3).
- [ ] Write the verdict here (symptom vs proven cause, per AGENTS.md) before
      touching code.

### Phase 2 — Heap set-up (choose ONE consistent model)
Option A — CRT auto-heap (`-DAMALLOC` / `AMALLOC1|2|3` for 1/4,2/4,3/4 free):
  + zero source changes, CRT sizes the heap from free memory.
  - must confirm realloc shares the same `_heap` (H2). CP/M free memory is
    ample for the benchmark's allocations.
Option B — explicit heap: a fixed static buffer + `mallinit()` + `sbrk()` (the
  register-ABI `sbrk`, NOT the broken `heapinit()` macro), sized to the
  benchmark's worst-case (c90lib-lnlc mallocs
  `60 + n*(72+max_k/8*2) + (n-1)(n-2)/2*28`; bound n/max_k -> pick a safe fixed
  size, e.g. 16–24 KB, assert fits under BDOS).
  + fully deterministic, self-contained, no reliance on CRT free-mem probing.
Decision rule: prefer A if Phase 1 shows realloc shares `_heap` under AMALLOC;
  otherwise B. Put the chosen set-up in `portme.c`/`bench_main.c` behind
  `#ifdef __LLVMZ80` (or unconditionally if harmless to sdcc/sccz80), so the
  benchmark is self-initialising and the harness needs no per-lane hack.

### Phase 3 — Fix realloc ABI (if H1)
- [ ] Extend the existing `__LLVMZ80` block in `include/z88dk .../malloc.h`
      (and, if the benchmark path uses it, `stdlib.h`) to route `realloc` to the
      correct register-ABI entry exactly like malloc/free/calloc already are
      (e.g. a `realloc_fastcall`/correctly-lowered `realloc_callee`), so
      `realloc(p,n)` preserves contents. Add the layered comment + a worked
      value example (the `"hello"` grow-to-300 case).
- [ ] Re-run the Phase 0 oracle: `REALLOC_OK`, no hang.
- [ ] This is a z88dk header fix that benefits ALL llvmz80 CP/M programs, not
      just the benchmark — note it in `CALLING_CONVENTION.md`.

### Phase 4 — Fix exit hang (if H3 is independent)
- [ ] Root-cause the CP/M exit hang seen once the heap is populated; fix in the
      CRT/exit path or benchmark teardown. Gate "done" on a clean program exit
      under ntvcm (process terminates, no timeout).

### Phase 5 — Enable c90lib on the llvmz80 lane end-to-end
- [ ] Remove `-DSTDCBENCH_DISABLE_C90LIB` for llvmz80; build `MODULES=all` verify
      (+cpm) and confirm `STDCBENCH OK` under ntvcm (c90base + c90lib), program
      exits cleanly.
- [ ] Build the +test benchmark lane; record `.COM` size + cycles for the full
      module set.

### Phase 6 — Harness + docs
- [ ] compare.sh: let the llvmz80 lane run `MODULES=all` (drop the llvmz80-only
      c90lib skip); keep other compilers as-is per stdcbench RULES.
- [ ] Update README.md "c90lib status" (now works on llvmz80) + the llvm-z80
      plan doc with full-module numbers and the realloc/heap fixes.
- [ ] Add the realloc oracle as a CI runtime fixture (Phase 0) + a lit test if
      any backend change was needed (none expected — this is header/ABI + CRT).

### Phase 7 — Commit (local only; DO NOT push / DO NOT file issues w/o go-ahead)
- [ ] z88dk: splitascii.pl (done, uncommitted), malloc.h/stdlib.h realloc fix,
      portme/bench_main heap set-up, compare.sh, README, oracle fixture.
- [ ] llvm-z80: TruncInstCombine fix + lit test + plan-doc update.
- [ ] Co-authored-by trailer on every commit.

## Definition of done
Full stdcbench (c90base + c90lib) builds under `+cpm -compiler=llvmz80`,
`malloc/calloc/realloc/free` all behave correctly (realloc preserves data),
the program prints `STDCBENCH OK` under ntvcm and EXITS cleanly, and the
harness records size+cycles for the full module set on the llvmz80 lane.
