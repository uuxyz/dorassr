SDL2 Source
===========

This vendored SDL2 source is based on the official libsdl-org SDL2
release **2.32.0** (commit 7a44b1ab002cee6efa56d3b4c0e146b7fbaed80b),
pruned to the layout required to build the engine dependency:
`include/`, `src/`, the CMake files, this source note, the SDL license,
and the Dora-specific `xmake.lua`.

Local modifications (enumerated):

1. `include/SDL_hints.h`, `src/video/kmsdrm/*`,
   `include/SDL_config_linux.h`: KMSDRM embedded-Linux support --
   Rockchip/Mali GBM buffer compatibility (drmModeAddFB instead of
   modifiers), XRGB8888 surface format, explicit EGL config attributes,
   async pageflip disabled for older KMSDRM stacks, and the
   SDL_HINT_KMSDRM_DISABLE_CURSOR hint.
2. `include/SDL_config_{android,iphoneos,macosx,windows}.h`: SDL's own
   render backends (D3D/D3D11/D3D12/Metal/GL/GLES) and AAUDIO are
   disabled -- Dora renders through bgfx and plays audio through
   SoLoud; SDL is used for window/input/platform integration only.
