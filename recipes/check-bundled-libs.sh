#!/usr/bin/env bash
# Lists the zlib and expat versions that binaries carry, found the way the OpenMS
# release check finds them: zlib's "deflate/inflate x.y.z Copyright" strings and
# its ZLIB_VERSION string, and expat's "expat_x.y.z" string. Fails if one of them
# names another version than versions.env.
#
# An MSVC build keeps only the code it uses, which may leave none of these strings
# in the executable; pass the static libraries it was linked from as well.
#
# usage: check-bundled-libs.sh <binary or library>...
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source-path=SCRIPTDIR source=versions.env
. "$here/versions.env"

printable() { # like "strings -a", which Git Bash on Windows does not have
  if command -v strings > /dev/null; then
    strings -a "$1"
  else
    "${PYTHON:-python3}" -c 'import re, sys
for s in re.findall(rb"[\t\x20-\x7e]{4,}", open(sys.argv[1], "rb").read()):
    print(s.decode())' "$1"
  fi
}

status=0
for file in "$@"; do
  echo "== $file"
  # zlib's ZLIB_VERSION is a bare "1.x.y" string, which other version numbers can
  # be as well; such a string fails the check only if it is the version of a zlib
  # that the upstream binaries bundled
  markers=$(printable "$file" | grep -oE '(de|in)flate [0-9][0-9.]* Copyright|expat_[0-9][0-9.]*|^1\.[0-9]\.[0-9]+(\.[0-9]+)?$' | sort | uniq -c || true)
  if [ -z "$markers" ]; then
    echo "   no zlib or expat version string"
    continue
  fi
  while read -r count marker; do
    case $marker in
      "deflate $ZLIB_VERSION Copyright" | "inflate $ZLIB_VERSION Copyright" | "$ZLIB_VERSION") verdict="zlib $ZLIB_VERSION" ;;
      "expat_$EXPAT_VERSION") verdict="expat $EXPAT_VERSION" ;;
      *flate* | 1.2.3 | 1.2.11) verdict="NOT zlib $ZLIB_VERSION"; status=1 ;;
      expat_*) verdict="NOT expat $EXPAT_VERSION"; status=1 ;;
      *) verdict="(another version string)" ;;
    esac
    printf '   %3s x %-28s %s\n' "$count" "$marker" "$verdict"
  done <<< "$markers"
done
exit $status
