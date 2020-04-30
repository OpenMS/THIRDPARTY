Version 2019.01 rev. 5
Built from source on macOS Catalina 10.15.4 with Apple LLVM version 11.0.3 (clang-1103.0.32.29) SDK 10.15. Min MacOSX deployment target 10.9.

Build Comet on macOS:

Remove every macro that references a C function with a 64 suffix (e.g. _ftelli64 -> _ftelli) in currently:
CometSearch/Common.h
MSToolkit/include/MSReader.h

See maybe bioconda recipe of Leon Kuchenbecker for the exact lines (if not outdated). The build will complain early if you forgot an occurrence. Then run:

```
CXX=clang++ CC=clang MACOSX_DEPLOYMENT_TARGET=10.9 make
```


Little script to check diffs in my comet sources:

```
 for file in ./comet_source_2019014/**/*.h; do echo "$file" ; diff "$file" "./comet_2019015/comet_source_2019015/${file//.*comet_source_2019014\//}"; done > diffs.log
```
