package main

import "base:intrinsics"
import "core:log"
import "core:mem"
import "core:math/linalg"
import ngl "nord_gl"

////////////////////////////////////////////////////////////////////////////////
// Entity 
////////////////////////////////////////////////////////////////////////////////

init_entity_memory :: proc (entity: ^Entity_Memory, id: Entity_ID) {
	entity^ = {} // zero
	entity._id = id
	entity._used = true
	entity.scale = 1
	entity.instance = subscript_aligned_array(&globals.instances, cast(int) entity._id)
	entity.instance^ = {} // zero
	entity.instance.color.a = 1
	entity.instance.uv_transform = {0,0,1,1}
}

make_entity :: proc {
	make_entity_basic,
	make_entity_variant
}

make_entity_basic :: proc () -> ^Entity {
	return make_entity_variant(Entity)
}

make_entity_variant :: proc ($T: typeid) -> ^T
where intrinsics.type_is_subtype_of(T, Entity) {
	for &mem, i in globals._entity_storage {
		if !mem._used {
			init_entity_memory(&mem, cast(Entity_ID) i)
			if T == Text {
				mem.variant = {}
				mem.tag = Entity_Variant.Text
			} else if T == Entity {
				mem.tag = Entity_Variant.None
			} else {
				panic("Unimplemented Entity Variant")
			}
			return transmute(^T) &mem
		}
	}
	panic("Out of entities.")
}

free_entity :: proc (entity: ^$T)
where intrinsics.type_is_subtype_of(T, Entity) {
	entity._used = false
}


//////////////////////////////////////////////////////////////////////
// Section: Renderer
//////////////////////////////////////////////////////////////////////

ren_make :: proc () -> ^Ren {
	ren := new(Ren)

	err: ngl.Error
	err, ren.frame_UBO = ngl.CreateBuffer()
	ngl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	ngl.BufferData(.UNIFORM_BUFFER, &globals.uniforms, .STATIC_DRAW)

	err = ngl.GenBuffers(1, &ren.instance_UBO)
	ngl.BindBuffer(.UNIFORM_BUFFER, ren.instance_UBO)
	ngl.BufferData(.UNIFORM_BUFFER, globals.instances.data[:])

	ren.programs[.Basic] = ren_make_shader(ren, basic_vertex_shader_source, basic_fragment_shader_source)
	ren.programs[.Water] = ren_make_shader(ren, water_vertex_shader_source, water_fragment_shader_source)

	return ren
}

ren_init :: proc (ren: ^Ren) {
	ngl.ClearColor(0.2, 0.3, 0.3, 1.0)

	ngl.Enable(.BLEND)
	ngl.BlendFunc(.SRC_ALPHA, .ONE_MINUS_SRC_ALPHA)

	ngl.Enable(.DEPTH_TEST)

	// ngl.Enable(.CULL_FACE)
	// ngl.CullFace(.BACK)
	ngl.FrontFace(.CCW)
}

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

ren_clear :: proc () {
	ngl.Clear({.COLOR_BUFFER_BIT, .DEPTH_BUFFER_BIT})
}

// ASSUME: data is sorted.
// TODO: Render opaque Near to Far and do fragment discard.
ren_draw :: proc (ren: ^Ren) {
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
GLES_MAX_BINDINGS :: 16 // per spec
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

glsl_attrib_is_int :: proc (type: GLSL_Attribute_Type) -> bool {
	return type >= .i32
}

slots_used_by_type :: proc (type: GLSL_Attribute_Type) -> uint {
	if type == .mat4 {
		return 4
	}
	return 1
}


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

////////////////////////////////////////////////////////////////////////////////
// Shaders /////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Basic ///////////////////////////////////////////////////////////////////////
basic_vertex_inputs :: `
	layout (location = 0) in vec3 v_position;
	layout (location = 1) in vec2 v_texcoord;
	layout (location = 2) in vec3 v_normal;
`

basic_vertex_shader_source :: vertex_preamble +
basic_vertex_inputs +
`
	out vec4 io_color;

	void main() {
		io_color = instance.color;
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
		color = instance.color;
		raw_surface_normal = v_normal;

		vec4 position4 = vec4(v_position, 1);
		position4.y = height_here;
		world_position = (instance.model_mat * position4).xyz;

		mat4 mvp = frame.projection * frame.view * instance.model_mat;
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
	ngl.GenVertexArrays(1, &VAO)
	ngl.BindVertexArray(VAO)

	// Create Vertex Buffer
	vertex_buffer := Ren_Buffer {
		element_size = size_of(Ren_Vertex_Base)
	}
	ngl.GenBuffers(1, &vertex_buffer.id)
	ngl.BindBuffer(.ARRAY_BUFFER, vertex_buffer.id)
	ngl.BufferData(.ARRAY_BUFFER, vertices, .STREAM_DRAW)
	ngl.BindBuffer(.ARRAY_BUFFER, 0)

	// Create Index Buffer
	index_count := len(indices)
	index_buffer_id: ngl.Buffer
	ngl.GenBuffers(1, &index_buffer_id)
	ngl.BindBuffer(.ELEMENT_ARRAY_BUFFER, index_buffer_id)
	ngl.BufferData(.ELEMENT_ARRAY_BUFFER, indices)

	instance_buffer_view := Ren_Buffer {
		id = instance_buffer,
		element_size = size_of(Ren_Instance)
	}
	offsets: []uintptr = {
		offset_of(Ren_Vertex_Base, position),
		offset_of(Ren_Vertex_Base, texcoord),
		offset_of(Ren_Vertex_Base, normal),
	}
	inputs: []Shader_Input = {
		{ type = .vec3, rate=.Vertex,   field_offset = offsets[0], buffer = vertex_buffer },
		{ type = .vec2, rate=.Vertex,   field_offset = offsets[1], buffer = vertex_buffer },
		{ type = .vec3, rate=.Vertex,   field_offset = offsets[2], buffer = vertex_buffer },
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

//////////////////////////////////////////////////////////////////////
// Section: UI Nodes
//////////////////////////////////////////////////////////////////////

