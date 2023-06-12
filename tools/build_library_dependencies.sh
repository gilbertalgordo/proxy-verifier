#!/bin/bash
#
# Build QUIC/HTTP3 library dependencies.
#
# Copyright 2023, Verizon Media
# SPDX-License-Identifier: Apache-2.0
#

# Inspired by:
# https://github.com/curl/curl/blob/master/docs/HTTP3.md

fail()
{
  echo $1
  exit 1
}

os=$(uname)
[ "${os}" = "Linux" -o "${os}" = "Darwin" ] || fail "Unrecognized OS: ${os}"

#
# Determine the number of threads to build with.
#
if [ "${os}" = "Linux" ]
then
  num_threads=$(nproc)
else
  # MacOS.
  num_threads=$(sysctl hw.logicalcpu)
fi

[ $# -eq 1 ] || fail "Please provide a directory in which to install the libraries."
install_dir=$1

echo
echo "Building with ${num_threads} threads, installing in ${install_dir}"
echo

# Only try using sudo if the install directory is not writable by the current
# user.
SUDO=""
[ -d "${install_dir}" ] || \
    mkdir -p ${install_dir} || \
    sudo mkdir -p ${install_dir}
[ -w "${install_dir}" ] || SUDO=sudo
sudo chmod -R ugo+rX ${install_dir}

mkdir -p ${install_dir}
repo_dir=/var/tmp/http3_dependency_repos_$$
mkdir -p ${repo_dir}

# 1. OpenSSL version that supports quic.
cd ${repo_dir}
git clone -b OpenSSL_1_1_1u+quic --depth 1 https://github.com/quictls/openssl.git openssl
cd openssl
git checkout 636c615c139061b125a25461708f4afc79284f83
./config --prefix=${install_dir}/openssl
make -j ${num_threads}
${SUDO} make install_sw
sudo chmod -R ugo+rX ${install_dir}/openssl

# 2. nghttp3
cd ${repo_dir}
git clone https://github.com/ngtcp2/nghttp3
cd nghttp3/
git checkout v0.11.0
autoreconf -i
./configure --prefix=${install_dir}/nghttp3 --enable-lib-only
make -j ${num_threads}
${SUDO} make install
sudo chmod -R ugo+rX ${install_dir}/nghttp3

# 3. ngtcp2
cd ${repo_dir}
git clone https://github.com/ngtcp2/ngtcp2
cd ngtcp2
git checkout v0.15.0
autoreconf -i
./configure \
  PKG_CONFIG_PATH=${install_dir}/openssl/lib/pkgconfig:${install_dir}/nghttp3/lib/pkgconfig \
  LDFLAGS="-Wl,-rpath,${install_dir}/openssl/lib" \
  --prefix=${install_dir}/ngtcp2 \
  --enable-lib-only
make -j ${num_threads}
${SUDO} make install
sudo chmod -R ugo+rX ${install_dir}/ngtcp2

#4. nghttp2
cd ${repo_dir}
git clone https://github.com/tatsuhiro-t/nghttp2.git
cd nghttp2
git checkout v.1.54.0
autoreconf -if
./configure \
  PKG_CONFIG_PATH=${install_dir}/openssl/lib/pkgconfig:${install_dir}/ngtcp2/lib/pkgconfig:${install_dir}/nghttp3/lib/pkgconfig \
  --prefix=${install_dir}/nghttp2 \
  --enable-lib-only
make -j ${num_threads}
${SUDO} make install
sudo chmod -R ugo+rX ${install_dir}/nghttp2
