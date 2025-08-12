package main

import sugar "sugar"
import ngl "nord_gl"

//////////////////////////////////////////////////////////////////////
// Section: Global Data
//////////////////////////////////////////////////////////////////////
game_initialized := false
globals: Globals

// I was thinking of tossing in a `time:f32`
// and got worried it'd lose precision so fast.
// 
// I usually use it for trig. I wonder if it's not just better
// To wrap an f32 from 0 to pi continuously. Plenty of precision there.
//
// That's an angle integrated over time. dtheta
Globals :: struct {
	// Engine
	gl_standard:     GL_Standard,
	ren:             ^Ren,
	instances:       Aligned_Array(Ren_Instance),
	_entity_storage: [max(Entity_ID)]Entity_Memory,
	entities:        [dynamic]^Entity_Memory,
	game_entities:   [dynamic]^Entity_Memory,
	ui_entities:     [dynamic]^Entity_Memory,
	// Coupled State (between Engine and Renderer)
	uniforms:        Uniforms,

	// Window/Framebuffer
	resolution:      [2]int,
	aspect_ratio:    f32,
	time:            f32,
	tau_time:        f32,

	// Camera
	game_camera:     Mat4,
	ui_orthographic: Mat4,
	game_view:       Mat4,
	ui_view:         Mat4,
	camera:          Camera3D,

	// Editor
	gizmo_asset:     Ren_Asset,

	// Controls
	quit:        sugar.Button_Action,
	left_click:  sugar.Button_Action,
	right_click: sugar.Button_Action,
	space:       sugar.Button_Action,

	// Game State
	water_plane: ^Entity,
	marker:      ^Entity,
	plane_mesh:  Geom_Mesh2
}

GL_Standard :: struct {
	UNIFORM_BUFFER_OFFSET_ALIGNMENT: int,
	MAX_UNIFORM_BLOCK_SIZE: i64
}

//////////////////////////////////////////////////////////////////////
// Section: Entities
//////////////////////////////////////////////////////////////////////

Entity_ID :: u16

// I've prefixed anything that isn't for gameplay with _
Entity :: struct {
	_id: Entity_ID, // index in storage.
	_used: bool,
	_ui:   bool, // 2D object anchored at origin in top-left (0,0)
	_asset: Ren_Asset,
	_distance_from_camera: f32,
	//
	gizmo: bool,
	//
	position: Vec3,
	rotation: Vec3,
	scale:    f32, // PUNT nonuniform scale
	hidden:   bool,
	using instance: ^Ren_Instance,
}

X_Entity :: struct {
	using entity: Entity,
	using pillar: X
}
X :: struct {}

// ASSUME: All variants are subtypes of Entity.
Entity_Memory :: struct #packed {
	using entity: Entity,
	using variant: struct #raw_union {
		x: X,
	},
	// Can Transmute to Variants if I keep this below.
	tag: enum {
		Entity,
		X
	},
}

//////////////////////////////////////////////////////////////////////
// Section: Renderer
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
}

Ren_Instance :: struct {
	model_transform: Mat4,
	uv_transform:    Vec4,
	color:           Vec4,
}

Uniforms :: struct #align(16) {
	view:       Mat4,
	projection: Mat4,
}

Ren_Vertex_Base :: struct {
	position: Vec3,
	texcoord: Vec2,
}

Ren_Asset :: struct {
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
