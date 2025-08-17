package main

// Purpose: This file provides resources to various subsystems.
// 						e.g. Rendering, Entities, Physics, Audio
//          It also integrates these resources such that the game
//          can make use of them with a smaller API.

import "core:log"
import "core:slice"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

framework_init :: proc () {
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
	ren_text_init()
	game_init()
}

// Mixed-scope between renderer and game entities.
framework_step :: proc (dt: f64) {
	ren_clear()
	globals.uniforms.tau_time += f32(dt)
	overflow := linalg.TAU - globals.uniforms.tau_time
	if overflow >= 0 {
		globals.uniforms.tau_time = overflow
	}
	globals.uniforms.time += f32(dt)

	// 1. Fill Caches //////////////////////////////////////////////////////////// 
	clear(&globals.entities)
	clear(&globals.game_entities)
	clear(&globals.ui_entities)
	for &e in globals._entity_storage {
		if e._used {
			append(&globals.entities, &e)
		}
	}
	// 2. Simulate /////////////////////////////////////////////////////////////// 
	//////////////////////////////////////////////////////////////////////////////
	game_step(dt)
	////////////////////////////////////////////////////////////////////////////// 
	// 3. Prepare Frame and Draw /////////////////////////////////////////////////
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
}

// TODO: Read various data from Globals such that the game
//       can program the camera simply by setting parameters.
resolution_changed :: proc (res: [2]int) {
	aspect_ratio := cast(f32)res.x / cast(f32)res.y
	globals.game_camera = linalg.matrix4_perspective_f32(
		fovy   = linalg.to_radians(f32(90.0)),
		aspect = aspect_ratio,
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
