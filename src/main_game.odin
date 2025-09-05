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
	err, tex := gl.CreateTexture()
	assert(err == nil)
	gl.glActiveTexture(gl.TEXTURE0 + 0) // A sampler can be set as i
	gl.BindTexture(.TEXTURE_2D, tex)
	gl.Set_Texture_Wrap_S(.TEXTURE_2D, .REPEAT)
	gl.Set_Texture_Wrap_T(.TEXTURE_2D, .REPEAT)
	gl.Set_Texture_Min_Filter(.TEXTURE_2D, .NEAREST)
	gl.Set_Texture_Mag_Filter(.TEXTURE_2D, .NEAREST)
	// gl.glPixelStorei(gl.UNPACK_ALIGNMENT,2) // TODO: abstract this global state in texture loader.
	gl.TexImage2D(
		.TEXTURE_2D,
		0, // LOD
		cast(int) gl.R16F,
		AXIS_POINTS,
		AXIS_POINTS,
		gl.RED,
		gl.FLOAT,
		globals.water_heightmap)

	err2, atlas_tex := gl.CreateTexture()
	assert(err2 == nil)
	gl.glActiveTexture(gl.TEXTURE0 + 0) // A sampler can be set as i
	gl.BindTexture(.TEXTURE_2D, atlas_tex)
	gl.Set_Texture_Wrap_S(.TEXTURE_2D, .REPEAT)
	gl.Set_Texture_Wrap_T(.TEXTURE_2D, .REPEAT)
	gl.Set_Texture_Min_Filter(.TEXTURE_2D, .LINEAR)
	gl.Set_Texture_Mag_Filter(.TEXTURE_2D, .LINEAR)
	log.infof("teximage2d atlas %v", globals.assets.font_atlas)
	gl.TexImage2D(
		.TEXTURE_2D,
		0, // LOD
		cast(int) gl.RGB8,
		globals.assets.font_atlas.width,
		globals.assets.font_atlas.height,
		gl.RGB,
		gl.UNSIGNED_BYTE,
		globals.assets.font_atlas.pixels.buf[:])


	hello: ^Text_Entity
	hello = text(`hello`)
	hello.position = Vec3{100,100,0}
}

// Mixed-scope between renderer and game entities.
game_step :: proc (dt: f64) {
	globals.game_view = tick_mouse_camera(&globals.camera, f32(dt))
	// step_water(dt)
}

AXIS_SQUARES  :: 100 // Squares per axis
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
		height_func(x, z, cast(^f32) &water_heightmap[i])
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
		type   = gl.FLOAT,
		data   = globals.water_heightmap)
}

height_func :: #force_inline proc (x, z: int, y: ^f32) {
	using globals
	using glsl
	derived_y := 1.5 * sin((0.2*uniforms.tau_time) + f32(x))
	y^ = cast(f32) derived_y
}