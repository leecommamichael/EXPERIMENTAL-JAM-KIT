package main

import "base:runtime"
import "core:log"
import "core:c"
import "core:strings"
import "core:os/os2"
import "core:image"
import "core:encoding/cbor"
import stbrp "vendor:stb/rect_pack"
import stbtt "vendor:stb/truetype"
import stbi "vendor:stb/image"
import "core:image/tga"
// The framework uses #load to embed assets for web-support.
//
// TODO:
// That's already going to take some time, so to keep the burden low,
// #load _baked_ font bitmaps. While the program is running on desktop,
// use a desktop-specific file I/O procedure to overwrite the cache.
font_files: []runtime.Load_Directory_File = #load_directory("../assets")

MAX_ATLAS_PIXELS :: 1 << 14 // 2^14th (Common Modern OpenGL MAX_TEXTURE_SIZE)
MAX_ATLAS_BYTES :: MAX_ATLAS_PIXELS * MAX_ATLAS_PIXELS // 268 MB

Asset_Bundle :: struct {
	font_infos: map[string]stbtt.fontinfo,
	font_atlas: ^tga.Image
}

asset_init :: proc () {
	log_time("Asset Bundler")
	bundle := &globals.assets
	bundle.font_infos = make(map[string]stbtt.fontinfo)
	when ODIN_OS != .JS {
		bundle_fonts()
	}
	load_bundled_fonts() // TODO store and load chardata.
	log_time("Asset Bundler")
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

Pack_Range :: struct {
	rects: []stbrp.Rect,
	range: stbtt.pack_range,
	font:  ^Font,
}

num_fonts :: len(Font_Variant) * len(Font_Usage)
pack_chars :: 95 // ASCII table

bundle_fonts :: proc () {
	log_time("1. Gather Rects")
	atlas_size: [2]int
	pack_ctx: stbtt.pack_context
	atlas_bytes := make([]u8, MAX_ATLAS_BYTES)
	pack_ranges := make([]Pack_Range, num_fonts)
	rects := make([]stbrp.Rect, pack_chars * num_fonts)
	raw_rects := raw_data(rects)
	stbtt.PackBegin(&pack_ctx, raw_data(atlas_bytes), MAX_ATLAS_PIXELS, MAX_ATLAS_PIXELS, MAX_ATLAS_PIXELS, 1, nil)
	stbtt.PackSetOversampling(&pack_ctx, 3, 3)
	total_rects: c.int = 0
	font_index: int = 0
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
			.caption     = 64,
			.body        = 64,
			.body_large  = 64,
			.header      = 64,
			.mono        = 64,
		}

		//////////////////////////////////////////////////////////////////////	
		variant: Font_Variant
		switch variant_name {
		case "Bold.ttf"      : variant = .bold
		case "BoldItalic.ttf": variant = .bold_italic
		case "Italic.ttf"    : variant = .italic
		case "Regular.ttf"   : variant = .regular
		case:
			log.warnf("FYI: Unrecognized Font_Variant (not loaded) %v", font_file.name)
			continue
		}

		//////////////////////////////////////////////////////////////////////	
		// Load and Pack Fonts ///////////////////////////////////////////////	
		for usage in usages {
			height_px := height_px_for_usage[usage]
			font: ^Font = &globals.fonts[usage][variant]
			ok := load_ttf(font_file.name, font_file.data, font)
			if !ok {
				log.errorf("Font parsing failed. %v", font_file.name)
				continue
			} // else continue to add font to atlas
			set_font_height(font, height_px)
			font.data = make([]stbtt.packedchar, pack_chars)
			range := stbtt.pack_range {
				font_size = height_px,
				first_unicode_codepoint_in_range = 32, // a
				num_chars = pack_chars,
				chardata_for_range = raw_data(font.data)
			}
			rects_so_far := total_rects
			range_rects := rects[rects_so_far:rects_so_far+pack_chars]
			num_rects := stbtt.PackFontRangesGatherRects(&pack_ctx, &font.info, &range, 1, raw_data(range_rects))
			pack_ranges[font_index] = Pack_Range {
				range_rects,
				range,
				font,
			}
			total_rects += num_rects
			font_index += 1
			if num_rects < 1 {
				log.warnf("GatherRects found no rects in font: %v", font_file.name)
				continue
			}
		} // for usage
	} // for file
	log_time("1. Gather Rects")

	log_time("2. Pack Rects")
	stbtt.PackFontRangesPackRects(&pack_ctx, raw_data(rects), total_rects)
	log_time("2. Pack Rects")
	log_time("3. Render Into Rects")
	for &pack_range in pack_ranges {
		ok := cast(bool) stbtt.PackFontRangesRenderIntoRects(
			&pack_ctx,
			&pack_range.font.info,
			&pack_range.range, 1,
			raw_data(pack_range.rects))
		if !ok {
			log.errorf("Font rasterizing failed.")
			continue
		} // else continue to adjust atlas dimensions 
	}
	log_time("3. Render Into Rects")

	for r in rects {
		x := cast(int) r.x + cast(int) r.w
		y := cast(int) r.y + cast(int) r.h
		if x > atlas_size.x {
			atlas_size.x = x
		}
		if y > atlas_size.y {
			atlas_size.y = y
		}
	} // for rect
	log_time("4. Resize Atlas")
	cropped_atlas_bytes := make([]u8, MAX_ATLAS_PIXELS*atlas_size.y)
	copy(cropped_atlas_bytes, atlas_bytes[0:MAX_ATLAS_PIXELS*atlas_size.y])
	log_time("4. Resize Atlas")
	delete(atlas_bytes)
	log.debugf("FYI: Atlas Size = %v", atlas_size)
	stbtt.PackEnd(&pack_ctx)

	log_time("write_atlas_to_disk")
	ok := cast(b32) stbi.write_tga(
		FONT_ATLAS_PATH,
		w=cast(i32)MAX_ATLAS_PIXELS,
		h=cast(i32)atlas_size.y,
		comp=1,
		data=raw_data(cropped_atlas_bytes))
	log_time("write_atlas_to_disk")
	if !ok {
		log.errorf("STBI failed to write PNG")
	}
	delete(pack_ranges)
	delete(rects)
	log_time("write_atlas_metadata")
	serialized_fonts := make([]Serialized_Atlas_Font, num_fonts)
	i: int
	for usage in Font_Usage {
		for variant in Font_Variant {
			font := globals.fonts[usage][variant]

			serialized_font: Serialized_Atlas_Font = {
				usage = usage,
				variant = variant,
				packed_char = font.data,
			}
			serialized_fonts[i] = serialized_font
			i += 1
		}
	}
	file, err := os2.open(FONT_ATLAS_METADATA, {.Read, .Trunc, .Create})
	defer os2.close(file)
	assert(err == nil)
	writer := os2.to_writer(file)
	cbor.marshal_into_writer(writer, serialized_fonts)
	log_time("write_atlas_metadata")
	delete(serialized_fonts)
	delete(cropped_atlas_bytes)
}

