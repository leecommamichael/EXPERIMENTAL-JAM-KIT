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
	gl.BindSampler(cast(u32) Texture_Unit.Heightmap,           globals.ren.nearest_sampler)
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
	gs.water_static_verts = geom_make_hexgrid(WAVE_MAP_SIZE_X/2, WAVE_MAP_SIZE_Z/2, DENSITY)
	
	gs.heightmap_texture = {
		target = .TEXTURE_2D,
		format = .R32F,
	}
	
	tex_ok := init_and_upload_texture(
		cast(u32) Texture_Unit.Heightmap,
		&gs.heightmap_texture,
		nil,
		{WAVE_MAP_SIZE_X, WAVE_MAP_SIZE_Z})
	assert(tex_ok)
	init_kernel(&gs.kernel)
} // game_init

init_kernel :: proc (kernel: ^[13][13]f32) {
	dk:    f32 = 0.01
	sigma: f32 = 1.0
	norm:  f32 = 0.0
	for k: f32 = 0; k < 10; k += dk { // k/dk iterations
		norm += k*k*exp(-sigma*k*k)
	}
	for i in -6..=6 do for j in -6..=6 {
		r: f32 = sqrt(f32(i*i) + f32(j*j))
		kern: f32 = 0
		for k: f32 = 0; k < 10; k += dk { // k/dk iterations
			kern += k*k*exp(-sigma*k*k) * f32(bessel(f64(r*k)))
		}
		kernel[i+6][j+6] = kern/norm
	}
}

step_partial_derivative :: #force_inline proc (
	w, h: int,
	kernel: [13][13]f32,
	height:               [WAVE_MAP_SIZE]f32,
	vertical_derivative: ^[WAVE_MAP_SIZE]f32,
) #no_bounds_check {
	for ix in 6..<w-6 do for iy in 6..<h-6 {
		i := ix + w * iy
		vd: f32
		for iix in -6..=6 do for iiy in -6..=6 {
			_i := ix + iix + w*(iy+iiy)
			vd += kernel[iix+6][iiy+6] * height[_i]
		}
		vertical_derivative[i] = vd
	}
}


step_wave_height :: #force_inline proc (
	w, h: int,
	kernel:             [13][13]f32,
	height:              ^[WAVE_MAP_SIZE]f32,
	prev_height:         ^[WAVE_MAP_SIZE]f32,
	vertical_derivative: ^[WAVE_MAP_SIZE]f32,
) #no_bounds_check {
	dt: f32 = globals.tick
	alpha :: 1.00 // lower is slower and spreads more
	gravity := 9.8 * dt * dt
	step_partial_derivative(w, h, kernel, height^, vertical_derivative)
	adt := alpha * dt
	adt2 := 1.0/(1+adt)
	for i in 0..<WAVE_MAP_SIZE {
		temp := height[i]
		defer prev_height[i] = temp
		height[i] = height[i]*(2-adt) - prev_height[i] - gravity*vertical_derivative[i]
		height[i] *= adt2
		
		x := i / WAVE_MAP_SIZE_X
		z := i % WAVE_MAP_SIZE_Z
		xz: Vec2 = array_cast([2]int{x,z}, f32)
		if is_nearly(gs.kart.position.zx*(1.0/DENSITY), xz, 1.5) {
			height[i] += 0.010
		}
	}
}

