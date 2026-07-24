; __strerror_table.asm -- minimal errno string table for the z80 classic CP/M
; build under ravn/llvm-z80 clang.
;
; WHY THIS FILE EXISTS
;   asm_strerror (libsrc/string/z80/asm_strerror.asm) searches a table at
;   __rodata_error_strings_head for matching errno entries.  In the z88dk
;   newlib model that symbol is the start-address of the rodata_error_strings
;   linker section, which the newlib CRT defines (clib_rodata.inc line 14).
;   The classic CRT has no such section and therefore no such symbol, so any
;   program calling strerror() fails to link with:
;
;     string/z80/asm_strerror.asm:36: error: undefined symbol:
;     __rodata_error_strings_head
;
;   This TU provides the symbol and a minimal table covering all errno values
;   in z88dk's classic errno.h (EACCES..EWOULDBLOCK).  The table is small:
;   ~140 bytes, demand-loaded (only pulled in when strerror is actually called).
;
; TABLE FORMAT (per asm_strerror.asm search loop)
;   [errnum_byte][name_string][NUL]  (repeated for each defined errno)
;   [0x00]  (sentinel -- errnum 0 == EOK is handled before the search)
;
; ERRNO VALUES
;   From z88dk classic include/errno.h (NOT the newlib values, which differ):
;   EACCES=1 EBADF=2 EBDFD=3 EDOM=4 EFBIG=5 EINVAL=6 EMFILE=7 ENFILE=8
;   ENOLCK=9 ENOMEM=10 ENOTSUP=11 EOVERFLOW=12 ERANGE=13 ESTAT=14
;   EAGAIN=15 EWOULDBLOCK=16
;   NOTE: EIO is absent from the classic errno.h; ERANGE is mistyped as ANGE=13.
;   The table uses the numeric values directly.

; The table lives in code_l_clang (not rodata_error_strings) to avoid conflict
; with the linker's auto-generated __rodata_error_strings_head section-start
; symbol (present in newlib binary links).  asm_strerror only needs the symbol
; to exist and be a valid pointer to the table data; the section it lives in
; does not matter for correctness.
;
; This module is listed in libsrc/l/llvmz80.lst so it is assembled into the
; CLASSIC crt library z80_crt0.lib (llvmz80.lst is pulled by
; classic/z80_crt0s/newlib-z80.lst, which feeds z80_crt0.lib).  It is pulled
; on demand: asm_strerror (in cpm_clib) leaves __rodata_error_strings_head
; undefined, and the linker resolves it from this module.  There is no
; double-inclusion risk: no classic module declares "section
; rodata_error_strings", so z80asm generates no auto section-start symbol to
; clash with; and the clang NEWLIB CP/M route (-clib=newlib_iy) links with
; -nostdlib and never links z80_crt0.lib, so it keeps using newlib's own
; section-start symbol from lib/crt/newlib/clib_rodata.inc.  (An earlier comment
; here claimed this file was pulled via a buildcrt obj-glob and must NOT be in
; llvmz80.lst; that was wrong -- z80nm showed the module never reached the lib,
; which is exactly the strerror link failure this fixes.)
SECTION code_l_clang

PUBLIC __rodata_error_strings_head

__rodata_error_strings_head:

    defb 1  : defm "EACCES"     : defb 0
    defb 2  : defm "EBADF"      : defb 0
    defb 3  : defm "EBDFD"      : defb 0
    defb 4  : defm "EDOM"       : defb 0
    defb 5  : defm "EFBIG"      : defb 0
    defb 6  : defm "EINVAL"     : defb 0
    defb 7  : defm "EMFILE"     : defb 0
    defb 8  : defm "ENFILE"     : defb 0
    defb 9  : defm "ENOLCK"     : defb 0
    defb 10 : defm "ENOMEM"     : defb 0
    defb 11 : defm "ENOTSUP"    : defb 0
    defb 12 : defm "EOVERFLOW"  : defb 0
    defb 13 : defm "ERANGE"     : defb 0
    defb 14 : defm "ESTAT"      : defb 0
    defb 15 : defm "EAGAIN"     : defb 0
    defb 16 : defm "EWOULDBLOCK": defb 0
    defb 0  ; sentinel
