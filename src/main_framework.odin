package main

// Purpose: This file provides resources to various subsystems.
// 						e.g. Rendering, Entities, Physics, Audio
//          It also integrates these resources such that the game
//          can make use of them with a smaller API.

import "core:log"
import "core:slice"
import "core:hash/xxhash"
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
	globals.entities_3D = alias_slice_as_empty_dynamic(game_entities)

	ui_entities := make([]^Entity, max(Entity_ID))
	globals.entities_2D = alias_slice_as_empty_dynamic(ui_entities)

	entities := make([]^Entity, max(Entity_ID))
	globals.entities = alias_slice_as_empty_dynamic(entities)

	collisions := make([]Collision, MAX_COLLISIONS_PER_FRAME)
	globals.collisions = alias_slice_as_empty_dynamic(collisions)

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
		if .Allocated in e.flags {
			append(&globals.entities, &e)
			if .Immediate_In_Use in e.flags {
				// assume it is not used.
				// after the game_step, if it is still not used, free it.
				e.flags -= { .Immediate_In_Use }
			}
		}
	}
////////////////////////////////////////////////////////////////////////////////
	game_step()
////////////////////////////////////////////////////////////////////////////////

	clear(&globals.collisions)
	#reverse for &entity in globals.entities {
		if .Immediate_Mode in entity.flags \
		&& .Immediate_In_Use not_in entity.flags {
			delete_key(&globals.immediate_entities, entity.immediate_hash)
			free_entity(entity) // mutates this array, hence the #reverse.
			continue
		}

////////////////////////////////////////////////////////////////////////////////
		entity_step(entity) or_continue
////////////////////////////////////////////////////////////////////////////////

		if .Is_3D in entity.flags {
			append(&globals.entities_3D, entity)
		} else {
			append(&globals.entities_2D, entity)
		}

		if .Collider_Enabled not_in entity.flags { continue }
		assert(entity.collider.shape != nil)
		collider_loop: for &other in globals.entities {
			for pair in globals.collisions {
				if pair.ids[0] == entity.id && pair.ids[1] == other.id \
				|| pair.ids[1] == entity.id && pair.ids[0] == other.id {
					continue
				}
			}
			if entity_contains_entity(entity, other) {
				append(&globals.collisions, Collision {{entity.id, other.id}})
			}
		} // collider_loop
	} // reverse entity loop

////////////////////////////////////////////////////////////////////////////////
// THIS SORT DEFINES THE DEPTH BUFFER.
////////////////////////////////////////////////////////////////////////////////
  slice.sort_by(globals.entities_3D[:], proc (i,j: ^Entity) -> bool {
    return i.distance_from_camera > j.distance_from_camera
  })
  slice.sort_by(globals.entities_2D[:], proc (i,j: ^Entity) -> bool {
    return i.distance_from_camera > j.distance_from_camera
  })
	ren_draw(globals.ren)
}

hit_test_aabb_aabb :: proc (box1, box2: ^Entity) -> bool {
	TR1 := box1.position + box1.collider.half_size
	BL1 := box1.position - box1.collider.half_size
	TR2 := box2.position + box2.collider.half_size
	BL2 := box2.position - box2.collider.half_size
	return \
	   (TR2.x <= TR1.x && BL1.x <= TR2.x  \
	&&  TR2.y <= TR1.y && BL1.y <= TR2.y  \
	&&  TR2.z <= TR1.z && BL1.z <= TR2.z) \
	|| (BL2.x <= TR1.x && BL1.x <= BL2.x  \
	&&  BL2.y <= TR1.y && BL1.y <= BL2.y  \
	&&  BL2.z <= TR1.z && BL1.z <= BL2.z)
}
hit_test_point_point   :: proc (p1, p2: ^Entity) -> bool {
	return is_nearly(p1.position, p2.position)
}
hit_test_aabb_circle   :: proc (box, circle: ^Entity) -> bool {
	// There's an equivalence for the case of AABBs.
	return hit_test_aabb_aabb(box, circle)
}
hit_test_aabb_point    :: proc (box,p: ^Entity) -> bool {
	TR := box.position + box.collider.half_size
	BL := box.position - box.collider.half_size
	point := p.position
	return \
	   point.x <= TR.x && BL.x <= point.x\
	&& point.y <= TR.y && BL.y <= point.y\
	&& point.z <= TR.z && BL.z <= point.z
}
hit_test_circle_circle :: proc (circle1, circle2: ^Entity) -> bool {
	dist := distance(circle1.position, circle2.position)
	return dist <= (circle1.collider.half_size.x + circle2.collider.half_size.x)
}
hit_test_circle_point  :: proc (circle, point: ^Entity) -> bool {
	dist := distance(circle.position, point.position)
	return dist <= circle.collider.half_size.x
}
hit_test_rect_rect     :: proc (r1,r2: ^Entity) -> bool { panic("TODO") }
hit_test_rect_aabb     :: proc (r,bb: ^Entity) -> bool { panic("TODO") }
hit_test_rect_circle   :: proc (r,c: ^Entity) -> bool { panic("TODO") }
hit_test_rect_point    :: proc (r,p: ^Entity) -> bool { panic("TODO") }

