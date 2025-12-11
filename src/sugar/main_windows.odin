package sugar

import "base:runtime"
import "core:log"
import "core:time"
import "core:sys/windows"
import os "core:os/os2"
import win "../windows"
import wgi "vendor:windows/GameInput"

platform_calls_step :: false

GL_Context :: windows.HGLRC
Window :: windows.HWND

stat :: os.stat
process_exec :: os.process_exec
get_working_directory :: os.get_working_directory
rename :: os.rename

Platform_State :: struct {
	window:         Window,
	window_resized: bool, // set in wndproc, unset in message queue reader
	window_style:   Window_Style,
	game_input:     ^wgi.IGameInput,
	gamepad_device: ^wgi.IGameInputDevice,
	gpu_hdc:        windows.HDC,
	gl_context:     GL_Context,
}

Gamepad_Button :: enum u32 {
	Start          = cast(u32) wgi.GamepadButtonsFlag.Menu,
	Select         = cast(u32) wgi.GamepadButtonsFlag.View,
	A              = cast(u32) wgi.GamepadButtonsFlag.A,
	B              = cast(u32) wgi.GamepadButtonsFlag.B,
	X              = cast(u32) wgi.GamepadButtonsFlag.X,
	Y              = cast(u32) wgi.GamepadButtonsFlag.Y,
	Up             = cast(u32) wgi.GamepadButtonsFlag.DPadUp,
	Down           = cast(u32) wgi.GamepadButtonsFlag.DPadDown,
	Left           = cast(u32) wgi.GamepadButtonsFlag.DPadLeft,
	Right          = cast(u32) wgi.GamepadButtonsFlag.DPadRight,
	Left_Shoulder  = cast(u32) wgi.GamepadButtonsFlag.LeftShoulder,
	Right_Shoulder = cast(u32) wgi.GamepadButtonsFlag.RightShoulder,
	Left_Stick     = cast(u32) wgi.GamepadButtonsFlag.LeftThumbstick,
	Right_Stick    = cast(u32) wgi.GamepadButtonsFlag.RightThumbstick,
}

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
	Space       = windows.VK_SPACE,
	W   = windows.VK_W,
	A   = windows.VK_A,
	S   = windows.VK_S,
	D   = windows.VK_D,
	_   = 0xFF,
}

capture_cursor :: proc () {
	window_rect: windows.RECT
	ok := windows.GetWindowRect(g.platform.window, &window_rect)
	assert(cast(bool) ok)
	windows.ClipCursor(&window_rect)
}

set_cursor_visible :: proc (show: bool) {
	windows.ShowCursor(cast(windows.BOOL) show)
}

init :: proc () {
	scale_windows_manually := windows.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
	assert(windows.SetProcessDpiAwarenessContext(scale_windows_manually) == true)
	init_native_input()
}

init_native_input :: proc () {
	result, ok := win.ok(wgi.Create(&g.platform.game_input))
  assert(ok)
}

list_displays :: proc (allocator := context.allocator) -> [dynamic]Display {
	displays := make([dynamic]Display, allocator)
	context.user_ptr = &displays

	display_iterator :: proc "system" (
		mon: windows.HMONITOR,
		hdc: windows.HDC,      // nil if EnumDisplayMonitors:hdc was nil
		rect: windows.LPRECT,  // virtual screen coordinates if hdc is nil
		data: windows.LPARAM
	) -> windows.BOOL {
		context = (cast(^runtime.Context) cast(uintptr) data)^
		array := cast(^[dynamic]Display) context.user_ptr
		resolution := win.GetMonitorPixelResolution(mon)
		dpi: windows.UINT
		_, ok := win.ok(windows.GetDpiForMonitor(
			mon,
			.MDT_EFFECTIVE_DPI,
			&dpi,
			&dpi))
		assert(ok)
		append(array, Display {
			{
				cast(int) rect.left,
				cast(int) rect.top 
			},
			resolution,
			cast(int) dpi
		})
		return true // keep looking for monitors
	}

	context_copy := context
	enumerate_monitors := windows.EnumDisplayMonitors(
		hdc      = nil,
		lprcClip = nil,
		lpfnEnum = display_iterator,
		dwData   = cast(int) cast(uintptr) &context_copy
	)
	assert(enumerate_monitors == true)
	return displays
}

