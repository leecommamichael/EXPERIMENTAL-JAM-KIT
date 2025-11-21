package main

import "core:log"
import "sugar"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

gravity: Vec3 = DOWN * 9.8
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
	cursor.collider.size = 44
	cursor.scale = 1
	cursor.position.z = next_z()
}

game_step :: proc () {
	if sugar.on_key_press(.Space) {
		globals.collider_visualization.flags ~= {.Hidden}
	}
	cursor.position.xy = globals.mouse_position

	floor, new_floor := rect(); if new_floor {
		floor.color = {0.1, 0.1, 0.1, 0.5}
		floor.basis.scale = 100
		floor.position.xy = 100
		floor.collider.size = floor.basis.scale
		floor.collider.shape = .AABB
		floor.flags += {.Collider_Enabled,}
		floor.collider.layer += {.Terrain}
	}

	ball, new_ball := circle(); if new_ball {
		ball.color = {0.3, 0.3, 0.3, 0.5}
		ball.basis.scale = 44
		ball.position.xy = {100, 400}
		ball.collider.size = ball.basis.scale
		ball.collider.shape = .Circle
		ball.flags += {.Collider_Enabled,}
		ball.velocity = gravity
	}

	ball_step(ball)
}

Ball_State :: enum {
	Ground,
	Air,
}

ball_state: Ball_State = .Air
ball_step :: proc (ball: ^Entity) {
	// Do ballistic motion with terrain.
	ball.velocity += f32(globals.dt) * gravity

	// ball_dir := normalize(ball.velocity)
	// ball_vel := length(ball.velocity)
	new_velocity: Vec3 = ball.velocity
	for collision in entity_collisions(ball) {
		if .Terrain in collision.other.collider.layer {
			terrain := collision.other
			// Integrate all collisions into a resulting vector.
			if terrain.collider.shape != .AABB { log.infof("NOT YET SUPPORTED"); continue }
			// 1. Find the normal.
			spherical_normal := normalize(ball.position - terrain.position)
			// 2. Inspect the xy aspects and snap them to Up,Down,Left,Right
			theta_xy := atan2(spherical_normal.y, spherical_normal.x) // -PI to PI
			to_right := abs( 0    - theta_xy)
			to_up    := abs( PI/2 - theta_xy)
			to_left  := abs( PI   - theta_xy)
			to_down  := abs(-PI/2 - theta_xy)
			directions := [4]f32{to_right, to_up, to_left, to_down}
			nearest_direction :f32= vec_min(directions)
			direction_index, found := find(directions[:], nearest_direction); assert(found)
			snapped_vector: Vec3 // NOTICE: truncation to 2D from 3D
			switch direction_index {
			case 0: snapped_vector = RIGHT;
			case 1: snapped_vector = UP;
			case 2: snapped_vector = LEFT;
			case 3: snapped_vector = DOWN;
			}
			new_velocity += 1.6* reflect(ball.velocity, snapped_vector)
		}
		ball.velocity = new_velocity
	}
	// Deflect the object using the integrated vector.
	// There is a force-threshold which determines roll vs bounce.

}