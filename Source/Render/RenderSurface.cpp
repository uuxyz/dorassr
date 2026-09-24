/* Copyright (c) 2016-2026 Li Jin <dragon-fly@qq.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#include "Const/Header.h"

#include "Render/RenderSurface.h"

#include "Basic/Application.h"

#include <SDL3/SDL.h>
#if BX_PLATFORM_ANDROID
#include <SDL3/SDL_system.h>
#endif

#include <bgfx/bgfx.h>


#if BX_PLATFORM_IOS
/* Implemented in RenderSurface.mm. */
void* createIOSMetalLayer(SDL_Window* window);
#endif

NS_DORA_BEGIN

uint32_t RenderSurface::prepareWindowCreation(uint32_t windowFlags, bool& fullscreen) {
#if BX_PLATFORM_LINUX
	/* SDL_CreateWindow initializes video lazily, but KMSDRM GL attributes
	   must be set before that window (and its EGL surface) is created. */
	if (SDL_InitSubSystem(SDL_INIT_VIDEO) != 0) {
		Error("SDL failed to initialize video! {}", SDL_GetError());
		return windowFlags;
	}
	const char* videoDriver = SDL_GetCurrentVideoDriver();
	const bool useKmsdrmGL = videoDriver && std::strcmp(videoDriver, "KMSDRM") == 0;
	if (useKmsdrmGL) {
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
		SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
		SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
		SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
		SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 8);
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
		/* ClipNode needs stencil storage in the SDL-owned default framebuffer. */
		SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
		windowFlags |= SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN | SDL_WINDOW_BORDERLESS;
		fullscreen = true;
	}
#else
	DORA_UNUSED_PARAM(windowFlags);
	DORA_UNUSED_PARAM(fullscreen);
#endif // BX_PLATFORM_LINUX
	return windowFlags;
}

bool RenderSurface::initPlatformData() {
#if BX_PLATFORM_EMSCRIPTEN
	_windowHandle = const_cast<char*>("#canvas");
	return true;
#else
	SDL_PropertiesID props = SDL_GetWindowProperties(_window);
	if (props == 0) {
		Error("SDL failed to provide window properties! {}", SDL_GetError());
		return false;
	}
#if BX_PLATFORM_OSX
	_windowHandle = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, nullptr);
#elif BX_PLATFORM_WINDOWS
	_windowHandle = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WIN32_HWND_POINTER, nullptr);
#elif BX_PLATFORM_ANDROID
	_windowHandle = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_ANDROID_WINDOW_POINTER, nullptr);
#elif BX_PLATFORM_IOS
	/* Implemented in RenderSurface.mm: iOS renders through a CAMetalLayer
	   added to the window's root view. */
	_windowHandle = createIOSMetalLayer(_window);
	if (!_windowHandle) {
		Error("failed to create the Metal layer for the window!");
		return false;
	}
	return true;
#elif BX_PLATFORM_LINUX
	if (SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, nullptr)) {
		_displayHandle = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, nullptr);
		_windowHandle = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, nullptr);
		_wayland = true;
	} else if (SDL_GetPointerProperty(props, SDL_PROP_WINDOW_KMSDRM_GBM_DEVICE_POINTER, nullptr)) {
		_glContext = SDL_GL_CreateContext(_window);
		if (!_glContext) {
			Error("SDL failed to create KMSDRM GL context! {}", SDL_GetError());
			return false;
		}
		if (SDL_GL_MakeCurrent(_window, s_cast<SDL_GLContext>(_glContext)) != 0) {
			Error("SDL failed to make KMSDRM GL context current! {}", SDL_GetError());
			return false;
		}
		_contextHandle = _glContext;
		int stencilBits = 0;
		if (SDL_GL_GetAttribute(SDL_GL_STENCIL_SIZE, &stencilBits) != 0) {
			Warn("SDL failed to query KMSDRM stencil buffer! {}", SDL_GetError());
		} else {
			Println("KMSDRM stencil buffer: {} bits", stencilBits);
			if (stencilBits < 8) {
				Warn("KMSDRM framebuffer has fewer than 8 stencil bits; ClipNode clipping may fail.");
			}
		}
	} else {
		_displayHandle = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_X11_DISPLAY_POINTER, nullptr);
		_windowHandle = (void*)(uintptr_t)SDL_GetNumberProperty(props, SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
	}
