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
`../scratch/tmp` from the workspace root).

The runner executes each `*.sh` test in this directory except the runner and
shared environment helper. Runtime scripts report `SKIP` when their required
tools are unavailable.
