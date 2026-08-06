# ravn/z88dk#40 — root cause + plan: dynamic whole-TPA heap fails with `malloc() failed`

**Status:** root-caused, fix APPLIED and VERIFIED. Author: Copilot (AI), for @ravn,
2026-08-06.

Issue: https://github.com/ravn/z88dk/issues/40

The user's goal: under `+cpm -compiler=llvmz80` (ravn/llvm-z80 clang), have a
**fixed-size stack sitting just below BDOS**, and **below the stack a heap region
that malloc/free owns**, all sized **at runtime**. Issue #40 is the blocker: every
attempt to use a dynamic whole-TPA heap (`CRT_STACK_SIZE=N`, or `-DAMALLOC`) dies
with `malloc() failed`, while a FIXED BSS heap (`CLIB_MALLOC_HEAP_SIZE=24576`)
works. This doc corrects the issue's suspected cause and gives the plan.

--------------------------------------------------------------------------------

## 1. Symptom (verified, reproducible)

Full stdcbench, dynamic heap (either `-pragma-define CRT_STACK_SIZE=NNNN` or
`-DAMALLOC`), under ntvcm:

```
...
malloc() failed
malloc() failed
malloc() failed        (repeats, warm-boot loop / hang)
```

The NULL comes from `c90lib-lnlc.c:382` `malloc(772)` inside
`load_network_and_label_colours`. The same program with a FIXED BSS heap
(`#pragma define CLIB_MALLOC_HEAP_SIZE=24576`, current portme.h workaround)
prints `STDCBENCH OK / final score: 480`.

## 2. Issue #40's suspected cause is WRONG

The issue guesses a bogus ~200 KB arena / `__BSS_END_tail` miscomputation (heap
registered far too large, then failing). **Disproven.** An in-program free-list
dump (`extern unsigned int heap[]`; read `{size,next}` at the arena base) shows a
**clean ~26 KB block** (`size=26538`) correctly registered at `__BSS_END_tail`.
The registration arithmetic is fine. The "200 KB" was almost certainly a
`mallinfo` misread (mallinfo is separately broken and returns garbage here).

The geometry is also NOT the problem: a `CRT_STACK_SIZE` sweep from 8192 to 24576
all failed identically, even with the heap top at `$9efc` (24 KB of stack
headroom) — so it is not a stack/heap collision either.

## 3. Actual root cause (VERIFIED)

**A missing section in the classic CRT BSS ordering lets qsort's scratch variable
land on top of the dynamic heap's free-list header.**

Evidence chain (each step verified):

1. Bisected the corruption with the free-list dump: the arena header is intact
   (`size=26538`) right up to *inside* `calc_neighbour_degrees` (c90lib-lnlc.c),
   then corrupt (`size=1`) immediately **after the `qsort()` call** there. qsort
   inputs at that call: `n=6, size=1, base=$864c, all values equal (12)`.
2. Replacing that `qsort()` with an inline insertion sort → **dynamic heap PASSES
   (480)**. So qsort is the culprit, not malloc/free or the comparator ABI.
3. The corrupt value is exactly `1`. qsort writes `((size-1)&size)^size` (the
   lowest set bit of the element size; `=1` for `size=1`) to a 2-byte BSS scratch
   var **`__stdlib_quicksort_size_lsb`** (see
   `libsrc/stdlib/z80/sort/asm_quicksort.asm`, `SECTION bss_stdlib`).
4. Map file confirms the collision: with a dynamic heap,
   `__stdlib_quicksort_size_lsb == __BSS_END_tail == __bss_stdlib_head == $879E`.
   The dynamic heap registers its arena base at `__BSS_END_tail`
   (`crt_init_heap.inc`), so **the free-list header word IS
   `__stdlib_quicksort_size_lsb`**. Every qsort overwrites the header's `size`
   field with the size-lsb, malloc then walks a broken free list, finds no block
   big enough → `malloc() failed`.

