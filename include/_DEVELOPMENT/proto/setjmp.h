include(__link__.m4)

#ifndef __SETJMP_H__
#define __SETJMP_H__

#include <sys/compiler.h>

#define setjmp(env)         l_setjmp(&(env))
#define longjmp(env, val)   l_longjmp(&(env), val)


typedef struct
{

   void *ix;
   void *iy;
   void *sp;
   void *pc;

} jmp_buf;



// must not use callee or fastcall linkage

#if defined(__LLVMZ80)
// llvmz80/clang: __SMALLC / __stdc expand empty (sys/compiler.h clang branch),
// so the default sdcccall(1) reads the return from DE and setjmp() "returns
// non-zero on the direct call". l_setjmp/l_longjmp are stack-arg + HL-return
// (sdcccall(0)); pin __smallc, mirroring the classic include/setjmp.h fix.
extern int __LIB__ l_setjmp (jmp_buf *env)          __smallc;
extern int __LIB__ l_longjmp(jmp_buf *env, int val) __smallc;
#else
__OPROTO(,,int,,l_setjmp,jmp_buf *env)
__SPROTO(,,void,,l_longjmp,jmp_buf *env,int val)
#endif

#endif
