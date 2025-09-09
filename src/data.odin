package main

// Purpose: This file is a non-comprehensive overview of
//          data which crosses layer-boundaries in the program.

import sugar "sugar"
import gl "nord_gl"
import stbtt "vendor:stb/truetype"

//////////////////////////////////////////////////////////////////////
// Section: Framework + App Data
//////////////////////////////////////////////////////////////////////

globals: Globals
MAX_GLYPHS_PER_FRAME :: 1 << 13 // 8K
Globals :: struct {
	// Assets
	assets: Asset_Bundle,
	fonts: [Font_Usage]Font_Family,
	// Render Service
	gl_standard: GL_Standard,
	ren:         ^Ren,
	// Entity Service
	// ubo_instance_data: Aligned_Array(Any_Instance), // TODO: Unused. Make it lights some day?
	_entity_storage: [max(Entity_ID)]Entity_Memory,
	entities:        [dynamic]^Entity,
	entities_2D:     [dynamic]^Entity,
	entities_3D:     [dynamic]^Entity,
	// This instance data is shared by across many (all?) shaders.
	// That means no intelligent BufferSubData to minimize traffic.
	// I must write to it everything which is needed by any draw command.
	// It also means that persistent data between runs of a command must be
	// managed separately. Probably attached to Entity variants, if not global.
	// TODO: rename entity_instance_staging
	instance_staging: [max(Entity_ID)]Any_Instance,
	instance_buffer:  gl.Buffer,

	// Text Rendering
	glyph_staging:    [MAX_GLYPHS_PER_FRAME]Any_Instance,
	glyph_buffer:     gl.Buffer,
	glpyh_offset:     int,
	immediate_glyph_staging: [MAX_GLYPHS_PER_FRAME]Any_Instance,
	immediate_glyph_buffer:  gl.Buffer,

	// Render+Entity Integration
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
INSTANCE_DATA_MAX_SIZE :: GLES_MAX_BINDINGS * size_of(Vec4)

Entity :: struct {
	type:  Entity_Type,
	id:    Entity_ID,  // index in storage.
	used:  bool,       // like "alive"
	is_3D: bool,       // 2D object anchored at origin in top-left (0,0)
	draw_command: Draw_Command,
	distance_from_camera: f32,
	parent:          ^Entity,
	using transform: Transform,
	// sometimes things will program in terms of these fields.
	// - animations choose different uvs,
	// - 3d needs to sort by position
	// - color is useful for debugging.
	// This means a singular (non-instanced) thing needs to be 
	using instance: ^Any_Instance, // This will be copied.
	hidden:   bool,
}

Transform :: struct {
	position: Vec3,
	rotation: Vec3,
	scale:    f32, // PUNT nonuniform scale
}


// ASSUMES: All variants are subtypes of Entity.
Entity_Memory :: struct #packed {
	using entity: Entity,
	using variant: struct #raw_union {
		text: Text,
	},
}

// This enables a safe specializing cast to a variant.
#assert(
	offset_of(Entity_Memory, entity) <
	offset_of(Entity_Memory, variant)
)

// I think ASAN implicated the wrong line of code, BUT:
// When I had Font as a non-pointer the program crashed.
// So here's an assert that serves as a reminder to keep variants small.
#assert(size_of(Entity_Memory) < 512) // arbitary, but FYI (512 * 1<<16) = 6 MB 

Entity_Type :: enum {
	None, // Generic, Any, Basic, Base
	Text
}

//////////////////////////////////////////////////////////////////////
// Section: Render
//////////////////////////////////////////////////////////////////////

Ren :: struct {
	prev_cmd:  Draw_Command,
	frame_UBO: gl.Buffer,
	programs:  [Game_Shader]gl.Program, // constant
	textures: [16]Texture_Binding
}

Game_Shader :: enum {
	Basic,
	Text,
	Image,
	UI_Box,
	Water,
}

Any_Instance :: struct {
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
	program:      gl.Program,
	VAO:          gl.VertexArrayObject,
	// attributes:   []Attribute_Binding, // easy to add. might do for debug.
	textures:     []Texture_Binding,
	index_buffer: gl.Buffer,
	index_count:  int,
		// Dynamic State Below (in the Vulkan sense) it's cheap to change per-draw.
	mode:         Ren_Mode,
}
#assert(size_of(Draw_Command) < 90, "Be mindful of this increasing.")

Texture_Binding :: struct {
	texture_unit:   u32, // binding point
	target:         gl.Texture_Target,
	texture:        gl.Texture, // TODO: associate this to prebundlefilenames
		// For copying
	format: gl.Internal_Color_Format,
	width:  int,
	height: int,
	level:  int,
		// Texture Unit State (all fields below are optional)
	magnify_filter: gl.Texture_Mag_Filter,
	minify_filter:  gl.Texture_Min_Filter,
	wrap_ST:        [2]gl.Texture_Wrap_Mode,
		// Fields below are more likely to matter in 3D.
	wrap_R:         gl.Texture_Wrap_Mode,
	base_level:     uint,
	max_level:      uint,
	min_LOD:        f32,
	max_LOD:        f32,
	compare_func:   gl.Compare_Func,
	compare_mode:   gl.Texture_Compare_Mode,
}

//  Interface ----------------------------------------- (fields you must assign)
//    .type         : The glsl data-type of the attribute
//    .rate         : Specifies if the attribute is per-vertex or per-instance.
//    .offset       : Used to extract fields from interleaved vertex structs.
//                  |   e.g. offset_of(Vertex, position)
//    .buffer       : The data-source for the given input.
//
//  Implementation ------------------------------ (fields you should not assign)
//    .value_count: Inferred from type.  e.g. vec2 is 2, and mat4 is 16.
//    .location   : The GLSL location of the attribute, which is computed when the
//                | shader is created. 
//                | For vertex attributes, it is based upon the order of inputs in
//                | the attribute slice and the number of slots
//                | their data types require.
//                |   For Example:
//                | > The Bindings { {type=.mat4}, {type=.f32} } take up 5 slots.
//                | > The first binding is a mat4 at location=0, and takes 4 slots.
//                | > The second binding is an f32 at location=4, and takes up 1 slot.
Attribute_Binding :: struct {
	buffer: gl.Buffer,
	rate:   Shader_Input_Rate,
	type:   GLSL_Attribute_Type,
	stride: int,
	offset: uintptr,
	// implementation details, don't manually init.
	// these are initialized by ren_make_draw_command
	location:    uint,
	value_count: int,
	gl_type:     gl.Data_Type
}

GLSL_Attribute_Type :: enum {
	f32, vec2, vec3, vec4,
	mat4,
	i32, ivec2, ivec3, ivec4,
	u32, uvec2, uvec3, uvec4,
}

Shader_Input_Rate :: enum {
	Vertex,
	Instance,
}

//////////////////////////////////////////////////////////////////////
// Section: Text
//////////////////////////////////////////////////////////////////////

