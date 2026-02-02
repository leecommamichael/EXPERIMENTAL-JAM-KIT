package sugar

import os "core:os/os2"

platform_calls_step :: false

TODO :: struct {}

GL_Context :: TODO
Window :: TODO
Window_Style :: TODO

stat :: os.stat
process_exec :: os.process_exec
get_working_directory :: os.get_working_directory
rename :: os.rename

Platform_State :: struct {
	window:         Window,
	window_resized: bool, // set in wndproc, unset in message queue reader
	window_style:   Window_Style,
	gl_context:     GL_Context,
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

// A virtual key code. Suitable for games if users have the same
// keyboard layout. e.g. QWERTY, AZERTY, etc
Key :: enum {
	Escape      ,
	Left_Mouse  ,
	Right_Mouse ,
	Left_Arrow  ,
	Right_Arrow ,
	Up_Arrow    ,
	Down_Arrow  ,
	Space       ,
	A ,
	B ,
	C ,
	D ,
	E ,
	F ,
	G ,
	H ,
	I ,
	J ,
	K ,
	L ,
	M ,
	N ,
	O ,
	P ,
	Q ,
	R ,
	S ,
	T ,
	U ,
	V ,
	W ,
	X ,
	Y ,
	Z ,
	_ ,
}

capture_cursor :: proc () {
}

set_cursor_visible :: proc (show: bool) {
}

init :: proc () {
}

list_displays :: proc (allocator := context.allocator) -> [dynamic]Display {
	return {}
}

@require_results
create_window :: proc (
	xywh: [4]int,
	title: string,
	use_gl: bool
) -> bool {
	return true
}

swap_buffers :: proc () {
}

// returns Should_Exit when the application should stop executing.
@require_results
poll_events :: proc () -> (feedback: bit_set[Feedback]) {
	return {}
}
