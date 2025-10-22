package sugar

import "base:runtime"
import "core:log"
import "core:sys/windows"
import win "../windows"

platform_calls_step :: false
Window :: windows.HWND
g_window: Window
g_window_resized: bool // set in wndproc, unset in message queue reader
g_scale_factor_changed: bool

// Just pasting this here for reference on which Windows-native features can be added.
////////////////////////////////////////////////////////////////////// 
@private
window_style: Window_Style
window_uses_menu: windows.BOOL : false
@private
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

init :: proc () {
	scale_windows_manually := windows.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
	assert(windows.SetProcessDpiAwarenessContext(scale_windows_manually) == true)
	init_input()
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
	window_style = Window_Style {
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
	prev_scale_factor = scale_factor
	assert(ok)
	adjusted := windows.AdjustWindowRectExForDpi(
		&rect,
		window_style.dwStyle,
		window_uses_menu,
		window_style.dwExStyle,
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
		style         = window_style.style
	}
	class_atom : windows.ATOM = win.nonzero(windows.RegisterClassExW(&window_class)) or_return
	window_title := windows.utf8_to_wstring(title)
	g_window = win.nonzero(windows.CreateWindowExW(
		dwStyle      = window_style.dwStyle,
		dwExStyle    = window_style.dwExStyle,
		lpClassName  = cast(cstring16) class_name,
		lpWindowName = window_title,
		X            = cast(i32)rect.left,
		Y            = cast(i32)rect.top,
		nWidth       = rect.right - rect.left,
		nHeight      = rect.bottom - rect.top,
		hWndParent   = window_style.hWndParent,
		hMenu        = window_style.hMenu,
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
	register_mouse_rawinput(g_window)

	// Technically this isn't necessary, since we're setting 
	// window-size in physical pixels.
	sized_rect: windows.RECT
	got_rect := windows.GetClientRect(g_window, &sized_rect)
	assert_contextless(cast(bool) got_rect)
	viewport_size = {
		cast(int) (sized_rect.right - sized_rect.left),
		cast(int) (sized_rect.bottom - sized_rect.top) 
	}
	g_window_resized = true
	// Now let's deal with graphics.
	if use_gl {
		gl_ok := load_gl()
		if !gl_ok {
			log.debug("Failed to initialize GL when creating a window.")
			return false
		}
	}

	windows.ShowWindow(g_window, 5)
	return true 
}

swap_buffers :: proc () {
	windows.SwapBuffers(g_dc)
}

thread_wndproc :: proc "system" (
	hwnd: windows.HWND,
	message: windows.UINT,
	w: windows.WPARAM,
	l: windows.LPARAM
) -> windows.LRESULT {
	switch message {
	case windows.WM_DPICHANGED:
		new_dpi := windows.HIWORD(w)
		set_scale_factor_from_dpi(new_dpi)
		g_scale_factor_changed = true
	case windows.WM_CLOSE:
		windows.DestroyWindow(hwnd)
	case windows.WM_DESTROY:
		windows.PostQuitMessage(0)
		return 0;
	// case windows.WM_ENTERSIZEMOVE:
	// case windows.WM_EXITSIZEMOVE:
	case windows.WM_SIZE:
		viewport_size.x = cast(int) windows.LOWORD(l)
		viewport_size.y = cast(int) windows.HIWORD(l)
		g_window_resized = true
	}

	return windows.DefWindowProcW(hwnd, message, w, l)
}

capture_cursor :: proc () {
	window_rect: windows.RECT
	ok := windows.GetWindowRect(g_window, &window_rect)
	assert(cast(bool) ok)
	windows.ClipCursor(&window_rect)
}

set_cursor_visible :: proc (show: bool) {
	windows.ShowCursor(cast(windows.BOOL) show)
}

set_scale_factor_from_dpi :: proc "contextless" (dpi: windows.WORD) {
	prev_scale_factor = scale_factor
	set_scale_factor(cast(f32) dpi / 96)
}
