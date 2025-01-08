#!/bin/bash

# Check if the script is called without parameters
if [ $# -ne 2 ]; then
    echo "Usage: $0 <ANDROID_NDK_ROOT> <CONFIGURATION>"
    echo "Accepted configurations: android-arm, android-arm64, android-x86, android-x86_64"
    exit 1
fi

# Assign script arguments to variables
ANDROID_NDK_ROOT=$1
CONFIGURATION=$2

# List of accepted configurations and their corresponding architectures
ACCEPTED_CONFIGURATIONS=("android-arm" "android-arm64" "android-x86" "android-x86_64")
ARCHITECTURE_MAPPING=("armeabi-v7a" "arm64-v8a" "x86" "x86_64")

# Check if the provided configuration is valid
if [[ ! " ${ACCEPTED_CONFIGURATIONS[@]} " =~ " ${CONFIGURATION} " ]]; then
    echo "Error: Invalid configuration '${CONFIGURATION}'"
    echo "Accepted configurations are: ${ACCEPTED_CONFIGURATIONS[*]}"
    exit 2
fi

# Map configuration to output architecture folder
for i in "${!ACCEPTED_CONFIGURATIONS[@]}"; do
    if [ "${ACCEPTED_CONFIGURATIONS[$i]}" == "$CONFIGURATION" ]; then
        ARCH="${ARCHITECTURE_MAPPING[$i]}"
        break
    fi
done

# Define the paths to be added to PATH
TOOLCHAIN_LLVM="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
TOOLCHAIN_ARM="$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin"

# Check if the toolchain paths exist
if [ ! -d "$TOOLCHAIN_LLVM" -a ! -d "$TOOLCHAIN_ARM" ]; then
    if [ ! -d "$TOOLCHAIN_LLVM" ]; then
        echo "Error: LLVM toolchain path '$TOOLCHAIN_LLVM' does not exist."
        exit 3
    fi
    
    if [ ! -d "$TOOLCHAIN_ARM" ]; then
        echo "Error: ARM toolchain path '$TOOLCHAIN_ARM' does not exist."
        exit 3
    fi
fi

# Define directories
CURR_DIR="$(pwd)"
OUTPUT_DIR="$(pwd)/openssl/build/out/$ARCH"
BUILD_DIR="$(pwd)/openssl/build/${ARCH}"

if [ -d "${BUILD_DIR}" ]; then
    echo "
 OOO   pppp   eeeee  n   n   SSSS   SSSS   L
O   O  p   p  e      nn  n  s       s     L
O   O  pppp   eeee   n n n   SSSS    SSS  L
O   O  p      e      n  nn      s      s   L
 OOO   p      eeeee  n   n  SSSS   SSSS   LLLLL
                                      
OpenSSL Build already completed for ${ARCH}.
To force a rebuild, rm -rf ${BUILD_DIR}
    "
    exit 0
fi


# Update PATH with Android NDK toolchains
export PATH=$TOOLCHAIN_LLVM:$TOOLCHAIN_ARM:$PATH
export ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"


cd ${BUILD_DIR}

${CURR_DIR}/openssl/Configure ${CONFIGURATION} -D__ANDROID_API__=29 --prefix="${OUTPUT_DIR}"
make
make install
