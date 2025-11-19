package main

import "base:runtime"
import "core:time"
import "core:log"
import "sugar"
import "audio"

main :: proc() {
	when !sugar.platform_calls_step {
		context.logger = create_sublime_text_logger()
	} else when ODIN_OS == .JS {
		runtime.default_context_ptr().logger = create_sublime_text_logger()
		context = runtime.default_context_ptr()^
	}
	_, k := audio.init(); assert(k)
	sugar.init()
	asset_init()
	displays := sugar.list_displays()
	display := displays[1] if len(displays) > 1 else displays[0]
	ok := sugar.create_window(
		[4]int{
			display.top_left.x,
			display.top_left.y, 0,0} + {2,44,0,0} + (1*{0,0,960,720}),
		"Tonic",
		use_gl = true
	)
	if !ok { panic("Window creation failed.") }

	asset_upload()
	framework_init()

	when sugar.platform_calls_step { return }

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
	@static start_time: time.Tick
	@static frame_number: uint = 0
	if frame_number == 1 {
		log_runtime("first_paint")
		start_time = time.tick_now()
	}
	globals.avg_fps = f64(frame_number) / time.duration_seconds(time.tick_since(start_time))
	if frame_number % 300 == 0 {
		// log.infof("[FPS] %v", globals.avg_fps)
	}
	frame_number += 1
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
	free_all(context.temp_allocator)
	return true
}

import gl "nord_gl"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
window_resized :: proc () {
	viewport_size := array_cast(sugar.viewport_size,f32)
	////////////////////////////////////////////////////////////////////////////
	// decide how the viewport will be sized. affects render-target size.
	switch globals.canvas_scaling {
	case .Smooth_Aspect:
		globals.canvas_scale = vec_min(viewport_size) / vec_max(globals.canvas_size_px)
	case .Fill_Window:
		globals.canvas_scale = viewport_size / globals.canvas_size_px
	case .Integer_Aspect:
		integer_scales := trunc(viewport_size / globals.canvas_size_px)
		globals.canvas_scale = vec_min(integer_scales)
	case .Fixed:
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
		globals.canvas_stretch = vec_min(viewport_size) / vec_max(scaled_canvas_px)
	case .Fill_Window:
		globals.canvas_stretch = 1.0 + unused_px / viewport_size
	case .Integer_Aspect:
		integer_scales := trunc(viewport_size / scaled_canvas_px)
		globals.canvas_stretch = vec_min(integer_scales)
	case .Fixed:
	}
	globals.framebuffer_size_px = globals.canvas_size_px *
	                              globals.canvas_scale *
	                              globals.canvas_stretch
	////////////////////////////////////////////////////////////////////////////
	log.infof("viewport = %v", viewport_size)
	log.infof("stretch = %v", globals.canvas_stretch)
	log.infof("scale = %v", globals.canvas_scale)
  gl.Viewport(0,0, sugar.viewport_size.x, sugar.viewport_size.y)
  build_camera()
}

set_canvas_size :: proc (size_px: [2]int, _loc := #caller_location) {
	make_or_resize_render_target(&globals.ren.canvas, size_px, _loc)
}

// YES, I KNOW. These are opposite the near/far args in matrix procs.
MAX_Z  :: 10000 // furthest.
MIN_Z  :: -10000 // nearest.

build_camera :: proc () {
	viewport_size := array_cast(sugar.viewport_size,f32)
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
		near   = MAX_Z,
		far    = MIN_Z
	)

	offset := globals.camera.offset
	zoom := globals.camera.zoom
	globals.orthographic_projection = glsl.mat4Ortho3d(
		left   = 0,
		right  = viewport_size.x,
		top    = viewport_size.y,
		bottom = 0,
		near   = MAX_Z,
		far    = MIN_Z // the parameter label says "far" but I'm inverting it.
	)
	globals.orthographic_view = linalg.matrix4_translate_f32({offset.x, offset.y, 0})\
	                          * linalg.matrix4_scale_f32({zoom, zoom, 1})
}