package main

import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:math/linalg"
import gl "nord_gl"

//////////////////////////////////////////////////////////////////////
// Section: Renderer
//////////////////////////////////////////////////////////////////////

ren_make :: proc () -> ^Ren {
	ren := new(Ren)

	err: gl.Error
	err, ren.frame_UBO = gl.CreateBuffer()
	gl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	gl.BufferData(.UNIFORM_BUFFER, &globals.uniforms, .STATIC_DRAW)
	gl.BindBuffer(.UNIFORM_BUFFER, 0)

	gl.GenBuffers(1, &globals.instance_buffer)
	gl.BindBuffer(.ARRAY_BUFFER, globals.instance_buffer)
	gl.BufferData(.ARRAY_BUFFER, globals.instance_staging[:], .STREAM_DRAW)
	gl.BindBuffer(.ARRAY_BUFFER, 0)

	gl.GenBuffers(1, &globals.glyph_buffer)
	gl.BindBuffer(.ARRAY_BUFFER, globals.glyph_buffer)
	gl.BufferData(.ARRAY_BUFFER, globals.glyph_staging[:], .STREAM_DRAW)
	gl.BindBuffer(.ARRAY_BUFFER, 0)

	ren.programs[Game_Shader.Basic]  = ren_make_shader(ren, basic_vertex_shader_source, basic_fragment_shader_source)
	ren.programs[Game_Shader.Water]  = ren_make_shader(ren, water_vertex_shader_source, water_fragment_shader_source)
	ren.programs[Game_Shader.Text]   = ren_make_shader(ren, text_vertex_shader_source,  text_fragment_shader_source)
	ren.programs[Game_Shader.Image]  = ren_make_shader(ren, image_vertex_shader_source, image_fragment_shader_source)
	ren.programs[Game_Shader.Sprite] = ren_make_shader(ren, sprite_vertex_shader_source, sprite_fragment_shader_source)

	return ren
}

ren_init :: proc (ren: ^Ren) {
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)

	gl.Enable(.BLEND)
	gl.BlendFunc(.SRC_ALPHA, .ONE_MINUS_SRC_ALPHA)

	gl.Enable(.DEPTH_TEST)

	// TODO: When you've got multiple entities,
	//       and more geometry going on, turn this on and fix issues.
	// gl.Enable(.CULL_FACE)
	// gl.CullFace(.BACK)
	gl.FrontFace(.CCW)
}

FRAME_UNIFORM_INDEX :: 0
INSTANCE_UNIFORM_INDEX :: 1

ren_make_shader :: proc (ren: ^Ren, vert, frag: string) -> gl.Program {
	// Compile program
	program, ok := gl.load_shaders_source(vert, frag)
	gl.UseProgram(program)
	defer gl.UseProgram(0)
	log.assertf(ok, "A shader failed to compile/link.\n%s\n%s", vert, frag)

	font_atlas_sampler := gl.GetUniformLocation(program, "font_atlas")
	texture_atlas_sampler := gl.GetUniformLocation(program, "texture_atlas")
	if font_atlas_sampler != -1 {
		gl.glUniform1i(font_atlas_sampler, 0)
		assert(gl.glGetError() == gl.NO_ERROR)
	}
	if texture_atlas_sampler != -1 {
		gl.glUniform1i(texture_atlas_sampler, 1)
		assert(gl.glGetError() == gl.NO_ERROR)
	}
	// Link Uniform Block
	//   TODO: apparently this is global and only needs to happen once
	//   if all programs share the same name + layout.
	uniform_index := gl.GetUniformBlockIndex(program, "Frame_Uniforms")
	assert(uniform_index != gl.INVALID_INDEX)
	gl.UniformBlockBinding(program, uniform_index, FRAME_UNIFORM_INDEX)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, FRAME_UNIFORM_INDEX, ren.frame_UBO)

	return program
}

