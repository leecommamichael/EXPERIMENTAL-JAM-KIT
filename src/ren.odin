package main

import "core:log"
import "core:mem"
import "core:math/linalg"
import ngl "nord_gl"
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

ren_make :: proc () -> ^Ren {
	ren := new(Ren)

	ngl.GenBuffers(&ren.frame_UBO)
	ngl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	ngl.BufferData(.UNIFORM_BUFFER, &globals.uniforms, .STATIC_DRAW)

	ngl.GenBuffers(&ren.instance_UBO)
	ngl.BindBuffer(.UNIFORM_BUFFER, ren.instance_UBO)
	ngl.BufferData(.UNIFORM_BUFFER, globals.instances.data[:])

	ren.programs[.Basic] = ren_make_shader(ren, basic_vertex_shader_source, basic_fragment_shader_source)

	return ren
}

ren_init :: proc (ren: ^Ren) {
	ngl.ClearColor(0.2, 0.3, 0.3, 1.0)

	ngl.Enable(.BLEND)
	ngl.BlendFunc(.SRC_ALPHA, .ONE_MINUS_SRC_ALPHA)

	ngl.Enable(.DEPTH_TEST)
	// ngl.ClearDepthf(1)
	// ngl.DepthRange(f64(1), f64(-1))
	// ngl.DepthFunc(ngl.GEQUAL)

	// ngl.Enable(.CULL_FACE)
	// ngl.CullFace(.BACK)
	ngl.FrontFace(.CW)
	// ngl.PolygonMode(ngl.FRONT_AND_BACK, ngl.LINE);
}

// Ren: Drawing //////////////////////////////////////////////////////////////////////////
FRAME_UNIFORM_INDEX :: 0
INSTANCE_UNIFORM_INDEX :: 1

ren_make_shader :: proc (ren: ^Ren, vert, frag: string) -> ngl.Program {
	// Compile program
	program, ok := ngl.load_shaders_source(vert, frag)
	log.assertf(ok, "A shader failed to compile/link.\n%s\n%s", vert, frag)
	// Link Uniform Block
	//   TODO: apparently this is global and only needs to happen once
	//   if all programs share the same name + layout.
	uniform_index := ngl.GetUniformBlockIndex(program, "Frame_Uniforms")
	assert(uniform_index != ngl.INVALID_INDEX)
	ngl.UniformBlockBinding(program, uniform_index, FRAME_UNIFORM_INDEX)
	ngl.BindBufferBase(ngl.UNIFORM_BUFFER, FRAME_UNIFORM_INDEX, ren.frame_UBO)

	uniform_index = ngl.GetUniformBlockIndex(program, "Instance_Uniforms")
	ngl.UniformBlockBinding(program, uniform_index, INSTANCE_UNIFORM_INDEX)
	ngl.BindBufferBase(ngl.UNIFORM_BUFFER, INSTANCE_UNIFORM_INDEX, ren.instance_UBO)

	return program
}

ren_draw_entity :: proc (ren: ^Ren, entity: ^Entity) {
	instance_index := cast(int) entity._id
	ngl.BindBufferRange(
		ngl.UNIFORM_BUFFER,
		index  = INSTANCE_UNIFORM_INDEX,
		buffer = ren.instance_UBO,
		offset = instance_index * globals.instances.stride,
		size = size_of(Ren_Instance)
	)
	asset := entity._asset
	if ren.program != asset.program {
		ren.program = asset.program
		ngl.UseProgram(ren.program)
	}
	if ren.VAO != asset.VAO {
		ren.VAO = asset.VAO
		ngl.BindVertexArray(ren.VAO)
	}
	ngl.DrawElements(
		ren_mode_to_primitive(asset.mode),
		count  = asset.index_count,
		type   = .UNSIGNED_INT,
		indices = cast(uintptr) 0,
	)
}
// ASSUME: data is sorted.
// TODO: Render opaque Near to Far and figure out fragment discard.
ren_draw :: proc (ren: ^Ren) {
	ngl.Clear({.COLOR_BUFFER_BIT, .DEPTH_BUFFER_BIT})
	globals.uniforms.projection = globals.game_camera
	globals.uniforms.view = globals.game_view
	ngl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	ngl.BufferSubData(.UNIFORM_BUFFER, 0, &globals.uniforms)
	ngl.BindBuffer(.UNIFORM_BUFFER, ren.instance_UBO)
	ngl.BufferSubData(.UNIFORM_BUFFER, 0, globals.instances.data[:])

	for entity in globals.game_entities {
		ren_draw_entity(ren, entity)
	}

	globals.uniforms.projection = globals.ui_orthographic
	globals.uniforms.view = globals.ui_view
	ngl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	ngl.BufferSubData(.UNIFORM_BUFFER, 0, &globals.uniforms)
	for entity in globals.ui_entities {
		ren_draw_entity(ren, entity)
	}
}

