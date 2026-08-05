# stdcbench cross-compiler sweep wrapper.  See README.md.
# Requires: LLVMZ80EXE set (llvmz80 lanes), zcc + z88dk-ticks on PATH, ntvcm
# (or NTVCM=/path/to/ntvcm).

NTVCM ?= ntvcm

.PHONY: sweep sweep-all components clean

sweep:
	NTVCM=$(NTVCM) ./compare.sh

sweep-all:
	NTVCM=$(NTVCM) MODULES=all ./compare.sh

# Per-component breakdown: isolates each sub-benchmark so you can see where a
# compiler's cycles go (the parts reconcile to the whole-suite number).
components:
	NTVCM=$(NTVCM) ./component_timing.sh

clean:
	rm -rf build
