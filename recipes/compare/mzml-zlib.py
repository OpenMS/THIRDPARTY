#!/usr/bin/env python3
"""Writes a copy of an (indexed) mzML whose binary data arrays are zlib-compressed
(MS:1000576 "no compression" becomes MS:1000574 "zlib compression"). The spectra
stay the same; the index offsets are recomputed.

usage: mzml-zlib.py <in.mzML> <out.mzML>
"""
import base64
import re
import sys
import zlib

src, dst = sys.argv[1], sys.argv[2]
data = open(src, "rb").read().decode("latin-1")


def compress(match):
    array = match.group(0)
    if 'accession="MS:1000576"' not in array:
        return array
    array = re.sub(r'<cvParam cvRef="MS" accession="MS:1000576" name="no compression"[^/]*/>',
                   '<cvParam cvRef="MS" accession="MS:1000574" name="zlib compression" value=""/>', array)
    array = re.sub(r"<binary>([^<]*)</binary>",
                   lambda m: "<binary>" + base64.b64encode(zlib.compress(base64.b64decode(m.group(1)))).decode() + "</binary>",
                   array)
    length = len(re.search(r"<binary>([^<]*)</binary>", array).group(1))
    return re.sub(r'encodedLength="\d+"', 'encodedLength="%d"' % length, array, count=1)


head_end = data.index("<mzML")
mzml_end = data.index("</mzML>") + len("</mzML>")
head, mzml = data[:head_end], data[head_end:mzml_end]
mzml = re.sub(r"<binaryDataArray .*?</binaryDataArray>", compress, mzml, flags=re.S)
if "MS:1000576" in mzml:
    sys.exit("%s: an uncompressed array is left" % src)

out = head + mzml + "\n"
if "<indexedmzML" in head:
    indices = []
    for kind in ("spectrum", "chromatogram"):
        items = [(m.start(), m.group(1)) for m in re.finditer(r'<%s [^>]*?id="([^"]*)"' % kind, mzml)]
        if items:
            indices.append('\t<index name="%s">\n' % kind
                           + "".join('\t\t<offset idRef="%s">%d</offset>\n' % (i, len(head) + p) for p, i in items)
                           + "\t</index>\n")
    out += ('<indexList count="%d">\n' % len(indices) + "".join(indices) + "</indexList>\n"
            + "<indexListOffset>%d</indexListOffset>\n" % (len(head) + len(mzml) + 1)
            + "<fileChecksum>0</fileChecksum>\n</indexedmzML>\n")
open(dst, "wb").write(out.encode("latin-1"))
