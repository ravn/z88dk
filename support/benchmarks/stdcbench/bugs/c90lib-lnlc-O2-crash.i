# 1 "c90lib-lnlc.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 358 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "c90lib-lnlc.c" 2
# 13 "c90lib-lnlc.c"
# 1 "./stdcbench.h" 1
# 1 "./portme.h" 1
# 18 "./portme.h"
typedef unsigned long stdcbench_clock_t;
# 2 "./stdcbench.h" 2

extern const char stdcbench_name_version_string[];

unsigned long stdcbench(void);

void stdcbench_error(const char *message);

stdcbench_clock_t stdcbench_clock(void);

union stdcbench_buffer
{
 unsigned char unsigned_char [1536];
 char basic_char [1536];
 signed int signed_int [32];
};

extern union stdcbench_buffer stdcbench_buffer;


extern unsigned long c90base_score;
unsigned long c90base(void);
# 34 "./stdcbench.h"
extern unsigned long c90lib_score;
unsigned long c90lib(void);
# 14 "c90lib-lnlc.c" 2



# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 1 3
# 11 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/sys/compiler.h" 1 3





# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/sys/proto.h" 1 3
# 7 "/Users/ravn/z80/z88dk/lib/config/../..//include/sys/compiler.h" 2 3
# 12 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 2 3
# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/sys/types.h" 1 3
# 17 "/Users/ravn/z80/z88dk/lib/config/../..//include/sys/types.h" 3
typedef double float_t;
# 26 "/Users/ravn/z80/z88dk/lib/config/../..//include/sys/types.h" 3
typedef double double_t;
# 44 "/Users/ravn/z80/z88dk/lib/config/../..//include/sys/types.h" 3
typedef unsigned int size_t;




typedef signed int ssize_t;




typedef unsigned long clock_t;




typedef signed int pid_t;




typedef unsigned char bool_t;




typedef unsigned int ino_t;




typedef unsigned long nseconds_t;




typedef long time_t;




typedef short wild_t;




typedef unsigned long fpos_t;



typedef unsigned char u8_t;
typedef unsigned short u16_t;
typedef unsigned long u32_t;

typedef char i8_t;
typedef short i16_t;
typedef long i32_t;





   typedef unsigned char uchar;




   typedef unsigned int uint;
# 13 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 2 3
# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdint.h" 1 3
# 13 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdint.h" 3
typedef signed char int8_t;
typedef signed int int16_t;
typedef signed long int32_t;

typedef unsigned char uint8_t;
typedef unsigned int uint16_t;
typedef unsigned long uint32_t;

typedef signed char int_least8_t;
typedef signed int int_least16_t;
typedef signed long int_least32_t;

typedef unsigned char uint_least8_t;
typedef unsigned int uint_least16_t;
typedef unsigned long uint_least32_t;

typedef signed int int_fast8_t;
typedef signed int int_fast16_t;
typedef signed long int_fast32_t;

typedef unsigned int uint_fast8_t;
typedef unsigned int uint_fast16_t;
typedef unsigned long uint_fast32_t;

typedef long long int64_t;
typedef unsigned long long uint64_t;

typedef long long int_least64_t;
typedef unsigned long long uint_least64_t;

typedef long long int_fast64_t;
typedef unsigned long long uint_fast64_t;




typedef int intptr_t;


typedef unsigned int uintptr_t;

typedef long intmax_t;
typedef unsigned long uintmax_t;
# 14 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 2 3
# 27 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern int atoi(const char *s);
# 37 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern int atoi_fastcall(const char *s) __attribute__((z80_fastcall));



extern long atol(const char *s);





extern long atol_fastcall(const char *s) __attribute__((z80_fastcall));



extern char * __itoa (int radix, char * buf,int num); __attribute__((always_inline)) static inline char * itoa(int num,char * buf, int radix) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __itoa (radix, buf,num); }





extern char * __ltoa (int radix, char * buf,long num); __attribute__((always_inline)) static inline char * ltoa(long num,char * buf, int radix) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __ltoa (radix, buf,num); }





extern long __strtol (char * nptr, char ** endptr, int base); __attribute__((always_inline)) static inline long strtol(char * nptr,char ** endptr, int base) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strtol (nptr, endptr, base); }





extern uint32_t __strtoul (char * nptr, char ** endptr, int base); __attribute__((always_inline)) static inline uint32_t strtoul(char * nptr,char ** endptr, int base) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strtoul (nptr, endptr, base); }





extern char * __ultoa (int radix, char * buf,uint32_t num); __attribute__((always_inline)) static inline char * ultoa(uint32_t num,char * buf, int radix) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __ultoa (radix, buf,num); }





extern char * __utoa (int radix, char * buf,uint16_t num); __attribute__((always_inline)) static inline char * utoa(uint16_t num,char * buf, int radix) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __utoa (radix, buf,num); }
# 91 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern long long atoll(char *buf) __attribute__((sdcccall(0)));






extern char *lltoa(long long num,char *buf,int radix) __attribute__((sdcccall(0)));






extern long long strtoll(char *nptr,char **endptr,int base) __attribute__((sdcccall(0)));






extern unsigned long long strtoull(char *nptr,char **endptr,int base) __attribute__((sdcccall(0)));






