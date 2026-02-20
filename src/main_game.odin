package main

import "base:runtime"
import gl "angle"
import "core:mem/virtual"
import "core:sys/windows"
import "core:math/rand"
import "core:fmt"
import "core:time"
import "core:log"
import "sugar"
import "audio"

@export
hot_reload :: proc (engine_globals: ^Globals, engine_gs: ^Game_State) {
	ensure(engine_gs != nil)
	ensure(engine_globals != nil)
	gs = engine_gs
	globals = engine_globals
	sugar.set_memory(&globals.sugar)
	sugar.load_gl()
	globals.hot_reloaded_this_frame = true
}

////////////////////////////////////////////////////////////////////////////////
// Brackeys Jam                                                         Feb 2026
////////////////////////////////////////////////////////////////////////////////
// RG35SP_RES: Vec2 = {640, 480}
// STEAM_DECK_RES: Vec2 = {1280, 800}
RES_X :: 640 // 1/2 of Steam Deck
RES_Y :: 400 // 1/2 of Steam Deck
RES_SCALE :: 1

gs: ^Game_State

game_init :: proc () {
	gl.BindSampler(cast(u32) Texture_Unit.Framebuffer_Texture, globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Texture,             globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Font,                globals.ren.nearest_sampler)
	globals.cursor = make_entity()
	globals.cursor.flags += {.Hidden}
	globals.cursor.position.xy = globals.mouse_position.xy
	globals.draw_colliders = false
	globals.canvas_size_px = {320,200}
	globals.canvas_scaling = .None
	globals.canvas_stretching = .Integer_Aspect
	globals.canvas_stretching = .Integer_Aspect

	r := rand.create(10)
	context.random_generator = rand.default_random_generator(&r)

	gs = new(Game_State)

	gs.sfx_sink = audio.make_sink(&globals.audio, "sfx")
	gs.music_sink = audio.make_sink(&globals.audio, "music")
	// 1. Clips are already loaded from the asset bundler.
	// Just have to init their platform.
	for _, &asset in globals.assets.audio {
		audio.add_source_from_clip(&globals.audio, asset)
	}
	// audio.play(&globals.audio, gs.music_sink, "music_flower_duet.ogg")
} // game_init

@export
game_step :: proc () {
	box := text("game_step", .bold_pixel)
	box.position = 100
	@static vol: f32 = 1.0
	if sugar.on_key_release(.Up_Arrow) {
		vol = clamp(vol+0.1, 0, 1)
		audio.sink_set_volume(gs.music_sink, vol)
		audio.sink_set_volume(gs.sfx_sink, vol)
	}
	if sugar.on_key_release(.Down_Arrow) {
		vol = clamp(vol-0.1, 0, 1)
		audio.sink_set_volume(gs.music_sink, vol)
		audio.sink_set_volume(gs.sfx_sink, vol)
	}
	// log.infof("vol %2.2f", vol)
	if sugar.on_key_release(.Space) {
		audio.play(&globals.audio, gs.sfx_sink, "LTTP_Rupee1.ogg", 0.5)
		// audio.play(&globals.audio, gs.sfx_sink, "LTTP_Get_HeartPiece.ogg")
		// audio.play(&globals.audio, gs.sfx_sink, "LTTP_ItemFanfare.ogg")
		// audio.play(&globals.audio, gs.sfx_sink, "LTTP_Text_Letter.ogg")
		// audio.play(&globals.audio, gs.sfx_sink, "LTTP_Text_Done.ogg")
		// audio.play(&globals.audio, gs.sfx_sink, "sfx_get_coin.ogg")
	}
} // game step
