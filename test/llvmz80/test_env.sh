#!/bin/sh
# Reuse the shared z88dk/llvm-z80 toolchain discovery.
_DIR=$(cd "$(dirname "$0")" && pwd)
. "$_DIR/../clang/test_env.sh"
