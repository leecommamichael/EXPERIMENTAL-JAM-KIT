package sugar

import "base:runtime"
import "base:intrinsics"
import "core:log"
import "core:sys/posix"
import gl "../nord_gl"
import NS "core:sys/darwin/Foundation"

// import NS "../../../darwodin/darwodin-macos-lite/darwodin/AppKit"
// import CG "../../../darwodin/darwodin-macos-lite/darwodin/CoreGraphics"
// import NSF "../../../darwodin/darwodin-macos-lite/darwodin/Foundation"
msgSend :: intrinsics.objc_send


platform_calls_step :: false

Window :: NS.Window

@require_results
create_window :: proc (
  rect: [4]int, // xywh
  title: string,
  use_gl: bool
) -> bool {
  NS.application_delegate_register_and_alloc({}, title, context)
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
    doDefer = false) // defer? NO
  title_str: ^NS.String = NS.String.alloc()->initWithOdinString(title)
  window->setTitle(title_str)
  window->makeKeyAndOrderFront(nil)
  content_view := window->contentView()
  assert(content_view != nil)
  pixel_format_attributes := []OpenGLPixelFormatAttribute {
    .OpenGLProfile, .NSOpenGLProfileVersion3_2Core,
    .ColorSize,     auto_cast 24,
    .AlphaSize,     auto_cast 8,
    .DoubleBuffer,
    .Accelerated,
    auto_cast 0 // sentinel
  }
  pixel_format := OpenGLPixelFormat.alloc()->initWithAttributes(raw_data(pixel_format_attributes))
  ctx: ^OpenGLContext = auto_cast OpenGLContext.alloc()->initWithFormat(pixel_format, nil)
  assert(ctx != nil)
  ctx->setView(content_view)
  ctx->makeCurrentContext()
  //
// Set_Proc_Address_Type :: #type proc(p: rawptr, name: cstring)
  set_proc_address :: proc (set_me: rawptr, name: cstring) {
    dest := set_me
    source: rawptr = posix.dlsym(transmute(posix.Symbol_Table)int(-1), name)
    log.debugf("%v = %v AKA %s", dest, source, name)
    ensure(dest != nil)
    (^rawptr)(set_me)^ = source
    ensure(dest != nil)
  }
  gl.load_up_to(3, 2, set_proc_address)
  // TODO: Version check the context.
  // actual_version: [2]int
  // gl.glGetIntegerv(gl.MAJOR_VERSION, &actual_version[0])
  // gl.glGetIntegerv(gl.MINOR_VERSION, &actual_version[1])
  // log.debugf("Mac GL Version: %v", actual_version)
  // if actual_version.x < CONTEXT_MAJOR || actual_version.y < CONTEXT_MINOR {
  //   log.errorf("Insufficient GL version. Got %v", actual_version)
  //   return false
  // }
  //
  return true
}

swap_buffers :: proc () {
}

capture_cursor :: proc () {
}

set_cursor_visible :: proc (show: bool) {
}

//////////////////////////////////////////////////////////////////////
@(objc_class="NSOpenGLContext")
OpenGLContext :: struct {
    using _: NS.Object, 
    using _: NS.Locking(NS.Object), // unsure about NS.Object this line.
}

@(objc_type=OpenGLContext,objc_name="setView")
OpenGLContext_setView :: proc "c" (self: ^OpenGLContext, view: ^NS.View) {
    msgSend(^OpenGLContext, self, "setView:", view)
}

@(objc_type=OpenGLContext, objc_name="makeCurrentContext")
OpenGLContext_makeCurrentContext :: #force_inline proc "c" (self: ^OpenGLContext) {
    msgSend(^OpenGLContext, self, "makeCurrentContext")
}

@(objc_type=OpenGLContext, objc_name="alloc", objc_is_class_method=true)
OpenGLContext_alloc :: #force_inline proc "c" () -> ^OpenGLContext {
    return msgSend(^OpenGLContext, OpenGLContext, "alloc")
}

@(objc_type=OpenGLContext, objc_name="initWithFormat")
OpenGLContext_initWithFormat :: #force_inline proc "c" (self: ^OpenGLContext, format: ^OpenGLPixelFormat, share: ^OpenGLContext) -> ^OpenGLContext {
    return msgSend(^OpenGLContext, self, "initWithFormat:shareContext:", format, share)
}
//////////////////////////////////////////////////////////////////////
@(objc_class="NSOpenGLPixelFormat")
OpenGLPixelFormat :: struct {
  using _: NS.Object, 
  // using _: NS.Coding,
}

@(objc_type=OpenGLPixelFormat, objc_name="alloc", objc_is_class_method=true)
OpenGLPixelFormat_alloc :: #force_inline proc "c" () -> ^OpenGLPixelFormat {
    return msgSend(^OpenGLPixelFormat, OpenGLPixelFormat, "alloc")
}

