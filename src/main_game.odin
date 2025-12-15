package main

import "core:fmt"
import "core:log"
import "core:sys/windows"
import "sugar"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

pixels_per_meter: f32 = 880.0 // Such that 50mm skateboard wheel is 44px.
pixels_per_decimeter: f32 = pixels_per_meter / 10
pixels_per_centimeter: f32 = pixels_per_meter / 100
pixels_per_millimeter: f32 = pixels_per_meter / 1000
just_cuz :: 10.0
gravity_acceleration: f32 = 9.8 * pixels_per_meter / just_cuz
gravity: Vec3 = DOWN * gravity_acceleration

pc: ^PC_State
game_init :: proc () {
	pc = new(PC_State)

	globals.draw_colliders = false
	globals.canvas_size_px = {960, 720}
	globals.canvas_scaling = .Fixed
	globals.canvas_stretching = .Smooth_Aspect

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

	pc.phase2_collisions = alias_slice_as_empty_dynamic(make([]Collision, MAX_COLLISIONS_PER_FRAME))
}

@export
hot_reload :: proc (engine_globals: ^Globals, engine_pc: ^PC_State) {
	ensure(engine_pc != nil)
	ensure(engine_globals != nil)
	pc = engine_pc
	globals = engine_globals
	sugar.set_memory(&globals.sugar)
	sugar.load_gl()
	globals.hot_reloaded_this_frame = true
}

terrain_color :: Vec4 {0.1, 0.5, 0.4, 1}
bg_color :: Vec4 {0.2, 0.3, 0.6, 1}

@export
game_step :: proc () {
	clear(&pc.phase2_collisions)

	if sugar.on_key_press(.Space) {
		globals.draw_colliders = !globals.draw_colliders
	}
	globals.cursor.position.xy = globals.mouse_position


	shaded_quad := rect();
	hand, new_hand := circle(); if new_hand {
		hand.name = "Hand"
		hand.color = {0.1, 0.1, 0.1, 0.1}
		hand.basis.scale = 22
		hand.position.xy = {100, 400}
		hand.collider.size = hand.basis.scale
		hand.collider.shape = .Circle
		hand.flags += {.Collider_Enabled, .Physics_Skip_Integrate}
	}

	ball, new_ball := circle(); if new_ball {
		ball.name = "Ball"
		ball.color = {0.0, 0.2, 0.5, 0.1}
		ball.basis.scale = 44
		ball.position.xy = {100, 400}
		ball.collider.size = ball.basis.scale
		ball.collider.shape = .Circle
		ball.flags += {.Collider_Enabled, .Physics_Skip_Integrate}

		ball.acceleration = gravity
		pc.initial_pos = ball.position.xy
	}
	if sugar.on_button_press(.Start) {
		ball.position.xy = pc.initial_pos
	}
// Ball Shader /////////////////////////////////////////////////////////////////
	blob_vert := vertex_preamble + basic_vertex_inputs +
	`
		out vec4 io_color;
		out vec2 smooth_pos;
		void main() {
			io_color.rgb = i_color.rgb * i_color.a; // Convert to PMA
			io_color.a = i_color.a; // Convert to PMA
			smooth_pos = (i_model_mat * vec4(v_position, 1)).xy;
			mat4 mvp = frame.projection * frame.view * i_model_mat;
			gl_Position = mvp * vec4(v_position, 1);
		}
	`

	blob_frag := fragment_preamble + `
		// Credit: Inigo Quilez
		float sdCircle( vec2 p, float r ) {
		    return length(p) - r;
		}
		float sdSegment( in vec2 p, in vec2 a, in vec2 b ) {
		    vec2 pa = p-a, ba = b-a;
		    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
		    return length( pa - ba*h );
		}
		// exponential
		float smin( float a, float b, float k ) {
		    k *= 1.0;
		    float r = exp2(-a/k) + exp2(-b/k);
		    return -k*log2(r);
		}

		in vec2 smooth_pos;
		in vec4 io_color;
		out vec4 outColor;
		void main() {
			outColor = vec4(0.0);
			vec2 p = smooth_pos;
			float sz_ball = frame.ball_size.x;
			float sz_hand = frame.hand_size.x;
			float ball_sdf = sdCircle(frame.ball_position - p, sz_ball);
			float hand_sdf = sdCircle(frame.hand_position - p, sz_hand);
			float seg = sdSegment(p, frame.ball_position, frame.hand_position);
			float x = smin(ball_sdf, hand_sdf, 5.0);
			x = min(x, seg - frame.hand_size.x);
			outColor = vec4(-1.0 * x);
			// if (seg <= frame.hand_size.x) {
			// 	outColor = vec4(seg);
			// }
		}
	`
// Ball Shaders ////////////////////////////////////////////////////////////////
	hot_reloaded_shader(shaded_quad, blob_vert, blob_frag)

	pc_step(ball, hand)
	shaded_quad.position.xy = (ball.position.xy + hand.position.xy) / 2
	shaded_quad.basis.scale = (ball.basis.scale + hand.basis.scale) * sqrt(f32(2))

	floor, new_floor := rect(); if new_floor {
		floor.name = "Floor"
		floor.color = terrain_color
		floor.basis.scale = 300
		floor.position.xy = {150, -140}
		floor.collider.size = floor.basis.scale
		floor.collider.shape = .AABB
		floor.flags += {.Collider_Enabled,}
		floor.collider.layer += {.Terrain}
	}

	floor2, new_floor2 := rect(); if new_floor2 {
		floor2.name = "Floor2"
		floor2.color = terrain_color
		floor2.basis.scale = 300
		floor2.position.xy = {600, 100}
		floor2.collider.size = floor2.basis.scale
		floor2.collider.shape = .AABB
		floor2.flags += {.Collider_Enabled,}
		floor2.collider.layer += {.Terrain}
	}

	wall, new_wall := rect(); if new_wall {
		wall.name = "Wall"
		wall.color = terrain_color
		wall.basis.scale = 300
		wall.position.xy = 300+260
		wall.collider.size = wall.basis.scale
		wall.collider.shape = .AABB
		wall.flags += {.Collider_Enabled,}
		wall.collider.layer += {.Terrain}
	}

	bump, new_bump := rect(); if new_bump {
		bump.name = "Bump"
		bump.color = terrain_color
		bump.basis.scale = 30
		bump.position.xy = 300+260 - {300,100}
		bump.collider.size = bump.basis.scale
		bump.collider.shape = .AABB
		bump.flags += {.Collider_Enabled,}
		bump.collider.layer += {.Terrain}
	}

	bg, new_bg := rect(); if new_bg {
		bg.name = "BG"
		bg.color = bg_color
		bg.basis.scale.xy = globals.canvas_size_px
		bg.position.xy = bg.basis.scale.xy / 2
	}
}

