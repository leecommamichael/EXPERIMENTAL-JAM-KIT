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
		assert(gl.glGetIntegerv != nil, "GL not loaded.")
	  assert(gl.glGetInteger64v != nil)
		globals.gl_standard.UNIFORM_BUFFER_OFFSET_ALIGNMENT = gl.GetIntegerv(.UNIFORM_BUFFER_OFFSET_ALIGNMENT)
		globals.gl_standard.MAX_UNIFORM_BLOCK_SIZE          = gl.GetInteger64v(.MAX_UNIFORM_BLOCK_SIZE)
		globals.gl_standard.MAX_TEXTURE_SIZE                = gl.GetInteger64v(.MAX_TEXTURE_SIZE)
		log.infof("OpenGL Platform Constants ---\n%#v", globals.gl_standard)
	}
	init_gl_constants()
	// META: The below assert is out of date. My instances aren't in UBOs.
	// #assert(size_of(Any_Instance) < (1 << 14), "Instances may not fit in one Uniform Block")
	// globals.ubo_instance_data = make_aligned_array(
	// 	Ren_Instance,
	// 	cast(int) max(Entity_ID),
	// 	cast(int) globals.gl_standard.UNIFORM_BUFFER_OFFSET_ALIGNMENT
	// )

	globals.game_view = 1
	globals.ui_view = 1

	game_entities := make([]^Entity, max(Entity_ID))
	globals.entities_3D = slice.into_dynamic(game_entities)

	ui_entities := make([]^Entity, max(Entity_ID))
	globals.entities_2D = slice.into_dynamic(ui_entities)

	entities := make([]^Entity, max(Entity_ID))
	globals.entities = slice.into_dynamic(entities)

	globals.ren = ren_make()

	ren_init(globals.ren)
	asset_init()
	game_init()
}

// Mixed-scope between renderer and game entities.
framework_step :: proc (dt: f64) {
	ren_clear()
	globals.dt = dt
	globals.uniforms.tau_time += f32(dt)
	overflow := linalg.TAU - globals.uniforms.tau_time
	if overflow >= 0 {
		globals.uniforms.tau_time = overflow
	}
	globals.uniforms.time += f32(dt)

	clear(&globals.entities)
	clear(&globals.entities_2D)
	clear(&globals.entities_3D)
	for &e in globals._entity_storage {
		if e.used {
			append(&globals.entities, &e)
		}
	}
////////////////////////////////////////////////////////////////////////////////
	game_step()
////////////////////////////////////////////////////////////////////////////////
	for &entity in globals.entities {
		entity_step(entity) or_continue

		if entity.is_3D {
			append(&globals.entities_3D, entity)
		} else {
			append(&globals.entities_2D, entity)
		}
	}
// IDEA: Could use the same sort for UI and interpret it as Z index.
  slice.sort_by(globals.entities_3D[:], proc (i,j: ^Entity) -> bool {
    return i.distance_from_camera > j.distance_from_camera
  })
	ren_draw(globals.ren)
}

////////////////////////////////////////////////////////////////////////////////
// Entity 
////////////////////////////////////////////////////////////////////////////////

init_entity_memory :: proc (entity: ^Entity_Memory, id: Entity_ID) {
	entity^ = {} // zero
	entity.id = id
	entity.used = true
	entity.scale = 1
	entity.instance = &globals.instance_staging[entity.id]
	entity.time_scale = 1
}

make_entity :: proc {
	make_entity_basic,
	make_entity_variant
}

make_entity_basic :: proc () -> ^Entity {
	return make_entity_variant(Entity)
}

make_entity_variant :: proc ($T: typeid) -> ^T where type_uses(T, Entity) {
	for &mem, i in globals._entity_storage {
		if !mem.used {
			init_entity_memory(&mem, cast(Entity_ID) i)
			switch typeid_of(T) {
			case Entity:
				mem.type = Entity_Type.None
			case Text_Entity:
				mem.variant = {}
				mem.type = Entity_Type.Text
			case Image_Entity:
				mem.variant = {}
				mem.type = Entity_Type.Image
			case Sprite_Entity:
				mem.variant = {}
				mem.type = Entity_Type.Sprite
			case:
				panic("Unimplemented Entity Variant")
			}
			entity := transmute(^T) &mem
			append(&globals.entities, entity)
			return entity
		}
	}
	panic("Out of entities.")
}

free_entity :: proc (entity: ^$T) where type_uses(T, Entity) {
	entity.used = false
	index, found := slice.linear_search(globals.entities[:], entity)
	assert(found)
	unordered_remove(&globals.entities, index)
}

// Prepare an object for rendering.
// The entity gets some time to do whatever.
// Data which is derivable from Entity variant data is computed here.
entity_step :: #force_inline proc (entity: ^Entity) -> (draw_it: bool) {
	if !entity.used {
		assert(false) // freed objects shouldn't make it here.
	}

	if entity.hidden {
		return false
	}

	switch entity.type {
	case .None:
	case .Text: step_text(transmute(^Text_Entity)entity, immediate=false)
	case .Sprite: step_sprite(transmute(^Sprite_Entity)entity, immediate=false)
	case .Image: step_image(transmute(^Image_Entity)entity, immediate=false)
	}

	instance: ^Any_Instance = entity.instance
	instance.model_transform =
		linalg.matrix4_translate(entity.position)\
		* linalg.matrix4_from_euler_angles_xyz(expand_values(entity.rotation))\
		* linalg.matrix4_scale(entity.scale)
	if entity.is_3D {
// TODO: Bucket Opaque from Transparent
// ASSUME: Centroid is 0,0,0 in model coordinates
		centroid: Vec4 : { 0, 0, 0, 1 }
    entity_centroid_in_world := instance.model_transform * centroid
		entity.distance_from_camera = glsl.distance(entity_centroid_in_world.xyz, globals.camera.position)
	}

	return true
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

