package main

import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:math/linalg"
import "base:runtime"
import gl "angle"

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

	ren.programs[Game_Shader.Basic]  = ren_make_basic_shader(ren, basic_vertex_shader_source, basic_fragment_shader_source)
	ren.programs[Game_Shader.Water]  = ren_make_basic_shader(ren, water_vertex_shader_source, water_fragment_shader_source)
	ren.programs[Game_Shader.Text]   = ren_make_basic_shader(ren, text_vertex_shader_source,  text_fragment_shader_source)
	ren.programs[Game_Shader.Image]  = ren_make_basic_shader(ren, image_vertex_shader_source, image_fragment_shader_source)
	ren.programs[Game_Shader.Sprite] = ren_make_basic_shader(ren, sprite_vertex_shader_source, sprite_fragment_shader_source)
	ren.programs[Game_Shader.Framebuffer_Texture] = ren_make_basic_shader(ren, framebuffer_quad_vertex_shader_source, framebuffer_quad_fragment_shader_source)

	ren.linear_sampler = gl.CreateSampler()
	gl.Set_Sampler_Min_Filter(ren.linear_sampler, .LINEAR)
	gl.Set_Sampler_Mag_Filter(ren.linear_sampler, .LINEAR)
	ren.nearest_sampler = gl.CreateSampler()
	gl.Set_Sampler_Min_Filter(ren.nearest_sampler, .NEAREST)
	gl.Set_Sampler_Mag_Filter(ren.nearest_sampler, .NEAREST)

	return ren
}

ren_init :: proc (ren: ^Ren) {
	set_canvas_size([2]int{2,2}) // arbitrary non-zero number creates the canvas.
	gl.FrontFace(.CCW)
	gl.ClearColor(0.0, 0.0, 0.0, 0.0)
	gl.glClearDepth(1.0)
	// gl.glClearStencil(0.0)
	gl.glDepthMask(true)
	gl.Enable(.DEPTH_TEST)
	gl.glDepthFunc(gl.LESS)
	gl.Enable(.BLEND)
	gl.BlendFunc(.ONE, .ONE_MINUS_SRC_ALPHA)
	globals.unit_circle_mesh = make_circle_2D(0.5, 64, context.allocator)
	globals.unit_quad_mesh = geom_make_quad(1.0, context.allocator)
	globals.unit_rect_mesh = geom_make_rect(1.0, context.allocator)
	circle_draw_cmd := ren_make_basic_draw_cmd(
		globals.instance_buffer, 0,
		globals.unit_circle_mesh.vertices[:],
		globals.unit_circle_mesh.indices[:])
	quad_draw_cmd := ren_make_basic_draw_cmd(
		globals.instance_buffer, 0,
		globals.unit_quad_mesh.vertices[:],
		globals.unit_quad_mesh.indices[:])
	globals.collider_draw_commands = {
		.None = {},
		.Point = circle_draw_cmd,
		.AABB = quad_draw_cmd,
		.Circle = circle_draw_cmd,
	}
}

FRAME_UNIFORM_INDEX :: 0
INSTANCE_UNIFORM_INDEX :: 1

Texture_Unit :: enum {
	Swap = 0,
	Font = 1,
	Texture = 2,
	Framebuffer_Texture = 3,
}

// How might a bad-shader cycle happen?
// If I never let a compilation failure run, then I guess it's fine.
hot_reloaded_shader :: proc (entity: ^Entity, vert: string, frag: string) {
	when !ODIN_DEBUG do return
	if !globals.hot_reloaded_this_frame { return }
	if .Shader_Reload_Failed in entity.flags { return }

	new_program, ok := ren_maybe_make_basic_shader(globals.ren, vert, frag)
	if !ok {
		log.infof(
			"[RELOADER] failed to reload a shader for entity %d: %s",
			entity.id,
			entity.debug_name
		)
		// If we failed to compile, don't change the shader from one that works.
		entity.flags += {.Shader_Reload_Failed}
		return 
	} else {
		entity.flags -= {.Shader_Reload_Failed}
	}
	old_program := entity.draw_command.program
	if !contains(slice.enumerated_array(&globals.ren.programs), old_program) {
		// INTENT: Don't delete shaders the rest of the game might want.
		gl.DeleteProgram(old_program)
	}
	entity.draw_command.program = new_program
	log.infof(
		"[RELOADER] reloaded a shader for entity %d: %s",
		entity.id,
		entity.debug_name
	)
}

