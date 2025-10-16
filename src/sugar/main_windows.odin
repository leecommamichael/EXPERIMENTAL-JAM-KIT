package sugar

import "base:runtime"
import "core:log"
import "core:sys/windows"
import win "../windows"

platform_calls_step :: false

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

Window :: windows.HWND
g_window: Window
g_window_resized: bool // set in wndproc, unset in message queue reader

@require_results
create_window :: proc (
  rect: [4]int, // Packed as xywh, xy is in virtual screen coordinates.
  title: string,
  use_gl: bool
) -> bool {
  scale_windows_manually := windows.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
  old_scaling_mode := windows.SetThreadDpiAwarenessContext(scale_windows_manually)
  assert(old_scaling_mode != nil)
  // Just pasting this here for reference on which Windows-native features can be added.
  ////////////////////////////////////////////////////////////////////// 
  Native_Extras :: struct {
    // Extras for CreateWindowExW
    // https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles
    dwExStyle:  windows.DWORD,
    // https://learn.microsoft.com/en-us/windows/win32/winmsg/window-styles
    dwStyle:    windows.DWORD,
    hWndParent: windows.HWND,
    hMenu:      windows.HMENU,
    lpParam:    windows.LPVOID,

    // https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-wndclassexw
    // WNDCLASSEXw
    style:         windows.UINT,
    // cbClsExtra:    windows.INT,
    // cbWndExtra:    windows.INT,
    // hIcon:         windows.HICON,
    // hCursor:       windows.HCURSOR,
    // hbrBackground: windows.HBRUSH,
    // lpszMenuName:  windows.LPCWSTR,
    // hIconSm:       windows.HICON,
  }
  default_extras := Native_Extras {
    style = windows.CS_OWNDC if use_gl else 0,
    dwStyle = windows.WS_OVERLAPPEDWINDOW
  }
  ////////////////////////////////////////////////////////////////////// 
  viewport_size = { rect[2], rect[3] }
  uses_menu: windows.BOOL : false
  log.infof("desired rect %v", rect)
  desired_client_rect: windows.RECT = {
    cast(i32) rect[0],
    cast(i32) rect[1],
    cast(i32) rect[2],
    cast(i32) rect[3],
  }
  hMonitor := windows.MonitorFromPoint({i32(rect.x),i32(rect.y)}, .MONITOR_DEFAULTTOPRIMARY)
  assert(hMonitor != nil)
  current_dpi: windows.UINT
  _, ok := win.ok(windows.GetDpiForMonitor(
    hMonitor,
    .MDT_EFFECTIVE_DPI,
    &current_dpi,
    &current_dpi))
  log.infof("DPI %v", current_dpi)
  assert(ok)
  adjusted := windows.AdjustWindowRectExForDpi(
    &desired_client_rect,
    default_extras.dwStyle,
    uses_menu,
    default_extras.dwExStyle,
    current_dpi)
  assert(cast(bool) adjusted)
  log.infof("adjusted rect %v", desired_client_rect)

  instance := cast(windows.HINSTANCE) win.nonzero(windows.GetModuleHandleW(nil)) or_return
  wtitle := windows.utf8_to_utf16(title)

  class_name := raw_data(wtitle)
  window_class := windows.WNDCLASSEXW {
    cbSize        = size_of(windows.WNDCLASSEXW),
    lpfnWndProc   = thread_wndproc,
    hInstance     = instance,
    lpszClassName = cast(cstring16) class_name,
    style         = default_extras.style
  }
  class_atom : windows.ATOM = win.nonzero(windows.RegisterClassExW(&window_class)) or_return

  window_title := windows.utf8_to_wstring(title)
  window_context := context
  g_window = win.nonzero(windows.CreateWindowExW(
    dwStyle      = default_extras.dwStyle,
    dwExStyle    = default_extras.dwExStyle,
    lpClassName  = cast(cstring16) class_name,
    lpWindowName = window_title,
    X            = cast(windows.INT) desired_client_rect.left,
    Y            = cast(windows.INT) desired_client_rect.top,
    nWidth       = cast(windows.INT) desired_client_rect.right,
    nHeight      = cast(windows.INT) desired_client_rect.bottom,
    hWndParent   = default_extras.hWndParent,
    hMenu        = default_extras.hMenu,
    hInstance    = instance,
    lpParam      = &window_context,
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

  // Now let's deal with graphics.
  if use_gl {
    gl_ok := load_gl(viewport_size)
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

// The runtime.Context used to create the main window is available.
thread_wndproc :: proc "system" (
  hwnd: windows.HWND,
  message: windows.UINT,
  w: windows.WPARAM,
  l: windows.LPARAM
) -> windows.LRESULT {
  // Initialize the runtime.Context.
  // In Practice: Only a WM_GETMINMAXINFO arrives before we can receive a context.
  // In Reality : You've got to check context_ready to do anything of importance.
  //////////////////////////////////////////////////////////////////////
  context = {}
  @static context_ready: bool
  if context_ready {
    window_user_data := windows.GetWindowLongPtrW(hwnd, windows.GWLP_USERDATA)
    context = ( cast(^runtime.Context) cast(uintptr) window_user_data )^
  } else {
    // NCCREATE receives a context pointer from create_window.
    // Here we persist that pointer using SetWindowLongPtr.
    if message == windows.WM_NCCREATE {
      context_ready = true
      createstruct := transmute(^windows.CREATESTRUCTW)l
      context = ( transmute(^runtime.Context)createstruct.lpCreateParams )^
      ctx := cast(windows.LONG_PTR) cast(uintptr) createstruct.lpCreateParams
      windows.SetWindowLongPtrW(hwnd, windows.GWLP_USERDATA, ctx)
    }
  }
  //////////////////////////////////////////////////////////////////////

  switch message {
  case windows.WM_CLOSE:
    windows.DestroyWindow(hwnd)
  case windows.WM_DESTROY:
    windows.PostQuitMessage(0)
    return 0;
  case windows.WM_SIZE:
    g_window_resized = true
    if g_gl_ready {
      resize_viewport()
    }
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
