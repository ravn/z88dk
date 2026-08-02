/*
 *      Small C+ Library
 *
 *      fnctl.h - low level file routines
 *
 *      djm 27/4/99
 *
 *	$Id: fcntl.h,v 1.21 2016-07-14 17:44:17 pauloscustodio Exp $
 */


#ifndef __FCNTL_H__
#define __FCNTL_H__

#include <sys/compiler.h>
#include <sys/types.h>


#define O_RDONLY  0
#define O_WRONLY  1
#define O_RDWR    2
#define O_APPEND  256
#define O_TRUNC   512
#define O_CREAT   1024

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2


/* O_BINARY has no significence */
#define O_BINARY  0

typedef int mode_t;

#if defined(__LLVMZ80)
/* clang/llvmz80: the target/test fcntl workers (open/read/write) are plain
 * stack-based smallc routines that read their three 16-bit args left-to-right
 * from the stack -- name at [sp+6] (deepest), flags at [sp+4], mode at [sp+2]
 * -- exactly the frame sccz80's __smallc produces. All three asm labels
 * (open/_open/___open) alias this ONE worker; there is no real register
 * bridge. __ZPROTO3's clang branch declares the reversed-arg ___open entry
 * with the DEFAULT convention (sdcccall(1): HL=1st, DE=2nd, stack=3rd), which
 * the stack worker does not honour -> garbage (open->245/fd=-1). Plain
 * __smallc on open() would push right-to-left, landing name at [sp+2] instead
 * of [sp+6] -> still wrong (fd=-1). The fix mirrors __ZPROTO3's own idiom
 * (reversed-arg entry + inline forwarder) but pins the entry to __smallc:
 * sdcccall(0) pushes the reversed params (mode,flags,name) right-to-left, so
 * name lands deepest at [sp+6] and the unmodified worker reads it correctly.
 * No asm change needed. */
extern int __LIB__ __open(mode_t mode, int flags, const char *name) __smallc;
__attribute__((always_inline)) __attribute__((overloadable))
__attribute__((enable_if(1, "")))
static inline int open(const char *name, int flags, mode_t mode) {
    return __open(mode, flags, name);
}
#else
__ZPROTO3(int,,open,const char *,name, int, flags, mode_t, mode)
#endif
__ZPROTO2(int,,creat,const char *,name,mode_t, mode)

extern int __LIB__ close(int fd);

#if defined(__LLVMZ80)
/* Same rationale as open() above: reversed-arg __smallc entry so the
 * unmodified stack workers see name/fd at [sp+6]. */
extern ssize_t __LIB__ __read(size_t len, void *ptr, int fd) __smallc;
__attribute__((always_inline)) __attribute__((overloadable))
__attribute__((enable_if(1, "")))
static inline ssize_t read(int fd, void *ptr, size_t len) {
    return __read(len, ptr, fd);
}
extern ssize_t __LIB__ __write(size_t len, void *ptr, int fd) __smallc;
__attribute__((always_inline)) __attribute__((overloadable))
__attribute__((enable_if(1, "")))
static inline ssize_t write(int fd, void *ptr, size_t len) {
    return __write(len, ptr, fd);
}
#else
__ZPROTO3(ssize_t,,read,int,fd,void *,ptr,size_t,len)
__ZPROTO3(ssize_t,,write,int,fd,void *,ptr,size_t,len)
#endif

#ifndef __STDC_ABI_ONLY
extern long __LIB__ __SAVEFRAME__ lseek(int fd,long posn, int whence) __smallc;
#else
__ZPROTO3(long,,lseek,int,fd,long,posn,int,whence)
#endif

extern int __LIB__ readbyte(int fd) __z88dk_fastcall;  // TODO: Clang
__ZPROTO2(int,,writebyte,int,fd,int,c)

extern int __LIB__ fsync(int fd);

/* mkdir is defined in sys/stat.h */
/* extern int __LIB__ mkdir(char *, int mode); */


__ZPROTO2(char,*,getcwd,char *,buf,size_t,newlen)
extern int __LIB__ chdir(const char *dir);
extern char __LIB__ *getwd(char *buf);

/* Following two only implemented for Sprinter ATM (20.11.2002) + esxdos */
extern int  __LIB__ rmdir(const char *);




/* ********************************************************* */

/*
* Default block size for "gendos.lib"
* every single block (up to 36) is written in a separate file
* the bigger RND_BLOCKSIZE, bigger can be the output file size,
* but this comes at the cost of the malloc'd space for the internal buffer.
* The current block size is kept in a control block (just the RND_FILE structure saved in a separate file),
* so changing this value at runtime before creating a file is perfectly legal.
*
* At linktime: -pragma-define:CLIB_RND_BLOCKSIZE=1000
*/

#ifndef RND_BLOCKSIZE
extern void *_RND_BLOCKSIZE;
#define RND_BLOCKSIZE (int)&_RND_BLOCKSIZE
#endif



/* Used in the generic random file access library only */
/* file will be split into blocks */

struct RND_FILE {
	char    name_prefix;   /* block name, including prefix char */
	char    name[15];         /* file name */
	i16_t	blocksize;
	unsigned char *blockptr;
	long    size;             /* file size */
	long    position;         /* current position in file */
	i16_t	pos_in_block;
	mode_t  mode;
};


/* The following three functions are target specific */
__ZPROTO3(int,,rnd_loadblock,char *,name,void *,loadstart,size_t,len)
__ZPROTO3(int,,rnd_saveblock,char *,name,void *,loadstart,size_t,len)

extern int  __LIB__  rnd_erase(char *name);
#ifndef __STDC_ABI_ONLY
extern int  __LIB__  rnd_erase_fastcall(char *name) __z88dk_fastcall;
#define rnd_erase(x) rnd_erase_fastcall(x)

#endif

/* ********************************************************* */

#endif /* _FCNTL_H */