Why it lands there: `lib/crt/classic/crt_section_bss.inc` (the classic BSS section
order) does **not** list `SECTION bss_stdlib`. The shared newlib sort core is
pulled into classic (`libsrc/classic/stdlib/qsort_core.asm` → the z80 `asm_quicksort.asm`),
and it emits `__stdlib_quicksort_size_lsb` into `bss_stdlib`. Unordered in
classic, the linker drops that section AT/AFTER the `BSS_END` marker — i.e. exactly
at `__BSS_END_tail`, the dynamic arena base. (Only the newlib CRT orders
`bss_stdlib`; classic never did.) As a bonus bug, being outside
`[__BSS_head .. __BSS_END_tail]`, the var is also **not zeroed** by
`crt_initialise_bss.inc`.

Why the FIXED heap was immune: its arena is `__autoheap`, a reserved array inside
the ordered `bss_crt` section — not at `__BSS_END_tail`. qsort's stray write lands
in unrelated slack there, never on the live free-list header.

## 4. The fix (VERIFIED, one line)

Add `bss_stdlib` to the classic BSS ordering so it sits *inside*
`[__BSS_head .. __BSS_END_tail]` (gets zeroed) and `__BSS_END_tail` moves above
it (no overlap with the arena).

`lib/crt/classic/crt_section_bss.inc`, after `SECTION bss_clib`:

```
	SECTION bss_stdlib
```

Verification after the change (rebuilt lib, ntvcm):

| model                                   | before fix        | after fix         |
| --------------------------------------- | ----------------- | ----------------- |
| dynamic `CRT_STACK_SIZE=NNNN`           | `malloc() failed` | **OK, score 480** |
| dynamic `-DAMALLOC`                     | `malloc() failed` | **OK, score 480** |
| fixed `CLIB_MALLOC_HEAP_SIZE=24576`     | OK, 480           | OK, 480 (no regr) |

Map after fix: `__stdlib_quicksort_size_lsb=$82BC` sits *below*
`__BSS_END_tail=$82BE` — the arena base is now clear.

Scope: this is a **z88dk classic-CRT library bug**, independent of the benchmark.
It affects ANY classic program that both (a) uses a dynamic CRT heap
(`CRT_STACK_SIZE`/`AMALLOC`) and (b) calls `qsort`. Not clang-specific in
principle, though clang/llvmz80 is where it was hit.

## 5. The runtime memory model the user wants — it already exists

The "fixed stack just below BDOS, heap below it, sized at runtime" design **is**
the existing `CRT_STACK_SIZE` model; it was only blocked by §3. How it works:

- `+cpm` sets **SP at runtime from word@6** (BDOS base), `cpm_crt0.asm`
  (`TAR__register_sp=-6`). So the stack top is always just under BDOS on whatever
  machine runs it — no hardcoding. **Stack grows downward** from there.
- With `CRT_STACK_SIZE=N`, the heap is registered as
  `[__BSS_END_tail .. SP − N]`; the top-of-memory `N` bytes are reserved for the
  stack. Layout: `[program][BSS][heap → … gap … ← stack][BDOS]`.
- Everything is computed at load time from word@6; nothing is baked into the
  binary. Correct on ntvcm (BDOS `$fefc`) and on real rcbios
  (BDOS `$CC06`, BIOS `$DA00` — `rc700-gensmedet/rcbios-in-c/bios.h`) alike.

So after the §4 fix, the user's desired model is simply: **build with
`CRT_STACK_SIZE=<reserve>`** (drop the fixed-heap `CLIB_MALLOC_HEAP_SIZE`
workaround). No new mechanism needed.

## 6. How big should the stack reserve be? — and how to determine it

**Is there a mechanism to set / measure the stack size?**

- **To SET it:** `#pragma define CRT_STACK_SIZE=N` — the only mechanism. The CRT
  (crt_init_heap.inc) computes at runtime `heap = [__BSS_END_tail .. SP−N]` and
  reserves the top `N` bytes for the stack. It is a **manual reserve number**,
  not auto-computed; nothing prevents the stack from growing past `N` into the
  heap, so `N` must exceed the real peak.
