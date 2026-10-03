

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
#define __z88dk_callback

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

// __preserves_regs(...) is a builtin keyword in sccz80 and SDCC (it annotates
// which registers a hand-asm routine leaves untouched), but clang/ez80-clang
// have no such keyword.  Without a no-op mapping, ctype.h's fastcall decls
// (e.g. `isdigit_fastcall(int) __z88dk_fastcall CTYPE_PRESERVE`) fail to parse
// under clang once __STDC_ABI_ONLY is not defined ("expected function body
// after function declarator").  Map it to nothing for the clang toolchains.
#if __clang__ | __XCC
#define __preserves_regs(x...)
#endif

// Classic-library callback thunks use sdcccall(0); other compilers already
// use that default.
#define __z88dk_callback

#if __SDCC
// __smallconly is for functions that only come in a smallc variant
#define __smallconly __smallc
#else
// Clang - we're out of luck
#define __smallconly
#endif

// Make intellisense run easier..
#if __clang__ | __CLANG | __XCC
#if !defined(__LLVMZ80)
#define __STDC_ABI_ONLY
#endif
// LLVM-Z80 maps these attributes to distinct classic-library ABIs:
// fastcall uses L/HL/DE:HL by argument width; callee cleans stack args;
// smallc pushes left-to-right and caller cleans.
#define __smallc __attribute__((smallc))
#define __z88dk_callee __attribute__((z88dk_callee))
#define __z88dk_fastcall __attribute__((z88dk_fastcall))

// Variadic classic stdio uses right-to-left stack args and HL returns.
// Keep it separate from __smallc; ez80-clang uses its own __stdc ABI.
#if defined(__LLVMZ80)
#undef  __vasmallc
#define __vasmallc __attribute__((sdcccall(0)))
// Callback thunks pass stack args right-to-left, not as __smallc does.
#undef  __z88dk_callback
#define __z88dk_callback __attribute__((sdcccall(0)))
#endif
#endif

#else
// sccz80 case
#define __SMALLC __smallc
#define __smallconly __smallc
#define __vasmallc __smallc
#define __z88dk_deprecated
// sccz80's default already matches classic-library callbacks.
#define __z88dk_callback
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
