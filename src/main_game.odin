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

game_init :: proc () {
	globals.camera.position.y = 5
	globals.plane_mesh = geom_make_xz_plane(squares_per_axis = AXIS_SQUARES)

	globals.water_plane = make_entity()
	globals.water_plane.is_3D = true
	globals.water_plane.draw_command = ren_make_water_draw_cmd(
		globals.water_plane.id,
		globals.plane_mesh.vertices[:],
		globals.plane_mesh.indices[:])
	globals.water_plane.color = vec4(0.33, 0.45, 0.9, 1)
	globals.water_heightmap = make([]f32, PLANE_POINTS)

	img = image(`gameplayboard.aseprite`)
	spr = sprite(`berserker.aseprite`)
	spr_state := &spr.variant.(Sprite_State)
	spr_state.repetitions = 10

	spr.position = Vec3{ 0=384/2, 1=216/2 }

	hello := text(`hello`)
	hello.color = Vec4{1,1,1, 1}
	// hello.color = Vec4{0,0,0, 1.0}
	hello.position.x = 400
	hello.position.z = 4
}

// Mixed-scope between renderer and game entities.
game_step :: proc () {
	do_text(`immediately!`, {200,300,4})
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