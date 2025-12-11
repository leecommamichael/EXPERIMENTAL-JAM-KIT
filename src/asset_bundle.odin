package main

import "base:runtime"
import "core:log"
import "core:bytes"
import "core:encoding/cbor"
import "core:image"
import "core:image/qoi" // texture atlas
import "core:image/tga" // font atlas
import stbtt "vendor:stb/truetype"
import "audio"

//////////////////////////////////////////////////////////////////////
// Interface
//////////////////////////////////////////////////////////////////////
Asset_Bundle :: struct {
	font_atlas:    GPU_Texture,
	font_infos:    map[string]stbtt.fontinfo,
	texture_atlas: GPU_Texture,
	images:        map[string]Image_Asset,
	sprites:       map[string]Sprite_Asset,
	audio:         map[string]Audio_Asset,
	bw_atlas_image:   image.Image,
	rgba_atlas_image: image.Image,
}

Audio_Asset :: struct {
	filename: string,
	using clip: audio.Clip,
}

MAX_ATLAS_PIXELS :: 1 << 14 // 2^14th (Common Modern OpenGL MAX_TEXTURE_SIZE)
MAX_ATLAS_BYTES :: MAX_ATLAS_PIXELS * MAX_ATLAS_PIXELS // 268 MB
FONT_COUNT :: len(Font_Variant) * len(Font_Usage) - (2*3) // pixel fonts have 1 variant
GLYPH_COUNT :: 0x058F - 32 // ascii thru Armenian (stops at Hebrew because it's RTL)

ASSET_DIR :: "../assets/"
CACHE_DIR :: "../cache/"
USE_BINARY_ASSET_CACHE :: ODIN_DEBUG// && ODIN_OS != .JS
BW_META_NAME    :: "font_atlas_metadata"
BW_ATLAS_NAME   :: "font_atlas"
RGBA_META_NAME  :: "texture_atlas_metadata"
RGBA_ATLAS_NAME :: "texture_atlas"
AUDIO_META_NAME :: "audio_metadata"
FONT_ATLAS_METADATA    :: CACHE_DIR + BW_META_NAME
FONT_ATLAS_PATH        :: CACHE_DIR + BW_ATLAS_NAME
TEXTURE_ATLAS_METADATA :: CACHE_DIR + RGBA_META_NAME
TEXTURE_ATLAS_PATH     :: CACHE_DIR + RGBA_ATLAS_NAME
AUDIO_METADATA         :: CACHE_DIR + AUDIO_META_NAME
font_atlas_bytes:          []u8
font_atlas_metadata_bytes: []u8
texture_atlas_metadata:    []u8
texture_atlas_bytes:       []u8
audio_metadata_bytes:      []u8

cache_files: []runtime.Load_Directory_File

//////////////////////////////////////////////////////////////////////
// Framework Integration Implementation
//////////////////////////////////////////////////////////////////////
// The asset cache minimizes time-to-first-frame in debug builds.
// A cache entry (uncompressed data) exists for each asset.
// In debug, uncompressed assets are used.
//   The cache is manually updated in game. (full re-create for now)
// In release, compressed assets are used.
//   The release cache is created by the exporter.
//
// TODO3D: Textures above a certain resolution will use ASTC compression.

