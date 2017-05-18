#!/bin/bash
#
# Usage:
#   ./spec-file.sh <function name>

set -o nounset
set -o pipefail
set -o errexit

readonly DASH=/bin/dash
readonly BASH=/bin/bash
readonly MKSH=/bin/mksh
readonly ZSH=/usr/bin/zsh  # Ubuntu puts it here
readonly BUSYBOX_ASH=_tmp/shells/ash

readonly OSH=bin/osh

# Run under the app bundle.
#readonly OSH=_bin/osh

# HACK that relies on word splitting
# TODO: Use ${OSH[@]} everywhere
#readonly OSH='bin/osh bin/opypy-osh'

# ash and dash are similar, so not including ash by default.  zsh is not quite
# POSIX.
readonly REF_SHELLS=($DASH $BASH $MKSH)

#
# Setup
#

# dash and bash should be there by default on Ubuntu.
install-shells() {
  sudo apt-get install busybox-static mksh zsh
  mkdir -p _tmp/shells
  ln -s -f --verbose /bin/busybox $BUSYBOX_ASH
}

_wget() {
  wget --no-clobber --directory _tmp/src "$@"
}

# As of March 2017
download-shell-source() {
  mkdir -p _tmp/src

  # https://tiswww.case.edu/php/chet/bash/bashtop.html - 9/2016 release
  # https://ftp.gnu.org/gnu/bash/
  _wget https://ftp.gnu.org/gnu/bash/bash-4.4.tar.gz

  # https://www.mirbsd.org/mksh.htm - no dates given
  _wget https://www.mirbsd.org/MirOS/dist/mir/mksh/mksh-R54.tgz

  # https://tracker.debian.org/pkg/dash  -- old versions
  # http://www.linuxfromscratch.org/blfs/view/svn/postlfs/dash.html
  # Site seems down now.
  # _wget http://gondor.apana.org.au/~herbert/dash/files/dash-0.5.9.1.tar.gz

  # http://zsh.sourceforge.net/News/ - 12/2016 release
  _wget https://downloads.sourceforge.net/project/zsh/zsh/5.3.1/zsh-5.3.1.tar.xz
}

maybe-show() {
  local path=$1
  if test -e $path; then
    echo "--- $path ---"
    cat $path
    echo
  fi
}

version-text() {
  date
  echo

  local branch=$(git rev-parse --abbrev-ref HEAD)
  local hash=$(git rev-parse $branch)
  echo "oil version: $hash on branch $branch"
  echo

  python3 --version 2>&1
  echo

  $BASH --version | head -n 1
  echo

  $ZSH --version | head -n 1
  echo

  # These don't have versions
  dpkg -s dash | egrep '^Package|Version'
  echo

  dpkg -s mksh | egrep '^Package|Version'
  echo

  # Need || true because of pipefail
  { busybox || true; } | head -n 1
  echo

  maybe-show /etc/debian_version
  maybe-show /etc/lsb-release
}

#
# Helpers
#

sh-spec() {
  local this_dir=$(cd $(dirname $0) && pwd)

  local tmp_env=$this_dir/../_tmp/spec-tmp
  mkdir -p $tmp_env

  test/sh_spec.py \
      --tmp-env $tmp_env \
      --path-env "$this_dir/../spec/bin:$PATH" \
      "$@"
}

#
# Misc
#

