#!/bin/sh
# Run all ravn/z88dk-specific zsdcc regression tests.
#
# Each test self-skips if prerequisites are missing (zcc, zsdcc,
# z88dk-ticks, host platform).  Exit code reflects whether any test
# failed; SKIPs don't count as failures.

set -e

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$TEST_DIR"

FAILED=0
RAN=0

for t in test_*.sh run_test_*.sh; do
    [ -x "$t" ] || continue
    RAN=$((RAN + 1))
    printf "%-40s " "$t"
    if "./$t" > /tmp/zsdcc_test_$$.log 2>&1; then
        cat /tmp/zsdcc_test_$$.log | tail -1
    else
        cat /tmp/zsdcc_test_$$.log | tail -3
        FAILED=$((FAILED + 1))
    fi
done
rm -f /tmp/zsdcc_test_$$.log

echo "---"
if [ "$FAILED" -eq 0 ]; then
    echo "ALL OK: $RAN test(s) ran, no failures"
    exit 0
else
    echo "FAILED: $FAILED of $RAN tests"
    exit 1
fi
