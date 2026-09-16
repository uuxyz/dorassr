# Apple 应用目标（macOS / iOS）的共享 CMake 逻辑。
# 与其手写并维护 .xcodeproj，这里用一份声明式定义，由
# `cmake -G Xcode` 生成工程：pbxproj 成为构建产物而非仓库资产。
#
# 用法（由 Projects/<platform>/CMakeLists.txt 提供 DORA_APPLE_PLATFORM）:
#   cmake -B build -G Xcode -DCMAKE_SYSTEM_NAME=iOS ...   (iOS)
#   cmake --build build

include_guard(GLOBAL)

function(dora_add_apple_app)
	set(options)
	set(one TARGET PLATFORM)
	cmake_parse_arguments(DA "${options}" "${one}" "" ${ARGN})

	set(app ${DA_TARGET})
	set(platform ${DA_PLATFORM}) # macos | ios

	set(DORA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
	set(DORA_SOURCE_ROOT "${DORA_ROOT}/Source")
	set(DORA_BGFX_ROOT "${DORA_SOURCE_ROOT}/3rdParty/bgfx")
	set(DORA_SDL2_ROOT "${DORA_SOURCE_ROOT}/3rdParty/SDL2")

	if(platform STREQUAL "macos")
		set(DORA_LIB_SUFFIX macOS)
		set(DORA_BX_COMPAT osx)
		set(DORA_BUILD_STYLE universal)
	else()
		set(DORA_BX_COMPAT ios)
		if(NOT DORA_IOS_VARIANT)
			set(DORA_IOS_VARIANT simulator)
		endif()
		# 模拟器与真机的 SDL2/Love/theora/wa/Rust 预编译库是不同产物
		if(DORA_IOS_VARIANT STREQUAL "simulator")
			set(DORA_LIB_SUFFIX iOS-Simulator)
		else()
			set(DORA_LIB_SUFFIX iOS)
		endif()
	endif()

	# ---- 预编译库路径（与 Tools/build-scripts 的产物布局一致；
	#      注意 xmake 平台名是 macosx/iphoneos，iOS 库分 device/simulator）----
	if(platform STREQUAL "macos")
		set(DORA_BGFX_LIB_DIR "${DORA_BGFX_ROOT}/build/macosx/universal")
	else()
		if(NOT DORA_IOS_VARIANT)
			set(DORA_IOS_VARIANT simulator)
		endif()
		set(DORA_BGFX_LIB_DIR "${DORA_BGFX_ROOT}/build/ios/${DORA_IOS_VARIANT}")
	endif()
	set(DORA_SDL2_LIB "${DORA_SDL2_ROOT}/Lib/${DORA_LIB_SUFFIX}/libSDL2.a")
	set(DORA_LOVE_LIB "${DORA_SOURCE_ROOT}/3rdParty/Love/Artifacts/${DORA_LIB_SUFFIX}/liblove.a")
	set(DORA_THEORA_LIB "${DORA_SOURCE_ROOT}/3rdParty/theora/Lib/${DORA_LIB_SUFFIX}/libtheoradec.a")
	set(DORA_WA_LIB "${DORA_SOURCE_ROOT}/3rdParty/Wa/Lib/${DORA_LIB_SUFFIX}/libwa.a")
	set(DORA_RUNTIME_LIB "${DORA_SOURCE_ROOT}/Rust/lib/${DORA_LIB_SUFFIX}/libdora_runtime.a")

	foreach(lib bgfx bimg bimg_decode bx shaderc-lib glslang spirv-cross spirv-opt)
		if(NOT EXISTS "${DORA_BGFX_LIB_DIR}/lib${lib}.a")
			message(FATAL_ERROR "missing ${DORA_BGFX_LIB_DIR}/lib${lib}.a -- run Tools/build-scripts/build_lib_bgfx.sh first")
		endif()
	endforeach()

	# ---- 源 ----
	include("${DORA_ROOT}/Projects/CMake/DoraEngineSources.cmake")
	include("${DORA_ROOT}/Projects/CMake/DoraGeneratedSources.cmake")

	# 平台实现以 .mm 补充可移植 .cpp（Application.cpp 内部有平台守卫，
	# 与 Application.mm 共存）；nfd 文件对话框：Apple 用 nfd_cocoa.m，
	# 排除 Linux 的 DBus 后端
	list(FILTER DORA_ENGINE_SOURCES EXCLUDE REGEX "/3rdParty/nfd/nfd_portal\\.cpp$")

	set(DORA_APPLE_SOURCES
		"${DORA_SOURCE_ROOT}/Basic/Application.mm"
		"${DORA_SOURCE_ROOT}/Basic/Content.mm"
		"${DORA_SOURCE_ROOT}/Render/RenderSurface.mm")
	if(platform STREQUAL "macos")
		list(APPEND DORA_APPLE_SOURCES "${DORA_SOURCE_ROOT}/3rdParty/nfd/nfd_cocoa.m")
	endif()

	add_executable(${app}
		${DORA_ENGINE_SOURCES}
		${DORA_APPLE_SOURCES})
	dora_add_generated_lua_sources(${app})

	set_target_properties(${app} PROPERTIES
		OUTPUT_NAME "Dora"
		MACOSX_BUNDLE TRUE
		MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Dora/Info.plist"
		XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "IppClub.DoraSSR"
		XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
		XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
		XCODE_ATTRIBUTE_CLANG_ENABLE_MODULES "YES")

	# 资源
	if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Dora/Assets.xcassets")
		target_sources(${app} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/Dora/Assets.xcassets")
		set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/Dora/Assets.xcassets" PROPERTIES
			MACOSX_PACKAGE_LOCATION Resources)
	endif()

	# ---- 头文件与定义（与 Linux CMake 对齐，去 DBUS/X11，bx compat 换 Apple）----
	target_include_directories(${app} PRIVATE
		"${DORA_SDL2_ROOT}/include"
		"${DORA_BGFX_ROOT}/include"
		"${DORA_SOURCE_ROOT}/3rdParty/bimg/include"
		"${DORA_SOURCE_ROOT}/3rdParty/bx/include"
		"${DORA_SOURCE_ROOT}/3rdParty/bx/include/compat/${DORA_BX_COMPAT}"
		"${DORA_SOURCE_ROOT}"
		"${DORA_SOURCE_ROOT}/3rdParty"
		"${DORA_SOURCE_ROOT}/3rdParty/Love/src"
		"${DORA_SOURCE_ROOT}/3rdParty/Love/src/modules"
		"${DORA_SOURCE_ROOT}/3rdParty/JoltPhysics"
		"${DORA_SOURCE_ROOT}/3rdParty/Lua"
		"${DORA_SOURCE_ROOT}/3rdParty/Zip"
		"${DORA_SOURCE_ROOT}/3rdParty/soloud"
		"${DORA_SOURCE_ROOT}/3rdParty/lodepng"
		"${DORA_SOURCE_ROOT}/3rdParty/imgui"
		"${DORA_SOURCE_ROOT}/3rdParty/implot"
		"${DORA_SOURCE_ROOT}/3rdParty/font"
		"${DORA_SOURCE_ROOT}/3rdParty/sqlite"
		"${DORA_SOURCE_ROOT}/3rdParty/dragonBones"
		"${DORA_SOURCE_ROOT}/3rdParty/wasm3"
		"${DORA_SOURCE_ROOT}/3rdParty/Zip/zlib"
		"${DORA_SOURCE_ROOT}/3rdParty/Effekseer"
		"${DORA_SOURCE_ROOT}/3rdParty/theora/include")

	target_compile_definitions(${app} PRIVATE
		WITH_SDL2
		BX_CONFIG_DEBUG=0
		d_m3HasWASI
		SPDLOG_FMT_EXTERNAL
		JPH_NO_FORCE_INLINE)
	if(platform STREQUAL "ios")
		# iOS 禁用 system()，Lua 走 l_system 空实现
		target_compile_definitions(${app} PRIVATE LUA_USE_IOS=1)
	endif()

	# ---- 预编译库 ----
	set(DORA_VENDOR_LIBS "")
	foreach(lib bgfx bimg bimg_decode bx shaderc-lib glslang spirv-cross spirv-opt)
		add_library(apple-${lib} STATIC IMPORTED)
		set_target_properties(apple-${lib} PROPERTIES IMPORTED_LOCATION
			"${DORA_BGFX_LIB_DIR}/lib${lib}.a")
		list(APPEND DORA_VENDOR_LIBS apple-${lib})
	endforeach()

	target_link_libraries(${app} PRIVATE
		"${DORA_SDL2_LIB}"
		"${DORA_LOVE_LIB}"
		"${DORA_THEORA_LIB}"
		"${DORA_WA_LIB}"
		"${DORA_RUNTIME_LIB}"
		${DORA_VENDOR_LIBS}
		z)

	# ---- 系统框架（与原 xcodeproj 链接清单一致）----
	if(platform STREQUAL "macos")
		target_link_libraries(${app} PRIVATE
			"-framework Cocoa" "-framework IOKit" "-framework Carbon"
			"-framework OpenGL" "-framework QuartzCore" "-framework Metal"
			"-framework MetalKit" "-framework CoreVideo" "-framework CoreMedia"
			"-framework VideoToolbox" "-framework AudioToolbox" "-framework AudioUnit"
			"-framework CoreAudio" "-framework CoreFoundation" "-framework CoreHaptics"
			"-framework GameController" "-framework ForceFeedback")
	else()
		target_link_libraries(${app} PRIVATE
			"-framework UIKit" "-framework Foundation" "-framework CoreGraphics"
			"-framework QuartzCore" "-framework Metal" "-framework CoreVideo"
			"-framework CoreMedia" "-framework VideoToolbox" "-framework AudioToolbox"
			"-framework CoreAudio" "-framework CoreHaptics" "-framework CoreBluetooth"
			"-framework CoreMotion" "-framework GameController" "-framework AVFoundation"
			"-e _SDL_main")
	endif()
endfunction()

# CI trigger: this file is watched by macos.yml/ios.yml since the xcodeproj removal.