#endif // BX_PLATFORM
	return true;
#endif // BX_PLATFORM_EMSCRIPTEN
}

bool RenderSurface::attach(SDL_Window* window) {
	_window = window;
	return initPlatformData();
}

bool RenderSurface::initDevice() {
	AssertIf(_deviceInitialized, "render device is already initialized.");
	bgfx::Init init{};
	/* Dora can render the host scene, Web IDE/ImGui, and embedded Love render
	   targets in the same bgfx frame. The bgfx defaults (6 MiB vertex / 2 MiB
	   index) are too small for otherwise valid Love workloads once the host UI
	   has consumed part of the frame-local pool. Keep an explicit fixed budget;
	   transient buffers are recycled by bgfx and do not grow across frames. */
	init.limits.maxTransientVbSize = 16 << 20;
	init.limits.maxTransientIbSize = 4 << 20;
#if BX_PLATFORM_LINUX
	if (_contextHandle) {
		init.type = bgfx::RendererType::OpenGLES;
	}
#endif // BX_PLATFORM_LINUX
	init.platformData.context = _contextHandle;
	if (_wayland) {
		init.platformData.type = bgfx::NativeWindowHandleType::Wayland;
	}
	init.swapChain.nwh = _windowHandle;
	init.swapChain.ndt = _displayHandle;
	_deviceInitialized = bgfx::init(init);
	return _deviceInitialized;
}

void RenderSurface::destroyDevice() {
	if (_deviceInitialized) {
		bgfx::shutdown();
		_deviceInitialized = false;
	}
}

bool RenderSurface::isDeviceInitialized() const noexcept {
	return _deviceInitialized;
}

uint32_t RenderSurface::nextFrame() {
	return bgfx::frame();
}

void RenderSurface::pump() {
	bgfx::renderFrame();
	if (_glContext) {
		SDL_GL_SwapWindow(_window);
	}
}

void RenderSurface::drain() {
	while (bgfx::RenderFrame::NoContext != bgfx::renderFrame());
}

void RenderSurface::detach() {
	if (_glContext) {
		SDL_GL_DestroyContext(s_cast<SDL_GLContext>(_glContext));
		_glContext = nullptr;
	}
}

void RenderSurface::reset(uint32_t width, uint32_t height, uint64_t flags) {
	bgfx::SwapChain sc{};
	sc.nwh = _windowHandle;
	sc.ndt = _displayHandle;
	sc.width = width;
	sc.height = height;
	bgfx::reset(flags, &sc);
}

void RenderSurface::onNativeWindowChanged() {
#if BX_PLATFORM_ANDROID
	SDL_PropertiesID props = SDL_GetWindowProperties(_window);
	if (props != 0) {
		bgfx::SwapChain sc{};
		sc.nwh = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_ANDROID_WINDOW_POINTER, nullptr);
		bgfx::reset(0, &sc);
	}
#else
	DORA_UNUSED_PARAM(_window);
#endif // BX_PLATFORM_ANDROID
}

void RenderSurface::requestScreenShot(const char* filepath) {
	bgfx::requestScreenShot(BGFX_INVALID_HANDLE, filepath);
}

double RenderSurface::getGPUTime() const noexcept {
	const bgfx::Stats* stats = bgfx::getStats();
	if (stats->gpuTimeEnd < stats->gpuTimeBegin) {
		return 0;
	}
	return s_cast<double>(stats->gpuTimeEnd - stats->gpuTimeBegin) / s_cast<double>(stats->gpuTimerFreq);
}

RenderSurface::~RenderSurface() {
	destroyDevice();
}

NS_DORA_END
