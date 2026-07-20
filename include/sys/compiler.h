

#ifndef __SYS_COMPILER_H__
#define __SYS_COMPILER_H__

#include <sys/proto.h>

#if defined(__CLION_IDE__) | defined(__INTELLISENSE__)

#define __LIB__
#define __SMALLC
#define __SAVEFRAME__
#define __z88dk_fastcall
#define __FASTCALL__
#define __CALLEE__
#define __SCCZ80
#define __Z80
#define __naked
#define __z88dk_callee
#define __stdc
#define __smallc
#define __smallconly
#define __preserves_regs(x...)
#define __no_z88dk_declspec
#define __at(x)
#define __sfr
#define __vasmallc

#else

/* Temporary fix to turn off features not supported by sdcc */
#if __SDCC | __clang__ | __XCC
#define __LIB__
#define __SAVEFRAME__
#define __SMALLC
#define far
#define __vasmallc
#define __Z88DK_R2L_CALLING_CONVENTION 1
#define __stdc
#define __z88dk_deprecated
#define __z88dk_sdccdecl

#if __SDCC
// __smallconly is for functions that only come in a smallc variant
#define __smallconly __smallc
#else
// Clang - we're out of luck
#define __smallconly
#endif

// Make intellisense run easier..
#if __clang__ | __CLANG | __XCC
#define __STDC_ABI_ONLY
// ravn/llvm-z80 clang honours SDCC calling conventions via the sdcccall
// attribute.  z88dk's classic clib functions are compiled __smallc (arguments
// pushed on the stack, caller cleans up) -- which is exactly sdcccall(0).
// Without this the attribute is a no-op and clang passes fixed arguments in
// HL, so e.g. putchar('H') -> the callee does `pop hl` and reads stack garbage
// (console output is corrupted).
//
// __z88dk_fastcall maps to the z80_fastcall attribute, which selects the
// ravn/llvm-z80 backend's z88dk-fastcall convention (CallingConv::
// Z80_Z88dkFastCall).  A single argument is passed in a fixed register by
// width, matching z88dk's classic clib (verified from source):
//   width | z88dk_fastcall (asm reads)      | z80_fastcall (backend)
//   ------+---------------------------------+---------------------------------
//   8-bit | L      (rs232_put.asm: `ld a,l`)| L      <- match
//   16-bit| HL     (swapendian.asm)         | HL     <- match
//   32-bit| DEHL                            | DE:HL  <- match (DE high, HL low)
// The return value uses the same registers.  Before z80_fastcall existed the
// macro was a no-op that only happened to work for a single 16-bit argument
// (clang's default i16 arg also lands in HL); 8/32-bit args were wrong.  Now
// all three widths are correct by construction.  The 16-bit contract remains
// pinned by a red-green regression test:
//   z88dk/test/clang/fastcall_abi_16.c
// and the full L/HL/DE:HL discipline by the LLVM lit test
//   llvm/test/CodeGen/Z80/z88dk-fastcall.ll (in the ravn/llvm-z80 tree).
// __z88dk_callee maps to the z80_callee attribute: arguments pushed on the
// stack like sdcccall(0), but the CALLEE cleans them up (CallingConv::
// Z80_Z88dkCallee).  This is the correct mapping -- z88dk clib functions marked
// __z88dk_callee callee-clean in their .asm, so the previous no-op was a latent
// bug (clang caller-cleaned while the callee also cleaned -> stack corruption).
// Backend mechanism pinned by llvm/test/CodeGen/Z80/z88dk-callee.ll; frontend
// mapping by clang/test/CodeGen/z80-callee.c.  End-to-end validation against a
// real clib link is Phase C.
#define __smallc __attribute__((sdcccall(0)))
#define __z88dk_callee __attribute__((z80_callee))
#define __z88dk_fastcall __attribute__((z80_fastcall))

// ravn/z88dk#31: the variadic stdio family (printf/sprintf/scanf/...) returns
// its count in HL (the classic clib convention).  llvmz80's default sdcccall(1)
// reads a 16-bit return from DE, so an unannotated variadic decl reads garbage
// (the count is wrong; formatting/parsing are fine because varargs are stacked
// either way).  Declaring the family __smallc == sdcccall(0) makes clang read
// the return from HL, matching the worker.  The sccz80 branch already sets
// `__vasmallc __smallc`; it was simply missing for llvmz80 when __smallc was
// wired to sdcccall(0).  Guarded to __LLVMZ80: ez80-clang (__stdc, HL return)
// is already correct and must not be touched (it may not support sdcccall).
#if defined(__LLVMZ80)
#undef  __vasmallc
#define __vasmallc __smallc
#endif
#endif

#else
// sccz80 case
#define __SMALLC __smallc
#define __smallconly __smallc
#define __vasmallc __smallc
#define __z88dk_deprecated
#endif

#endif

#ifdef __8080
#define __DISABLE_BUILTIN
#endif

#ifdef __8085
#define __DISABLE_BUILTIN
#endif

#if __SDCC && __GBZ80
#define __DISABLE_BUILTIN
#define __z88dk_fastcall
#endif

#define NONBANKED __nonbanked
#define BANKED __banked

#define __CHAR_LF '\n'
#define __CHAR_CR '\r'


#endif
