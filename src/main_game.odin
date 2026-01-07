package main

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:sys/windows"
import "sugar"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

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

RG35SP_RESOLUTION: Vec2 = {640, 480}

Game_State :: struct {

}

gs: ^Game_State

game_init :: proc () {
	gs = new(Game_State)

	globals.draw_colliders = false
	globals.canvas_size_px = RG35SP_RESOLUTION / 2 // 320, 240 (~2x Gameboy SP)
	globals.canvas_scaling = .None
	globals.canvas_stretching = .Integer_Aspect

	globals.cursor = make_circle()
	globals.cursor.basis.position = 0
	globals.cursor.basis.scale = 22
	globals.cursor.flags += {.Collider_Enabled,}
	globals.cursor.collider.shape = .Circle
	globals.cursor.collider.layer += {.Terrain}
	globals.cursor.collider.size = 22
	globals.cursor.scale = 1
	globals.cursor.color.a = 0.6
	globals.cursor.color.rgb = 1.0
}

@export
game_step :: proc () {
	globals.cursor.position.xy = globals.mouse_position
	for i in 0..<12*12 {
		row := i % 12
		column := i / 12
		t, newt := tile(i); if newt {
			t.basis.scale = 19
			t.basis.position = t.basis.scale.x/2
			t.basis.position.x += 40
			t.position.xy = {f32(row), f32(column)} * (1+t.basis.scale.x)
			t.color.rgba = 1
		}
	}
}

tile :: proc (index: int) -> (^Entity, bool) #optional_ok {
	x, n := rect(index_hash(index))

	return x, n
}

