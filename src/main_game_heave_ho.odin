package main

import "core:log"
import "sugar"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

cursor: ^Entity

game_init :: proc () {
	globals.draw_colliders = true
	globals.canvas_size_px = {960, 720}
	globals.canvas_scaling = .Smooth_Aspect
	globals.canvas_stretching = .Smooth_Aspect

	cursor = make_sprite(`berserker.aseprite`)
	cursor.basis.position = 0
	cursor.flags += {.Collider_Enabled,}
	cursor.collider.shape = .Circle
	cursor.collider.size = 44/2
	cursor.position.xy += cursor.basis.scale.xy/2
}

game_step :: proc () {
	ball, new_ball := circle()
	if new_ball {
		ball.basis.position = 0
		ball.scale = 44
		ball.color = {0.3, 0.6, 0.3, 1.0}
		ball.flags += {.Collider_Enabled,}
		ball.collider.shape = .Circle
		ball.collider.size = 44
	}
	ball.position.xy += 0.5
}