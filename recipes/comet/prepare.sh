#!/usr/bin/env bash
# Replaces the zlib 1.2.11 and expat 2.2.9 that Comet's MSToolkit bundles with
# the releases in versions.env. The patch points Comet's Makefiles and Visual
# Studio projects to them, and their release archives take the place of the old
# ones in MSToolkit/src, extracted next to them as the old ones were.
#
# usage: prepare.sh <Comet checkout> <folder with the zlib and expat archives>
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../versions.env
. "$here/../versions.env"

comet=$1
downloads=$(cd "$2" && pwd)
patch=$here/zlib-$ZLIB_VERSION-expat-$EXPAT_VERSION.patch  # written for these versions

cd "$comet"
test "$(git rev-parse HEAD)" = "$COMET_COMMIT"
git apply "$patch"

rm -r MSToolkit/src/expat-2.2.9 MSToolkit/src/zlib-1.2.11
rm MSToolkit/src/expat-2.2.9.tar.gz MSToolkit/src/zlib1211.zip
cp "$downloads/zlib-$ZLIB_VERSION.tar.gz" "$downloads/expat-$EXPAT_VERSION.tar.xz" MSToolkit/src/
tar -xzf "MSToolkit/src/zlib-$ZLIB_VERSION.tar.gz" -C MSToolkit/src
tar -xJf "MSToolkit/src/expat-$EXPAT_VERSION.tar.xz" -C MSToolkit/src

if [ "${OS:-}" = Windows_NT ]; then
  # The Visual Studio projects compile expat's sources into MSToolkitLite. Unlike
  # those of expat 2.2.9, they include expat_config.h also on Windows; this is the
  # one that expat's CMake build writes for MSVC.
  cmake -S "MSToolkit/src/expat-$EXPAT_VERSION" -B expat-config -A x64 -DEXPAT_SHARED_LIBS=OFF \
        -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_DOCS=OFF
  cp expat-config/expat_config.h "MSToolkit/src/expat-$EXPAT_VERSION/lib/"
fi

build_files="Makefile CometSearch/Makefile MSToolkit/Makefile MSToolkit/MAKEFILE.nmake MSToolkit/mstoolkitlite.mri
             Comet.vcxproj CometSearch/CometSearch.vcxproj CometWrapper/CometWrapper.vcxproj
             MSToolkit/MSToolkitLite.vcxproj MSToolkit/MSToolkitLite.vcxproj.filters"
# shellcheck disable=SC2086
if grep -n -e 'expat-2\.2\.9' -e 'zlib-1\.2\.11' -e 'zlib1211' $build_files; then
  echo "Comet's build files still refer to the bundled zlib 1.2.11 or expat 2.2.9" >&2
  exit 1
fi
ls -d MSToolkit/src/zlib-* MSToolkit/src/expat-*