- **To MEASURE actual usage:** there is **no built-in** classic facility. The
  mechanism is **sentinel painting using the TRUE hardware SP**. Note `&local`
  does NOT give the hardware SP here — clang gives `main` a *static BSS frame*
  (`__sframe_main`), so a `&local` read returns a BSS address (~`$81xx`), far
  from SP. Read the real SP with a 3-instruction asm helper instead:
  ```
      SECTION code_clib
      PUBLIC _get_sp
  _get_sp:            ; unsigned int get_sp(void) -> SP in HL (sdcccall(1))
      ld   hl,2       ; +2 undoes this call's return address
      add  hl,sp
      ret
  ```
  Then paint `[SP−N+margin .. SP−margin]` (the reserve, above the heap top) with
  a sentinel, run the workload, and scan upward for the first overwritten word;
  `peak = SP0 − first_overwritten`.

**Measured peak (dynamic `CRT_STACK_SIZE=2048` model, full run, true SP):
708 B.** SP started at `$feb4` (main's frame is ~72 B below ntvcm word@6
`$fefc`); deepest reach `$fbf0`; heap top `~$f6b4`, so ~20 KB of clear air
between the deepest stack and the heap. Consistent with the earlier ~780 B
fixed-heap figure. (Ordinary functions DO use the hardware stack via an IX frame
pointer — `push ix / add ix,sp` — it is only `main` that gets a static frame.)

- **Recommendation: reserve 2 KB (`CRT_STACK_SIZE=2048`)** — ~2.9× the measured
  708 B peak, comfortable margin for deeper call chains / future code, still
  leaving 20+ KB of heap under a `$C000`-class BDOS.
- **Validate the reserve on the real ceiling, not just ntvcm.** ntvcm's BDOS is at
  `$fefc` (near top of 64 KB); real rcbios BDOS is `$CC06`, ~13 KB lower, so the
  usable TPA (and thus the heap) is smaller there. Confirm on MAME / real
  hardware, per AGENTS.md ("building is not behaving").

## 6a. Permanent regression guard (shipped in the benchmark)

`portme.c` now defines `stdcbench_heap_selfcheck()` (called at the top of `main`
in `bench_main.c`, prototype in `portme.h`; a no-op off `__LLVMZ80`). It malloc's,
qsort's an all-equal array of element size 1 (the exact corrupting shape from
`calc_neighbour_degrees`), then malloc's again; if the free-list header was
clobbered the second malloc returns NULL and it prints `HEAP SELFCHECK FAILED
(issue #40: bss_stdlib overlaps dynamic heap)` and exits, instead of failing deep
in a kernel with a bare `malloc() failed`. **Verified to fire:** removing
`SECTION bss_stdlib` from the CRT and rebuilding makes the guard print the FAILED
line at startup; restoring the fix makes it pass silently (`STDCBENCH OK / 480`).

## 7. Secondary correctness bug found (not the corruption cause)

stdcbench `src/portme.h` (~line 78) sets `STDCBENCH_CMP_CONV __smallc` under
`__LLVMZ80`. Per `include/sys/compiler.h`, an llvmz80 qsort comparator must be
**`__z88dk_callback`** (= `__attribute__((sdcccall(0)))`), NOT `__smallc`
(`__smallc` swaps operands / inverts the compare result). ravn/z88dk#33 ("classic
qsort: clang comparator ABI mismatch") is CLOSED with the header fix; portme.h was
just never updated to match. Fixing it also makes the
`-Wno-error=incompatible-function-pointer-types` build hack unnecessary (the
attribute then matches the `qsort` prototype). This is a real latent bug but it did
NOT cause the §1 `malloc() failed` (proven: with the corrected convention the
benchmark still corrupted until the §4 section fix).

--------------------------------------------------------------------------------

## Plan (phased)

### Phase 1 — Land the CRT fix (the real unblocker)  ✅ DONE
- [x] `lib/crt/classic/crt_section_bss.inc`: added `SECTION bss_stdlib` after
      `SECTION bss_input` / before `SECTION bss_string` (matching the newlib
      ordering in `lib/crt/newlib/clib_bss.inc`).
- [x] Regression-verify: dynamic `CRT_STACK_SIZE=2048` build PASSES
      (`STDCBENCH OK / final score: 480`); map confirms
      `__stdlib_quicksort_size_lsb=$82BC` now BELOW `__BSS_END_tail=$82BE`
      (no overlap).
