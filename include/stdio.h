#ifndef __STDIO_H__
#define __STDIO_H__

#include <sys/compiler.h>
#include <stdint.h>

/* $Id: stdio.h */

#undef __STDIO_BINARY      /* By default don't consider binary/text file differences */
#undef __STDIO_CRLF        /* By default don't insert automatic linefeed in text mode */

#ifdef __SPECTRUM__
#include <arch/zx/spectrum.h>
#endif

#ifdef __LAMBDA__
#include <zx81.h>
#endif

#ifdef __ZX81__
#include <zx81.h>
#endif

#ifdef __ZX80__
#include <zx81.h>
#endif

#ifdef __CPM__
/* This will define __STDIO_BINARY, __STDIO_EOFMARKER and __STDIO_CRLF  */
#include <cpm.h>
#endif

#ifdef __HDOS__
/* This will define __STDIO_BINARY, __STDIO_EOFMARKER and __STDIO_CRLF  */
#include <arch/hdos.h>
#endif

#ifdef __MSX__
/* This will define __STDIO_BINARY, __STDIO_EOFMARKER and __STDIO_CRLF  */
#include <cpm.h>
#include <msx.h>
#endif

#ifdef __SHARPMZ__
#include <arch/mz.h>
#endif

#ifdef __OSCA__
/* This will define __STDIO_BINARY, __STDIO_EOFMARKER and __STDIO_CRLF  */
#include <flos.h>
#endif

#ifdef __SOS__
#include <sos.h>
#endif

#ifdef ZXVGS
#include <zxvgs.h>
#endif


#ifdef AMALLOC
#include <malloc.h>
#endif
#ifdef AMALLOC1
#include <malloc.h>
#endif
#ifdef AMALLOC2
#include <malloc.h>
#endif
#ifdef AMALLOC3
#include <malloc.h>
#endif


/*
 * This is the new stdio library - everything is pretty much
 * generic - just a few machine specific routines are needed
 * and these are clearly marked
 */

#include <sys/types.h>
#include <fcntl.h>

#ifndef NULL
#define NULL ((void *)0)
#endif

#ifndef EOF
#define EOF (-1)
#endif

#define FILENAME_MAX    128


struct filestr {
        union f0xx {
                int         fd;
                uint8_t    *ptr;
        } desc;
        uint8_t   flags;
        uint8_t   ungetc;
        intptr_t  extra;
        uint8_t   flags2;
        uint8_t   reserved;
        uint8_t   reserved1;
        uint8_t   reserved2;
};


/* extra may point to an asm label that can be used to add extra stdio functionality
 * Entry: ix = fp for all 
 */

/* Exit: hl = byte read, c = error, nc = success */
#define __STDIO_MSG_GETC        1
/* Entry: bc = byte to write, Exit: hl = byte written (or EOF) */
#define __STDIO_MSG_PUTC        2
/* Entry: de = buf, bc = len, Exit: hl = bytes read */
#define __STDIO_MSG_READ        3
/* Entry: de = buf, bc = len, Exit: hl = bytes written */
#define __STDIO_MSG_WRITE       4
/* Entry: debc = offset, a' = whence */
#define __STDIO_MSG_SEEK        5
#define __STDIO_MSG_FLUSH       6
#define __STDIO_MSG_CLOSE       7
#define __STDIO_MSG_IOCTL       8


/* For asm routines kinda handy to have a nice DEFVARS of the structure*/
#ifdef STDIO_ASM
#asm
DEFVARS 0 {
    fp_desc         ds.w    1
    fp_flags        ds.b    1
    fp_ungetc       ds.b    1
    fp_extra        ds.w    1
    fp_flags2       ds.b    1
    reserved        ds.b    1
    reserved2       ds.b    1
    reserved3       ds.b    1
}
#endasm
#endif

typedef struct filestr FILE;

/* System is used for initial std* streams 
 * Network streams do not set IOREAD/IOWRITE, it is assumed that
 * they are read/write always
 */

#define _IOUNGETC       1
#define _IOREAD         2
#define _IOWRITE        4
#define _IOEOF          8
#define _IOSYSTEM      16
#define _IOEXTRA       32
#define _IOTEXT        64
#define _IOSTRING     128


/* Number of open files, this can be overridden by the crt0, but the 10 is the default for classic */
#ifndef FOPEN_MAX
extern void *_FOPEN_MAX;
#define FOPEN_MAX (int)&_FOPEN_MAX
#endif


extern struct filestr _sgoioblk[10]; 
extern struct filestr _sgoioblk_end; 


#define stdin  &_sgoioblk[0]
#define stdout &_sgoioblk[1]
#define stderr &_sgoioblk[2]

