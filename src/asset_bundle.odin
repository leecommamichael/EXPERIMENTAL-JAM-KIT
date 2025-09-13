package main

import "base:runtime"
import "core:log"
import "core:c"
import "core:slice"
import "core:strings"
import "core:os/os2"
import "core:image"
import "core:mem"
import "core:time"
import "core:fmt"
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
	stbtt.PackBegin(
		spc = &pack_ctx,
		pixels = raw_data(atlas_bytes),
		width = MAX_ATLAS_PIXELS,
		height = MAX_ATLAS_PIXELS,
		stride_in_bytes = MAX_ATLAS_PIXELS,
		padding = 1,
		alloc_context = nil)
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
	rect_id :: #force_inline proc (filename: string, frame_index:int) -> string {
		return fmt.tprintf("%s_frame%d", filename, frame_index)
	}

	Image_With_Pixels :: struct {
		using _: Image,
		pixels: []u8 `cbor:"-" fmt:"-"`,
	}
	Sprite_With_Pixels :: struct {
		using _: Sprite,
		pixels: [][]u8 `cbor:"-" fmt:"-"`,
	}
	Packable_Asset :: union {
		Image_With_Pixels,
		Sprite_With_Pixels,
	}

	log_time("Texture Bundler")
// 1. Gather Rects ///////////////////////////////////////////////////////////////////////
	pack_list := make([dynamic]Packable_Asset)
	for file in asset_files {
		switch {
		case strings.ends_with(file.name, ".png"):
			log.infof("png IMAGE: %s", file.name)
			img, img_err := png.load_from_bytes(file.data, { .alpha_premultiply })
			log.infof("Loaded image %s: %v", FONT_ATLAS_PATH, img)
			if img_err != nil {
				log.errorf("Failed to load %s as a PNG. %v",
					file.name, img_err)
				continue
			}
			append(&pack_list, Image_With_Pixels{
				Image{file.name, {img.width, img.height}, {}, 0, 0},
				img.pixels.buf[:]
			})
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
					log.infof("ase TAGGED_ANIMATIONS(%d): %s", len(ase_info.tags), file.name)
					sprite := Sprite_With_Pixels {
						Sprite{
							file.name,
							{ ase_info.md.width, ase_info.md.height },
							make([]Sprite_Animation_Frame, len(ase_info.frames)),
							{}, 
						},
						make([][]u8, len(ase_info.frames)),
					}
					for frame, i in ase_info.frames {
						img, err := aseprite_utils.get_image_bytes_from_frame(frame, ase_info)
						aseprite_ok(file.name, err) or_continue
						sprite.pixels[i] = img
						sprite.frames[i] = {
							{},
							f64(frame.duration) / 1000,
						}
					}
					for tag in ase_info.tags {
						animation: Sprite_Animation = {
							name = tag.name,
							first_frame_index = tag.from,
							final_frame_index = tag.to,
							frame_count = tag.to - tag.from,
							playback_mode = cast(Animation_Playback_Mode) tag.direction, // TODO: robustness: enum mapping function
						}
						sprite.animations[animation.name] = animation
					}
					append(&pack_list, sprite)
				} else {
					// No tags, but multiple frames. Take all frames.
					log.infof("ase INFER_ANIMATION(%d): %s", len(ase_info.frames), file.name)
					sprite := Sprite_With_Pixels {
						Sprite{
							file.name,
							{ ase_info.md.width, ase_info.md.height },
							make([]Sprite_Animation_Frame, len(ase_info.frames)),
							{}, 
						},
						make([][]u8, len(ase_info.frames)),
					}
					for frame, i in ase_info.frames {
						img, err := aseprite_utils.get_image_bytes_from_frame(frame, ase_info)
						aseprite_ok(file.name, err) or_continue
						sprite.pixels[i] = img
						sprite.frames[i] = {
							{},
							f64(frame.duration) / 1000
						}
					}
					animation := Sprite_Animation { // principle difference between this and the above
						name = "default",
						first_frame_index = 0,
						final_frame_index = len(ase_info.frames)-1,
						frame_count = len(ase_info.frames),
						playback_mode = .Forward,
					}
					sprite.animations[animation.name] = animation
					append(&pack_list, sprite)
				}
			} else {
				// Consider it an image. Take first frame.
				log.infof("ase IMAGE: %s", file.name)
				img, error_making_first_frame := aseprite_utils.get_image_from_doc(&ase_doc)
				aseprite_ok(file.name, error_making_first_frame) or_continue
				append(&pack_list, 
					Image_With_Pixels{Image{file.name, {img.width, img.height}, {}, 0, 0},
					img.data
				})
			}
		}
	}

