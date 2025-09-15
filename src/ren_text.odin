package main

import gl "nord_gl"
import stbtt "vendor:stb/truetype"
import "base:runtime"
import "core:fmt"
import "core:slice"
import "core:log"
import "core:c"
import "core:math/linalg"

//////////////////////////////////////////////////////////////////////
// Entity Variant
//////////////////////////////////////////////////////////////////////

Text_Entity :: struct {
	using base:  Entity,
	using variant: Text,
}

Text :: struct {
	text: string,
	font: ^Font,
}

//////////////////////////////////////////////////////////////////////
// Interface
//////////////////////////////////////////////////////////////////////

text :: proc (
	message: string,
	usage:   Font_Usage   = .body,
	variant: Font_Variant = .regular,
) -> ^Text_Entity {
	entity: ^Text_Entity = make_entity(Text_Entity)
	entity.font = &globals.fonts[usage][variant]
	entity.text = message
	return entity
}

do_text :: proc (
	message:  string,
	position: Vec3,
	usage:    Font_Usage   = .body,
	variant:  Font_Variant = .regular,
) {
	entity: ^Text_Entity = text(message, usage, variant)
	entity.position = position
	entity.color = 1
	step_text(entity, immediate=true)
	ren_draw_entity(globals.ren, transmute(^Entity) entity)
	free_entity(entity)
}

Font_Usage :: enum {
	caption,    // 10px, sans // TODO: link to definition
	body,       // 12px, sans
	body_large, // 16px, sans
	header,     // 20px, sans
	mono        // 12px, mono
}

Font_Variant :: enum {
	regular,
	bold,
	italic,
	bold_italic
}

Font_Family :: [Font_Variant]Font
Font :: struct {
	name:       string,
	file_bytes: []u8,
	height_px:  f32,
	scale:      f32,
	is_monospace: bool, // else proportional
	// stb related data
	info: stbtt.fontinfo,
	data: []stbtt.packedchar,
  // Scaled metrics
  monospace_advance: f32,
  ascent:            f32,
  descent:           f32,
  line_height:       f32,
  line_gap:          f32,
}

//////////////////////////////////////////////////////////////////////
// Framework Integration Implementation
//////////////////////////////////////////////////////////////////////
// Last chance to write instance data before it's bulk-copied.
step_text :: proc (entity: ^Text_Entity, immediate: bool) {
	font: ^Font = entity.font
	verts_needed   := len(entity.text) * 4
	indices_needed := len(entity.text) * 6
	verts := make([]Ren_Vertex_Base, verts_needed, context.temp_allocator)
	indices := make([]u32, indices_needed, context.temp_allocator)

  atlas_size: [2]int = globals.assets.font_atlas.size_px

	text_cursor: [2]f32
	for byte, glyph_index in entity.text {
		chardata_index := i32(byte - 32)
		quad: stbtt.aligned_quad
		stbtt.GetPackedQuad(raw_data(font.data),
			cast(i32) atlas_size.x,
			cast(i32) atlas_size.y,
			chardata_index,
			&text_cursor.x,
			&text_cursor.y,
			&quad,
			false)

		gnum := glyph_index+1
		verts[(4*gnum)-4] = { position = {quad.x0,quad.y0, 0,}, texcoord = {quad.s0,quad.t0} }
		verts[(4*gnum)-3] = { position = {quad.x1,quad.y0, 0,}, texcoord = {quad.s1,quad.t0} }
		verts[(4*gnum)-2] = { position = {quad.x0,quad.y1, 0,}, texcoord = {quad.s0,quad.t1} }
		verts[(4*gnum)-1] = { position = {quad.x1,quad.y1, 0,}, texcoord = {quad.s1,quad.t1} }

		indices[(6*gnum)-6] = u32(4*glyph_index)+0 // TL
		indices[(6*gnum)-5] = u32(4*glyph_index)+2 // BL
		indices[(6*gnum)-4] = u32(4*glyph_index)+1 // TR
		indices[(6*gnum)-3] = u32(4*glyph_index)+3 // BR
		indices[(6*gnum)-2] = u32(4*glyph_index)+1 // TR
		indices[(6*gnum)-1] = u32(4*glyph_index)+2 // BL
	}
// Flush Instance //////////////////////////////////////////////////////////////
	if immediate {
		globals.instance_staging[entity.id] = {
			model_transform = linalg.matrix4_translate(entity.position) *
												linalg.matrix4_from_euler_angles_xyz_f32(entity.rotation.x, 
												                                         entity.rotation.y, 
												                                         entity.rotation.z) *
												linalg.matrix4_scale(entity.scale),
			color = entity.color
		}
		gl.BindBuffer(.ARRAY_BUFFER, globals.instance_buffer)
		gl.BufferSubData(.ARRAY_BUFFER, 0, globals.instance_staging[entity.id:entity.id+1])
		gl.BindBuffer(.ARRAY_BUFFER, 0)
	}
	entity.draw_command = ren_make_text_draw_cmd(globals.instance_buffer, cast(int) entity.id, verts[:], indices[:])
}
