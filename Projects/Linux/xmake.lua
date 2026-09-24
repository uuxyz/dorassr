-- Linux 应用目标：取代手写的 CMake 流程（Stage 2 of xmake unification）。
-- vendor 库由 Tools/build-scripts/build_lib_linux.sh 构建（SDL3 走系统包，
-- bgfx/Love 走 xmake，Wa 走 Go，Rust 走 Cargo），本工程按路径链接其产物。
--
-- 用法（在 Projects/Linux 下）:
--   xmake f -c -p linux -a x86_64 -m release -y
--   xmake -j8 dora

set_project("Dora-Linux")

local DORA_ROOT = path.join(os.scriptdir(), "../..")
local DORA_SOURCE_ROOT = path.join(DORA_ROOT, "Source")
local HOST_ARCH = os.getenv("DORA_HOST_ARCH") or os.arch()
local WA_LIB_ARCH = HOST_ARCH == "x86_64" and "amd64" or HOST_ARCH
local MODE_DIR = is_mode("debug") and "debug" or "release"
local BGFX_LIB_DIR = path.join(DORA_SOURCE_ROOT, "3rdParty/bgfx/build/linux", HOST_ARCH, MODE_DIR)
local VENDOR_LIBS = { "bgfx", "bimg", "bimg_decode", "bx", "shaderc-lib", "glslang", "spirv-cross", "spirv-opt" }

