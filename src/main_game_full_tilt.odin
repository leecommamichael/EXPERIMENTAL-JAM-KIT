package main

import "core:log"
import "sugar"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

pixels_per_meter: f32 = 880.0 // Such that 50mm skateboard wheel is 44px.
gravity: Vec3 = DOWN * 9.8 * pixels_per_meter
cursor: ^Entity

game_init :: proc () {
	globals.draw_colliders = true
	globals.canvas_size_px = {960, 720}
	globals.canvas_scaling = .Fixed
	globals.canvas_stretching = .Smooth_Aspect

	cursor = make_sprite(`berserker.aseprite`)
	cursor.basis.position = 0
	cursor.basis.scale = 44
	cursor.flags += {.Collider_Enabled,}
	cursor.collider.shape = .Circle
	cursor.collider.layer += {.Terrain}
	cursor.collider.size = 44
	cursor.scale = 1
	cursor.position.z = next_z()
}

game_step :: proc () {
	if sugar.on_key_press(.Space) {
		globals.draw_colliders = !globals.draw_colliders
	}
	cursor.position.xy = globals.mouse_position

	floor, new_floor := rect(); if new_floor {
		floor.name = "Floor"
		floor.color = {0.1, 0.1, 0.1, 0.3}
		floor.basis.scale = 100
		floor.position.xy = 100
		floor.collider.size = floor.basis.scale
		floor.collider.shape = .AABB
		floor.flags += {.Collider_Enabled,}
		floor.collider.layer += {.Terrain}
	}

	ball, new_ball := circle(); if new_ball {
		ball.name = "Ball"
		ball.color = {0.3, 0.3, 0.3, 0.3}
		ball.basis.scale = 44
		ball.position.xy = {100, 400}
		ball.collider.size = ball.basis.scale
		ball.collider.shape = .Circle
		ball.flags += {.Collider_Enabled,}
	}

	ball_step(ball)

	if they_touch(cursor, floor) {
		cursor.color = {1,0,0, 0.5}
	} else {
		cursor.color = {0.0, 0.0, 0.0, 0.0}
	}
}

Ball_State :: enum {
	Ground,
	Air,
}

ball_state: Ball_State = .Air
ball_step :: proc (ball: ^Entity) {
	// Do ballistic motion with terrain.
	ball.acceleration = gravity
	new_velocity: Vec3 = ball.velocity
	for collision in entity_collisions(ball) {
		if .Terrain not_in collision.other.collider.layer { continue }

		terrain := collision.other
		terrain_to_ball := ball.position - terrain.position
		normal := normalize(terrain_to_ball)

		// Integrate all collisions into a resulting vector.
		switch terrain.collider.shape {
		case .None: continue
		case .Point: continue
		case .AABB:
			normal = nearest_direction_xy(normal)
		case .Circle:
		}
		// Deflect the object using the integrated vector.
		// There is a force-threshold which determines roll vs bounce.
		ENERGY_LOSS :: 0.15
		reflected_velocity := (1 - ENERGY_LOSS) * reflect(ball.velocity, normal)
		new_velocity = reflected_velocity
		// log.infof("reflection normal %v", normal)
	}
	// if it's touching floor, and the resulting vector is weaker than gravity, follow surface.
	// neutralize that force, but stay open to others.
	ball.velocity = new_velocity
}