@require_results
create_window :: proc (
	xywh: [4]int,
	title: string,
	use_gl: bool
) -> bool {
	g.platform.window_style = Window_Style {
		style = windows.CS_OWNDC if use_gl else 0,
		dwStyle = windows.WS_OVERLAPPEDWINDOW
	}
	////////////////////////////////////////////////////////////////////// 
	rect: windows.RECT = {
		left   = cast(i32) xywh[0],
		top    = cast(i32) xywh[1],
		right  = cast(i32) (xywh[0] + xywh[2]),
		bottom = cast(i32) (xywh[1] + xywh[3]),
	}
	hMonitor := windows.MonitorFromPoint({i32(xywh.x),i32(xywh.y)}, .MONITOR_DEFAULTTONULL)
	assert(hMonitor != nil)
	current_dpi: windows.UINT
	_, ok := win.ok(windows.GetDpiForMonitor(
		hMonitor,
		.MDT_EFFECTIVE_DPI,
		&current_dpi,
		&current_dpi))
	set_scale_factor_from_dpi(cast(windows.WORD)current_dpi)
	g.prev_scale_factor = g.scale_factor
	assert(ok)
	window_uses_menu: windows.BOOL : false
	adjusted := windows.AdjustWindowRectExForDpi(
		&rect,
		g.platform.window_style.dwStyle,
		window_uses_menu,
		g.platform.window_style.dwExStyle,
		current_dpi)
	assert(cast(bool) adjusted)

	instance := cast(windows.HINSTANCE) win.nonzero(windows.GetModuleHandleW(nil)) or_return
	wtitle := windows.utf8_to_utf16(title)

	class_name := raw_data(wtitle)
	window_class := windows.WNDCLASSEXW {
		cbSize        = size_of(windows.WNDCLASSEXW),
		lpfnWndProc   = thread_wndproc,
		hInstance     = instance,
		hCursor       = windows.LoadCursorA(nil, windows.IDC_ARROW),
		lpszClassName = cast(cstring16) class_name, // TODO unsafe assumes \0-term
		style         = g.platform.window_style.style
	}
	class_atom : windows.ATOM = win.nonzero(windows.RegisterClassExW(&window_class)) or_return
	window_title := windows.utf8_to_wstring(title)
	g.platform.window = win.nonzero(windows.CreateWindowExW(
		dwStyle      = g.platform.window_style.dwStyle,
		dwExStyle    = g.platform.window_style.dwExStyle,
		lpClassName  = cast(cstring16) class_name,
		lpWindowName = window_title,
		X            = cast(i32)rect.left,
		Y            = cast(i32)rect.top,
		nWidth       = rect.right - rect.left,
		nHeight      = rect.bottom - rect.top,
		hWndParent   = g.platform.window_style.hWndParent,
		hMenu        = g.platform.window_style.hMenu,
		hInstance    = instance,
		lpParam      = nil,
	)) or_return
	// Basic window creation succeeded.

	register_mouse_rawinput :: proc (window: windows.HWND) {
		// WARN: The message array can be heterogeneous.
		//       Don't request more than mouse input as raw input.
		devices: [1]windows.RAWINPUTDEVICE = {
			{
				usUsagePage = windows.HID_USAGE_PAGE_GENERIC,
				usUsage = windows.HID_USAGE_GENERIC_MOUSE,
				dwFlags = 0,
				hwndTarget = window,
			}
		}
		ok := windows.RegisterRawInputDevices(&devices[0], len(devices), size_of(devices))
		if !ok {
			log.error("Failed to register raw input.")
		}
	}
	register_mouse_rawinput(g.platform.window)

	// Technically this isn't necessary, since we're setting 
	// window-size in physical pixels.
	sized_rect: windows.RECT
	got_rect := windows.GetClientRect(g.platform.window, &sized_rect)
	assert_contextless(cast(bool) got_rect)
	g.viewport_size = {
		cast(int) (sized_rect.right - sized_rect.left),
		cast(int) (sized_rect.bottom - sized_rect.top) 
	}
	g.platform.window_resized = true
	// Now let's deal with graphics.
	if use_gl {
		gl_ok := init_gl()
		if !gl_ok {
			log.debug("Failed to initialize GL when creating a window.")
			return false
		}
	}

	windows.ShowWindow(g.platform.window, 5)
	return true 
}

swap_buffers :: proc () {
	windows.SwapBuffers(g.platform.gpu_hdc)
}

set_scale_factor_from_dpi :: proc "contextless" (dpi: windows.WORD) {
	g.prev_scale_factor = g.scale_factor
	set_scale_factor(cast(f32) dpi / 96)
}

thread_wndproc :: proc "system" (
	hwnd: windows.HWND,
	message: windows.UINT,
	w: windows.WPARAM,
	l: windows.LPARAM
) -> windows.LRESULT { switch message {
	case windows.WM_DPICHANGED:
		new_dpi := windows.HIWORD(w)
		set_scale_factor_from_dpi(new_dpi)
		g.scale_factor_changed = true
	case windows.WM_CLOSE:
		windows.DestroyWindow(hwnd)
	case windows.WM_DESTROY:
		windows.PostQuitMessage(0)
		return 0;
	// case windows.WM_ENTERSIZEMOVE:
	// case windows.WM_EXITSIZEMOVE:
	case windows.WM_SIZE:
		g.viewport_size.x = cast(int) windows.LOWORD(l)
		g.viewport_size.y = cast(int) windows.HIWORD(l)
		g.platform.window_resized = true
	}

	return windows.DefWindowProcW(hwnd, message, w, l)
}

