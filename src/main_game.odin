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
// Aster
////////////////////////////////////////////////////////////////////////////////
// RG35SP_RES: Vec2 = {640, 480}
// STEAM_DECK_RES: Vec2 = {1280, 800}
RES_X :: 800
RES_Y :: 800
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
	globals.canvas_size_px = array_cast([2]int{RES_X, RES_Y}, f32)
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
	defer {
		txt := text("Trigger Pressure Experiment", .bold_pixel)
		txt.position.xy = 8
	}



	gamepad := globals.sugar.input.gamepad
	pressure := gamepad.right_trigger
	@static prev_pressure: f32; defer prev_pressure = pressure
	d_pressure: f32 = pressure - prev_pressure

	shake_debounce :: .030
	shake_duration :: .150
	@static since_shake: f32 = 0; since_shake += globals.dt
	played: bool
	can_play := since_shake > shake_debounce
	shake_alpha: f32 = clamp((shake_duration - since_shake) / shake_duration, 0, 1)
	@static shake_power: f32 = 0

	if can_play && (pressure <= 0 || pressure >= 1) && d_pressure != 0 {
		played = true
		since_shake = 0
		shake_power = d_pressure
		audio.play(&globals.audio, gs.sfx_sink, "LTTP_Text_Letter.ogg")
	}

	basis: Vec2 = 44
	if shake_alpha != 0 {
	basis += { 
		0,//cos((shake_power * 40)*shake_alpha) * 5 / 2,
		sin((shake_power * 10)*shake_alpha) * 7 / 2
	}
	}

	bg := rect()
	bg.position.xy = 44 - 11
	bg.scale = 66
	bg.color = 0.2
	// linear_fill := rect()
	// linear_fill.position.xy = 44
	// linear_fill.scale.x = 44
	// linear_fill.scale.y = 44 * pressure

	bg2 := rect()
	bg2.position.xy = basis
	bg2.scale = 44
	bg2.color = 0.2
	curved_fill := rect()
	curved_fill.position.xy = basis
	curved_fill.scale.x = 44
	curved_fill.color.rb = 1 - shake_alpha
	// curved_fill.scale.y = 44 * midtone(pressure, 2.0)


	// I need a prepend which shoves other values aside.
	if played {
		// decide the velocity.
		// backtrack until a value lower than the present value is found.
	}


	// switch {
	// case pressure > 5.0/6.0: pressure = 5.0/5.0
	// case pressure > 4.0/6.0: pressure = 4.0/5.0
	// case pressure > 3.0/6.0: pressure = 3.0/5.0
	// case pressure > 2.0/6.0: pressure = 2.0/5.0
	// case pressure > 1.0/6.0: pressure = 1.0/5.0
	// case: pressure = 0
	// }

	if sugar.on_key_release(.Up_Arrow) {
	}
	if sugar.on_key_release(.Down_Arrow) {
	}
} // game step

