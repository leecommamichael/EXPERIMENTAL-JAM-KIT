package main

// Purpose: This file is a non-comprehensive overview of
//          data which crosses layer-boundaries in the program.

import sugar "sugar"
import ngl "nord_gl"
import stbtt "vendor:stb/truetype"

//////////////////////////////////////////////////////////////////////
// Section: Framework + App Data
//////////////////////////////////////////////////////////////////////
globals: Globals

Globals :: struct {
	// Assets
	assets: Asset_Bundle,
	fonts: Fonts,
	// Render Service
	gl_standard: GL_Standard,
	ren:         ^Ren,
	// Entity Service
	_entity_storage: [max(Entity_ID)]Entity_Memory,
	entities:        [dynamic]^Entity_Memory,
	game_entities:   [dynamic]^Entity_Memory,
	ui_entities:     [dynamic]^Entity_Memory,
	// Render+Entity Integration
	instances:       Aligned_Array(Ren_Instance),
	uniforms:        Uniforms,
	game_camera:     Mat4,
	ui_orthographic: Mat4,
	game_view:       Mat4,
	ui_view:         Mat4,
	// TODO: make this var an interface to modify the above
	camera:          Camera3D,

	// App Data
	water_plane:     ^Entity,
	water_heightmap: []f32,
	marker:          ^Entity,
	plane_mesh:      Geom_Mesh2
}

GL_Standard :: struct {                 // RTX-4070 ,          ,
	UNIFORM_BUFFER_OFFSET_ALIGNMENT: int, // 256   web, same  win,
	MAX_UNIFORM_BLOCK_SIZE: i64,          // 65536 web, same  win,
	MAX_TEXTURE_SIZE: i64,                // 16384 web, 32768 win,
}
// Looks like 16K textures is standard for the past decade.

//////////////////////////////////////////////////////////////////////
// Section: Entities
//////////////////////////////////////////////////////////////////////

Entity_ID :: u16

// I've prefixed anything that isn't for gameplay with _
Entity :: struct {
	id: Entity_ID,  // index in storage.
	used: bool,     // like "alive"
	is_3D: bool,    // 2D object anchored at origin in top-left (0,0)
	draw_command: Draw_Command,
	distance_from_camera: f32,
	//
	gizmo: bool,
	//
	position: Vec3,
	rotation: Vec3,
	scale:    f32, // PUNT nonuniform scale
	hidden:   bool,
	using instance: ^Ren_Instance,
}

Text_Entity :: struct {
	using entity:  Entity,
	using variant: Text,
}
Text :: struct {
	text: string,
	font: ^Font,
}

// ASSUMES: All variants are subtypes of Entity.
Entity_Memory :: struct #packed {
	using entity: Entity,
	using variant: struct #raw_union {
		text: Text_Entity,
	},
	// Can Transmute to Variants if I keep this below.
	tag: Entity_Variant
}

// This enables a safe specializing cast to a variant.
#assert(offset_of(Entity_Memory, variant) > 
	offset_of(Entity_Memory, entity))
#assert(offset_of(Entity_Memory, tag) > 
	offset_of(Entity_Memory, variant))

// I think ASAN implicated the wrong line of code, BUT:
// When I had Font as a non-pointer the program crashed.
// So here's an assert that serves as a reminder to keep variants small.
#assert(size_of(Entity_Memory) < 256)

Entity_Variant :: enum {
	None,
	Text
}

//////////////////////////////////////////////////////////////////////
// Section: Render
//////////////////////////////////////////////////////////////////////

Ren :: struct {
	program:      ngl.Program,
	VAO:          ngl.VertexArrayObject,
	frame_UBO:    ngl.Buffer,
	instance_UBO: ngl.Buffer,           // constant
	programs: [Game_Shader]ngl.Program, // constant
	instance_buffer: ngl.Buffer,        // union of all instances
}

Game_Shader :: enum {
	Basic,
	Water,
}

Ren_Instance :: struct {
	model_transform: Mat4,
	uv_transform:    Vec4,
	color:           Vec4,
}

Uniforms :: struct #align(16) {
	view:       Mat4,
	projection: Mat4,
	time:     f32,
	tau_time: f32,
	padding0: Vec2, // std140
}

Ren_Vertex_Base :: struct {
	position: Vec3,
	texcoord: Vec2,
	normal:   Vec3,
}

Draw_Command :: struct {
	program:     ngl.Program,
	VAO:         ngl.VertexArrayObject,
	index_count: int,
	mode:        Ren_Mode,
	VBO:         ngl.Buffer,
}

//  Shader_Input
//  .field_offset indicates the offset of the attribute into the struct.
//  .type         of vec2 == ngl.FLOAT ; vec3 = ngl.FLOAT ; i32 == ngl.INT ...
//	.value_count  of vec2 == 2        ; f32 == 1        ; mat4 == 16 ...
//  .location     is computed when the shader is created, based upon the order of
//                inputs in the attribute slice and the # of slots their data types require.
//   Example:
//     The Bindings { {type=.mat4}, {type=.f32} } take up 5 slots.
//     The first binding is a mat4 at location=0, and takes 4 slots.
//     The second binding is an f32 at location=4, and takes up 1 slot.
Shader_Input :: struct {
	type:          GLSL_Attribute_Type,
	rate:          Shader_Input_Rate,
	field_offset:  uintptr,
	buffer:        Ren_Buffer,
	// These are really just caches.
	location:      uint,
	value_count:   int,
	ngl_type:      ngl.Data_Type
}

Ren_Buffer :: struct {
	id:            ngl.Buffer,
	element_size:  int,
}

Shader_Input_Rate :: enum {
	Vertex,
	Instance,
}

GLSL_Attribute_Type :: enum {
	f32, vec2, vec3, vec4,
	mat4,
	i32, ivec2, ivec3, ivec4,
	u32, uvec2, uvec3, uvec4,
}

//////////////////////////////////////////////////////////////////////
// Section: Text
//////////////////////////////////////////////////////////////////////

// What you need to render text.
Font :: struct {
	name:       string,
	file_bytes: []u8,
	height_px:  f32,
	// bitmap:     [512*512]u8,
	scale:      f32,
	is_monospace: bool, // otherwise proportional
	// stb related data
	info: stbtt.fontinfo,
	data: []stbtt.packedchar,
  // Scaled metrics
  monospace_advance: f32,
  ascent:            f32,
  descent:           f32,
  line_height:       f32,
  line_gap:          f32,
}

// What you need to render _styled_ text.
Font_Family :: [Font_Variant]Font

Font_Variant :: enum {
	regular,
	bold,
	italic,
	bold_italic
}