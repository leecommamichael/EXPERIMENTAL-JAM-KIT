package main

import "core:log"
import "core:slice"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"
import sugar "sugar"

app_init :: proc () {
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
	globals.plane_mesh = geom_make_xz_plane(squares_per_axis = AXIS_SQUARES)
	plane_asset := ren_make_basic_asset(globals.ren, globals.plane_mesh.vertices[:], globals.plane_mesh.indices[:], globals.ren.instance_UBO)
	v,i := make_circle_2D(44.0)
	cursor_asset := ren_make_basic_asset(globals.ren, v, i, globals.ren.instance_UBO)
	vm,im := make_circle_2D(0.5)
	marker_asset := ren_make_basic_asset(globals.ren, vm, im, globals.ren.instance_UBO)

	globals.water_plane = make_entity()
	globals.water_plane._asset = plane_asset
	globals.water_plane._asset.program = globals.ren.programs[.Water]
	globals.water_plane.color = vec4(0.33, 0.45, 0.9, 1)
	// globals.water_plane._asset.mode = .Line_Loop

	globals.marker = make_entity()
	globals.marker._asset = marker_asset
	globals.marker.rotation.x = f32(linalg.PI/2)
	globals.marker.hidden = true

	globals.water_heightmap = make([]f16, PLANE_POINTS)
	tex: uint
	gl.glGenTextures(1, &tex)
	gl.glBindTexture(gl.TEXTURE_2D, tex)
	gl.glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, auto_cast gl.REPEAT)
	gl.glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, auto_cast gl.REPEAT)
	gl.glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl.NEAREST)
	gl.glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl.NEAREST)

	gl.glPixelStorei(gl.UNPACK_ALIGNMENT,2)
	gl.TexImage2D(
		.TEXTURE_2D,
		0, // LOD
		cast(int) gl.R16F,
		AXIS_POINTS,
		AXIS_POINTS,
		gl.RED,
		gl.HALF_FLOAT,
		globals.water_heightmap)
}

app_step :: proc (dt: f64) {
	globals.uniforms.tau_time += f32(dt)
	overflow := linalg.TAU - globals.uniforms.tau_time
	if overflow >= 0 {
		globals.uniforms.tau_time = overflow
	}
	globals.uniforms.time += f32(dt)


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


	// globals.cursor.position = vec3(sugar.input.mouse_position)

	cost := glsl.cos(globals.uniforms.tau_time * 4)
	sint := glsl.sin(globals.uniforms.tau_time * 4)
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

AXIS_SQUARES  :: 1000 // Squares per axis
AXIS_POINTS   :: AXIS_SQUARES + 1
PLANE_SQUARES :: AXIS_SQUARES * AXIS_SQUARES
PLANE_POINTS :: AXIS_POINTS * AXIS_POINTS

step_water :: proc (dt: f64) {
	using globals
	using glsl
	// I can't use a loop var.
	// I need to use the data of the buffer (vert positions) to derive x,y which derive Y.
	for i in 0 ..< PLANE_POINTS {
		pos := &plane_mesh.vertices[i].position
		x := cast(int) pos.x
		z := cast(int) pos.z
		// derived_y := 1.5 * sin((0.2*uniforms.tau_time) + f32(x))
		// plane_mesh.vertices[i].position.y = derived_y
		height_func(x, z, cast(^f16) &water_heightmap[i])
	}
	// Sync Debug Mesh
	// gl.BindBuffer(.ARRAY_BUFFER, water_plane._asset.VBO)
	// gl.BufferSubData(.ARRAY_BUFFER, 0, plane_mesh.vertices[:])
	// Sync 
	gl.TexSubImage2D(
		target  = .TEXTURE_2D,
		level   = 0,
		xoffset = 0,
		yoffset = 0,
		width  = AXIS_POINTS,
		height = AXIS_POINTS,
		format = gl.RED,
		type   = gl.HALF_FLOAT,
		data   = globals.water_heightmap)
}

height_func :: #force_inline proc (x, z: int, y: ^f16) {
	using globals
	using glsl
	derived_y := 1.5 * sin((0.2*uniforms.tau_time) + f32(x))
	y^ = cast(f16) derived_y
}