package main

import gl "nord_gl"

//////////////////////////////////////////////////////////////////////
// Entity Variant
//////////////////////////////////////////////////////////////////////

Image_State :: struct {
	asset: ^Image_Asset,
}

// Rect geometry could be the size or scale it from 1.
Image_Asset :: struct {
	filename: string, // TODO?: call it ID? name/id. name.
	uv_rect:  [4]f32, // .xy = top_left, .w = width, .z = height
	size_px:  [2]int,
	texture:  ^GPU_Texture `cbor:"-"`
}

//////////////////////////////////////////////////////////////////////
// Immediate Interface
//////////////////////////////////////////////////////////////////////

image :: proc (filename: string, loc := #caller_location) -> (^Entity, bool) {
// This way I don't have to explode the API into retained/immediate
// The storage can be in the system, only necessary copies.
	entity, is_new := do_entity(loc)
	if is_new {
		init_image(entity)
		set_image(entity, filename)
	} else if filename != entity.variant.(Image_State).asset.filename {
		// TODO: Come up with comprehensive state diffing.
		set_image(entity, filename)
	}
	entity.position.z = next_z()
	return entity, is_new
}

//////////////////////////////////////////////////////////////////////
// Retained Interface
//////////////////////////////////////////////////////////////////////

make_image :: proc (filename: string) -> ^Entity {
	entity := make_entity()
	init_image(entity)
	set_image(entity, filename)
	return entity
}

init_image :: proc (entity: ^Entity) {
	mesh: Geom_Mesh2 = geom_make_quad(1, context.temp_allocator)
	entity.draw_command = image_make_draw_command(globals.instance_buffer, cast(int) entity.id, mesh.vertices[:], mesh.indices[:])
}

set_image :: proc (entity: ^Entity, filename: string) {
	image := Image_State {
		asset = &globals.assets.images[filename]
	}
	entity.variant = image
	entity.basis.scale.xy = array_cast(image.asset.size_px, f32)
	entity.basis.position.xy = array_cast(image.asset.size_px/2, f32)
}

//////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////
image_vertex_shader_source :: vertex_preamble + basic_vertex_inputs +
`
	out vec4 io_color;
	out vec2 uv;

	void main() {
		uv = i_uv_xform.xy + (v_texcoord * i_uv_xform.zw);
		io_color = i_color;
		mat4 mvp = frame.projection * frame.view * i_model_mat;
		gl_Position = mvp * vec4(v_position, 1);
	}
`

image_fragment_shader_source :: fragment_preamble + 
`
	uniform sampler2D font_atlas;
	uniform sampler2D texture_atlas;

	in vec4 io_color;
	in vec2 uv;

	out vec4 outColor;

	void main() {
		vec4 tex_color = texture(texture_atlas, uv);
		outColor = tex_color;
	}
`

step_image :: proc (entity: ^Entity) {
	variant := entity.variant.(Image_State)
	globals.instance_staging[cast(int) entity.id].uv_transform = variant.asset.uv_rect
	// ...
}

image_make_draw_command :: proc (
	instance_buffer: gl.Buffer,
	instance_index: int,
	vertices: []Ren_Vertex_Base,
	indices:  []u32,
) -> (cmd: Draw_Command) {
	cmd = ren_make_basic_draw_cmd(instance_buffer, instance_index, vertices, indices)
	cmd.program = globals.ren.programs[Game_Shader.Image]
	return cmd
}
