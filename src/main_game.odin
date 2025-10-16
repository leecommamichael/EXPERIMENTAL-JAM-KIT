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
debug_colliders: ^Entity

game_init :: proc () {
	globals.camera.position.y = 5
	debug_colliders = make_entity()
	debug_colliders.position.z = 1
	debug_colliders.flags += {.Is_3D }
	debug_colliders.draw_command = ren_make_basic_draw_cmd(
		globals.instance_buffer,
		cast(int) debug_colliders.id, {},{})
	debug_colliders.color = vec4(0.33, 0.45, 0.9, 0.5)
	globals.draw_colliders = true

	img = make_image(`gameplayboard.aseprite`)
	img.position.y = 100
	img.position.z = 1
	spr = sprite(`berserker.aseprite`)
	spr.position.z = 2
	spr.position.xy = 42
	spr.collider.shape = .Circle
	spr.collider.size = array_cast(spr.variant.(Sprite_State).asset.size_px/2, f32).x
	spr.flags += {.Collider_Enabled}
	spr_state := &spr.variant.(Sprite_State)
	spr_state.repetitions = 10
	cursor = sprite(`berserker.aseprite`)
	cursor.basis.scale /= 2
	cursor.basis.position = 0
	cursor.flags += {.Collider_Enabled}
	cursor.collider.shape = .Circle
	cursor.collider.size = 20
}

old_target: ^Entity
// Mixed-scope between renderer and game entities.
game_step :: proc () {
	bg, is_new := image(`bg.png`)
	if is_new {
		// bg.basis.scale *= 1/1.5
		// bg.basis.position *= 1/1.5
	}
	cursor.position.x = sugar.mouse_position.x
	cursor.position.y = sugar.mouse_position.y
	cursor.position.z = 0

	btn := button()
	btn.position.z = 0
	btn.position.xy = {500,100}
	btn.scale.xy = {100,100}
	btn.color.rgb = 0.2
	if globals.button_focus == btn {
			btn.color.rgb = {0.2, 0.8, 0.2} + 0.1
	}
	if .Pressed in btn.ui.state {
			btn.color.rgb = {0.8, 0.2, 0.2} - 0.1
	} else if .Hovered in btn.ui.state {
			btn.color.rgb = {0.8, 0.2, 0.2}
	}

	next_btn := button()
	next_btn.position.z = 0
	next_btn.position.xy = {650,100}
	next_btn.scale.xy = {100,100}
	next_btn.color.rgb = 0.2
	if globals.button_focus == next_btn {
			next_btn.color.rgb = {0.2, 0.8, 0.2} + 0.1
	}
	if .Pressed in next_btn.ui.state {
			next_btn.color.rgb = {0.8, 0.2, 0.2} - 0.1
	} else if .Hovered in next_btn.ui.state {
			next_btn.color.rgb = {0.8, 0.2, 0.2}
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

	if sugar.on_button_press(.Select) {
		globals.draw_colliders = !globals.draw_colliders
	}
	if globals.button_focus == nil { globals.button_focus = btn }
	if sugar.on_button_press(.Left) {
		if hit_test_ray_aabb(next_btn.position, 100*Vec3{-1,0,0}, btn) {

			log.infof("Go Left")
			globals.button_focus = btn
		}
	}
	if sugar.on_button_press(.Right) {
		hit_test_ray_aabb(btn.position,100*Vec3{1,0,0}, next_btn)
		if hit_test_ray_aabb(btn.position, 100*Vec3{1,0,0}, next_btn) {
			log.infof("Go Right")
			globals.button_focus = next_btn
		}
	}

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