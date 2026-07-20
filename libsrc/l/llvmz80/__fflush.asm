; _fflush_fastcall — fflush bridge for ravn/llvm-z80 clang.
;
; WHY THIS FILE EXISTS
;   z88dk's classic clib exports fflush as a __smallc (sccz80) function whose
;   body fetches its FILE* argument off the stack:
;       fflush:  pop bc      ; return address
;                pop hl      ; fp  (caller pushed it; caller-cleaned)
;                push hl
;                push bc
;                ...         ; result in HL
;   ravn/llvm-z80 clang uses a REGISTER ABI: a single 16-bit arg arrives in HL
;   and nothing is pushed.  Calling the worker directly makes it `pop hl` the
;   caller's saved data as "fp" and, worse, leaves SP 2 bytes high on the
;   caller-cleanup `pop bc` that never happens -> the C runtime's exit path
;   runs off a corrupted stack and the whole program restarts in a loop
;   (observed: printf("hi"); fflush(stdout); return 0;  looped forever).
;
;   fflush has no fastcall/callee variant in the classic clib to route to
;   (unlike atoi/strlen), so this thin wrapper re-pushes the argument onto the
;   stack in the layout the __smallc worker expects, calls it, then cleans up.
;   stdio.h routes fflush() -> fflush_fastcall() only for -D__LLVMZ80, so
;   sccz80/sdcc keep calling the plain stack-ABI _fflush unchanged.
;
; ABI (__z88dk_fastcall == z80_fastcall, verified against llvm-z80 clang):
;   enter : HL = fp
;   exit  : HL = fflush() return value (int)
;
; Stack story (SP grows down; [top ... bottom]):
;   entry            [caller_ret]                     HL = fp
;   pop de / push de [caller_ret]                     DE = caller_ret (parked)
;   push hl          [fp][caller_ret]
;   call _fflush     [wret][fp][caller_ret]           worker sees fp at [SP+2]
;     worker pop bc/pop hl reads fp, push hl/push bc restores, ret pops wret
;   after call       [fp][caller_ret]                 HL = result
;   pop de           [caller_ret]                     DE = fp (discarded)
;   ret              []                               returns to clang, HL=result

SECTION code_l_clang

PUBLIC _fflush_fastcall
PUBLIC fflush_fastcall

EXTERN _fflush

_fflush_fastcall:
fflush_fastcall:
	pop	de		; DE = return address to the clang caller
	push	de		; keep it below the argument for later cleanup
	push	hl		; push fp where the __smallc worker expects it
	call	_fflush		; worker reads fp off the stack; result in HL
	pop	de		; discard the fp we pushed (caller-cleanup)
	ret			; return to clang with HL = result
