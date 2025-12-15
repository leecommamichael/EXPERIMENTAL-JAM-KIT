package sugar

import "core:c"
import "core:log"
import "core:sys/windows"
import gl "../angle"
import win "../windows"

CONTEXT_MAJOR:: 3
CONTEXT_MINOR:: 3

load_gl :: proc () {
  gl.load_up_to(CONTEXT_MAJOR, CONTEXT_MINOR, windows.gl_set_proc_address)
}

// https://www.khronos.org/opengl/wiki/Creating_an_OpenGL_Context_(WGL)#Create_a_False_Context
// https://www.khronos.org/opengl/wiki/Load_OpenGL_Functions#Windows_2
@require_results
init_gl :: proc () -> bool {
  g.platform.gpu_hdc = win.nonzero(windows.GetDC(g.platform.window)) or_return
  pf := dummy_gl_pixel_format
  pf_id := windows.ChoosePixelFormat(g.platform.gpu_hdc, &pf)
  windows.SetPixelFormat(g.platform.gpu_hdc, pf_id, &pf) // What? Why send the id and the data?
  dummy_ctx: windows.HGLRC = win.nonzero(windows.wglCreateContext(g.platform.gpu_hdc)) or_return
  dummy_is_current := win.nonzero(windows.wglMakeCurrent(g.platform.gpu_hdc, dummy_ctx)) or_return

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
  modern_ctx := windows.wglCreateContextAttribsARB(g.platform.gpu_hdc, nil, raw_data(ctx_attribs))
  no_ctx := win.nonzero(windows.wglMakeCurrent(g.platform.gpu_hdc, nil)) or_return
  modern_ctx_is_current := win.nonzero(windows.wglMakeCurrent(g.platform.gpu_hdc, modern_ctx)) or_return
  windows.wglDeleteContext(dummy_ctx)
  actual_version: [2]int

  g.platform.gl_context = modern_ctx
  load_gl()
  // TODO: Version check the context.
  gl.glGetIntegerv(gl.MAJOR_VERSION, &actual_version[0])
  gl.glGetIntegerv(gl.MINOR_VERSION, &actual_version[1])
  if actual_version.x < CONTEXT_MAJOR || actual_version.y < CONTEXT_MINOR {
    log.errorf("Insufficient GL version. Got %v", actual_version)
    return false
  }
  // windows.wglSwapIntervalEXT = cast(windows.SwapIntervalEXTType)windows.wglGetProcAddress("wglSwapIntervalEXT")
  // windows.wglSwapIntervalEXT(0)
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