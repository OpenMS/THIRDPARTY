Built from source on Win10 with VS2015 and MSVC 14. XML support off.
cmake -G "Visual Studio 14 2015" -A "x64" ..
cmake --build . --target percolator --config Release
