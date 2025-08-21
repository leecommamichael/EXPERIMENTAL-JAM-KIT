package main

import "base:runtime"
import "core:log"
import "core:strings"
import "core:os/os2"
import stbrp "vendor:stb/rect_pack"
import stbtt "vendor:stb/truetype"
import stbi "vendor:stb/image"
// The framework uses #load to embed assets for web-support.
//
// TODO:
// That's already going to take some time, so to keep the burden low,
// #load _baked_ font bitmaps. While the program is running on desktop,
// use a desktop-specific file I/O procedure to overwrite the cache.
asset_files: []runtime.Load_Directory_File = #load_directory("../assets")

MAX_ATLAS_SIZE :: 1 << 14 // 2^14th (Common Modern OpenGL MAX_TEXTURE_SIZE)
MAX_ATLAS_BYTES :: MAX_ATLAS_SIZE * MAX_ATLAS_SIZE // 268 MB

Asset_Bundle :: struct {
	font_atlas: []u8,
	atlases: [][]u8
}

bundle_fonts :: proc () {
	max_extent: [2]int
	pack_ctx: stbtt.pack_context
	atlas_bytes := make([]u8, MAX_ATLAS_BYTES)
	stbtt.PackBegin(&pack_ctx, raw_data(atlas_bytes), MAX_ATLAS_SIZE, MAX_ATLAS_SIZE, MAX_ATLAS_SIZE, 1, nil)
	file_loop: for asset_file in asset_files {
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
				// font_from_ttf(font_name, asset_file.data, height_px, &globals.fonts[usage][variant])
				font: ^stbtt.fontinfo = &globals.fonts[usage][variant].info
				ok := stbtt.InitFont(font, raw_data(asset_file.data), 0)
				ensure(cast(bool)ok)
				num_chars :: 95
				rects := make([]stbrp.Rect, num_chars)
				rdata := raw_data(rects)
				chardata := make([]stbtt.packedchar, num_chars)
				ranges := stbtt.pack_range {
					font_size = height_px,
					first_unicode_codepoint_in_range = 32, // a
					num_chars = num_chars,
					chardata_for_range = raw_data(chardata)
				}
				num_rects := stbtt.PackFontRangesGatherRects(&pack_ctx, font, &ranges, 1, rdata)
				stbtt.PackFontRangesPackRects(&pack_ctx, rdata, num_rects)
				ok = cast(b32) stbtt.PackFontRangesRenderIntoRects(&pack_ctx, font, &ranges, 1, rdata)
				ensure(cast(bool)ok)
				for i in 0 ..< num_rects {
					r := rects[i]
					x := cast(int) r.x + cast(int) r.w
					y := cast(int) r.y + cast(int) r.h
					if x > max_extent.x {
						max_extent.x = x 
					}
					if y > max_extent.y {
						max_extent.y = y 
					}
				}
				delete(rects)
				log.debugf("FYI: Loaded Font %v", asset_file.name)
			}
		}
	}
	log.debugf("FYI: Max extent was %v", max_extent)
	stbtt.PackEnd(&pack_ctx)
	// file, err := os2.create("./bob.bmp")
	// ensure(err == nil)
	stbi.write_png("./font_atlas.png", i32(max_extent.x), i32(max_extent.y), 1, raw_data(atlas_bytes), MAX_ATLAS_SIZE)
	// _, err = os2.write(file, atlas_bytes)
	// ensure(err == nil)
}
