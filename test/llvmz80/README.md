# llvmz80 integration tests

These tests cover the `-compiler=llvmz80` path and its direct use of z88dk
math32. Run one test directly, for example:

```sh
sh test/llvmz80/runtime_float.sh
```

The master integration runner includes both `test/clang` and `test/llvmz80`:

```sh
sh test/clang/run_all.sh
```

To run the suite for multiple z88dk C libraries, use
`sh test/clang/run_matrix.sh [classic newlib_iy ...]`. The default matrix is
`classic newlib_iy`.
