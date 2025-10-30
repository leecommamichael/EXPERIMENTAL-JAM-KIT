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

spr: ^Entity
cursor: ^Entity
debug_colliders: ^Entity

game_init :: proc () {
	globals.canvas_size_px = {384, 216}
	globals.canvas_scaling = .Fixed
	globals.canvas_stretching = .Integer_Aspect
	globals.ren.canvas_framebuffer = make_framebuffer(array_cast(globals.canvas_size_px, int))

	// debug_colliders = make_entity()
	// debug_colliders.position.z = 1
	// debug_colliders.flags += {.Is_3D }
	// debug_colliders.draw_command = ren_make_basic_draw_cmd(
	// 	globals.instance_buffer,
	// 	cast(int) debug_colliders.id, {},{})
	// debug_colliders.color = vec4(0.33, 0.45, 0.9, 0.5)
	// globals.draw_colliders = true
	cursor = sprite(`berserker.aseprite`)
	cursor.basis.position = 0
	cursor.flags += {.Collider_Enabled,}
	cursor.collider.shape = .Circle
	cursor.collider.size = 16


	// spr = sprite(`berserker.aseprite`)
	// spr.position.xy = 42
	// spr.collider.shape = .Circle
	// spr.collider.size = array_cast(spr.variant.(Sprite_State).asset.size_px/2, f32).x
	// spr.flags += {.Collider_Enabled}
	// spr_state := &spr.variant.(Sprite_State)
	// spr_state.repetitions = 10
}

// lerp test
// game_step :: proc () {
// 	rect := framebuffer_quad(from = globals.ren.framebuffer, to = 0)
// 	rect.scale.xy = array_cast(globals.framebuffer_size_px, f32)
// 	rect.basis.scale.y = -1 // because textures are flipped...
// 	rect.basis.position.xy = rect.scale.xy/2

// 	bg, bg_new := image(`bg.ase`)
// 	if bg_new {
// 		bg.basis.scale = 32
// 		bg.basis.position = 32/2
// 	}

// 	@static flip: bool
// 	@static tl: ^Timed_Lerp
// 	if sugar.on_button_press(.A) && tl == nil {
// 		target :f32= 0 if flip else 100
// 		tl = timed_lerp(&bg.position.x, target, 1.0)
// 		tl.timeout = proc (_: ^Managed_Data) {
// 			tl = nil
// 			flip = !flip
// 		}
// 		// te := timed_effect(&bg.position.x, 1.0, proc (x: ^^f32, percent: f32) {
// 		// 	if flip {
// 		// 		x^^ = cast(f32) lerp(f32(100), f32(00), percent)
// 		// 	} else {
// 		// 		x^^ = cast(f32) lerp(f32(00), f32(100), percent)
// 		// 	}
// 		// })
// 		// te.timeout = proc (x: ^^f32) {
// 		// 	flip = !flip
// 		// }
// 	}

// 	cursor.position.xy = globals.mouse_position
// 	tn1 := text("-1 hello", .pixel)
// 	{
// 		tn1.position.xy = 10
// 		tn1.color.rgb = 1.0
// 	}
// 	t0 := text(" 0")
// 	{
// 		t0.position.xy = 20
// 		t0.color.rgb = 0.8
// 	}
// 	t1 := text("+1")
// 	{
// 		t1.position.xy = 30
// 		t1.color.rgb = 0.6
// 	}
// 	t2 := text("+2")
// 	{
// 		t2.position.xy = 40
// 		t2.color.rgb = 0.4
// 	}

// 	tn1.position.z = -1
// 	t0.position.z  = 0
// 	t1.position.z  = +1
// 	t2.position.z  = +2
// }

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
game_step :: proc ()  {
	img := make_image(`gameplayboard.aseprite`)
	cursor.position.x = globals.mouse_position.x
	cursor.position.y = globals.mouse_position.y

	btn := button()
	btn.position.xy = {128,100}
	btn.basis.scale.xy = 44 / globals.canvas_stretch.x
	btn.color.rgb = 0.2
	if globals.button_focus == btn {
			btn.color.rgb = {0.2, 0.8, 0.2} + 0.1
	}
	if .Pressed in btn.ui.state {
			btn.color.rgb = {0.8, 0.2, 0.2} - 0.1
	} else if .Hovered in btn.ui.state {

		btn.color.rgb = {0.8, 0.2, 0.2}
	}

	for c, n in entity_collisions(cursor) {
		//
	}
	if they_started_touching(cursor, btn) {
		log.infof("Cursor entered button")
	}
	if they_stopped_touching(cursor, btn) {
		log.infof("Cursor exited button")
	}

	next_btn := button()
	next_btn.position.xy = {32,100}
	next_btn.basis.scale.xy = 44 / globals.canvas_stretch.x
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
			text("1"),
			text("2"),
			text("3"),
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

	globals.perspective_view = tick_mouse_camera(&globals.camera, f32(globals.dt))
	if sugar.is_button_pressed(.A) {
		globals.camera.offset.xy += 1
	}
	if sugar.is_button_pressed(.B) {
		globals.camera.offset.x = 100
	}
	if sugar.is_button_pressed(.X) {
	}
	if sugar.is_button_pressed(.Y) {
	}
	if sugar.on_button_press(.Start) {
	}
	cursor.position.z = next_z()
	rect := framebuffer_quad(from = globals.ren.canvas_framebuffer, to = 0)
	rect.scale.xy = array_cast(globals.framebuffer_size_px, f32)
	rect.basis.scale.y = -1 // because textures are flipped...
	rect.basis.position.xy = rect.scale.xy/2
	rect.flags += {.Is_UI}
}