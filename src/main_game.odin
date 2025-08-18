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
	plane_asset := ren_make_basic_asset(globals.ren, globals.plane_mesh.vertices[:], globals.plane_mesh.indices[:], globals.ren.instance_UBO)
	v,i := make_circle_2D(44.0)
	cursor_asset := ren_make_basic_asset(globals.ren, v, i, globals.ren.instance_UBO)
	vm,im := make_circle_2D(0.5)
	marker_asset := ren_make_basic_asset(globals.ren, vm, im, globals.ren.instance_UBO)

	globals.water_plane = make_entity()
	globals.water_plane._asset = plane_asset
	globals.water_plane._asset.program = globals.ren.programs[.Water]
	globals.water_plane.color = vec4(0.33, 0.45, 0.9, 1)
	// globals.water_plane._asset.mode = .Line_Loop

	globals.marker = make_entity()
	globals.marker._asset = marker_asset
	globals.marker.rotation.x = f32(linalg.PI/2)
	globals.marker.hidden = true

	globals.water_heightmap = make([]f16, PLANE_POINTS)
	tex: uint
	gl.glGenTextures(1, &tex)
	gl.glBindTexture(gl.TEXTURE_2D, tex)
	gl.glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, auto_cast gl.REPEAT)
	gl.glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, auto_cast gl.REPEAT)
	gl.glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl.NEAREST)
	gl.glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl.NEAREST)

	gl.glPixelStorei(gl.UNPACK_ALIGNMENT,2)
	gl.TexImage2D(
		.TEXTURE_2D,
		0, // LOD
		cast(int) gl.R16F,
		AXIS_POINTS,
		AXIS_POINTS,
		gl.RED,
		gl.HALF_FLOAT,
		globals.water_heightmap)
}

// Mixed-scope between renderer and game entities.
game_step :: proc (dt: f64) {
	globals.game_view = tick_mouse_camera(&globals.camera, f32(dt))
	step_water(dt)

	cost := glsl.cos(globals.uniforms.tau_time * 4)
	sint := glsl.sin(globals.uniforms.tau_time * 4)
	globals.marker.position = vec3(1*cost, 0, 1*sint)
	globals.marker.position +=  vec3(0,0,8)
	if (cost) > 0.99 {
		globals.marker.color = vec4(1,0,0,1)
	} else if (sint) > 0.99 {
		globals.marker.color = vec4(0,0,1,1)
	} else {
		globals.marker.color = vec4(0,0,0,1)
	}
}


AXIS_SQUARES  :: 1000 // Squares per axis
AXIS_POINTS   :: AXIS_SQUARES + 1
PLANE_SQUARES :: AXIS_SQUARES * AXIS_SQUARES
PLANE_POINTS :: AXIS_POINTS * AXIS_POINTS

step_water :: proc (dt: f64) {
	using globals
	using glsl
	// I can't use a loop var.
	// I need to use the data of the buffer (vert positions) to derive x,y which derive Y.
	for i in 0 ..< PLANE_POINTS {
		pos := &plane_mesh.vertices[i].position
		x := cast(int) pos.x
		z := cast(int) pos.z
		// derived_y := 1.5 * sin((0.2*uniforms.tau_time) + f32(x))
		// plane_mesh.vertices[i].position.y = derived_y
		height_func(x, z, cast(^f16) &water_heightmap[i])
	}
	// Sync Debug Mesh
	// gl.BindBuffer(.ARRAY_BUFFER, water_plane._asset.VBO)
	// gl.BufferSubData(.ARRAY_BUFFER, 0, plane_mesh.vertices[:])
	// Sync 
	gl.TexSubImage2D(
		target  = .TEXTURE_2D,
		level   = 0,
		xoffset = 0,
		yoffset = 0,
		width  = AXIS_POINTS,
		height = AXIS_POINTS,
		format = gl.RED,
		type   = gl.HALF_FLOAT,
		data   = globals.water_heightmap)
}

height_func :: #force_inline proc (x, z: int, y: ^f16) {
	using globals
	using glsl
	derived_y := 1.5 * sin((0.2*uniforms.tau_time) + f32(x))
	y^ = cast(f16) derived_y
}