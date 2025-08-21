package main

import "base:runtime"
import "core:log"
import "core:strings"
import "core:os/os2"
import "core:image/png"
import stbrp "vendor:stb/rect_pack"
import stbtt "vendor:stb/truetype"
import stbi "vendor:stb/image"
// The framework uses #load to embed assets for web-support.
//
// TODO:
// That's already going to take some time, so to keep the burden low,
// #load _baked_ font bitmaps. While the program is running on desktop,
// use a desktop-specific file I/O procedure to overwrite the cache.
font_files: []runtime.Load_Directory_File = #load_directory("../assets")

MAX_ATLAS_SIZE :: 1 << 14 // 2^14th (Common Modern OpenGL MAX_TEXTURE_SIZE)
MAX_ATLAS_BYTES :: MAX_ATLAS_SIZE * MAX_ATLAS_SIZE // 268 MB

Asset_Bundle :: struct {
	font_infos: map[string]stbtt.fontinfo,
	font_atlas: []u8
}

asset_init :: proc () {
	bundle := &globals.assets
	bundle.font_infos = make(map[string]stbtt.fontinfo)
	when ODIN_OS != .JS {
		bundle_fonts()
	}
	load_bundled_fonts() // TODO store and load chardata.
}

load_ttf :: proc (
	name: string,
	file_bytes: []byte,
	out_font: ^Font,
) -> (ok: bool) {
	out_font.name = name
	out_font.file_bytes = file_bytes
	if name in globals.assets.font_infos {
		out_font.info = globals.assets.font_infos[name]
		return true
	} else { // It's not cached yet.
		ok = cast(bool) stbtt.InitFont(&out_font.info, raw_data(file_bytes), offset = 0)
		if ok {
			globals.assets.font_infos[name] = out_font.info
			log.debugf("FYI: Loaded Font %v", name)
		}
	}
	return
}

pack_chars :: 95

bundle_fonts :: proc () {
	atlas_size: [2]int
	pack_ctx: stbtt.pack_context
	atlas_bytes := make([]u8, MAX_ATLAS_BYTES)
	stbtt.PackBegin(&pack_ctx, raw_data(atlas_bytes), MAX_ATLAS_SIZE, MAX_ATLAS_SIZE, MAX_ATLAS_SIZE, 1, nil)
	for font_file in font_files {
		splits := strings.split(font_file.name, "-") // LEAK
		if len(splits) < 2 {
			continue; // File not likely a font.
		} // else continue to add font to atlas

		font_name := splits[0]
		variant_name := splits[1]
		//////////////////////////////////////////////////////////////////////	
		// Defining fonts for usages /////////////////////////////////////////	
		cousine :: "Cousine"
		inter :: "Inter"

		inter_usages: []Font_Usage : { .caption, .body, . body_large, .header }
		cousine_usages: []Font_Usage : { .mono }

		usages: []Font_Usage
		switch font_name {
		case inter:   usages = inter_usages
		case cousine: usages = cousine_usages
		case:
			log.debugf("FYI: Unrecognized Font (not loaded) %v", font_file.name)
			continue
		}
		height_px_for_usage: [Font_Usage]f32 = {
			.caption     = 10,
			.body        = 12,
			.body_large  = 16,
			.header      = 20,
			.mono        = 12,
		}

		//////////////////////////////////////////////////////////////////////	
		variant: Font_Variant
		switch variant_name {
		case "Bold.ttf"      : variant = .bold
		case "BoldItalic.ttf": variant = .bold_italic
		case "Italic.ttf"    : variant = .italic
		case "Regular.ttf"   : variant = .regular
		case:
			log.debugf("FYI: Unrecognized Font_Variant (not loaded) %v", font_file.name)
			continue
		}

		//////////////////////////////////////////////////////////////////////	
		// Load and Pack Fonts ///////////////////////////////////////////////	
		for usage in usages {
			height_px := height_px_for_usage[usage]
			font: ^Font = &globals.fonts[usage][variant]
			ok := load_ttf(font_file.name, font_file.data, font)
			font.height_px = height_px // TWO STEP INIT
			if !ok {
				log.warnf("Font parsing failed. %v", font_file.name)
				continue
			} // else continue to add font to atlas
			rects := make([]stbrp.Rect, pack_chars)
			defer delete(rects)
			rdata := raw_data(rects)
			font.data = make([]stbtt.packedchar, pack_chars)
			ranges := stbtt.pack_range {
				font_size = height_px,
				first_unicode_codepoint_in_range = 32, // a
				num_chars = pack_chars,
				chardata_for_range = raw_data(font.data)
			}
			num_rects := stbtt.PackFontRangesGatherRects(&pack_ctx, &font.info, &ranges, 2, rdata)
			stbtt.PackFontRangesPackRects(&pack_ctx, rdata, num_rects)
			ok = cast(bool) stbtt.PackFontRangesRenderIntoRects(&pack_ctx, &font.info, &ranges, 1, rdata)
			if !ok {
				log.warnf("Font rasterizing failed. %v", font_file.name)
				continue
			} // else continue to adjust atlas dimensions 

			for i in 0 ..< num_rects {
				r := rects[i]
				x := cast(int) r.x + cast(int) r.w
				y := cast(int) r.y + cast(int) r.h
				if x > atlas_size.x {
					atlas_size.x = x
				}
				if y > atlas_size.y {
					atlas_size.y = y
				}
			} // for rect
		} // for usage
	} // for file
	log.debugf("FYI: Atlas Size = %v", atlas_size)
	stbtt.PackEnd(&pack_ctx)
	stbi.write_png(FONT_ATLAS_PATH, i32(atlas_size.x), i32(atlas_size.y), 1, raw_data(atlas_bytes), MAX_ATLAS_SIZE)
}

FONT_ATLAS_PATH :: "./font_atlas.png"

load_bundled_fonts :: proc () {
	font_atlas_bytes, err := os2.read_entire_file_from_path(FONT_ATLAS_PATH, context.allocator)
	assert(err == nil)
	img, img_err := png.load_from_bytes(font_atlas_bytes)
	assert(img_err == nil)
	globals.assets.font_atlas = img.pixels.buf[:] // is dynamic
}
