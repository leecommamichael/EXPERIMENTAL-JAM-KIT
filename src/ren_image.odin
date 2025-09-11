package main

import gl "nord_gl"

//////////////////////////////////////////////////////////////////////
// Entity Variant
//////////////////////////////////////////////////////////////////////
Image_Entity :: struct {
	using base:  Entity,
	using image: ^Image,
}

Image :: struct {
	filename:       string,
	size_in_pixels: [2]int,
	uv_rect:        [4]f32, // .xy = top_left, .w = width, .z = height
	lod:            int,
	gpu_handle:     gl.Texture,
}

//////////////////////////////////////////////////////////////////////
// Interface
//////////////////////////////////////////////////////////////////////

image :: proc (filename: string) -> ^Image_Entity {
	image: ^Image = &globals.assets.images[filename]
	entity: ^Image_Entity = make_entity(Image_Entity)
	entity.image = image
	return entity
}

do_image :: proc (filename: string, position: Vec3) {
	entity: ^Image_Entity = make_entity(Image_Entity)
	entity.position = position
	step_image(entity, immediate=true)
	ren_draw_entity(globals.ren, transmute(^Entity) entity)
	free_entity(entity)
}

//////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////

image_vertex_shader_source :: vertex_preamble + basic_vertex_inputs +
`
	out vec4 io_color;
	out vec2 uv;

	void main() {
		uv = v_texcoord;
		io_color = i_color;
		mat4 mvp = frame.projection * frame.view * i_model_mat;
		gl_Position = mvp * vec4(v_position, 1);
	}
`

image_fragment_shader_source :: fragment_preamble + `
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

ren_make_image_draw_cmd :: proc (
	instance_buffer: gl.Buffer,
	instance_index: int,
	vertices: []Ren_Vertex_Base,
	indices:  []u32,
) -> (cmd: Draw_Command) {
	cmd = ren_make_basic_draw_cmd(instance_buffer, instance_index, vertices, indices)
	cmd.program = globals.ren.programs[Game_Shader.Image]
	return cmd
}

step_image :: proc (entity: ^Image_Entity, immediate: bool) {
	// ...
}
