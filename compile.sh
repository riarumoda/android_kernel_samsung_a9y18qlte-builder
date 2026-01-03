#!/bin/bash
##################################################
# Unofficial OneUI Perf kernel Compile Script
# Based on the original compile script by vbajs
# Forked by Riaru Moda
##################################################

# Help message
help_message() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --ksu          Enable KernelSU support"
  echo "  --no-ksu       Disable KernelSU support"
  echo "  --help         Show this help message"
}

# Environment setup
setup_environment() {
  echo "Setting up build environment..."
  export ARCH=arm64
  export SUBARCH=arm64
  export HEADER_ARCH=arm64
  export KBUILD_BUILD_USER=riaru
  export KBUILD_BUILD_HOST=ximiedits
  export GCC64_DIR=$PWD/gcc64
  export KSU_SETUP_URI="https://github.com/KernelSU-Next/KernelSU-Next"
  export KSU_BRANCH="legacy"
}

# Toolchain setup
setup_toolchain() {
  echo "Setting up toolchains..."

  if [ ! -d "$PWD/gcc64" ]; then
    echo "Downloading GCC..."
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 --depth=1 gcc64
  else
    echo "Local gcc dirs found, using them."
  fi

  echo "Setting up openssl 1.1..."
  local OPENSSL_DIR="$HOME/.openssl1.1"
  
  if [ ! -d "$OPENSSL_DIR" ]; then
    wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz
    tar -xf openssl-1.1.1w.tar.gz
    cd openssl-1.1.1w
    ./config --prefix="$OPENSSL_DIR" --openssldir="$OPENSSL_DIR"
    make -s -j$(nproc)
    make -s install
    cd ..
    rm -rf openssl-1.1.1w*
  fi

  export HOSTCFLAGS="-I$OPENSSL_DIR/include"
  export HOSTLDFLAGS="-L$OPENSSL_DIR/lib -Wl,-rpath,$OPENSSL_DIR/lib"
  export LD_LIBRARY_PATH="$OPENSSL_DIR/lib:$LD_LIBRARY_PATH"
  export MY_OPENSSL_DIR="$OPENSSL_DIR"
}

# Update PATH
update_path() {
  echo "Updating PATH..."
  export PATH="$GCC64_DIR/bin/:$HOME/.openssl1.1/bin:/usr/bin:$PATH"
}

# KSU Setup
setup_ksu() {
  local arg="$1"
  if [[ "$arg" == "--ksu" ]]; then
    echo "Setting up KernelSU..."
    echo "CONFIG_KSU=y" >> arch/arm64/configs/a9y18qlte_eur_open_defconfig
    echo "CONFIG_KSU_LSM_SECURITY_HOOKS=y" >> arch/arm64/configs/a9y18qlte_eur_open_defconfig
    echo "CONFIG_KSU_MANUAL_HOOKS=y" >> arch/arm64/configs/a9y18qlte_eur_open_defconfig
    patch -p1 < ksumakefile.patch
    git clone "$KSU_SETUP_URI" -b "$KSU_BRANCH" KernelSU
    cd drivers
    ln -sfv ../KernelSU/kernel kernelsu
    cd ..
  elif [[ "$arg" == "--no-ksu" ]]; then
    echo "KernelSU setup skipped."
  fi
}

# Compile kernel
compile_kernel() {
  echo -e "\nStarting compilation..."
  sed -i 's/# CONFIG_LOCALVERSION is not set/CONFIG_LOCALVERSION="-perf-neon"/' arch/arm64/configs/a9y18qlte_eur_open_defconfig
  sed -i 's/CONFIG_LOCALVERSION_AUTO=y/# CONFIG_LOCALVERSION_AUTO is not set/' arch/arm64/configs/a9y18qlte_eur_open_defconfig
  make O=out ARCH=arm64 \
    HOSTCFLAGS="$HOSTCFLAGS" \
    HOSTLDFLAGS="$HOSTLDFLAGS" \
    a9y18qlte_eur_open_defconfig
  make -j$(nproc --all) \
    ARCH=arm64 \
    O=out \
    SUBARCH=arm64 \
    CC=aarch64-linux-android-gcc \
    LD=aarch64-linux-android-ld.bfd \
    AR=aarch64-linux-android-ar \
    AS=aarch64-linux-android-as \
    NM=aarch64-linux-android-nm \
    OBJCOPY=aarch64-linux-android-objcopy \
    OBJDUMP=aarch64-linux-android-objdump \
    STRIP=aarch64-linux-android-strip \
    CROSS_COMPILE=aarch64-linux-android- \
    HOSTCFLAGS="$HOSTCFLAGS" \
    HOSTLDFLAGS="$HOSTLDFLAGS" \
    OPENSSL="$MY_OPENSSL_DIR/bin/openssl"
}

# Main function
main() {
  case "$1" in
    --help)
      help_message
      exit 0
      ;;
  esac
  setup_environment
  setup_toolchain
  update_path
  setup_ksu "$1"
  compile_kernel
}

# Run the main function
main "$1"
