#!/usr/bin/env bash
# Fetches the sources named in versions.env into <dest> and checks them:
# the tarballs against their SHA-256, the git sources against the pinned
# commits (and the commits against their upstream tags).
#
# usage: fetch-sources.sh <dest> <source>...
#   zlib, expat             the release tarballs
#   comet, maracluster      the engine sources
#   pwiz                    ProteoWizard without its vendor APIs, like its pwiz-src-without-tv tarball
#   pwiz-with-vendor-apis   ProteoWizard with its vendor APIs, like its pwiz-src-without-t tarball
#   openms-testdata         the OpenMS test data that the scripts in compare/ use
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source-path=SCRIPTDIR source=versions.env
. "$here/versions.env"

dest=$1
shift
mkdir -p "$dest"
cd "$dest"

sha256() {
  if command -v sha256sum > /dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

download() { # <url> <sha256>
  local file=${1##*/}
  curl -fsSL --retry 3 -o "$file" "$1"
  local got
  got=$(sha256 "$file")
  if [ "$got" != "$2" ]; then
    echo "$file: SHA-256 is $got, expected $2" >&2
    exit 1
  fi
  echo "$file: SHA-256 $got as expected"
}

# a shallow checkout of <commit>; with a tag, the tag must name that commit
init_repo() { # <repo> <dir> [line ends: as-committed (default) | platform]
  git init -q "$2"
  if [ "${3:-as-committed}" = as-committed ]; then
    # also on Windows, so that the patches apply and indexed mzML files keep their offsets
    git -C "$2" config core.autocrlf false
  fi
  git -C "$2" remote add origin "$1"
}
checkout() { # <dir> <commit> [<tag>]
  if [ -n "${3:-}" ]; then
    local refs tagged
    refs=$(git -C "$1" ls-remote --tags origin "refs/tags/$3")
    # an annotated tag is listed twice; its "^{}" line names the commit
    tagged=$(printf '%s\n' "$refs" | awk -v t="refs/tags/$3^{}" '$2 == t { print $1 }')
    [ -n "$tagged" ] || tagged=$(printf '%s\n' "$refs" | awk -v t="refs/tags/$3" '$2 == t { print $1 }')
    if [ "$tagged" != "$2" ]; then
      echo "$1: tag $3 is at ${tagged:-nothing}, expected $2" >&2
      exit 1
    fi
  fi
  git -C "$1" fetch -q --depth 1 "${@:4}" origin "$2"
  git -C "$1" -c advice.detachedHead=false checkout -q FETCH_HEAD
  test "$(git -C "$1" rev-parse HEAD)" = "$2"
  echo "$1: $2${3:+ ($3)}"
}

# ProteoWizard's source tarballs leave out the example data, some of the .NET
# applications and libraries, the tests (Jamroot.jam: .pwiz-src-exclusions, .l,
# .no-t), and pwiz-src-without-tv the vendor APIs (.no-v). The tests have to go: those
# of the vendor readers cannot be built without the vendor APIs, and b2 then
# skips everything that depends on them, among it the "libraries" target.
pwiz() { # <with vendor APIs: yes|no>
  init_repo "$PWIZ_REPO" pwiz platform  # CRLF for the batch files on Windows, as ProteoWizard's own builds have them
  git -C pwiz sparse-checkout init --no-cone
  {
    echo '/*'
    echo '!/example_data/'
    # of libraries/, the tarballs have only what the libraries build needs
    for f in arrow/ 7zz readme.txt expat-*.tar.bz2 fftw-*.tar.bz2 msvc-2005-2008-runtime.tar.bz2; do
      echo "!/libraries/$f"
    done
    for f in BiblioSpec Skyline Bumbershoot Shared/BiblioSpec Shared/Crawdad Shared/ProteomeDb \
             Shared/Lib/Microsoft.Diagnostics.Runtime Shared/Lib/MSAmanda Shared/Lib/DotNetZip \
             Shared/Lib/NHibernate Shared/Lib/npgsql Shared/Lib/x86 Shared/Lib/x64 'Shared/Lib/mysql.*' \
             'Shared/Lib/zlib.*' 'Shared/Lib/*.pdb' 'Shared/Lib/grpc*' 'Shared/Lib/log4net*' \
             'Shared/Lib/MathNet.Numerics*'; do
      echo "!/pwiz_tools/$f"
    done
    echo '!*Test*.data*'
    echo '!*Test.?pp'
    echo '!*TestData.?pp'
    if [ "$1" = no ]; then
      echo '!/libraries/msparser_*.7z'
      echo '!/pwiz_aux/msrc/utility/vendor_api/*/'
      echo '!/pwiz_aux/msrc/utility/vendor_api_*.7z'
    fi
  } > pwiz/.git/info/sparse-checkout
  checkout pwiz "$PWIZ_COMMIT" "" --filter=blob:none
}

# the OpenMS test data that recipes/compare runs the engines on
openms_testdata() {
  init_repo "$OPENMS_REPO" openms
  git -C openms sparse-checkout init --no-cone
  {
    for f in CometAdapter_3.mzML CometAdapter_3.fasta CometAdapter_6_in.mzML spectra_comet.mzML proteins.fasta \
             MaRaClusterAdapter_1_in_1.mzML MaRaClusterAdapter_1_in_2.mzML; do
      echo "/src/tests/topp/THIRDPARTY/$f"
    done
    echo /share/OpenMS/examples/FRACTIONS/BSA1_F1.mzML
    echo /share/OpenMS/examples/TOPPAS/data/BSA_Identification/18Protein_SoCe_Tr_detergents_trace_target_decoy.fasta
  } > openms/.git/info/sparse-checkout
  checkout openms "$OPENMS_TESTDATA_COMMIT" "" --filter=blob:none
}

for source in "$@"; do
  case $source in
    zlib) download "$ZLIB_URL" "$ZLIB_SHA256" ;;
    expat) download "$EXPAT_URL" "$EXPAT_SHA256" ;;
    comet) init_repo "$COMET_REPO" comet && checkout comet "$COMET_COMMIT" "$COMET_TAG" ;;
    maracluster) init_repo "$MARACLUSTER_REPO" maracluster && checkout maracluster "$MARACLUSTER_COMMIT" "$MARACLUSTER_TAG" ;;
    pwiz) pwiz no ;;
    pwiz-with-vendor-apis) pwiz yes ;;
    openms-testdata) openms_testdata ;;
    *) echo "unknown source: $source" >&2; exit 1 ;;
  esac
done
