cmake_minimum_required(VERSION 3.30)

# iOS 应用：本文件只声明，工程由 `cmake -G Xcode` 生成（pbxproj 为产物）。
# CI/模拟器: cmake -B build -G Xcode -DCMAKE_SYSTEM_NAME=iOS \
#              -DCMAKE_OSX_SYSROOT=iphonesimulator [-DCMAKE_OSX_ARCHITECTURES=x86_64]
# 真机:      -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64
project(Dora LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(DORA_APPLE_PLATFORM ios)
set(DORA_IOS_VARIANT simulator CACHE STRING "Which prebuilt iOS bgfx libraries to link (simulator/device)")
include("${CMAKE_CURRENT_SOURCE_DIR}/../apple/AppleApp.cmake")
dora_add_apple_app(TARGET Dora PLATFORM ${DORA_APPLE_PLATFORM})
