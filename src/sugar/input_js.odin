package sugar

import "core:time"
import "core:log"
import "core:sys/wasm/js"
import "core:math/linalg"

// TODO: This is API-surface, but I don't think people would expect mouse-buttons
//       to be a "Key". Either rename "Button" or move to Pointer-API on all platforms.
Button :: enum {
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

js_key_from_code :: proc (key: string) -> Button {
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

js_mouse_button_from_event :: proc (event: js.Event) -> Button {
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


// With the exception of "Should_Exit" you don't need to handle these.
// Sugar tries to handle as many things as possible.
// This is just a way of detecting what has happened.
Feedback :: enum {
	None,
	Should_Exit,
	Resized, // the new resolution is already in global state.
}

// returns Should_Exit when the application should stop executing.
@require_results
poll_events :: proc () -> (feedback: Feedback) {
	begin_input_frame()
	if js_should_resize {
		js_should_resize = false
		return .Resized
	}
	return .None
}