ren_bind_or_reuse_draw_command :: proc (entity: ^Entity) {
	next := &entity.draw_command
	prev := &globals.ren.prev_cmd
	pipeline_changed: bool = false

	if prev.program != next.program {
		prev.program = next.program
		gl.UseProgram(next.program)
		pipeline_changed = true
	}

	if prev.VAO != next.VAO {
		prev.VAO = next.VAO
		gl.BindVertexArray(next.VAO)
		pipeline_changed = true
	}
	// If there was a change, each program locates instances differently.
	if pipeline_changed {
		// At the time of writing, freeing an entity doesn't wipe the draw command.
		// This works for now, but if there's a bug in the future, suspect this.
		prev = next
	}
}

ren_draw_entity :: proc (ren: ^Ren, entity: ^Entity) {
	ren_bind_or_reuse_draw_command(entity)
	// TODO: copy all instance-level data
	instance_index := cast(int) entity.id
	gl.DrawElements(
		ren_mode_to_primitive(entity.draw_command.mode),
		count  = entity.draw_command.index_count,
		type   = .UNSIGNED_INT,
		indices = cast(uintptr) 0,
	)
}

ren_clear :: proc () {
	gl.Clear({.COLOR_BUFFER_BIT, .DEPTH_BUFFER_BIT})
}

// ASSUME: data is sorted.
// TODO: Render opaque Near to Far and do fragment discard.
ren_draw :: proc (ren: ^Ren) {
	gl.BindBuffer(.ARRAY_BUFFER, globals.instance_buffer)
	gl.BufferSubData(.ARRAY_BUFFER, 0, globals.instance_staging[:])

	globals.uniforms.projection = globals.game_camera
	globals.uniforms.view = globals.game_view
	gl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	gl.BufferSubData(.UNIFORM_BUFFER, 0, &globals.uniforms)

	for entity in globals.entities_3D {
		ren_draw_entity(ren, entity)
	}

	// TODO: Just use a different shader for 2D things. Don't have to copy this.
	globals.uniforms.projection = globals.ui_orthographic
	globals.uniforms.view = globals.ui_view
	gl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	gl.BufferSubData(.UNIFORM_BUFFER, 0, &globals.uniforms)
	for entity in globals.entities_2D {
		ren_draw_entity(ren, entity)
	}
}

//////////////////////////////////////////////////////////////////////
// Section: Draw Commands
//////////////////////////////////////////////////////////////////////

// Creates and initializes:
//   - a vertex buffer.
//   - an index buffer.
// This is lazy and slow, I could use one buffer for loads of models.
//
// But the instance buffer is shared, so that's good.
ren_make_basic_draw_cmd :: proc (
	instance_buffer: gl.Buffer,
	instance_index: int,
	vertices: []Ren_Vertex_Base,
	indices:  []u32,
) -> (cmd: Draw_Command) {
	cmd.program = globals.ren.programs[.Basic]
	gl.GenVertexArrays(1, &cmd.VAO)
	gl.BindVertexArray(cmd.VAO)

	// Create Vertex Buffer
	VBO: gl.Buffer
	gl.GenBuffers(1, &VBO)
	gl.BindBuffer(.ARRAY_BUFFER, VBO)
	gl.BufferData(.ARRAY_BUFFER, vertices, .STREAM_DRAW)
	gl.BindBuffer(.ARRAY_BUFFER, 0)

	// Create Index Buffer
	cmd.index_count = len(indices)
	gl.GenBuffers(1, &cmd.index_buffer)
	gl.BindBuffer(.ELEMENT_ARRAY_BUFFER, cmd.index_buffer)
	gl.BufferData(.ELEMENT_ARRAY_BUFFER, indices)

	entity_offset := uintptr(size_of(Any_Instance) * instance_index) 
	attributes: []Attribute_Binding = {
		{
			buffer = VBO,
			rate   = .Vertex,
			type   = .vec3,
			stride = size_of(Ren_Vertex_Base), 
			offset = offset_of(Ren_Vertex_Base, position)
		},
		{
			buffer = VBO,
			rate = .Vertex,
			type = .vec2,
			stride = size_of(Ren_Vertex_Base),
			offset = offset_of(Ren_Vertex_Base, texcoord)
		},
		{ 
			buffer = VBO,
			rate = .Vertex,
			type = .vec3,
			stride = size_of(Ren_Vertex_Base),
			offset = offset_of(Ren_Vertex_Base, normal)
		},
		{
			buffer = instance_buffer,
			rate = .Instance,
			type = .mat4,
			stride = size_of(Any_Instance),
			offset = entity_offset + offset_of(Any_Instance, model_transform)
		},
		{
			buffer = instance_buffer,
			rate = .Instance,
			type = .vec4,
			stride = size_of(Any_Instance),
			offset = entity_offset + offset_of(Any_Instance, uv_transform)
		},
		{
			buffer = instance_buffer,
			rate = .Instance,
			type = .vec4,
			stride = size_of(Any_Instance),
			offset = entity_offset + offset_of(Any_Instance, color)
		},
	}
	set_VAO_attributes(&cmd.VAO, attributes)
	return
}