extern char *ulltoa(unsigned long long num,char *buf,int radix) __attribute__((sdcccall(0)));
# 131 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern int rand(void);
extern void srand(unsigned int seed);
# 141 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern void srand_fastcall(unsigned int seed) __attribute__((z80_fastcall));
# 157 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/malloc.h" 1 3
# 59 "/Users/ravn/z80/z88dk/lib/config/../..//include/malloc.h" 3
extern void mallinit(void);
extern void * __sbrk (unsigned int size,void * addr); __attribute__((always_inline)) static inline void * sbrk(void * addr,unsigned int size) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __sbrk (size,addr); }
extern void * __calloc (unsigned int size,unsigned int nobj); __attribute__((always_inline)) static inline void * calloc(unsigned int nobj,unsigned int size) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __calloc (size,nobj); }
extern void free(void *addr);
extern void *malloc(unsigned int size);
extern void * __realloc (unsigned int size,void * p); __attribute__((always_inline)) static inline void * realloc(void * p,unsigned int size) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __realloc (size,p); }
extern void __mallinfo (unsigned int * largest,unsigned int * total); __attribute__((always_inline)) static inline void mallinfo(unsigned int * total,unsigned int * largest) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __mallinfo (largest,total); }
# 97 "/Users/ravn/z80/z88dk/lib/config/../..//include/malloc.h" 3
extern void *malloc_fastcall(unsigned int size) __attribute__((z80_fastcall));
extern void free_fastcall(void *addr) __attribute__((z80_fastcall));
extern void *calloc_callee(unsigned int nobj, unsigned int size) __attribute__((sdcccall(0))) __attribute__((z80_callee));
# 150 "/Users/ravn/z80/z88dk/lib/config/../..//include/malloc.h" 3
extern void HeapCreate(void *heap) __attribute__((z80_fastcall));
extern void HeapSbrk(void *heap, void *addr, unsigned int size) __attribute__((sdcccall(0)));
extern void HeapSbrk_callee(void *heap, void *addr, unsigned int size) __attribute__((sdcccall(0))) __attribute__((z80_callee));
extern void *HeapCalloc(void *heap, unsigned int nobj, unsigned int size) __attribute__((sdcccall(0)));
extern void *HeapCalloc_callee(void *heap, unsigned int nobj, unsigned int size) __attribute__((sdcccall(0))) __attribute__((z80_callee));
extern void HeapFree(void *heap, void *addr) __attribute__((sdcccall(0)));
extern void HeapFree_callee(void *heap, void *addr) __attribute__((sdcccall(0))) __attribute__((z80_callee));
extern void *HeapAlloc(void *heap, unsigned int size) __attribute__((sdcccall(0)));
extern void *HeapAlloc_callee(void *heap, unsigned int size) __attribute__((sdcccall(0))) __attribute__((z80_callee));
extern void *HeapRealloc(void *heap, void *p, unsigned int size) __attribute__((sdcccall(0)));
extern void *HeapRealloc_callee(void *heap, void *p, unsigned int size) __attribute__((sdcccall(0))) __attribute__((z80_callee));
extern void HeapInfo(unsigned int *total, unsigned int *largest, void *heap) __attribute__((sdcccall(0)));
extern void HeapInfo_callee(unsigned int *total, unsigned int *largest, void *heap) __attribute__((sdcccall(0))) __attribute__((z80_callee));
# 158 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 2 3
# 170 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern void exit(int status);
extern int atexit(void (*func)(void));
# 181 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern void exit_fastcall(int status) __attribute__((z80_fastcall));
extern int atexit_fastcall(void (*func)(void)) __attribute__((z80_fastcall));







extern char *getenv(const char *name);
extern char * __getenv_r (size_t len, char * buf,const char * name); __attribute__((always_inline)) static inline char * getenv_r(const char * name,char * buf, size_t len) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __getenv_r (len, buf,name); }
extern int __setenv (int overflow, const char * value,const char * name); __attribute__((always_inline)) static inline int setenv(const char * name,const char * value, int overflow) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __setenv (overflow, value,name); }
extern int unsetenv(const char *name);



extern int __getopt (const char * optstring, char ** argv,int argc); __attribute__((always_inline)) static inline int getopt(int argc,char ** argv, const char * optstring) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __getopt (optstring, argv,argc); }


extern char *optarg;
extern int opterr;
extern int optind;
extern int optopt;
extern int optreset;
# 229 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern void __qsort_llvmz80(int (*compar)(const void *, const void *) __attribute__((sdcccall(0))),
                             unsigned int size, unsigned int nmemb, void *base)
    __attribute__((sdcccall(0))) __asm("qsort");


extern void *__bsearch_llvmz80(int (*compar)(const void *, const void *) __attribute__((sdcccall(0))),
                               unsigned int size, unsigned int nmemb, void *base, void *key)
    __attribute__((sdcccall(0))) __asm("bsearch");
# 254 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
typedef struct
{

   int rem;
   int quot;

} div_t;

typedef struct
{

   unsigned int rem;
   unsigned int quot;

} divu_t;

typedef struct
{

   long quot;
   long rem;

} ldiv_t;

typedef struct
{

   unsigned long quot;
   unsigned long rem;

} ldivu_t;

extern void _div_(div_t *d,int numer,int denom) __attribute__((sdcccall(0)));






extern void _divu_(divu_t *d,unsigned int numer,unsigned int denom) __attribute__((sdcccall(0)));






extern void _ldiv_(ldiv_t *ld,long numer,long denom) __attribute__((sdcccall(0)));






extern void _ldivu_(ldivu_t *ld,unsigned long numer,unsigned long denom) __attribute__((sdcccall(0)));
# 319 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern int abs(int n);
# 329 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern int abs_fastcall(int n) __attribute__((z80_fastcall));



extern long labs(long n);






extern long labs_fastcall(long n) __attribute__((z80_fastcall));




extern uint isqrt(uint n);
# 355 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern uint isqrt_fastcall(uint n) __attribute__((z80_fastcall));
# 372 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern unsigned int inp(unsigned int port);
# 382 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern unsigned int inp_fastcall(unsigned int port) __attribute__((z80_fastcall));



extern void __outp (unsigned int byte,unsigned int port); __attribute__((always_inline)) static inline void outp(unsigned int port,unsigned int byte) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __outp (byte,port); }
# 401 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern void *swapendian(void *addr) __attribute__((z80_fastcall));
# 422 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern void t_delay(unsigned int tstates) __attribute__((z80_fastcall));

extern int sleep (int secs);
# 433 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern int sleep_fastcall (int secs) __attribute__((z80_fastcall));



extern void msleep(unsigned int milliseconds);
# 446 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern int msleep_fastcall (unsigned int milliseconds) __attribute__((z80_fastcall));
# 464 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern unsigned long extract_bits(unsigned char *data, unsigned int start, unsigned int size) __attribute__((sdcccall(0)));






