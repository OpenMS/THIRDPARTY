# Rebuilt engines

The upstream binaries of two engines carry copies of zlib and expat with known
vulnerabilities, so this repository holds binaries built from the same engine
versions against current releases of those libraries:

| Engine | Folders | Upstream binaries carry | Rebuilt with |
| --- | --- | --- | --- |
| Comet 2025.01 rev. 1 | `Linux/x86_64`, `Linux/aarch64`, `MacOS/arm64`, `MacOS/x86_64`, `Windows/x86_64` | zlib 1.2.11 and expat 2.2.9, bundled by its MSToolkit | zlib 1.3.2, expat 2.8.5 |
| MaRaCluster 1.04.1 | `Linux/x86_64`, `MacOS/arm64`, `Windows/x86_64` | zlib 1.2.3, bundled by ProteoWizard | zlib 1.3.2 |

## How they are built

`versions.env` pins every source: the zlib and expat release archives by their
SHA-256, and the engines and ProteoWizard by commit (which `fetch-sources.sh`
checks against the release tags). The builds are those of the upstream release
binaries, with the same runners, compilers and build scripts; what differs is
in the patches here.

- **Comet** (`comet/`): `prepare.sh` replaces the zlib and expat archives and
  source trees in MSToolkit's `src` folder with the pinned releases, and the
  patch points Comet's Makefiles and Visual Studio projects at them. For the
  Visual Studio build it also adds expat's `random_rand_s.c`, and `prepare.sh`
  writes the `expat_config.h` that expat's CMake build generates for MSVC:
  unlike expat 2.2.9's, the sources of expat 2.8.5 include it on Windows too. The binaries
  are built with `make` on Linux and macOS and with MSBuild (v142 toolset) on
  Windows, as Comet's release workflows do.
- **MaRaCluster** (`maracluster/`): MaRaCluster links ProteoWizard, which builds
  zlib, Boost and itself from the zlib in its `libraries` folder; ProteoWizard and
  MaRaCluster have to use the same zlib. The patch makes MaRaCluster's builder
  scripts (`admin/builders`) build the ProteoWizard tree that `prepare.sh` puts
  in place, with ProteoWizard's `--zlib-src` option pointing to zlib 1.3.2;
  `prepare.sh` removes ProteoWizard's zlib 1.2.3. MaRaCluster's release build
  took the newest ProteoWizard at build time; `versions.env` pins the commit
  that was (26 June 2025). The ProteoWizard tree is a sparse checkout with the
  content of ProteoWizard's source tarballs (`pwiz-src-without-tv`, and on
  Windows `pwiz-src-without-t`, which has the vendor APIs).

`.github/workflows/rebuild-engines.yml` runs the builds on pushes and pull
requests that change this folder, and by hand (workflow_dispatch).

## How they are checked

- `check-bundled-libs.sh` lists the zlib and expat version strings in a binary
  (as the OpenMS release check finds them) and fails on the copyright strings of
  any other zlib, the version strings of any other expat, and the ZLIB_VERSION
  strings of the zlib releases the upstream binaries bundled. MSVC drops most of
  these strings from the executables, so on Windows it also checks the static
  libraries that are linked.
- `compare/comet.sh` and `compare/maracluster.sh` run the rebuilt binary and the
  upstream binary it replaces (`BASELINE_COMMIT`) on OpenMS's test data, with the
  spectra uncompressed, zlib-compressed and gzipped, and require the same
  results: Comet's txt, pepXML, mzIdentML, pin and SQT output, and MaRaCluster's
  clusters and consensus spectra (the latter name ProteoWizard's version).

## Updating the binaries

1. Run the workflow, or push a change to this folder.
2. Download the `engines` artifact of the run. It holds the binaries in this
   repository's folder layout (without their file modes: the Linux and macOS
   binaries need `chmod +x`).
3. Copy them over the old ones and commit them, with the run's URL.

## Not covered

MaRaCluster also links ProteoWizard's HDF5 1.8.7 (for mzMLb and mz5 files), and
ProteoWizard's master still bundles that version. Only zlib is replaced here.
