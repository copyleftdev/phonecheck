#!/bin/bash
set -euo pipefail

echo "🔨 Building C++ wrapper for libphonenumber..."

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    CXX="clang++"
else
    PLATFORM="linux"
    CXX="g++"
fi

# Compiler flags
CXXFLAGS="-std=c++17 -fPIC -O3 -Wall -Wextra"
INCLUDES="-I/usr/include -I/usr/local/include"
LDFLAGS="-lphonenumber -lprotobuf -licuuc -licudata"

# Output directory
mkdir -p lib

# Compile wrapper
echo "→ Compiling phonenumber_wrapper.cpp..."
$CXX $CXXFLAGS $INCLUDES -c src/phonenumber_wrapper.cpp -o lib/phonenumber_wrapper.o

# Create shared library
echo "→ Creating shared library..."
if [[ "$PLATFORM" == "macos" ]]; then
    $CXX -dynamiclib -o lib/libphonenumber_wrapper.dylib lib/phonenumber_wrapper.o $LDFLAGS
else
    $CXX -shared -o lib/libphonenumber_wrapper.so lib/phonenumber_wrapper.o $LDFLAGS
fi

echo "✅ Build complete!"
echo ""
echo "Library location:"
if [[ "$PLATFORM" == "macos" ]]; then
    ls -lh lib/libphonenumber_wrapper.dylib
else
    ls -lh lib/libphonenumber_wrapper.so
fi

echo ""
echo "To use the library, add to LD_LIBRARY_PATH:"
echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$(pwd)/lib"