ren_make_text_draw_cmd :: proc (
	instance_buffer: gl.Buffer,
	instance_index: int,
	vertices: []Ren_Vertex_Base,
	indices:  []u32,
) -> (cmd: Draw_Command) {
	cmd.program = globals.ren.programs[.Text]
	gl.GenVertexArrays(1, &cmd.VAO)
	gl.BindVertexArray(cmd.VAO)

	// Create Vertex Buffer
	VBO: gl.Buffer
	gl.GenBuffers(1, &VBO)
	gl.BindBuffer(.ARRAY_BUFFER, VBO)
	gl.BufferData(.ARRAY_BUFFER, vertices, .STREAM_DRAW)
	gl.BindBuffer(.ARRAY_BUFFER, 0)

	// Create Index Buffer
	cmd.index_count = len(indices)
	gl.GenBuffers(1, &cmd.index_buffer)
	gl.BindBuffer(.ELEMENT_ARRAY_BUFFER, cmd.index_buffer)
	gl.BufferData(.ELEMENT_ARRAY_BUFFER, indices)

	entity_offset := uintptr(size_of(Any_Instance) * instance_index) 
	attributes: []Attribute_Binding = {
		{
			buffer = VBO,
			rate   = .Vertex,
			type   = .vec3,
			stride = size_of(Ren_Vertex_Base), 
			offset = offset_of(Ren_Vertex_Base, position)
		},
		{
			buffer = VBO,
			rate = .Vertex,
			type = .vec2,
			stride = size_of(Ren_Vertex_Base),
			offset = offset_of(Ren_Vertex_Base, texcoord)
		},
		{
			buffer = VBO,
			rate = .Vertex,
			type = .vec3,
			stride = size_of(Ren_Vertex_Base),
			offset = offset_of(Ren_Vertex_Base, normal)
		},
		{
			buffer = instance_buffer,
			rate = .Instance,
			type = .mat4,
			stride = size_of(Any_Instance),
			offset = entity_offset + offset_of(Any_Instance, model_transform)
		},
		{
			buffer = instance_buffer,
			rate = .Instance,
			type = .vec4,
			stride = size_of(Any_Instance),
			offset = entity_offset + offset_of(Any_Instance, uv_transform)
		},
		{
			buffer = instance_buffer,
			rate = .Instance,
			type = .vec4,
			stride = size_of(Any_Instance),
			offset = entity_offset + offset_of(Any_Instance, color)
		},
	}
	set_VAO_attributes(&cmd.VAO, attributes)
	return
}

