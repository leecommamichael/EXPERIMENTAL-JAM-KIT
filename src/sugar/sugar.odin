package sugar

import "core:time"

//////////////////////////////////////////////////////////////////////
// Common/Easy Interface
//////////////////////////////////////////////////////////////////////

viewport_size:  [2]int
mouse_position: [2]f32
mouse_delta:    [2]f32

is_key_pressed :: #force_inline proc (key: Key) -> bool {
	return input.keys[key].is_pressed
}

is_button_pressed :: #force_inline proc (btn: Gamepad_Button) -> bool {
	return input.gamepad.buttons[btn].is_pressed
}

// Instantly fires when pressed, but cannot refire without both of:
// - The debounce elapsing
// - The Switch_State releasing and re-pressing. (lmk if you want on_press_and_repeat())
on_press :: proc {
	on_key_press,
	on_button_press,
}

// Fires when releasing the key after a debounce interval.
on_release :: proc {
	on_key_release,
	on_button_release,
}

on_key_press :: proc (key: Key, debounce: time.Duration = DEFAULT_DEBOUNCE) -> bool {
	return on_switch_press(&input.keys[key], debounce)
}

on_key_release :: proc (key: Key, debounce: time.Duration = DEFAULT_DEBOUNCE) -> bool {
	return on_switch_release(&input.keys[key], debounce)
}

on_button_press :: proc (btn: Gamepad_Button, debounce: time.Duration = DEFAULT_DEBOUNCE) -> bool {
	return on_switch_press(&input.gamepad.buttons[btn], debounce)
}

on_button_release :: proc (btn: Gamepad_Button, debounce: time.Duration = DEFAULT_DEBOUNCE) -> bool {
	return on_switch_release(&input.gamepad.buttons[btn], debounce)
}

//////////////////////////////////////////////////////////////////////
// The rest of the interface
//////////////////////////////////////////////////////////////////////
init_input :: proc () {
	init_native_input()
}

on_switch_press :: proc (state: ^Switch_State, debounce: time.Duration = DEFAULT_DEBOUNCE) -> bool {
	if state.pending_trigger { return true }

	can_fire := state.is_pressed &&
	            time.tick_diff(state.last_trigger, state.prev_release) >= 0 &&
	            debounce <= time_since_action_triggered(state)
	if can_fire {
		state.pending_trigger = true
	}
	return can_fire
}

on_switch_release :: proc (state: ^Switch_State, debounce: time.Duration = DEFAULT_DEBOUNCE) -> bool {
	if state.pending_trigger { return true }

	can_fire := !state.is_pressed &&
	             time.tick_diff(state.last_trigger, state.prev_press) > 0 && // > not >=
	             debounce <= time_since_action_triggered(state)
	if can_fire {
		state.pending_trigger = true
	}
	return can_fire
}

// The world record is 16 button-presses in one second.
// This allows 20 presses per second and prevents spamming without feeling shoddy.
DEFAULT_DEBOUNCE :: 50.0 * time.Millisecond

// This isn't really necessary to use, since procs exist to use its data idiomatically.
input: Input_Frame

Switch_State :: struct {
	is_pressed:   bool,
	prev_press:   time.Tick,
	prev_release: time.Tick,
	// Fields below are used by interface procs to enable debounce.
	last_trigger:    time.Tick,
	pending_trigger: bool,
}

Gamepad_State :: struct {
	button_bits:   bit_set[Gamepad_Button; u32],
	buttons:       [Gamepad_Button]Switch_State,
	left_trigger:  f32,
	right_trigger: f32,
	left_stick:    [2]f32,
	right_stick:   [2]f32,
}

// Polling for events yields an updated Input_Frame. 
// There's only ever one frame in memory. The `tick` field uniquely identifies 
// this frame; and is written only once when polling.
Input_Frame :: struct {
	tick:    time.Tick,
	keys:    #sparse[Key]Switch_State,
	gamepad: Gamepad_State,
}

begin_input_frame :: proc () {
	input.tick = time.tick_now()
}

end_input_frame :: proc () {
	mouse_delta = 0
	// TODO?: Allocate switch state from one array and rip through it with handles.
	// Allows sugar.on_press(.Space) to return true more than once per frame,
	//   but not more often than the debounce.
	for &key in input.keys {
		if key.pending_trigger {
			key.last_trigger = input.tick
			key.pending_trigger = false
		}
	}
	for &button in input.gamepad.buttons {
		if button.pending_trigger {
			button.last_trigger = input.tick
			button.pending_trigger = false
		}
	}
}

time_since_action_triggered :: proc (action: ^Switch_State) -> time.Duration {
	return time.tick_diff(action.last_trigger, input.tick)
}

// Procs below may be used to simulate input events coming from the OS.

set_pressed :: proc {
	press_key,
	press_gamepad_button,
}

set_released :: proc {
	release_key,
	release_gamepad_button,
}

press_gamepad_button :: proc (button: Gamepad_Button) {
	press_switch(&input.gamepad.buttons[button])
}

release_gamepad_button :: proc (button: Gamepad_Button) {
	release_switch(&input.gamepad.buttons[button])
}

press_key :: proc (button: Key) {
	press_switch(&input.keys[button])
}

release_key :: proc (button: Key) {
	release_switch(&input.keys[button])
}

press_switch :: proc (it: ^Switch_State) {
	it.is_pressed = true
	it.prev_press = input.tick
}

release_switch :: proc (it: ^Switch_State) {
	it.is_pressed = false
	it.prev_release = input.tick
}
