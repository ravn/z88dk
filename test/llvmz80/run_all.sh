#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"

for test in "$DIR"/*.sh; do
    case "$test" in
        */run_all.sh|*/test_env.sh) continue ;;
    esac
    printf '\n==> %s\n' "$(basename "$test")"
    sh "$test"
done
