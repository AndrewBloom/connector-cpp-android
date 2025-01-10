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

# Get the path to the cmake folder
CMAKE_FOLDER="$ANDROID_NDK_ROOT/../../cmake"
# Find the latest cmake version dynamically
CMAKE_LATEST_VERSION=$(ls -d "$CMAKE_FOLDER"/* | awk -F'/' '{print $NF}' | sort -V | tail -n 1)
# Construct the path using the latest version
ANDROID_CMAKE="$CMAKE_FOLDER/$CMAKE_LATEST_VERSION/bin/"

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

#Current path
CURR_DIR="$(pwd)"

echo "
##################################################################
#                                                                #
#          P A T C H I N G   S O U R C E   C O D E               #
#                                                                #
##################################################################
"
PATCH_FILE=${CURR_DIR}/cross_compile.patch
cd mysql-connector-cpp
# Check if the reverse patch can be applied (indicating the patch is already applied)
if git apply --check --reverse "$PATCH_FILE" >/dev/null 2>&1; then
    echo "The cross-compile.patch is already applied to mysql-connector-cpp."
else
    echo "The cross-compile.patch is not applied. Applying now..."
    if git apply "$PATCH_FILE"; then
        echo "Patch successfully applied to mysql-connector-cpp."
    else
        echo "Error: Failed to apply patch."
        exit 1
    fi
fi 
cd -
   
echo "
##################################################################
#                                                                #
#              C O M P I L I N G   O P E N S S L                 #
#            F O R   T A R G E T   P L A T F O R M               #
#                                                                #
##################################################################
"

#build the openssl dependency
#echo "Compiling OpenSSL..." 
./compile_openssl.sh $1 $2

#Output directory
mkdir -p mysql-connector-cpp/android_libs

# Define absolute paths
OPENSSL_DIR="${CURR_DIR}/openssl/build/out/${ARCH}"

#host architecture separated build folder
BUILD_HOST_DIR="${CURR_DIR}/mysql-connector-cpp/build/host"
BUILD_HOST_PROTOBUF_DIR="${BUILD_HOST_DIR}/protobuf"
BUILD_HOST_SAVE_LINKER_OPTS_DIR="${BUILD_HOST_DIR}/save_linker_opts"
mkdir -p ${BUILD_HOST_SAVE_LINKER_OPTS_DIR}
mkdir -p ${BUILD_HOST_PROTOBUF_DIR} && cd ${BUILD_HOST_PROTOBUF_DIR}

echo "
##################################################################
#                                                                #
#      C O M P I L I N G   P R O T O C   C O M P I L E R         #
#      & S A V E _ L I N K E R _ O P T S   U T I L I T Y         #
#             F O R   H O S T   P L A T F O R M                  #
#                                                                #
##################################################################
"
cmake \
    -G Ninja \
    ../../../cdk/extra/protobuf/
ninja

#creates the CMakeLists.txt for save_linker_opts if does not exist
LIBUTILS_CMAKE_DIR="${CURR_DIR}/mysql-connector-cpp/cmake/libutils"

if [ ! -f "${LIBUTILS_CMAKE_DIR}/CMakeLists.txt" ]; then
    echo "Creating CMakeLists.txt in ${LIBUTILS_CMAKE_DIR}"
    cat > "${LIBUTILS_CMAKE_DIR}/CMakeLists.txt" << 'EOF'
cmake_minimum_required(VERSION 3.10)
project(save_linker_opts)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(save_linker_opts save_linker_opts.cc)
EOF
else
    echo "CMakeLists.txt already exists in ${LIBUTILS_CMAKE_DIR}"
fi

cd ${BUILD_HOST_SAVE_LINKER_OPTS_DIR}
cmake \
    -G Ninja \
    ../../../cmake/libutils/
ninja

#target architecture separated build folder
BUILD_TARGET_DIR="${CURR_DIR}/mysql-connector-cpp/build/${ARCH}"
mkdir -p ${BUILD_TARGET_DIR} && cd ${BUILD_TARGET_DIR}

echo "
##################################################################
#                                                                #
#   C O M P I L I N G   F O R   T A R G E T   P L A T F O R M    #
#                                                                #
##################################################################
"
 
${ANDROID_CMAKE}/cmake \
    -G Ninja \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_SYSTEM_VERSION=34 \
    -DANDROID_PLATFORM=android-34 \
    -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=${ARCH} \
    -DANDROID_NDK=${ANDROID_NDK_ROOT} \
    -DANDROID_TOOLCHAIN=clang \
    -DANDROID_STL=c++_shared \
    -DCMAKE_INSTALL_PREFIX=./android_libs \
    -DWITH_SSL=${OPENSSL_DIR} \
    -DOPENSSL_INCLUDE_DIR=${OPENSSL_DIR}/include \
    -DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_DIR}/lib/libcrypto.so \
    -DOPENSSL_SSL_LIBRARY=${OPENSSL_DIR}/lib/libssl.so \
    -DWITH_ZSTD=ON \
    -DWITH_LZ4=ON \
    -DWITH_ZLIB=ON \
    -DWITH_PROTOBUF=ON \
    -DWITH_PROTOC=${BUILD_HOST_PROTOBUF_DIR}/runtime_output_directory/protoc \
    -DWITH_SAVE_LINKER_OPTS=${BUILD_HOST_SAVE_LINKER_OPTS_DIR}/save_linker_opts \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_TESTS=OFF \
    -DWITH_JDBC=OFF \
    ../..

#replace the wrong system version that we don't know why is set to 1
#find . -type f -name "CMakeSystem.cmake" -exec sed -i 's/CMAKE_SYSTEM_VERSION "1"/CMAKE_SYSTEM_VERSION "29"/g' {} +
#find . -type f -name "CMakeCache.txt" -exec sed -i 's/CMAKE_SYSTEM_VERSION:UNINITIALIZED=1/CMAKE_SYSTEM_VERSION:UNINITIALIZED=29/g' {} +

${ANDROID_CMAKE}/ninja
${ANDROID_CMAKE}/ninja install

