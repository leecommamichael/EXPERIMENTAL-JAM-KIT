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
// The framework uses #load to embed assets for web-support.
//
// TODO:
// That's already going to take some time, so to keep the burden low,
// #load _baked_ font bitmaps. While the program is running on desktop,
// use a desktop-specific file I/O procedure to overwrite the cache.
asset_files: []runtime.Load_Directory_File = #load_directory("../assets")

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
	ren_draw_entity(globals.ren, entity)
	free_entity(entity)
}

// Use this to scale a font in-place.
scale_font :: bake_font

//////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////

font_from_ttf :: proc (
	name: string,
	file_bytes: []byte,
	height_px: f32,
	out_font: ^Font,
) -> (ok: bool) {
	out_font.name = name
	out_font.file_bytes = file_bytes
	ok = cast(bool) stbtt.InitFont(&out_font.info, raw_data(file_bytes), offset = 0)
	bake_font(out_font, height_px)
	return
}

// Bakes the bitmap and scales metrics.
// Call this on a font to re-scale it.
bake_font :: proc (font: ^Font, new_height_px: f32) {
  scale: f32 = stbtt.ScaleForPixelHeight(&font.info, new_height_px);

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

  stbtt.BakeFontBitmap(
  	&font.file_bytes[0],  offset=0,
    pixel_height = new_height_px,
    pixels = &font.bitmap[0],  pw=512,  ph=512,
    first_char=32,  num_chars=96,
    chardata = &font.baked_chars[0]) // no guarantee font fits!
}

//////////////////////////////////////////////////////////////////////
// Framework Integration Implementation
//////////////////////////////////////////////////////////////////////
import "core:strings"

// TODO: Introduce a stbtt.font_info cache so it doesn't parse the file so much.
ren_text_init :: proc () {
	for asset_file in asset_files {
		splits := strings.split(asset_file.name, "-")
		if len(splits) > 1 {
			variant_name := splits[1]
			variant: Font_Variant
			switch variant_name {
			case "Bold.ttf"      : variant = .bold
			case "BoldItalic.ttf": variant = .bold_italic
			case "Italic.ttf"    : variant = .italic
			case "Regular.ttf"   : variant = .regular
			case:
				log.debugf("FYI: Unrecognized Font_Variant (not loaded) %v", asset_file.name)
				continue
			}

			sans_font :: "Cousine"
			mono_font :: "Inter"
			sans_usages: []Font_Usage : { .caption, .body, . body_large, .header }
			mono_usages: []Font_Usage : { .mono }
			font_name := splits[0]
			usages: []Font_Usage
			if font_name == sans_font {
				usages = sans_usages
			} else if font_name == mono_font {
				usages = mono_usages
			} else {
				log.debugf("FYI: Unrecognized Font (not loaded) %v", asset_file.name)
				continue
			}
			height_px_for_usage: [Font_Usage]f32 = {
				.caption     = 10,
				.body        = 12,
				.body_large  = 16,
				.header      = 20,
				.mono        = 12,
			}
			for usage in usages {
				height_px := height_px_for_usage[usage]
				font_from_ttf(font_name, asset_file.data, height_px, &globals.fonts[usage][variant])
				log.debugf(" OK: Loaded Font %v", asset_file.name)
			}
		}
	}
}

