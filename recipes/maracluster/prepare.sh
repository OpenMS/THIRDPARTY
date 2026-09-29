#!/usr/bin/env bash
# Prepares a MaRaCluster build with its own builder scripts (admin/builders)
# that uses zlib 1.3.2 instead of ProteoWizard's zlib 1.2.3, in ProteoWizard,
# in Boost and in MaRaCluster itself.
#
# The patch makes the builders take the ProteoWizard source tree that is already
# in <build dir>/tools/proteowizard (instead of the newest one from ProteoWizard's
# TeamCity server) and build it with --zlib-src pointing to zlib 1.3.2 in its
# libraries folder. This script puts the pinned ProteoWizard tree and zlib there,
# and removes ProteoWizard's zlib 1.2.3, so that nothing can use it.
#
# usage: prepare.sh <MaRaCluster checkout> <ProteoWizard checkout> <folder with the zlib archive> <build dir>
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../versions.env
. "$here/../versions.env"

maracluster=$1
pwiz=$2
downloads=$(cd "$3" && pwd)
build=$4

test "$(git -C "$maracluster" rev-parse HEAD)" = "$MARACLUSTER_COMMIT"
test "$(git -C "$pwiz" rev-parse HEAD)" = "$PWIZ_COMMIT"
git -C "$maracluster" apply "$here/pwiz-zlib-$ZLIB_VERSION.patch"  # written for this version

mkdir -p "$build/tools"
mv "$pwiz" "$build/tools/proteowizard"
libraries=$build/tools/proteowizard/libraries
rm "$libraries"/zlib-1.2.3.tar.bz2
tar -xzf "$downloads/zlib-$ZLIB_VERSION.tar.gz" -C "$libraries"
ls -d "$libraries"/zlib*

# ProteoWizard compiles zlib's sources without zlib's configure, which leaves
# zconf.h without <unistd.h>: gzlib.c, gzread.c and gzwrite.c then call lseek,
# read, write and close undeclared, an error for clang and a warning for GCC.
# Configure zlib as its own build does (Windows declares them in <io.h>).
if [ "${OS:-}" != Windows_NT ]; then
  (cd "$libraries/zlib-$ZLIB_VERSION" && ./configure > /dev/null)
  if grep -n 'HAVE_UNISTD_H-0' "$libraries/zlib-$ZLIB_VERSION/zconf.h"; then
    echo "zlib's configure did not find unistd.h" >&2
    exit 1
  fi
fi

# cmd.exe needs CRLF line ends to find the labels that the batch files call,
# as a checkout on Windows would give them
if [ "${OS:-}" = Windows_NT ]; then
  for f in "$maracluster"/admin/builders/*.bat; do
    sed -i -e 's/\r$//' -e 's/$/\r/' "$f"
  done
fi
