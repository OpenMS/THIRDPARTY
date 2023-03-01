2023/01/31

Compiled executables can be found on GitHub --> https://github.com/UWPR/Comet/releases

release 2023.01 rev. 0 (2023.01.0), release date 2023/01/31

- Address issue where a peptide with a low xcorr identified in a very poor/sparse spectrum would be assigned a good E-value. This is due to the majority of matched xcorr scores being “0” so any poor scoring match looks like a good outlier. Thanks to D. Shteynberg for reporting the issue.
- Add “scale_fragmentNL” parameter entry which scales (multiplies) the neutral loss mass value by the number of modified residues in the fragment. Feature requested by A. Keller.
- Add contributions of fragment neutral loss peaks in preliminary (Sp) score; previously they only applied to the cross-correlation score.
- Correct bug where the fragment neutral loss peak was not analyzed if the primary fragment peak was not matched.
- Fix minor typo in command line help. Thanks to M. Riffle for the pull request.


Comet is an open source MS/MS database search engine released under 
the Apache 2.0 license.

Current supported input formats are mzXML, mzML, mgf, ms2, cms2, 
and Thermo RAW files (under Windows).  Current supported output 
formats are pepXML, Percolator pin (tsv), SQT, tab-delimited text, 
and .out files.

To run a search on an input file requires the Comet binary, a 
search parameters file (comet.params), an input file, and a protein 
sequence database in FASTA format.  The syntax of a search:

   comet.exe input.mzXML
   comet.exe input.ms2

Search parameters, such as which sequence database to query, modifications
to consider, mass tolerances, output format, etc. are defined in the
comet.params file.

One can generate a parameters file with the command

   comet.exe -p

Rename the created file "comet.params.new" to "comet.params".

Windows and linux command line binaries are included with this release.


To compile under linux, just type "make"; this should work on the vast
majority of systems. The resulting binary is "comet.exe" in the root
directory.

To compile with Windows Visual Studio 2017, load the Comet.sln file, set the
target as "Release" and "x64" (or "Win32"), and build "Comet".  Building the
entire solution may work but I've seen build issues with CometUI which is not
necessary.  For Windows, an additional dependency is Thermo's MSFileReader
library to read RAW files directly.  MSFileReader can be downloaded under
"Other Software Releases" at
   https://thermo.flexnetoperations.com/control/thmo/login
Or simply skip MSFileReader and the ability to read RAW files directly by
addding "# define _NO_THERMO_RAW" at the head of these files
   MSToolkit/include/MSReader.h
   MSToolkit/src/RAWReader.cpp
