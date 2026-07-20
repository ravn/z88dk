#!/bin/sh
# Regression test for ravn/z88dk#15 (sdcc-macos-aarch64-z88dk.patch).
#
# The patched zsdcc should NOT print "Mac OS X ppc" in its version
# banner on Apple Silicon hosts.  Pre-patch, the upstream SDCC's
# getBuildEnvironment() in src/SDCCutil.c falls through to "Mac OS X
# ppc" for any non-Intel Apple platform (an artefact of the PowerPC
# era).  The patch adds an __aarch64__ branch and modernises the OS
# name to "macOS".
#
# This is a host-platform test — only meaningful on macOS Apple
# Silicon.  Skips silently on other platforms.

set -e

# Locate zsdcc relative to this test file.
TEST_DIR=$(cd "$(dirname "$0")" && pwd)
ZSDCC="${ZSDCC:-$TEST_DIR/../../../bin/z88dk-zsdcc}"

if [ ! -x "$ZSDCC" ]; then
    echo "SKIP: zsdcc not found at $ZSDCC"
    exit 0
fi

# Only meaningful on macOS aarch64.
UNAME_S=$(uname -s)
UNAME_M=$(uname -m)
if [ "$UNAME_S" != "Darwin" ] || [ "$UNAME_M" != "arm64" ]; then
    echo "SKIP: not macOS aarch64 (running on $UNAME_S $UNAME_M)"
    exit 0
fi

BANNER=$("$ZSDCC" --version 2>&1 | head -3)

# Pre-fix bug: banner contains "Mac OS X ppc".
if echo "$BANNER" | grep -q "Mac OS X ppc"; then
    echo "FAIL: zsdcc banner reports 'Mac OS X ppc' on macOS aarch64."
    echo "$BANNER"
    exit 1
fi

# Post-fix expectation: banner mentions "macOS" with the correct arch.
if echo "$BANNER" | grep -q "macOS aarch64"; then
    echo "PASS: zsdcc banner reports macOS aarch64 correctly."
    exit 0
fi

# Any other banner that doesn't say "Mac OS X ppc" is acceptable too
# (e.g. if SDCC upstream adopted a different scheme).
echo "PASS: zsdcc banner does not report 'Mac OS X ppc' (banner: $BANNER)"
exit 0