-- 引擎可移植源清单（与 Projects/CMake/DoraEngineSources.cmake 保持同步）
local sources = {
		"../../Source/Platformer/AINode.cpp",
		"../../Source/Platformer/Define.cpp",
		"../../Source/Platformer/AI.cpp",
		"../../Source/Platformer/Data.cpp",
		"../../Source/Platformer/VisualCache.cpp",
		"../../Source/Platformer/PlatformCamera.cpp",
		"../../Source/Platformer/Unit.cpp",
		"../../Source/Platformer/Face.cpp",
		"../../Source/Platformer/PlatformWorld.cpp",
		"../../Source/Platformer/BulletDef.cpp",
		"../../Source/Platformer/Bullet.cpp",
		"../../Source/Platformer/UnitAction.cpp",
		"../../Source/Platformer/VisualCache.cpp",
		"../../Source/Cache/AtlasCache.cpp",
		"../../Source/Cache/Cache.cpp",
		"../../Source/Cache/ClipCache.cpp",
		"../../Source/Cache/ShaderCache.cpp",
		"../../Source/Cache/ParticleCache.cpp",
		"../../Source/Cache/TextureCache.cpp",
		"../../Source/Cache/SkeletonCache.cpp",
		"../../Source/Cache/ModelCache.cpp",
		"../../Source/Cache/Model3DCache.cpp",
		"../../Source/Cache/DragonBoneCache.cpp",
		"../../Source/Cache/AudioCache.cpp",
		"../../Source/Cache/FontCache.cpp",
		"../../Source/Cache/FrameCache.cpp",
		"../../Source/Animation/Action.cpp",
		"../../Source/Animation/Animation.cpp",
		"../../Source/Animation/ModelDef.cpp",
		"../../Source/Audio/Audio.cpp",
		"../../Source/Basic/Application.cpp",
		"../../Source/Basic/AutoreleasePool.cpp",
		"../../Source/Basic/Content.cpp",
		"../../Source/Basic/Database.cpp",
		"../../Source/Basic/Director.cpp",
		"../../Source/Basic/Object.cpp",
		"../../Source/Basic/Scheduler.cpp",
		"../../Source/Common/Async.cpp",
		"../../Source/Common/Debug.cpp",
		"../../Source/Common/MemoryPool.cpp",
		"../../Source/Common/Singleton.cpp",
		"../../Source/Common/Utils.cpp",
		"../../Source/Const/Header.cpp",
		"../../Source/Effect/Effect.cpp",
		"../../Source/Effect/Material.cpp",
		"../../Source/Entity/Entity.cpp",
		"../../Source/Event/Event.cpp",
		"../../Source/Event/EventQueue.cpp",
		"../../Source/Event/EventType.cpp",
		"../../Source/Event/Listener.cpp",
		"../../Source/GUI/ImGuiBinding.cpp",
		"../../Source/GUI/ImGuiDora.cpp",
		"../../Source/Http/HttpServer.cpp",
		"../../Source/Input/Controller.cpp",
		"../../Source/Input/Keyboard.cpp",
		"../../Source/Input/Mouse.cpp",
		"../../Source/Input/TouchDispather.cpp",
		"../../Source/Love/LoveNode.cpp",
		"../../Source/Love/LoveRuntime.cpp",
		"../../Source/Love/LoveVideoSources.cpp",
		"../../Source/Lua/LuaEngine.cpp",
		"../../Source/Lua/LuaFromXml.cpp",
		"../../Source/Lua/LuaHandler.cpp",
		"../../Source/Lua/LuaManual.cpp",
		"../../Source/Lua/TealCompiler.cpp",
		"../../Source/Lua/ToLua/tolua_event.cpp",
		"../../Source/Lua/ToLua/tolua_map.cpp",
		"../../Source/Lua/ToLua/tolua_push.cpp",
		"../../Source/Lua/ToLua/tolua_to.cpp",
		"../../Source/Lua/ToLua/tolua_is.cpp",
		"../../Source/Lua/Xml/DoraTag.cpp",
		"../../Source/Lua/Xml/XmlResolver.cpp",
		"../../Source/ML/ML.cpp",
		"../../Source/Node/AlignNode.cpp",
		"../../Source/Node/AudioSource.cpp",
		"../../Source/Node/ClipNode.cpp",
		"../../Source/Node/DragonBone.cpp",
		"../../Source/Node/DrawNode.cpp",
		"../../Source/Node/EffekNode.cpp",
		"../../Source/Node/Grid.cpp",
		"../../Source/Node/Label.cpp",
		"../../Source/Node/Light3D.cpp",
		"../../Source/Node/Menu.cpp",
		"../../Source/Node/Model.cpp",
		"../../Source/Node/Model3D.cpp",
		"../../Source/Node/Node.cpp",
		"../../Source/Node/Node3D.cpp",
		"../../Source/Node/Particle.cpp",
		"../../Source/Node/Playable.cpp",
		"../../Source/Node/Spine.cpp",
		"../../Source/Node/Sprite.cpp",
		"../../Source/Node/Surface3D.cpp",
		"../../Source/Node/TIC80Node.cpp",
		"../../Source/Node/TileNode.cpp",
		"../../Source/Node/VGNode.cpp",
		"../../Source/Node/VideoNode.cpp",
		"../../Source/Node/View3D.cpp",
		"../../Source/Node/Visual3D.cpp",
		"../../Source/Physics/Body.cpp",
		"../../Source/Physics/BodyDef.cpp",
		"../../Source/Physics/DebugDraw.cpp",
		"../../Source/Physics/Joint.cpp",
		"../../Source/Physics/JointDef.cpp",
		"../../Source/Physics/JoltBridge.cpp",
		"../../Source/Physics/PhysicsWorld.cpp",
		"../../Source/Physics/Sensor.cpp",
		"../../Source/Platformer/AINode.cpp",
		"../../Source/Render/Camera.cpp",
		"../../Source/Render/Camera3D.cpp",
		"../../Source/Render/RenderSurface.cpp",
		"../../Source/Render/RenderTarget.cpp",
		"../../Source/Render/Renderer.cpp",
		"../../Source/Render/VGRender.cpp",
		"../../Source/Render/View.cpp",
		"../../Source/Shader/Builtin.cpp",
		"../../Source/Shader/ShaderCompiler.cpp",
		"../../Source/Support/Array.cpp",
		"../../Source/Support/Common.cpp",
		"../../Source/Support/Dictionary.cpp",
		"../../Source/Support/Geometry.cpp",
		"../../Source/Support/Value.cpp",
		"../../Source/3rdParty/font/font_manager.cpp",
		"../../Source/3rdParty/Zip/miniz.c",
		"../../Source/Wasm/WasmRuntime.cpp",
		"../../Source/Wasm/RustRuntimeBridge.cpp",
}