//////////////////////////////////////////////////////////////////////
// Section: Shading & Asset
//////////////////////////////////////////////////////////////////////

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
	// vertices:    []Ren_Vertex_Base,
	VBO:         ngl.Buffer,
}

ren_make_asset :: proc (
	ren: ^Ren,
	program: ngl.Program,
	VAO:     ngl.VertexArrayObject,
	inputs: []Shader_Input,
	index_count: int,
) -> Ren_Asset {
	assert(GLES_MAX_BINDINGS > len(inputs), "GLSL shaders only have 16 slots.")

	// Allocate room for inputs
	obj: Ren_Asset
	obj.program = program
	obj.index_count = index_count
	obj.VAO = VAO

	// Enable inputs
	next_location: uint = 0
	for &input in inputs {
		input.location = next_location
		next_location += slots_used_by_type(input.type)
		log.assertf(GLES_MAX_BINDINGS > next_location, "GLSL shaders only have 16 slots.")

		switch input.type {
		case .f32, .vec2, .vec3, .vec4, .mat4:
			input.ngl_type = .FLOAT
		case .i32, .ivec2, .ivec3, .ivec4:
			input.ngl_type = .INT
		case .u32, .uvec2, .uvec3, .uvec4:
			input.ngl_type = .UNSIGNED_INT
		}

		switch input.type {
		case .f32, .i32, .u32:
			input.value_count = 1
		case .vec2, .ivec2, .uvec2:
			input.value_count = 2
		case .vec3, .ivec3, .uvec3:
			input.value_count = 3
		case .vec4, .ivec4, .uvec4:
			input.value_count = 4
		case .mat4:
			input.value_count = 16
		}
	}

	// Create ideal VAO for this obj.
	ngl.BindVertexArray(obj.VAO)

	for input in inputs {
		divisor: uint = 0 if input.rate == .Vertex else 1
		slots := slots_used_by_type(input.type)
		ngl.BindBuffer(.ARRAY_BUFFER, input.buffer.id)
		for slot_num in 0..<slots {
			index := input.location + slot_num
			num_components := input.value_count / cast(int) slots
			// WARNING:
			// This size_of in here is a little forceful.
			// But usually if you've got a multi-slot it's an f32 matrix.
			offset := input.field_offset + cast(uintptr) (cast(uint) num_components * slot_num * size_of(f32))
			if glsl_attrib_is_int(input.type) {
				ngl.VertexAttribIPointer(
					index      = index,
					size       = num_components,
					type       = input.ngl_type,
					stride     = input.buffer.element_size,
					offset     =  offset
				)
			} else {
				ngl.VertexAttribPointer(
					index      = index,
					size       = num_components,
					type       = input.ngl_type,
					normalized = false,
					stride     = input.buffer.element_size,
					offset     = offset
				)
			}
			ngl.EnableVertexAttribArray(index)
			ngl.VertexAttribDivisor(index, divisor)
		}
	}
	ngl.BindBuffer(.ARRAY_BUFFER, 0)
	ngl.BindVertexArray(0)

	return obj
}

