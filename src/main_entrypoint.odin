package main

// Purpose: This file is the integration of various platforms and Odin.

import "base:runtime"
import "core:time"
import "core:log"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "sugar"

create_sublime_text_logger :: proc () -> log.Logger {
		return log.create_console_logger(lowest = log.Level.Debug, opt = { .Level, })
}

frame_number: uint = 0

main :: proc() {
	sugar.init_input()
	log_time("first_paint")
	log_time("initializing platform")
	when !sugar.platform_calls_step {
		context.logger = create_sublime_text_logger()
	} else when ODIN_OS == .JS {
		runtime.default_context_ptr().logger = create_sublime_text_logger()
		context = runtime.default_context_ptr()^
	}
	ok := sugar.create_window([4]int{0,0, 900, 900}, "Wave Racer", use_gl = true)
	if !ok { panic("Window creation failed.") }
	log_time("initializing platform")

	log_time("initializing framework")
	framework_init()
	log_time("initializing framework")

	sugar.capture_cursor()
	sugar.set_cursor_visible(false)

	when !sugar.platform_calls_step {
		tick := time.tick_now()
		dt: f64
		for {
			dt = time.duration_seconds(time.tick_lap_time(&tick))
			step(dt) or_break
			sugar.swap_buffers()
		}
	}
}

// This is an entry-point, and so all game data must be globally visible for Web support.
// The context is defaulted each time you enter. Related: `runtime.default_context_ptr()`
@export
step :: proc (dt: f64) -> bool {
	frame_number += 1
	if frame_number == 2 {
		log_time("first_paint")
	}
	defer free_all(context.temp_allocator)
	switch sugar.poll_events() { // begins input frame.
	case .Should_Exit: return false
	case .Resized:     resolution_changed(sugar.viewport_size)
	case .None:
	}

	if sugar.on_key_release(.Escape) || sugar.on_button_release(.Select) {
		return false
	}

	framework_step(dt)

	sugar.end_input_frame()
	return true
}

// TODO: Read various data from Globals such that the game
//       can program the camera simply by setting parameters.
resolution_changed :: proc (res: [2]int) {
	aspect_ratio := cast(f32)res.x / cast(f32)res.y
	globals.game_camera = linalg.matrix4_perspective_f32(
		fovy   = linalg.to_radians(f32(90.0)),
		aspect = aspect_ratio,
		near   = .1,
		far    = 1000,
		flip_z_axis = false
	)
	globals.ui_orthographic = glsl.mat4Ortho3d(
		left   = 0,
		right  = cast(f32) res.x,
		top    = 0,
		bottom = cast(f32) res.y,
		near   = -10,
		far    = 1000
	)
}