ren_maybe_make_basic_shader :: proc (
	ren: ^Ren,
	vert: string,
	frag: string,
	caller := #caller_location,
) -> (program: gl.Program, ok: bool) {
	// Compile program
	program, ok = gl.load_shaders_source(vert, frag)
	if !ok {
		log.errorf("A shader failed to compile/link.\n%s\n%s", vert, frag)
		return 0, false
	}
	gl.UseProgram(program)
	defer gl.validate(caller)
	defer gl.UseProgram(0)

	font_atlas_sampler := gl.GetUniformLocation(program, "font_atlas")
	if font_atlas_sampler >= 0 {
		gl.glUniform1i(font_atlas_sampler, cast(int) Texture_Unit.Font)
	}

	texture_atlas_sampler := gl.GetUniformLocation(program, "texture_atlas")
	if texture_atlas_sampler >= 0 {
		gl.glUniform1i(texture_atlas_sampler, cast(int) Texture_Unit.Texture)
	}

	fb_sampler := gl.GetUniformLocation(program, "framebuffer_color")
	if fb_sampler >= 0 {
		gl.glUniform1i(fb_sampler, cast(int) Texture_Unit.Framebuffer_Texture)
	}
	// Link Uniform Block
	//   TODO: apparently this is global and only needs to happen once
	//   if all programs share the same name + layout.
	uniform_index := gl.GetUniformBlockIndex(program, "Frame_Uniforms")
	(uniform_index != gl.INVALID_INDEX) or_return
	gl.UniformBlockBinding(program, uniform_index, FRAME_UNIFORM_INDEX)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, FRAME_UNIFORM_INDEX, ren.frame_UBO)

	return program, true
}

