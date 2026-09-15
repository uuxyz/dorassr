/* Copyright (c) 2016-2026 Li Jin <dragon-fly@qq.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#pragma once

/* The only render-device header the general engine code may depend on. It
   exposes the device's frozen ABI constants and hides naming drift behind
   DORA_* shims so upstream renames are absorbed here in one place. */

#include <bgfx/defines.h>

/* Texture formats appended by Dora. Current vendored tree (API 129 + patch)
   names them EACR/EACRS/EACRG/EACRGS; upstream bgfx (#3487, API >= 130ish)
   names them EACR11/EACR11S/EACRG11/EACRG11S. Flip the four lines below when
   upgrading and the whole engine follows. */
#define DORA_TEXTURE_FORMAT_EACR bgfx::TextureFormat::EACR
#define DORA_TEXTURE_FORMAT_EACRS bgfx::TextureFormat::EACRS
#define DORA_TEXTURE_FORMAT_EACRG bgfx::TextureFormat::EACRG
#define DORA_TEXTURE_FORMAT_EACRGS bgfx::TextureFormat::EACRGS
