#+build !js
package main

import "base:runtime"
import "core:thread"
import "core:log"
import "core:c"
import "core:slice"
import "core:strings"
import "core:image"
import "core:mem"
import "core:time"
import "core:fmt"
import "core:bytes"
import "core:encoding/cbor"
import "core:os/os2"
import "core:image/qoi" // texture atlas
import "core:image/tga" // font atlas
import "core:image/png" // make bundle
import stbrp "vendor:stb/rect_pack"
import stbtt "vendor:stb/truetype"
import stbi "vendor:stb/image"
import stbv "vendor:stb/vorbis"
import aseprite "third-party/odin-aseprite"
import aseprite_utils "third-party/odin-aseprite/utils"
import gl "angle"
import "audio"

font_cache_exists :: proc () -> bool {
	return len(font_atlas_bytes) > 0\
	    && len(font_atlas_metadata_bytes) > 0
}

texture_cache_exists :: proc () -> bool {
	return len(texture_atlas_metadata) > 0\
	    && len(texture_atlas_bytes) > 0
}

audio_cache_exists :: proc () -> bool {
	return len(audio_metadata_bytes) > 0
}

desktop_load_binary_asset_cache :: proc () {
	if !font_cache_exists() {
		// SCENARIO: First startup, create a cache and read it.
		bundle_fonts(USE_BINARY_ASSET_CACHE)
		err: os2.Error
		font_atlas_bytes,          err = os2.read_entire_file(FONT_ATLAS_PATH, context.allocator)
	assert(err == nil)
		font_atlas_metadata_bytes, err = os2.read_entire_file(FONT_ATLAS_METADATA, context.allocator)
	assert(err == nil)
	}
	if !texture_cache_exists() {
		// SCENARIO: First startup, create a cache and read it.
		bundle_textures(USE_BINARY_ASSET_CACHE)
		err: os2.Error
		texture_atlas_bytes,    err = os2.read_entire_file(TEXTURE_ATLAS_PATH, context.allocator)
	assert(err == nil) // TODO: Occurs when no textures were packed.
		texture_atlas_metadata, err = os2.read_entire_file(TEXTURE_ATLAS_METADATA, context.allocator)
	assert(err == nil)
	}
	if !audio_cache_exists() {
		// SCENARIO: First startup, create a cache and read it.
		bundle_audio()
		err: os2.Error
		audio_metadata_bytes, err = os2.read_entire_file(AUDIO_METADATA, context.allocator)
	assert(err == nil)
	}
}

//////////////////////////////////////////////////////////////////////
// Implementation (1/2) Font Atlas                  (1 channel bitmap)
//////////////////////////////////////////////////////////////////////

