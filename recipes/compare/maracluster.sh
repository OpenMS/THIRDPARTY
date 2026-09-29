#!/usr/bin/env bash
# Runs two MaRaCluster binaries as OpenMS's MaRaClusterAdapter runs it (index in
# one thread, batch, consensus) on the adapter's test spectra and compares the
# clusters and the consensus spectra. The spectra are given as they are
# (uncompressed), with zlib-compressed binary arrays, and gzipped, so that the
# runs go through zlib.
#
# The batch step alone would convert the spectra in one OpenMP thread per file,
# and opening several files at once crashes MaRaCluster's Windows build, the
# release binary as the rebuilt one (see ../README.md); the index step converts
# them in one thread, and batch reuses them. With REPEAT=<n>, the index and batch
# steps of both binaries run n more times on the uncompressed spectra, and each
# of these runs has to succeed as well.
#
# usage: [REPEAT=<n>] maracluster.sh <old maracluster> <new maracluster> <work dir> <OpenMS checkout>
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# the absolute path of a file
abs() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
# native paths for the file lists (Git Bash on Windows)
native() { if command -v cygpath > /dev/null; then cygpath -m "$1"; else echo "$1"; fi; }
python=${PYTHON:-python3}

# cluster <maracluster>: the index and batch steps, in the folder with files.txt,
# with the parameters of MaRaClusterAdapter's test 1
cluster() {
  OMP_NUM_THREADS=1 "$1" index -b files.txt -f res -p 20ppm > index.log 2>&1 &&
    "$1" batch -b files.txt -f res -p 20ppm -t -10 -c -10 > batch.log 2>&1
}

old=$(abs "$1")
new=$(abs "$2")
work=$3
data=$(cd "$4/src/tests/topp/THIRDPARTY" && pwd)

mkdir -p "$work/in"
cd "$work"
for i in 1 2; do
  cp "$data/MaRaClusterAdapter_1_in_$i.mzML" "in/plain_$i.mzML"
  "$python" "$here/mzml-zlib.py" "$data/MaRaClusterAdapter_1_in_$i.mzML" "in/zlib_$i.mzML"
  gzip -c "$data/MaRaClusterAdapter_1_in_$i.mzML" > "in/gz_$i.mzML.gz"
done

status=0
for variant in plain zlib gz; do
  for bin in old new; do
    exe=$old
    [ $bin = new ] && exe=$new
    out=out/$bin/$variant
    mkdir -p "$out"
    for f in in/"$variant"_1.mzML* in/"$variant"_2.mzML*; do native "$PWD/$f"; done > "$out/files.txt"
    (cd "$out" && cluster "$exe" \
               && "$exe" consensus -l res/MaRaCluster.clusters_p10.tsv -f res -o consensus.mzML -M 1 > consensus.log 2>&1) \
      || { echo "FAIL  $bin $variant"; tail -n 5 "$out"/*.log; status=1; continue; }
    # leave out what changes from run to run: checksums, paths, the time, ProteoWizard's version
    sed -E -e '/fileChecksum|MS:1000569|completion time|sourceFile |location=/d' \
           -e 's/pwiz_3\.0\.[0-9]+/pwiz_3.0/g' -e 's/version="3\.0\.[0-9]+"/version="3.0"/g' \
      "$out/consensus.part1.mzML" > "$out/consensus.norm"
    sed -E -e 's#^[^[:blank:]]*[/\\]in[/\\]#in/#' "$out/res/MaRaCluster.clusters_p10.tsv" > "$out/clusters.norm"
  done
  for f in clusters.norm consensus.norm; do
    if cmp -s "out/old/$variant/$f" "out/new/$variant/$f"; then
      echo "same  $variant ${f%.norm} ($(wc -l < "out/old/$variant/$f") lines)"
    else
      echo "DIFF  $variant ${f%.norm}"
      diff "out/old/$variant/$f" "out/new/$variant/$f" | head -n 10 || true
      status=1
    fi
  done
done
# and the encodings of the spectra must not change the clusters
for variant in zlib gz; do
  if diff -q <(sed -E "s#in/${variant}_([12])\.mzML(\.gz)?#in/plain_\1.mzML#" "out/new/$variant/clusters.norm") \
             "out/new/plain/clusters.norm" > /dev/null; then
    echo "same  plain and $variant input (clusters)"
  else
    echo "DIFF  plain and $variant input (clusters)"
    status=1
  fi
done

repeat=${REPEAT:-0}
if [ "$repeat" -gt 0 ]; then
  failed_old=0 failed_new=0
  for ((i = 1; i <= repeat; i++)); do
    for bin in old new; do
      exe=$old
      [ $bin = new ] && exe=$new
      out=out/repeat/$bin-$i
      mkdir -p "$out"
      cp "out/$bin/plain/files.txt" "$out/"
      if (cd "$out" && cluster "$exe"); then
        rm -r "$out"
      else
        echo "FAIL  $bin repeat $i (exit status $?)"
        tail -n 5 "$out"/*.log
        if [ $bin = old ]; then failed_old=$((failed_old + 1)); else failed_new=$((failed_new + 1)); fi
      fi
    done
  done
  echo "old: $failed_old of $repeat repeated runs failed"
  echo "new: $failed_new of $repeat repeated runs failed"
  [ $failed_old -eq 0 ] && [ $failed_new -eq 0 ] || status=1
fi
exit $status
