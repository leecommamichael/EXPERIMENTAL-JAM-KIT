package main

import "base:runtime"
import "core:time"
import "core:log"
import "core:slice"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"
import sugar "sugar"

main :: proc() {
	context.logger = log.create_console_logger(
		lowest = log.Level.Debug,
		opt = { .Level, } 
	)
	x := 1920 + 400 when ODIN_OS == .Windows else 0
	y := 400 when ODIN_OS == .Windows else 0
	window_rect := [4]int{x,y, 900, 900}
	ok := sugar.create_window(window_rect, "TCM", use_gl = true)
	ensure(ok)
	sugar.capture_cursor()
	sugar.set_cursor_visible(false)
	
	if sugar.platform_calls_step do return // Probably just Web.

	tick := time.tick_now()
	dt: f64
	frame_loop: for {
		dt = time.duration_seconds(time.tick_lap_time(&tick))
		if !step(dt) {
			break frame_loop
		}
	}
}

// This is an entry-point, and so all game data must be globally visible for Web support.
@export
step :: proc (dt: f64) -> bool {
	globals.time += f32(dt)
	globals.tau_time += f32(dt)
	overflow := linalg.TAU - globals.tau_time
	if overflow >= 0 {
		globals.tau_time = overflow
	}

	switch sugar.poll_events() {
	case .None:
	case .Should_Exit:
		return false
	case .Resized:
		resolution_changed(sugar.g_state.resolution)
	}

	if !game_initialized {
		when ODIN_OS == .JS {
			runtime.default_context_ptr().logger = log.create_console_logger(
				lowest = log.Level.Debug,
				opt = { .Level, } 
			)
		}
		game_initialized = true
		init_gl_constants :: proc () {
			assert(gl.GetIntegerv != nil, "GL not loaded.")
			globals.gl_standard.UNIFORM_BUFFER_OFFSET_ALIGNMENT = gl.GetIntegerv(.UNIFORM_BUFFER_OFFSET_ALIGNMENT)
			globals.gl_standard.MAX_UNIFORM_BLOCK_SIZE          = gl.GetInteger64v(.MAX_UNIFORM_BLOCK_SIZE)
			log.infof("OpenGL Platform Constants ---\n" +
				"  MAX_UNIFORM_BLOCK_SIZE:          %v Bytes\n" +
				"  UNIFORM_BUFFER_OFFSET_ALIGNMENT: %v Bytes",
				globals.gl_standard.MAX_UNIFORM_BLOCK_SIZE,
				globals.gl_standard.UNIFORM_BUFFER_OFFSET_ALIGNMENT
			)
		}
		init_gl_constants()
		#assert(size_of(Ren_Instance) < (1 << 14), "Instances may not fit in one Uniform Block")
		globals.instances = make_aligned_array(
			Ren_Instance,
			cast(int) max(Entity_ID),
			cast(int) globals.gl_standard.UNIFORM_BUFFER_OFFSET_ALIGNMENT
		)

		// 1. Init Globals /////////////////////////////////////////////////////////
		globals.camera.position.y = 5
		globals.game_view = 1
		globals.ui_view = 1
		game_entities := make([]^Entity_Memory, max(Entity_ID))
		globals.game_entities = slice.into_dynamic(game_entities)
		ui_entities := make([]^Entity_Memory, max(Entity_ID))
		globals.ui_entities = slice.into_dynamic(ui_entities)
		entities := make([]^Entity_Memory, max(Entity_ID))
		globals.entities = slice.into_dynamic(entities)
		globals.ren = ren_make()	
		ren_init(globals.ren)
		globals.plane_mesh = geom_make_xz_plane(plane_size = PLANE_SIZE, squares_per_axis = AXIS_SQUARES)
		plane_asset := ren_make_basic_asset(globals.ren, globals.plane_mesh.vertices[:], globals.plane_mesh.indices[:], globals.ren.instance_UBO)
		v,i := make_circle_2D(44.0)
		cursor_asset := ren_make_basic_asset(globals.ren, v, i, globals.ren.instance_UBO)
		vm,im := make_circle_2D(0.5)
		marker_asset := ren_make_basic_asset(globals.ren, vm, im, globals.ren.instance_UBO)

		globals.water_plane = make_entity()
		globals.water_plane._asset = plane_asset
		globals.water_plane._asset.mode = .Line_Loop

		globals.marker = make_entity()
		globals.marker._asset = marker_asset
		globals.marker.rotation.x = f32(linalg.PI/2)

		// 2. Init Inputs //////////////////////////////////////////////////////////
		globals.quit = sugar.Button_Action {
			button = &sugar.g_state.input.keys[sugar.Key.Escape],
		}
		globals.left_click = sugar.Button_Action {
			button = &sugar.g_state.input.keys[sugar.Key.Left_Mouse],
		}
		globals.right_click = sugar.Button_Action {
			button = &sugar.g_state.input.keys[sugar.Key.Right_Mouse],
		}
		globals.space = sugar.Button_Action {
			button = &sugar.g_state.input.keys[sugar.Key.Space],
		}
	}

	// 3. Fill Caches //////////////////////////////////////////////////////////// 
	clear(&globals.entities)
	clear(&globals.game_entities)
	clear(&globals.ui_entities)
	for &e in globals._entity_storage {
		if e._used {
			append(&globals.entities, &e)
		}
	}
	// 4. Simulate /////////////////////////////////////////////////////////////// 
	//////////////////////////////////////////////////////////////////////////////
	globals.game_view = tick_mouse_camera(&globals.camera, f32(dt))
	step_water(dt)

	if sugar.on_release(&globals.quit) {
		return false // stop the app
	}

	// globals.cursor.position = vec3(sugar.g_state.input.mouse.window)

	cost := glsl.cos(globals.tau_time * 4)
	sint := glsl.sin(globals.tau_time * 4)
	globals.marker.position = vec3(1*cost, 0, 1*sint)
	globals.marker.position +=  vec3(0,0,8)
	if (cost) > 0.99 {
		globals.marker.color = vec4(1,0,0,1)
	} else if (sint) > 0.99 {
		globals.marker.color = vec4(0,0,1,1)
	} else {
		globals.marker.color = vec4(0,0,0,1)
	}
	
	////////////////////////////////////////////////////////////////////////////// 
	// 5. Prepare Frame and Draw /////////////////////////////////////////////////
	finalize_simulation_frame :: proc () {
		for &entity in globals.entities {
			if entity.hidden {
				// INTENT: If an object is hiddesugar.n, don't add it to render-lists.
				continue
			}

			entity.model_transform =
				linalg.matrix4_translate(entity.position) *
				linalg.matrix4_from_euler_angles_xyz_f32(entity.rotation.x, entity.rotation.y, entity.rotation.z) *
				linalg.matrix4_scale(entity.scale)
			if entity._ui {
				append(&globals.ui_entities, entity)
			} else {
				// TODO: Bucket Opaque from Transparent
				// ASSUME: Centroid is 0,0,0 in model coordinates
				centroid: Vec4 : { 0, 0, 0, 1 }
		    entity_centroid_in_world := entity.model_transform * centroid
				entity._distance_from_camera = glsl.distance(entity_centroid_in_world.xyz, globals.camera.position)
				append(&globals.game_entities, entity)
			}
		}
		// IDEA: Could use the same sort for UI and interpret it at Z index.
	  slice.sort_by(globals.game_entities[:], proc (i,j: ^Entity_Memory) -> bool {
	    return i._distance_from_camera > j._distance_from_camera
	  })
	}
	finalize_simulation_frame()
	ren_draw(globals.ren)
	sugar.end_input_frame()
	sugar.swap_buffers()
	return true // keep going
}