ren_make_basic_shader :: proc (ren: ^Ren, vert, frag: string) -> gl.Program {
	// Compile program
	program, ok := gl.load_shaders_source(vert, frag)
	gl.UseProgram(program)
	defer gl.UseProgram(0)
	log.assertf(ok, "A shader failed to compile/link.\n%s\n%s", vert, frag)

	font_atlas_sampler := gl.GetUniformLocation(program, "font_atlas")
	if font_atlas_sampler != -1 {
		gl.glUniform1i(font_atlas_sampler, cast(int) Texture_Unit.Font)
		assert(gl.GetError() == .NO_ERROR)
	}
	texture_atlas_sampler := gl.GetUniformLocation(program, "texture_atlas")
	if texture_atlas_sampler != -1 {
		gl.glUniform1i(texture_atlas_sampler, cast(int) Texture_Unit.Texture)
		assert(gl.GetError() == .NO_ERROR)
	}
	fb_sampler := gl.GetUniformLocation(program, "framebuffer_color")
	if fb_sampler != -1 {
		gl.glUniform1i(fb_sampler, cast(int) Texture_Unit.Framebuffer_Texture)
		assert(gl.GetError() == .NO_ERROR)
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
	if prev.render_target != next.render_target {
		pipeline_changed = true
		// log.infof("Set FB [%p]%v -> [%p]%v)", prev, prev.render_target, next, next.render_target)
		gl.BindFramebuffer(.FRAMEBUFFER, next.render_target)
	}

	if prev.program != next.program {
		pipeline_changed = true
		prev.program = next.program
		gl.UseProgram(next.program)
	}

	if prev.VAO != next.VAO {
		pipeline_changed = true
		prev.VAO = next.VAO
		gl.BindVertexArray(next.VAO)
	}

	if prev.cull_mode != next.cull_mode {
		pipeline_changed = true
		// Conflating enable/disable with mode causes more API calls.
		// but these ones are cheap.
		switch next.cull_mode {
		case .None: 
			gl.glDisable(gl.CULL_FACE)
		case .Front_Faces:
			gl.Enable(.CULL_FACE)
			gl.CullFace(.FRONT)
		case .Back_Faces:
			gl.Enable(.CULL_FACE)
			gl.CullFace(.BACK)
		}
	}
	// If there was a change, each program locates instances differently.
	if pipeline_changed {
		// At the time of writing, freeing an entity doesn't wipe the draw command.
		// This works for now, but if there's a bug in the future, suspect this.
		prev^ = next^
	}
}

ren_force_draw_entity :: proc (ren: ^Ren, entity: ^Entity, loc := #caller_location) {
	ren_bind_or_reuse_draw_command(entity)
	gl.DrawElements(
		ren_mode_to_primitive(entity.draw_command.mode),
		count  = entity.draw_command.index_count,
		type   = .UNSIGNED_INT,
		indices = cast(uintptr) 0,
		_loc = loc
	)
}

ren_draw_entity :: proc (ren: ^Ren, entity: ^Entity) {
	entity.flags -= {.Skip_Next_Interpolation}
	if .Hidden in entity.flags { return }
	if .Allocated not_in entity.flags { return }
	ren_force_draw_entity(ren, entity)
}

ren_clear :: proc () {
	gl.BindFramebuffer(.FRAMEBUFFER, 0)
	gl.Clear({.COLOR_BUFFER_BIT, .DEPTH_BUFFER_BIT, .STENCIL_BUFFER_BIT})
	gl.BindFramebuffer(.FRAMEBUFFER, globals.ren.canvas.fbo)
	gl.Clear({.COLOR_BUFFER_BIT, .DEPTH_BUFFER_BIT, .STENCIL_BUFFER_BIT})
	gl.BindFramebuffer(.FRAMEBUFFER, globals.ren.prev_cmd.render_target)
}

ren_draw :: proc (ren: ^Ren) {
	gl.BindBuffer(.ARRAY_BUFFER, globals.instance_buffer)
	gl.BufferSubData(.ARRAY_BUFFER, 0, globals.instance_staging[:])

	globals.uniforms.projection = globals.perspective_projection
	globals.uniforms.view = globals.perspective_view
	gl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	gl.BufferSubData(.UNIFORM_BUFFER, 0, &globals.uniforms)
	for entity in globals.entities_3D {
		ren_draw_entity(ren, entity)
	}

	globals.uniforms.projection = globals.orthographic_projection
	globals.uniforms.view = globals.orthographic_view
	gl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	gl.BufferSubData(.UNIFORM_BUFFER, 0, &globals.uniforms)
	for entity in globals.entities_2D {
		if .Is_UI in entity.flags { continue }
		ren_draw_entity(ren, entity)
	}

	if globals.draw_colliders {
		ren_draw_colliders :: proc (allocator: runtime.Allocator) {
			mesh := Geom_Mesh2 {
				vertices = make([dynamic]Ren_Vertex_Base, allocator),
				indices = make([dynamic]u32, allocator)
			}
			for entity in globals.entities {
				if .Collider_Enabled not_in entity.flags || entity.collider.shape == .None {
					continue
				}
				switch entity.collider.shape {
				case .None:
				case .Point: fallthrough
				case .Circle:
					geom_append_circle(&mesh, 16, entity.position, entity.collider.size.x/2) // <---| NOTE not interpolated
				case .AABB:
					geom_append_quad(&mesh, entity.position, entity.collider.size) // <-------------| NOTE not interpolated
				}
			}
			if len(mesh.vertices) == 0 do return // INTENT: Silence logs for empty buffer-copies.
			viz := globals.collider_visualization
			if viz.draw_command.VAO == 0 {
				viz.draw_command = ren_make_basic_draw_cmd(
					globals.instance_buffer,
					cast(int) viz.id,
					mesh.vertices[:],
					mesh.indices[:])
			} else {
				ren_reuse_basic_draw_cmd(
					&viz.draw_command,
					globals.instance_buffer,
					cast(int) viz.id,
					mesh.vertices[:],
					mesh.indices[:])
			}
			gl.BindVertexArray(viz.draw_command.VAO) // TODO: IDK why I need this.
			ren_force_draw_entity(globals.ren, viz)
		}
		ren_draw_colliders(context.temp_allocator)
	}

	globals.uniforms.projection = globals.ui_projection
	globals.uniforms.view = globals.ui_view
	gl.BindBuffer(.UNIFORM_BUFFER, ren.frame_UBO)
	gl.BufferSubData(.UNIFORM_BUFFER, 0, &globals.uniforms)
	for entity in globals.entities_2D {
		if .Is_UI not_in entity.flags { continue }
		ren_draw_entity(ren, entity)
	}
}

//////////////////////////////////////////////////////////////////////
// Section: Framebuffer
//////////////////////////////////////////////////////////////////////

make_render_target :: proc (
	size_px: [2]int,
	_loc := #caller_location
) -> (out: Render_Target) {
	make_or_resize_render_target(&out, size_px, _loc)
	return
}

resize_render_target :: proc (
	rt: ^Render_Target,
	size_px: [2]int,
	_loc := #caller_location) {
	assert(rt.fbo == 0)
	assert(rt.color == 0)
	assert(rt.depth_stencil == 0)
	make_or_resize_render_target(rt, size_px, _loc)
	return
}

// if the GL objects pointed to by `rt` are 0, they will be overwritten with new objects.
make_or_resize_render_target :: proc (rt: ^Render_Target, size_px: [2]int, _loc := #caller_location) {
	rt.size_px = size_px
	gl.glActiveTexture(gl.TEXTURE0)

	if rt.color == 0 {
		_, rt.color = gl.CreateTexture()
assert(rt.color != 0)
	}
	gl.BindTexture(.TEXTURE_2D, rt.color)
assert(gl.Error.NO_ERROR == gl.validate(_loc))
	gl.make_texture_2D(
		.TEXTURE_2D,
		.RGBA8,
		size_px.x, size_px.y,
		{},
		lod=0)
	gl.Set_Texture_Min_Filter(.TEXTURE_2D, .LINEAR)
	gl.Set_Texture_Mag_Filter(.TEXTURE_2D, .LINEAR)
	gl.Set_Texture_Wrap_S(.TEXTURE_2D, .CLAMP_TO_EDGE)
	gl.Set_Texture_Wrap_T(.TEXTURE_2D, .CLAMP_TO_EDGE)
	gl.BindTexture(.TEXTURE_2D, 0)

	if rt.depth_stencil == 0 {
		_, rt.depth_stencil = gl.CreateTexture()
assert(rt.depth_stencil != 0)
	}
	gl.BindTexture(.TEXTURE_2D, rt.depth_stencil)
assert(gl.Error.NO_ERROR == gl.validate(_loc))
	gl.make_texture_2D(
		.TEXTURE_2D,
		.DEPTH24_STENCIL8,
		size_px.x, size_px.y,
		{},
		lod=0)
	gl.Set_Texture_Min_Filter(.TEXTURE_2D, .LINEAR)
	gl.Set_Texture_Mag_Filter(.TEXTURE_2D, .LINEAR)
	gl.Set_Texture_Wrap_S(.TEXTURE_2D, .CLAMP_TO_EDGE)
	gl.Set_Texture_Wrap_T(.TEXTURE_2D, .CLAMP_TO_EDGE)
	gl.BindTexture(.TEXTURE_2D, 0)

	if rt.fbo == 0 {
		rt.fbo = gl.CreateFramebuffer()
assert(rt.fbo != 0)
	}
	gl.BindFramebuffer(.FRAMEBUFFER, rt.fbo)
assert(gl.Error.NO_ERROR == gl.validate(_loc))
assert(gl.Error.NO_ERROR == gl.validate(_loc))
	gl.FramebufferTexture2D(.FRAMEBUFFER, .COLOR_ATTACHMENT0, .TEXTURE_2D, rt.color, level=0)
	gl.FramebufferTexture2D(.FRAMEBUFFER, .DEPTH_STENCIL_ATTACHMENT, .TEXTURE_2D, rt.depth_stencil, level=0)
	val := gl.CheckFramebufferStatus(.FRAMEBUFFER)
assert(val == gl.FRAMEBUFFER_COMPLETE)
	gl.Clear({.COLOR_BUFFER_BIT, .DEPTH_BUFFER_BIT, .STENCIL_BUFFER_BIT})
assert(gl.Error.NO_ERROR == gl.validate(_loc))
	gl.BindFramebuffer(.FRAMEBUFFER, 0)
assert(gl.Error.NO_ERROR == gl.validate(_loc))

	gl.glActiveTexture(gl.TEXTURE0 + cast(u32) Texture_Unit.Framebuffer_Texture)
	gl.BindTexture(.TEXTURE_2D, rt.color)
assert(gl.Error.NO_ERROR == gl.validate(_loc))
	gl.glActiveTexture(gl.TEXTURE0)
}

//////////////////////////////////////////////////////////////////////
// Section: Draw Commands
//////////////////////////////////////////////////////////////////////

// 1. Store the attribute bindings so it's easier to overwrite them.
// 2. That doesn't help me diff. Just wanna set attrs 4,5,6
// What's the ideal API?
// set_basic_draw_command_instance :: proc (cmd: ^Draw_Command, entity: Entity) {
// 	entity_offset := uintptr(size_of(Any_Instance) * cast(int) entity.id)
// 	cmd.attributes[3].offset = entity_offset + offset_of(Any_Instance, model_transform)
// 	cmd.attributes[4].offset = entity_offset + offset_of(Any_Instance, uv_transform)
// 	cmd.attributes[5].offset = entity_offset + offset_of(Any_Instance, color)
// 	ensure(!(cmd.attributes[1].location == 0 && cmd.attributes[1].location == 0))
// 	gl.BindVertexArray(cmd.VAO)
// 	set_VAO_attribute(cmd.VAO, cmd.attributes[3])
// 	set_VAO_attribute(cmd.VAO, cmd.attributes[4])
// 	set_VAO_attribute(cmd.VAO, cmd.attributes[5])
// 	gl.BindBuffer(.ARRAY_BUFFER, 0)
// 	gl.BindVertexArray(0)
// 	// set_VAO_attributes(cmd.VAO, cmd.attributes)
// }

init_cmd_with_basic_vertex_attributes :: proc (
	cmd: ^Draw_Command,
	VBO: gl.Buffer,
	instance_buffer: gl.Buffer,
	instance_index: int,
) {
	cmd.render_target = globals.ren.canvas.fbo
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
	// TODO: Delete this when I can create commands up-front and "inherit" them.
	// Purpose 1. Rebinding/copying/templating from existing draws.
	//            Only rebind attributes whose buffers change.
	//            Ensures draw calls keep their attributes and associated resources.
	// Purpose 2. Don't create loads of VAOs. Not certainly a good idea to optimize for.
	// This will allow re-using VAOs, but not draw commands,
	// and is to be deleted the moment I can query for commands and "inherit" them.
	if len(cmd.attributes) < len(attributes) {
		if len(cmd.attributes) > 0 {
			delete(cmd.attributes)
		} else {
			cmd.attributes = make([]Attribute_Binding, len(attributes))
			copy(cmd.attributes, attributes)
		}
	}
	set_VAO_attributes(cmd.VAO, cmd.attributes)
	ensure(len(cmd.attributes) > 2)
	ensure(!(cmd.attributes[0].location == 0 && cmd.attributes[1].location == 0))
}

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
	loc := #caller_location
) -> (cmd: Draw_Command) {
	cmd.program = globals.ren.programs[.Basic]
	gl.GenVertexArrays(1, &cmd.VAO)
	gl.BindVertexArray(cmd.VAO)

	// Create Vertex Buffer
	VBO: gl.Buffer
	gl.GenBuffers(1, &VBO)
	gl.BindBuffer(.ARRAY_BUFFER, VBO, loc)
	gl.BufferData(.ARRAY_BUFFER, vertices, .STREAM_DRAW, loc)
	gl.BindBuffer(.ARRAY_BUFFER, 0, loc)

	// Create Index Buffer
	cmd.index_count = len(indices)
	gl.GenBuffers(1, &cmd.index_buffer, loc)
	gl.BindBuffer(.ELEMENT_ARRAY_BUFFER, cmd.index_buffer, loc)
	gl.BufferData(.ELEMENT_ARRAY_BUFFER, indices, _loc=loc)
	init_cmd_with_basic_vertex_attributes(&cmd, VBO, instance_buffer, instance_index)
	return
}

