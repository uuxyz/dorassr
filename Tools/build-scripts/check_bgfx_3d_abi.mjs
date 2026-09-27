import assert from "node:assert/strict";
import {readFileSync, readdirSync} from "node:fs";

const header = readFileSync("Source/3rdParty/bgfx/include/bgfx/c99/bgfx.h", "utf8");
const ffi = readFileSync("Source/Rust/src/bgfx_rs/bgfx_sys/ffi.rs", "utf8");
const wrapper = readFileSync("Source/Rust/src/bgfx_rs/static_lib.rs", "utf8");

const enumBody = header.match(/typedef enum bgfx_attrib[\s\S]*?\{([\s\S]*?)BGFX_ATTRIB_COUNT/);
assert.ok(enumBody, "bgfx attribute enum was not found");
const attributes = [...enumBody[1].matchAll(/\bBGFX_ATTRIB_([A-Z0-9]+)\s*,/g)]
	.map((match) => match[1]);
assert.ok(attributes.length > 0, "bgfx attribute enum is empty");

attributes.forEach((name, index) => {
	assert.match(ffi, new RegExp(`pub const BGFX_ATTRIB_${name}: bgfx_attrib = ${index};`),
		`Rust bgfx attribute ${name} differs from the C header`);
});
assert.match(ffi, new RegExp(`pub const BGFX_ATTRIB_COUNT: bgfx_attrib = ${attributes.length};`));

const typeBody = header.match(/typedef enum bgfx_attrib_type[\s\S]*?\{([\s\S]*?)BGFX_ATTRIB_TYPE_COUNT/);
assert.ok(typeBody, "bgfx attribute type enum was not found");
const types = [...typeBody[1].matchAll(/\bBGFX_ATTRIB_TYPE_([A-Z0-9]+)\s*,/g)]
	.map((match) => match[1]);
types.forEach((name, index) => {
	assert.match(ffi, new RegExp(`pub const BGFX_ATTRIB_TYPE_${name}: bgfx_attrib_type = ${index};`),
		`Rust bgfx attribute type ${name} differs from the C header`);
});
assert.match(ffi, new RegExp(`pub const BGFX_ATTRIB_TYPE_COUNT: bgfx_attrib_type = ${types.length};`));

const textureBody = header.match(/typedef enum bgfx_texture_format[\s\S]*?\{([\s\S]*?)BGFX_TEXTURE_FORMAT_COUNT/);
assert.ok(textureBody, "bgfx texture format enum was not found");
const textureFormats = [...textureBody[1].matchAll(/\bBGFX_TEXTURE_FORMAT_([A-Z0-9]+)\s*,/g)]
	.map((match) => match[1]);
const modelSources = readdirSync("Source/Rust/src/dora_3d")
	.filter((name) => name.endsWith(".rs"))
	.map((name) => readFileSync(`Source/Rust/src/dora_3d/${name}`, "utf8"))
	.join("\n");
const functions = [...new Set([...modelSources.matchAll(/bgfx_sys::(bgfx_[a-zA-Z0-9_]+)\s*\(/g)]
	.map((match) => match[1]))];
for (const name of functions) {
	const c = header.match(new RegExp(`BGFX_C_API\\s+[^;\\n]*?\\b${name}\\s*\\(([^)]*)\\);`));
	const rust = ffi.match(new RegExp(`pub fn\\s+${name}\\s*\\((.*?)\\)\\s*(?:->|;)`, "s"));
	assert.ok(c && rust, `${name} is missing from a bgfx declaration`);
	const cParams = c[1].split(",").filter((param) => param.trim() && param.trim() !== "void");
	const rustParams = rust[1].split(",").filter((param) => param.trim());
	assert.equal(rustParams.length, cParams.length,
		`${name} has ${rustParams.length} Rust parameters but ${cParams.length} C parameters`);
}
textureFormats.forEach((name, index) => {
	if (new RegExp(`\\bBGFX_TEXTURE_FORMAT_${name}\\b`).test(modelSources)) {
		assert.match(ffi, new RegExp(`pub const BGFX_TEXTURE_FORMAT_${name}: bgfx_texture_format = ${index};`),
			`Rust bgfx texture format ${name} differs from the C header`);
	}
});

for (const [source, structure] of [[ffi, "bgfx_vertex_layout_s"], [wrapper, "VertexLayoutBuilder"]]) {
	const body = source.match(new RegExp(`pub struct ${structure} \\{([\\s\\S]*?)\\n\\}`));
	assert.ok(body, `${structure} was not found`);
	for (const field of ["offset", "attributes"]) {
		assert.match(body[1], new RegExp(`pub ${field}: \\[u16; ${attributes.length}usize\\]`),
			`${structure}.${field} has the wrong bgfx ABI length`);
	}
}

console.log(`bgfx 3D ABI matches ${attributes.length} vertex attributes, ${types.length} types, ${functions.length} function signatures, and used texture formats`);
