/* Copyright (c) 2016-2026 Li Jin <dragon-fly@qq.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#pragma once

struct SDL_Window;

NS_DORA_BEGIN

/* Owns everything the engine touches at render-device startup and shutdown:
   native window handles, swap chain setup, device init/reset, and the frame
   pump. This is the single file that must be adapted when the render device
   changes its initialization API; the rest of the engine depends only on the
   bgfx-free interface below. */

class RenderSurface : public NonCopyable {
public:
	/* Desktop platforms only. Initializes the video subsystem if needed and
	   applies window creation attributes required by special display drivers
	   (KMSDRM needs GLES attributes before the window exists). Returns the
	   adjusted window flags and sets fullscreen when the driver demands it. */
	uint32_t prepareWindowCreation(uint32_t windowFlags, bool& fullscreen);
	/* Captures native window handles from the SDL window (or the Web canvas).
	   Must be called after the window is created and before initDevice. */
	bool attach(SDL_Window* window);
	/* Initializes the render device. Call once from the logic thread. */
	bool initDevice();
	/* Destroys the render device without going through the Life system. */
	void destroyDevice();
	PROPERTY_READONLY_BOOL(DeviceInitialized);
	virtual ~RenderSurface();
	/* Submits the current frame. Logic thread only. */
	uint32_t nextFrame();
	/* Pumps the render thread and presents the frame where SDL owns the
	   swap. Main thread only. */
	void pump();
	/* Pumps until the render thread reports no context. Main thread only. */
	void drain();
	/* Releases the externally created GL context, if one was made. */
	void detach();
	/* Applies a new backbuffer size together with reset flags. */
	void reset(uint32_t width, uint32_t height, uint64_t flags);
	/* Re-extracts the native window and hands it to the render device.
	   Android replaces its surface when the app returns to foreground. */
	void onNativeWindowChanged();
	void requestScreenShot(const char* filepath);
	PROPERTY_READONLY(double, GPUTime);

	SINGLETON_REF(RenderSurface, Application);

private:
	bool initPlatformData();
	bool _deviceInitialized = false;
	SDL_Window* _window = nullptr;
	void* _glContext = nullptr;
	/* Raw platform window handles captured by attach(). Stored as plain data
	   so this header does not expose render device types. */
	void* _windowHandle = nullptr;
	void* _displayHandle = nullptr;
	void* _contextHandle = nullptr;
	bool _wayland = false;
};

#define SharedRenderSurface \
	Dora::Singleton<Dora::RenderSurface>::shared()

NS_DORA_END
