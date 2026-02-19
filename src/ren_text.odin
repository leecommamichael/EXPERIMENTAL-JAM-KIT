package main

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

Text_State :: struct {
	text: string,
	font: ^Font,
}

//////////////////////////////////////////////////////////////////////
// Interface
//////////////////////////////////////////////////////////////////////


make_text :: proc (
	message: string,
	usage: Font_Usage = nil,
	variant: Font_Variant = nil,
) -> ^Entity {
	entity: ^Entity = make_entity()
	entity.flags += {.Skip_Interpolation}
	entity.variant = Text_State {
		message,
		&globals.fonts[usage][variant],
	}
	set_text(entity, message)
	entity.color = 1
	return entity
}

text :: proc (
	message: string,
	usage: Font_Usage = nil,
	variant: Font_Variant = nil,
	hash: Hash = #caller_location,
) -> (^Entity) {
	entity, is_new := get_entity(hash); if is_new {
		entity.flags += {.Skip_Interpolation}
		entity.variant = Text_State {}
		entity.color = 1
	}
	entity.variant = Text_State {
		message,
		&globals.fonts[usage][variant],
	}
	set_text(entity, message)
	entity.position.z = next_z()
	return entity
}

Font_Usage :: enum {
	caption,    // 10px, sans
	body,       // 12px, sans
	body_large, // 16px, sans
	header,     // 20px, sans
	mono,       // 12px, mono
	pixel,      // 16px, mono
	bold_pixel, // 16px, mono
}

Font_Variant :: enum {
	regular,
	bold,
	italic,
	bold_italic,
}

Font :: struct {
	name:       string,
	height_px:  f32,
	scale:      f32,
	// stb related data
	data: []stbtt.packedchar,
  // Scaled metrics
  monospace_advance: f32,
  ascent:            f32,
  descent:           f32,
  line_height:       f32,
  line_gap:          f32,
  // state for asset bundler
	bundled:    bool,
}

//////////////////////////////////////////////////////////////////////
// Framework Integration Implementation
//////////////////////////////////////////////////////////////////////
// Last chance to write instance data before it's bulk-copied.
set_text :: proc (entity: ^Entity, message: string) {
	text := entity.variant.(Text_State)
	text.text = message
	verts_needed   := len(text.text) * 4
	indices_needed := len(text.text) * 6
	verts := make([]Ren_Vertex_Base, verts_needed, context.temp_allocator)
	indices := make([]u32, indices_needed, context.temp_allocator)

  atlas_size: [2]int = globals.assets.font_atlas.size_px
	text_cursor: [2]f32
	quad: stbtt.aligned_quad
	for byte, glyph_index in text.text {
		chardata_index := i32(byte - 32)
		stbtt.GetPackedQuad(
			raw_data(text.font.data),
			cast(i32) atlas_size.x,
			cast(i32) atlas_size.y,
			chardata_index,
			&text_cursor.x,
			&text_cursor.y,
			&quad,
			false)

		if byte == ' ' {
			// TODO: only do this for pixel fonts
			quad.x0 = ceil(quad.x0)
			quad.x1 = ceil(quad.x1)
			quad.y0 = ceil(quad.y0)
			quad.y1 = ceil(quad.y1)
			text_cursor.x = ceil(text_cursor.x)
			text_cursor.y = ceil(text_cursor.y)
		}
		if byte == '\t' {
			text_cursor.x += text.font.monospace_advance * 2
		}
		if byte == '\n' {
			text_cursor.x = 0
			text_cursor.y += text.font.line_height
		}

		gnum := glyph_index+1
		verts[(4*gnum)-4] = { position = ({quad.x0,-quad.y0, 0,}), texcoord = {quad.s0,quad.t0} } // TL
		verts[(4*gnum)-3] = { position = ({quad.x1,-quad.y0, 0,}), texcoord = {quad.s1,quad.t0} } // TR
		verts[(4*gnum)-2] = { position = ({quad.x0,-quad.y1, 0,}), texcoord = {quad.s0,quad.t1} } // BL
		verts[(4*gnum)-1] = { position = ({quad.x1,-quad.y1, 0,}), texcoord = {quad.s1,quad.t1} } // BR

		indices[(6*gnum)-6] = u32(4*glyph_index)+0 // TL
		indices[(6*gnum)-5] = u32(4*glyph_index)+2 // BL
		indices[(6*gnum)-4] = u32(4*glyph_index)+1 // TR
		indices[(6*gnum)-3] = u32(4*glyph_index)+3 // BR
		indices[(6*gnum)-2] = u32(4*glyph_index)+1 // TR
		indices[(6*gnum)-1] = u32(4*glyph_index)+2 // BL
	}
	entity.basis.scale.xy = {text_cursor.x, text.font.line_height}
	for &v in verts {
		v.position.xy /= entity.basis.scale.xy
	}
	// JANKY: I need to re-use the VAO and buffer. Just resize it.
	if entity.draw_command.VAO == 0 {
		entity.draw_command = ren_make_text_draw_cmd(globals.instance_buffer, cast(int) entity.id, verts[:], indices[:])
	} else {
		ren_reuse_basic_draw_cmd(&entity.draw_command, globals.instance_buffer, cast(int) entity.id, verts[:], indices[:])
	}
}

// text cursor is at the baseline, so it's not useful.
// gotta measure distance between y1 and y0
measure_text :: proc (entity: Entity) -> (out: Vec2) {
	text := entity.variant.(Text_State)
  atlas_size: [2]int = globals.assets.font_atlas.size_px

	text_cursor: Vec2
	quad: stbtt.aligned_quad
	for byte, glyph_index in text.text {
		chardata_index := i32(byte - 32)
		stbtt.GetPackedQuad(
			raw_data(text.font.data),
			cast(i32) atlas_size.x,
			cast(i32) atlas_size.y,
			chardata_index,
			&text_cursor.x,
			&text_cursor.y,
			&quad,
			false)

		if byte == ' ' {
			// TODO: only do this for pixel fonts
			quad.x0 = ceil(quad.x0)
			quad.x1 = ceil(quad.x1)
			quad.y0 = ceil(quad.y0)
			quad.y1 = ceil(quad.y1)
			text_cursor.x = ceil(text_cursor.x)
			text_cursor.y = ceil(text_cursor.y)
		}
		if byte == '\t' {
			text_cursor.x += text.font.monospace_advance * 2
		}
		if byte == '\n' {
			text_cursor.x = 0
			text_cursor.y += text.font.line_height
		}
	}
	out.x = text_cursor.x + quad.x0 - quad.x1
	out.y = text.font.line_height
	// out.y = entity.basis.scale.y
	// out *= entity.basis.scale.xy * entity.scale.xy // This should be intrinsic size.
	return
}