# Really what I want is enter(func) and exit(func), and filter by regex?
trace-var-sub() {
  local out=_tmp/coverage
  mkdir -p $out

  # This creates *.cover files, with line counts.
  #python -m trace --count -C $out \

  # This prints trace with line numbers to stdout.
  #python -m trace --trace -C $out \
  python -m trace --trackcalls -C $out \
    test/sh_spec.py spec/var-sub.test.sh $DASH $BASH "$@"

  ls -l $out
  head $out/*.cover
}

#
# Run All tests
#

all() {
  test/spec-runner.sh all-parallel "$@"
}


#
# Invidual tests.
#
# We configure the shells they run on and the number of allowed failures (to
# prevent regressions.)
#

smoke() {
  sh-spec spec/smoke.test.sh ${REF_SHELLS[@]} $OSH "$@"
}

# Regress bugs
bugs() {
  sh-spec spec/bugs.test.sh ${REF_SHELLS[@]} $OSH "$@"
}

blog1() {
  sh-spec spec/blog1.test.sh --osh-failures-allowed 4 \
    ${REF_SHELLS[@]} $ZSH $OSH "$@"
}

comments() {
  sh-spec spec/comments.test.sh ${REF_SHELLS[@]} $OSH "$@"
}

word-split() {
  sh-spec spec/word-split.test.sh --osh-failures-allowed 3 \
    ${REF_SHELLS[@]} $OSH "$@"
}

word-eval() {
  sh-spec spec/word-eval.test.sh \
    ${REF_SHELLS[@]} $OSH "$@"
}

# 'do' -- detected statically as syntax error?  hm.
assign() {
  sh-spec spec/assign.test.sh --osh-failures-allowed 1 \
    ${REF_SHELLS[@]} $OSH "$@" 
}

background() {
  sh-spec spec/background.test.sh --osh-failures-allowed 4 \
    ${REF_SHELLS[@]} $OSH "$@" 
}


# Need to fix $ tokens, and $''
quote() {
  sh-spec spec/quote.test.sh --osh-failures-allowed 4 \
    ${REF_SHELLS[@]} $OSH "$@"
}

loop() {
  sh-spec spec/loop.test.sh \
    ${REF_SHELLS[@]} $OSH "$@"
}

# Not implemented in osh at all.  Need glob matching of words.
case_() {
  sh-spec spec/case_.test.sh --osh-failures-allowed 2 \
    ${REF_SHELLS[@]} $OSH "$@"
}

if_() {
  sh-spec spec/if_.test.sh --osh-failures-allowed 2 \
    ${REF_SHELLS[@]} $ZSH $OSH "$@"
}

# NOTE: osh uses external test!  But that's OK for now.
test-builtin() {
  sh-spec spec/test-builtin.test.sh ${REF_SHELLS[@]} $OSH "$@"
}

builtins() {
  sh-spec spec/builtins.test.sh --osh-failures-allowed 3 \
    ${REF_SHELLS[@]} $OSH "$@"
}

builtins-special() {
  sh-spec spec/builtins-special.test.sh --osh-failures-allowed 1 \
    ${REF_SHELLS[@]} $OSH "$@"
}

command-parsing() {
  sh-spec spec/command-parsing.test.sh ${REF_SHELLS[@]} $OSH "$@"
}

func-parsing() {
  sh-spec spec/func-parsing.test.sh ${REF_SHELLS[@]} $OSH "$@"
}

func() {
  sh-spec spec/func.test.sh --osh-failures-allowed 1 \
    ${REF_SHELLS[@]} $OSH "$@"
}

glob() {
  sh-spec spec/glob.test.sh --osh-failures-allowed 2 \
    ${REF_SHELLS[@]} $BUSYBOX_ASH $OSH "$@"
}

arith() {
  sh-spec spec/arith.test.sh --osh-failures-allowed 9 \
    ${REF_SHELLS[@]} $ZSH $OSH "$@"
}

# pysh failures: case not implemented
command-sub() {
  sh-spec spec/command-sub.test.sh --osh-failures-allowed 3 \
    ${REF_SHELLS[@]} $OSH "$@"
}

pipeline() {
  sh-spec spec/pipeline.test.sh --osh-failures-allowed 2 \
    ${REF_SHELLS[@]} $ZSH $OSH "$@"
}

explore-parsing() {
  sh-spec spec/explore-parsing.test.sh --osh-failures-allowed 5 \
    ${REF_SHELLS[@]} $OSH "$@"
}

here-doc() {
  # NOTE: The last two tests, 28 and 29, have different behavior on my Ubuntu
  # and Debian machines.
  # - On Ubuntu, read_from_fd.py fails with Errno 9 -- bad file descriptor.
  # - On Debian, the whole process hangs.
  # Is this due to Python 3.2 vs 3.4?  Either way osh doesn't implement the
  # functionality, so it's probably best to just implement it.
  sh-spec spec/here-doc.test.sh --osh-failures-allowed 8 --range 1-27 \
    ${REF_SHELLS[@]} $OSH "$@"
}

redirect() {
  # BUG: osh treats stdin as stdout!  Fix this.
  sh-spec spec/redirect.test.sh --osh-failures-allowed 11 \
    ${REF_SHELLS[@]} $OSH "$@"
}

posix() {
  sh-spec spec/posix.test.sh \
    ${REF_SHELLS[@]} $OSH "$@"
}

special-vars() {
  sh-spec spec/special-vars.test.sh --osh-failures-allowed 7 \
    ${REF_SHELLS[@]} $OSH "$@"
}

# DONE -- pysh is the most conformant!
tilde() {
  sh-spec spec/tilde.test.sh ${REF_SHELLS[@]} $OSH "$@"
}

var-op-test() {
  sh-spec spec/var-op-test.test.sh --osh-failures-allowed 5 \
    ${REF_SHELLS[@]} $OSH "$@"
}

var-op-other() {
  sh-spec spec/var-op-other.test.sh --osh-failures-allowed 5 \
    ${REF_SHELLS[@]} $OSH "$@"
}

var-op-strip() {
  sh-spec spec/var-op-strip.test.sh --osh-failures-allowed 4 \
    ${REF_SHELLS[@]} $OSH "$@"
}

var-sub() {
  # NOTE: ZSH has interesting behavior, like echo hi > "$@" can write to TWO
  # FILES!  But ultimately we don't really care, so I disabled it.
  sh-spec spec/var-sub.test.sh --osh-failures-allowed 2 \
    ${REF_SHELLS[@]} $OSH "$@"
}

var-num() {
  sh-spec spec/var-num.test.sh \
    ${REF_SHELLS[@]} $OSH "$@"
}

var-sub-quote() {
  sh-spec spec/var-sub-quote.test.sh \
    ${REF_SHELLS[@]} $OSH "$@"
}

sh-options() {
  sh-spec spec/sh-options.test.sh --osh-failures-allowed 3 \
    ${REF_SHELLS[@]} $OSH "$@"
}


# 
# Non-POSIX extensions: arrays, brace expansion, [[, ((, etc.
#

# There as many non-POSIX arithmetic contexts.
arith-context() {
  sh-spec spec/arith-context.test.sh --osh-failures-allowed 10 \
    $BASH $MKSH $ZSH $OSH "$@"
}

array() {
  sh-spec spec/array.test.sh --osh-failures-allowed 14 \
    $BASH $MKSH $OSH "$@"
}

array-compat() {
  sh-spec spec/array-compat.test.sh --osh-failures-allowed 3 \
    $BASH $MKSH $OSH "$@"
}

# += is not POSIX and not in dash.
append() {
  sh-spec spec/append.test.sh $BASH $MKSH "$@" 
}

# associative array -- mksh implements different associative arrays.
assoc() {
  sh-spec spec/assoc.test.sh $BASH "$@"
}

# ZSH also has associative arrays, which means we probably need them
assoc-zsh() {
  sh-spec spec/assoc-zsh.test.sh $ZSH "$@"
}

# NOTE: zsh passes about half and fails about half.  It supports a subset of [[
# I guess.
dbracket() {
  sh-spec spec/dbracket.test.sh --osh-failures-allowed 7 \
    $BASH $MKSH $OSH "$@"
  #sh-spec spec/dbracket.test.sh $BASH $MKSH $OSH $ZSH "$@"
}

dparen() {
  sh-spec spec/dparen.test.sh --osh-failures-allowed 4 \
    $BASH $MKSH $ZSH $OSH "$@"
}

brace-expansion() {
  # TODO for osh: implement num ranges, mark char ranges unimplemented?
  sh-spec spec/brace-expansion.test.sh --osh-failures-allowed 13 \
    $BASH $MKSH $ZSH $OSH "$@"
}

regex() {
  sh-spec spec/regex.test.sh --osh-failures-allowed 2 \
    $BASH $ZSH $OSH "$@"
}

process-sub() {
  # mksh and dash don't support it
  sh-spec spec/process-sub.test.sh --osh-failures-allowed 1 \
    $BASH $ZSH $OSH "$@"
}

extended-glob() {
  # Do NOT use dash here.  Brace sub breaks things.
  sh-spec spec/extended-glob.test.sh $BASH $MKSH "$@"
}

# ${!var} syntax -- oil should replace this with associative arrays.
var-ref() {
  sh-spec spec/var-ref.test.sh $BASH $MKSH "$@"
}

let() {
  sh-spec spec/let.test.sh $BASH $MKSH $ZSH "$@"
}

for-expr() {
  sh-spec spec/for-expr.test.sh --osh-failures-allowed 2 \
    $MKSH $BASH $OSH "$@"
}

# TODO: This is for the ANTLR grammars, in the oil-sketch repo.
# osh has infinite loop?
shell-grammar() {
  sh-spec spec/shell-grammar.test.sh $BASH $MKSH $ZSH "$@"
}

"$@"