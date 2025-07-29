package sugar

import "base:runtime"
import "base:intrinsics"
import "core:log"
import "core:sys/darwin"

import NS "../../darwodin/darwodin-macos-lite/darwodin/AppKit"
import CG "../../darwodin/darwodin-macos-lite/darwodin/CoreGraphics"
import NSF "../../darwodin/darwodin-macos-lite/darwodin/Foundation"

platform_calls_step :: false

Window :: NS.Window

@require_results
create_window :: proc (
  rect: [4]int, // xywh
  title: string,
  use_gl: bool
) -> bool {
  app_delegate := AppDelegate.alloc()->initWithContext(context)
  app := NS.Application.sharedApplication()
  app->setActivationPolicy(.Regular)
  app->activate()
  app->setDelegate(app_delegate)

  window_rect: NSF.Rect = {
    origin = { CG.Float(rect.x), CG.Float(rect.y) },
    size = { CG.Float(rect[2]), CG.Float(rect[3]) }
  }
  window: ^Window = NS.Window.alloc()->initWithContentRect_styleMask_backing_defer(
    contentRect = window_rect,
    style = { .Titled, .Closable, .Resizable },
    backingStoreType = .Buffered,
    flag = false) // defer? NO
  title_str: ^NSF.String = NSF.String.alloc()->initWithBytes(
    raw_data(title),
    auto_cast len(title),
    NSF.UTF8StringEncoding)
  window->setTitle(title_str)
  window->makeKeyAndOrderFront(nil)
  content_view := window->contentView()
  // pixel_format_attributes := []NS.OpenGLPixelFormatAttribute {
  //   NS.OpenGLPFAOpenGLProfile, NS.OpenGLProfileVersion3_2Core,
  //   NS.OpenGLPFAColorSize, 24,
  //   NS.OpenGLPFAAlphaSize, 8,
  //   NS.OpenGLPFADoubleBuffer,
  //   NS.OpenGLPFAAccelerated,
  //   0
  // }
  pixel_format := NS.OpenGLPixelFormat.alloc()->init()
  ctx := NS.OpenGLContext.alloc()->init()
  ctx->setView(content_view)
  ctx->makeCurrentContext()
  // NSOpenGLContext *glContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
  // // Attach to the existing view
  // [glContext setView:contentView];
  // [glContext makeCurrentContext];

  return true
}

swap_buffers :: proc () {
}

capture_cursor :: proc () {
}

set_cursor_visible :: proc (show: bool) {
}

// Private /////////////////////////////////////////////////////////////////////
@(objc_class="AppDelegate",
  objc_superclass=NSF.Object,
  objc_implement)
AppDelegate :: struct {
  using _: NSF.Object,
  using _: NS.ApplicationDelegate,
}

@(objc_implement,
  objc_is_class_method=true,
  objc_type=AppDelegate,
  objc_name="alloc")
AppDelegate_alloc :: proc "c" () -> ^AppDelegate {
  return intrinsics.objc_send(^AppDelegate, AppDelegate, "alloc")
}

@(objc_implement,
  objc_type = AppDelegate,
  objc_name = "initWithContext")
AppDelegate_initWithContext :: proc "c" (
  self: ^AppDelegate,
  ctx: runtime.Context
) -> ^AppDelegate {
  return self
}

@(objc_implement,
  objc_type=AppDelegate,
  objc_name="applicationDidFinishLaunching",
  objc_selector="applicationDidFinishLaunching:")
AppDelegate_applicationDidFinishLaunching :: proc "c" (
  self: ^AppDelegate,
  notification: ^NSF.Notification
) {
  // NOOP
}
