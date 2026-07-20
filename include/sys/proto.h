#ifndef __SYS_PROTO_H__
#define __SYS_PROTO_H__

// 
// 

#if __SCCZ80
#define __ZPROTO2(r,p, n,t1,a1,t2,a2) extern r __LIB__ p n(t1 a1,t2 a2) __smallc;
#elif __SDCC
#define __ZPROTO2(r,p, n,t1,a1,t2,a2) extern r p n(t1 a1,t2 a2) __smallc;
#else
#define __ZPROTO2(r,p, n,t1, a1,t2, a2) extern r p __##n  (t2 a2,t1 a1); \
  __attribute__((always_inline)) \
  static inline r p n(t1 a1,t2 a2) \
        __attribute__((overloadable)) \
        __attribute__((enable_if(1, ""))) { \
        return __##n  (a2,a1); \
  }
#endif

#if __SCCZ80
#define __ZPROTO3(r,p, n,t1,a1,t2,a2,t3,a3) extern r __LIB__ p n(t1 a1,t2 a2, t3 a3) __smallc;
#elif __SDCC
#define __ZPROTO3(r,p, n,t1,a1,t2,a2,t3,a3) extern r p n(t1 a1,t2 a2, t3 a3) __smallc;
#else
#define __ZPROTO3(r,p, n,t1,a1,t2,a2,t3,a3) extern r p __##n  (t3 a3, t2 a2,t1 a1); \
  __attribute__((always_inline)) \
  static inline r p n(t1 a1,t2 a2, t3 a3) \
        __attribute__((overloadable)) \
        __attribute__((enable_if(1, ""))) { \
        return __##n  (a3, a2,a1); \
  }
#endif

// __ZPROTO3N: like __ZPROTO3 but passes args in NATURAL order (a1,a2,a3) to ___fn.
// For clang/llvmz80 this means: HL=a1, DE=a2, stack=a3 (bridge-caller-cleans a3).
// Use when the underlying asm function already wants HL=a1, DE=a2 -- the bridge
// only needs to pop a3 into BC (via IX frame), avoiding the full peek/swap dance.
// For sccz80/sdcc the behaviour is identical to __ZPROTO3 (all args on stack).
#if __SCCZ80
#define __ZPROTO3N(r,p, n,t1,a1,t2,a2,t3,a3) extern r __LIB__ p n(t1 a1,t2 a2, t3 a3) __smallc;
#elif __SDCC
#define __ZPROTO3N(r,p, n,t1,a1,t2,a2,t3,a3) extern r p n(t1 a1,t2 a2, t3 a3) __smallc;
#else
#define __ZPROTO3N(r,p, n,t1,a1,t2,a2,t3,a3) extern r p __##n  (t1 a1, t2 a2, t3 a3); \
  __attribute__((always_inline)) \
  static inline r p n(t1 a1,t2 a2, t3 a3) \
        __attribute__((overloadable)) \
        __attribute__((enable_if(1, ""))) { \
        return __##n  (a1, a2, a3); \
  }
#endif

#if __SCCZ80
#define __ZPROTO4(r,p, n,t1,a1,t2,a2,t3,a3,t4,a4) extern r __LIB__ p n(t1 a1,t2 a2, t3 a3,t4 a4) __smallc;
#elif __SDCC
#define __ZPROTO4(r,p, n,t1,a1,t2,a2,t3,a3,t4,a4) extern r p n(t1 a1,t2 a2, t3 a3, t4 a4) __smallc;
#else
#define __ZPROTO4(r,p, n,t1,a1,t2,a2,t3,a3,t4,a4) extern r p __##n  (t4 a4, t3 a3, t2 a2,t1 a1); \
  __attribute__((always_inline)) \
  static inline r p n(t1 a1,t2 a2, t3 a3, t4 a4) \
        __attribute__((overloadable)) \
        __attribute__((enable_if(1, ""))) { \
        return __##n  (a4, a3, a2,a1); \
  }
#endif

#if __SCCZ80
#define __ZPROTO5(r,p, n,t1,a1,t2,a2,t3,a3,t4,a4,t5,a5) extern r __LIB__ p n(t1 a1,t2 a2, t3 a3,t4 a4,t5 a5) __smallc;
#elif __SDCC
#define __ZPROTO5(r,p, n,t1,a1,t2,a2,t3,a3,t4,a4,t5,a5) extern r p n(t1 a1,t2 a2, t3 a3, t4 a4,t5 a5) __smallc;
#else
#define __ZPROTO5(r,p, n,t1,a1,t2,a2,t3,a3,t4,a4,t5,a5) extern r p __##n  (t5 a5, t4 a4, t3 a3, t2 a2,t1 a1); \
  __attribute__((always_inline)) \
  static inline r p n(t1 a1,t2 a2, t3 a3,t4 a4,t5 a5) \
        __attribute__((overloadable)) \
        __attribute__((enable_if(1, ""))) { \
        return __##n  (a5, a4, a3, a2,a1); \
  }
#endif



#endif
