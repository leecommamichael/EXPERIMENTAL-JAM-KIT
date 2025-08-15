package main

import "core:time"
import "core:log"
import sugar "sugar"

create_sublime_text_logger :: proc () -> log.Logger {
		return log.create_console_logger(lowest = log.Level.Debug, opt = { .Level, })
} 

main :: proc() {
	when !sugar.platform_calls_step {
		context.logger = create_sublime_text_logger()
	} else when ODIN_OS == .JS {
		runtime.default_context_ptr().logger = create_sublime_text_logger()
	}
	ok := sugar.create_window([4]int{0,0, 900, 900}, "Wave Racer", use_gl = true)
	if !ok { panic("Window creation failed.") }

	app_init()
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
	switch sugar.poll_events() {
	case .Should_Exit: return false
	case .Resized:     resolution_changed(sugar.viewport_size)
	case .None:
	}

	if sugar.on_release(.Escape) {
		return false
	}

	app_step(dt)

	sugar.end_input_frame()
	return true
}
