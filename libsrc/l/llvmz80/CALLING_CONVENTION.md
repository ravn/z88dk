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

---

# The `__ZPROTO` family — how the header macros wire clang → classic clib

Many clib prototypes in `include/**` are written with the `__ZPROTO2/3/3N/4/5`
macros from `include/sys/proto.h` instead of a plain `extern`. This section
documents exactly what they expand to for clang (`-compiler=llvmz80`), the
register/stack contract the generated `___name` low-level must satisfy, and how
to implement or verify a bridge for one. Everything here was verified by
disassembling this clang's output (2026-07-17); re-verify with the same method
if the backend changes.

## What the macro expands to

`include/sys/proto.h` has three branches per arity: `__SCCZ80`, `__SDCC`, and a
clang/other `#else`. For sccz80/sdcc the macro is just a `__smallc` prototype in
natural order. For clang, `__ZPROTON(r,,name, t1,a1, … tN,aN)` expands to:

```c
/* low-level: params in REVERSED order, DEFAULT sdcccall(1) convention (NO __smallc) */
extern r __name(tN aN, …, t1 a1);
/* public entry: header-only, always-inlined, natural order, just reorders + tail-calls */
__attribute__((always_inline))
static inline r name(t1 a1, …, tN aN)
    __attribute__((overloadable)) __attribute__((enable_if(1, "")))
    { return __name(aN, …, a1); }
```

So a call `name(a1,…,aN)` in user code inlines to a call of the low-level
`__name(aN,…,a1)`. clang prepends one leading underscore to the asm symbol, so
the C identifier `__name` is emitted as **`___name`** (triple underscore) — that
is the symbol a bridge must define. (`overloadable`/`enable_if(1,"")` let the
inline coexist with a same-named macro and force inlining; they have no ABI
effect.)

## The `___name` low-level contract (what a bridge must accept)

Because the low-level params are `(aN, …, a1)` under the **sdcccall(1)** default
(see the top of this file), for the common 16-bit (int/pointer) case:

| low-level param # | value (natural arg) | location            |
|-------------------|---------------------|---------------------|
| 1                 | `aN` (LAST nat arg) | `HL`                |
| 2                 | `a(N-1)`            | `DE`                |
| 3, 4, …           | `a(N-2)`, `a(N-3)`… | stack, pushed R-to-L: **arg pushed first = deepest**; param 3 (`a(N-2)`) ends up **on top**, just above the return address |

- **Return value**: the bridge must return in **`DE`** (sdcccall(1): 16-bit ret in
  DE, 8-bit in A, 32-bit in **DE:HL** = DE low, HL high). Classic `asm_*` workers
  return in `HL` (or DE:HL for 32-bit), so a bridge typically ends `ex de,hl / ret`.
