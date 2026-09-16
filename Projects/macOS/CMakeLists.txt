cmake_minimum_required(VERSION 3.30)

# macOS 应用：本文件只声明，工程由 `cmake -G Xcode` 生成。
# 不再手写/维护 Dora.xcodeproj。
project(Dora LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(DORA_APPLE_PLATFORM macos)
include("${CMAKE_CURRENT_SOURCE_DIR}/../apple/AppleApp.cmake")
dora_add_apple_app(TARGET Dora PLATFORM ${DORA_APPLE_PLATFORM})
