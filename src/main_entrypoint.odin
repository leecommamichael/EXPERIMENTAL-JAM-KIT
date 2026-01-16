package main

// Purposes:
// - General Initialization
// - Establishing the input/simulate/render loop.
//
// The platform-layer (main_entrypoint.odin) hides OS details such that
// the framework-layer (main_framework.odin) can hide subsystem-details for
// the game-layer (main_game.odin) to leverage seamlessly.
//
// A "subsystem" might be something like rendering or collision-detection.
//
// Major structs defined by each layer:
// - Platform:  sugar.Memory
// - Framework: Globals, Entity, Ren, Any_Instance, Collision
// - Game:      Game_State

import "base:runtime"
import "core:time"
import "core:log"
import "sugar"
import "audio"
import gl "angle"

EJK_DLL :: #config(EJK_DLL, false)

main :: proc() {
	when EJK_DLL do return // compiling with -no-entry-point failed to link.

	globals = new(Globals)
	when !sugar.platform_calls_step {
		context.logger = create_sublime_text_logger()
	} else when ODIN_OS == .JS {
		runtime.default_context_ptr().logger = create_sublime_text_logger()
		context = runtime.default_context_ptr()^
	}
	_, k := audio.init(); assert(k)
	sugar.set_memory(&globals.sugar)
	sugar.init()
	asset_init()
	displays := sugar.list_displays()
	display := displays[1] if len(displays) > 1 else displays[0]
	ok := sugar.create_window(
		[4]int{
			2 + display.top_left.x,
			44+ display.top_left.y, 0,0} + ({430,430, 640, 400}),
		"SimSettlement",
		use_gl = true
	)
	if !ok { panic("Window creation failed.") }


	asset_upload()
	framework_init()

	when sugar.platform_calls_step { return }
	
	gl_debug_proc :: proc "c" (
		source: gl.GLuint,
		type: gl.GLuint,
		id: gl.GLuint,
		severity: gl.GLuint,
		length: int,
		message: cstring,
		userParam: rawptr,
	) {
		context = (cast(^runtime.Context) userParam)^
		if type == gl.DEBUG_SEVERITY_MEDIUM {
			log.warnf("%v", message)
		} else if type == gl.DEBUG_SEVERITY_HIGH {
			log.errorf("%v", message)
		} else {
			// log.infof("%v", message)
		}
	}
	ctx := context
	gl.glDebugMessageCallback(gl_debug_proc, &ctx)

	tick := time.tick_now()
	dt: f64
	for {
		dt = time.duration_seconds(time.tick_lap_time(&tick))
		step(dt) or_break
	}
}

// This is an entry-point, and so all game data must be globally visible for Web support.
// The context is defaulted each time you enter. Related: `runtime.default_context_ptr()`
@export
step :: proc (dt: f64) -> bool {
	dt: f32 = f32(dt)
////////////////////////////////////////////////////////////////////////////////
	@static start_time: time.Tick
	if globals.tick_counter == 1 {
		log_runtime("first_paint")
		start_time = time.tick_now()
	}
	globals.avg_fps = f64(globals.tick_counter) / time.duration_seconds(time.tick_since(start_time))
	if globals.tick_counter % 300 == 0 {
		// log.infof("[FPS] %v", globals.avg_fps)
	}
////////////////////////////////////////////////////////////////////////////////
	@static tick_buildup: f32
	for tick_buildup += dt; tick_buildup >= globals.tick; tick_buildup -= globals.tick {
		events := sugar.poll_events() // begins input frame.
		if .Should_Exit in events { return false }
		if .Window_Scale_Factor_Changed in events {
			// Noop
		}
		if .Window_Resized in events {
			window_resized()
		}

		if sugar.on_key_release(.Escape) || sugar.on_button_release(.Select) {
			return false
		}
		framework_step(dt)
		sugar.end_input_frame()
		globals.tick_counter += 1
		// when ODIN_DEBUG do break
	}

	framework_draw(tick_buildup/globals.tick)
	free_all(context.temp_allocator)
	return true
}

