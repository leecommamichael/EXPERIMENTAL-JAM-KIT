package main

import "base:runtime"
import gl "angle"
import "core:mem/virtual"
import "core:sys/windows"
import "core:math/rand"
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

	globals.camera.position.y = 1.7
	globals.camera.position.z = -1.7
} // game_init


@export
game_step :: proc () {
	globals.perspective_view = tick_mouse_camera(&globals.camera, globals.tick)

	sphere, _ := sphere()
	sphere.position = {0,1,0}
	sphere.color = color("f00")
	sphere.draw_command.cull_mode = .Front_Faces
	// sphere.color.a = 0.55

	vehicle := mesh(&boat_mesh)
	vehicle.draw_command.program = globals.ren.programs[.Phong]
	vehicle.basis.scale.xz = 1
	vehicle.position.z = 0
	vehicle.flags += {.Is_3D}


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
} // game step

boat_mesh: []Vec3 = {
  // --- BOTTOM FACE (y=0) ---
  {0,0,0}, {1, 0, -1}, {1, 0, 1},
  {0,0,0}, {-1, 0, -1}, {1, 0, -1},
  {0,0,0}, {-1, 0, 1}, {-1, 0, -1},
  {0,0,0}, {-1, 0, 1}, {1, 0, 1}, 
  {-1, 0, 1}, {1, 0, 1}, {0, 0, 2},

  // --- TOP FACE (y=1) ---
  {0,1,0}, {1, 1, -1}, {1, 1, 1},
  {0,1,0}, {-1, 1, -1}, {1, 1, -1},
  {0,1,0}, {-1, 1, 1}, {-1, 1, -1},
  {0,1,0}, {-1, 1, 1}, {1, 1, 1}, 
  {-1, 1, 1}, {1, 1, 1}, {0, 1, 2},

  // --- SIDE WALLS (Connecting y=0 to y=1) ---
  
  // Right Wall
  {1, 0, -1}, {1, 1, -1}, {1, 1, 1},
  {1, 0, -1}, {1, 1, 1}, {1, 0, 1},

  // Front-Right Wall (to Tip)
  {1, 0, 1}, {1, 1, 1}, {0, 1, 2},
  {1, 0, 1}, {0, 1, 2}, {0, 0, 2},
// Front-Left Wall (from Tip)
  {0, 0, 2}, {0, 1, 2}, {-1, 1, 1},
  {0, 0, 2}, {-1, 1, 1}, {-1, 0, 1},

  // Left Wall
  {-1, 0, 1}, {-1, 1, 1}, {-1, 1, -1},
  {-1, 0, 1}, {-1, 1, -1}, {-1, 0, -1},

  // Back Wall
  {-1, 0, -1}, {-1, 1, -1}, {1, 1, -1},
  {-1, 0, -1}, {1, 1, -1}, {1, 0, -1},
}

trigger_test :: proc () {
		defer {
		txt := text("Trigger Pressure Experiment", .bold_pixel)
		txt.position.xy = 8
	}

	gamepad := globals.sugar.input.gamepad
	pressure := gamepad.right_trigger
	pressure = precision(pressure, 2) // DENOISE INPUT. 1000 values.
	@static _pp: f32; defer _pp = pressure
	@static _pp2: f32; defer _pp2 = _pp
	prev_pressure := pressure == 0 ? max(_pp, _pp2) : min(_pp, _pp2)
	d_pressure: f32 = pressure - prev_pressure


	shake_debounce :: .030
	shake_duration :: .150
	@static since_shake: f32 = 0; since_shake += globals.dt
	shook: bool
	can_play := since_shake > shake_debounce
	shake_alpha: f32 = clamp((shake_duration - since_shake) / shake_duration, 0, 1)
	@static shake_power: f32 = 0

	if can_play && pressure >= 1 && d_pressure != 0 {
		shook = true
		since_shake = 0
		shake_power = d_pressure
		sfx := abs(d_pressure) >= 1 ? "LTTP_Text_Done.ogg" : "LTTP_Text_Letter.ogg"
		audio.play(&globals.audio, gs.sfx_sink, sfx, shake_power)
	}

	basis: Vec2 = 44
	if shake_alpha != 0 {
		basis += {
			0,
			6 * shake_power * shake_alpha * sin(shake_alpha)
		}
	}

	bg := rect()
	bg.position.xy = 44 - 11
	bg.scale = 66
	bg.color = 0.4

	bg2 := rect()
	bg2.position.xy = basis
	bg2.scale = 44
	bg2.color = 0.6

	curved_fill := rect()
	curved_fill.position.xy = basis
	curved_fill.scale.x = 44
	curved_fill.color.rbg = 0.7
	curved_fill.scale.y = 44 * midtone(pressure, 2.0)

	@static last_d_pressure: f32
	if shook {
		last_d_pressure = d_pressure
	}
	pressure_label: string = fmt.tprintf("Shake %2.1f", abs(last_d_pressure))
	txt := text(pressure_label, .bold_pixel)
	txt.position.y = 44 + 55 + 4
	txt.position.x = 44 - 10 }
