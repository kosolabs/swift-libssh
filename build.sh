#!/bin/bash

export OPENSSL=openssl-4.0.2   # https://github.com/openssl/openssl/releases
export LIBSSH=libssh-0.12.2    # https://www.libssh.org/files/
export MACOSX_DEPLOYMENT_TARGET=15.0

set -euo pipefail

export KEYROOT=$(realpath keys)
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)

rm -rf .build/clibssh
mkdir -p .build/clibssh/{src,install}
export BUILD=$(realpath .build/clibssh)

# Download OpenSSL

cd $BUILD/src
curl -LO https://github.com/openssl/openssl/releases/download/$OPENSSL/$OPENSSL.tar.gz
curl -LO https://github.com/openssl/openssl/releases/download/$OPENSSL/$OPENSSL.tar.gz.asc
gpgv --keyring $KEYROOT/openssl.gpg $OPENSSL.tar.gz.asc $OPENSSL.tar.gz
tar xzf $OPENSSL.tar.gz

# Build OpenSSL for arm64

cd $BUILD/src/$OPENSSL

./Configure darwin64-arm64-cc \
  no-shared \
  no-tests \
  --prefix=$BUILD/install/openssl-arm64 \
  --openssldir=$BUILD/install/openssl-arm64/ssl \
  -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET

make clean
make -j$(sysctl -n hw.ncpu)
make install_sw

# Build OpenSSL for x86_64

./Configure darwin64-x86_64-cc \
  no-shared \
  no-tests \
  --prefix=$BUILD/install/openssl-x86_64 \
  --openssldir=$BUILD/install/openssl-x86_64/ssl \
  -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET

make clean
make -j$(sysctl -n hw.ncpu)
make install_sw

# Build OpenSSL (static, universal)

cd $BUILD
mkdir -p $BUILD/install/openssl-universal/{lib,include}

lipo -create \
  $BUILD/install/openssl-arm64/lib/libssl.a \
  $BUILD/install/openssl-x86_64/lib/libssl.a \
  -output $BUILD/install/openssl-universal/lib/libssl.a

lipo -create \
  $BUILD/install/openssl-arm64/lib/libcrypto.a \
  $BUILD/install/openssl-x86_64/lib/libcrypto.a \
  -output $BUILD/install/openssl-universal/lib/libcrypto.a

cp -R $BUILD/install/openssl-arm64/include/openssl \
      $BUILD/install/openssl-universal/include/

# Fetch libssh

cd $BUILD/src
LIBSSH_SERIES=$(echo $LIBSSH | sed -E 's/libssh-([0-9]+\.[0-9]+).*/\1/')
curl -LO https://www.libssh.org/files/$LIBSSH_SERIES/$LIBSSH.tar.xz
curl -LO https://www.libssh.org/files/$LIBSSH_SERIES/$LIBSSH.tar.xz.asc
gpgv --keyring $KEYROOT/libssh.gpg $LIBSSH.tar.xz.asc $LIBSSH.tar.xz
tar xzf $LIBSSH.tar.xz

# Build libssh for arm64

mkdir -p $BUILD/build/libssh-arm64
cd $BUILD/build/libssh-arm64

cmake $BUILD/src/$LIBSSH \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DWITH_GSSAPI=OFF \
  -DWITH_ZLIB=OFF \
  -DWITH_EXAMPLES=OFF \
  -DWITH_TESTING=OFF \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET \
  -DCMAKE_INSTALL_PREFIX=$BUILD/install/libssh-arm64 \
  -DOPENSSL_ROOT_DIR=$BUILD/install/openssl-arm64

make -j$(sysctl -n hw.ncpu)
make install

# Build libssh for x86_64

mkdir -p $BUILD/build/libssh-x86_64
cd $BUILD/build/libssh-x86_64

cmake $BUILD/src/$LIBSSH \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DWITH_GSSAPI=OFF \
  -DWITH_ZLIB=OFF \
  -DWITH_EXAMPLES=OFF \
  -DWITH_TESTING=OFF \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET \
  -DCMAKE_INSTALL_PREFIX=$BUILD/install/libssh-x86_64 \
  -DOPENSSL_ROOT_DIR=$BUILD/install/openssl-x86_64

make -j$(sysctl -n hw.ncpu)
make install

# Create universal libssh

mkdir -p $BUILD/install/libssh-universal/lib
mkdir -p $BUILD/install/libssh-universal/include

lipo -create \
  $BUILD/install/libssh-arm64/lib/libssh.a \
  $BUILD/install/libssh-x86_64/lib/libssh.a \
  -output $BUILD/install/libssh-universal/lib/libssh.a

cp -R $BUILD/install/libssh-arm64/include/libssh \
      $BUILD/install/libssh-universal/include/

# Install into CLibSSH

cd $BUILD/../..

rm -rf Sources/CLibSSH
mkdir -p Sources/CLibSSH/{lib,include/libssh}

cp $BUILD/install/libssh-universal/lib/libssh.a Sources/CLibSSH/lib/
cp $BUILD/install/openssl-universal/lib/libssl.a Sources/CLibSSH/lib/
cp $BUILD/install/openssl-universal/lib/libcrypto.a Sources/CLibSSH/lib/
cp $BUILD/install/libssh-universal/include/libssh/*.h Sources/CLibSSH/include/libssh/
touch Sources/CLibSSH/dummy.c

echo "✅ Built CLibSSH with OpenSSL $OPENSSL and libssh $LIBSSH"