target("dora")
	set_kind("binary")
	set_basename("dora-ssr")
	set_targetdir(path.join(os.scriptdir(), "build", MODE_DIR))

	for _, p in ipairs(sources) do
		add_files(p)
	end
	-- tolua 生成的绑定
	add_files(
		path.join(DORA_SOURCE_ROOT, "Lua/LuaBinding.cpp"),
		path.join(DORA_SOURCE_ROOT, "Lua/LuaBindingWeb.cpp"),
		path.join(DORA_SOURCE_ROOT, "Lua/LuaCode.cpp"),
		path.join(DORA_SOURCE_ROOT, "Lua/LuaCodeWeb.cpp"),
		path.join(DORA_SOURCE_ROOT, "Lua/TealCompiler.cpp"))

	set_pcxxheader(path.join(DORA_SOURCE_ROOT, "Const/Header.h"))

	add_defines(
		"WITH_SDL2_STATIC",
		"d_m3HasWASI",
		"LUA_USE_LINUX",
		"SPDLOG_FMT_EXTERNAL",
		"JPH_NO_FORCE_INLINE",
		"BGFX_PLATFORM_SUPPORTS_DXBC=0",
		"BGFX_PLATFORM_SUPPORTS_WGSL=0")
	set_languages("c++20")
	add_cxxflags("-msse4.2", { force = true })
	if is_mode("debug") then
		add_defines("BX_CONFIG_DEBUG=1")
	else
		add_defines("BX_CONFIG_DEBUG=0")
	end

	local ver = os.getenv("DORA_VERSION_OVERRIDE")
	if ver then
		add_defines('DORA_VERSION_OVERRIDE="' .. ver .. '"')
	end
	local rev = os.getenv("DORA_REVISION_OVERRIDE")
	if rev then
		add_defines('DORA_REVISION_OVERRIDE="' .. rev .. '"')
	end

	add_includedirs(
		path.join(DORA_SOURCE_ROOT, "3rdParty/bgfx/include"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/bimg/include"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/bx/include"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/bx/include/compat/linux"),
		DORA_SOURCE_ROOT,
		path.join(DORA_SOURCE_ROOT, "3rdParty"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Love/src"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Love/src/modules"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Love/src/libraries"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/JoltPhysics"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Lua"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Zip"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/soloud"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/lodepng"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/imgui"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/implot"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/font"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/sqlite"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/dragonBones"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/wasm3"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Zip/zlib"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Effekseer"),
		path.join(DORA_SOURCE_ROOT, "3rdParty/theora/include"))

	if is_plat("linux") then
		add_cxxflags("-Wno-psabi", { force = true })
	end

	-- vendor + 第三方预编译库链接
	add_linkdirs(
		BGFX_LIB_DIR,
		path.join(DORA_SOURCE_ROOT, "3rdParty/Love/Artifacts/Linux", HOST_ARCH),
		path.join(DORA_SOURCE_ROOT, "3rdParty/theora/Lib/Linux", HOST_ARCH),
		path.join(DORA_SOURCE_ROOT, "3rdParty/Wa/Lib/Linux", WA_LIB_ARCH),
		path.join(DORA_ROOT, "Source/Rust/lib/Linux", HOST_ARCH))
	add_links(
		"bgfx", "bimg", "bimg_decode", "bx",
		"shaderc-lib", "glslang", "spirv-cross", "spirv-opt",
		"love", "theoradec", "wa", "dora_runtime")

	-- SDL3 via pkg-config
	add_extpackages("pkgconfig::sdl3")

	-- 渲染/系统库
	if HOST_ARCH == "aarch64" then
		add_syslinks("EGL", "GLESv2")
	else
		add_syslinks("GL")
	end
	add_syslinks("dbus-1", "z", "m", "dl", "pthread", "rt")

	-- 头文件目录：DBus
	add_includedirs(
		"/usr/include/dbus-1.0",
		"/usr/lib/" .. HOST_ARCH .. "-linux-gnu/dbus-1.0/include")