// TODO: maybe rename it something "entity draw cmd?"
//   but that can't be it, it implies there are draws that aren't for entities.
//
// A "basic" draw command uses the engine frame-buffer and instance-buffer.
// This proc will not free those resources, but will free all else.
//
// ASSUMES: Shaders are deleted upon linking the Program.
ren_free_basic_draw_cmd :: proc (cmd: Draw_Command) {
	if cmd.index_buffer != 0 {
		gl.DeleteBuffer(cmd.index_buffer)
	}
	if cmd.attributes != nil {
		for attr in cmd.attributes {
			if attr.buffer == globals.instance_buffer && attr.buffer != 0 {
				// EARLY RETURN INTENT: Don't free the shared entity instance buffer.
				continue
			}
			gl.DeleteBuffer(attr.buffer)
		}
		delete(cmd.attributes)
	}
	if cmd.textures != nil { delete(cmd.textures) }
	gl.DeleteProgram(cmd.program)
	gl.DeleteVertexArray(cmd.VAO)
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
	init_cmd_with_basic_vertex_attributes(&cmd, VBO, instance_buffer, instance_index)

	return
}

ren_reuse_basic_draw_cmd :: proc (
	cmd: ^Draw_Command,
	instance_buffer: gl.Buffer,
	instance_index: int,
	vertices: []Ren_Vertex_Base,
	indices:  []u32,
) {
	gl.BindVertexArray(cmd.VAO)
	// works because ASSUMING created with init_cmd_with_basic_vertex_attributes
	VBO := cmd.attributes[0].buffer
	gl.BindBuffer(.ARRAY_BUFFER, VBO)
	gl.BufferData(.ARRAY_BUFFER, vertices, .STREAM_DRAW)
	gl.BindBuffer(.ARRAY_BUFFER, 0)

	cmd.index_count = len(indices)
	gl.BindBuffer(.ELEMENT_ARRAY_BUFFER, cmd.index_buffer)
	gl.BufferData(.ELEMENT_ARRAY_BUFFER, indices)
	init_cmd_with_basic_vertex_attributes(cmd, VBO, instance_buffer, instance_index)
}

