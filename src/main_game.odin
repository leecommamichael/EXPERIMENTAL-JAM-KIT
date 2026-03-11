package main

import "base:runtime"
import gl "angle"
import "core:mem/virtual"
import "core:sys/windows"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:time"
import "core:log"
import "sugar"
import "audio"

@export
hot_reload :: proc (engine_globals: ^Globals, engine_gs: ^Game_State) {
	ensure(engine_gs != nil)
	ensure(engine_globals != nil)
	gs = engine_gs
	globals = engine_globals
	sugar.set_memory(&globals.sugar)
	sugar.load_gl()
	globals.hot_reloaded_this_frame = true
}

////////////////////////////////////////////////////////////////////////////////
// Wave Racer
////////////////////////////////////////////////////////////////////////////////
// RG35SP_RES: Vec2 = {640, 480}
// STEAM_DECK_RES: Vec2 = {1280, 800}
RES_X :: 1000
RES_Y :: 800
RES_SCALE :: 1

gs: ^Game_State

game_init :: proc () {
	gl.BindSampler(cast(u32) Texture_Unit.Framebuffer_Texture, globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Texture,             globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Font,                globals.ren.nearest_sampler)
	globals.cursor = make_entity()
	globals.cursor.flags += {.Hidden}
	globals.cursor.position.xy = globals.mouse_position.xy
	globals.draw_colliders = false
	globals.canvas_size_px = array_cast([2]int{RES_X, RES_Y}, f32)
	globals.canvas_scaling = .Integer_Aspect
	globals.canvas_stretching = .None

	r := rand.create(10)
	context.random_generator = rand.default_random_generator(&r)

	gs = new(Game_State)

	gs.sfx_sink = audio.make_sink(&globals.audio, "sfx")
	gs.music_sink = audio.make_sink(&globals.audio, "music")
	// 1. Clips are already loaded from the asset bundler.
	// Just have to init their platform.
	defer for _, &asset in globals.assets.audio {
		audio.add_source_from_clip(&globals.audio, asset)
	}

	gs.facing = {0,0,1}

	rows :: 512
	cols :: 512
	verts :: rows * cols + (rows/2)
	gs.water_static_verts = {
		make([dynamic]Ren_Vertex_Base, verts),
		make([dynamic]u32, 0, 3*((2*(rows-1)*(cols-1)) + (rows-1)) )
	}

	assert(cols > 1)
	assert(rows > 1)
	X_GAP: f32 : 1
	Z_GAP: f32 : 0.866025 // sqrt(3)/2 for equilateral
	long_row: bool = false
	row: int = 0
	col: int = 0
	for i in 0..<u32(verts) {
		if ( long_row && col % (cols+1) == 0  \
		||  !long_row && col %  cols    == 0) && col > 0 {
			col = 0
			row += 1
			long_row = !long_row
		}

		if long_row && col > 0 { // Avoids top and left edges
			a: u32 = i-(cols+1)
			b: u32 = i-cols
			c: u32 = i-1
			d: u32 = i
			e: u32 = i+cols
			f: u32 = i+(cols+1)
			if row == rows-1 {
				if col == cols { // BOTTOM RIGHT EDGE
					append(&gs.water_static_verts.indices, d,a,c)
				} else {          // BOTTOM EDGE
					append(&gs.water_static_verts.indices, d,b,a, d,a,c)
				}
			} else {
				if col == cols { // RIGHT EDGE
					append(&gs.water_static_verts.indices, d,a,c, d,c,e)
				} else {           // COMMON CASE
					append(&gs.water_static_verts.indices, d,b,a, d,a,c)
					append(&gs.water_static_verts.indices, d,c,e, d,e,f)
				}
			}
		}

		x_inset: f32 = long_row ? -f32(X_GAP)/2 : 0
		// x_inset: f32 = 0
		gs.water_static_verts.vertices[i].position.x = x_inset + f32(col) * X_GAP
		gs.water_static_verts.vertices[i].position.z =           f32(row) * Z_GAP
		col += 1
	}
} // game_init


