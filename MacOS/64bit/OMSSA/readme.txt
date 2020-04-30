# Compile omssa macOS

# Download trunk NCBI-Toolkit (via svn)
# https://www.ncbi.nlm.nih.gov/IEB/ToolBox/CPP_DOC/lxr/source/src/algo/ms/omssa/
svn export https://anonsvn.ncbi.nlm.nih.gov/repos/v1/trunk/c++

# configure
./configure --with-static --with-bin-release --without-debug  --without-gui --without-gbench --without-jpeg --without-app --without-lmdb

# go to build folder (as indicated after ./configure is finished) 
cd ../c++/Clang1100-ReleaseMT64/build && /usr/bin/make all_r

# in addition build pepxml and omssa (build dir)
make -C ./build/algo/ms/formats/pepxml
make -C ./build/algo/ms/omssa


