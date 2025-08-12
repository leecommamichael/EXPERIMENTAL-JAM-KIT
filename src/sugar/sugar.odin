package sugar

import "core:time"

g_state: State

State :: struct {
	input: Input_Frame,
	resolution: [2]int,
}

//////////////////////////////////////////////////////////////////////
// Input Interface
//////////////////////////////////////////////////////////////////////

Input_Frame :: struct {
	tick: time.Tick,
	keys: #sparse[Key]Button,
	mouse: Mouse,
}

Mouse :: struct {
	window: [2]f32,
	delta:  [2]f32,
}

Button :: struct {
	is_pressed: bool,
	prev_press:   time.Tick,
	prev_release: time.Tick,
}

Button_Action :: struct {
	button:       ^Button,
	debounce:      time.Duration,
	last_trigger:  time.Tick,
}

time_since_last_trigger :: proc (action: ^Button_Action) -> time.Duration {
	return time.tick_diff(action.last_trigger, g_state.input.tick)
}

// Instantly fires if pressed, but cannot refire without both of:
// - The debounce elapsing
// - The Button releasing and re-pressing.
// GOTCHA:
//   You can't write if(action) {}; if (action) {}; and expect both to run.
//   EXPERIMENT: Write it as if that's not needed. Lift out to state if necessary.
//               e.g. "switch_mode: bool" so many places in the app can respond.
on_press :: proc (action: ^Button_Action) -> bool {
	button := action.button
	can_fire := button.is_pressed &&
	            time.tick_diff(action.last_trigger, button.prev_release) >= 0 &&
	            action.debounce < time_since_last_trigger(action)
	if can_fire {
		action.last_trigger = g_state.input.tick
	}
	return can_fire
}

on_release :: proc (action: ^Button_Action) -> bool {
	button := action.button
	can_fire := !button.is_pressed &&
	             time.tick_diff(action.last_trigger, button.prev_press) > 0 &&
	             action.debounce < time_since_last_trigger(action)
	if can_fire {
		action.last_trigger = g_state.input.tick
	}
	return can_fire
}

//////////////////////////////////////////////////////////////////////
// Input Implementation
//////////////////////////////////////////////////////////////////////
begin_input_frame :: proc () {
	g_state.input.tick = time.tick_now()
}

end_input_frame :: proc () {
	g_state.input.mouse.delta = 0
}

press_key :: proc (key: Key) {
	g_state.input.keys[key].is_pressed = true
	g_state.input.keys[key].prev_press = g_state.input.tick
}

release_key :: proc (key: Key) {
	g_state.input.keys[key].is_pressed = false
	g_state.input.keys[key].prev_release = g_state.input.tick
}
