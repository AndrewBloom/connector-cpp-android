# connector-cpp-android

MySql-Connector-cpp scripts to cross-compile the library for android.

## Instruction
1. `git submodule update --init --recursive`
2. `chmod +x compile.sh; chmod +x compile_openssl.sh`
3. execute `./compile.sh`, passing the ndk root folder and the architecture. for example: `./compile.sh /home/bloom/Android/Sdk/ndk/28.0.12433566/ android-arm64`. ./compile.sh without arguments will show the supported architectures.

## Status
The project successfully compiles for the 4 supported architectures on a Fedora Linux system. The resulting libraries were not tested, let me know if you do. In particular, both source code and cmake scripts of mysql-connector-cpp were patched.

For consulting services, write at:
Bloom Engineering Ltd
ing(dot)fiorito(at)gmail(dot)com
