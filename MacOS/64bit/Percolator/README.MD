# Percolator v304 
# MacOS build instructions:
# Note: In some cases the "CMAKE_INSTALL_PREFIX" PATH has to be set manually in the cmake_install.cmake

curl -L --remote-name --location https://github.com/percolator/percolator/archive/rel-3-04.tar.gz
tar xf rel-3-04.tar.gz
sync
rm rel-3-04.tar.gz

mkdir percolator-build
mkdir percolator-install

# Enable static build
L='add_executable(percolator main.cpp)'
L1='SET(BUILD_SHARED_LIBS OFF)'
gsed -i "s/$L/$L1\\n$L/g" percolator-rel-3-04/src/CMakeLists.txt

# Configure and build
cd percolator-build
cmake -DCMAKE_C_COMPILER=/usr/bin/gcc -DCMAKE_CXX_COMPILER=/usr/bin/g++ -DTARGET_ARCH=x86_64 -DCMAKE_OSX_DEPLOYMENT_TARGET=10.9 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(realpath '../percolator-install')" -DXML_SUPPORT=OFF "$(realpath ../percolator-rel-3-04)"
make -v
make install
strip ../percolator-install/bin/percolator

