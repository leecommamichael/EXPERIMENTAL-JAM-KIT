package main

import "base:runtime"
import "core:log"
import "core:c"
import "core:strings"
import "core:os/os2"
import "core:image"
import "core:mem"
import "core:encoding/cbor"
import stbrp "vendor:stb/rect_pack"
import stbtt "vendor:stb/truetype"
import stbi "vendor:stb/image"
import "core:image/tga"
import "core:image/png"
import aseprite "third-party/odin-aseprite"
import aseprite_utils "third-party/odin-aseprite/utils"

//////////////////////////////////////////////////////////////////////
// Interface
//////////////////////////////////////////////////////////////////////
Asset_Bundle :: struct {
	font_infos: map[string]stbtt.fontinfo,
	font_atlas: ^tga.Image,
	images: map[string]Image,
	sprites: map[string]Sprite,
}

//////////////////////////////////////////////////////////////////////
// Framework Integration Implementation
//////////////////////////////////////////////////////////////////////
// The framework uses #load to embed assets for web-support.
// While the program is running on desktop, use a desktop-specific
// file I/O procedure to overwrite the cache.

asset_init :: proc () {
	log_time("Asset Bundler")
	bundle := &globals.assets
	bundle.font_infos = make(map[string]stbtt.fontinfo)
	when ODIN_OS != .JS {
		bundle_fonts()
		bundle_textures()
	}
	load_bundled_fonts()
	log_time("Asset Bundler")
}

//////////////////////////////////////////////////////////////////////
// Implementation (1/2) Font Atlas                  (1 channel bitmap)
//////////////////////////////////////////////////////////////////////
Serialized_Atlas_Font :: struct {
	usage:       Font_Usage,
	variant:     Font_Variant,
	packed_char: []stbtt.packedchar,
}

asset_files: []runtime.Load_Directory_File = #load_directory("../assets")

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
	serialized_fonts := make([]Serialized_Atlas_Font, FONT_COUNT)
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
	img, img_err := tga.load_from_bytes(font_atlas_bytes) //{ .do_not_expand_grayscale, })
	log_time("decode_atlas_to_pixels")
	log.infof("Loaded image %s: %v", FONT_ATLAS_PATH, img)
	if img_err != nil {
		log.errorf("%v", img_err)
		assert(img_err == nil)
	}
	globals.assets.font_atlas = img
}

MAX_ATLAS_PIXELS :: 1 << 14 // 2^14th (Common Modern OpenGL MAX_TEXTURE_SIZE)
MAX_ATLAS_BYTES :: MAX_ATLAS_PIXELS * MAX_ATLAS_PIXELS // 268 MB
FONT_COUNT :: len(Font_Variant) * len(Font_Usage)
GLYPH_COUNT :: 95 // characters from beginning of ASCII table

