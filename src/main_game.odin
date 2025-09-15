package main

// Purpose: This file makes use of services afforded by the framework.
//          It tries not to work with implementation details of i.e. the renderer.
//          This file should strive not to import OpenGL

import "core:log"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

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

	sprite :: proc (a:string) -> int { return 0 }
	spr := sprite(`berserker.aseprite`)
	hello = text(`hello`)
	hello.color = Vec4{1,0,0,1}
	hello.position.x = 100
	hello.position.y = 100
}

hello: ^Text_Entity
offset: f32
// Mixed-scope between renderer and game entities.
game_step :: proc (dt: f64) {
	do_text(`immediately!`, hello.position)
	globals.game_view = tick_mouse_camera(&globals.camera, f32(dt))
	// step_water(dt)
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