#ifdef __CPM
//
// File descriptors to represent other CP/M devices
//
// These are not enabled by default, to enable them add:
//
// -pragma-define:WANT_DEVICE_STDPUN=1
// -pragma-define:WANT_DEVICE_STDRDR=1
// -pragma-define:WANT_DEVICE_STDLST=1
//
// To the command line/pragma file
extern FILE _stdpun;
#define stdpun &_stdpun
extern FILE _stdlst;
#define stdlst &_stdlst
extern FILE _stdrdr;
#define stdrdr &_stdrdr
#endif

/* ---- FIXME These are not enabled but allow compilation to proceed --- */
#define ttyin  &_sgoioblk[3]
#define ttyout &_sgoioblk[4]
#define ttyerr &_sgoioblk[5]

#define clearerr(f)
extern FILE __LIB__ *fopen_zsock(char *name);

/* Get a file file descriptor from a file pointer */
extern int __LIB__ fileno(FILE *stream) __smallc __z88dk_fastcall;

/* Our new and improved functions!! */

#if defined(__LLVMZ80)
/* ravn/llvm-z80: same register-vs-stack mismatch as fread/fwrite (the generic
 * __ZPROTO2/3 clang branch tail-calls the classic worker with args in HL/DE,
 * but _fopen/_freopen are __smallc stack workers) -> fopen returned a non-NULL
 * but never-opened FILE* (a subsequent fwrite finds no _IOWRITE flag and writes
 * 0 bytes).  Bind straight to the classic worker via a reversed-param __smallc
 * prototype so clang pushes the args in the exact order the worker reads them.
 * See libsrc/l/llvmz80/CALLING_CONVENTION.md.  sccz80/sdcc keep __ZPROTO. */
extern FILE __LIB__ *__fopen_llvmz80(const char *mode, const char *name) __asm__("fopen") __smallc;
extern FILE __LIB__ *__freopen_llvmz80(FILE *fp, const char *mode, const char *name) __asm__("freopen") __smallc;
#define fopen(name,mode)      __fopen_llvmz80(mode,name)
#define freopen(name,mode,fp) __freopen_llvmz80(fp,mode,name)
#else
__ZPROTO2(FILE,*,fopen,const char *,name, const char *,mode)
__ZPROTO3(FILE,*,freopen,const char *,name, const char *,mode,FILE *,fp)
#endif
__ZPROTO2(FILE,*,fdopen,const int, fileds,const char *,mode)

__ZPROTO4(FILE,*,_freopen1,const char *,name, int, fd, const char *,mode, FILE *,fp)
__ZPROTO3(FILE,*,fmemopen,void *,buf, size_t, size, const char *,mode)

// Leaving this one, it's complicated
#ifndef __STDC_ABI_ONLY
extern FILE __LIB__ *funopen(const void     *cookie, int (*readfn)(void *, char *, int),
                    int (*writefn)(void *, const char *, int),
                    fpos_t (*seekfn)(void *, fpos_t, int), int (*closefn)(void *)) __smallc;
#endif

#if defined(__LLVMZ80)
/* ravn/llvm-z80: _fclose is a __smallc stack worker; clang would pass fp in HL.
 * __smallc makes clang push fp so the stack read matches.  sccz80/sdcc keep
 * the plain declaration below. */
extern int __LIB__  fclose(FILE *fp) __smallc;
#else
extern int __LIB__  fclose(FILE *fp);
#endif
extern int __LIB__  fflush(FILE *);
#if defined(__LLVMZ80)
/* ravn/llvm-z80: the classic clib's _fflush is __smallc (fetches its FILE*
 * off the stack), but clang passes it in HL -> the worker reads stack garbage
 * and corrupts SP, making the program restart in a loop at exit.  Route to a
 * register-ABI wrapper (libsrc/l/llvmz80/__fflush.asm).  sccz80/sdcc unaffected. */
extern int __LIB__  fflush_fastcall(FILE *) __z88dk_fastcall;
#define fflush(a) fflush_fastcall(a)
#endif

extern void __LIB__ closeall(void);



/* --------------------------------------------------------------*/
/* Optimized stdio uses the 'CALLEE' convention here and there   */

__ZPROTO3(char,*,fgets,char *,s,int,l,FILE *,fp)

