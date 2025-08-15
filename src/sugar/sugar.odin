package sugar

import "core:time"

//////////////////////////////////////////////////////////////////////
// Common/Easy Interface
//////////////////////////////////////////////////////////////////////

viewport_size:  [2]int
mouse_position: [2]f32
mouse_delta:    [2]f32

is_pressed :: #force_inline proc (button: Button) -> bool {
	return input.buttons[button].is_pressed
}

// Instantly fires when pressed, but cannot refire without both of:
// - The debounce elapsing
// - The Button_State releasing and re-pressing. (lmk if you want on_press_and_repeat())
on_press :: proc (button: Button, debounce: time.Duration = DEFAULT_DEBOUNCE) -> bool {
	state: ^Button_State = &input.buttons[button]
	if state.pending_trigger { return true }

	can_fire := state.is_pressed &&
	            time.tick_diff(state.last_trigger, state.prev_release) >= 0 &&
	            debounce <= time_since_action_triggered(state)
	if can_fire {
		state.pending_trigger = true
	}
	return can_fire
}

// Fires when releasing the button after a debounce interval.
on_release :: proc (button: Button, debounce: time.Duration = DEFAULT_DEBOUNCE) -> bool {
	state: ^Button_State = &input.buttons[button]
	if state.pending_trigger { return true }

	can_fire := !state.is_pressed &&
	             time.tick_diff(state.last_trigger, state.prev_press) > 0 && // > not >=
	             debounce <= time_since_action_triggered(state)
	if can_fire {
		state.pending_trigger = true
	}
	return can_fire
}

//////////////////////////////////////////////////////////////////////
// The rest of the interface
//////////////////////////////////////////////////////////////////////

// The world record is 16 button-presses in one second.
// This allows 20 presses per second and prevents spamming without feeling shoddy.
DEFAULT_DEBOUNCE :: 50.0 * time.Millisecond

// This isn't really necessary to use, since procs exist to use its data idiomatically.
input: Input_Frame

// Polling for events yields an updated Input_Frame. 
// There's only ever one frame in memory. The `tick` field uniquely identifies 
// this frame; and is written only once when polling.
Input_Frame :: struct {
	tick:     time.Tick,
	buttons: #sparse[Button]Button_State,
}

begin_input_frame :: proc () {
	input.tick = time.tick_now()
}

end_input_frame :: proc () {
	mouse_delta = 0

	for &button in input.buttons {
		// Allows sugar.on_press(.Space) to return true more than once per frame,
		//   but not more often than the debounce.
		if button.pending_trigger {
			button.last_trigger = input.tick
			button.pending_trigger = false
		}
	}
}

Button_State :: struct {
	is_pressed:   bool,
	prev_press:   time.Tick,
	prev_release: time.Tick,
	// Fields below are used by interface procs to enable debounce.
	last_trigger:    time.Tick,
	pending_trigger: bool,
}

time_since_action_triggered :: proc (action: ^Button_State) -> time.Duration {
	return time.tick_diff(action.last_trigger, input.tick)
}

// Procs below may be used to simulate input events coming from the OS.
press_button :: proc (button: Button) {
	input.buttons[button].is_pressed = true
	input.buttons[button].prev_press = input.tick
}

release_button :: proc (button: Button) {
	input.buttons[button].is_pressed = false
	input.buttons[button].prev_release = input.tick
}
