#!/bin/sh
# Exercise the real wrappers with tools that require an isolated working dir.
set -eu
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
WORK=$(mktemp -d "$Z80_TEST_TMPDIR/runtime-workdir.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/bin" "$WORK/runs"

cat >"$WORK/bin/zcc" <<'EOF'
#!/bin/sh
set -eu
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then
        shift
        printf '%s\n' "$(dirname "$1")" >>"$ISOLATION_LOG"
        [ "$ISOLATION_MODE" != build-fail ] || exit 1
        : >"$(dirname "$1")/RT.COM"
        exit 0
    fi
    shift
done
exit 1
EOF
cat >"$WORK/bin/ntvcm" <<'EOF'
#!/bin/sh
set -eu
# Refuse to create artifacts outside the per-run directory, even before fix.
[ "$PWD" = "$(dirname "$1")" ] || {
    echo "emulator cwd is not its per-run directory" >&2
    exit 1
}
printf 'hello\n' >A.DAT
printf XYZ >WP.DAT
printf 'ALL PASS\nPASS autoformat\nqsort -3,0,1,7,7\n'
printf 'fputs=6 OK\nfgets=hello OK\nungetc=104,h,h OK\nfgetpos=0,2 OK\nDONE\n'
printf 'open=1\nwrite=3\nclose=0\n'
[ "$ISOLATION_MODE" != runtime-fail ] || exit 1
EOF
chmod +x "$WORK/bin/zcc" "$WORK/bin/ntvcm"
ZCC="$WORK/bin/zcc"
NTVCM="$WORK/bin/ntvcm"
Z80_TEST_TMPDIR="$WORK/runs"
ISOLATION_LOG="$WORK/created"
export ZCC NTVCM Z80_TEST_TMPDIR ISOLATION_LOG

for test in runtime_float runtime_fconv runtime_fcmp runtime_fcmp_fast \
    runtime_libm runtime_printf_autoformat runtime_qsort_callback \
    issue22_stdio_abi issue23_fcntl_write
do
    for ISOLATION_MODE in pass build-fail runtime-fail; do
        export ISOLATION_MODE
        : >"$ISOLATION_LOG"
        status=0
        sh "$DIR/$test.sh" >"$WORK/output" 2>&1 || status=$?
        if [ "$ISOLATION_MODE" = pass ]; then
            [ "$status" -eq 0 ] && ! grep -q SKIP "$WORK/output" || {
                cat "$WORK/output"
                echo "FAIL: $test did not run successfully in isolation"
                exit 1
            }
        elif [ "$status" -eq 0 ]; then
            cat "$WORK/output"
            echo "FAIL: $test hid $ISOLATION_MODE"
            exit 1
        fi
        [ -s "$ISOLATION_LOG" ] || {
            echo "FAIL: $test did not invoke the build tool"
            exit 1
        }
        while IFS= read -r run; do
            [ ! -e "$run" ] || {
                echo "FAIL: $test left its temporary directory: $run"
                exit 1
            }
        done <"$ISOLATION_LOG"
    done
done
echo "PASS: runtime wrappers isolate files and clean up after success and failure"
