package main

import gl "nord_gl"
import stbtt "vendor:stb/truetype"
import "base:runtime"
import "core:fmt"
import "core:slice"
import "core:log"
import "core:c"

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
	ren_draw_text(globals.ren, entity)
	free_entity(entity)
}

//////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////

make_draw_call :: proc () {
	// asset := ren_make_basic_asset(globals.ren, v, i, globals.ren.instance_UBO)
}


// Bakes the bitmap and scales metrics.
// Call this on a font to re-scale it.
// bake_font :: proc (font: ^Font, new_height_px: f32) {
//   scale: f32 = stbtt.ScaleForPixelHeight(&font.info, new_height_px);

//   // Get the font's line height
//   ascent, descent, line_gap: f32;
//   stbtt.GetFontVMetrics(&font.info, cast(^c.int)&ascent, cast(^c.int)&descent, cast(^c.int)&line_gap);
//   font.ascent   = ascent  * scale;
//   font.descent  = descent * scale;
//   font.line_gap = line_gap * scale;
//   font.line_height = font.ascent - font.descent + font.line_gap;

//   // Get the monospace character width
//   _lsb, monospace_advance: f32;
//   stbtt.GetCodepointHMetrics(&font.info, ' ', cast(^c.int)&monospace_advance, cast(^c.int)&_lsb);
//   font.monospace_advance = monospace_advance * scale;

//   stbtt.BakeFontBitmap(
//   	&font.file_bytes[0],  offset=0,
//     pixel_height = new_height_px,
//     pixels = nil/*&font.bitmap[0]*/,  pw=512,  ph=512,
//     first_char=32,  num_chars=96,
//     chardata = &font.baked_chars[0]) // no guarantee font fits!
// }

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
	asset := entity._asset // asset for font?
	//////////////////////////////////////////////////////////////////////	
	instance_index := cast(int) entity._id
	gl.BindBufferRange(
		gl.UNIFORM_BUFFER,
		index  = INSTANCE_UNIFORM_INDEX,
		buffer = ren.instance_UBO,
		offset = instance_index * globals.instances.stride,
		size = size_of(Ren_Instance)
	)
	if ren.program != asset.program {
		ren.program = asset.program
		gl.UseProgram(ren.program)
	}
	if ren.VAO != asset.VAO {
		ren.VAO = asset.VAO
		gl.BindVertexArray(ren.VAO)
	}
	// The above is pretty much going to be in every draw proc.
	//////////////////////////////////////////////////////////////////////
	// text will be about instancing a quad all over with different textures.
	// gl.DrawElements(
	// 	ren_mode_to_primitive(asset.mode),
	// 	count  = asset.index_count,
	// 	type   = .UNSIGNED_INT,
	// 	indices = cast(uintptr) 0,
	// )
}