// returns Should_Exit when the application should stop executing.
@require_results
poll_events :: proc () -> (feedback: bit_set[Feedback]) {
	begin_input_frame()

	poll_game_input :: proc () {
		reading: ^wgi.IGameInputReading
		if win.is_ok(g.platform.game_input->GetCurrentReading({.Gamepad}, g.platform.gamepad_device, &reading)) {
			if g.platform.gamepad_device == nil {
				// SCENARIO: First input in this run.
				reading->GetDevice(&g.platform.gamepad_device)
			}
			state: wgi.GamepadState
			reading->GetGamepadState(&state)
			new_button_bits := transmute(bit_set[Gamepad_Button; u32]) transmute(u32) state.buttons
			for button in new_button_bits - g.input.gamepad.button_bits {
				set_pressed(cast(Gamepad_Button) button)
			}
			for button in g.input.gamepad.button_bits - new_button_bits {
				set_released(cast(Gamepad_Button) button)
			}
			g.input.gamepad.button_bits = new_button_bits
			g.input.gamepad.left_trigger = state.leftTrigger
			g.input.gamepad.right_trigger = state.rightTrigger
			g.input.gamepad.left_stick = {state.leftThumbstickX, state.leftThumbstickY}
			g.input.gamepad.right_stick = {state.rightThumbstickX, state.rightThumbstickY}
			reading->Release()
		} else if g.platform.gamepad_device != nil {
			// Assume the error means the device was disconnected.
			// I could use callbacks to confirm.
			g.platform.gamepad_device->Release()
			g.platform.gamepad_device = nil
			return
		}
	}
	poll_game_input()

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
			g.mouse_delta.x += f32(mouse.lLastX)
			g.mouse_delta.y += f32(mouse.lLastY)
		}
	}
	get_raw_input()

  for message: windows.MSG; windows.PeekMessageW(
    lpMsg = &message,
    hWnd = {}, // thread-level, not window (to get WM_QUIT)
    wMsgFilterMin = 0,
    wMsgFilterMax = 0,
    wRemoveMsg = windows.PM_REMOVE
  );{

    if message.message == windows.WM_QUIT {
    	feedback += {.Should_Exit}
    	return
    }

    switch (message.message) {
    case windows.WM_ENTERSIZEMOVE:
  	case windows.WM_KEYDOWN:   on_key_down(message)
  	case windows.WM_KEYUP:     on_key_up(message)
  	case windows.WM_MOUSEMOVE: on_mousemove(message)
  	case windows.WM_LBUTTONDOWN:
			set_pressed(Key.Left_Mouse)
  	case windows.WM_LBUTTONUP:
  		set_released(Key.Left_Mouse)
    }

    if g.platform.window_resized {
    	g.platform.window_resized = false // set by peek
    	feedback += {.Window_Resized}
    }
    if g.scale_factor_changed {
    	g.scale_factor_changed = false // set by peek
    	feedback += {.Window_Scale_Factor_Changed}
    }

    windows.TranslateMessage(&message)
    windows.DispatchMessageW(&message)
  }
  
  return
}

on_key_down :: proc (message: windows.MSG) {
	if message.wParam < windows.VK_LBUTTON || message.wParam > windows.VK_OEM_CLEAR { return }
	virtual_keycode := cast(Key) message.wParam
	down := win.Key_LPARAM(message.lParam)
	// Don't process key repeats. Those are for text editing, not games.
	if down.was_down { return }

	set_pressed(virtual_keycode)
}

on_key_up :: proc (message: windows.MSG) {
	if message.wParam < windows.VK_LBUTTON || message.wParam > windows.VK_OEM_CLEAR { return }
	virtual_keycode := cast(Key) message.wParam
	set_released(virtual_keycode)
}

on_mousemove :: proc (message: windows.MSG) {
	size_y := cast(f32)(g.viewport_size.y)
	g.mouse_position.x = cast(f32) windows.GET_X_LPARAM(message.lParam)
	g.mouse_position.y = size_y - cast(f32) windows.GET_Y_LPARAM(message.lParam)
}

////////////////////////////////////////////////////////////////////////////////
// Misc.
////////////////////////////////////////////////////////////////////////////////

// Just pasting this here for reference on which Windows-native features can be added.
Window_Style :: struct {
	// CreateWindowExW parameters //////////////////////////////////////////////////////////
	// https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles
	dwExStyle:  windows.DWORD,
	// https://learn.microsoft.com/en-us/windows/win32/winmsg/window-styles
	dwStyle:    windows.DWORD,
	hWndParent: windows.HWND,
	hMenu:      windows.HMENU,
	lpParam:    windows.LPVOID,

	// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-wndclassexw
	// WNDCLASSEXw /////////////////////////////////////////////////////////////////////////
	style:         windows.UINT,
	// cbClsExtra:    windows.INT,
	// cbWndExtra:    windows.INT,
	// hIcon:         windows.HICON,
	// hCursor:       windows.HCURSOR,
	// hbrBackground: windows.HBRUSH,
	// lpszMenuName:  windows.LPCWSTR,
	// hIconSm:       windows.HICON,
}