ren_make_water_draw_cmd :: proc (
	instance_buffer: gl.Buffer,
	instance_index: int,
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
	

	init_cmd_with_basic_vertex_attributes(&cmd, VBO, globals.instance_buffer, instance_index)
	return
}


//////////////////////////////////////////////////////////////////////
// GL_UTIL
//////////////////////////////////////////////////////////////////////

GLES_MAX_BINDINGS :: 16 // per spec
GLES_MAX_FRAGMENT_TEXTURES :: 16 // limit from Intel HD 4000

set_VAO_attributes :: proc (
	VAO:        gl.VertexArrayObject,
	attributes: []Attribute_Binding,
) {
	assert(len(attributes) <= GLES_MAX_BINDINGS , "GLSL shaders only have 16 slots.")

	// Enable inputs
	next_location: u32 = 0
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

	gl.BindVertexArray(VAO)
	for attr in attributes {
		set_VAO_attribute(VAO, attr)
	}
	gl.BindBuffer(.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)
}

set_VAO_attribute :: proc (
	VAO:  gl.VertexArrayObject,
	attr: Attribute_Binding,
) {
	divisor: u32 = 0 if attr.rate == .Vertex else 1
	slots := slots_used_by_type(attr.type)
	gl.BindBuffer(.ARRAY_BUFFER, attr.buffer)
	for slot_num in 0..<slots {
		index := attr.location + slot_num
		num_components := attr.value_count / cast(int) slots
		// WARNING: Breaks when you start needing ivecs... probably.
		// This size_of in here is a little forceful.
		// But usually if you've got a multi-slot it's an f32 matrix.
		offset := attr.offset + cast(uintptr) (cast(u32) num_components * slot_num * size_of(f32))
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
		ensure(gl.glVertexAttribDivisor != nil)
		gl.VertexAttribDivisor(index, divisor)
	}
}