bundle_fonts :: proc () {
	// Exists to store rects with with their font data
	// To defer rendering until all rects from all fonts are packed.
	Pack_Range :: struct {
		rects: []stbrp.Rect,
		range: stbtt.pack_range,
		font:  ^Font,
	}
	log_time("1. Gather Rects")
	atlas_size: [2]int
	pack_ctx: stbtt.pack_context
	atlas_bytes := make([]u8, MAX_ATLAS_BYTES)
	pack_ranges := make([]Pack_Range, FONT_COUNT)
	rects := make([]stbrp.Rect, GLYPH_COUNT * FONT_COUNT)
	raw_rects := raw_data(rects)
	stbtt.PackBegin(&pack_ctx, raw_data(atlas_bytes), MAX_ATLAS_PIXELS, MAX_ATLAS_PIXELS, MAX_ATLAS_PIXELS, 1, nil)
	stbtt.PackSetOversampling(&pack_ctx, 3, 3)
	total_rects: c.int = 0
	font_index: int = 0
	for font_file in asset_files {
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
			ok := load_ttf(font_file.name, font_file.data, font)
			if !ok {
				log.errorf("Font parsing failed. %v", font_file.name)
				continue
			} // else continue to add font to atlas
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
			set_font_height(font, height_px)
			font.data = make([]stbtt.packedchar, GLYPH_COUNT)
			range := stbtt.pack_range {
				font_size = height_px,
				first_unicode_codepoint_in_range = 32, // a
				num_chars = GLYPH_COUNT,
				chardata_for_range = raw_data(font.data)
			}
			rects_so_far := total_rects
			range_rects := rects[rects_so_far:rects_so_far+GLYPH_COUNT]
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
		log.errorf("STBI failed to write the font atlas.")
	}
	delete(pack_ranges)
	delete(rects)
	log_time("write_atlas_metadata")
	serialized_fonts := make([]Serialized_Atlas_Font, FONT_COUNT)
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

//////////////////////////////////////////////////////////////////////
// Implementation (2/2) Texture Atlas                (4 channel image)
//////////////////////////////////////////////////////////////////////
MAX_TEXTURE_ATLAS_BYTES :: 4 * MAX_ATLAS_PIXELS * MAX_ATLAS_PIXELS // 1074 MB
TEXTURE_ATLAS_METADATA :: "./texture_atlas_metadata.cbor"
TEXTURE_ATLAS_PATH :: "./texture_atlas.tga"
bundle_textures :: proc () {
// I need to iterate over these and render from them.
	Aseprite_Animation :: struct {
		name: string,
		document:  aseprite.Document,
		tag:       Maybe(aseprite_utils.Tag),
		animation: aseprite_utils.Animation,
	}
	Aseprite_Image :: struct {
		name: string,
		document: aseprite.Document,
		image:    aseprite_utils.Image,
	}
	PNG_Image :: struct {
		name: string,
		image: ^png.Image
	}
	Packable_Rect :: union {
		PNG_Image,
		Aseprite_Image,
		Aseprite_Animation,
	}
	log_time("Texture Bundler")
// 1. Gather Rects ///////////////////////////////////////////////////////////////////////
	num_rects: i32 = 0
	packable_rects := make([dynamic]Packable_Rect)
	for file in asset_files {
		switch {
		case strings.ends_with(file.name, ".png"): 
			img, img_err := png.load_from_bytes(file.data, { .alpha_premultiply })
			log.infof("Loaded image %s: %v", FONT_ATLAS_PATH, img)
			if img_err != nil {
				log.errorf("Failed to load %s as a PNG. %v",
					file.name, img_err)
				continue
			}
			append(&packable_rects, PNG_Image{file.name, img})
		// If there are tags, only frames in tags will be saved.
		case strings.ends_with(file.name, ".aseprite"): fallthrough
		case strings.ends_with(file.name, ".ase"):
			ase_doc: aseprite.Document
			error_unmarshalling := aseprite.unmarshal_from_slice(&ase_doc, file.data)
			if error_unmarshalling != nil {
				log.errorf("Failed to unmarshal %s as an aseprite file. %v",
					file.name, error_unmarshalling)
				continue
			}

			ase_info, error_getting_info := aseprite_utils.get_info(&ase_doc)
			if error_getting_info != nil {
				log.errorf("Failed to get_info from %s after unmarshalling. %v",
					file.name, error_getting_info)
				continue
			}

			// Build either an image, one animation, or many animations.
			// Progressively stream animation data into the atlas metadata.
			if len(ase_info.frames) > 1 {
				if len(ase_info.tags) >= 1 {
					// Take only the frames which reside in tags.
					for tag in ase_info.tags {
						// Tag :: struct {
						//     from:      int,
						//     to:        int,
						//     direction: ase.Tag_Loop_Dir,
						//     name:      string,
						// }
						//
						// Animation :: struct {
						//     using md: Metadata,
						//     fps:      int,
						//     length:   time.Duration, 
						//     frames:   []Pixels, 
						// }
						animation: aseprite_utils.Animation
						err := aseprite_utils.get_animation_from_frames(ase_info, &animation, tag.name)
						aseprite_ok(file.name, err) or_continue
						append(&packable_rects, Aseprite_Animation{file.name, ase_doc, tag, animation})
					}
				} else {
					// No tags, but multiple frames. Take all frames.
					animation: aseprite_utils.Animation
					err := aseprite_utils.get_animation_from_doc(&ase_doc, &animation)
					aseprite_ok(file.name, err) or_continue
					append(&packable_rects, Aseprite_Animation{file.name, ase_doc, nil, animation})
				}
			} else {
				// Consider it an image. Take first frame.
				img, error_making_first_frame := aseprite_utils.get_image_from_doc(&ase_doc)
				aseprite_ok(file.name, error_making_first_frame) or_continue
				append(&packable_rects, Aseprite_Image{file.name, ase_doc, img})
			}
		}
		// At this point we've got a rect from those procedures.
		// The rect ID is the location in the array.
	}
// 2. Pack & Render //////////////////////////////////////////////////////////////////////
	n_chan :: 4 // it's the job of the program to expand to 4 (and premult alpha) by now.
	pad_px :: 1 // pixels
	num_rects = cast(i32) len(packable_rects)
	rects := make([]stbrp.Rect, num_rects)
	for packable_union, i in packable_rects {
		w,h: i32
		switch asset in packable_union {
		case PNG_Image:
			w = cast(i32) asset.image.width
			h = cast(i32) asset.image.height
		case Aseprite_Image:
			w = cast(i32) asset.document.header.width
			h = cast(i32) asset.document.header.height
		case Aseprite_Animation:
			w = cast(i32) asset.document.header.width
			h = cast(i32) asset.document.header.height
		}
		rects[i] = stbrp.Rect {
			id=i32(i),
			w=stbrp.Coord(w + (2*pad_px)),
			h=stbrp.Coord(h + (2*pad_px)),
		}
	}
	atlas_rgba := make([]u8, MAX_TEXTURE_ATLAS_BYTES)
	nodes := make([]stbrp.Node, num_rects)
	ctx: stbrp.Context
	stbrp.init_target(&ctx, MAX_ATLAS_PIXELS, MAX_ATLAS_PIXELS, raw_data(nodes), i32(len(nodes)))
	stbrp.pack_rects(&ctx, raw_data(rects), num_rects)
	delete(nodes)
	size: [2]i32
	for stb_rect in rects {
assert(stb_rect.was_packed == true)
		x2 := i32(stb_rect.x + stb_rect.w)
		if x2 > size.x { size.x = x2 }
		y2 := i32(stb_rect.y + stb_rect.h)
		if y2 > size.y { size.y = y2 }
assert(size.x > 0 && size.y > 0)
		packable_rect := packable_rects[stb_rect.id]
		atlas_stride := n_chan*MAX_ATLAS_PIXELS
		px_line_of_write := (int(stb_rect.y) + pad_px)
		px_offset_into_line := (int(stb_rect.x) + pad_px)
		atlas_subrect_topleft := (atlas_stride*px_line_of_write) + (n_chan*px_offset_into_line)
		switch asset in packable_rect {
		case PNG_Image:
assert(asset.image.channels == n_chan)
assert(asset.image.pixels.off == 0)
		case Aseprite_Image:
		asset_channels := 4 // TODO: find a way to write read this from the file.
		log.info(asset.name)
		asset_stride := asset_channels * size_of(u8) * (int(asset.document.header.width))
		for row in 0..< int(asset.document.header.height) {
			src_start := (row * asset_stride)
			src_end := src_start + asset_stride
			copy(atlas_rgba[atlas_subrect_topleft + (row*atlas_stride):],
			     asset.image.data[src_start: src_end])
		}
		case Aseprite_Animation:
			// asset_channels := 4 // TODO: find a way to write read this from the file.
			// log.info(asset.name)
			// for frame in asset.animation.frames {
			// 	asset_stride := asset_channels * size_of(u8) * (int(asset.document.header.width))
			// 	for row in 0..< int(asset.document.header.height) {
			// 		src_start := (row * asset_stride)
			// 		src_end := src_start + asset_stride
			// 		copy(atlas_rgba[atlas_subrect_topleft + (row*atlas_stride):],
			// 		     frame.pixels[src_start: src_end])
			// 	}
			// }
		}
	}
	log.infof("texture atlas size: %v", size)
	log_time("write_texture_atlas_to_disk")
	ok := cast(b32) stbi.write_tga(
		TEXTURE_ATLAS_PATH,
		w=cast(i32)MAX_ATLAS_PIXELS,
		h=cast(i32)size.y,
		comp=4,
		data=raw_data(atlas_rgba))
	log_time("write_texture_atlas_to_disk")
	if !ok {
		log.errorf("STBI failed to write the RGBA atlas.")
	}

	log_time("Texture Bundler")
}

@(private="file")
aseprite_ok :: #force_inline proc (
	filename: string,
	err: aseprite_utils.Errors,
	location := #caller_location
) -> bool {
	if err != nil {
		log.errorf("Failed to make image from %s. %v", filename, err, location = location)
		return false
	}
	return true
}

// TODO: 
load_textures :: proc () {
}
	// #load Textureatlas
	// #load Textureatlasmetadata
	// cbor unmarshal meta
	// treat atlas as png (but tga was better?) (but no premult alpha)
	//
	// unpack into types I actually care to use.
	// No reason those types can't be the app types, either.

// Diagnostic :: struct {
// layer
// issue
// resolution
// rationale | nil
// }