extern int __wcmatch (char * filename,char *wildname); __attribute__((always_inline)) static inline int wcmatch(char *wildname,char * filename) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __wcmatch (filename,*wildname); }
# 480 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdlib.h" 3
extern unsigned int unbcd(unsigned int value) __attribute__((sdcccall(0)));
# 18 "c90lib-lnlc.c" 2
# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/string.h" 1 3






extern int __bcmp (size_t len, const void * b2,const void * b1); __attribute__((always_inline)) static inline int bcmp(const void * b1,const void * b2, size_t len) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __bcmp (len, b2,b1); }





extern void __bcopy (size_t len, void * dst,const void * src); __attribute__((always_inline)) static inline void bcopy(const void * src,void * dst, size_t len) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __bcopy (len, dst,src); }





extern void __bzero (size_t n,void * mem); __attribute__((always_inline)) static inline void bzero(void * mem,size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __bzero (n,mem); }





extern char * __index (int c,const char * s); __attribute__((always_inline)) static inline char * index(const char * s,int c) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __index (c,s); }






extern char * __rindex (int c,const char * s); __attribute__((always_inline)) static inline char * rindex(const char * s,int c) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __rindex (c,s); }





extern char * __strset (int c,char * s); __attribute__((always_inline)) static inline char * strset(char * s,int c) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strset (c,s); }





extern char * __strnset (size_t n, int c,char * s); __attribute__((always_inline)) static inline char * strnset(char * s,int c, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strnset (n, c,s); }





extern void * __rawmemchr (int c,const void * mem); __attribute__((always_inline)) static inline void * rawmemchr(const void * mem,int c) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __rawmemchr (c,mem); }






extern char * ___memlwr_ (size_t n,void * p); __attribute__((always_inline)) static inline char * _memlwr_(void * p,size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return ___memlwr_ (n,p); }





extern char * ___memstrcpy_ (size_t n, const char * s,void * p); __attribute__((always_inline)) static inline char * _memstrcpy_(void * p,const char * s, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return ___memstrcpy_ (n, s,p); }





extern char * ___memupr_ (size_t n,void * p); __attribute__((always_inline)) static inline char * _memupr_(void * p,size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return ___memupr_ (n,p); }
# 81 "/Users/ravn/z80/z88dk/lib/config/../..//include/string.h" 3
extern void * __memccpy (size_t n, int c, const void * src,void * dst); __attribute__((always_inline)) static inline void * memccpy(void * dst,const void * src, int c, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __memccpy (n, c, src,dst); }





extern void * __memchr (size_t n, int c,const void * s); __attribute__((always_inline)) static inline void * memchr(const void * s,int c, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __memchr (n, c,s); }






extern int __memcmp (size_t n, const void * s2,const void * s1); __attribute__((always_inline)) static inline int memcmp(const void * s1,const void * s2, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __memcmp (n, s2,s1); }






extern void * __memcpy (size_t n, const void * src,void * dst); __attribute__((always_inline)) static inline void * memcpy(void * dst,const void * src, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __memcpy (n, src,dst); }






extern void *memmem(const void *haystack,size_t haystack_len,const void *needle,size_t needle_len) __attribute__((sdcccall(0)));






extern void * __memmove (size_t n, const void * src,void * dst); __attribute__((always_inline)) static inline void * memmove(void * dst,const void * src, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __memmove (n, src,dst); }






extern void * __memrchr (size_t n, int c,const void * s); __attribute__((always_inline)) static inline void * memrchr(const void * s,int c, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __memrchr (n, c,s); }





extern void * __memset (size_t n, int c,void * s); __attribute__((always_inline)) static inline void * memset(void * s,int c, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __memset (n, c,s); }
# 138 "/Users/ravn/z80/z88dk/lib/config/../..//include/string.h" 3
extern void * __memset_wr (size_t n, int c,volatile void * s); __attribute__((always_inline)) static inline void * memset_wr(volatile void * s,int c, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __memset_wr (n, c,s); }





extern void * __memswap (size_t n, void * s2,void * s); __attribute__((always_inline)) static inline void * memswap(void * s,void * s2, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __memswap (n, s2,s); }





extern char * __stpcpy (const char * src,char * dst); __attribute__((always_inline)) static inline char * stpcpy(char * dst,const char * src) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __stpcpy (src,dst); }






extern char * __stpncpy (size_t n, const char * src,char * dst); __attribute__((always_inline)) static inline char * stpncpy(char * dst,const char * src, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __stpncpy (n, src,dst); }





extern int __strcasecmp (const char * s2,const char * s1); __attribute__((always_inline)) static inline int strcasecmp(const char * s1,const char * s2) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strcasecmp (s2,s1); }





extern char * __strcat (const char * src,char * dest); __attribute__((always_inline)) static inline char * strcat(char * dest,const char * src) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strcat (src,dest); }





extern char * __strchr (int c,const char * s); __attribute__((always_inline)) static inline char * strchr(const char * s,int c) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strchr (c,s); }





extern char * __strchrnul (int c,const char * s); __attribute__((always_inline)) static inline char * strchrnul(const char * s,int c) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strchrnul (c,s); }





extern int __strcmp (const char * s2,const char * s1); __attribute__((always_inline)) static inline int strcmp(const char * s1,const char * s2) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strcmp (s2,s1); }





extern int __strcoll (const char * s2,const char * s1); __attribute__((always_inline)) static inline int strcoll(const char * s1,const char * s2) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strcoll (s2,s1); }





extern char * __strcpy (const char * src,char * dst); __attribute__((always_inline)) static inline char * strcpy(char * dst,const char * src) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strcpy (src,dst); }





extern size_t __strcspn (const char * nspn,const char * s); __attribute__((always_inline)) static inline size_t strcspn(const char * s,const char * nspn) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strcspn (nspn,s); }






extern char *strdup(const char *s);




extern char *strdup_fastcall(const char *s) __attribute__((z80_fastcall));




extern char *strerror(char *s);







extern char *strerror_fastcall(int errnum) __attribute__((z80_fastcall));




extern int __stricmp (const char * s2,const char * s1); __attribute__((always_inline)) static inline int stricmp(const char * s1,const char * s2) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __stricmp (s2,s1); }





extern size_t __strlcat (size_t n, const char * src,char * dest); __attribute__((always_inline)) static inline size_t strlcat(char * dest,const char * src, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strlcat (n, src,dest); }





