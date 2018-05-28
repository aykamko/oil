#!/usr/bin/env bash

set -o nounset
set -o pipefail
set -o errexit

# TODO: This changes depending on the version.  Maybe there should be a 'clang'
# function for things that really require clang, like code coverage and so
# forth.
readonly CLANG_DIR=$PWD/_deps/clang+llvm-5.0.1-x86_64-linux-gnu-ubuntu-16.04
readonly CLANG=$CLANG_DIR/bin/clang
readonly CLANGXX=$CLANG_DIR/bin/clang++

readonly CLANG_COV_FLAGS='-fprofile-instr-generate -fcoverage-mapping'
readonly CLANG_LINK_FLAGS=''

readonly PY27=Python-2.7.13

readonly PREPARE_DIR=_devbuild/cpython-full

# Used by scripts/run.sh and opy/build.sh
readonly OIL_SYMLINKS=(oil osh oshc sh wok boil true false)
readonly OPY_SYMLINKS=(opy opyc)

readonly UNAME=$(uname)

is_macos() {
  [[ "$UNAME" == "Darwin" ]] || return 1
}

if is_macos; then
  if ! brew --prefix coreutils >/dev/null >&1; then
    echo 'Please install Mac OS dependendies: build/dev.sh macos-deps' >&2
    exit 1
  fi

  readonly NPROC=$(sysctl -n hw.ncpu)
  readonly CPYTHON_PROG="$PREPARE_DIR/python.exe"
  readonly DATE_PROG=gdate
  readonly AWK_PROG="$(brew --prefix gawk 2>/dev/null)/bin/gawk"
  readonly TAR_PROG=gtar
else  # Linux
  readonly NPROC=$(nproc)
  readonly CPYTHON_PROG="$PREPARE_DIR/python"
  readonly DATE_PROG=date
  readonly AWK_PROG=awk
  readonly TAR_PROG=tar
fi


log() {
  echo "$@" >&2
}

die() {
  log "FATAL: $@"
  exit 1
}

source-detected-config-or-die() {
  if ! source _build/detected-config.sh; then
    # Make this error stand out.
    echo
    echo "FATAL: can't find _build/detected-config.h.  Run './configure'"
    echo
    exit 1
  fi
}
