setup:
clone https://github.com/Microsoft/vcpkg
git clone https://github.com/Microsoft/vcpkg.git

cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install

then to set up websocket lib:
vcpkg install uwebsockets uwebsockets:x64-windows
and if needed also:
vcpkg install openssl zlib libuv openssl:x64-windows zlib:x64-windows libuv:x64-windows