extern size_t __strlcpy (size_t n, const char * src,char * dest); __attribute__((always_inline)) static inline size_t strlcpy(char * dest,const char * src, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strlcpy (n, src,dest); }






extern size_t strlen(const char *s);
# 265 "/Users/ravn/z80/z88dk/lib/config/../..//include/string.h" 3
extern size_t strlen_fastcall(const char *s) __attribute__((z80_fastcall));





extern char *strlwr(char *s);




extern char *strlwr_fastcall(char *s) __attribute__((z80_fastcall));



extern int __strncasecmp (size_t n, const char * s2,const char * s1); __attribute__((always_inline)) static inline int strncasecmp(const char * s1,const char * s2, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strncasecmp (n, s2,s1); }





extern char * __strncat (size_t n, const char * src,char * dst); __attribute__((always_inline)) static inline char * strncat(char * dst,const char * src, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strncat (n, src,dst); }





extern char * __strnchar (int c, size_t n,const char * s); __attribute__((always_inline)) static inline char * strnchar(const char * s,size_t n, int c) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strnchar (c, n,s); }
# 303 "/Users/ravn/z80/z88dk/lib/config/../..//include/string.h" 3
__attribute__((always_inline)) static inline
char *strnchr(const char *s, size_t n, int c) { return strnchar(s, n, c); }



extern int __strncmp (size_t n, const char * s2,const char * s1); __attribute__((always_inline)) static inline int strncmp(const char * s1,const char * s2, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strncmp (n, s2,s1); }





extern char * __strncpy (size_t n, const char * src,char * dest); __attribute__((always_inline)) static inline char * strncpy(char * dest,const char * src, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strncpy (n, src,dest); }





extern char * __strndup (size_t n,const char * s); __attribute__((always_inline)) static inline char * strndup(const char * s,size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strndup (n,s); }





extern int __strnicmp (size_t n, const char * s2,const char * s1); __attribute__((always_inline)) static inline int strnicmp(const char * s1,const char * s2, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strnicmp (n, s2,s1); }





extern size_t __strnlen (size_t max_len,const char * s); __attribute__((always_inline)) static inline size_t strnlen(const char * s,size_t max_len) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strnlen (max_len,s); }





extern char * __strpkbrk (const char * set,const char * s); __attribute__((always_inline)) static inline char * strpkbrk(const char * s,const char * set) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strpkbrk (set,s); }





extern char * __strrchr (int c,const char * s); __attribute__((always_inline)) static inline char * strrchr(const char * s,int c) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strrchr (c,s); }





extern size_t __strrcspn (const char * set,const char * s); __attribute__((always_inline)) static inline size_t strrcspn(const char * s,const char * set) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strrcspn (set,s); }
extern size_t strrcspn(const char *s,const char *set) __attribute__((sdcccall(0)));






extern char *strrev(char *s);




extern char *strrev_fastcall(char *s) __attribute__((z80_fastcall));




extern size_t __strrspn (const char * set,const char * s); __attribute__((always_inline)) static inline size_t strrspn(const char * s,const char * set) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strrspn (set,s); }
extern size_t strrspn(const char *s,const char *set) __attribute__((sdcccall(0)));






extern char *strrstrip(char *s);




extern char *strrstrip_fastcall(char *s) __attribute__((z80_fastcall));



extern char * __strsep (const char * delim,char ** s); __attribute__((always_inline)) static inline char * strsep(char ** s,const char * delim) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strsep (delim,s); }





extern size_t __strspn (const char * pfx,const char * s); __attribute__((always_inline)) static inline size_t strspn(const char * s,const char * pfx) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strspn (pfx,s); }





extern char * __strstr (const char * subs,const char * s); __attribute__((always_inline)) static inline char * strstr(const char * s,const char * subs) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strstr (subs,s); }







extern char *strstrip(char *s);




extern char *strstrip_fastcall(char *s) __attribute__((z80_fastcall));



extern char * __strtok (const char * delim,char * s); __attribute__((always_inline)) static inline char * strtok(char * s,const char * delim) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strtok (delim,s); }





extern char * __strtok_r (char ** last_s, const char * delim,char * s); __attribute__((always_inline)) static inline char * strtok_r(char * s,const char * delim, char ** last_s) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strtok_r (last_s, delim,s); }





extern char *strupr(char *s);




extern char *strupr_fastcall(char *s) __attribute__((z80_fastcall));




extern size_t __strxfrm (size_t n, const char * src,char * dst); __attribute__((always_inline)) static inline size_t strxfrm(char * dst,const char * src, size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strxfrm (n, src,dst); }





extern char * __strrstr (const char * needle,const char * haystack); __attribute__((always_inline)) static inline char * strrstr(const char * haystack,const char * needle) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __strrstr (needle,haystack); }
extern char *strrstr(const char *haystack, const char *needle) __attribute__((sdcccall(0)));
# 19 "c90lib-lnlc.c" 2
# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 1 3
# 30 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 1 3
# 21 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 3
extern void *_CLIB_OPEN_MAX;
# 52 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 3
struct fcb {

    uint8_t drive;
    char name[8];
    char ext[3];
    uint8_t extent;
    char s1;
    char s2;
    char records;
    char discmap[16];
    char current_record;
    uint8_t ranrec[3];



    unsigned long rwptr;
    uint8_t use;
    uint8_t uid;
    uint8_t mode;
    uint8_t rnr_dirty;
    uint32_t record_nr;


    unsigned long cached_record;
    uint8_t dirty;
    uint8_t buffer[128];
};

struct sfcb {
    uint8_t drive;
    char name[8];
    char ext[3];
    uint8_t pwdmode;
    char filler[11];
    int c_date;
    uint8_t c_hours;
    uint8_t c_minutes;
    int date;
    uint8_t hours;
    uint8_t minutes;
};


extern struct fcb _fcb[0];
# 107 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 3
struct dpb {
    int SPT;
    uint8_t BSH;
    uint8_t BLM;
    uint8_t EXM;
    int DSM;
    int DRM;
    uint8_t AL0;
    uint8_t AL1;
    int CKS;
    uint8_t OFF;
};


