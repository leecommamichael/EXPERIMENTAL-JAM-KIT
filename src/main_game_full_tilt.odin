package main

import "core:log"
import "sugar"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

cursor: ^Entity

gravity: Vec3 = DOWN * 0.5 * 9.8

game_init :: proc () {
	globals.draw_colliders = true
	globals.canvas_size_px = {960, 720}
	globals.canvas_scaling = .Fixed
	globals.canvas_stretching = .Smooth_Aspect

	cursor = make_sprite(`berserker.aseprite`)
	cursor.basis.position = 0
	// cursor.flags += {.Collider_Enabled,}
	// cursor.collider.shape = .Circle
	cursor.collider.size = 44
	cursor.scale = 1
}

game_step :: proc () {
	if sugar.on_key_press(sugar.Key.Space) {
		if .Hidden in globals.collider_visualization.flags {
			globals.collider_visualization.flags -= {.Hidden}
			globals.draw_colliders = true
		} else {
			globals.collider_visualization.flags += {.Hidden}
			globals.draw_colliders = false
		}
	}
	cursor.position.xy = globals.mouse_position

	floor, new_floor := rect(); if new_floor {
		floor.color = {0.1, 0.1, 0.1, 0.3}
		floor.basis.scale = 100
		floor.position.xy = 100
		floor.scale = 1
		floor.collider.size = floor.basis.scale
		floor.collider.shape = .AABB
		floor.flags += {.Collider_Enabled,}
	}

	ball, new_ball := circle(); if new_ball {
		ball.color = {0.3, 0.3, 0.3, 0.3}
		ball.basis.scale = 44
		ball.position.xy = {100, 400}
		ball.collider.size = ball.basis.scale
		ball.collider.shape = .Circle
		ball.flags += {.Collider_Enabled,}
		ball.velocity = gravity
	}
	if they_touch(ball, floor) {
		ball.velocity = 0
	}
}