ren_make_water_draw_cmd :: proc (
	entity_id: Entity_ID,
	vertices: []Ren_Vertex_Base,
	indices:  []u32,
) -> (cmd: Draw_Command) {
	cmd.program = globals.ren.programs[.Water]
	gl.GenVertexArrays(1, &cmd.VAO)
	gl.BindVertexArray(cmd.VAO)

	// Create Vertex Buffer
	VBO: gl.Buffer
	gl.GenBuffers(1, &VBO)
	gl.BindBuffer(.ARRAY_BUFFER, VBO)
	gl.BufferData(.ARRAY_BUFFER, vertices, .STREAM_DRAW)
	gl.BindBuffer(.ARRAY_BUFFER, 0)

	// Create Index Buffer
	cmd.index_count = len(indices)
	gl.GenBuffers(1, &cmd.index_buffer)
	gl.BindBuffer(.ELEMENT_ARRAY_BUFFER, cmd.index_buffer)
	gl.BufferData(.ELEMENT_ARRAY_BUFFER, indices)
	
	entity_offset := uintptr(size_of(Any_Instance) * entity_id) 
	attributes: []Attribute_Binding = {
		{
			buffer = VBO,
			rate   = .Vertex,
			type   = .vec3,
			stride = size_of(Ren_Vertex_Base), 
			offset = offset_of(Ren_Vertex_Base, position)
		},
		{
			buffer = VBO,
			rate = .Vertex,
			type = .vec2,
			stride = size_of(Ren_Vertex_Base),
			offset = offset_of(Ren_Vertex_Base, texcoord)
		},
		{ 
			buffer = VBO,
			rate = .Vertex,
			type = .vec3,
			stride = size_of(Ren_Vertex_Base),
			offset = offset_of(Ren_Vertex_Base, normal)
		},
		{
			buffer = globals.instance_buffer,
			rate = .Instance,
			type = .mat4,
			stride = size_of(Any_Instance),
			offset = entity_offset + offset_of(Any_Instance, model_transform)
		},
		{
			buffer = globals.instance_buffer,
			rate = .Instance,
			type = .vec4,
			stride = size_of(Any_Instance),
			offset = entity_offset + offset_of(Any_Instance, uv_transform)
		},
		{
			buffer = globals.instance_buffer,
			rate = .Instance,
			type = .vec4,
			stride = size_of(Any_Instance),
			offset = entity_offset + offset_of(Any_Instance, color)
		},
	}
	set_VAO_attributes(&cmd.VAO, attributes)
	return
}

GLES_MAX_BINDINGS :: 16 // per spec
GLES_MAX_FRAGMENT_TEXTURES :: 16 // limit from Intel HD 4000

set_VAO_attributes :: proc (
	VAO:        ^gl.VertexArrayObject,
	attributes: []Attribute_Binding,
) {
	assert(len(attributes) <= GLES_MAX_BINDINGS , "GLSL shaders only have 16 slots.")

	// Enable inputs
	next_location: uint = 0
	for &attr in attributes {
		attr.location = next_location
		next_location += slots_used_by_type(attr.type)
		log.assertf(GLES_MAX_BINDINGS > next_location, "GLSL shaders only have 16 slots.")

		switch attr.type {
		case .f32, .vec2, .vec3, .vec4, .mat4:
			attr.gl_type = .FLOAT
		case .i32, .ivec2, .ivec3, .ivec4:
			attr.gl_type = .INT
		case .u32, .uvec2, .uvec3, .uvec4:
			attr.gl_type = .UNSIGNED_INT
		}

		switch attr.type {
		case .f32, .i32, .u32:
			attr.value_count = 1
		case .vec2, .ivec2, .uvec2:
			attr.value_count = 2
		case .vec3, .ivec3, .uvec3:
			attr.value_count = 3
		case .vec4, .ivec4, .uvec4:
			attr.value_count = 4
		case .mat4:
			attr.value_count = 16
		}
	}

	// Create ideal VAO for this obj.
	gl.BindVertexArray(VAO^)

	for attr in attributes {
		divisor: uint = 0 if attr.rate == .Vertex else 1
		slots := slots_used_by_type(attr.type)
		gl.BindBuffer(.ARRAY_BUFFER, attr.buffer)
		for slot_num in 0..<slots {
			index := attr.location + slot_num
			num_components := attr.value_count / cast(int) slots
			// WARNING: Breaks when you start needing ivecs... probably.
			// This size_of in here is a little forceful.
			// But usually if you've got a multi-slot it's an f32 matrix.
			offset := attr.offset + cast(uintptr) (cast(uint) num_components * slot_num * size_of(f32))
			if glsl_attrib_is_int(attr.type) {
				gl.VertexAttribIPointer(
					index      = index,
					size       = num_components,
					type       = attr.gl_type,
					stride     = attr.stride,
					offset     = offset
				)
			} else {
				gl.VertexAttribPointer(
					index      = index,
					size       = num_components,
					type       = attr.gl_type,
					normalized = false,
					stride     = attr.stride,
					offset     = offset
				)
			}
			gl.EnableVertexAttribArray(index)
			gl.VertexAttribDivisor(index, divisor)
		}
	}
	gl.BindBuffer(.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)
}