extern struct dpb *get_dpb(int drive) __attribute__((z80_fastcall));
# 178 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 3
extern int __bdos_llvmz80(int arg,int func) __asm__("bdos_callee") __attribute__((sdcccall(0))) __attribute__((z80_callee));

extern int __bdosh_llvmz80(int arg,int func) __asm__("bdosh_callee") __attribute__((sdcccall(0))) __attribute__((z80_callee));
# 233 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 3
extern int __bios (int arg2, int arg,int func); __attribute__((always_inline)) static inline int bios(int func,int arg, int arg2) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __bios (arg2, arg,func); }

extern int biosh(int func,int arg,int arg2) __attribute__((sdcccall(0)));




extern struct fcb *getfcb(void);


extern int cpm_cache_get(struct fcb *fcb, unsigned long record_nr, int for_read);
extern int cpm_cache_flush(struct fcb *fcb);


extern int setfcb(struct fcb *fc, char *name) __attribute__((sdcccall(0)));
extern void parsefcb(struct fcb *fc, char *name) __attribute__((sdcccall(0)));


extern void putoffset(char *dest, long val) __attribute__((sdcccall(0)));


extern void _putoffset(unsigned char *where,long offset) __attribute__((sdcccall(0)));


extern int swapuid(int reqid) __attribute__((z80_fastcall));
# 270 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 3
extern struct fcb fc_dir;
extern char fc_dirpos;
extern char *fc_dirbuf;


extern int change_volume(int volume);
extern int get_current_volume(void);

extern int dir_move_first(void);
extern int dir_move_next(void);
extern int dir_get_entry_type(void);
extern char *dir_get_entry_name(void);
extern unsigned long dir_get_entry_size(void);
extern int get_dir_name(void);







extern int a_statusline(int onoff);

extern int a_keyspeed(int delay, int repeat) __attribute__((sdcccall(0)));

extern int a_border(int color);

extern int a_paper(int color);

extern int a_ink(int color);

extern int a_curx(void);

extern int a_cury(void);


extern int a_machine(void);






extern int a_machinever(void);

extern int a_biosver(void);


extern int a_memsize(void);

extern int a_driveb(void);

extern int a_serialport(void);
# 332 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 3
struct GSX_PB {
    void *control;
    void *intin;
    void *ptsin;
    void *intout;
    void *ptsout;
};


struct GSX_CTL {
    int fn;
    int n_ptsin;
    int n_ptsout;
    int n_intin;
    int n_intout;
    int special;
};
# 407 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 3
extern struct GSX_PB gios_pb;


extern struct GSX_CTL gios_ctl;



extern int gios_intin[];


extern int gios_ptsin[];


extern int gios_intout[];


extern int gios_ptsout[];




extern int gios(int fn) __attribute__((z80_fastcall));





extern int gios_1pm(int fn, int parm) __attribute__((sdcccall(0)));
extern int gios_1pm_callee(int fn, int parm) __attribute__((sdcccall(0))) __attribute__((z80_callee));



extern int gios_2px(int fn, int x1, int y1, int x2, int y2) __attribute__((sdcccall(0)));
extern int gios_2px_callee(int fn, int x1, int y1, int x2, int y2) __attribute__((sdcccall(0))) __attribute__((z80_callee));



extern int gios_1px(int fn, int x1, int y1) __attribute__((sdcccall(0)));
extern int gios_1px_callee(int fn, int x1, int y1) __attribute__((sdcccall(0))) __attribute__((z80_callee));




extern int gios_text(const char *s) __attribute__((z80_fastcall));
# 585 "/Users/ravn/z80/z88dk/lib/config/../..//include/cpm.h" 3
extern int gios_esc(int esc_code) __attribute__((z80_fastcall));
# 31 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 2 3
# 83 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/fcntl.h" 1 3
# 34 "/Users/ravn/z80/z88dk/lib/config/../..//include/fcntl.h" 3
typedef int mode_t;
# 66 "/Users/ravn/z80/z88dk/lib/config/../..//include/fcntl.h" 3
extern int __open (mode_t mode, int flags,const char * name); __attribute__((always_inline)) static inline int open(const char * name,int flags, mode_t mode) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __open (mode, flags,name); }

extern int __creat (mode_t mode,const char * name); __attribute__((always_inline)) static inline int creat(const char * name,mode_t mode) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __creat (mode,name); }

extern int close(int fd);
# 89 "/Users/ravn/z80/z88dk/lib/config/../..//include/fcntl.h" 3
extern ssize_t __read (size_t len, void * ptr,int fd); __attribute__((always_inline)) static inline ssize_t read(int fd,void * ptr, size_t len) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __read (len, ptr,fd); }
extern ssize_t __write (size_t len, void * ptr,int fd); __attribute__((always_inline)) static inline ssize_t write(int fd,void * ptr, size_t len) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __write (len, ptr,fd); }





extern long __lseek (int whence, long posn,int fd); __attribute__((always_inline)) static inline long lseek(int fd,long posn, int whence) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __lseek (whence, posn,fd); }


extern int readbyte(int fd) __attribute__((z80_fastcall));
extern int __writebyte (int c,int fd); __attribute__((always_inline)) static inline int writebyte(int fd,int c) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __writebyte (c,fd); }

extern int fsync(int fd);





extern char * __getcwd (size_t newlen,char * buf); __attribute__((always_inline)) static inline char * getcwd(char * buf,size_t newlen) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __getcwd (newlen,buf); }
extern int chdir(const char *dir);
extern char *getwd(char *buf);


extern int rmdir(const char *);
# 132 "/Users/ravn/z80/z88dk/lib/config/../..//include/fcntl.h" 3
extern void *_RND_BLOCKSIZE;
# 141 "/Users/ravn/z80/z88dk/lib/config/../..//include/fcntl.h" 3
struct RND_FILE {
 char name_prefix;
 char name[15];
 i16_t blocksize;
 unsigned char *blockptr;
 long size;
 long position;
 i16_t pos_in_block;
 mode_t mode;
};



