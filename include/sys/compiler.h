

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

// llvmz80 implements the Z80 calling-convention attributes natively;
// enable the ZPROTO bridges so classic sccz80 libraries link correctly.
// Other clang-shaped frontends (IDE indexers, ez80-clang) keep
// __STDC_ABI_ONLY so the headers parse without the bridge machinery.
#if __clang__ | __CLANG | __XCC
#if defined(__LLVMZ80)
#define __smallc         __attribute__((smallc))
#define __z88dk_callee   __attribute__((z88dk_callee))
#define __z88dk_fastcall __attribute__((z88dk_fastcall))
#else
#define __STDC_ABI_ONLY
#define __smallc
#define __z88dk_callee
#define __z88dk_fastcall
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
