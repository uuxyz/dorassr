/*
  Native File Dialog Extended
  Repository: https://github.com/btzy/nativefiledialog-extended
  License: Zlib
  Authors: Bernard Teo

  This header contains a function to convert an SDL window handle to a native window handle for
  passing to NFDe.

  This is meant to be used with SDL2, but if there are incompatibilities with future SDL versions,
  we can conditionally compile based on SDL_MAJOR_VERSION.
 */

#ifndef _NFD_SDL2_H
#define _NFD_SDL2_H

#include <SDL3/SDL_error.h>
#include "nfd/nfd.h"
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#define NFD_INLINE inline
#else
#define NFD_INLINE static inline
#endif  // __cplusplus

/**
 *  Converts an SDL window handle to a native window handle that can be passed to NFDe.
 *  @param sdlWindow The SDL window handle.
 *  @param[out] nativeWindow The output native window handle, populated if and only if this function
 *  returns true.
 *  @return Either true to indicate success, or false to indicate failure.  If false is returned,
 * you can call SDL_GetError() for more information.  However, it is intended that users ignore the
 * error and simply pass a value-initialized nfdwindowhandle_t to NFDe if this function fails. */
NFD_INLINE bool NFD_GetNativeWindowFromSDLWindow(SDL_Window* sdlWindow,
                                                 nfdwindowhandle_t* nativeWindow) {
    SDL_PropertiesID props = SDL_GetWindowProperties(sdlWindow);
    void* handle = nullptr;
#if defined(SDL_VIDEO_DRIVER_WINDOWS)
    if (!handle)
        handle = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WIN32_HWND_POINTER, nullptr);
    if (handle) {
        nativeWindow->type = NFD_WINDOW_HANDLE_TYPE_WINDOWS;
        nativeWindow->handle = handle;
        return true;
    }
#endif
#if defined(SDL_VIDEO_DRIVER_COCOA)
    if (!handle)
        handle = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, nullptr);
    if (handle) {
        nativeWindow->type = NFD_WINDOW_HANDLE_TYPE_COCOA;
        nativeWindow->handle = handle;
        return true;
    }
#endif
#if defined(SDL_VIDEO_DRIVER_X11)
    if (!handle)
        handle = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_X11_WINDOW_POINTER, nullptr);
    if (handle) {
        nativeWindow->type = NFD_WINDOW_HANDLE_TYPE_X11;
        nativeWindow->handle = handle;
        return true;
    }
#endif
    (void)nativeWindow;
    SDL_SetError("Unsupported native window type.");
    return false;
}

#undef NFD_INLINE
#ifdef __cplusplus
}
#endif  // __cplusplus

#endif  // _NFD_SDL2_H