extern int __rnd_loadblock (size_t len, void * loadstart,char * name); __attribute__((always_inline)) static inline int rnd_loadblock(char * name,void * loadstart, size_t len) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __rnd_loadblock (len, loadstart,name); }
extern int __rnd_saveblock (size_t len, void * loadstart,char * name); __attribute__((always_inline)) static inline int rnd_saveblock(char * name,void * loadstart, size_t len) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __rnd_saveblock (len, loadstart,name); }

extern int rnd_erase(char *name);
# 84 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 2 3
# 96 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
struct filestr {
        union f0xx {
                int fd;
                uint8_t *ptr;
        } desc;
        uint8_t flags;
        uint8_t ungetc;
        intptr_t extra;
        uint8_t flags2;
        uint8_t reserved;
        uint8_t reserved1;
        uint8_t reserved2;
};
# 146 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
typedef struct filestr FILE;
# 165 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern void *_FOPEN_MAX;




extern struct filestr _sgoioblk[10];
extern struct filestr _sgoioblk_end;
# 189 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern FILE _stdpun;

extern FILE _stdlst;

extern FILE _stdrdr;
# 203 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern FILE *fopen_zsock(char *name);


extern int fileno(FILE *stream) __attribute__((sdcccall(0))) __attribute__((z80_fastcall));
# 218 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern FILE *__fopen_llvmz80(const char *mode, const char *name) __asm__("fopen") __attribute__((sdcccall(0)));
extern FILE *__freopen_llvmz80(FILE *fp, const char *mode, const char *name) __asm__("freopen") __attribute__((sdcccall(0)));






extern FILE * __fdopen (const char * mode,const int fileds); __attribute__((always_inline)) static inline FILE * fdopen(const int fileds,const char * mode) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __fdopen (mode,fileds); }

extern FILE * ___freopen1 (FILE * fp, const char * mode, int fd,const char * name); __attribute__((always_inline)) static inline FILE * _freopen1(const char * name,int fd, const char * mode, FILE * fp) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return ___freopen1 (fp, mode, fd,name); }
extern FILE * __fmemopen (const char * mode, size_t size,void * buf); __attribute__((always_inline)) static inline FILE * fmemopen(void * buf,size_t size, const char * mode) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __fmemopen (mode, size,buf); }
# 242 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern int fclose(FILE *fp) __attribute__((sdcccall(0)));



extern int fflush(FILE *);





extern int fflush_fastcall(FILE *) __attribute__((z80_fastcall));



extern void closeall(void);






extern char * __fgets (FILE * fp, int l,char * s); __attribute__((always_inline)) static inline char * fgets(char * s,int l, FILE * fp) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __fgets (fp, l,s); }

extern int __fputs (FILE * fp,const char * s); __attribute__((always_inline)) static inline int fputs(const char * s,FILE * fp) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __fputs (fp,s); }







extern int fputc(int c, FILE *fp) __attribute__((sdcccall(0)));
# 284 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern int putchar(int) __attribute__((sdcccall(0)));



extern int fgetc(FILE *fp) __attribute__((sdcccall(0)));


extern int __ungetc (FILE * fp,int c); __attribute__((always_inline)) static inline int ungetc(int c,FILE * fp) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __ungetc (fp,c); }

extern int feof(FILE *fp);






extern int ferror(FILE *fp);





extern int puts(const char *) __attribute__((sdcccall(0)));
# 316 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern fpos_t ftell(FILE *fp) __attribute__((sdcccall(0)));



extern int __fgetpos (fpos_t * pos,FILE * fp); __attribute__((always_inline)) static inline int fgetpos(FILE * fp,fpos_t * pos) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __fgetpos (pos,fp); }







extern int __fseek_llvmz80(int whence, fpos_t offset, FILE *fp) __asm__("fseek") __attribute__((sdcccall(0)));
# 351 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern int __fread_llvmz80(FILE *fp, size_t num, size_t size, void *ptr) __asm__("fread") __attribute__((sdcccall(0)));
extern int __fwrite_llvmz80(FILE *fp, size_t num, size_t size, void *ptr) __asm__("fwrite") __attribute__((sdcccall(0)));
# 361 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern char *gets(char *s);

extern int printf(const char *fmt,...) __attribute__((sdcccall(0)));
extern int fprintf(FILE *f,const char *fmt,...) __attribute__((sdcccall(0)));
extern int sprintf(char *s,const char *fmt,...) __attribute__((sdcccall(0)));
extern int snprintf(char *s,size_t n,const char *fmt,...) __attribute__((sdcccall(0)));







extern int vfprintf(FILE *f,const char *fmt,void *ap) __attribute__((sdcccall(0)));
extern int vsnprintf(char *str, size_t n,const char *fmt,void *ap) __attribute__((sdcccall(0)));
# 421 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern void printn(int number, int radix,FILE *file) __attribute__((sdcccall(0)));






extern int scanf(const char *fmt,...) __attribute__((sdcccall(0)));
extern int fscanf(FILE *,const char *fmt,...) __attribute__((sdcccall(0)));
extern int sscanf(char *,const char *fmt,...) __attribute__((sdcccall(0)));




extern int vfscanf(FILE *, const char *fmt, void *ap) __attribute__((sdcccall(0)));
extern int vsscanf(char *str, const char *fmt, void *ap) __attribute__((sdcccall(0)));
# 450 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
extern int getarg(void);




extern int fchkstd(FILE *);




extern int fgetc_cons(void);


extern int fgetc_cons_inkey(void);


extern int fputc_cons(char c);


extern char * __fgets_cons (size_t n,char * s); __attribute__((always_inline)) static inline char * fgets_cons(char * s,size_t n) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __fgets_cons (n,s); }

extern int puts_cons(char *s);


extern void fabandon(FILE *);

extern long fdtell(int fd);
extern int __fdgetpos (fpos_t * pos,int fd); __attribute__((always_inline)) static inline int fdgetpos(int fd,fpos_t * pos) __attribute__((overloadable)) __attribute__((enable_if(1, ""))) { return __fdgetpos (pos,fd); }





extern int __rename_llvmz80(const char *d, const char *s) __asm__("rename") __attribute__((sdcccall(0)));






extern int remove(const char *name) __attribute__((sdcccall(0)));






extern int getk(void);

