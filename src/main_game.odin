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
	globals.canvas_size_px = {640,400}
	globals.canvas_scaling = .None
	globals.canvas_stretching = .Integer_Aspect
	globals.canvas_stretching = .Integer_Aspect

	r := rand.create(10)
	context.random_generator = rand.default_random_generator(&r)

	gs = new(Game_State)

	gs.sfx_sink = audio.make_sink()
	gs.music_sink = audio.make_sink()

	for k,&v in globals.assets.audio {
		v.source = audio.make_source_from_clip(globals.audio, v)
	}
	// audio.play(globals.audio, gs.sfx_sink, globals.assets.audio["sfx_get_coin.ogg"])
	// audio.play(globals.audio, gs.music_sink, globals.assets.audio["music_flower_duet.ogg"])
} // game_init

@export
game_step :: proc () {
	box := rect()
	box.basis.scale = 44
} // game step
