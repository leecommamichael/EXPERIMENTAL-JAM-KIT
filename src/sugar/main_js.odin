package sugar

import "base:runtime"
import "core:log"
import "core:sys/wasm/js"
import gl "../nord_gl"

platform_calls_step :: true

Window :: int // TODO

g_window: Window

canvas_id :: "the_canvas"

@require_results
create_window :: proc (
  rect: [4]int, // xywh
  title: string,
  use_gl: bool // Would be a better build constant like SUGAR_GL
) -> bool {

	if use_gl {
	  ctx := gl.CreateCurrentContextById(canvas_id, {})
	  if !ctx {
	    panic("Context no good.")
	  }
	  assert(ctx, "WebGL2 unsupported.")
	}
	// ok := js.add_resize_observer(canvas_id, on_canvas_resize)
	// assert(ok, "failed to add resize observer")
	js.add_event_listener(canvas_id, .Pointer_Move, user_data = nil, callback = js_on_canvas_event)
	js.add_event_listener(canvas_id, .Pointer_Up,   user_data = nil, callback = js_on_canvas_event)
	js.add_event_listener(canvas_id, .Pointer_Down, user_data = nil, callback = js_on_canvas_event)
	js.add_event_listener(canvas_id, .Key_Up,       user_data = nil, callback = js_on_canvas_event)
	js.add_event_listener(canvas_id, .Key_Down,     user_data = nil, callback = js_on_canvas_event)
	js.add_event_listener(canvas_id, .Wheel,        user_data = nil, callback = js_on_canvas_event)
	js.add_event_listener(canvas_id, .Scroll,       user_data = nil, callback = js_on_canvas_event)
	js.add_event_listener(canvas_id, .Gamepad_Connected,     user_data = nil, callback = js_on_canvas_event)
	js.add_event_listener(canvas_id, .Gamepad_Disconnected,  user_data = nil, callback = js_on_canvas_event)
	return true
}

swap_buffers :: proc () {
	// Unsure if possible/needed.
}

js_should_capture_pointer := false
capture_cursor :: proc () {
	js_should_capture_pointer = true
}

js_should_release_pointer := false
release_cursor :: proc () {
	js_should_release_pointer = false
}

set_cursor_visible :: proc (show: bool) {
	value := "" if show else "none"
	js.set_element_style(canvas_id, "cursor", value)
}

js_should_resize: bool = false
@export
canvas_resize_callback :: proc (w,h: f64) {
	log.infof("resized: %v,%v", w, h)
	js_should_resize = true
	pixels_per_css_pixel := js.device_pixel_ratio()
	wpx := cast(int) (pixels_per_css_pixel * w)
	hpx := cast(int) (pixels_per_css_pixel * h)
	g_state.resolution = {wpx, hpx}
}

// Convert callback to pollable structure.
js_on_canvas_event :: proc (event: js.Event) {
	#partial switch event.kind {
	case .Pointer_Move: on_pointer_move(event)
	case .Pointer_Up:   on_pointer_up(event)
	case .Pointer_Down: on_pointer_down(event)
	case .Key_Up:       on_key_up(event)
	case .Key_Down:     on_key_down(event)
	case .Wheel:        // TODO

	case .Scroll:       // TODO? (prevent?)

	case .Gamepad_Connected: // TODO
	case .Gamepad_Disconnected: // TODO
	}
}