entity_contains_entity :: proc (entity, other: ^Entity) -> bool {
	if .Collider_Enabled not_in other.flags \
	|| .Collider_Enabled not_in entity.flags \
	|| entity == other {
		return false
	}

	assert(other.collider.shape != nil)
	collision_detected: bool
	switch entity.collider.shape {
	case .None:
	case .Point://///////////////// entity is point
		switch other.collider.shape {
		case .Point:
			collision_detected = hit_test_point_point(entity, other)
		case .AABB:
			collision_detected = hit_test_aabb_point(other, entity)
		// case .Rect:   // P:Rect
		case .Circle:
			collision_detected = hit_test_circle_point(other, entity)
		case .None:
		}
	case .AABB://////////////////// entity is AABB
		switch other.collider.shape {
		case .Point:
			collision_detected = hit_test_aabb_point(entity, other)
		case .AABB: 
			collision_detected = hit_test_aabb_aabb(entity, other) 
		// case .Rect:   // AABB:Rect
		case .Circle:
			collision_detected = hit_test_aabb_circle(entity, other)
		case .None:
		}
	// case .Rect:////////////////////
	// 	switch other.collider.shape {
	// 	case .Point:  // Rect:P
	// 	case .AABB:   // Rect:AABB
	// 	// case .Rect:   // Rect:Rect
	// 	case .Circle: // Rect:Circle
	// 	case .None: continue
	// 	}
	case .Circle:////////////////// entity is Circle
		switch other.collider.shape {
		case .Point:
			collision_detected = hit_test_circle_point(entity, other)
		case .AABB:
			collision_detected = hit_test_aabb_circle(other, entity)
		// case .Rect:   // Circle: Rect
		case .Circle:
			collision_detected = hit_test_circle_circle(entity, other)
		case .None:
		}
	}
	return collision_detected
}

////////////////////////////////////////////////////////////////////////////////
// Entity 
////////////////////////////////////////////////////////////////////////////////

init_entity_memory :: proc (entity: ^Entity, id: Entity_ID) {
	entity^ = {} // zero all fields
	entity.id = id
	entity.flags = { .Allocated }
	entity.scale = 1
	entity.basis.scale = 1
	entity.instance = &globals.instance_staging[entity.id]
	entity.color.rgb = 0.9
	entity.time_scale = 1
	entity.collider = {}
	entity.collider.layer = { .Default }
	entity.collider.mask  = { .Default }
}

// YOU ARE FIRED IF YOU COPY THIS POINTER. IT IS TO BE A LOCAL IN A step :: proc
do_entity :: proc (loc := #caller_location) -> (entity: ^Entity, is_new: bool) {
	hash := entity_hash(loc)
	value, found := globals.immediate_entities[hash]
	if !found {
		value = make_entity()
		value.flags += { .Immediate_Mode, .Immediate_In_Use }
		value.immediate_hash = hash
		globals.immediate_entities[hash] = value
		return value, true
	}
	value.flags += { .Immediate_In_Use }
	return value, false
}

entity_hash :: proc (declaration: runtime.Source_Code_Location) -> u64 {
	loc := declaration
	hash_input := make([dynamic]u8, 0, len(loc.file_path) + 2*size_of(i32), context.temp_allocator)
	append(&hash_input, loc.file_path)
	append(&hash_input, ..(cast(^[4]u8)&loc.line)^[:])
	append(&hash_input, ..(cast(^[4]u8)&loc.column)^[:])
	hash := xxhash.XXH3_64(hash_input[:])
	delete(hash_input)
	return hash
}

make_entity :: proc () -> ^Entity {
	for &mem, i in globals._entity_storage {
		if .Allocated not_in mem.flags {
			init_entity_memory(&mem, cast(Entity_ID) i)
			entity := &mem
			append(&globals.entities, &mem)
			return entity
		}
	}
	panic("Out of entities.")
}

free_entity :: proc (entity: ^Entity) {
	entity.flags = { } // mark as free (not .Allocated)
	index, found := slice.linear_search(globals.entities[:], entity)
	assert(found)
	unordered_remove(&globals.entities, index)
}

// Prepare an object for rendering.
// The entity gets some time to do whatever.
// Data which is derivable from Entity variant data is computed here.
entity_step :: #force_inline proc (entity: ^Entity) -> (draw_it: bool) {
	entity.ui = {}

	if .Allocated not_in entity.flags {
		assert(false) // freed objects shouldn't make it here.
	}
	animate_physics :: proc (entity: ^Entity) {
		entity.position += entity.velocity
		entity.rotation += entity.angular_velocity
		entity.velocity += entity.acceleration
		entity.angular_velocity += entity.acceleration
	}
	animate_physics(entity)

	if .Hidden not_in entity.flags {
		switch &variant in entity.variant {
		case nil: // general-purpose entity
		case Text_State:   //step_text(entity, immediate=false)
		case Image_State:  step_image(entity, immediate=false)
		case Sprite_State: step_sprite(entity, immediate=false)
		case UI_Element:   // find root and position children.
		}
	}

	instance: ^Any_Instance = entity.instance
	instance.model_transform =
		linalg.matrix4_translate(entity.position + entity.basis.position)\
		* linalg.matrix4_from_euler_angles_xyz(expand_values(entity.rotation + entity.basis.rotation))\
		* linalg.matrix4_scale(entity.scale * entity.basis.scale)
	if .Is_3D in entity.flags {
// TODO: Bucket Opaque from Transparent
// ASSUME: Centroid is 0,0,0 in model coordinates
		centroid: Vec4 : { 0, 0, 0, 1 }
    entity_centroid_in_world := instance.model_transform * centroid
		entity.distance_from_camera = glsl.distance(entity_centroid_in_world.xyz, globals.camera.position)
	} else {
		// 2D sort will deviate especially with things like Y-sort
		centroid: Vec4 : { 0, 0, 0, 1 }
    entity_centroid_in_world := instance.model_transform * centroid
		entity.distance_from_camera = glsl.distance(entity_centroid_in_world.xyz, globals.camera.position)
	}

	return true
}