glsl_attrib_is_int :: proc (type: GLSL_Attribute_Type) -> bool {
	return type >= .i32
}

slots_used_by_type :: proc (type: GLSL_Attribute_Type) -> uint {
	if type == .mat4 {
		return 4
	}
	return 1
}

//////////////////////////////////////////////////////////////////////
// Section: Basic GL ESSL Parse
//////////////////////////////////////////////////////////////////////
// WHY IS THIS COMMENTED?
// Because I don't have to parse it if I use the same variable names across shaders.
// 
// uniform SAMPLER_TYPE identifier;
// samplers :: []string {
// 	// float kinds
// 	"sampler2D",
// 	"sampler3D",
// 	"samplerCube",
// 	"samplerCubeShadow",
// 	"sampler2DShadow",
// 	"sampler2DArray",
// 	"sampler2DArrayShadow",
// 	// int kinds
// 	"isampler2D",
// 	"isampler3D",
// 	"isamplerCube",
// 	"isampler2DArray",
// 	// uint kinds
// 	"usampler2D",
// 	"usampler3D",
// 	"usamplerCube",
// 	"usampler2DArray",
// }

// // returns a map of uniform names paired with their integer values.
// extract_samplers_from_program :: proc (vs, fs: string) -> []string {
// 	start_of_line: bool
// 	for c in vs {
// 		switch c {
// 		case 's': 
// 		case 'i': 
// 		case 'u': 
// 		case ';':
// 		}
// 	}
// }

//////////////////////////////////////////////////////////////////////
// Section: Textures
//////////////////////////////////////////////////////////////////////

bind_texture_to_unit :: proc (texture_unit: uint, texture: GPU_Texture) {
	gl.glActiveTexture(gl.TEXTURE0 + texture_unit)
	gl.BindTexture(texture.target, texture.texture)
}

init_and_upload_texture :: proc (texture_unit: uint, texture: ^GPU_Texture, pixels: []$T, size_px: [2]int) -> bool {
	assert(texture.texture == 0)
	assert(pixels != nil)
	err, new_texture_name := gl.CreateTexture()
	if err != nil { return false }
	texture.texture = new_texture_name
	texture.size_px = size_px

	bind_texture_to_unit(texture_unit, texture^)

	info: gl.Color_Format_Info = gl.Internal_Format_Infos[texture.format]
	err = gl.TexImage2D(
		auto_cast texture.target, // TODO auto_cast
		texture.level,
		cast(int) texture.format,
		size_px.x,
		size_px.y,
		cast(uint) info.format,
		cast(uint) info.type,
		pixels)
	if err != nil { return false }

	set_texture_state(texture^)
	return true
}

// TODO casts in this function
upload_pixels_to_texture :: proc (texture: ^GPU_Texture, pixels: []u8, size_px: [2]int) {
	info: gl.Color_Format_Info = gl.Internal_Format_Infos[texture.format]
	gl.TexSubImage2D(
		auto_cast texture.target, // TODO
		texture.level,
		0,0, // offset into image
		size_px.x,
		size_px.y,
		cast(uint) info.format,
		cast(uint) info.type,
		pixels
	)
}

