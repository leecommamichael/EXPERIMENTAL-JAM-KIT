package main

import gl "angle"

make_circle :: proc () -> (^Entity, bool) #optional_ok {
	it, new := circle(); if new {
		it.flags -= {.Immediate_Mode, .Immediate_In_Use}
	}
	return it, new
}

circle :: proc (hash: Located_Hash_Input = #caller_location) -> (^Entity, bool) #optional_ok {
	entity, is_new := do_entity({})
	if is_new {
		entity.draw_command = ren_make_basic_draw_cmd(
		globals.instance_buffer, cast(int) entity.id,
		globals.unit_circle_mesh.vertices[:],
		globals.unit_circle_mesh.indices[:])
	}
	entity.position.z = next_z()
	return entity, is_new
}

rect :: proc (
	entity_hash: Located_Hash_Input = #caller_location,
) -> (^Entity, bool) #optional_ok {

	entity, is_new := do_entity(entity_hash)
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
	entity, is_new := do_entity(_loc)
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
