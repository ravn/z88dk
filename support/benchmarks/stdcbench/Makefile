# stdcbench cross-compiler sweep wrapper.  See README.md.
# Requires: LLVMZ80EXE set (llvmz80 lanes), zcc + z88dk-ticks on PATH, ntvcm
# (or NTVCM=/path/to/ntvcm).

NTVCM ?= ntvcm

.PHONY: sweep sweep-all clean

sweep:
	NTVCM=$(NTVCM) ./compare.sh

sweep-all:
	NTVCM=$(NTVCM) MODULES=all ./compare.sh

clean:
	rm -rf build
