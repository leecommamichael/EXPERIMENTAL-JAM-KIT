package sugar

import "base:runtime"
import wl "../third-party/odin-wayland"
import "vendor:egl"
import gl "../angle"
import "../third-party/odin-wayland/ext/libdecor"
import os "core:os/os2"
import "core:dynlib"
import "core:log"

platform_calls_step :: false

Window :: struct {
	egl_display: egl.Display,
	egl_window: ^wl.egl_window,
	egl_surface: egl.Surface,
	egl_context: egl.Context,
	display:    ^wl.display,
	surface:    ^wl.surface,
	compositor: ^wl.compositor,
	region:     ^wl.region,
	instance:     ^libdecor.instance,
	window_state: libdecor.window_state,
	frame:        ^libdecor.frame,
	size:      [2]int, 
	geometry:  [2]int,
	maximized: bool,
}

stat :: os.stat
process_exec :: os.process_exec
get_working_directory :: os.get_working_directory
rename :: os.rename

// g.platform = ...
Platform_State :: struct {
	window:         Window,
	window_resized: bool, // set in wndproc, unset in message queue reader
	gl_context:     egl.Context,
  lib:            dynlib.Library,
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

global_context: runtime.Context
init :: proc () {
	global_context = context
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
	window := &g.platform.window
	global_context = context
	window^ = { geometry = {1280,720}, size = {1280, 720} }
	window.display = wl.display_connect(nil)
	if window.display != nil {
		log.info("Successfully connected to a wayland display.")
	}
	else {
		log.info("Failed to connect to a wayland display")
		return false
	}
	registry := wl.display_get_registry(window.display)
	wl.registry_add_listener(registry, &registry_listener, nil)
	wl.display_roundtrip(window.display)
	window.surface = wl.compositor_create_surface(window.compositor)

	major, minor : i32
	egl.BindAPI(egl.OPENGL_API)
	config_attribs := []i32 {
		egl.RED_SIZE, 8,
		egl.GREEN_SIZE, 8,
		egl.BLUE_SIZE, 8,
    egl.ALPHA_SIZE, 8,
		egl.NONE
	}

	window.egl_display = egl.GetDisplay(cast(egl.NativeDisplayType)window.display)
	if window.egl_display == nil {
		log.info("Failed to create egl display")
		return false
	}

	if use_gl {
		egl.Initialize(window.egl_display, &major, &minor)
		log.infof("EGL Major: %v, EGL Minor: %v", major, minor)

		config: egl.Config
		num_config: i32
		egl.ChooseConfig(window.egl_display, raw_data(config_attribs), &config, 1, &num_config)
		window.egl_context = egl.CreateContext(window.egl_display, config, nil, nil)
		window.egl_window = wl.egl_window_create(window.surface, window.size.x, window.size.y)
		window.egl_surface = egl.CreateWindowSurface(window.egl_display, config, cast(egl.NativeWindowType)window.egl_window, nil)
		wl.surface_commit(window.surface)
		egl.MakeCurrent(window.egl_display, window.egl_surface, window.egl_surface, window.egl_context)
		gl.load_up_to(3,3,egl.gl_set_proc_address)
	}
	window.instance = libdecor.new(window.display, &iface)
	window.frame = libdecor.decorate(window.instance, window.surface, &frame_iface, nil)
	libdecor.frame_set_app_id(window.frame, "odin-wayland-egl")
	libdecor.frame_set_title(window.frame, cast(cstring) raw_data(title)) // <-- unsafe assume null terminated
	libdecor.frame_map(window.frame)
	wl.display_dispatch(window.display)
	// It requires calling it two times to get a configure event
	wl.display_dispatch(window.display)
	return true
}

swap_buffers :: proc () {
	egl.SwapBuffers(g.platform.window.egl_display, g.platform.window.egl_surface)
}

// returns Should_Exit when the application should stop executing.
@require_results
poll_events :: proc () -> (feedback: bit_set[Feedback]) {
	wl.display_dispatch(g.platform.window.display)
	@static ctr: int = 0
	defer ctr += 1
	if ctr == 0 {
		g.viewport_size = {1280,720}
		g.scale_factor = 1
		return {.Window_Resized}
	}
	return {}
}

load_gl :: proc () {
  gl.load_up_to(3, 3, set_proc_address)
}

set_proc_address :: proc (set_me: rawptr, name: cstring) {
  dest := set_me
  source, found := dynlib.symbol_address(g.platform.lib, string(name))
  if !found {
    log.errorf("%v = %v AKA %s", dest, source, name)
  }
  ensure(found)
  ensure(dest != nil)
  (^rawptr)(set_me)^ = source
  ensure(dest != nil)
}

//////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////
registry_listener := wl.registry_listener {
	global = registry_global,
	global_remove = registry_global_remove
}

iface := libdecor.interface {
	error = interface_error
}

frame_iface := libdecor.frame_interface {
	commit = frame_commit,
	close = frame_close,
	configure = frame_configure,
}
frame_close :: proc "c" (frame: ^libdecor.frame, user_data: rawptr) {
	os.exit(0)
}
frame_commit :: proc "c" (frame: ^libdecor.frame, user_data: rawptr) {
	window := &g.platform.window
	egl.SwapBuffers(window.egl_display, window.egl_surface)
}

frame_configure :: proc "c" (frame: ^libdecor.frame, configuration: ^libdecor.configuration, user_data: rawptr) {
	window := &g.platform.window
	context = global_context
	width, height: int
	state: ^libdecor.state

	if !libdecor.configuration_get_content_size(configuration, frame, &width, &height) {
		width = window.geometry.x
		height = window.geometry.y
	}
	if width > 0 && height > 0 {
		if !window.maximized {
			window.size = {width, height}
		}
		window.geometry = {width, height}
	}
	else if !window.maximized {
		window.geometry = window.size
	}

	wl.egl_window_resize(window.egl_window, width, height,0,0)

	state = libdecor.state_new(width, height)
	libdecor.frame_commit(frame, state, configuration)
	libdecor.state_free(state)
	window_state: libdecor.window_state
	if !libdecor.configuration_get_window_state(configuration, &window_state) do window_state = {}

	window.maximized = window_state & {.MAXIMIZED, .FULLSCREEN} != {};
}

interface_error :: proc "c" (instance: ^libdecor.instance, error: libdecor.error, message:cstring)
{
	context = global_context
	log.errorf("libdecor error(%v):%v", error, message)
	os.exit(1)
}

registry_global :: proc "c" (data: rawptr, registry: ^wl.registry, name: uint, interface_name: cstring, version: uint) {
	window := &g.platform.window
	context = global_context
	switch interface_name {
		case wl.compositor_interface.name:
			window.compositor = cast(^wl.compositor)wl.registry_bind(registry, name, &wl.compositor_interface, 4)
	}
}

registry_global_remove :: proc "c" (data: rawptr, registry: ^wl.registry, name: uint) {
}
