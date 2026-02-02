package sugar

import "base:runtime"
import "base:intrinsics"
import "core:log"
import "core:sys/posix"
import "core:dynlib"
import os "core:os/os2"
import gl "../angle"
import NS "core:sys/darwin/Foundation"
import Metal "vendor:darwin/Metal"
import MTK "vendor:darwin/MetalKit"

platform_calls_step :: false


stat :: os.stat
process_exec :: os.process_exec
get_working_directory :: os.get_working_directory
rename :: os.rename

Platform_State :: struct {
  window_resized: bool,
  display: EGL_Display,
  surface: Surface,
  lib:     dynlib.Library,
}

init :: proc () {}

list_displays :: proc () -> []Display {
  d := make([]Display, 1)
  d[0] = {{0,0},{0,0}, 96} // TODO
  return d
}

NativeDisplayType :: distinct rawptr
NativeWindowType  :: distinct rawptr
EGL_Display :: distinct rawptr
Surface :: distinct rawptr
Config  :: distinct rawptr
Context :: distinct rawptr

Boolean :: b32

NO_DISPLAY :: EGL_Display(uintptr(0))
NO_CONTEXT :: Context(uintptr(0))
NO_SURFACE :: Surface(uintptr(0))

DEFAULT_DISPLAY :: NativeDisplayType(uintptr(0))

CONTEXT_OPENGL_CORE_PROFILE_BIT :: 0x00000001
WINDOW_BIT        :: 0x0004
OPENGL_BIT        :: 0x0008
OPENGL_ES2_BIT    :: 0x0004
OPENGL_ES3_BIT    :: 0x00000040

ALPHA_SIZE        :: 0x3021
BLUE_SIZE         :: 0x3022
GREEN_SIZE        :: 0x3023
RED_SIZE          :: 0x3024
DEPTH_SIZE        :: 0x3025
STENCIL_SIZE      :: 0x3026
NATIVE_VISUAL_ID  :: 0x302E

SURFACE_TYPE      :: 0x3033
EGL_NONE          :: 0x3038
COLOR_BUFFER_TYPE :: 0x303F
RENDERABLE_TYPE   :: 0x3040
CONFORMANT        :: 0x3042
HEIGHT            :: 0x3056
WIDTH             :: 0x3057

BACK_BUFFER          :: 0x3084
RENDER_BUFFER        :: 0x3086
GL_COLORSPACE_SRGB   :: 0x3089
GL_COLORSPACE_LINEAR :: 0x308A
RGB_BUFFER           :: 0x308E
GL_COLORSPACE        :: 0x309D

CONTEXT_CLIENT_VERSION      :: 0x3098
CONTEXT_MAJOR_VERSION       :: 0x3098
CONTEXT_MINOR_VERSION       :: 0x30FB
CONTEXT_OPENGL_PROFILE_MASK :: 0x30FD
CONTEXT_OPENGL_DEBUG              :: 0x31B0
CONTEXT_OPENGL_ROBUST_ACCESS      :: 0x31B2 

OPENGL_API        :: 0x30A2

foreign import egl "../libEGL.dylib"
@(default_calling_convention="c")
foreign egl {
  eglGetDisplay          :: proc(display: NativeDisplayType) -> EGL_Display ---
  eglInitialize          :: proc(display: EGL_Display, major: ^i32, minor: ^i32) -> Boolean ---
  eglBindAPI             :: proc(api: u32) -> Boolean ---
  eglChooseConfig        :: proc(display: EGL_Display, attrib_list: ^i32, configs: ^Config, config_size: i32, num_config: ^i32) -> Boolean ---
  eglCreateWindowSurface :: proc(display: EGL_Display, config: Config, native_window: NativeWindowType, attrib_list: ^i32) -> Surface ---
  eglCreateContext       :: proc(display: EGL_Display, config: Config, share_context: Context, attrib_list: ^i32) -> Context ---
  eglMakeCurrent         :: proc(display: EGL_Display, draw: Surface, read: Surface, ctx: Context) -> Boolean ---
  eglQuerySurface        :: proc(display: EGL_Display, surface: Surface, attribute: i32, value: ^i32) -> Boolean ---
  eglSwapInterval        :: proc(display: EGL_Display, interval: i32) -> Boolean ---
  eglSwapBuffers         :: proc(display: EGL_Display, surface: Surface) -> Boolean ---
  eglGetProcAddress      :: proc(name: cstring) -> rawptr ---
  eglGetConfigAttrib     :: proc(display: EGL_Display, config: Config, attribute: i32, value: ^i32) -> Boolean ---
  eglDestroyContext      :: proc(display: EGL_Display, ctx: Context) -> Boolean ---
  eglDestroySurface      :: proc(display: EGL_Display, surface: Surface) -> Boolean ---
  eglTerminate           :: proc(display: EGL_Display) -> Boolean ---
}