resolution_changed :: proc (res: [2]int) {
	globals.aspect_ratio = cast(f32)res.x / cast(f32)res.y
	globals.resolution = res
	// linalg.matrix4_perspective
	globals.game_camera = linalg.matrix4_perspective_f32(
		fovy   = linalg.to_radians(f32(90.0)),
		aspect = globals.aspect_ratio,
		near   = .1,
		far    = 1000,
		flip_z_axis = false
	)
	globals.ui_orthographic = glsl.mat4Ortho3d(
		left   = 0,
		right  = cast(f32) res.x,
		top    = 0,
		bottom = cast(f32) res.y,
		near   = -10,
		far    = 1000
	)
}

// I can flush about 4 million vertices each frame and _just_ hit 60fps.
// We can eliminate the data-transfer time by using a vertex shader.
// Let's see the effect of that.

PLANE_SIZE    :: 256
AXIS_SQUARES  :: 1400 // Squares per axis
AXIS_POINTS   :: AXIS_SQUARES + 1
PLANE_SQUARES :: AXIS_SQUARES * AXIS_SQUARES

step_water :: proc (dt: f64) {
	using globals
	using glsl
	for i in 0 ..< PLANE_SQUARES {
		x := i / AXIS_POINTS
		y := i % AXIS_POINTS
		plane_mesh.vertices[(y*AXIS_POINTS)+x].position.y = 1.5 * sin((0.2*time) + f32(y))
	}
	gl.BindBuffer(.ARRAY_BUFFER, water_plane._asset.VBO)
	gl.BufferSubData(.ARRAY_BUFFER, 0, plane_mesh.vertices[:])
}