extern int getk_inkey(void);



extern int printk(const char *fmt,...) __attribute__((sdcccall(0)));


extern void perror(const char *msg) __attribute__((z80_fastcall));
# 515 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdio.h" 3
typedef int (*fputc_cons_func)(char c);

extern fputc_cons_func set_fputc_cons(fputc_cons_func func);


extern int fputc_cons_native(char c);

extern int fputc_cons_generic(char c);

extern int fputc_cons_ansi(char c);
# 20 "c90lib-lnlc.c" 2


# 1 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdbool.h" 1 3
# 12 "/Users/ravn/z80/z88dk/lib/config/../..//include/stdbool.h" 3
typedef unsigned char bool;
# 23 "c90lib-lnlc.c" 2

typedef uint_least8_t node_t;
typedef uint_fast8_t count_t;
# 38 "c90lib-lnlc.c"
bool ref_adjacency_matrix[8][8];
node_t ref_n;
node_t max_k;

bool check_lnlc(bool);


static bool adjacency_matrix[8][8];
static node_t n;
static node_t node_degrees[8];
static node_t degree_list[8];
static node_t num_edges;

static node_t k;
static node_t node_colors[8];

bool ref_adjacency_matrix[8][8];
node_t ref_n;
static node_t ref_node_degrees[8];
static node_t ref_degree_list[8];
static node_t ref_mindeg, ref_maxdeg;
static node_t ref_num_edges;
static node_t ref_neighbour_degrees[8];

node_t max_k;

static char *instructions;

bool add(void);
bool recolor(void);
bool test(void);


bool add(void)
{
 bool ret = 0;
 node_t sum, ref_sum;
 node_t i;
 node_t new_node_color;
 count_t connect_colors;

 node_t node_degrees_backup[8];
 node_t degree_list_backup[8];
 node_t num_edges_backup;

 memcpy(node_degrees_backup, node_degrees, 8 * sizeof(node_t));
 memcpy(degree_list_backup, degree_list, 8 * sizeof(node_t));
 num_edges_backup = num_edges;

 for(connect_colors = 0; connect_colors < (1 << k) && !ret; connect_colors++)
 {
  node_degrees[n] = 0;
  n++;
  memset(adjacency_matrix[n - 1], 0, (n - 1) * sizeof(bool));


  for(i = 0; i < n - 1; i++)
   if (connect_colors & (1 << node_colors[i]))
   {
    num_edges++;
    if(num_edges + (ref_n - n) * ref_mindeg / 2 > ref_num_edges)
      goto tried;
    if(num_edges - num_edges_backup > ref_maxdeg)
     goto tried;

    adjacency_matrix[n - 1][i] = 1;

    degree_list[node_degrees[i]]--;
    node_degrees[i]++;
    degree_list[node_degrees[i]]++;

    node_degrees[n - 1]++;
   }
  degree_list[node_degrees[n - 1]]++;

  if(num_edges + (ref_n - n) * ref_maxdeg < ref_num_edges)
   goto tried;

  if(n == ref_n)
  {
   if(test())
   {
    if(instructions)
    {
     instructions += sprintf(instructions, "Add node %d of color 0, connect it to nodes of the following colors: ", n - 1);
     for(i = 0; i < k; i++)
      if (connect_colors & (1 << i))
       instructions += sprintf(instructions, "%d ", i);
     instructions += sprintf(instructions, "\n");
    }

    ret = 1;
   }
   goto tried;
  }


  sum = 0;
  ref_sum = 0;
  for(i = ref_n - 1; i > 0; i--)
  {
   sum += degree_list[i];
   ref_sum += ref_degree_list[i];
   if(sum > ref_sum)
    goto tried;
  }

  for(new_node_color = 0; new_node_color <= k && new_node_color < max_k; new_node_color++)
  {
   node_t k_backup = k;

   if(new_node_color == k)
    k++;

   node_colors[n - 1] = new_node_color;


   if(recolor())
   {
    if(instructions)
    {
     instructions += sprintf(instructions, "Add node %d of color %d, connect it to nodes of the following colors: ", n - 1, new_node_color);
     for(i = 0; i < k; i++)
      if (connect_colors & (1 << i))
       instructions += sprintf(instructions, "%d ", i);
     instructions += sprintf(instructions, "\n");
    }

    ret = 1;

    goto tried;
   }

   k = k_backup;
  }

tried:
  n--;
  degree_list[n] = 0;
  memcpy(degree_list, degree_list_backup, 8 * sizeof(node_t));
  memcpy(node_degrees, node_degrees_backup, 8 * sizeof(node_t));
  num_edges = num_edges_backup;
 }

 return(ret);
}

static node_t recolormap[4];

bool do_recolor(void)
{
 bool ret = 0;
 node_t i;
 node_t node_colors_backup[8];
 bool used_colors[8];
 node_t k_backup;


 if(recolormap[node_colors[n - 1]] != node_colors[n - 1] &&
  recolormap[node_colors[n - 1]] == recolormap[recolormap[node_colors[n - 1]]])
  return(0);

 k_backup = k;
 memcpy(node_colors_backup, node_colors, 8 * sizeof(node_t));


 memset(used_colors, 0, 8 * sizeof(bool));
 k = 0;
 for(i = 0; i < k_backup; i++)
 {
  used_colors[recolormap[i]] = 1;
  if(recolormap[i] >= k)
   k = recolormap[i] + 1;
 }

 for(i = 0; i < k; i++)
  if(!used_colors[i])
   goto tried;


 for(i = 0; i < n; i++)
  node_colors[i] = recolormap[node_colors[i]];


 if(ret = add())
 {
  for(i = 0; i < n; i++)
   if (node_colors[i] != node_colors_backup[i] && instructions)
    instructions += sprintf(instructions, "Recolor node %d from %d to %d\n", i, node_colors_backup[i], node_colors[i]);
 }

tried:
 memcpy(node_colors, node_colors_backup, 8 * sizeof(node_t));
 k = k_backup;

 return(ret);
}

bool maprecolor(node_t i)
{
 node_t j;

 if (i == k)
  return(do_recolor());
 else
  for(j = 0; j <= i; j++)
  {
   recolormap[i] = j;
   if(maprecolor(i + 1))
    return(1);
  }
 return(0);
}


