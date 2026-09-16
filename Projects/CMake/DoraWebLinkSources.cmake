# Web-only source set needed to turn the portable Dora engine objects into a
# linked browser executable. These libraries are built from source because the
# native archives under Source/3rdParty are platform-specific.
include_guard(GLOBAL)

if(NOT DEFINED DORA_SOURCE_ROOT)
	message(FATAL_ERROR "DORA_SOURCE_ROOT must be set before loading Web link sources")
endif()

file(GLOB DORA_WEB_BX_SOURCES CONFIGURE_DEPENDS
	"${DORA_SOURCE_ROOT}/3rdParty/bx/src/*.cpp")
# amalgamated.cpp 由上游提供但本构建使用分文件编译，排除以防符号重复
list(FILTER DORA_WEB_BX_SOURCES EXCLUDE REGEX "/amalgamated\.cpp$")
file(GLOB DORA_WEB_BIMG_SOURCES CONFIGURE_DEPENDS
	"${DORA_SOURCE_ROOT}/3rdParty/bimg/src/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bimg/3rdparty/astc-encoder/source/*.cpp")
# image_encode.cpp 依赖未随 vendor 保留的编码库（libsquish/nvtt/etcpak 等）
list(FILTER DORA_WEB_BIMG_SOURCES EXCLUDE REGEX "/image_encode\.cpp$")

# glslang + SPIRV-Tools + SPIRV-Cross：新版 shaderc 的 GLSL/SPIR-V 路径依赖
file(GLOB DORA_WEB_GLSLANG_SOURCES CONFIGURE_DEPENDS
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/glslang/glslang/GenericCodeGen/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/glslang/glslang/MachineIndependent/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/glslang/glslang/MachineIndependent/preprocessor/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/glslang/glslang/OSDependent/Unix/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/glslang/glslang/HLSL/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/glslang/glslang/ResourceLimits/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/glslang/SPIRV/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/glslang/SPIRV/CInterface/*.cpp")
file(GLOB DORA_WEB_SPIRV_TOOLS_SOURCES CONFIGURE_DEPENDS
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/spirv-tools/source/opt/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/spirv-tools/source/val/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/spirv-tools/source/*.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/spirv-tools/source/util/*.cpp")
list(FILTER DORA_WEB_SPIRV_TOOLS_SOURCES EXCLUDE REGEX "/mimalloc\.cpp$")
file(GLOB DORA_WEB_SPIRV_CROSS_SOURCES CONFIGURE_DEPENDS
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/3rdparty/spirv-cross/*.cpp")
list(FILTER DORA_WEB_SPIRV_CROSS_SOURCES EXCLUDE REGEX "spirv_cross_c\.cpp$")
list(FILTER DORA_WEB_SPIRV_CROSS_SOURCES EXCLUDE REGEX "/main\.cpp$")

set(DORA_WEB_BGFX_SOURCES
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/bgfx.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/debug_renderdoc.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/glcontext_html5.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_agc.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_d3d11.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_d3d12.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_gl.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_gnm.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_mtl.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_noop.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_nvn.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_vk.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/renderer_webgpu.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/shader.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/topology.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/vertexlayout.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/video_d3d11.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/video_d3d12.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/video_mtl.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/bgfx/src/video_vk.cpp"
	"${DORA_SOURCE_ROOT}/Shader/DoraShaderc/DoraShaderc.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/shaderc/pp.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/shaderc/shaderc.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/shaderc/shaderc_dxil_stub.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/shaderc/shaderc_glsl.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/shaderc/shaderc_hlsl.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/shaderc/shaderc_metal.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/shaderc/shaderc_pssl.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/shaderc/shaderc_spirv.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/shaderc/shaderc_wgsl.cpp")

set(DORA_WEB_LINK_SOURCES
	"${DORA_SOURCE_ROOT}/3rdParty/theora/TheoraSources.c"
	${DORA_WEB_BX_SOURCES}
	${DORA_WEB_BIMG_SOURCES}
	${DORA_WEB_GLSLANG_SOURCES}
	${DORA_WEB_SPIRV_TOOLS_SOURCES}
	${DORA_WEB_SPIRV_CROSS_SOURCES}
	${DORA_WEB_BGFX_SOURCES})