PC_State :: struct {
	initial_pos:     Vec2,
	ball_mode:       bool, // else sticky blob
	blob_grounded:   bool, // in terrain, corrected.
	hand_grounded:   bool, // in terrain (assumes grabbing at all times) (no RT yet.)
	hand_striking:   bool, // in terrain (assumes grabbing at all times) (no RT yet.)
	blob_on_surface: Vec3,
	hand_on_surface: Vec3,
	prev_rs:         Vec3,
	rs_velocity:     Vec3, // % of a half-circle moved per second
	phase2_collisions: [dynamic]Collision,
}

// Allowing the system to move objects with acceleration
// will end in jank unless you fix the numbers to avoid it.
// Jank in this case is the jiggling above:below Terrain boundaries.
//
pc_step :: proc (blob: ^Entity, hand: ^Entity) {
	sugar := &globals.sugar
	lt := sugar.input.gamepad.left_trigger
	lt_down := lt > 0.01
	rt := sugar.input.gamepad.right_trigger
	rt_down := rt > 0.01;
	ls := clamp_length(vec3(sugar.input.gamepad.left_stick), 1)
	rs := clamp_length(vec3(sugar.input.gamepad.right_stick), 1)
	pc.rs_velocity += (rs - pc.prev_rs) * globals.tick
	// if length(rs - pc.prev_rs) < 0.0001 {
	// 	pc.rs_velocity = 0
	// }
	pc.ball_mode = lt_down

	rs_vel := length(rs - pc.prev_rs)
	if rs_vel > 0.2 do rs_vel = 1
	defer pc.prev_rs = rs
	if pc.blob_grounded && pc.hand_grounded {
		blob.position = hand.position - (rs * 32) // potentially move blob into Terrain
		blob.acceleration = 0
	}
	if pc.hand_grounded && !pc.blob_grounded {
		blob.position = hand.position - (rs * 32) // potentially move blob into Terrain
		blob.acceleration = 0 // TODO: make this stretchy|pendulum
	} 
	if pc.blob_grounded && !pc.hand_grounded {
		// INPUT RULE: LEFT STICK
		// Left stick moves the blob because it's grounded.
		blob.velocity = 0 // PUNT: needs to eliminate perp vel, not be zero.
		blob.acceleration = 0
		blob.position.x += ls.x
		// INPUT RULE: RIGHT STICK
		// Right stick works because it always does outside of the ball.
		hand.position = blob.position + rs * 32
	}
	if !pc.blob_grounded && !pc.hand_grounded { // Fall, cause nothing is grounded.
		blob.acceleration = gravity
		// INPUT RULE: RIGHT STICK
		// Right stick works because it always does outside of the ball.
		hand.position = blob.position + rs * 32
	}
	do_physics_integrate_tick(blob) // commit changes for t1 checking + adjustment.
	blob.acceleration = 0 // don't re-integrate gravity (this is new/untested)
	////////////////////////////////////////////////////////////////////////////// begin t1
	// t1: - Inputs are consumed and wiped for re-testing.
	// Goal of t1 is to adjust positions to prevent jitter caused by overlap + thrashing.
	////////////////////////////////////////////////////////////////////////////// t1
	pc.blob_grounded = false
	blob_collisions := find_collisions_involving_entity(game_check_phase2_collisions(blob)[:], blob)
	for collision in blob_collisions {
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

	pc.hand_striking = false
	pc.hand_grounded = false
	te: ^Timed_Effect_State(Empty_Struct)
	@static num_effects: int = 0
	hand_collisions := find_collisions_involving_entity(game_check_phase2_collisions(hand)[:], hand)
	for collision in hand_collisions {
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
		if rt_down {
			pc.hand_grounded = true // due to hand touching something.
		} else {
			pc.hand_striking = true
			pc.blob_grounded = false
			collision_position := nearest_point_along_aabb_to_circle(terrain, hand)
			pc.hand_on_surface = collision_position + (normal * hand.collider.size.x)
			hand.position = pc.hand_on_surface
			rs_stick_diff := pc.rs_velocity//rs - pc.prev_rs
			rs_vec := (rs_stick_diff) * 5000
			v_para := dot(rs_vec, normal) * normal // force into surface
			v_perp := rs_vec - v_para // force along surface
			v_para_force := length(v_para)
			v_perp_force := length(v_perp)
			assert(v_para_force >= 0)
			assert(v_perp_force >= 0)
			// if v_para_force + v_para_force < 100.0 { continue }
			// if v_para.y > 0 { continue }
			blob.velocity += -v_para - v_perp;
			{ // LOG
				// Timed_Label :: struct {anchor: Vec2, label: ^Entity, value: Vec3}
				// effect := Timed_Label {
				// 	anchor = Vec2 {300, globals.canvas_size_px.y - 20} - { 0, 14 * f32(num_effects)},
				// 	label = make_text("Hello"),
				// 	value = rs_stick_diff
				// }
				// te := timed_effect(effect, 2, proc(it: ^Timed_Label, percent: f32) {
				// 	set_text(it.label, fmt.tprintf("RSd %v", it.value))
				// 	it.label.basis.position.xy = it.anchor
				// })
				// num_effects += 1
				// te.timeout = proc (it: ^Timed_Label) {
				// 	free_entity(it.label)
				// 	num_effects -= 1
				// }
			}
		}
	} // for collision(hand)
	blob_collisions = find_collisions_involving_entity(game_check_phase2_collisions(blob)[:], blob)
	for collision in blob_collisions {
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
	do_physics_integrate_tick(blob) // commit changes for t1 checking + adjustment.
	hand.position = blob.position + rs * 32
	globals.uniforms.ball_position = blob.position.xy
	globals.uniforms.ball_size = blob.basis.scale.xy / 2
	globals.uniforms.hand_position = hand.position.xy
	globals.uniforms.hand_size = hand.basis.scale.xy / 2
} // pc step

game_check_phase2_collisions :: proc (entity: ^Entity) -> [dynamic]Collision {
	clear(&pc.phase2_collisions)
	if .Collider_Enabled in entity.flags {
		assert(entity.collider.shape != nil)
		collider_loop: for &other in globals.entities {
			for pair in pc.phase2_collisions {
				if pair.ids[0] == entity.id && pair.ids[1] == other.id \
				|| pair.ids[1] == entity.id && pair.ids[0] == other.id {
					continue collider_loop // INTENT: Already in list. Don't duplicate.
				}
			}

			if entity_contains_entity(entity, other) {
				new_collision := Collision {ids={entity.id, other.id}}
				append(&pc.phase2_collisions, new_collision)
			}
		} // collider_loop
	}
	return pc.phase2_collisions
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