- [x] Permanent regression guard shipped: `stdcbench_heap_selfcheck()` in
      `portme.c` (§6a). Verified it FIRES on the broken CRT (bss_stdlib removed →
      `HEAP SELFCHECK FAILED`) and passes silently once fixed.

### Phase 2 — Switch stdcbench to the runtime model  ✅ DONE
- [x] `support/benchmarks/stdcbench/src/portme.h`: replaced the fixed-heap
      `#pragma define CLIB_MALLOC_HEAP_SIZE=24576` workaround with the dynamic
      `#pragma define CRT_STACK_SIZE=2048` model (§6).
- [x] Fixed `STDCBENCH_CMP_CONV` `__smallc` → `__z88dk_callback` (§7). The full
      build is now clean with NO `-Wno-error=incompatible-function-pointer-types`
      hack (the comparator attribute matches the `qsort` prototype), and runs
      `STDCBENCH OK / 480`.

### Phase 3 — Validate on the real ceiling  (remaining)
- [ ] Confirm the `CRT_STACK_SIZE=2048` model boots and runs on MAME / real
      rcbios (BDOS `$CC06`), not just ntvcm — heap fits, stack does not collide.

### Phase 4 — Correct issue #40 upstream (needs go-ahead)
- [ ] Per AGENTS.md (`feedback_explain_before_filing`, symptom-vs-cause): post a
      corrected root-cause comment on ravn/z88dk#40 — the suspected ~200 KB
      arena / `__BSS_END_tail` miscomputation is wrong; the real cause is the
      missing `bss_stdlib` in classic CRT ordering (§3) with the one-line fix
      (§4). **Do not post until @ravn gives the go-ahead.**

### Phase 5 — Docs
- [ ] Note the CRT fix in `CALLING_CONVENTION.md` / the llvm-z80 status docs
      (benefits every classic dynamic-heap + qsort program, not just stdcbench).
- [ ] Update `bugs/README.md` / `PLAN-heap-and-realloc.md` cross-refs to point at
      this findings doc for the `malloc() failed` blocker.

## Definition of done
The dynamic runtime memory model (`CRT_STACK_SIZE=<reserve>`, SP from word@6, heap
`[__BSS_END_tail .. SP−reserve]`) works: full stdcbench prints `STDCBENCH OK` with
NO fixed-heap workaround, on ntvcm AND the real rcbios ceiling; a CI oracle guards
the qsort/heap-overlap regression; issue #40 carries the corrected root cause.

--------------------------------------------------------------------------------

## Appendix — key facts for a re-run

- Toolchain (export every shell): from z88dk root `PATH="$PWD/bin:$PATH"`,
  `ZCCCFG="$PWD/lib/config"`,
  `LLVMZ80EXE=/Users/ravn/z80/llvm-z80/build-macos/bin/clang`. Emulator
  `/Users/ravn/z80/ntvcm/ntvcm foo.com`. Wrap runs in `( ulimit -t N; … )`
  (failures warm-boot-loop).
- Build full stdcbench: 16 sources (`c90base*.c stdcbench.c portme.c
  bench_main.c c90lib*.c`). Builds CLEAN under the zcc DEFAULT `gnu23` now — no
  `-Cg-std=gnu11` and no `-Cg-Wno-error=incompatible-function-pointer-types`
  needed: the `<stdbool.h>` C23-keyword clash was fixed (guard the classic
  `typedef bool` on `__STDC_VERSION__ < 202311L`) and the comparator convention
  fix (§7) removed the fn-ptr warning.
- Free-list probe from C: `extern unsigned int heap[]; heap[1]` = first free
  block ptr; at that address word0=size, word2=next. Header at arena base
  `{size,next}`.
- Corrupting call: `c90lib-lnlc.c:312` `qsort(neighbour_degrees, ref_n,
  sizeof(node_t), cmp)` in `calc_neighbour_degrees`. NULL surfaces at
  `c90lib-lnlc.c:382` `malloc(772)`.
- Scratch var: `libsrc/stdlib/z80/sort/asm_quicksort.asm`, `SECTION bss_stdlib`,
  `__stdlib_quicksort_size_lsb: defw 0`; written `ld
  (__stdlib_quicksort_size_lsb),hl` (size-lsb) during partition.