bundle_fonts :: proc (use_binary: bool) {
log_time("render_font")
	// Exists to store rects with with their font data
	// To defer rendering until all rects from all fonts are packed.
	Pack_Range :: struct {
		rects: []stbrp.Rect,
		font:  ^Font,
		range: stbtt.pack_range,
		info:  stbtt.fontinfo,
	}
	atlas_size: [2]int
	pack_ctx: stbtt.pack_context
	atlas_bytes := make([]u8, MAX_ATLAS_BYTES)
	pack_ranges := make([dynamic]Pack_Range)
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
	font_files, dir_err := read_files_in_directory_with_suffix("../assets", "ttf")
	if dir_err != nil {
		log.errorf("failed to read fonts %v", dir_err)
		assert(dir_err == nil)
	}
	for font_file in font_files {
		splits := strings.split(font_file.name, "-") // LEAK
		if len(splits) < 2 {
			continue; // File not likely a font.
		} // else continue to add font to atlas

		font_name := splits[0]
		//////////////////////////////////////////////////////////////////////	
		// Defining fonts for usages /////////////////////////////////////////	
		cousine :: "Cousine"
		inter :: "Inter"
		fs_pixel :: "fs_pixel_sans_unicode"
		bold_pixels :: "BoldPixels"

		inter_usages:    []Font_Usage : { .caption, .body, . body_large, .header }
		cousine_usages:  []Font_Usage : { .mono }
		fs_pixel_usages: []Font_Usage : { .pixel }
		bold_pixels_usages: []Font_Usage : { .bold_pixel }

		usages: []Font_Usage
		switch font_name {
		case inter:       usages = inter_usages
		case cousine:     usages = cousine_usages
		case fs_pixel:    usages = fs_pixel_usages
		case bold_pixels: usages = bold_pixels_usages
		case:
			log.infof("FYI: Unrecognized Font (not loaded) %v", font_file.name)
			continue
		}
		height_px_for_usage: [Font_Usage]f32 = {
			.caption     = 10 * 1.5,
			.body        = 14 * 1.5,
			.body_large  = 18 * 1.5,
			.header      = 24 * 1.5,
			.mono        = 14 * 1.5,
			.bold_pixel  = 16, // unscaled (to be used with integer scaling)
			.pixel       = 16, // unscaled (to be used with integer scaling)
		}

		//////////////////////////////////////////////////////////////////////	
		variant_name := splits[1]
		variant: Font_Variant
		switch variant_name {
		case "Regular.ttf"   : variant = .regular
		case "Bold.ttf"      : variant = .bold
		case "BoldItalic.ttf": variant = .bold_italic
		case "Italic.ttf"    : variant = .italic
		case:
			log.warnf("FYI: Unrecognized Font_Variant (not loaded) %v", font_file.name)
			continue
		}

		//////////////////////////////////////////////////////////////////////	
		// Load and Pack Fonts ///////////////////////////////////////////////	
		for usage in usages {
			height_px := height_px_for_usage[usage]
			font: ^Font = &globals.fonts[usage][variant]

			ok, fontinfo := load_ttf(font_file.name, font_file.data, font)
			if !ok {
				log.errorf("Font parsing failed. %v", font_file.name)
				continue
			} // else continue to add font to atlas
			log.infof("font: %v %v %v", font.name, usage, variant)
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
			num_rects := stbtt.PackFontRangesGatherRects(&pack_ctx, &fontinfo, &range, 1, raw_data(range_rects))
			append(&pack_ranges, Pack_Range {
				range_rects,
				font,
				range,
				fontinfo,
			})
			total_rects += num_rects
			if num_rects < 1 {
				log.warnf("GatherRects found no rects in font: %v", font_file.name)
				continue
			}
			font.bundled = true
		} // for usage
	} // for file


	stbtt.PackFontRangesPackRects(&pack_ctx, raw_data(rects), total_rects)
	for &pack_range in pack_ranges {
		// assert(pack_range.rects != nil)
		ok := cast(bool) stbtt.PackFontRangesRenderIntoRects(
			&pack_ctx,
			&pack_range.info,
			&pack_range.range, 1,
			raw_data(pack_range.rects))
		if !ok {
			log.errorf("Font rasterizing failed.")
			continue
		} // else continue to adjust atlas dimensions 
	}

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
	cropped_atlas_bytes := make([]u8, MAX_ATLAS_PIXELS*atlas_size.y)
	copy(cropped_atlas_bytes, atlas_bytes[0:MAX_ATLAS_PIXELS*atlas_size.y])
	delete(atlas_bytes)
	delete(pack_ranges)
	delete(rects)
	log.infof("FYI: Atlas Size = %v", atlas_size)
	stbtt.PackEnd(&pack_ctx)
log_time("render_font")
log_time("write_font")
	if use_binary {
		err3 := os2.write_entire_file(FONT_ATLAS_PATH, cropped_atlas_bytes)
		assert(err3 == nil)
	} else {
		ok := cast(b32) stbi.write_tga(
			FONT_ATLAS_PATH,
			w=cast(i32)MAX_ATLAS_PIXELS,
			h=cast(i32)atlas_size.y,
			comp=1,
			data=raw_data(cropped_atlas_bytes))
		if !ok {
			log.errorf("STBI failed to write the font atlas.")
		}
	}
	delete(cropped_atlas_bytes)

	serialized_fonts := make([]Serialized_Atlas_Font, FONT_COUNT)
	i: int
	for usage in Font_Usage {
		for variant in Font_Variant {
			font := globals.fonts[usage][variant]
			if !font.bundled { continue }
			serialized_font: Serialized_Atlas_Font = {
				usage = usage,
				variant = variant,
				font = font,
			}
			serialized_fonts[i] = serialized_font
			i += 1
		}
	}
	file, err := os2.open(FONT_ATLAS_METADATA, {.Write, .Trunc, .Create})
	assert(err == nil)
	writer := os2.to_writer(file)
	merr := cbor.marshal_into_writer(writer, serialized_fonts)
	if merr != nil {
		log.errorf("Failed to write cbor. %v", merr)
		// import "core:sys/posix"
		// log.errorf("POSIX err is %v", posix.get_errno())
	}
	assert(merr == nil)
	os2.close(file)
	log.infof("FYI: Wrote %d fonts", len(serialized_fonts))
	delete(serialized_fonts)
	log_time("write_font")
}

