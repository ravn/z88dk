# LLVM-Z80 integration tests

Run the dedicated suite with:

```sh
make -C test llvmz80
```

The suite is separate from the default z88dk test targets because it requires
the llvm-z80 clang backend. `test_env.sh` uses `bin/zcc` when available,
otherwise `zcc` on `PATH`; it also discovers the workspace clang and ntvcm
builds. Set `ZCC`, `ZCCCFG`, `LLVMZ80EXE`, and `NTVCM` to override those
choices. Test artifacts are written under `Z80_TEST_TMPDIR` (default:
`scratch/tmp` in the workspace root). Each runtime test runs the emulator
inside its own temporary directory and removes that directory on exit,
including failed builds and runtime checks.

The llvmz80 driver defaults to `-fdefault-calling-conv=sdcccall0` for
unannotated program functions. Override it with
`-Cg-fdefault-calling-conv=sdcccall1`; user `-Cg` arguments follow the default.
This requires an llvm-z80 build supporting these option values. Explicit
library attributes and compiler runtime conventions retain their own ABIs.
Compile all program translation units with a consistent convention.
`zcc_backend_smoke` checks both option ordering and the emitted function ABI.

`issue22_stdio_abi` and `issue23_fcntl_write` restore the classic file-I/O
fixtures from `ravn-main:test/clang`. They create `A.DAT` (`hello\n`) and
`WP.DAT` (`XYZ`) only inside their per-run directories. `runtime_workdir`
checks the actual wrappers with substitute tools, including failed builds
and failed emulator runs, to guard working-directory isolation and cleanup.

The runner executes each `*.sh` test in this directory except the runner and
shared environment helper. Runtime scripts report `SKIP` when their required
tools are unavailable.

`z80asm_c_line_e2e` builds a debug-enabled CP/M Hello World with zcc and
z80asm, checks the source-line symbols in its map, and runs it in ntvcm.
It belongs here because it requires those external tools; the LLVM lit suite
retains the self-contained `llc`/`FileCheck` checks for `C_LINE` emission.