// TODO: Can't set to defaults using nil, could enable a path for that?
set_texture_state :: proc (texture: GPU_Texture) {
	// TODO: No variant of a texture for a cubemap. Implement one to find an API.
	parameter_target := gl.parameter_for_target(texture.target)
	if texture.magnify_filter != nil {
		gl.Set_Texture_Mag_Filter(parameter_target, texture.magnify_filter)
	}
	if texture.minify_filter != nil {
		gl.Set_Texture_Min_Filter(parameter_target, texture.minify_filter)
	}
	if texture.wrap_ST[0] != nil {
		gl.Set_Texture_Wrap_S(parameter_target, texture.wrap_ST[0])
	}
	if texture.wrap_ST[1] != nil {
		gl.Set_Texture_Wrap_T(parameter_target, texture.wrap_ST[1])
	}
	if texture.wrap_R != nil {
		gl.Set_Texture_Wrap_R(parameter_target, texture.wrap_R)
	}
	if texture.base_level != 0 {
		gl.Set_Texture_Base_Level(parameter_target, texture.base_level)
	}
	if texture.max_level != 0 {
		gl.Set_Texture_Max_Level(parameter_target, texture.max_level)
	}
	if texture.min_LOD != 0 {
		gl.Set_Texture_Min_LOD(parameter_target, texture.min_LOD)
	}
	if texture.max_LOD != 0 {
		gl.Set_Texture_Max_LOD(parameter_target, texture.max_LOD)
	}
	if texture.compare_func != nil {
		gl.Set_Texture_Compare_Func(parameter_target, texture.compare_func)
	}
	if texture.compare_mode != nil {
		gl.Set_Texture_Compare_Mode(parameter_target, texture.compare_mode)
	}
}

//////////////////////////////////////////////////////////////////////
// Section: Shaders
//////////////////////////////////////////////////////////////////////

version :: "#version 300 es\n"

precision_defaults :: `
	precision highp float;
	precision highp int;
`

frame_uniforms :: `
	layout(std140) uniform Frame_Uniforms {
		mat4 view;       // where the camera is
		mat4 projection; // camera lens
		float time;
		float tau_time;
		vec2  padding0; // extend to vec4
	} frame;
`

vertex_preamble :: 
	version +
	"#pragma STDGL invariance(all)\n" +
	precision_defaults +
	frame_uniforms

fragment_preamble ::
	version +
	precision_defaults +
	frame_uniforms

// Basic ///////////////////////////////////////////////////////////////////////
basic_vertex_inputs :: `
	layout (location = 0) in vec3 v_position;
	layout (location = 1) in vec2 v_texcoord;
	layout (location = 2) in vec3 v_normal;
	layout (location = 3) in mat4 i_model_mat;
	layout (location = 7) in vec4 i_uv_xform;
	layout (location = 8) in vec4 i_color;
`

basic_vertex_shader_source :: vertex_preamble +
basic_vertex_inputs +
`
	out vec4 io_color;

	void main() {
		io_color = i_color;
		mat4 mvp = frame.projection * frame.view * i_model_mat;
		gl_Position = mvp * vec4(v_position, 1);
	}
`

basic_fragment_shader_source :: fragment_preamble + `

	in vec4 io_color;
	out vec4 outColor;
	void main() {
		outColor = io_color;
	}
`

// Basic: Water ////////////////////////////////////////////////////////////////
water_vertex_shader_source :: vertex_preamble + basic_vertex_inputs +
`
	out vec4 color;
	out vec3 raw_surface_normal;
	out vec3 world_position;

	uniform sampler2D heightmap;

	void main() {
		vec2 heightmap_size   = vec2(textureSize(heightmap, 0));
		vec2 heightmap_here   = v_position.xz / heightmap_size;
		// vec2 heightmap_next_x = v_position.xz + vec2(1,0) / heightmap_size;
		// vec2 heightmap_next_z = v_position.xz + vec2(0,1) / heightmap_size;
		float height_here = texture(heightmap, heightmap_here).r;
		// float height_next_x = texture(heightmap, heightmap_next_x).r;
		// float height_next_z = texture(heightmap, heightmap_next_z).r;
		color = i_color;
		raw_surface_normal = v_normal;

		vec4 position4 = vec4(v_position, 1);
		position4.y = height_here;
		world_position = (i_model_mat * position4).xyz;

		mat4 mvp = frame.projection * frame.view * i_model_mat;
		gl_Position = mvp * position4;
	}
`