@private
resize_viewport :: proc (w,h: int) {
  g.platform.window_resized = true
  g.viewport_size = { w, h }
  gl.Viewport(0,0, w, h)
  log.infof("viewport set to %d,%d", w,h)
}
msgSend :: intrinsics.objc_send

load_gl :: proc () {
  gl.load_up_to(3, 2, set_proc_address)
}

set_proc_address :: proc (set_me: rawptr, name: cstring) {
  dest := set_me
  // 
  // source: rawptr = posix.dlsym(transmute(posix.Symbol_Table)int(-1), name)
  source, found := dynlib.symbol_address(g.platform.lib, string(name))
  if !found {
    log.errorf("%v = %v AKA %s", dest, source, name)
  }
  ensure(found)
  ensure(dest != nil)
  (^rawptr)(set_me)^ = source
  ensure(dest != nil)
}

@require_results
create_window :: proc (
  rect: [4]int, // xywh
  title: string,
  use_gl: bool
) -> bool {
  lib_ok: bool
  g.platform.lib, lib_ok = dynlib.load_library(`/Users/mal/GitHub/EXPERIMENTAL_JAM_KIT/src/libGLESv2.dylib`)
  ensure(lib_ok)
  NS.application_delegate_register_and_alloc({
    applicationShouldTerminateAfterLastWindowClosed = proc(app: ^NS.Application) -> NS.BOOL {
      app->terminate(app)
      return true 
    }
  }, title, context)
  app := NS.Application.sharedApplication()
  app->setActivationPolicy(.Regular)
  app->activate()

  window_rect: NS.Rect = {
    origin = { NS.Float(rect.x), NS.Float(rect.y) },
    size = { NS.Float(rect[2]), NS.Float(rect[3]) }
  }
  window: ^NS.Window = NS.Window.alloc()->initWithContentRect(
    contentRect = window_rect,
    styleMask = NS.WindowStyleMask { .Titled, .Closable, .Resizable },
    backing = NS.BackingStoreType.Buffered,
    doDefer = false)
  window_delegate := NS.window_delegate_register_and_alloc({
    windowWillClose = proc(notification: ^NS.Notification) {
      NS.Application.sharedApplication()->terminate(nil)
    }
  }, "NSWindowDelegate", context)
  assert(window_delegate != nil)
  window->setDelegate(window_delegate)
  title_str: ^NS.String = NS.String.alloc()->initWithOdinString(title)
  window->setTitle(title_str)
  window->makeKeyAndOrderFront(nil)
  device := Metal.CreateSystemDefaultDevice()
  assert(device != nil)
  content_view: ^MTK.View = MTK.View.alloc()->initWithFrame(window_rect, device)
assert(content_view != nil)
  content_view->setWantsLayer(true)
  content_view->layer()->setContentsScale(1) // From Chromium: scales framebuffer otherwise.
  window->setContentView(content_view)
  maj: i32 = 0
  min: i32 = 0
  display := eglGetDisplay(auto_cast content_view->layer())
  g.platform.display = display
  assert(display != NO_DISPLAY)
  egl_ok := eglInitialize(display, &maj, &min)
  assert(maj >= 1)
  assert(min >= 5)
  assert(egl_ok != false)
  attrib_list: []i32 = {
      RED_SIZE, 8,
      GREEN_SIZE, 8,
      BLUE_SIZE, 8,
      ALPHA_SIZE, 8,
      EGL_NONE
  }
  config: Config
  configs_found: i32
  egl_ok = eglChooseConfig(display, raw_data(attrib_list), &config, 1, &configs_found)
  assert(egl_ok == true)
  assert(configs_found > 0)
  surface_attribs: []i32 = { EGL_NONE }
  surface := eglCreateWindowSurface(display, config, auto_cast content_view->layer(), raw_data(surface_attribs))
  g.platform.surface = surface
  assert(surface != NO_SURFACE)
  ctx_attribs: []i32 = {
    CONTEXT_MAJOR_VERSION, 3,
    CONTEXT_MINOR_VERSION, 0,
    CONTEXT_OPENGL_PROFILE_MASK, OPENGL_ES3_BIT | CONTEXT_OPENGL_CORE_PROFILE_BIT,
    CONTEXT_OPENGL_ROBUST_ACCESS, 1,
    CONTEXT_OPENGL_DEBUG, 1,
    EGL_NONE }
  ctx := eglCreateContext(display, config, share_context=nil, attrib_list=raw_data(ctx_attribs))
  assert(ctx != NO_CONTEXT)
  egl_ok = eglMakeCurrent(display, surface, surface, ctx)
  assert(egl_ok == true)

  load_gl()
  resize_viewport(rect.z, rect.w)
  return true
}

swap_buffers :: proc () {
  assert(true == eglSwapBuffers(g.platform.display, g.platform.surface))
}

capture_cursor :: proc () {
}

set_cursor_visible :: proc (show: bool) {
}