@export
game_step :: proc () {
	gamepad := globals.sugar.input.gamepad
	rt := precision(gamepad.right_trigger, 2)
	lt := precision(gamepad.left_trigger, 2)
	ls := gamepad.left_stick
	r_input := precision(ls.x, 2)

	v := gs.v
	r := gs.r
	facing := gs.facing

	v_max: f32 : 7.0
	v_min: f32 : -v_max * 0.5

	a_input: f32 = rt - lt
	a_max: f32 = v_max * globals.tick / 1.0 // K*tick/N = hit K speed after N seconds from rest.
	a_min: f32 = -a_max
	a_coast: f32 = -0.66*a_max
	a: f32 = clamp(a_input, a_min, a_max)
	if a_input == 0 { // coast
		if v > 0 { // coast-down
			a = a_coast
			if sign(v + a) != sign(v) { v = 0; a = 0 }
		} else if v < 0 { // coast-up
			a = -a_coast
			if sign(v + a) != sign(v) { v = 0; a = 0 }
		}
	}

	if a != 0 { // Intent: Disallow steering in-place.
		steer_rate := 2*globals.tick // radians
		gs.r += r_input * steer_rate * (v < 0 ? -1 : 1)
		gs.facing = normalize( (FRONT4 * glsl.mat4Rotate(UP,-r)).xyz )
	}

	gs.v = clamp(v + a, v_min, v_max)

	vehicle, new_vehicle := mesh(&boat_mesh)
	if new_vehicle {
		vehicle.flags += {.Is_3D}
		vehicle.draw_command.program = globals.ren.programs[.Phong]
		vehicle.position.z = 0.5
	}
	vehicle.position += (v*facing) * globals.tick
	vehicle.rotation.y = r
	vehicle.flags += {.Collider_Enabled}
	vehicle.collider.shape = .Circle
	vehicle.collider.size = 1.5 // ground-probe
	globals.draw_colliders = true

	globals.camera.position = vehicle.position + -facing*6
	globals.camera.position.y = vehicle.position.y + 3
	globals.camera.up_rad = r

	isle1, _ := sphere()
	isle1.color.a = 0.5
	isle1.position = {-10, 0, 10}
	isle1.basis.scale = 3
	isle1.scale = 3 // collider
	isle1.flags += {.Collider_Enabled}
	isle1.collider.shape = .Circle
	isle1.collider.size = isle1.basis.scale

	isle2, _ := sphere()
	isle2.position = { 10, 0, 20}
	isle2.scale = isle1.scale

	isle3, _ := sphere()
	isle3.position = {-10, 0, 30}
	isle3.scale = isle1.scale

	isle4, _ := sphere()
	isle4.position = { 10, 0, 40}
	isle4.scale = isle1.scale

	water := mesh_from_geom(&gs.water_static_verts)
	water.position = 0
	water.flags += {.Is_3D,}
	water.draw_command.program = globals.ren.programs[.Water]
	water.color = color("69f9")

	@static carr: Geom_Mesh2
	arr, nua := get_entity(); if nua || globals.hot_reloaded_this_frame {
		carr = geom_make_arrow({0,1,0}, allocator=context.allocator)
		arr.flags += {.Is_3D}
		arr.draw_command = ren_make_phong_draw_cmd(
			globals.instance_buffer,
			cast(int) arr.id,
			carr.vertices[:],
			carr.indices[:])
	}

	globals.uniforms.lights[0].position = {0,2,0}
	globals.uniforms.lights[0].power = .2
	globals.uniforms.lights[1].position = {0,-200,0}
	globals.uniforms.lights[1].power = .2
	globals.uniforms.num_lights = 2

	arr.position = globals.uniforms.lights[0].position
	arr.blend_normals = true
	arr.color = {0,1,0,1}

	if sugar.key_held(.Up_Arrow) {
	}
	if sugar.key_held(.Down_Arrow) {
	}
	globals.perspective_view = camera_view_matrix(&globals.camera)//tick_mouse_camera(&globals.camera, globals.tick)
} // game step