- **Stacked-arg cleanup depends on the RETURN WIDTH** (verified empirically
  2026-07-17, `extern int fi(int,int,int)` vs `extern long fl(int,int,int)`):
  - **≤16-bit return (int/pointer/char): callee-cleans.** clang emits NO cleanup
    after the `call`; the bridge itself must consume its stacked args before
    `ret` (e.g. `pop hl` (retaddr) / `ex (sp),hl` to drop one stacked word).
  - **32-bit return (`long`): caller-cleans.** clang emits `pop af`×(stacked
    words) AFTER the `call`; the bridge must leave the stacked args in place and
    just `ret`.
  This is why the two shipped bridges differ (both correct):
  `___strncmp` (returns `int` → callee-cleans, consumes `s1` via `pop hl / ex
  (sp),hl`) vs `___strtol` (returns `long` → caller-cleans, leaves `base` on the
  stack for the caller's `pop af`). Getting this backwards corrupts SP — it was a
  real bug in the first strtol bridge (see the strtol.asm history / session
  2026-07-16c). **Match the cleanup side to the return width, not to a habit.**

## `__ZPROTO3N` — natural (non-reversed) order

`__ZPROTO3N` is identical to `__ZPROTO3` **except the low-level keeps natural
order**: `__name(a1,a2,a3)` → `HL=a1, DE=a2, stack=a3`. Use it when the classic
`asm_*` worker already wants `HL=a1, DE=a2` (so the bridge only has to fetch the
one stacked arg into the register the worker expects, no HL/DE swap dance).
Shipped example: `___strtol`/`___strtoul` (`asm_strtol` enters `HL=nptr,
DE=endptr, BC=base`; the bridge only reads `base` off the stack into BC).

## Two ways to satisfy the low-level — and when NOT to use `__ZPROTO`

1. **`__ZPROTO` + a hand-asm register bridge (Strategy A).** Keep the header on
   the `__ZPROTO` macro and write a `___name:` marshaller in the worker's `.asm`
   that moves HL/DE/stack into the `asm_*` worker's expected registers, does
   `ex de,hl`, and cleans the stack per the return-width rule above. Used by the
   14 string functions (`libsrc/string/c/sccz80/*.asm`) and strtol/strtoul.
2. **Bypass `__ZPROTO`, rebind the low-level to the `__smallc` worker directly
   (Strategy B).** Do NOT use the macro; in the header write, under `#if
   defined(__LLVMZ80)`, `extern r __name(<reversed params>) __smallc
   __asm__("<classic global worker>");` plus a natural-order forwarding inline.
   clang then stack-marshals the whole call straight into the classic `__smallc`
   worker — **no asm bridge, and no `ex de,hl`** (the worker returns HL and clang
   adds the `ex de,hl` itself). This is the maintainer-preferred "least asm"
   style and is what the **stdio FILE\* layer** uses (fopen/freopen/fread/fwrite/
   fclose/ftell/fseek/rename/remove in `include/stdio.h`). It is only possible
   when a classic `__smallc` GLOBAL worker with the matching semantics exists.

Preferred order stays: annotation (Strategy B) > tiny `defc` alias > hand-asm
bridge (Strategy A). Strategy A is only needed when the target function is not a
plain `__smallc` global (e.g. it has a register-passing `asm_*` core the bridge
must adapt).

## POSIX fd-layer (`open`/`creat`/`read`/`write`/`close`/`lseek`) on CP/M — DUMMY

`<fcntl.h>` declares these with `__ZPROTO3`/`__ZPROTO2`, so clang emits
`call ___open` / `___read` / `___write` (and `call _close` for the plain
`close`). **On the classic `+cpm` target they resolve to
`libsrc/classic/fcntl/dummy/*.asm` — intentional no-op stubs** (`open`→`ld hl,-1`
= error, `read`/`write`/`close`→bare `ret`). Those stubs already
`PUBLIC open / _open / ___open`, so clang links against them and needs **no
bridge** — the POSIX integer-fd layer simply does not exist on CP/M for ANY
compiler (sccz80/sdcc/clang alike). Real CP/M file I/O goes through the **stdio
`FILE*` layer**, which is complete and MAME-verified (16/16, `stdiotst.c`). So
there is nothing to fix for clang in the fd-layer; do not add fd-layer bridges.

## Checklist to add/verify a `__ZPROTO` bridge

1. Read the macro arity in the header → know natural arg order `a1..aN`.
2. Low-level is `___name`; args land `HL=aN, DE=a(N-1), stack=a(N-2)…a1`
   (reversed) unless it is `__ZPROTO3N` (natural `HL=a1,DE=a2,stack=a3…`).
3. Return in `DE` (16-bit) / `A` (8-bit) / `DE:HL` (32-bit) — bridge usually ends
   `ex de,hl / ret`.
4. Cleanup: **int/ptr return → callee-cleans (bridge drops stacked args);
   long return → caller-cleans (bridge leaves them).**
5. Prefer Strategy B (`__smallc __asm__("worker")`, no asm) if a `__smallc`
   global worker exists; else Strategy A (hand-asm `___name`).
6. Red-green: add a `test/clang/runtime_*.{c,sh}` case, prove it fails before /
   passes after (ntvcm for stdout-only; MAME for file I/O).