glsl_attrib_is_int :: proc (type: GLSL_Attribute_Type) -> bool {
	return type >= .i32
}

slots_used_by_type :: proc (type: GLSL_Attribute_Type) -> u32 {
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

bind_texture_to_unit :: proc (texture_unit: u32, texture: GPU_Texture) {
	gl.glActiveTexture(gl.TEXTURE0 + texture_unit)
	gl.BindTexture(texture.target, texture.texture)
}

init_and_upload_texture :: proc (texture_unit: u32, texture: ^GPU_Texture, pixels: []$T, size_px: [2]int) -> bool {
	assert(texture.texture == 0)
	assert(pixels != nil)
	assert(gl.glGenTextures != nil)
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
		cast(u32) info.format,
		cast(u32) info.type,
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
		cast(u32) info.format,
		cast(u32) info.type,
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

// Keep synchronized with Uniforms :: struct (stored at globals.uniforms.)
frame_uniforms :: `
	layout(std140) uniform Frame_Uniforms {
		mat4  view;       // where the camera is
		mat4  projection; // camera lens
		float time;
		float tau_time;
		vec2  ball_position;
		vec2  ball_size;
		vec2  hand_position;
		vec2  hand_size;
		vec2  canvas_size_px;
		vec2  collision_position;
		float collision_force;
		float collision_time;
	} frame;
`

glsl_constants :: `
const float PI = 3.141592653589793;
`

vertex_preamble :: 
	version +
	"#pragma STDGL invariance(all)\n" +
	precision_defaults +
	glsl_constants +
	frame_uniforms

fragment_preamble ::
	version +
	precision_defaults +
	glsl_constants +
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
//basicvert
	out vec4 io_color;

	void main() {
		io_color.rgb = i_color.rgb * i_color.a; // Convert to PMA
		io_color.a = i_color.a; // Convert to PMA
		mat4 mvp = frame.projection * frame.view * i_model_mat;
		gl_Position = mvp * vec4(v_position, 1);
	}
`

basic_fragment_shader_source :: fragment_preamble + `
//basicfrag
	in vec4 io_color;
	out vec4 outColor;
	void main() {
		outColor = io_color;
	}
`

// Basic: Water ////////////////////////////////////////////////////////////////
water_vertex_shader_source :: vertex_preamble + basic_vertex_inputs +
`
//watervert
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
//waterfrag
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
//text_vert
	layout (location = 0) in vec3 v_position;
	layout (location = 1) in vec2 v_texcoord;
	layout (location = 2) in vec3 v_normal;
	layout (location = 3) in mat4 i_model_mat;
	layout (location = 7) in vec4 i_uv_xform;
	layout (location = 8) in vec4 i_color;

	out vec4 io_color;
	out vec2 uv;

	void main() {
		io_color   = clamp(i_color, 0.0, 1.0);
		mat4 mvp   = frame.projection * frame.view * i_model_mat;
		gl_Position = mvp * vec4(v_position, 1);
		uv = v_texcoord;
	}
`

text_fragment_shader_source :: fragment_preamble + `
//text_frag
	uniform sampler2D font_atlas;

	in vec4 io_color;
	in vec2 uv;

	out vec4 outColor;

	void main() {
		vec4 glyph_alpha = texture(font_atlas, uv);
		outColor = mix(vec4(0.0), io_color, io_color.a * glyph_alpha.r);
	}
`
