-- Windows 应用目标：取代手写的 Dora.vcxproj/Dora.sln。
-- vendor 库由 Tools/bgfx/xmake.lua（build_lib_bgfx_windows.bat）构建，
-- SDL2/Love/theora/wa/Rust 由 Tools/build-scripts/build_lib_windows.bat 构建，
-- 本工程只负责引擎与应用的编译链接。
--
-- 用法（在 Projects/Windows 下）:
--   xmake f -c -p windows -a x86 -m debug -y
--   xmake -j8 dora

set_project("Dora-Windows")

local DORA_ROOT = path.join(os.scriptdir(), "../..")
local DORA_SOURCE_ROOT = path.join(DORA_ROOT, "Source")
local MODE_DIR = is_mode("debug") and "debug" or "release"
local SDL_MODE = is_mode("debug") and "Debug" or "Release"
local BGFX_LIB_DIR = path.join(DORA_SOURCE_ROOT, "3rdParty/bgfx/build/windows/x86", MODE_DIR)
local VENDOR_LIBS = { "bgfx", "bimg", "bimg_decode", "bx", "shaderc-lib", "glslang", "spirv-cross", "spirv-opt" }

target("dora")
	set_kind("binary")
	set_basename("Dora")
	set_targetdir(path.join(os.scriptdir(), "build", MODE_DIR))

	-- 源清单（一次性从原 vcxproj 提取）；.c 文件按 C++ 编译（原工程 /TP）
	local sources = include("sources.lua")
	local c_sources = {}
	for _, p in ipairs(sources) do
		if p:find("%.c$") then
			table.insert(c_sources, p)
		else
			add_files(p)
		end
	end
	for _, p in ipairs(c_sources) do
		add_files(p, { sourcekind = "cxx" })
	end
	add_files("Dora/Resource.rc")

	-- 预编译头（原工程 Const/Header.h）
	set_pcxxheader(path.join(DORA_SOURCE_ROOT, "Const/Header.h"))

	-- 定义（原 vcxproj 公共集）
	add_defines(
		"WIN32",
		"_WINDOWS",
		"_MBCS",
		"_CRT_SECURE_NO_WARNINGS",
		"_SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING",
		"WITH_SDL2_STATIC",
		"SDL_MAIN_HANDLED",
		"d_m3HasWASI",
		"LUA_USE_WINDOWS",
		"SPDLOG_FMT_EXTERNAL")
	if is_mode("debug") then
		add_defines("_ITERATOR_DEBUG_LEVEL=0")
	end

	-- 头文件目录（原 vcxproj 全局 IncludePath）
	add_includedirs(
		DORA_SOURCE_ROOT,
		path.join(DORA_SOURCE_ROOT, "3rdParty"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Love/src"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/JoltPhysics"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/bx/include/bx/compat/msvc"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/bgfx/include"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/bx/include"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/bimg/include"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/SDL2/include"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Lua"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Zip"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/soloud"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/lodepng"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/imgui"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/implot"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/sqlite"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/dragonBones"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/wasm3"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Zip/zlib"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Effekseer"))

	-- 警告抑制（原 vcxproj）
	add_cxxflags("/utf-8", "/wd4244", "/wd4996", "/wd4200", { force = true })

	-- vendor 库（build_lib_bgfx_windows.bat 的产物，显式路径链接）
	for _, name in ipairs(VENDOR_LIBS) do
		add_files(path.join(BGFX_LIB_DIR, name .. ".lib"))
	end

	-- 预编译第三方库（build_lib_windows.bat 的产物）
	add_files(
		path.join(DORA_SOURCE_ROOT, "3rdParty/SDL2/Lib/Windows", SDL_MODE, "SDL2.lib"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Love/Artifacts/Windows/love.lib"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/theora/Lib/Windows", SDL_MODE, "theoradec.lib"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Wa/Lib/Windows/wa.lib"),
		path.join(DORA_SOURCE_ROOT, "Rust/lib/Windows/dora_runtime.lib"))

	-- 系统库（原 vcxproj 链接行）
	add_syslinks("psapi", "setupapi", "userenv", "winmm", "imm32", "version",
		"ws2_32", "gdi32", "advapi32", "crypt32", "user32", "ntdll")

	-- 窗口子系统（WinMain 在 Application.cpp 中）
	add_ldflags("/SUBSYSTEM:WINDOWS", { force = true })
