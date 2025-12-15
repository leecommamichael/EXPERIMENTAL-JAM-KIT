package main

// Purpose: This file is a non-comprehensive overview of
//          data which crosses layer-boundaries in the program.

import "core:time"
import "core:dynlib"
import sugar "sugar"
import gl "angle"

//////////////////////////////////////////////////////////////////////
// Section: Framework + App Data
//////////////////////////////////////////////////////////////////////

globals: ^Globals
MAX_GLYPHS_PER_FRAME :: 1 << 13 // 8K
MAX_COLLISIONS_PER_FRAME :: 100
Globals :: struct {
	// Reload
	hot_reloaded_this_frame: bool,
	hot_reload: proc (engine_globals: ^Globals, engine_pc: ^PC_State),
	game_step:  proc (),
	game_dll:   dynlib.Library,
	// General
	cursor:     ^Entity,
	sugar:      sugar.Memory,
	tick:       f32,
	dt:         f32,
	avg_fps:    f64,
	// Assets
	assets: Asset_Bundle,
	fonts: [Font_Usage][Font_Variant]Font,
	// Render Service
	gl_standard: GL_Standard,
	ren:         ^Ren,
	// Entity Service
	// ubo_instance_data: Aligned_Array(Any_Instance), // TODO: Unused. Make it lights some day?
	_entity_storage: [max(Entity_ID)]Entity,
	entities:        [dynamic]^Entity,
	entities_2D:     [dynamic]^Entity,
	entities_3D:     [dynamic]^Entity,
	immediate_entities: map[u64]^Entity,
	// This instance data is shared by across many (all?) shaders.
	// That means no intelligent BufferSubData to minimize traffic.
	instance_staging: [max(Entity_ID)]Any_Instance,
	instance_buffer:  gl.Buffer,

	// Text Rendering
	glyph_staging:    [MAX_GLYPHS_PER_FRAME]Any_Instance,
	glyph_buffer:     gl.Buffer,

	canvas_size_px:      [2]f32,
	canvas_scale:        [2]f32,
	canvas_scaling:      Canvas_Scaling,
	canvas_stretch:      [2]f32, // after scaling.
	canvas_stretching:   Canvas_Scaling,
	framebuffer_size_px: [2]f32, // canvas_size_px * canvas_scale * canvas_stretch
	mouse_position:      [2]f32, // in the canvas.
	ui_mouse_position:   [2]f32, // in the canvas.
	// Render+Entity Integration /////////////////////////////////////////////////
	// How much each pixel stretched while fitting to the window AFTER framebuffer scaling.
	// Measures the # of fragments covered by each input pixel.
	// See `Canvas_Scaling`
	uniforms:                Uniforms,
	perspective_projection:  Mat4,
	perspective_view:        Mat4,
	orthographic_projection: Mat4,
	orthographic_view:       Mat4,
	ui_projection:           Mat4,
	ui_view:                 Mat4,
	camera:                  Camera,

	old_collisions:   [dynamic]Collision, // last frame/sample
	collisions:       [dynamic]Collision,
	enter_collisions: [dynamic]Collision,
	exit_collisions:  [dynamic]Collision,
	collider_visualization: ^Entity,
	pointer_focus: ^Entity,
	button_focus:  ^Entity,
	z_cursor: f32,
	collider_draw_commands: [Collision_Shape]Draw_Command,
	unit_circle_mesh: Geom_Mesh2,
	unit_quad_mesh:   Geom_Mesh2,
	draw_colliders: bool,

	// App Data
}

// Looks like 16K textures is standard for the past decade.
GL_Standard :: struct {                 // RTX-4070 ,          ,
	UNIFORM_BUFFER_OFFSET_ALIGNMENT: int, // 256   web, same  win,
	MAX_UNIFORM_BLOCK_SIZE: i64,          // 65536 web, same  win,
	MAX_TEXTURE_SIZE: i64,                // 16384 web, 32768 win,
}

Canvas_Scaling :: enum {
	// The framework will not set the `canvas_scale` as the window resizes.
	Fixed,
	// `canvas_scale` changes as the OS window changes. Keeps base resolution aspect ratio.
	Smooth_Aspect,
	// `canvas_scale` changes as the OS window changes. Completely fills the window.
	Fill_Window,
	// `canvas_scale` will only have integer values.
	Integer_Aspect,
}

//////////////////////////////////////////////////////////////////////
// Section: Entities
//////////////////////////////////////////////////////////////////////

Entity_ID :: u16
INSTANCE_DATA_MAX_SIZE :: GLES_MAX_BINDINGS * size_of(Vec4)

