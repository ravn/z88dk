/*
 * Definitions etc. for regexp(3) routines.
 *
 * Caveat:  this is V8 regexp(3) [actually, a reimplementation thereof],
 * not the System V one.
 */
#ifndef __REGEXP_H
#define __REGEXP_H

#include <sys/compiler.h>

#define NSUBEXP  10

typedef struct regexp {
	char	*startp[NSUBEXP];
	char	*endp[NSUBEXP];
	char	regstart;	/* Internal use only. */
	char	reganch;	/* Internal use only. */
	char	*regmust;	/* Internal use only. */
	int	regmlen;	/* Internal use only. */
	char	program[1];	/* Unwarranted chumminess with compiler. */
} regexp;

#if defined(__LLVMZ80)
/* clang/llvmz80: like regexec below, regcomp/regerror are sccz80 __smallc
 * stack workers (pattern on the stack; regcomp returns its regexp* in HL).
 * Without __smallc clang uses its default sdcccall(1) -- passing the pattern
 * in HL and reading the return from DE -- so regcomp() returns a garbage
 * pointer and the very first regexec() then reports "corrupted program".
 * Declaring them __smallc (== sdcccall(0)) restores stack args + HL return.
 * See ravn/z88dk#39. */
extern regexp __LIB__ *regcomp(char *) __smallc;
extern void __LIB__ regerror(const char *) __smallc;
#else
extern regexp __LIB__ __SAVEFRAME__ *regcomp(char *);
extern void __LIB__ __SAVEFRAME__ regerror(const char *);
#endif

#if defined(__LLVMZ80)
/* clang/llvmz80: regexec/regsub are sccz80 __smallc STACK workers in
 * libsrc/regex/cimpl/regexp.c. sccz80 __smallc pushes args first-arg-DEEPEST
 * (the worker reads prog at [sp+8] == the deepest arg slot, verified from the
 * compiled ___regexec prologue), but clang's __smallc == sdcccall(0) pushes
 * first-arg-SHALLOWEST (cdecl/right-to-left) -- the two conventions are
 * MIRRORED for multi-arg calls. A straight __smallc decl therefore lands prog
 * in the shallow slot and the worker reads `string` as prog ->
 * prog->program[0] != MAGIC -> "corrupted program". Mirror the fcntl.h fix:
 * reversed-arg __smallc entries + inline forwarders so clang's shallow-first
 * push places the logical FIRST arg (prog) in the deepest slot, matching the
 * worker. (asm ___regexec/___regsub alias the same _regexec/_regsub workers;
 * int result comes back in HL, which sdcccall(0) reads.) regcomp/regerror
 * above take one arg, so order is moot -- they only need __smallc for the
 * stack arg + HL return. No asm change needed. See ravn/z88dk#39. */
extern int __LIB__ __regexec(char *__string, regexp *__prog) __smallc;
__attribute__((always_inline)) __attribute__((overloadable))
__attribute__((enable_if(1, "")))
static inline int regexec(regexp *__prog, char *__string) {
    return __regexec(__string, __prog);
}
extern void __LIB__ __regsub(char *__dest, char *__source, regexp *__prog) __smallc;
__attribute__((always_inline)) __attribute__((overloadable))
__attribute__((enable_if(1, "")))
static inline void regsub(regexp *__prog, char *__source, char *__dest) {
    __regsub(__dest, __source, __prog);
}
#elif !defined(__STDC_ABI_ONLY)
extern int __LIB__ __SAVEFRAME__ regexec(regexp *__prog, char *__string) __smallc;
extern void __LIB__ __SAVEFRAME__ regsub(regexp *__prog, char *__source, char *__dest) __smallc;
#else
__ZPROTO2(int,,regexec,regexp *,__prog, char *,__string)
__ZPROTO3(void,,regsub,regexp *,__prog, char *,__source, char *,__dest)
#endif

#endif