//////////////////////////////////////////////////////////////////////
// Implementation (2/2) Texture Atlas                (4 channel image)
//////////////////////////////////////////////////////////////////////
MAX_TEXTURE_ATLAS_BYTES :: 4 * MAX_ATLAS_PIXELS * MAX_ATLAS_PIXELS // 1074 MB

bundle_textures :: proc (use_binary: bool) {
log_time("render_textures")
	// This is more leaning into the 
	Packable_Image :: struct {
		using image: Image_Asset,
		pixels:      []u8  `cbor:"-" fmt:"-"`,
	}
	Packable_Sprite :: struct {
		using sprite: Sprite_Asset,
		pixels:       [][]u8 `cbor:"-" fmt:"-"`,
	}
	Atlas_Entry :: union {
		Packable_Image,
		Packable_Sprite,
	}

// 1. Gather Packables ///////////////////////////////////////////////////////////////////
	pack_list := make([dynamic]Atlas_Entry)

	pngs, dir_err1 := read_files_in_directory_with_suffix("../assets", "png") 
assert(dir_err1 == nil)
	for file in pngs {
			log.infof("png IMAGE: %s", file.name)
			img, img_err := png.load_from_bytes(file.data, { .alpha_premultiply })
			log.infof("Loaded image %s: %v", FONT_ATLAS_PATH, img)
			if img_err != nil {
				log.errorf("Failed to load %s as a PNG. %v",
					file.name, img_err)
				continue
			}
			// To pack an image, I need its size, but the size is stored in the binding pointer.
			// The binding is a result of loading an image.
			// So it pack an image you've got to load it. Doesn't make the most sense.
			append(&pack_list, Packable_Image{
				Image_Asset{
					file.name,
					{},
					{img.width, img.height},
					nil},
				img.pixels.buf[:]
			})
	}

	aseprites, dir_err2 := read_files_in_directory_with_suffixes("../assets", {"ase", "aseprite"}) 
assert(dir_err2 == nil)
	for file in aseprites {
		// If there are tags, only frames in tags will be saved.
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
				sprite := Packable_Sprite {
					Sprite_Asset{
						file.name,
						make([]Sprite_Animation_Frame, len(ase_info.frames)),
						{},
					{ ase_info.md.width, ase_info.md.height },
						nil
					},
					make([][]u8, len(ase_info.frames)),
				}
				for frame, i in ase_info.frames {
					img, err := aseprite_utils.get_image_bytes_from_frame(frame, ase_info)
					aseprite_ok(file.name, err) or_continue
					sprite.pixels[i] = img
					sprite.frames[i] = {
						{},
						f32(frame.duration) / 1000,
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
				sprite := Packable_Sprite {
					Sprite_Asset{
						file.name,
						make([]Sprite_Animation_Frame, len(ase_info.frames)),
						{}, 
						{ ase_info.md.width, ase_info.md.height },
						nil
					},
					make([][]u8, len(ase_info.frames)),
				}
				for frame, i in ase_info.frames {
					img, err := aseprite_utils.get_image_bytes_from_frame(frame, ase_info)
					aseprite_ok(file.name, err) or_continue
					sprite.pixels[i] = img
					sprite.frames[i] = {
						{},
						f32(frame.duration) / 1000
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
			img, error_making_first_frame := aseprite_utils.get_image_from_doc(&ase_doc)
			aseprite_ok(file.name, error_making_first_frame) or_continue
			append(&pack_list, 
				Packable_Image{Image_Asset{file.name, {}, {img.width, img.height}, nil},
				img.data
			})
		}
	}

	if len(pack_list) == 0 {
		log.infof("No textures to pack.")
		return
	}
// 2. Pack  //////////////////////////////////////////////////////////////////////////////
	n_chan :: 4 // it's the job of the program to expand to 4 (and premult alpha) by now.
	pad_px :: 1 // pixels
	rects := make([dynamic]stbrp.Rect)
	for packable_union, i in pack_list {
		assert(i <= cast(int) max(i16))
		id := [2]i16 { cast(i16)i, -1 } // if -1 use index naively
		switch asset in packable_union {
		case Packable_Image:
			size_px := asset.size_px
			append(&rects, stbrp.Rect {
				id = transmute(i32) id,
				w  = stbrp.Coord(size_px.x + (2*pad_px)),
				h  = stbrp.Coord(size_px.y + (2*pad_px)),
			})
		case Packable_Sprite:
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
	atlas_size: [2]i32 = { MAX_ATLAS_PIXELS, 0 } // don't crop X
	for stb_rect in rects {
		assert(stb_rect.was_packed == true)
		x2 := i32(stb_rect.x + stb_rect.w)
		if x2 > atlas_size.x { atlas_size.x = x2 }
		y2 := i32(stb_rect.y + stb_rect.h)
		if y2 > atlas_size.y { atlas_size.y = y2 }
		assert(atlas_size.x > 0 && atlas_size.y > 0)
	}
	atlas_sizef: [2]f32 = array_cast(atlas_size, f32)
// 3. Render  ////////////////////////////////////////////////////////////////////////////
	for stb_rect in rects {
		atlas_stride := n_chan*MAX_ATLAS_PIXELS
		px_line_of_write := int(stb_rect.y) + pad_px
		px_offset_into_line := int(stb_rect.x) + pad_px
		atlas_subrect_topleft := (atlas_stride*px_line_of_write) + (n_chan*px_offset_into_line)
		id := transmute([2]i16) stb_rect.id
		packable_asset := &pack_list[id.x]
		asset_channels :: 4 // TODO: Skip if it isn't 4 channels in step 1 (gather assets)
		switch &asset in packable_asset {
		case Packable_Image:
			asset.uv_rect = {
				f32(px_offset_into_line) / atlas_sizef.x,
				f32(px_line_of_write) / atlas_sizef.y,
				f32(asset.size_px.x) / atlas_sizef.x,
				f32(asset.size_px.y) / atlas_sizef.y,
			}
			asset_stride := asset_channels * size_of(u8) * asset.size_px.x
			for row in 0..< asset.size_px.y {
				src_start := (row * asset_stride)
				src_end := src_start + asset_stride
				copy(atlas_rgba[atlas_subrect_topleft + (row*atlas_stride):],
				     asset.pixels[src_start: src_end])
			}
		case Packable_Sprite:
			frame_index := id.y
			assert(frame_index >= 0) // defaults to -1 for images.
			asset.frames[frame_index].uv_rect = {
				f32(px_offset_into_line) / atlas_sizef.x,
				f32(px_line_of_write) / atlas_sizef.y,
				f32(asset.size_px.x) / atlas_sizef.x,
				f32(asset.size_px.y) / atlas_sizef.y,
			}
			asset_stride := asset_channels * size_of(u8) * asset.size_px.x
			for row in 0..< asset.size_px.y {
				src_start := (row * asset_stride)
				src_end := src_start + asset_stride
				copy(atlas_rgba[atlas_subrect_topleft + (row*atlas_stride):],
				     asset.pixels[frame_index][src_start: src_end])
			}
		}
	}
log_time("render_textures")
// 4. Write Files ////////////////////////////////////////////////////////////////////////
	log_time("write_textures")
	width := MAX_ATLAS_PIXELS
	height := cast(int) atlas_size.y
	atlas_rgba = atlas_rgba[:width*height*4] // 4 channels
	err2: Image_File_Error
	if use_binary {
		err2 = os2.write_entire_file(TEXTURE_ATLAS_PATH, atlas_rgba[:])
	} else {
		err2 = write_rgba_qoi(atlas_rgba[:], width, height, TEXTURE_ATLAS_PATH)
	}
	if err2 != nil {
		fmt.printfln("LINE: %v", err2)
		assert(err2 == nil)
	}

	entries := Serialized_Texture_Atlas_Entries {}
	for packable in pack_list {
		switch asset in packable {
		case Packable_Image:
			entries.images[asset.filename] = asset.image
		case Packable_Sprite:
			entries.sprites[asset.filename] = asset.sprite
		}
	}
	file, err := os2.open(TEXTURE_ATLAS_METADATA, {.Write, .Trunc, .Create})
	defer os2.close(file)
assert(err == nil)
	writer := os2.to_writer(file)
	cbor.marshal_into_writer(writer, entries)
	delete(pack_list)
log_time("write_textures")
}


//////////////////////////////////////////////////////////////////////
// Implementation (3/3) Audio
//////////////////////////////////////////////////////////////////////


// Writes []Audio_Asset as AUDIO_METADATA
bundle_audio :: proc () {
// TODO: Compressed version. (cbor for metadata, copy ogg to cache for release.)
	asset_array := make([dynamic]Audio_Asset)
	log_time("LOAD_AUDIO"); defer log_time("LOAD_AUDIO")
	oggvs, dir_err := read_files_in_directory_with_suffix("../assets", "ogg") 
assert(dir_err == nil)
	for file in oggvs {
		clip, ok := audio.load_from_bytes(file.data)
		if !ok {
			log.errorf("[%v] Failed to import ogg. Is it vorbis? %s", clip.samples, file.name)
			continue
		}
		asset: Audio_Asset = {
			file.name,
			clip
		}
		append(&asset_array, asset)
		path := strings.concatenate({CACHE_DIR, file.name}) // LEAK
		file_write_err := os2.write_entire_file(path, clip.bytes)
	}
	// Now write the cache ///////////////////////////////////////////////////////
	file_write_err := os2.write_entire_file(AUDIO_METADATA, slice.reinterpret([]u8, asset_array[:]))
	assert(file_write_err == nil)
}

Image_File_Error :: union #shared_nil { image.Error, os2.Error }

@(require_results)
write_rgba_qoi :: proc (pixels: []u8, w,h: int, path: string) -> Image_File_Error {
	assert(len(pixels) == w*h*4)
	img: image.Image
	img.width = w
	img.height = h
	img.channels = 4
	img.depth = 8
	img.pixels.buf = alias_slice_as_dynamic(pixels)
	assert(len(img.pixels.buf) == w*h*4)
	buffer: bytes.Buffer
	qoi.save_to_buffer(&buffer, &img) or_return
	file: ^os2.File
	file = os2.open(path, {.Write, .Trunc, .Create}) or_return
	num_bytes := os2.write(file, buffer.buf[:]) or_return
	os2.close(file)
	return nil
}

// TODO: Use your own type lol... not runtime.
read_files_in_directory_with_suffix :: proc (
	dirpath: string,
	suffix: string
) -> (result: [dynamic]runtime.Load_Directory_File, error: os2.Error) {
	files := os2.read_all_directory_by_path(dirpath, context.allocator) or_return
	result = make([dynamic]runtime.Load_Directory_File)
	for file_info in files {
		(strings.ends_with(file_info.name, suffix)) or_continue
		file_bytes, err := os2.read_entire_file_from_path(file_info.fullpath, context.allocator)
		if err != nil {
			log.errorf("Failed to read a file. %s %v", file_info.fullpath, err)
			error = err
			continue
		}
		append_elem(&result, runtime.Load_Directory_File {
			file_info.name,
			file_bytes
		})
	}
	return
}

read_files_in_directory_with_suffixes :: proc (
	dirpath: string,
	suffixes: []string
) -> (result: [dynamic]runtime.Load_Directory_File, error: os2.Error) {
	files := os2.read_all_directory_by_path(dirpath, context.allocator) or_return
	result = make([dynamic]runtime.Load_Directory_File)
	for file_info in files {
		for suffix in suffixes {
			(strings.ends_with(file_info.name, suffix)) or_continue
			file_bytes, err := os2.read_entire_file_from_path(file_info.fullpath, context.allocator)
			if err != nil {
				log.errorf("Failed to read a file. %s %v", file_info.fullpath, err)
				error = err
				continue
			}
			append_elem(&result, runtime.Load_Directory_File {
				file_info.name,
				file_bytes
			})
		}
	}
	return
}

read_files_in_directory :: proc (
	dirpath: string,
) -> (result: [dynamic]runtime.Load_Directory_File, error: os2.Error) {
	files := os2.read_all_directory_by_path(dirpath, context.allocator) or_return
	result = make([dynamic]runtime.Load_Directory_File)
	for file_info in files {
		file_bytes, err := os2.read_entire_file_from_path(file_info.fullpath, context.allocator)
		if err != nil {
			log.errorf("Failed to read a file. %s %v", file_info.fullpath, err)
			error = err
			continue
		}
		append_elem(&result, runtime.Load_Directory_File {
			file_info.name,
			file_bytes
		})
	}
	return
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
