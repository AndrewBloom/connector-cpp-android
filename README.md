# connector-cpp-android

MySql-Connector-cpp playground to attempt cross-compilation for android.

## Instruction
1. `git submodule update --init --recursive`
2. `chmod +x compile.sh; chmod +x compile_openssl.sh`
3. execute `./compile.sh`, passing the ndk root folder and the architecture. for example: `./compile.sh /home/bloom/Android/Sdk/ndk/28.0.12433566/ android-arm64`

