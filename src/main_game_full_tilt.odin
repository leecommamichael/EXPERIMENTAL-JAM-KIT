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
	cursor.old_basis.scale = 0
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
		floor.position.xy = {160, 0}
		floor.collider.size = floor.basis.scale
		floor.collider.shape = .AABB
		floor.flags += {.Collider_Enabled,}
		floor.collider.layer += {.Terrain}
	}

	floor2, new_floor2 := rect(); if new_floor2 {
		floor2.name = "Floor2"
		floor2.color = {0.1, 0.1, 0.1, 0.3}
		floor2.basis.scale = 300
		floor2.position.xy = {600, 0}
		floor2.collider.size = floor2.basis.scale
		floor2.collider.shape = .AABB
		floor2.flags += {.Collider_Enabled,}
		floor2.collider.layer += {.Terrain}
	}

	wall, new_wall := rect(); if new_wall {
		wall.name = "Wall"
		wall.color = {0.1, 0.1, 0.1, 0.3}
		wall.basis.scale = 300
		wall.position.xy = 300+160
		wall.collider.size = wall.basis.scale
		wall.collider.shape = .AABB
		wall.flags += {.Collider_Enabled,}
		wall.collider.layer += {.Terrain}
	}

	bump, new_bump := rect(); if new_bump {
		bump.name = "Bump"
		bump.color = {0.1, 0.1, 0.1, 0.3}
		bump.basis.scale = 30
		bump.position.xy = 300+160 - {300,100}
		bump.collider.size = bump.basis.scale
		bump.collider.shape = .AABB
		bump.flags += {.Collider_Enabled,}
		bump.collider.layer += {.Terrain}
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
	}
	hand, new_hand := circle(); if new_hand {
		hand.name = "Hand"
		hand.color = {0.3, 0.3, 0.3, 0.3}
		hand.basis.scale = 22
		hand.position.xy = {100, 400}
		hand.collider.size = hand.basis.scale
		hand.collider.shape = .Circle
		hand.flags += {.Collider_Enabled,}
	}

	pc_step(ball, hand)
	// ball_step(ball)
}

// Crawl, Roll, or Swing
// Swinging if hand mounted and body not on ground.
// Crawling if body mounted and not ball
// Rolling  if not hand mounted and LT held.
//
// hand mounted if hand in contact with something & RT held.
// body mounted if in contact with something.
PC_State :: struct {
	hand: Vec3,
	hand_anchored: bool,
	ball_motion:   bool,
}

pc: PC_State

pc_step :: proc (blob: ^Entity, hand: ^Entity) {
	if sugar.input.gamepad.left_trigger > 0.1 {
		if pc.hand_anchored {
			// can't go ball while hanging (for now?)
		} else {
			pc.ball_motion = true
		}
	}

	if sugar.input.gamepad.right_trigger > 0.1 {
		pc.hand_anchored = true
	} else {
		pc.hand_anchored = false
	}

	if pc.ball_motion {
		ball_step(blob)
	} else { // INTENT: do slime movement because we're not a ball.
		pc.hand = blob.position // until moved | shooting | retracting this will move the hand instantly.
		if pc.hand_anchored {
			// TODO: pendulum.
		}
		hand_range: f32 : 32.0
		ls := clamp_length(vec3(sugar.input.gamepad.left_stick), 1)
		rs := clamp_length(vec3(sugar.input.gamepad.right_stick), 1)
		blob.position += ls
		pc.hand = blob.position + rs * hand_range
		hand.position = pc.hand
		// TODO: if R3, pop hand out, check collision and propel.
		////////////////////////////////////////////////////////////////////////////
		// INTENT: acceleration is gravity, unless touching something or mounted.
		touching_something: bool
		for collision in entity_collisions(blob) {
			if .Terrain not_in collision.other.collider.layer { continue }
			touching_something = true
			terrain := collision.other
			terrain_to_blob := blob.position - terrain.position
			normal := normalize(terrain_to_blob)

			switch terrain.collider.shape {
			case .None: continue
			case .Point: continue
			case .AABB:
				normal = nearest_direction_xy(normal)
			case .Circle:
			}
			collision_position := nearest_point_along_aabb_to_circle(terrain, blob)
			blob.position = collision_position + (normal * blob.collider.size.x/2)
		} // for collision /////////////////////////////////////////////////////////
		if touching_something {
			blob.acceleration = 0
		} else {
			blob.acceleration = gravity
		}
	} // else blob motion
} // pc step

ball_step :: proc (ball: ^Entity) {
	// Do ballistic motion with terrain.
	for collision in entity_collisions(ball) {
		if .Terrain not_in collision.other.collider.layer { continue }

		terrain := collision.other
		terrain_to_ball := ball.position - terrain.position
		normal := normalize(terrain_to_ball)

		switch terrain.collider.shape {
		case .None: continue
		case .Point: continue
		case .AABB:
			normal = nearest_direction_xy(normal)
		case .Circle:
		}
		// Deflect the object using the integrated vector.
		// There is a force-threshold which determines roll vs bounce.
		BOUNCE_LOSS :: 1 - 0.35
		ROLL_DECELERATION :: 1.0
		// If the force into the surface can't generate a bounce, roll.
		// If it can't overcome gravity to bounce even a centimeter, we don't care.
		collision_position := nearest_point_along_aabb_to_circle(terrain, ball)
		ball.position = collision_position + normal * ball.collider.size.x/2
		v_para := dot(ball.velocity, normal) * normal // force into surface
		v_perp := ball.velocity - v_para // force along surface
		v_para_force := length(v_para)
		v_perp_force := length(v_perp)

		bounce_minimum_force := (globals.tick * gravity_acceleration)\
		                       + globals.tick * pixels_per_centimeter
		if v_para_force <= bounce_minimum_force {
			if is_nearly(v_perp_force, 0) {
				ball.acceleration = 0
				// at rest.
				// log.infof("rest")
			} else {
				// ROLL
				log.infof("ROLL v_perp: %v", length(v_perp))
				v_perp_inverse := -1 * normalize(v_perp) // vector for deceleration
				deceleration := v_perp_inverse * ROLL_DECELERATION * globals.tick
				ball.velocity += -deceleration + v_perp * globals.tick
				ball.acceleration = gravity
			}
		} else {
			ball.acceleration = gravity
			// BOUNCE.
			log.infof("BOUNCE v||: %v OVER THRESH :%v", v_para_force, bounce_minimum_force)
			reflected_velocity := BOUNCE_LOSS * reflect(ball.velocity, normal)
			ball.velocity = reflected_velocity
		}
	}
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