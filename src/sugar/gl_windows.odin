package sugar

import "core:c"
import "core:log"
import "core:sys/windows"
import gl "../nord_gl"
import win "../windows"

GL_Context :: windows.HGLRC
g_dc: windows.HDC
g_context: GL_Context
g_gl_ready: bool

// https://www.khronos.org/opengl/wiki/Creating_an_OpenGL_Context_(WGL)#Create_a_False_Context
// https://www.khronos.org/opengl/wiki/Load_OpenGL_Functions#Windows_2
@require_results
load_gl :: proc (window_size: [2]int) -> bool {
  g_dc = win.nonzero(windows.GetDC(g_window)) or_return
  pf := dummy_gl_pixel_format
  pf_id := windows.ChoosePixelFormat(g_dc, &pf)
  windows.SetPixelFormat(g_dc, pf_id, &pf) // What? Why send the id and the data?
  dummy_ctx: windows.HGLRC = win.nonzero(windows.wglCreateContext(g_dc)) or_return
  dummy_is_current := win.nonzero(windows.wglMakeCurrent(g_dc, dummy_ctx)) or_return

  CONTEXT_MAJOR:: 3
  CONTEXT_MINOR:: 3
  // TODO: vsync (needs extension detection)
  // windows.wglGetExtensionsStringARB = auto_cast windows.wglGetProcAddress("wglGetExtensionsStringARB")
  windows.wglCreateContextAttribsARB = auto_cast windows.wglGetProcAddress("wglCreateContextAttribsARB")
  if windows.wglCreateContextAttribsARB == nil {
    log.error("Lacking Modern GL. How old is this device?")
    return false
  }
  debug_flags: c.int = windows.WGL_CONTEXT_DEBUG_BIT_ARB | windows.WGL_CONTEXT_ROBUST_ACCESS_BIT_ARB when ODIN_DEBUG else 0
  ctx_attribs: []c.int = {
    windows.CONTEXT_MAJOR_VERSION_ARB, CONTEXT_MAJOR,
    windows.CONTEXT_MINOR_VERSION_ARB, CONTEXT_MINOR,
    windows.CONTEXT_FLAGS_ARB,         debug_flags,
    windows.CONTEXT_PROFILE_MASK_ARB,  windows.CONTEXT_CORE_PROFILE_BIT_ARB, 0
  }
  modern_ctx := windows.wglCreateContextAttribsARB(g_dc, nil, raw_data(ctx_attribs))
  no_ctx := win.nonzero(windows.wglMakeCurrent(g_dc, nil)) or_return
  modern_ctx_is_current := win.nonzero(windows.wglMakeCurrent(g_dc, modern_ctx)) or_return
  windows.wglDeleteContext(dummy_ctx)
  actual_version: [2]int

  g_context = modern_ctx
  gl.load_up_to(CONTEXT_MAJOR, CONTEXT_MINOR, windows.gl_set_proc_address)
  // TODO: Version check the context.
  gl.glGetIntegerv(gl.MAJOR_VERSION, &actual_version[0])
  gl.glGetIntegerv(gl.MINOR_VERSION, &actual_version[1])
  if actual_version.x < CONTEXT_MAJOR || actual_version.y < CONTEXT_MINOR {
    log.errorf("Insufficient GL version. Got %v", actual_version)
    return false
  }
  resize_viewport()
  g_gl_ready = true
  return true
}

dummy_gl_pixel_format: windows.PIXELFORMATDESCRIPTOR : {
  nSize    = size_of(windows.PIXELFORMATDESCRIPTOR),
  nVersion = 1,
  dwFlags = windows.PFD_DRAW_TO_WINDOW | windows.PFD_SUPPORT_OPENGL | windows.PFD_DOUBLEBUFFER,
  iPixelType = windows.PFD_TYPE_RGBA,
  cColorBits = 32,
  cDepthBits = 24,
  cStencilBits = 8,
  iLayerType = windows.PFD_MAIN_PLANE,
}

@private
resize_viewport :: proc () {
  sized_rect: windows.RECT
  got_rect := windows.GetClientRect(g_window, &sized_rect)
  assert(cast(bool) got_rect)
  g_state.resolution = { cast(int) sized_rect.right, cast(int) sized_rect.bottom }
  gl.Viewport(0,0, g_state.resolution.x, g_state.resolution.y)
}