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
	log.info("---------------------------------------- framework initialized.")
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

init_entity_memory :: proc (entity: ^Entity, id: Entity_ID) {
	entity^ = {} // zero all fields
	entity.id = id
	entity.used = true
	entity.scale = 1
	entity.instance = &globals.instance_staging[entity.id]
	entity.time_scale = 1
}

make_entity :: proc () -> ^Entity {
	for &mem, i in globals._entity_storage {
		if !mem.used {
			init_entity_memory(&mem, cast(Entity_ID) i)
			entity := &mem
			append(&globals.entities, &mem)
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

	switch &variant in entity.variant {
	case nil: // general-purpose entity
	case Text_State:   step_text(entity, immediate=false)
	case Image_State:  step_image(entity, immediate=false)
	case Sprite_State: step_sprite(entity, immediate=false)
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

