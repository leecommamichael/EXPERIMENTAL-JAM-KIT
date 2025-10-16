package main

import "base:runtime"
import "core:time"
import "core:log"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "sugar"
import "audio"

create_sublime_text_logger :: proc () -> log.Logger {
		return log.create_console_logger(lowest = log.Level.Debug, opt = { .Level, })
}
frame_number: uint = 0
import "core:fmt"
main :: proc() {
	log_time("initializing platform")
	when !sugar.platform_calls_step {
		context.logger = create_sublime_text_logger()
	} else when ODIN_OS == .JS {
		runtime.default_context_ptr().logger = create_sublime_text_logger()
		context = runtime.default_context_ptr()^
	}
	_, k := audio.init(); assert(k)
	sugar.init_input()
	asset_init()
	displays := sugar.list_displays()
	display := displays[1] if len(displays) > 1 else displays[0]
	log.debugf("Display: %v", display)
	ok := sugar.create_window(
		[4]int{0,0, 800, 800} + {8,44,0,0},
		"Wave Racer",
		use_gl = true
	)
	if !ok { panic("Window creation failed.") }
	log_time("initializing platform")

	log_time("initializing framework")
	asset_upload()
	framework_init()
	log_time("initializing framework")

	// sugar.capture_cursor()
	// sugar.set_cursor_visible(false)

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
		log_runtime("first_paint")
	}
	switch sugar.poll_events() { // begins input frame.
	case .Should_Exit: return false
	case .Resized:     viewport_resized(sugar.viewport_size)
	case .None:
	}

	if sugar.on_key_release(.Escape) || sugar.on_button_release(.Select) {
		return false
	}

	framework_step(dt)

	sugar.end_input_frame()
	free_all(context.temp_allocator)
	return true
}

// TODO: Read various data from Globals such that the game
//       can program the camera simply by setting parameters.
viewport_resized :: proc (res: [2]int) {
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
		top    = cast(f32) res.y,
		bottom = 0,
		near   = -10,
		far    = 1000
	)
}