GLSL_Attribute_Type :: enum {
	f32, vec2, vec3, vec4,
	mat4,
	i32, ivec2, ivec3, ivec4,
	u32, uvec2, uvec3, uvec4,
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
Shader_Input_Rate :: enum {
	Vertex,
	Instance,
}

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

GLES_MAX_BINDINGS :: 16 // per spec

version :: "#version 300 es\n"

precision_defaults :: `
	precision highp float;
	precision highp int;
`

frame_uniforms :: `
	layout(std140) uniform Frame_Uniforms {
		mat4 view;       // where the camera is
		mat4 projection; // camera lens
	} frame;
`

instance_uniforms :: `
	layout(std140) uniform Instance_Uniforms {
		mat4 model_mat;
		vec4 uv_xform;
		vec4 color;
	} instance;
`

vertex_preamble :: 
	version +
	"#pragma STDGL invariance(all)\n" +
	precision_defaults +
	frame_uniforms +
	instance_uniforms

fragment_preamble ::
	version +
	precision_defaults +
	frame_uniforms +
	instance_uniforms

basic_vertex_inputs :: `
	layout (location = 0) in vec3 v_position;
	layout (location = 1) in vec2 v_texcoord;
`

basic_vertex_shader_source :: vertex_preamble +
basic_vertex_inputs +
`
	out vec4 io_color;

	const vec4 nan_color = vec4(1,0,0,1);
	const vec4 inf_color = vec4(0,0,1,1);
	const vec4 zero_color = vec4(1,0,1,1); // todo compute random over time.

	vec4 float_to_color(float f) {
		if (isnan(f)) {
			return nan_color;
		} else if (isinf(f)) {
			return inf_color;
		} else {
			return vec4(f);
		}
	}

	vec4 mat4_to_color(mat4 m) {
		bool has_nan = isnan(m[0][0]) || isnan(m[1][1]) || isnan(m[2][2]);
		if (has_nan) {
			return nan_color;
		}
		bool has_inf = isinf(m[0][0]) || isinf(m[1][1]) || isinf(m[2][2]);
		if (has_inf) {
			return inf_color;
		}
		vec4 xx = float_to_color(m[0][0]);
		vec4 yy = float_to_color(m[1][1]);
		vec4 zz = float_to_color(m[2][2]);
		float channel_sum = xx[0] + yy[0] + zz[0];
		if (channel_sum == 0.0) {
			return zero_color;
		}
		return vec4(xx.x/channel_sum,yy.y/channel_sum,zz.z/channel_sum, 1.0);
	}

// Desktop: frame.projection is cyan, but is zero-color on Web
// Desktop: frame.view         is OK
// Desktop: instance model_mat is OK

	void main() {
		io_color = instance.color;
		// io_color = mat4_to_color(frame.projection);
		// gl_Position = vec4(v_position, 1);
		mat4 mvp = frame.projection * frame.view * instance.model_mat;
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

// Creates and initializes:
//   - a vertex buffer.
//   - an index buffer.
// This is lazy and slow, I could use one buffer for loads of models.
//
// But the instance buffer is shared, so that's good.
ren_make_basic_asset :: proc (
	ren: ^Ren,
	vertices: []Ren_Vertex_Base,
	indices:  []u32,
	instance_buffer: ngl.Buffer,
) -> Ren_Asset {
	VAO: ngl.VertexArrayObject
	ngl.GenVertexArrays(&VAO)
	ngl.BindVertexArray(VAO)

	// Create Vertex Buffer
	vertex_buffer := Ren_Buffer {
		element_size = size_of(Ren_Vertex_Base)
	}
	ngl.GenBuffers(&vertex_buffer.id)
	ngl.BindBuffer(.ARRAY_BUFFER, vertex_buffer.id)
	ngl.BufferData(.ARRAY_BUFFER, vertices, .STREAM_DRAW)
	ngl.BindBuffer(.ARRAY_BUFFER, 0)

	// Create Index Buffer
	index_count := len(indices)
	index_buffer_id: ngl.Buffer
	ngl.GenBuffers(&index_buffer_id)
	ngl.BindBuffer(.ELEMENT_ARRAY_BUFFER, index_buffer_id)
	ngl.BufferData(.ELEMENT_ARRAY_BUFFER, indices)

	instance_buffer_view := Ren_Buffer {
		id = instance_buffer,
		element_size = size_of(Ren_Instance)
	}
	offsets: []uintptr = {
		offset_of(Ren_Vertex_Base, position),
		offset_of(Ren_Vertex_Base, texcoord),
	}
	inputs: []Shader_Input = {
		{ type = .vec3, rate=.Vertex,   field_offset = offsets[0], buffer = vertex_buffer },
		{ type = .vec2, rate=.Vertex,   field_offset = offsets[1], buffer = vertex_buffer },
	}

	asset := ren_make_asset(ren, ren.programs[.Basic], VAO, inputs, index_count)
	asset.VBO = vertex_buffer.id
	return asset
}

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
  // We can build an index buffer to from triangles from the points.
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