#if defined(__LLVMZ80)
/* ravn/llvm-z80: same register-vs-stack mismatch as fopen/fread (the generic
 * __ZPROTO2 clang branch calls the classic worker ___fputs with args in HL/DE,
 * but _fputs is a __smallc stack worker: it does `pop bc=fp / pop de=s`).  The
 * register call left BC/DE holding a garbage FILE*, ix was set from it and the
 * subsequent write corrupted SP -> warm-boot restart loop.  Bind straight to
 * the classic worker via a reversed-param __smallc prototype: clang's
 * sdcccall(0) push puts the FIRST declared param on top, and _fputs reads fp
 * from the top, so declaring fp first reproduces the exact stack frame the
 * worker wants; clang caller-cleans (matching the worker) and moves the HL
 * return into DE itself -- no asm bridge needed.  Verified: fputs("BC",f)
 * returns 1 and the bytes read back as B,C.  See
 * libsrc/l/llvmz80/CALLING_CONVENTION.md.  sccz80/sdcc keep __ZPROTO2. */
extern int __LIB__ __fputs_llvmz80(FILE *fp, const char *s) __asm__("fputs") __smallc;
#define fputs(s,fp) __fputs_llvmz80(fp,s)
#else
__ZPROTO2(int,,fputs,const char *,s,FILE *,fp)
#endif
#ifndef __STDC_ABI_ONLY
extern int __LIB__  fputs_callee(const char *s,  FILE *fp) __smallc __z88dk_callee;
#define fputs(a,b)   fputs_callee(a,b)
#endif



extern int __LIB__ fputc(int c, FILE *fp) __smallc;
#ifndef __STDC_ABI_ONLY
extern int __LIB__  fputc_callee(int c, FILE *fp) __smallc __z88dk_callee;
#define fputc(a,b)   fputc_callee(a,b)
#define putc(bp,fp) fputc_callee(bp,fp)
#define putchar(bp) fputc_callee(bp,stdout)
#else
// clang expects putchar to be a library function not just a macro.
// __smallc carries the stack calling convention (sdcccall(0)) so clang pushes
// the argument instead of leaving it in HL -- without it console output is
// corrupted (see include/sys/compiler.h).
extern int __LIB__ putchar(int) __smallc;
#define putc(bp,fp) fputc(bp,fp)
#endif

extern int __LIB__ fgetc(FILE *fp) __smallc;
#define getc(f) fgetc(f)

__ZPROTO2(int,,ungetc,int,c,FILE *,fp)

extern int __LIB__ feof(FILE *fp);
#ifndef __STDC_ABI_ONLY
extern int __LIB__ feof_fastcall(FILE *fp) __z88dk_fastcall;
#define feof(f) feof_fastcall(f)
#endif


extern int __LIB__ ferror(FILE *fp);
#ifndef __STDC_ABI_ONLY
extern int __LIB__ ferror_fastcall(FILE *fp) __z88dk_fastcall;
#define ferror(f) ferror_fastcall(f)
#endif

extern int __LIB__ puts(const char *) __smallc;

#ifdef __STDC_ABI_ONLYe

#endif
#define getchar()  fgetc(stdin)


/* Routines for file positioning */
#if defined(__LLVMZ80)
extern fpos_t __LIB__ ftell(FILE *fp) __smallc;
#else
extern fpos_t __LIB__ ftell(FILE *fp);
#endif
__ZPROTO2(int,,fgetpos,FILE *,fp,fpos_t *, pos)


#if defined(__LLVMZ80)
/* classic _fseek is __smallc (stack), worker fseek(fp,offset,whence); the
 * __STDC_ABI_ONLY branch below routes clang to a register low-level (___fseek)
 * that does not match.  Bind the reversed-param low-level to the GLOBAL worker
 * so clang's __smallc push order reproduces the worker's stack frame. */
extern int __LIB__ __fseek_llvmz80(int whence, fpos_t offset, FILE *fp) __asm__("fseek") __smallc;
#define fseek(fp,offset,whence) __fseek_llvmz80(whence,offset,fp)
#elif !defined(__STDC_ABI_ONLY)
extern int __LIB__ __SAVEFRAME__ fseek(FILE *fp, fpos_t offset, int whence) __smallc;
#else
__ZPROTO3(int,,fseek,FILE *,fp,fpos_t,offset,int,whence)
#endif
#define fsetpos(fp,pos) fseek(fp,pos,SEEK_SET)
#define rewind(fp) fseek(fp,0L,SEEK_SET)