water_fragment_shader_source :: fragment_preamble + `
	in vec4 color;
	in vec3 raw_surface_normal;
	in vec3 world_position;

	out vec4 outColor;
	void main() {
		float ambient_luminance = 0.1;
		vec3 ambient_light = ambient_luminance * color.xyz;

		vec3 surface_normal = normalize(raw_surface_normal);

		surface_normal = -normalize(cross( dFdx(world_position), dFdy(world_position) ));
		vec3 surface_to_light = normalize(vec3(1, 10, 1) - world_position);
		float diffuse_luminance = max(dot(surface_normal, surface_to_light), 0.0);
		vec3 diffuse_light = diffuse_luminance * vec3(1,1,1);

		vec3 light = (ambient_light + diffuse_light) * color.xyz;
		outColor = vec4(light, 1.0);
	}
`
// Text ////////////////////////////////////////////////////////////////////////
text_vertex_shader_source :: vertex_preamble +
`
	layout (location = 0) in vec3 v_position;
	layout (location = 1) in vec2 v_texcoord;
	layout (location = 2) in vec3 v_normal;
	layout (location = 3) in mat4 i_model_mat;
	layout (location = 7) in vec4 i_uv_xform;
	layout (location = 8) in vec4 i_color;

	out vec4 io_color;
	out vec2 uv;

	void main() {
		uv = v_texcoord;
		io_color = i_color;
		mat4 mvp = frame.projection * frame.view * i_model_mat;
		gl_Position = mvp * vec4(v_position, 1);
	}
`

text_fragment_shader_source :: fragment_preamble + `
	uniform sampler2D font_atlas;

	in vec4 io_color;
	in vec2 uv;

	out vec4 outColor;

	void main() {
		vec4 tex_color = texture(font_atlas, uv);
		tex_color = mix(tex_color, io_color, tex_color.r);
		tex_color = mix(tex_color, vec4(0,0,0,0), 1.-tex_color.r);
		outColor = tex_color;
	}
`
//////////////////////////////////////////////////////////////////////
// Section: Geometry
//////////////////////////////////////////////////////////////////////
import "core:math/linalg/glsl"

make_circle_cap_2D :: proc (
  mesh: ^[dynamic]Ren_Vertex_Base,
  sides: int,
  radius: f32,
) {
  assert(mesh != nil)
  // Begin by appending zero. (center point)
  append(mesh, Ren_Vertex_Base { position = Vec4{0,0,0,1}.xyz })

  // Find the step through the circle to make N sides. 0...(360-theta_step)
  theta_step := glsl.radians_f32(360.0) / f32(sides)
  for i in 0 ..< sides {
    theta := f32(i) * theta_step
    // I find it easier to look down at this shape from above,
    // So for my imagination, the sine component is mapped to the Z dimension.
    vertex: Ren_Vertex_Base
    vertex.position = {
      glsl.cos(theta) * radius,
      glsl.sin(theta) * radius,
      0,
    }
    append(mesh, vertex)
  }
}

make_circle_2D :: proc (radius: f32, sides: int = 32) -> ([]Ren_Vertex_Base, []u32) {
  verts := make([dynamic]Ren_Vertex_Base)
  make_circle_cap_2D(&verts, sides, radius)
  VERTS_PER_CAP: u32 = cast(u32) sides + 1 // counting center-point

  // Now that the geometry has been baked in position according to the transforms,
  // We can build an index buffer to from triagles from the points.
  indices: [dynamic]u32 = make([dynamic]u32)
  EDGE_SEGMENTS: u32 = cast(u32) sides
  geom_make_cap_indices(&indices, 0, EDGE_SEGMENTS)
  //geom_make_faces_between_rings(&indices, 0, VERTS_PER_CAP, EDGE_SEGMENTS)

  return verts[:], indices[:]
}

make_triangle_2D :: proc () -> ([]Ren_Vertex_Base, []u32) {
  verts := make([dynamic]Ren_Vertex_Base)
  append(&verts, Ren_Vertex_Base{position = Vec3{-1,1,0}})
  append(&verts, Ren_Vertex_Base{position = Vec3{1,1,0}})
  append(&verts, Ren_Vertex_Base{position = Vec3{0,-1,0}})
  indices: [dynamic]u32 = make([dynamic]u32)
  append(&indices, 0)
  append(&indices, 1)
  append(&indices, 2)
  return verts[:], indices[:]
}