// Rebuilds cache if necessary
asset_init :: proc () {
	cache_files = #load_directory(CACHE_DIR)
	// It's a debug build on a desktop and we're going to try to re-use the cache.
	for file in cache_files {
		target: ^[]u8
		switch file.name {
		case BW_META_NAME:
			target = &font_atlas_metadata_bytes
		case BW_ATLAS_NAME:
			target = &font_atlas_bytes
		case RGBA_META_NAME:
			target = &texture_atlas_metadata
		case RGBA_ATLAS_NAME:
			target = &texture_atlas_bytes
		case AUDIO_META_NAME:
			target = &audio_metadata_bytes
		}
		if target != nil {
			target^ = file.data
		}
	}

	when USE_BINARY_ASSET_CACHE && ODIN_OS != .JS {
		desktop_load_binary_asset_cache()
	} else {
		// If this is false, it's a release and we're using compressed assets.
		// TODO: something similar to above, but add a decompression step after reading ../assets
	}
	bundle := &globals.assets
	bundle.font_infos = make(map[string]stbtt.fontinfo)
	load_bundled_fonts(&bundle.bw_atlas_image, USE_BINARY_ASSET_CACHE)
	load_bundled_textures(&bundle.rgba_atlas_image, USE_BINARY_ASSET_CACHE)
	load_audio(USE_BINARY_ASSET_CACHE)
	// font_thread := thread.create_and_start_with_poly_data(&bundle.bw_atlas_image, load_bundled_fonts, context)
	// tex_thread := thread.create_and_start_with_poly_data(&bundle.rgba_atlas_image, load_bundled_textures, context)
	// audio_thread := thread.create_and_start(load_audio, context)
	// thread.join_multiple(font_thread, tex_thread)
	// thread.destroy(font_thread)
	// thread.destroy(tex_thread)
	// TODO when to join and destroy audio thread? store thread somewhere else in engine?
}

Serialized_Atlas_Font :: struct {
	usage:   Font_Usage,
	variant: Font_Variant,
	font:    Font,
}

Serialized_Texture_Atlas_Entries :: struct {
	images:  map[string]Image_Asset,
	sprites: map[string]Sprite_Asset,
}

asset_upload :: proc (use_binary: bool = USE_BINARY_ASSET_CACHE) {
	log_time("ASSET_UPLOAD")
	//////////////////////////////////////////////////////////////////////	
	// BW
	//////////////////////////////////////////////////////////////////////	
	globals.assets.font_atlas = {
		target = .TEXTURE_2D,
		minify_filter = .LINEAR,
		magnify_filter = .LINEAR,
		format = .R8, // <----------- CANT RELEASE .TGA UNTIL THEY TAKE MY PR (RGB8 otherwise)
	}
	bw := globals.assets.bw_atlas_image
	init_and_upload_texture(cast(u32) Texture_Unit.Font, &globals.assets.font_atlas, bw.pixels.buf[:], {bw.width, bw.height})
	globals.assets.images[FONT_ATLAS_PATH] = Image_Asset {
		FONT_ATLAS_PATH,
		{0,0, 1,1}, // does this even go here?
		{bw.width, bw.height},
		&globals.assets.font_atlas,
	}
	//////////////////////////////////////////////////////////////////////	
	// RGBA
	//////////////////////////////////////////////////////////////////////	
	globals.assets.texture_atlas = {
		target = .TEXTURE_2D,
		minify_filter = .NEAREST,
		magnify_filter = .NEAREST,
		format = .RGBA8,
	}
	rgba := globals.assets.rgba_atlas_image
	init_and_upload_texture(cast(u32) Texture_Unit.Texture, &globals.assets.texture_atlas, rgba.pixels.buf[:], {rgba.width, rgba.height})
	globals.assets.images[TEXTURE_ATLAS_PATH] = Image_Asset {
		TEXTURE_ATLAS_PATH,
		{0,0, 1,1}, // does this even go here?
		{rgba.width, rgba.height},
		&globals.assets.texture_atlas,
	}
	log_time("ASSET_UPLOAD")
	log_time("READ ATLAS METADATA")
	//////////////////////////////////////////////////////////////////////	
	// CBOR Textures
	//////////////////////////////////////////////////////////////////////	
	entries: Serialized_Texture_Atlas_Entries
	unmarshal_error := cbor.unmarshal_from_bytes(texture_atlas_metadata, &entries)
	globals.assets.images = entries.images
	globals.assets.sprites = entries.sprites
	// TODO: this pointer-wiring feels stupid... is it?
	for k, &i in globals.assets.images {
		i.texture = &globals.assets.texture_atlas
	}
	for k, &s in globals.assets.sprites {
		s.texture = &globals.assets.texture_atlas
	}
	//////////////////////////////////////////////////////////////////////	
	// CBOR Fonts
	//////////////////////////////////////////////////////////////////////	
	serialized_fonts := make([]Serialized_Atlas_Font, FONT_COUNT)
	assert(len(font_atlas_metadata_bytes) > 0)
	unmarshal_error2 := cbor.unmarshal_from_bytes(font_atlas_metadata_bytes, &serialized_fonts)
	if unmarshal_error2 != nil {
		log.errorf("Failed to unmarshal font atlas metadata %v", unmarshal_error2)
	}
	assert(unmarshal_error2 == nil)
	for font in serialized_fonts {
		globals.fonts[font.usage][font.variant] = font.font
	}
	log_time("READ ATLAS METADATA")
}