import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
// INTENT: To set the framebuffer_size_px of the render target, and resize the GL.Viewport.
window_resized :: proc () {
	viewport_size := array_cast(globals.sugar.viewport_size,f32)
	////////////////////////////////////////////////////////////////////////////
	// decide how the viewport will be sized. affects render-target size.
	switch globals.canvas_scaling {
	case .Smooth_Aspect:
		ratios := viewport_size/globals.canvas_size_px
		globals.canvas_scale = vec_min(ratios)
	case .Fill_Window:
		globals.canvas_scale = viewport_size / globals.canvas_size_px
	case .Integer_Aspect:
		integer_scales := trunc(viewport_size / globals.canvas_size_px)
		globals.canvas_scale = vec_min(integer_scales)
	case .None:
	}
	////////////////////////////////////////////////////////////////////////////
	scaled_canvas_px := globals.canvas_scale * globals.canvas_size_px
	casted := array_cast(scaled_canvas_px, int)
	if globals.ren.canvas.size_px != casted {
		log.infof("canvas resized from %v to %v", globals.ren.canvas.size_px, casted)
		set_canvas_size(casted)
	}
	unused_px := viewport_size - scaled_canvas_px 
	// decide how the viewport will be stretched after sizing.
	switch globals.canvas_stretching {
	case .Smooth_Aspect:
		ratios := viewport_size/globals.canvas_size_px
		globals.canvas_stretch = vec_min(ratios)
		// globals.canvas_stretch = vec_min(viewport_size) / vec_max(scaled_canvas_px)
	case .Fill_Window:
		globals.canvas_stretch = 1.0 + unused_px / viewport_size
	case .Integer_Aspect:
		integer_scales := trunc(viewport_size / scaled_canvas_px)
		globals.canvas_stretch = vec_min(integer_scales)
	case .None:
	}
	// framebuffer is the actual scaled & stretched rect we're drawing
	globals.framebuffer_size_px = globals.canvas_size_px *
	                              globals.canvas_scale *
	                              globals.canvas_stretch
	////////////////////////////////////////////////////////////////////////////
	log.infof("viewport = %v", viewport_size)
	log.infof("stretch = %v", globals.canvas_stretch)
	log.infof("scale = %v", globals.canvas_scale)
  gl.Viewport(0,0, globals.sugar.viewport_size.x, globals.sugar.viewport_size.y)
  build_camera()
}

// Takes a size in pixels for the framebuffer.
// If you're just stretching, and not scaling, this doesn't need to be used.
set_canvas_size :: proc (size_px: [2]int, _loc := #caller_location) {
	make_or_resize_render_target(&globals.ren.canvas, size_px, _loc)
	globals.uniforms.canvas_size_px = globals.canvas_size_px
}

// As Z is greater, depth values are lesser, and sorted to draw later.
// So the Z cursor for UI should probably start far (near) and come near.
FAR_Z  :: -10000 // furthest.
NEAR_Z  :: 10000 // nearest.
// This assert protects range-checks.
#assert(NEAR_Z > 0); #assert(FAR_Z < 0);

build_camera :: proc () {
	viewport_size := array_cast(globals.sugar.viewport_size,f32)
	aspect_ratio := viewport_size.x / viewport_size.y

	globals.perspective_projection = linalg.matrix4_perspective_f32(
		fovy   = linalg.to_radians(f32(90.0)),
		aspect = aspect_ratio,
		near   = .1,
		far    = 1000,
		flip_z_axis = false
	)
	globals.ui_projection = glsl.mat4Ortho3d(
		left   = 0,
		right  = viewport_size.x,
		top    = viewport_size.y,
		bottom = 0,
		near   = FAR_Z, // yes, it's flipped
		far    = NEAR_Z
	)

	offset := globals.camera.offset
	zoom := globals.camera.zoom
	globals.orthographic_projection = glsl.mat4Ortho3d(
		left   = 0,
		right  = viewport_size.x,
		top    = viewport_size.y,
		bottom = 0,
		near   = FAR_Z, // yes, it's flipped
		far    = NEAR_Z
	)
	globals.orthographic_view = linalg.matrix4_translate_f32({offset.x, offset.y, 0})\
	                          * linalg.matrix4_scale_f32({zoom, zoom, 1})
}