Serialized_Atlas_Font :: struct {
	usage:       Font_Usage,
	variant:     Font_Variant,
	packed_char: []stbtt.packedchar,
}

FONT_ATLAS_METADATA :: "./font_atlas_metadata.cbor"
FONT_ATLAS_PATH :: "./font_atlas.tga"

load_bundled_fonts :: proc () {
	log_time("read_atlas_metadata_from_disk")
	metadata_file, err_opening_metadata_file := os2.open(FONT_ATLAS_METADATA, {.Read})
	if err_opening_metadata_file != nil {
		log.errorf("%v", err_opening_metadata_file)
		assert(false)
	}
	metadata_reader := os2.to_reader(metadata_file)
	serialized_fonts := make([]Serialized_Atlas_Font, num_fonts)
	unmarshal_error := cbor.unmarshal_from_reader(metadata_reader, &serialized_fonts)
	for font in serialized_fonts {
		globals.fonts[font.usage][font.variant].data = font.packed_char
	}
	assert(unmarshal_error == nil)
	log_time("read_atlas_metadata_from_disk")

	log_time("read_atlas_from_disk")
	font_atlas_bytes, err := os2.read_entire_file_from_path(FONT_ATLAS_PATH, context.allocator)
	log_time("read_atlas_from_disk")
	assert(err == nil)
	log_time("decode_atlas_to_pixels")
	img, img_err := tga.load_from_bytes(font_atlas_bytes, { .do_not_expand_grayscale })
	log_time("decode_atlas_to_pixels")
	log.infof("Loaded image %s: %v", FONT_ATLAS_PATH, img)
	if img_err != nil {
		log.errorf("%v", img_err)
		assert(img_err == nil)
	}
	globals.assets.font_atlas = img
}