Entity :: struct {
	name:            string,
	immediate_hash:  u64,
	id:              Entity_ID,  // index in storage.
	flags:           bit_set[Entity_Flag; u64],
	time_scale:      f32,
	basis:           Transform,
	using transform: Transform,
	old_basis:       Transform,
	old_transform:   Transform, // for interpolation of fixed timestep
	collider:        Collider,
	velocity:             Vec3,
	acceleration:         Vec3,
	angular_velocity:     Vec3,
	angular_acceleration: Vec3,
	distance_from_camera: f32,
	using instance:  ^Any_Instance, // rendered visual representation of transforms
	draw_command:    Draw_Command,
	ui: UI_Element,
	variant: union {
		Text_State,
		Image_State,
		Sprite_State,
		Timed_Effect_State(Empty_Struct),
	},
	parent: ^Entity,
	children: []^Entity,
}

Entity_Flag :: enum {
	Allocated,
	Immediate_Mode,
	Immediate_In_Use,// immediate _step functions mark the entity as used. framework clears it.
	Is_3D,
	Hidden,
	Collider_Enabled,
	Physics_Skip_Integrate,
	Skip_Interpolation,
	Is_UI,
	Shader_Reload_Failed,
}

Transform :: struct {
	position: Vec3,
	rotation: Vec3,
	scale:    Vec3,
}

Collider :: struct {
	shape: Collision_Shape,
	size:  Vec3, // use collider_size(entity) instead.
	layer: bit_set[Collision_Layer; u32], // what it is defined to be.
	mask:  bit_set[Collision_Layer; u32], // what it may contact.
}

Collision_Layer :: enum {
	Default,
	Terrain,
	Ball,
	Board,
	Wheel,
}

Collision_Shape :: enum {
	None,
	Point,
	AABB,
	Circle, // Positive, uniform scales only. No Ellipses. No asserts will catch you yet.
	// Rect,
}

Collision :: struct {
	ids:   [2]Entity_ID,
	// This field is not created by collision-detection.
	// When game code queries for collisions relative to _some entity_,
	// 	this is the _other_ entity in any collisions found.
	other: ^Entity
}

//////////////////////////////////////////////////////////////////////
// Section: Render
//////////////////////////////////////////////////////////////////////

Ren :: struct {
	canvas:    Render_Target,
	prev_cmd:  Draw_Command,
	frame_UBO: gl.Buffer,
	programs:  [Game_Shader]gl.Program,
	textures:  [16]GPU_Texture,
	linear_sampler:  gl.Sampler,
	nearest_sampler: gl.Sampler,
}

Game_Shader :: enum {
	Basic,
	Text,
	Image,
	UI_Box,
	Water,
	Sprite,
	Framebuffer_Texture,
}

Any_Instance :: struct {
	model_transform: Mat4,
	uv_transform:    Vec4,
	color:           Vec4,
}

// Keep synchronized with global constant frame_uniforms :: string
Uniforms :: struct #align(16) {
	view:           Mat4, // 4 slots
	projection:     Mat4, // 4 slots
	time:           f32,  // 1 slot
	tau_time:       f32,  // 1 slot
	ball_position:  Vec2, // 2 slots
	ball_size:      Vec2, // 2 slots
	hand_position:  Vec2, // 2 slots
	hand_size:      Vec2, // 2 slots
	canvas_size_px: Vec2  // 2 slots
}

Ren_Vertex_Base :: struct {
	position: Vec3,
	texcoord: Vec2,
	normal:   Vec3,
}

Draw_Command :: struct {
	render_target: gl.Framebuffer,
	program:       gl.Program,
	VAO:           gl.VertexArrayObject,
	attributes:    []Attribute_Binding,
	textures:      []GPU_Texture,
	index_buffer:  gl.Buffer,
	index_count:   int,
		// Dynamic State Below (in the Vulkan sense) it's cheap to change per-draw.
	mode:          Ren_Mode,  // default triangles
	cull_mode:     Cull_Mode, // default none
}
#assert(size_of(Draw_Command) < 256, "Be mindful of this increasing.")

Render_Target :: struct {
	fbo:           gl.Framebuffer,
	color:         gl.Texture,
	depth_stencil: gl.Texture,
	size_px:       [2]int
}

GPU_Texture :: struct {
	target:         gl.Texture_Target,
	texture:        gl.Texture, // TODO: associate this to prebundlefilenames
		// For copying
	format: gl.Internal_Color_Format,
	size_px: [2]int,
	level:   int,
		// Texture Unit State (all fields below are optional)
	magnify_filter: gl.Texture_Mag_Filter,
	minify_filter:  gl.Texture_Min_Filter,
	wrap_ST:        [2]gl.Texture_Wrap_Mode,
		// Fields below are more likely to matter in 3D.
	wrap_R:         gl.Texture_Wrap_Mode,
	base_level:     u32,
	max_level:      u32,
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
	//   these are initialized when the draw command is initially created.
	location:    u32,
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
