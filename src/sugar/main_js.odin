package sugar

import "base:runtime"
import "core:log"
import "core:sys/wasm/js"
import "core:math/linalg"
import gl "../nord_gl"

platform_calls_step :: true
js_should_capture_pointer := false
js_should_release_pointer := false
js_should_resize: bool = false

Window :: int // TODO

g_window: Window

canvas_id :: "the_canvas"

init :: proc () {}
init_native_input :: proc () {}

list_displays :: proc () -> []Display {
	@static stub: [1]Display = {}
	return stub[:]
}

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

capture_cursor :: proc () {
	js_should_capture_pointer = true
}

release_cursor :: proc () {
	js_should_release_pointer = false
}

set_cursor_visible :: proc (show: bool) {
	value := "" if show else "none"
	js.set_element_style(canvas_id, "cursor", value)
}

@export
canvas_resize_callback :: proc (w,h: f64) {
	log.infof("resized: %v,%v", w, h)
	js_should_resize = true
	pixels_per_css_pixel := js.device_pixel_ratio()
	wpx := cast(int) (pixels_per_css_pixel * w)
	hpx := cast(int) (pixels_per_css_pixel * h)
	viewport_size = {wpx, hpx}
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


Gamepad_Button :: enum u32 {
	Start          ,
	Select         ,
	A              ,
	B              ,
	X              ,
	Y              ,
	Up             ,
	Down           ,
	Left           ,
	Right          ,
	Left_Shoulder  ,
	Right_Shoulder ,
	Left_Stick     ,
	Right_Stick    ,
}

Key :: enum {
	None,

	Escape,
	Left_Mouse,
	Right_Mouse,
	Left_Arrow,
	Right_Arrow,
	Up_Arrow,
	Down_Arrow,
	Space,
	W,
	A,
	S,
	D,
}

js_key_from_code :: proc (key: string) -> Key {
	switch key {
	case "Escape":    return .Escape
	case "ArrowLeft": return .Left_Arrow
	case "ArrowRight":return .Right_Arrow
	case "ArrowUp":   return .Up_Arrow
	case "ArrowDown": return .Down_Arrow
	case "Space":     return .Space
	case "KeyW":      return .W
	case "KeyA":      return .A
	case "KeyS":      return .S
	case "KeyD":      return .D
	}
	return .None
}

js_mouse_button_from_event :: proc (event: js.Event) -> Key {
	switch event.mouse.button {
	case 0: return .Left_Mouse
	// case 1: Wheel_Button,
	case 2: return .Right_Mouse
	// case 3: Back_Button,
	// case 4: Forward_Button,
	}
	return .None
}

on_key_down :: proc (event: js.Event) {
	virtual_keycode := js_key_from_code(event.key.code)

	// Don't process key repeats. Those are for text editing, not games.
	if event.key.repeat { return }

	press_key(virtual_keycode)
}

on_key_up :: proc (event: js.Event) {
	virtual_keycode := js_key_from_code(event.key.code)
	release_key(virtual_keycode)
}

on_pointer_move :: proc (event: js.Event) {
	mouse_position = linalg.array_cast(event.mouse.offset, f32)
	// Deltas are zeroed each input frame.
	mouse_delta += linalg.array_cast(event.mouse.movement, f32)
}

on_pointer_up :: proc (event: js.Event) {
	release_key(js_mouse_button_from_event(event))
}

on_pointer_down :: proc (event: js.Event) {
	press_key(js_mouse_button_from_event(event))
}

// returns Should_Exit when the application should stop executing.
@require_results
poll_events :: proc () -> (feedback: bit_set[Feedback]) {
	begin_input_frame()
	if js_should_resize {
		js_should_resize = false
		feedback += { .Window_Resized }
	}
	return feedback
}