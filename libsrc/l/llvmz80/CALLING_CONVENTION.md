# clang-z80 (ravn/llvm-z80) calling convention — reference for the bridge layer

This directory holds the ABI adapters that let a program compiled by
`zcc +cpm -compiler=llvmz80` call z88dk's classic clib. To write or review one
correctly you need the exact calling convention ravn/llvm-z80 emits. It is NOT
documented by the backend, so it is captured here. Every fact below was
verified by disassembling real caller/callee code with this clang (dates in
parentheses); re-verify with the same method if the backend changes.

## `sdcccall(1)` — the default convention (what an unannotated `extern` uses)

This is the ravn/llvm-z80 backend default and is `sdcccall(1)`-compatible; it is
kept per the user's "do not change sdcccall 0/1" directive. An unannotated
declaration already uses it, so **no annotation is normally needed**; the
explicit form is `__attribute__((sdcccall(1)))` (there is no `__smallc`-style
short macro for it because it is the default). It is the convention every
clang-compiled C function here is emitted with, and the one a bridge must match
when it is *called by* clang code.

- **Arguments**: arg1 → `HL`, arg2 → `DE`. Args 3.. are **pushed right-to-left**
  (last declared arg deepest, arg3 nearest the top / just above the return
  address). Verified 2026-07-16: `worker4(0x1111,0x2222,0x3333,0x4444)` emits
  `ld hl,0x1111 / ld de,0x2222 / push 0x4444 / push 0x3333 / call` (arg4 pushed
  first = deepest, arg3 on top). Register assignment for **8-bit and 32-bit
  args differs under sdcccall(1)** (e.g. a leading `char` uses `A`/`L`) and was
  not separately re-verified here — the facts above are for 16-bit (pointer/int)
  args, which is what the stdio/string/mem bridges pass.
- **16-bit return value**: in **`DE`**, NOT HL. At a call site the caller does
  `call foo / ex de,hl / ld (dst),hl`, and a returning function ends
  `... / ex de,hl / ret`. (Also independently noted in `__divhi3.asm`.)
- **8-bit return value**: in `A`.
- **Stacked-arg cleanup**: **callee-cleans**. A callee that received stacked
  args ends its epilogue `pop bc (ret) / inc sp*(2·N) / push bc / ret`, i.e. it
  drops the caller's pushed words itself. Verified 2026-07-16 from a 4-arg
  callee: `... / pop ix / pop bc / inc sp / inc sp / inc sp / inc sp / push bc /
  ret` (drops the 2 stacked words).
- **Register preservation**: `HL`, `DE`, `BC`, `AF` are all **caller-saved**
  (clobberable by a callee). `IX` is callee-saved (the compiler's own frames
  push/pop it). `IY` is reserved (never touched). (From `__divhi3.asm`'s note.)

## `__smallc` == `__attribute__((sdcccall(0)))` (the stack convention)

Used to make clang call a classic `__smallc` clib worker directly, or to make a
callback (e.g. a qsort comparator) match the classic stack protocol. `__smallc`
is a no-op for sccz80/sdcc, so an annotated declaration stays source-portable.

- **Arguments**: **all** args pushed onto the stack, **right-to-left** (last
  declared arg pushed first = deepest; **first declared arg ends up on top**,
  nearest the return address). Verified 2026-07-16: a `sdcccall(0)` call
  `fr(ptr,size,num,fp)` emits `push fp / push num / push size / push ptr / call`
  → on the stack above the return address, top→deep: `ptr, size, num, fp`.
- **Return value**: the callee returns 16-bit in **`HL`** (classic clib
  convention); clang emits `ex de,hl` after the call to move it into its own
  `DE` return register. So a `__smallc` bridge does NOT need its own `ex de,hl`.
- **Cleanup**: **caller-cleans** (clang emits `pop af`×N after the call),
  matching the classic sccz80 `__smallc` workers (which end `pop ix / ret`,
  leaving the args on the stack).

### Consequence — arg order vs the classic worker

A classic `__smallc` worker reads its args via `push ix / ld ix,0 / add ix,sp`
as `ix+4 = last-declared arg`, `ix+6 = …`. E.g. classic
`fread(void *ptr, size_t size, size_t nmemb, FILE *fp)` reads `ix+4=fp`,
`ix+6=nmemb`, `ix+8=size`, `ix+10=ptr` — i.e. it wants **`fp` on top, `ptr`
deepest**. clang's `__smallc` puts the **first** declared param on top, so to
hit that layout you declare the low-level prototype with **reversed params**
and forward to it from a natural-order `static inline`:

```c
/* binds to the classic _fread; note reversed params + __smallc */
extern int __fread_ll(FILE *fp, size_t num, size_t size, void *ptr)
        __smallc __asm__("<classic asm symbol>");
static inline int fread(void *ptr, size_t size, size_t num, FILE *fp)
        { return __fread_ll(fp, num, size, ptr); }
```

This is exactly what `include/sys/proto.h`'s `__ZPROTO4` macro automates (its
clang `#else` branch declares a reversed-arg low-level `__##n` and a forwarding
inline). The only difference is whether the low-level is `__smallc` (so clang
marshals the whole call and you need no asm at all — preferred) or the register
default (which then needs a hand-asm marshalling bridge like an early draft of
`__fread.asm`).

## Preferred implementation order (least asm wins)

1. **Pure annotation** — declare the classic worker with the right convention
   (`__smallc` [+ `__z88dk_callee` if a `*_callee` entry exists], reversed
   params if needed) and a forwarding inline. No asm. This is the maintainer's
   preferred style; see `fputc_callee`/`fputs_callee` in `include/stdio.h` and
   the qsort comparator (`__smallc` callback, no trampoline).
2. **Tiny asm alias** (`defc ___name = _worker`) — only if the symbol name
   can't be bound from the header.
3. **Hand-asm marshalling bridge** (`__fflush.asm` style) — only when no
   annotation can express the mismatch (e.g. a single-arg function with no
   fastcall/callee entry, or a register↔stack conversion the ZPROTO swapper
   can't do).