_2d_demo_step :: proc () {
	step_wave_height(WAVE_MAP_SIZE_X, WAVE_MAP_SIZE_Z,
		gs.kernel, &gs.height, &gs.prev_height, &gs.vertical_derivative)

	set_texture_unit(.Heightmap)	
	upload_pixels_to_texture(
		&gs.heightmap_texture,
		to_bytes(gs.height[:]),
		{WAVE_MAP_SIZE_X, WAVE_MAP_SIZE_Z})
	set_texture_unit(.Swap)	

	b := rect()
	b.basis.scale.xy = { WAVE_MAP_SIZE_X+8, WAVE_MAP_SIZE_Z+8 }
	b.position.xy = 10-4
	b.color = color("222")
	r := rect()
	r.basis.scale.xy = { WAVE_MAP_SIZE_X, WAVE_MAP_SIZE_Z }
	r.position.xy = 10

	// b.basis.scale.xy *= 2
	// r.basis.scale.xy *= 2

	hot_reloaded_shader(r,
		vert= vertex_preamble + basic_vertex_inputs + `
		out vec4 color;
		out vec3 raw_surface_normal;
		out vec3 world_position;
		out vec2 uv;

		void main() {
			color = i_color;
			raw_surface_normal = v_normal;
			uv = v_position.xy;
			vec4 position4 = vec4(v_position, 1);
			world_position = (i_model_mat * position4).xyz;
			mat4 mvp = frame.projection * frame.view * i_model_mat;
			gl_Position = mvp * position4;
		}`,
		frag= fragment_preamble + `
		in vec4 color;
		in vec3 raw_surface_normal;
		in vec3 world_position;
		in vec2 uv;
		uniform sampler2D heightmap;

		out vec4 outColor;
		void main() {
			float texel = texture(heightmap, uv).r;
			outColor = vec4(texel) + 0.5;
		}`
	)
}


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
		gs.kart = vehicle
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
	// water.position.x = -128/2*DENSITY
	// water.position.z = -6/2*DENSITY
	// water.basis.scale.xz = 10
	water.flags += {.Is_3D,}
	water.draw_command.program = globals.ren.programs[.Water]
	water.color = color("69f")
	water.blend_normals = true

		step_wave_height(WAVE_MAP_SIZE_X, WAVE_MAP_SIZE_Z,
			gs.kernel, &gs.height, &gs.prev_height, &gs.vertical_derivative)

		set_texture_unit(.Heightmap)	
		upload_pixels_to_texture(
			&gs.heightmap_texture,
			to_bytes(gs.height[:]),
			{WAVE_MAP_SIZE_X, WAVE_MAP_SIZE_Z})
		set_texture_unit(.Swap)	

		// hot_reloaded_shader(water,
		// 	vert= vertex_preamble + basic_vertex_inputs + `
		// 	out vec4 color;
		// 	out vec3 raw_surface_normal;
		// 	out vec3 world_position;
		// 	uniform sampler2D heightmap;

		// 	void main() {
		// 		vec2 uv = v_position.xz / vec2(128);
		// 		float heightmap_texel = texture(heightmap, uv).r;
		// 		color = i_color;
		// 		raw_surface_normal = v_normal;
		// 		vec4 position4 = vec4(v_position, 1);
		// 		position4.y += heightmap_texel;
		// 		world_position = (i_model_mat * position4).xyz;
		// 		mat4 mvp = frame.projection * frame.view * i_model_mat;
		// 		gl_Position = mvp * position4;
		// 	}`,
		// 	frag= fragment_preamble + `
		// 	in vec4 color;
		// 	in vec3 raw_surface_normal;
		// 	in vec3 world_position;

		// 	out vec4 outColor;
		// 	void main() {
		// 		outColor = color;
		// 		outColor.a = 1.0;
		// 	}`
		// )

	globals.uniforms.lights[0].position = {0,1,2}
	globals.uniforms.lights[0].power = .4
	globals.uniforms.lights[1].position = {10,1,10}
	globals.uniforms.lights[1].power = .2
	globals.uniforms.lights[2].position = {0,200,0}
	globals.uniforms.lights[2].power = .05
	globals.uniforms.num_lights = 2


	if sugar.key_held(.Up_Arrow) {
	}
	if sugar.key_held(.Down_Arrow) {
	}
	globals.perspective_view = camera_view_matrix(&globals.camera)//tick_mouse_camera(&globals.camera, globals.tick)
} // game step