// 2. Pack & Render //////////////////////////////////////////////////////////////////////
	n_chan :: 4 // it's the job of the program to expand to 4 (and premult alpha) by now.
	pad_px :: 1 // pixels
	rects := make([dynamic]stbrp.Rect)
	for packable_union, i in pack_list {
		assert(i <= cast(int) max(i16))
		id := [2]i16 { cast(i16)i, -1 } // if -1 use index naively
		switch asset in packable_union {
		case Image_With_Pixels:
			size_px := asset.size_in_pixels
			append(&rects, stbrp.Rect {
				id = transmute(i32) id,
				w  = stbrp.Coord(size_px.x + (2*pad_px)),
				h  = stbrp.Coord(size_px.y + (2*pad_px)),
			})
		case Sprite_With_Pixels:
			size_px := asset.size_px
			for frame, frame_index in asset.frames {
				id.y = cast(i16) frame_index
				append(&rects, stbrp.Rect {
					id = transmute(i32) id,
					w  = stbrp.Coord(size_px.x + (2*pad_px)),
					h  = stbrp.Coord(size_px.y + (2*pad_px)),
				})
			}
		}
	}
	num_rects := len(rects)
	atlas_rgba := make([]u8, MAX_TEXTURE_ATLAS_BYTES)
	nodes := make([]stbrp.Node, num_rects)
	ctx: stbrp.Context
	stbrp.init_target(&ctx, MAX_ATLAS_PIXELS, MAX_ATLAS_PIXELS, raw_data(nodes), i32(len(nodes)))
	stbrp.pack_rects(&ctx, raw_data(rects), cast(i32) num_rects)
	delete(nodes)
	size: [2]i32
	for stb_rect in rects {
assert(stb_rect.was_packed == true)
		x2 := i32(stb_rect.x + stb_rect.w)
		if x2 > size.x { size.x = x2 }
		y2 := i32(stb_rect.y + stb_rect.h)
		if y2 > size.y { size.y = y2 }
assert(size.x > 0 && size.y > 0)
		atlas_stride := n_chan*MAX_ATLAS_PIXELS
		px_line_of_write := (int(stb_rect.y) + pad_px)
		px_offset_into_line := (int(stb_rect.x) + pad_px)
		atlas_subrect_topleft := (atlas_stride*px_line_of_write) + (n_chan*px_offset_into_line)
		id := transmute([2]i16) stb_rect.id
		packable_asset := pack_list[id.x]
		frame_index := id.y
		asset_channels :: 4 // TODO: find a way to ensure this.
		switch asset in packable_asset {
		case Image_With_Pixels:
			asset_stride := asset_channels * size_of(u8) * asset.size_in_pixels.x
			for row in 0..< asset.size_in_pixels.y {
				src_start := (row * asset_stride)
				src_end := src_start + asset_stride
				copy(atlas_rgba[atlas_subrect_topleft + (row*atlas_stride):],
				     asset.pixels[src_start: src_end])
			}
		case Sprite_With_Pixels:
			asset_stride := asset_channels * size_of(u8) * asset.size_px.x
			for row in 0..< asset.size_px.y {
				src_start := (row * asset_stride)
				src_end := src_start + asset_stride
				copy(atlas_rgba[atlas_subrect_topleft + (row*atlas_stride):],
				     asset.pixels[frame_index][src_start: src_end])
			}
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
