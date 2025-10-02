package main

// Purpose: This file makes use of services afforded by the framework.
//          It tries not to work with implementation details of i.e. the renderer.
//          This file should strive not to import OpenGL

import "core:log"
import "sugar"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

img: ^Entity
spr: ^Entity
cursor: ^Entity

game_init :: proc () {
	globals.camera.position.y = 5
	globals.plane_mesh = geom_make_xz_plane(AXIS_SQUARES, context.temp_allocator)

	globals.water_plane = make_entity()
	globals.water_plane.flags += {.Is_3D }
	globals.water_plane.draw_command = ren_make_water_draw_cmd(
		globals.water_plane.id,
		globals.plane_mesh.vertices[:],
		globals.plane_mesh.indices[:])
	globals.water_plane.color = vec4(0.33, 0.45, 0.9, 1)
	globals.water_heightmap = make([]f32, PLANE_POINTS)

	img = make_image(`gameplayboard.aseprite`)
	img.position.y = 100
	img.position.z = 1
	spr = sprite(`berserker.aseprite`)
	spr.position.z = 2
	spr.position.xy = 42
	spr.collider.shape = .Circle
	spr.collider.half_size = array_cast(spr.variant.(Sprite_State).asset.size_px/2, f32).x
	spr.flags += {.Collider_Enabled}
	spr_state := &spr.variant.(Sprite_State)
	spr_state.repetitions = 10
	cursor = sprite(`berserker.aseprite`)
	cursor.basis.scale /= 2
	cursor.basis.position = 0
	cursor.flags += {.Collider_Enabled}
	cursor.collider.shape = .Circle
	cursor.collider.half_size = 2

	hello := make_text(`hello`)
	hello.color = Vec4{1,1,1, 1}
	// hello.color = Vec4{0,0,0, 1.0}
	hello.position.x = 400
	hello.position.z = 4
}

old_target: ^Entity
// Mixed-scope between renderer and game entities.
game_step :: proc () {
	cursor.position.x = sugar.mouse_position.x
	cursor.position.y = f32(sugar.viewport_size.y) - sugar.mouse_position.y
	cursor.position.z = -1.5

	b := button()
	b.position.z = 0
	b.position.xy = {500,100}
	b.scale.xy = {100,100}
	if entity_contains_entity(cursor, b) {
		b.color.rgb = {0.8, 0.2, 0.2}
	} else {
		b.color.rgb = 0.2
	}

		ro := ui_element(
			row(
				text("rThis"),
				text("isRow"),
			)
		)
		ro.position.xy = {32,32}
		elem := ui_element(
			column(
				text("This"),
				text("is"),
				text("a"),
				text("_"),
				text("column")
			)
		)

	// target: ^Entity
	// for coll in globals.collisions {
	// 	if coll.ids[0] == cursor.id {
	// 		target = &globals._entity_storage[coll.ids[1]]
	// 	} else if coll.ids[1] == cursor.id {
	// 		target = &globals._entity_storage[coll.ids[0]]
	// 	}
	// }

	// if target == nil {
	// 	if old_target != nil {
	// 		// no collision found, drop focus
	// 		old_target.scale = 1
	// 		old_target = nil
	// 	}
	// } else {

	// 	if target != old_target {
	// 		// new target, drop focus on old.
	// 		if old_target != nil {
	// 			// new collision found, drop focus
	// 			old_target.scale = 1
	// 		}
	// 		old_target = target
	// 		old_target.scale = 5
	// 	}
	// }

	globals.game_view = tick_mouse_camera(&globals.camera, f32(globals.dt))
	if sugar.is_button_pressed(.A) {
		img.position.y -= 1
		spr.position.y -= 1
	}
	if sugar.is_button_pressed(.B) {
		img.position.x += 1
		spr.position.x += 1
	}
	if sugar.is_button_pressed(.X) {
		img.position.x -= 1
		spr.position.x -= 1
	}
	if sugar.is_button_pressed(.Y) {
		img.position.y += 1
		spr.position.y += 1
	}
	if sugar.on_button_press(.Start) {
		spr.scale.y *=  -1
	}
}

AXIS_SQUARES  :: 100 // Squares per axis
AXIS_POINTS   :: AXIS_SQUARES + 1
PLANE_SQUARES :: AXIS_SQUARES * AXIS_SQUARES
PLANE_POINTS :: AXIS_POINTS * AXIS_POINTS


height_func :: #force_inline proc (x, z: int, y: ^f32) {
	using globals
	using glsl
	derived_y := 1.5 * sin((0.2*uniforms.tau_time) + f32(x))
	y^ = cast(f32) derived_y
}