setup:
clone https://github.com/Microsoft/vcpkg
git clone https://github.com/Microsoft/vcpkg.git

cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install

then to set up websocket lib:
vcpkg install uwebsockets uwebsockets:x64-windows nlohmann-json nlohmann-json:x64-windows
