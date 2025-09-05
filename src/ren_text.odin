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
// Interface
//////////////////////////////////////////////////////////////////////

Font_Usage :: enum {
	caption,    // 10px, sans
	body,       // 12px, sans
	body_large, // 16px, sans
	header,     // 20px, sans
	mono        // 12px, mono
}

Fonts :: [Font_Usage]Font_Family

// Use this to create an entity whose text changes when the string changes.
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

// Use this _every frame_ to draw text.
// It will disappear otherwise.
do_text :: proc (
	message:  string,
	position: Vec3,
	usage:    Font_Usage   = .body,
	variant:  Font_Variant = .regular,
) {
	entity: ^Text_Entity = make_entity(Text_Entity)
	entity.font = &globals.fonts[usage][variant]
	entity.text = message
	ren_draw_text(globals.ren, entity)
	free_entity(entity)
}

//////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////


set_font_height :: proc (font: ^Font, new_height_px: f32) {
	font.height_px = new_height_px
  scale: f32 = stbtt.ScaleForPixelHeight(&font.info, new_height_px);
  font.scale = scale

  // Get the font's line height
  ascent, descent, line_gap: f32;
  stbtt.GetFontVMetrics(&font.info, cast(^c.int)&ascent, cast(^c.int)&descent, cast(^c.int)&line_gap);
  font.ascent   = ascent  * scale;
  font.descent  = descent * scale;
  font.line_gap = line_gap * scale;
  font.line_height = font.ascent - font.descent + font.line_gap;

  // Get the monospace character width
  _lsb, monospace_advance: f32;
  stbtt.GetCodepointHMetrics(&font.info, ' ', cast(^c.int)&monospace_advance, cast(^c.int)&_lsb);
  font.monospace_advance = monospace_advance * scale;
}

//////////////////////////////////////////////////////////////////////
// Framework Integration Implementation
//////////////////////////////////////////////////////////////////////
import "core:strings"

// TODO: Introduce a stbtt.font_info cache so it doesn't parse the file so much.
ren_text_init :: proc () {

}

// Build an array of textured-quads to have drawn in one shot.
// This means a font bitmap is bound as a texture,
// And that texture is sampled in the shader.
//
// To do styled text, I'll have the whole font-family bound as textures.
// This means binding 4 textures before drawing.
// For this to work, I'll need each quad to know it's texture binding number...
//
// Ideally, I'd bind an array (texbindings) and send that up as a uniform.
// More ideally, I'd use a texture atlas, but that only goes so far.
// Eventually I'll need an array of lights anyway.
// So both techniques are needed. It's all about which way to go here.
// For people to add plenty of textures to their game, they'll need an easy
// way to upload textures to the GPU and not have to worry about associating
// every little drawn-instance to some texture binding number, just 
// having to say "this draw wants this image".
ren_draw_text :: proc (ren: ^Ren, entity: ^Text_Entity) {
	font: ^Font = entity.font
	verts: [4]Ren_Vertex_Base
	indices: [6]u32

  p := 0.5 * font.height_px
  TL := Vec3{ -p, p, 0, }
  TR := Vec3{  p, p, 0, }
  BL := Vec3{ -p,-p, 0, }
  BR := Vec3{  p,-p, 0, }

	@static print_once: bool = false
	text_cursor: [2]f32
	quad_pos: Vec3
	for byte, glyph_index in entity.text { // TODO: utf8 parse to runes
		chardata_index := i32(byte - 32)
		quad: stbtt.aligned_quad
		stbtt.GetPackedQuad(raw_data(font.data),
			cast(i32) globals.assets.font_atlas.width,
			cast(i32) globals.assets.font_atlas.height,
			chardata_index,
			&text_cursor.x,
			&text_cursor.y,
			&quad,
			false)
		if !print_once {
			log.infof("%v: %v", rune(chardata_index), quad)
		}
		quad_pos.x += 26

		// now with info make quads
		globals.immediate_glyph_staging[glyph_index] = {
			model_transform = linalg.matrix4_translate(entity.position + quad_pos) *
												linalg.matrix4_from_euler_angles_xyz_f32(entity.rotation.x, 
												                                         entity.rotation.y, 
												                                         entity.rotation.z) *
												linalg.matrix4_scale(entity.scale),
			uv_transform = {
				quad.s0,
				quad.t0,
				quad.s1 - quad.s0,
				quad.t1 - quad.t0,
			},
			color = { 1, 1, 1, 1 }
		}
		gl.BindBuffer(.ARRAY_BUFFER, globals.immediate_glyph_buffer)
		gl.BufferSubData(.ARRAY_BUFFER, 0, globals.immediate_glyph_staging[:])

		// verts[0] = { position = TL, texcoord = { 0,0 } }
		// verts[1] = { position = TR, texcoord = { 1,0 } }
		// verts[2] = { position = BL, texcoord = { 0,1 } }
		// verts[3] = { position = BR, texcoord = { 1,1 } }
		verts[0] = { position = TL, texcoord = { 0,1 } }
		verts[1] = { position = TR, texcoord = { 1,1 } }
		verts[2] = { position = BL, texcoord = { 0,0 } }
		verts[3] = { position = BR, texcoord = { 1,0 } }

		indices[0] = u32(0) // TL
		indices[1] = u32(2) // BL
		indices[2] = u32(1) // TR
		indices[3] = u32(3) // BR
		indices[4] = u32(1) // TR
		indices[5] = u32(2) // BL
	}
	print_once = true
	entity.draw_command = ren_make_image_draw_cmd(globals.immediate_glyph_buffer, 0, verts[:], indices[:])
	asset := entity.draw_command // asset for font?

	//////////////////////////////////////////////////////////////////////	
	instance_index := cast(int) entity.id
	// TODO upload instance data
	if ren.prev_cmd.program != asset.program {
		ren.prev_cmd.program = asset.program
		gl.UseProgram(ren.prev_cmd.program)
	}
	if ren.prev_cmd.VAO != asset.VAO {
		ren.prev_cmd.VAO = asset.VAO
		gl.BindVertexArray(ren.prev_cmd.VAO)
	}
	gl.DrawElementsInstanced(
		ren_mode_to_primitive(asset.mode),
		count  = asset.index_count,
		type   = .UNSIGNED_INT,
		offset = 0,
		instance_count = len(entity.text)
	)
	// The above section is pretty much going to be in every draw proc.
	//////////////////////////////////////////////////////////////////////
}