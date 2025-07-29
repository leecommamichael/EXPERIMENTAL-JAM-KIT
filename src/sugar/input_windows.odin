package sugar

import "core:time"
import "core:log"
import "core:sys/windows"
import win "../windows"


// A virtual key code. Suitable for games if users have the same
// keyboard layout. e.g. QWERTY, AZERTY, etc
Key :: enum {
	Escape      = windows.VK_ESCAPE,
	Left_Mouse  = windows.VK_LBUTTON,
	Right_Mouse = windows.VK_RBUTTON,
	Left_Arrow  = windows.VK_LEFT,
	Right_Arrow = windows.VK_RIGHT,
	Up_Arrow    = windows.VK_UP,
	Down_Arrow  = windows.VK_DOWN,
	Space = windows.VK_SPACE,
	W   = windows.VK_W,
	A   = windows.VK_A,
	S   = windows.VK_S,
	D   = windows.VK_D,
	_   = 0xFF,
}

@private
on_key_down :: proc (message: windows.MSG) {
	if message.wParam < windows.VK_LBUTTON || message.wParam > windows.VK_OEM_CLEAR { return }
	virtual_keycode := cast(Key) message.wParam
	down := win.Key_LPARAM(message.lParam)
	// Don't process key repeats. Those are for text editing, not games.
	if down.was_down { return }

	press_key(virtual_keycode)
}

@private
on_key_up :: proc (message: windows.MSG) {
	if message.wParam < windows.VK_LBUTTON || message.wParam > windows.VK_OEM_CLEAR { return }
	virtual_keycode := cast(Key) message.wParam
	release_key(virtual_keycode)
}

@private
on_mousemove :: proc (message: windows.MSG) {
	g_state.input.mouse.window.x = cast(f32) windows.GET_X_LPARAM(message.lParam)
	g_state.input.mouse.window.y = cast(f32) windows.GET_Y_LPARAM(message.lParam)
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
	get_raw_input :: proc () {
		byte_count: windows.UINT
		_, size_query_ok := win.zero(windows.GetRawInputBuffer(nil, &byte_count, size_of(windows.RAWINPUTHEADER)))
		if !size_query_ok {
			// No remarks in docs for when this happens.
		}
		N :: 32 // Messages per frame. 60fps * 32samples ~ 1800hz
		byte_count *= N
		messages: [N]windows.RAWINPUT
		messages_written, ok := win.not_negative_one(windows.GetRawInputBuffer(&messages[0], &byte_count, size_of(windows.RAWINPUTHEADER)))
		if !ok {
			// No remarks in docs for when this happens.
		}

		for i in 0..<messages_written {
			// WARN: The message array can be heterogeneous.
			//       Don't request more than mouse input as raw input.
			mouse := messages[i].data.mouse
			g_state.input.mouse.delta.x += f32(mouse.lLastX)
			g_state.input.mouse.delta.y += f32(mouse.lLastY)
		}
	}
	get_raw_input()

  message: windows.MSG
  for {
    has_more_messages := windows.PeekMessageW(
      lpMsg = &message,
      hWnd = {}, // thread-level, not window (to get WM_QUIT)
      wMsgFilterMin = 0,
      wMsgFilterMax = 0,
      wRemoveMsg = windows.PM_REMOVE
    )
    if message.message == windows.WM_QUIT { return .Should_Exit }

    switch (message.message) {
  	case windows.WM_KEYDOWN: on_key_down(message)
  	case windows.WM_KEYUP:   on_key_up(message)
  	case windows.WM_MOUSEMOVE: on_mousemove(message)
  	case windows.WM_LBUTTONDOWN:        // TODO: KILLME (dedupe with on_ handlers)
			g_state.input.keys[.Left_Mouse].is_pressed = true
			g_state.input.keys[.Left_Mouse].prev_press = g_state.input.tick
  	case windows.WM_LBUTTONUP:        // TODO: KILLME
			g_state.input.keys[.Left_Mouse].is_pressed = false
			g_state.input.keys[.Left_Mouse].prev_release = g_state.input.tick
    }
    if g_window_resized {
    	g_window_resized = false
    	feedback = .Resized
    }

    if !has_more_messages { break }
    windows.TranslateMessage(&message)
    windows.DispatchMessageW(&message)
  }
  
  return
}