/* Block read/writing */
#if defined(__LLVMZ80)
/* ravn/llvm-z80: the classic clib workers _fread/_fwrite are __smallc
 * (sdcccall(0)) and read every arg off the stack with (deepest..top)
 * ptr,size,nmemb,fp -- i.e. fp on top.  The generic __ZPROTO4 clang branch
 * instead declares a register-ABI low-level (___fread/___fwrite) that nothing
 * defines, so fread/fwrite failed to link.  Bind straight to the classic
 * worker via a reversed-param __smallc prototype: clang's sdcccall(0) push
 * puts the FIRST declared param on top, so declaring fp first reproduces the
 * exact stack layout the worker wants, clang caller-cleans (matching the
 * worker) and moves the HL return into DE itself -- no asm bridge needed.
 * See libsrc/l/llvmz80/CALLING_CONVENTION.md.  sccz80/sdcc keep __ZPROTO4. */
extern int __LIB__ __fread_llvmz80(FILE *fp, size_t num, size_t size, void *ptr) __asm__("fread") __smallc;
extern int __LIB__ __fwrite_llvmz80(FILE *fp, size_t num, size_t size, void *ptr) __asm__("fwrite") __smallc;
#define fread(ptr,size,num,fp)  __fread_llvmz80(fp,num,size,ptr)
#define fwrite(ptr,size,num,fp) __fwrite_llvmz80(fp,num,size,ptr)
#else
__ZPROTO4(int,,fread,void *,ptr,size_t,size,size_t,num,FILE *,fp)
__ZPROTO4(int,,fwrite,void *,ptr,size_t,size,size_t,num,FILE *,fp)
#endif


extern char __LIB__ *gets(char *s);

extern int __LIB__ printf(const char *fmt,...) __vasmallc;
extern int __LIB__ fprintf(FILE *f,const char *fmt,...) __vasmallc;
extern int __LIB__ sprintf(char *s,const char *fmt,...) __vasmallc;
extern int __LIB__ snprintf(char *s,size_t n,const char *fmt,...) __vasmallc;
#if defined(__LLVMZ80)
/* ravn/llvm-z80: _vfprintf/_vsnprintf are __smallc stack workers returning the
 * count in HL; clang's default sdcccall(1) would pass leading args in HL/DE and
 * read the return from DE (empty buf + garbage count).  __smallc marshals all
 * args on the stack (natural order: first arg on top, matching the workers) and
 * reads HL.  Verified GREEN: a va_start/vsnprintf/va_end wrapper formats
 * strings/ints/chars correctly with the right return count. */
extern int __LIB__ vfprintf(FILE *f,const char *fmt,void *ap) __smallc;
extern int __LIB__ vsnprintf(char *str, size_t n,const char *fmt,void *ap) __smallc;
#else
extern int __LIB__ vfprintf(FILE *f,const char *fmt,void *ap);
extern int __LIB__ vsnprintf(char *str, size_t n,const char *fmt,void *ap);
#endif

#define vprintf(ctl,arg) vfprintf(stdout,ctl,arg)
#define vsprintf(buf,ctl,arg) vsnprintf(buf,65535,ctl,arg)

#if defined(__LLVMZ80) && defined(__LLVMZ80_IEEE_PRINTF)
/* ravn/llvm-z80: opt-in transparent IEEE-754 printf.
 *
 * Define __LLVMZ80_IEEE_PRINTF (e.g. `zcc ... -D__LLVMZ80_IEEE_PRINTF`, or
 * `#define __LLVMZ80_IEEE_PRINTF` before <stdio.h>) and stock
 * printf/fprintf/sprintf/snprintf route through the nanoprintf-backed shim in
 * softfloat_cpm_z80.lib, so plain `printf("%f", x)` prints correct IEEE
 * binary64 (stock z88dk printf formats z88dk's math48, giving garbage for
 * clang's doubles).  Every other specifier (%d/%s/%x/%c/%o/%u/precision/width)
 * is also handled by nanoprintf.
 *
 * NOT the default: routing pulls ~3 KB of nanoprintf, and the shim lives in the
 * softfloat archive (auto-linked only when LLVMZ80RTLIB is set).  A double
 * program already links that archive, so `%f` users pay nothing extra to opt
 * in; leaving it off keeps integer-only printf programs (which may not link the
 * softfloat lib) unaffected.  See llvmz80-softfloat/src/npf_printf.c. */
extern int __llvmz80_printf(const char *fmt, ...);
extern int __llvmz80_fprintf(FILE *f, const char *fmt, ...);
extern int __llvmz80_sprintf(char *s, const char *fmt, ...);
extern int __llvmz80_snprintf(char *s, size_t n, const char *fmt, ...);
#define printf   __llvmz80_printf
#define fprintf  __llvmz80_fprintf
#define sprintf  __llvmz80_sprintf
#define snprintf __llvmz80_snprintf
#endif