load_bundled_fonts :: proc (result: ^image.Image, use_binary: bool) {
	if use_binary {
		px_bytes := font_atlas_bytes
		img: image.Image
		img.channels = 1
		img.width = MAX_ATLAS_PIXELS
		img.height = len(px_bytes) / (MAX_ATLAS_PIXELS * img.channels)
		img.depth = 8
		img.pixels.buf = alias_slice_as_dynamic(px_bytes)
		result^ = img
	} else {
		img, img_err := tga.load_from_bytes(font_atlas_bytes)
		if img_err != nil {
			log.errorf("Failed to load font atlas (%d bytes). %v", len(font_atlas_bytes), img_err)
			assert(img_err == nil)
		}
		result^ = img^
	}
}

load_ttf :: proc (
	name: string,
	file_bytes: []u8,
	out_font: ^Font
) -> (ok: bool, info: stbtt.fontinfo) {
	out_font.name = name
	if name in globals.assets.font_infos {
		return true, globals.assets.font_infos[name]
	} else { // It's not cached yet.
		globals.assets.font_infos[name] = {}
		ok = cast(bool) stbtt.InitFont(
			&globals.assets.font_infos[name],
			raw_data(file_bytes),
			offset = 0)
		if ok {
			return true, globals.assets.font_infos[name]
		} else {
			delete_key(&globals.assets.font_infos, name)
		}
	}
	return false, {}
}

set_font_height :: proc (font: ^Font, new_height_px: f32) {
	fontinfo, already_cached := globals.assets.font_infos[font.name]
	assert(already_cached)
	font.height_px = new_height_px
  scale: f32 = stbtt.ScaleForPixelHeight(&fontinfo, new_height_px);
  font.scale = scale

  // Get the font's line height
  ascent, descent, line_gap: i32
  stbtt.GetFontVMetrics(&fontinfo, &ascent, &descent, &line_gap);
  font.ascent   = cast(f32)ascent  * scale;
  font.descent  = cast(f32)descent * scale;
  font.line_gap = cast(f32)line_gap * scale;
  font.line_height = font.ascent - font.descent + font.line_gap;

  // Get the monospace character width
  _lsb, monospace_advance: i32
  stbtt.GetCodepointHMetrics(&fontinfo, ' ', &monospace_advance, &_lsb);
  font.monospace_advance = cast(f32)monospace_advance * scale;
}

load_bundled_textures :: proc (result: ^image.Image, use_binary: bool) {
	// TODO use_binary or not
	log_time("LOAD_TEXTURES"); defer log_time("LOAD_TEXTURES")
	px_bytes := texture_atlas_bytes
	img: image.Image
	img.width = MAX_ATLAS_PIXELS
	img.height = (len(px_bytes) / (MAX_ATLAS_PIXELS * 4))
	img.channels = 4
	img.depth = 8
	img.pixels.buf = alias_slice_as_dynamic(px_bytes)
	result^ = img
}

load_audio :: proc (use_binary: bool) {
}