// @(objc_type=OpenGLPixelFormat, objc_name="init")
// OpenGLPixelFormat_init :: proc "c" (self: ^OpenGLPixelFormat) -> ^OpenGLPixelFormat {
//     return msgSend(^OpenGLPixelFormat, self, "init")
// }

@(objc_type=OpenGLPixelFormat, objc_name="initWithAttributes")
OpenGLPixelFormat_initWithAttributes :: #force_inline proc "c" (self: ^OpenGLPixelFormat, attribs: [^]OpenGLPixelFormatAttribute) -> ^OpenGLPixelFormat {
    return msgSend(^OpenGLPixelFormat, self, "initWithAttributes:", attribs)
}

//////////////////////////////////////////////////////////////////////
// Per NSOpenGL.h
OpenGLPixelFormatAttribute:: enum u32 {
    AllRenderers            =   1, /* choose from all available renderers          NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    TripleBuffer            =   3, /* choose a triple buffered pixel format        NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    DoubleBuffer            =   5, /* choose a double buffered pixel format        NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    AuxBuffers              =   7, /* number of aux buffers                        NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    ColorSize               =   8, /* number of color buffer bits                  NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    AlphaSize               =  11, /* number of alpha component bits               NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    DepthSize               =  12, /* number of depth buffer bits                  NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    StencilSize             =  13, /* number of stencil buffer bits                NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    AccumSize               =  14, /* number of accum buffer bits                  NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    MinimumPolicy           =  51, /* never choose smaller buffers than requested  NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    MaximumPolicy           =  52, /* choose largest buffers of type requested     NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    SampleBuffers           =  55, /* number of multi sample buffers               NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    Samples                 =  56, /* number of samples per multi sample buffer    NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    AuxDepthStencil         =  57, /* each aux buffer has its own depth stencil    NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    ColorFloat              =  58, /* color buffers store floating point pixels    NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    Multisample             =  59, /* choose multisampling                         NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    Supersample             =  60, /* choose supersampling                         NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    SampleAlpha             =  61, /* request alpha filtering                      NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    RendererID              =  70, /* request renderer by ID                       NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    NoRecovery              =  72, /* disable all failure recovery systems         NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    Accelerated             =  73, /* choose a hardware accelerated renderer       NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    ClosestPolicy           =  74, /* choose the closest color buffer to request   NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    BackingStore            =  76, /* back buffer contents are valid after swap    NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    ScreenMask              =  84, /* bit mask of supported physical screens       NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    AllowOfflineRenderers   =  96,  /* allow use of offline renderers              NS_OPENGL_ENUM_DEPRECATED(10.5, 10.14)*/
    AcceleratedCompute      =  97, /* choose a hardware accelerated compute device NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    OpenGLProfile           =  99, /* specify an OpenGL Profile to use             NS_OPENGL_ENUM_DEPRECATED(10.7, 10.14)*/
    VirtualScreenCount      = 128, /* number of virtual screens in this format     NS_OPENGL_ENUM_DEPRECATED(10.0, 10.14)*/
    
    // Stereo                API_DEPRECATED("", macos(10.0,10.12))     =   6,
    // OffScreen             API_DEPRECATED("", macos(10.0,10.7))      =  53,
    // FullScreen            API_DEPRECATED("", macos(10.0,10.6))      =  54,
    // SingleRenderer        API_DEPRECATED("", macos(10.0,10.9))      =  71,
    // Robust                API_DEPRECATED("", macos(10.0,10.5))      =  75,
    // MPSafe                API_DEPRECATED("", macos(10.0,10.5))      =  78,
    // Window                API_DEPRECATED("", macos(10.0,10.9))      =  80,
    // MultiScreen           API_DEPRECATED("", macos(10.0,10.5))      =  81,
    // Compliant             API_DEPRECATED("", macos(10.0,10.9))      =  83,
    // PixelBuffer           API_DEPRECATED("", macos(10.3,10.7))      =  90,
    // RemotePixelBuffer     API_DEPRECATED("", macos(10.3,10.7))      =  91,

    // These 3 are a different enum, but here for convenience.
    NSOpenGLProfileVersionLegacy      = 0x1000,   /* choose a Legacy/Pre-OpenGL 3.0 Implementation NS_OPENGL_ENUM_DEPRECATED(10.7, 10.14) */
    NSOpenGLProfileVersion3_2Core     = 0x3200,   /* choose an OpenGL 3.2 Core Implementation      NS_OPENGL_ENUM_DEPRECATED(10.7, 10.14) */
    NSOpenGLProfileVersion4_1Core     = 0x4100    /* choose                                        NS_OPENGL_ENUM_DEPRECATED(10.10, 10.14)*/
}
