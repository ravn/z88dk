; ___calloc — calloc bridge for ravn/llvm-z80 clang.
;
; WHY THIS FILE EXISTS
;   z88dk's proto.h wraps calloc(nobj,size) for clang via __ZPROTO2:
;     extern void *__calloc(unsigned size, unsigned nobj);
;     static inline void *calloc(unsigned nobj, unsigned size)
;       { return __calloc(size, nobj); }
;   The inline swaps the argument order so __calloc receives (size, nobj).
;   z88dk's cpm_clib exports _calloc (sccz80 __smallc ABI) but not __calloc
;   (sdcccall(1) ABI), so any clang program that calls calloc() gets
;   "undefined symbol: ___calloc" at link time.  This wrapper closes the gap.
;
; ABI (sdcccall(1), verified against llvm-z80 clang 2026-07-11):
;   enter : HL = size   (first arg to __calloc, already swapped by the inline)
;           DE = nobj   (second arg)
;   exit  : DE = pointer to zeroed block (0 if allocation failed)
;
; asm_HeapCalloc (classic/alloc/malloc-classic/HeapCalloc_callee.asm):
;   enter : HL = nobj, DE = size, BC = &_heap
;   exit  : HL = pointer (carry set on success; HL=0 on failure)
;
; Since nobj*size == size*nobj the multiply is commutative, so passing
; HL=size and DE=nobj is equivalent to HL=nobj and DE=size.  We just set
; BC=&_heap and jump directly.  The result arrives in HL; clang reads it
; from DE, so we swap with EX DE,HL before returning.

SECTION code_l_clang

PUBLIC ___calloc

EXTERN asm_HeapCalloc
EXTERN _heap

___calloc:
	ld	bc,_heap
	call	asm_HeapCalloc		; HL = ptr (carry) or 0 (no carry)
	ex	de,hl			; DE = ptr (clang's return register)
	ret
