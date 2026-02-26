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
// Aster
////////////////////////////////////////////////////////////////////////////////
// RG35SP_RES: Vec2 = {640, 480}
// STEAM_DECK_RES: Vec2 = {1280, 800}
RES_X :: 800
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
	globals.canvas_scaling = .None
	globals.canvas_stretching = .Integer_Aspect
	globals.canvas_stretching = .Integer_Aspect

	r := rand.create(10)
	context.random_generator = rand.default_random_generator(&r)

	gs = new(Game_State)

	gs.sfx_sink = audio.make_sink(&globals.audio, "sfx")
	gs.music_sink = audio.make_sink(&globals.audio, "music")
	// 1. Clips are already loaded from the asset bundler.
	// Just have to init their platform.
	for _, &asset in globals.assets.audio {
		audio.add_source_from_clip(&globals.audio, asset)
	}
	// audio.play(&globals.audio, gs.music_sink, "music_flower_duet.ogg")
} // game_init

@export
game_step :: proc () {
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
	t := text(pressure_label, .bold_pixel)
	t.position.y = 44 + 55 + 4
	t.position.x = 44 - 10

	globals.camera.position.y = 2
	globals.perspective_view = tick_mouse_camera(&globals.camera, globals.tick)

	vehicle := mesh([]Vec3{
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
	})

	vehicle.draw_command.mode = .Triangles
	vehicle.basis.scale.xz = 1
	vehicle.position.z = 0
	vehicle.flags += {.Is_3D}

	// cylinder
	@static cm: Geom_Mesh2
	cylinder, nu := get_entity()
	if nu {
		cm = geom_make_cylinder({0,1,0}, context.allocator)
		cylinder.flags += {.Is_3D}
		cylinder.draw_command = ren_make_basic_draw_cmd(
			globals.instance_buffer,
			cast(int) cylinder.id,
			cm.vertices[:],
			cm.indices[:],
			)
		cylinder.color = color("f44")
		cylinder.position = {2,1.9,2}
		cylinder.draw_command.mode = .Lines
	}

	floor := mesh([]Vec3{
		{-1, 0, -1}, { 1, 0, -1}, { 1, 0,  1},  
		{ 1, 0,  1}, {-1, 0,  1}, {-1, 0, -1}
	})
	floor.position.z = 0
	log.infof("%#v", floor.position)

	floor.color = color("55f")
	// floor.draw_command.mode = .Lines
	floor.flags += {.Is_3D}
	floor.basis.scale.xz = 100

	// switch {
	// case pressure > 5.0/6.0: pressure = 5.0/5.0
	// case pressure > 4.0/6.0: pressure = 4.0/5.0
	// case pressure > 3.0/6.0: pressure = 3.0/5.0
	// case pressure > 2.0/6.0: pressure = 2.0/5.0
	// case pressure > 1.0/6.0: pressure = 1.0/5.0
	// case: pressure = 0
	// }

	if sugar.on_key_release(.Up_Arrow) {
	}
	if sugar.on_key_release(.Down_Arrow) {
	}
} // game step

