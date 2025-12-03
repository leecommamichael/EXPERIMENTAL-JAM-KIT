package main

import "core:log"
import "sugar"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

pixels_per_meter: f32 = 880.0 // Such that 50mm skateboard wheel is 44px.
pixels_per_decimeter: f32 = pixels_per_meter / 10
pixels_per_centimeter: f32 = pixels_per_meter / 100
pixels_per_millimeter: f32 = pixels_per_meter / 1000
gravity_acceleration: f32 = 9.8 * pixels_per_meter
gravity: Vec3 = DOWN * gravity_acceleration
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
		floor.basis.scale = 300
		floor.position.xy = 160
		floor.collider.size = floor.basis.scale
		floor.collider.shape = .AABB
		floor.flags += {.Collider_Enabled,}
		floor.collider.layer += {.Terrain}
	}
	wall, new_wall := rect(); if new_wall {
		wall.name = "Wall"
		wall.color = {0.1, 0.1, 0.1, 0.3}
		wall.basis.scale = 300
		wall.position.xy = 300+160
		wall.collider.size = floor.basis.scale
		wall.collider.shape = .AABB
		wall.flags += {.Collider_Enabled,}
		wall.collider.layer += {.Terrain}
	}

	ball, new_ball := circle(); if new_ball {
		ball.name = "Ball"
		ball.color = {0.3, 0.3, 0.3, 0.3}
		ball.basis.scale = 44
		ball.position.xy = {100, 400}
		ball.collider.size = ball.basis.scale
		ball.collider.shape = .Circle
		ball.flags += {.Collider_Enabled,}

		ball.acceleration = gravity
		ball.velocity.x = 1000
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
		BOUNCE_LOSS :: 1 - 0.25
		ROLL_LOSS :: 1 - 0.02
		v_parallel := dot(ball.velocity, normal) * normal // force into surface
		v_perp := ball.velocity - v_parallel              // force along surface
		// If the force into the surface can't generate a bounce, roll.
		// If it can't overcome gravity to bounce even a centimeter, we don't care.
		bounce_minimum_force := (f32(globals.dt) * gravity_acceleration) + f32(globals.dt) * pixels_per_centimeter
		v_parallel_force := length(v_parallel)
		if v_parallel_force <= bounce_minimum_force {
			// ROLL
			collision_position := nearest_point_along_aabb_to_circle(terrain, ball)//ball vs 
			ball.position = collision_position + normal * ball.collider.size.x/2
			ball.velocity = ROLL_LOSS * v_perp
			log.infof("ROLL vperp: %v", v_perp)
		} else {
			log.infof("len(v||): %v thresh: %v", v_parallel_force, bounce_minimum_force)
			// BOUNCE
			reflected_velocity := BOUNCE_LOSS * reflect(ball.velocity, normal)
			// log.infof("BOUNCE r: %v\normal: %v", reflected_velocity, normal)
			new_velocity = reflected_velocity
			// log.infof("v|| %v. vT: %v\n", v_parallel, v_perp)
			// log.infof("reflected %v", reflected_velocity)
		}
	}
	// if it's touching floor, and the resulting vector is weaker than gravity, follow surface.
	// neutralize that force, but stay open to others.
	ball.velocity = new_velocity
}

nearest_point_along_aabb_to_circle :: proc (aabb, circle: ^Entity) -> Vec3 {
	aabb_size := collider_size(aabb)
	aabb_max := aabb.position + aabb_size
	aabb_min := aabb.position - aabb_size
	to_max := aabb_max - circle.position
	to_min := aabb_min - circle.position

	nearest_point: Vec3 = circle.position
	if aabb_min.x > circle.position.x || circle.position.x > aabb_max.x {
		distance_to_nearest_edge_x := min_by_abs(to_min.x, to_max.x)
		nearest_point.x += distance_to_nearest_edge_x
	}
	if aabb_min.y > circle.position.y || circle.position.y > aabb_max.y {
		distance_to_nearest_edge_y := min_by_abs(to_min.y, to_max.y)
		nearest_point.y += distance_to_nearest_edge_y
	}


	return nearest_point
}