bool recolor(void)
{
 return(maprecolor(0));
}

static node_t testperm[8];


bool permtest(node_t i)
{
 node_t j;


 for(j = 0; j + 2 < i; j++)
  if((testperm[i - 1] > testperm[j] ? adjacency_matrix[testperm[i - 1]][testperm[j]] : adjacency_matrix[testperm[j]][testperm[i - 1]]) != ref_adjacency_matrix[i - 1][j])
   return(0);

 if(i == n)
  return(1);

 for(j = i; j < n; j++)
 {
  node_t t;

  if (node_degrees[testperm[j]] != ref_node_degrees[i])
   continue;

  t = testperm[i];
  testperm[i] = testperm[j];
  testperm[j] = t;

  if(permtest(i + 1))
   return(1);

  t = testperm[i];
  testperm[i] = testperm[j];
  testperm[j] = t;
 }

 return(0);
}

int cmp(const void *l, const void *r) __attribute__((sdcccall(0)))
{
 return *((node_t*)r) - *((node_t *)l);
}

void calc_neighbour_degrees(node_t *restrict neighbour_degrees, bool (*adjacency_matrix)[8], const node_t *restrict degrees)
{
 node_t i, j;

 memset(neighbour_degrees, 0, 8);
 for(i = 0; i < ref_n; i++)
  for(j = 0; j < i; j++)
   if(adjacency_matrix[i][j])
   {
    neighbour_degrees[i] += (1 << (degrees[j] - 1));
    neighbour_degrees[j] += (1 << (degrees[i] - 1));
   }
 __qsort_llvmz80((cmp), (sizeof(node_t)), (ref_n), (neighbour_degrees));
}


bool test(void)
{
 node_t i;
 node_t neighbour_degrees[8];


 if (memcmp(ref_degree_list, degree_list, n * sizeof(node_t)))
  return(0);


 calc_neighbour_degrees(neighbour_degrees, adjacency_matrix, node_degrees);
 if (memcmp(ref_neighbour_degrees, neighbour_degrees, n * sizeof(node_t)))
  return(0);

 for(i = 0; i < n; i++)
  testperm[i] = i;

 return(permtest(0));
}



bool check_lnlc(bool output_instructions)
{
 bool ret;
 char *startinstructions;
 char *outinstructions = stdcbench_buffer.basic_char;
 node_t i, j;

 if(!ref_n)
  return(1);

 memset(ref_node_degrees, 0, 8 * sizeof(node_t));
 memset(ref_degree_list + 1, 0, (8 - 1) * sizeof(node_t));
 ref_degree_list[0] = ref_n;
 ref_num_edges = 0;
 for(i = 0; i < ref_n; i++)
  for(j = 0; j < i; j++)
   if(ref_adjacency_matrix[i][j])
   {
    ref_degree_list[ref_node_degrees[i]]--;
    ref_node_degrees[i]++;
    ref_degree_list[ref_node_degrees[i]]++;
    ref_degree_list[ref_node_degrees[j]]--;
    ref_node_degrees[j]++;
    ref_degree_list[ref_node_degrees[j]]++;
    ref_num_edges++;
   }

 for(i = 1, ref_mindeg = ref_maxdeg = ref_node_degrees[0]; i < ref_n; i++)
 {
  node_t ref_deg = ref_node_degrees[i];
  if (ref_deg < ref_mindeg)
   ref_mindeg = ref_deg;
  if (ref_deg > ref_maxdeg)
   ref_maxdeg = ref_deg;
 }

 calc_neighbour_degrees(ref_neighbour_degrees, ref_adjacency_matrix, ref_node_degrees);

 memset(degree_list, 0, 8 * sizeof(node_t));
 num_edges = 0;
 k = 0;

 if(output_instructions)
 {
  if(!(startinstructions = instructions = malloc_fastcall(60 + (ref_n) * (72 + max_k / 8 * 2) + (ref_n - 1) * (ref_n - 2) / 2 * 28)))
   stdcbench_error("c90lib c90lib_lnlc(): malloc() failed\n");
  else
   startinstructions[0] = 0;
 }
 else
  startinstructions = instructions = 0;

 ret = add();

 if (ret && startinstructions)
 {
  char *c;

  outinstructions += sprintf(outinstructions, "Instructions for constructing the graph:");

  while(c = strrchr(startinstructions, '\n'))
  {
   outinstructions += sprintf(outinstructions, c);
   *c = 0;
  }
  outinstructions += sprintf(outinstructions, "\n%s\n", startinstructions);
 }

 free_fastcall(startinstructions);

 return(ret);
}

static const char resultinstructions[] =
 "Instructions for constructing the graph:\n"
 "\n"
 "Add node 0 of color 0, connect it to nodes of the following colors: \n"
 "Add node 1 of color 1, connect it to nodes of the following colors: \n"
 "Add node 2 of color 2, connect it to nodes of the following colors: 0 1 \n"
 "Add node 3 of color 1, connect it to nodes of the following colors: 0 \n"
 "Add node 4 of color 0, connect it to nodes of the following colors: 0 1 \n"
 "Recolor node 2 from 2 to 1\n"
 "Add node 5 of color 0, connect it to nodes of the following colors: 1 \n";

static volatile const bool prism[6][6] =
 {{0, 1, 1, 1, 0, 0},
 {1, 0, 1, 0, 1, 0},
 {1, 1, 0, 0, 0, 1},
 {1, 0, 0, 0, 1, 1},
 {0, 1, 0, 1, 0, 1},
 {0, 0, 1, 1, 1, 0}};

void c90lib_lnlc(void)
{
 node_t i, j;

 ref_n = 6;
 for(i = 0; i < ref_n; i++)
  for(j = 0; j < ref_n; j++)
   ref_adjacency_matrix[i][j] = prism[i][j];

 for(max_k = 0; max_k <= 4; max_k++)
  if(check_lnlc(1))
   break;

 if(k != 1 || strcmp(stdcbench_buffer.basic_char, resultinstructions))
  stdcbench_error("c90lib c90lib_lnlc(): Result validation failed");
}
