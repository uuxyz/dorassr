local globals = {lfs=true}
lfs = require("lfs")
TOLUA_VERSION = "1.0.92+dora"

-- Builds configured with --dora_spine=n set DORA_TOLUA_NO_SPINE before
-- invoking the generator. The Spine runtime is then excluded from the
-- binary, so the parsed package must not reference its symbols either:
-- emit a header copy without the Spine class and point the packages at it.
local noSpine = os.getenv("DORA_TOLUA_NO_SPINE")
if noSpine then
	local f = io.open("Dora.h", "r")
	assert(f, "Dora.h not found next to tolua++.lua")
	local content = f:read("*a")
	f:close()
	local stripped, count = content:gsub("\nclass Spine : public Playable\n%{.-\n%};\n", "\n")
	assert(count == 1, "expected exactly one Spine class declaration in Dora.h, found " .. tostring(count))
	local out = io.open("DoraNoSpine.h", "w")
	assert(out, "failed to write DoraNoSpine.h")
	out:write(stripped)
	out:close()
end

for k in pairs(_G) do
	globals[k] = true
end

for _,v in ipairs({
		{t=true,D=true,L="basic.lua",o="../../Source/Lua/LuaBinding.cpp",f="LuaBinding.pkg",lua_entry=true},
		{t=true,D=true,L="basic.lua",o="../../Source/Lua/LuaBindingWeb.cpp",f="LuaBindingWeb.pkg",lua_entry=true},
		{t=true,D=true,L="basic.lua",o="../../Source/Lua/LuaCode.cpp",f="LuaCode.pkg",lua_entry=true},
		{t=true,D=true,L="basic.lua",o="../../Source/Lua/LuaCodeWeb.cpp",f="LuaCodeWeb.pkg",lua_entry=true},
		{t=true,D=true,L="basic.lua",o="../../Source/Lua/TealCompiler.cpp",f="TealCompiler.pkg",lua_entry=true},
	}) do

	keys = {}
	for k in pairs(_G) do
		if not globals[k] then
			table.insert(keys,k)
		end
	end
	for _,k in ipairs(keys) do
		_G[k] = nil
	end

	if noSpine then
		local pkg = io.open(v.f, "r")
		assert(pkg, "package not found: " .. v.f)
		local pkgSrc = pkg:read("*a")
		pkg:close()
		if pkgSrc:find('$pfile "Dora.h"', 1, true) then
			local altName = v.f:gsub("%.", ".nospine.", 1)
			local alt = io.open(altName, "w")
			assert(alt, "failed to write " .. altName)
			alt:write((pkgSrc:gsub('$pfile "Dora.h"', '$pfile "DoraNoSpine.h"')))
			alt:close()
			v.f = altName
		end
	end

	_extra_parameters = {}
	flags = v

	local files = {
		"tolua++/compat.lua",
		"tolua++/basic.lua",
		"tolua++/feature.lua",
		"tolua++/verbatim.lua",
		"tolua++/code.lua",
		"tolua++/typedef.lua",
		"tolua++/container.lua",
		"tolua++/package.lua",
		"tolua++/module.lua",
		"tolua++/namespace.lua",
		"tolua++/define.lua",
		"tolua++/enumerate.lua",
		"tolua++/declaration.lua",
		"tolua++/variable.lua",
		"tolua++/array.lua",
		"tolua++/function.lua",
		"tolua++/operator.lua",
		"tolua++/template_class.lua",
		"tolua++/class.lua",
		"tolua++/clean.lua",
		"tolua++/doit.lua"
	}

	for _,file in ipairs(files) do
		dofile(file)
	end

	local err,msg = pcall(doit)
	if not err then
		local _,_,label,msg = strfind(msg,"(.-:.-:%s*)(.*)")
		error(msg..tostring(label))
		print(debug.traceback())
	end

end

if noSpine then
	os.remove("DoraNoSpine.h")
	for _,name in ipairs({"LuaBinding", "LuaBindingWeb", "LuaCode", "LuaCodeWeb", "TealCompiler"}) do
		os.remove(name .. ".nospine.pkg")
	end
end
