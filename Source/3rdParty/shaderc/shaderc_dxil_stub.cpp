/*
 * Copyright 2026. License: BSD-2-Clause
 *
 * Dora vendor addition: link stub for platforms without the Windows DXC
 * toolchain. shaderc.cpp references bgfx::compileDxilShader unconditionally,
 * but shaderc_dxil.cpp only compiles where the Windows SDK headers exist.
 */

#include "shaderc.h"

namespace bgfx
{
	bool compileDxilShader(const Options& _options, uint32_t _version, const std::string& _code, bx::WriterI* _writer, bx::WriterI* _messages)
	{
		BX_UNUSED(_options, _version, _code, _writer, _messages);
		return false;
	}

} // namespace bgfx
