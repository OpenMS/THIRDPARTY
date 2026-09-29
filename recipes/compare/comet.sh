#!/usr/bin/env bash
# Runs two Comet binaries on the same searches and compares all their outputs
# (txt, pepXML, mzIdentML, Percolator pin, SQT). The spectra come from OpenMS's
# test data, each as given (uncompressed), with zlib-compressed binary arrays,
# and gzipped, so that the searches go through expat and through zlib.
#
# usage: comet.sh <old comet> <new comet> <work dir> <OpenMS checkout>
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# the absolute path of a file
abs() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
# native paths for the params file (Git Bash on Windows)
native() { if command -v cygpath > /dev/null; then cygpath -m "$1"; else echo "$1"; fi; }
python=${PYTHON:-python3}

old=$(abs "$1")
new=$(abs "$2")
work=$3
openms=$(cd "$4" && pwd)
data=$openms/src/tests/topp/THIRDPARTY
examples=$openms/share/OpenMS/examples

searches=(
  "c3|$data/CometAdapter_3.mzML|$data/CometAdapter_3.fasta"
  "c6|$data/CometAdapter_6_in.mzML|$data/CometAdapter_3.fasta"
  "bsa|$examples/FRACTIONS/BSA1_F1.mzML|$examples/TOPPAS/data/BSA_Identification/18Protein_SoCe_Tr_detergents_trace_target_decoy.fasta"
  "spectra|$data/spectra_comet.mzML|$data/proteins.fasta"
)

mkdir -p "$work"
cd "$work"
"$old" -p > /dev/null  # writes comet.params.new
status=0
for search in "${searches[@]}"; do
  IFS='|' read -r name mzml fasta <<< "$search"
  mkdir -p "in/$name"
  cp "$mzml" "in/$name/plain.mzML"
  "$python" "$here/mzml-zlib.py" "$mzml" "in/$name/zlib.mzML"
  gzip -c "$mzml" > "in/$name/gz.mzML.gz"
  sed -e "s|^database_name = .*|database_name = $(native "$fasta")|" \
      -e 's|^decoy_search = .*|decoy_search = 1|' \
      -e 's|^num_threads = .*|num_threads = 4|' \
      -e 's|^output_sqtfile = .*|output_sqtfile = 1|' \
      -e 's|^output_txtfile = .*|output_txtfile = 1|' \
      -e 's|^output_mzidentmlfile = .*|output_mzidentmlfile = 1|' \
      -e 's|^output_percolatorfile = .*|output_percolatorfile = 1|' \
      comet.params.new > "in/$name/comet.params"
  for variant in plain zlib gz; do
    input=$(cd "in/$name" && ls "$variant".mzML*)
    for bin in old new; do
      exe=$old
      [ $bin = new ] && exe=$new
      out=out/$bin/$name-$variant
      mkdir -p "$out"
      # the same relative paths for both binaries, so that their outputs are comparable
      (cd "$out" && "$exe" -P"../../../in/$name/comet.params" -Nr "../../../in/$name/$input" > log.txt 2>&1) \
        || { echo "FAIL  $bin $name-$variant"; status=1; }
      # leave out what changes from run to run: dates, times, absolute paths
      for f in "$out"/r.*; do
        [ -e "$f" ] || continue  # no output at all
        case $f in *.norm) continue ;; esac
        sed -E -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+//g' -e 's/(date|creationDate)="[^"]*"//g' \
               -e 's#[0-9]{2}/[0-9]{2}/[0-9]{4}, [0-9]{2}:[0-9]{2}:[0-9]{2} [AP]M##g' \
               -e 's/[A-Z][a-z]{2} [A-Z][a-z]{2} +[0-9]+ [0-9:]+ [0-9]{4}//g' \
               -e 's#[^ "<>]*[/\\]out[/\\](old|new)[/\\]#out/BIN/#g' \
               "$f" > "$f.norm"
      done
    done
    # the same output files from both, and the same content in each
    if ! diff <(cd "out/old/$name-$variant" && ls r.*.norm 2> /dev/null) \
              <(cd "out/new/$name-$variant" && ls r.*.norm 2> /dev/null) > /dev/null; then
      echo "DIFF  $name-$variant output files"
      status=1
    fi
    for f in out/old/"$name-$variant"/r.*.norm; do
      g=out/new/$name-$variant/$(basename "$f")
      if cmp -s "$f" "$g"; then
        echo "same  $name-$variant $(basename "${f%.norm}") ($(wc -l < "$f") lines)"
      else
        echo "DIFF  $name-$variant $(basename "${f%.norm}")"
        diff "$f" "$g" | head -n 10 || true
        status=1
      fi
    done
  done
  # and the encodings of the spectra must not change the results
  for variant in zlib gz; do
    if cmp -s "out/new/$name-plain/r.txt.norm" "out/new/$name-$variant/r.txt.norm"; then
      echo "same  $name plain and $variant input (txt)"
    else
      echo "DIFF  $name plain and $variant input (txt)"
      status=1
    fi
  done
done
exit $status
