package main

import "core:fmt"
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

	phase2_collisions = alias_slice_as_empty_dynamic(make([]Collision, MAX_COLLISIONS_PER_FRAME))
}

game_step :: proc () {
	clear(&phase2_collisions)

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

	if pc.hand_grounded {
		hand.color = 0.8
	} else {
		hand.color = 0.5
	}
	if pc.blob_grounded {
		ball.color = 0.8
	} else {
		ball.color = 0.5
	}

	pc_step(ball, hand)
	if globals.draw_colliders {
		e := text(fmt.tprintf("%#v", pc));
		e.basis.position.y = globals.canvas_size_px.y - 20
		e2 := text(fmt.tprintf("ball acc. := %#v", ball.acceleration));
		e2.basis.position.y = globals.canvas_size_px.y - 350
	}
}

PC_State :: struct {
	ball_mode:     bool, // else sticky blob
	blob_grounded: bool, // in terrain, corrected.
	blob_on_surface: Vec3,
	hand_grounded: bool, // in terrain (assumes grabbing at all times) (no RT yet.)
	hand_on_surface: Vec3
}

pc: PC_State

// Allowing the system to move objects with acceleration
// will end in jank unless you fix the numbers to avoid it.
// Jank in this case is the jiggling above:below Terrain boundaries.
pc_step :: proc (blob: ^Entity, hand: ^Entity) {
	// t0: - The game state drives possible inputs.
	//     - Colliders are promised integrity by previous step. (adjustments)
	// Goal of t0 is to set all forces allowed by controls.
	////////////////////////////////////////////////////////////////////////////// t0
	lt := sugar.input.gamepad.left_trigger
	wants_ball := lt > 0.01
	pc.ball_mode = wants_ball

	if pc.ball_mode {
		pc.blob_grounded = false
		pc.hand_grounded = false
		blob.acceleration = gravity
		hand.position = blob.position // (TODO: needs to happen after integration)             Hand trails ball by one frame.
		ball_step(blob) ///////////////////////////////// <--------- DIVERGE TO BALL
		return
	}
	rt := sugar.input.gamepad.right_trigger
	wants_grab := rt > 0.01

	ls := clamp_length(vec3(sugar.input.gamepad.left_stick), 1)
	rs := clamp_length(vec3(sugar.input.gamepad.right_stick), 1)
	if pc.hand_grounded {
		hand.position = pc.hand_on_surface
		blob.position = hand.position - (rs * 32) // potentially move blob into Terrain
		hand.velocity = 0
		blob.acceleration = 0 // TODO: make this stretchy|pendulum
	} else if pc.blob_grounded {
		// INPUT RULE: LEFT STICK
		// Left stick moves the blob because it's grounded.
		blob.velocity = 0 // PUNT: needs to eliminate perp vel, not be zero.
		blob.acceleration = 0
		blob.position.x += ls.x
		// INPUT RULE: RIGHT STICK
		// Right stick works because it always does outside of the ball.
		hand.position = blob.position + rs * 32
	} else { // Fall, cause nothing is grounded.
		blob.acceleration = gravity
		// INPUT RULE: RIGHT STICK
		// Right stick works because it always does outside of the ball.
		hand.position = blob.position + rs * 32
	}
	// t1: - Inputs are consumed and wiped for re-testing.
	// Goal of t1 is to adjust positions to prevent jitter caused by overlap + thrashing.
	////////////////////////////////////////////////////////////////////////////// t1
	for collision in entity_collisions(blob) {
		if .Terrain not_in collision.other.collider.layer { continue }
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
		pc.blob_on_surface = collision_position + (normal * blob.collider.size.x/2)
		pc.blob_grounded = true
		blob.position = pc.blob_on_surface
	} // for collision(blob)
	if !wants_grab {
		pc.hand_grounded = false
	} else {
		for collision in entity_collisions(hand) {
			if .Terrain not_in collision.other.collider.layer { continue }
			terrain := collision.other
			terrain_to_hand := hand.position - terrain.position
			normal := normalize(terrain_to_hand)

			switch terrain.collider.shape {
			case .None: continue
			case .Point: continue
			case .AABB:
				normal = nearest_direction_xy(normal)
			case .Circle:
			}
			collision_position := nearest_point_along_aabb_to_circle(terrain, hand)
			pc.hand_on_surface = collision_position + (normal * hand.collider.size.x/2)
			pc.hand_grounded = true // due to hand touching something.
			hand.position = pc.hand_on_surface
		} // for collision(hand)
	}
} // pc step

phase2_collisions: [dynamic]Collision
game_check_phase2_collisions :: proc (entity: ^Entity) {
	if .Collider_Enabled in entity.flags {
		assert(entity.collider.shape != nil)
		collider_loop: for &other in globals.entities {
			for pair in phase2_collisions {
				if pair.ids[0] == entity.id && pair.ids[1] == other.id \
				|| pair.ids[1] == entity.id && pair.ids[0] == other.id {
					continue collider_loop // INTENT: Already in list. Don't duplicate.
				}
			}

			if entity_contains_entity(entity, other) {
				new_collision := Collision {ids={entity.id, other.id}}
				append(&phase2_collisions, new_collision)
			}
		} // collider_loop
	}
}

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
				log.infof("rest")
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