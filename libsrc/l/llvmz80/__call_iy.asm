; __call_iy — indirect call trampoline for ravn/llvm-z80 clang.
;
; Z80 has no CALL (reg) instruction.  When the GlobalISel backend needs to
; call a function pointer that it holds in IY, it emits "call __call_iy".
; This trampoline jumps to the address in IY; when the callee RETurns, it
; returns to the original CALL site (return address on stack from the CALL).
;
; Mirror of compiler-rt/lib/builtins/z80/call_iy.asm; this copy lives in
; z88dk's z80_crt0.lib so programs built with `zcc +cpm -compiler=llvmz80`
; resolve the symbol without needing a separate compiler-rt link step.

SECTION code_l_clang

PUBLIC __call_iy

__call_iy:
	jp	(iy)
