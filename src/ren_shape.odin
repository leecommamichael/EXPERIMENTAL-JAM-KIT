package main

import gl "angle"

mesh :: proc {
	mesh_from_vertices,
	mesh_from_geom
}

mesh_from_vertices :: proc (verts: ^[]Vec3, hash: Hash = #caller_location) -> (^Entity, bool) #optional_ok {
	entity, is_new := get_entity(hash)
	// INTENT: Reference comparison.
	if verts != entity._data {
		// They're just getting copied to the GPU, no need to retain.
		temp_indices := make([dynamic]u32, context.temp_allocator)
		for i in 0..<len(verts) {
			append(&temp_indices, cast(u32)i)
		}
		
		temp_verts := make([dynamic]Ren_Vertex_Base, context.temp_allocator)
		for v in verts {
			append(&temp_verts, Ren_Vertex_Base{position=v})
		}
		if is_new {
			entity.draw_command = ren_make_basic_draw_cmd(
				globals.instance_buffer, cast(int) entity.id,
				temp_verts[:],
				temp_indices[:])
		} else {
			ren_reuse_basic_draw_cmd(&entity.draw_command,
				globals.instance_buffer, cast(int) entity.id,
				temp_verts[:],
				temp_indices[:])
		}
		entity._data = verts
	}
	// entity.position.z = next_z()
	return entity, is_new
}

mesh_from_geom :: proc (mesh: ^Geom_Mesh2, hash: Hash = #caller_location) -> (^Entity, bool) #optional_ok {
	entity, is_new := get_entity(hash)
	// INTENT: Reference comparison.
	if mesh != entity._data {
		if is_new {
			entity.draw_command = ren_make_basic_draw_cmd(
				globals.instance_buffer, cast(int) entity.id,
				mesh.vertices[:],
				mesh.indices[:])
		} else {
			ren_reuse_basic_draw_cmd(&entity.draw_command,
				globals.instance_buffer, cast(int) entity.id,
				mesh.vertices[:],
				mesh.indices[:])
		}
		entity._data = mesh
	}
	// entity.position.z = next_z()
	return entity, is_new
}

circle :: proc (hash: Hash = #caller_location) -> (^Entity, bool) #optional_ok {
	entity, is_new := get_entity(hash)
	if is_new {
		entity.draw_command = ren_make_basic_draw_cmd(
		globals.instance_buffer, cast(int) entity.id,
		globals.unit_circle_mesh.vertices[:],
		globals.unit_circle_mesh.indices[:])
	}
	entity.position.z = next_z()
	return entity, is_new
}

sphere :: proc (hash: Hash = #caller_location) -> (^Entity, bool) #optional_ok {
	entity, is_new := get_entity(hash)
	if is_new {
		entity.draw_command = ren_make_phong_draw_cmd(
		globals.instance_buffer, cast(int) entity.id,
		globals.unit_sphere_mesh.vertices[:],
		globals.unit_sphere_mesh.indices[:])
		entity.flags += {.Is_3D}
		entity.blend_normals = true
	}
	// entity.position.z = next_z()
	return entity, is_new
}

// With anchor at bottom-left.
rect :: proc (
	color: Color4 = {1,1,1,1},
	hash: Hash = #caller_location,
) -> (^Entity, bool) #optional_ok {

	entity, is_new := get_entity(hash)
	if is_new {
		entity.draw_command = ren_make_basic_draw_cmd(
		globals.instance_buffer, cast(int) entity.id,
		globals.unit_rect_mesh.vertices[:],
		globals.unit_rect_mesh.indices[:])
	}
	entity.color = color
	entity.position.z = next_z()
	return entity, is_new
}

// With anchor at center.
quad :: proc (
	hash: Hash = #caller_location,
) -> (^Entity, bool) #optional_ok {

	entity, is_new := get_entity(hash)
	if is_new {
		entity.draw_command = ren_make_basic_draw_cmd(
		globals.instance_buffer, cast(int) entity.id,
		globals.unit_quad_mesh.vertices[:],
		globals.unit_quad_mesh.indices[:])
	}
	entity.position.z = next_z()
	return entity, is_new
}

framebuffer_quad :: proc (
	from: gl.Framebuffer, 
	to: gl.Framebuffer, 
	_loc := #caller_location
) -> (^Entity, bool) #optional_ok {
	entity, is_new := get_entity(_loc)
	if is_new {
		entity.draw_command = ren_make_basic_draw_cmd(
		globals.instance_buffer, cast(int) entity.id,
		globals.unit_quad_mesh.vertices[:],
		globals.unit_quad_mesh.indices[:])
		entity.draw_command.program = globals.ren.programs[.Framebuffer_Texture]
		entity.draw_command.render_target = to
	}
	entity.position.z = next_z()
	return entity, is_new
}

framebuffer_quad_vertex_shader_source :: vertex_preamble + `
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

framebuffer_quad_fragment_shader_source :: fragment_preamble + `
	uniform sampler2D framebuffer_color;

	in vec4 io_color;
	in vec2 uv;

	out vec4 outColor;

	void main() {
		vec4 glyph_alpha = texture(framebuffer_color, uv);
		outColor.rgb = glyph_alpha.rgb * glyph_alpha.a;
		outColor.a = glyph_alpha.a;
	}
`