// Some far variants of functions
#ifdef __SCCZ80
extern int __LIB__ sprintff(char *__far s,const char *fmt,...) __vasmallc;
extern int __LIB__ snprintff(char *__far s,size_t n,const char *fmt,...) __vasmallc;
extern int __LIB__ vsnprintff(char *__far str, size_t n,const char *fmt,void *ap);
#define vsprintff(buf,ctl,arg) vsnprintff(buf,65535,ctl,arg)

#endif

/* Routines used by the old printf - will be removed soon */
extern void __LIB__ printn(int number, int radix,FILE *file) __smallc;


/*
 * Scanf family 
 */

extern int __LIB__ scanf(const char *fmt,...) __vasmallc;
extern int __LIB__ fscanf(FILE *,const char *fmt,...) __vasmallc;
extern int __LIB__ sscanf(char *,const char *fmt,...) __vasmallc;
#if defined(__LLVMZ80)
/* ravn/llvm-z80: same __smallc bridge as the vfprintf family above.  Verified
 * GREEN: a va_start/vsscanf/va_end wrapper parses "%d %d" into the caller's
 * variables with the right conversion count. */
extern int __LIB__ vfscanf(FILE *, const char *fmt, void *ap) __smallc;
extern int __LIB__ vsscanf(char *str, const char *fmt, void *ap) __smallc;
#else
extern int __LIB__ vfscanf(FILE *, const char *fmt, void *ap); 
extern int __LIB__ vsscanf(char *str, const char *fmt, void *ap);
#endif
#define vscanf(ctl,arg) vfscanf(stdin,ctl,arg)


/*
 * Used in variable argument lists
 */

#ifndef DEF_GETARG
#define DEF_GETARG
extern int __LIB__ getarg(void);
#endif


/* Check whether a file is for the console */
extern int __LIB__ fchkstd(FILE *);

/* All functions below here are machine specific */

/* Get a key press using the default keyboard driver */
extern int __LIB__ fgetc_cons(void);

/* Get a key press using the "inkey" keyboard driver */
extern int __LIB__ fgetc_cons_inkey(void);

/* Output a character to the console using the default driver */
extern int __LIB__ fputc_cons(char c);

/* Read a string using the default keyboard driver */
__ZPROTO2(char,*,fgets_cons,char *,s,size_t,n)

extern int __LIB__ puts_cons(char *s);

/* Abandon file - can be the generic version */
extern void __LIB__ fabandon(FILE *);
/* Get file position for file handle fd */
extern long __LIB__ fdtell(int fd);
__ZPROTO2(int,,fdgetpos,int,fd,fpos_t *,pos)
/* Rename a file */
#if defined(__LLVMZ80)
/* classic worker is rename(oldname,newname), __smallc (stack, first arg on top).
 * Reverse the low-level params so clang's __smallc push order lands oldname on
 * top, matching the worker. */
extern int __LIB__ __rename_llvmz80(const char *d, const char *s) __asm__("rename") __smallc;
#define rename(s,d) __rename_llvmz80(d,s)
#else
__ZPROTO2(int,,rename,const char *,s,const char *,d)
#endif
/* Remove a file */
#if defined(__LLVMZ80)
extern int __LIB__ remove(const char *name) __smallc;
#else
extern int __LIB__ remove(const char *name);
#endif


/* Scan for a keypress using the default keyboard driver */
extern int __LIB__ getk(void);
/* Scan for a keypress using the "inkey" keyboard driver */
extern int __LIB__ getk_inkey(void);
#define getkey() fgetc_cons()

/* Print a formatted string directly to the console using the default driver */
extern int __LIB__ printk(const char *fmt,...) __vasmallc;

/* Error handler (mostly an empty fn) */
extern void __LIB__ perror(const char *msg) __z88dk_fastcall;


/* We have multiple methods of outputting a character to the console.
   Normally they are setup at the linking stage, but sometimes we may
   need multiple methods linked into the program (for example systems
   with a serial port and a graphics card).
 */

typedef int (*fputc_cons_func)(char c);
/* Set the fputc_cons implementation, return the old one */
extern fputc_cons_func __LIB__ set_fputc_cons(fputc_cons_func func);

/* Implementation that uses the ROM/firmware */
extern int __LIB__ fputc_cons_native(char c);
/* Implementation that uses the generic console */
extern int __LIB__ fputc_cons_generic(char c);
/* Implementation that uses the ansi terminal */
extern int __LIB__ fputc_cons_ansi(char c);


/*
 *  MICRO C compatibility:  keep at bottom of this file
 *  Some of Dunfield's Micro C code can be ported with the '-DMICROC' parameter
 */

#ifdef MICROC
#include <microc.h>
#endif

#endif /* _STDIO_H */
