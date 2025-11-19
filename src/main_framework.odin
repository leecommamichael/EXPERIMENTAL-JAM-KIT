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
import "sugar"

framework_init :: proc () {
	init_gl_constants :: proc () {
		when ODIN_OS != .JS {
			assert(gl.glGetIntegerv != nil, "GL not loaded.")
		  assert(gl.glGetInteger64v != nil)
		}
		globals.gl_standard.UNIFORM_BUFFER_OFFSET_ALIGNMENT = gl.GetIntegerv(.UNIFORM_BUFFER_OFFSET_ALIGNMENT)
		globals.gl_standard.MAX_UNIFORM_BLOCK_SIZE          = gl.GetInteger64v(.MAX_UNIFORM_BLOCK_SIZE)
		globals.gl_standard.MAX_TEXTURE_SIZE                = gl.GetInteger64v(.MAX_TEXTURE_SIZE)
		log.infof("OpenGL Platform Constants ---\n%#v", globals.gl_standard)
	}
	init_gl_constants()

	globals.canvas_scale = 1
	globals.canvas_scaling = .Fixed
	globals.canvas_stretch = 1
	globals.canvas_stretching = .Integer_Aspect
	globals.camera.zoom = 1.0

	globals.perspective_view = 1
	globals.orthographic_view = 1
	globals.ui_view = 1

	reset_z_cursor()

	game_entities := make([]^Entity, max(Entity_ID))
	globals.entities_3D = alias_slice_as_empty_dynamic(game_entities)

	ui_entities := make([]^Entity, max(Entity_ID))
	globals.entities_2D = alias_slice_as_empty_dynamic(ui_entities)

	entities := make([]^Entity, max(Entity_ID))
	globals.entities = alias_slice_as_empty_dynamic(entities)

	old_collisions := make([]Collision, MAX_COLLISIONS_PER_FRAME)
	globals.old_collisions = alias_slice_as_empty_dynamic(old_collisions)

	collisions := make([]Collision, MAX_COLLISIONS_PER_FRAME)
	globals.collisions = alias_slice_as_empty_dynamic(collisions)

	enters := make([]Collision, MAX_COLLISIONS_PER_FRAME)
	globals.enter_collisions = alias_slice_as_empty_dynamic(enters)

	exits := make([]Collision, MAX_COLLISIONS_PER_FRAME)
	globals.exit_collisions = alias_slice_as_empty_dynamic(exits)

	globals.ren = ren_make()
	ren_init(globals.ren)
	log.info("---------------------------------------- framework initialized.")
	debug_colliders := make_entity()
	debug_colliders.position.z = 1
	debug_colliders.flags += {.Is_3D}
	debug_colliders.draw_command = ren_make_basic_draw_cmd(
		globals.instance_buffer,
		cast(int) debug_colliders.id, {},{})
	debug_colliders.color = vec4(0.33, 0.45, 0.9, 0.5)
	globals.collider_visualization = debug_colliders
	game_init()
	assert(globals.canvas_size_px != 0)
	set_canvas_size(array_cast(globals.canvas_size_px, int))
}

// Mixed-scope between renderer and game entities.
framework_step :: proc (dt: f64) {
	ren_clear()
	
	// position of mouse in design coordinates world.
	globals.ui_mouse_position = (sugar.mouse_position / globals.canvas_stretch) 
	// position of mouse in world coordinates. (same thing if no offset.)
	globals.mouse_position = (sugar.mouse_position / globals.canvas_stretch) 
	// globals.mouse_position += globals.camera.offset.xy
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
				// assume it is not used
				// after the game_step, if it is still not used, free it.
				e.flags -= { .Immediate_In_Use }
			}
		}
	}
////////////////////////////////////////////////////////////////////////////////
	game_step()

	rect := framebuffer_quad(from = globals.ren.canvas.fbo, to = 0)
	rect.scale.xy = array_cast(globals.framebuffer_size_px, f32)
	rect.basis.scale.y = -1 // because textures are flipped...
	rect.basis.position.xy = rect.scale.xy/2
	rect.flags += {.Is_UI}
////////////////////////////////////////////////////////////////////////////////
	reset_z_cursor()
	build_camera()

	clear(&globals.exit_collisions)
	clear(&globals.enter_collisions)
	clear(&globals.old_collisions)
	append(&globals.old_collisions, ..globals.collisions[:])
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
			if .Collider_Enabled in entity.flags {
				// TODO 3D Collider Viz
			}
		} else {
			append(&globals.entities_2D, entity)
		}

		if .Collider_Enabled in entity.flags {
			assert(entity.collider.shape != nil)
			collider_loop: for &other in globals.entities {
				for pair in globals.collisions {
					if pair.ids[0] == entity.id && pair.ids[1] == other.id \
					|| pair.ids[1] == entity.id && pair.ids[0] == other.id {
						continue collider_loop // INTENT: Already in list. Don't duplicate.
					}
				}

				if entity_contains_entity(entity, other) {
					old_collision: bool
					for oc in globals.old_collisions {
						if oc.ids[0] == entity.id && oc.ids[1] == other.id \
						|| oc.ids[1] == entity.id && oc.ids[0] == other.id {
							// this collision existed last frame. Dwelling overlap.
							old_collision = true
						}
					}
					new_collision := Collision {ids={entity.id, other.id}}
					if !old_collision {
						append(&globals.enter_collisions, new_collision)
						// The collision is new in this sample, so it's an "enter" event.
					}
					append(&globals.collisions, new_collision)
				}
			} // collider_loop
		} // if has collider
	} // reverse entity loop

	// Now all collisions are gathered, and we can compare them with old_collisions.
	for oc in globals.old_collisions {
		still_colliding: bool
		for cc in globals.collisions {
			if oc.ids[0] == cc.ids[0] && oc.ids[1] == cc.ids[1] \
			|| oc.ids[0] == cc.ids[1] && oc.ids[1] == cc.ids[0] {
				still_colliding = true
			}
		}
		if !still_colliding {
			append(&globals.exit_collisions, oc)
			// An old collision is not present in this sample. It's an "exit" event.
		}
	} // for old_collisions

////////////////////////////////////////////////////////////////////////////////
// THIS SORT DEFINES THE DEPTH BUFFER.       (TODO: It's also an unstable sort.)
////////////////////////////////////////////////////////////////////////////////
  slice.sort_by(globals.entities_3D[:], proc (i,j: ^Entity) -> bool {
    return i.distance_from_camera > j.distance_from_camera
  })
  slice.sort_by(globals.entities_2D[:], proc (i,j: ^Entity) -> bool {
    return i.position.z > j.position.z
  })
	ren_draw(globals.ren)
	sugar.swap_buffers()
}

next_z :: proc () -> f32 {
	z := globals.z_cursor
	globals.z_cursor += 1
	return z
}

reset_z_cursor :: proc () {
	globals.z_cursor = MIN_Z + 1
}

////////////////////////////////////////////////////////////////////////////////
// Collision Detection
////////////////////////////////////////////////////////////////////////////////

they_touch :: proc (e1, e2: ^Entity) -> bool {
	return find_collision_involving_entities(globals.collisions[:], e1, e2)
}

they_started_touching :: proc (e1, e2: ^Entity) -> bool {
	return find_collision_involving_entities(globals.enter_collisions[:], e1, e2)
}

they_stopped_touching :: proc (e1, e2: ^Entity) -> bool {
	return find_collision_involving_entities(globals.exit_collisions[:], e1, e2)
}

entity_collisions :: proc (entity: ^Entity) -> []Collision {
	return find_collisions_involving_entity(globals.collisions[:], entity)
}

enter_events :: proc (entity: ^Entity) -> []Collision {
	return find_collisions_involving_entity(globals.enter_collisions[:], entity)
}

exit_events :: proc (entity: ^Entity) -> []Collision {
	return find_collisions_involving_entity(globals.exit_collisions[:], entity)
}

find_collision_involving_entities :: proc (array: []Collision, e1, e2: ^Entity) -> bool {
	for it in array {
		if it.ids[0] == e1.id && it.ids[1] == e2.id \
		|| it.ids[1] == e1.id && it.ids[0] == e2.id {
			return true
		}
	}
	return false
}

find_collisions_involving_entity :: proc (
	array: []Collision,
	entity: ^Entity,
	allocator := context.temp_allocator
) -> []Collision {
	result := make([dynamic]Collision, allocator)
	for it in array {
		it := it // copy
		if it.ids[0] == entity.id {
			it.other = entity_with_id(it.ids[1])
			append(&result, it)
		} else if it.ids[1] == entity.id {
			it.other = entity_with_id(it.ids[0])
			append(&result, it)
		}
	}
	return result[:]
}

hit_test_aabb_aabb :: proc (box1, box2: ^Entity) -> bool {
	TR1 := box1.position + collider_size(box1)
	BL1 := box1.position - collider_size(box1)
	TR2 := box2.position + collider_size(box2)
	BL2 := box2.position - collider_size(box2)
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
	TR := box.position + collider_size(box)
	BL := box.position - collider_size(box)
	point := p.position
	return \
	   point.x <= TR.x && BL.x <= point.x\
	&& point.y <= TR.y && BL.y <= point.y\
	&& point.z <= TR.z && BL.z <= point.z
}
hit_test_circle_circle :: proc (circle1, circle2: ^Entity) -> bool {
	dist := distance(circle1.position, circle2.position)
	return dist <= (collider_size(circle1).x + collider_size(circle2).x)
}
hit_test_circle_point  :: proc (circle, point: ^Entity) -> bool {
	dist := distance(circle.position, point.position)
	return dist <= collider_size(circle).x
}
hit_test_rect_rect     :: proc (r1,r2: ^Entity) -> bool { panic("TODO") }
hit_test_rect_aabb     :: proc (r,bb: ^Entity) -> bool { panic("TODO") }
hit_test_rect_circle   :: proc (r,c: ^Entity) -> bool { panic("TODO") }
hit_test_rect_point    :: proc (r,p: ^Entity) -> bool { panic("TODO") }
// vector needs position and direction.
hit_test_ray_aabb :: proc (s,v: Vec3, aabb: ^Entity) -> bool {
	s := s - aabb.position
	size := aabb.scale / 2
	if v.x > -size.x {
		// test against min_x
		t := (-size.x - s.x) / v.x
		p := s + t*v
		in_y := -size.y <= p.y && p.y <= size.y
		in_z := -size.z <= p.z && p.z <= size.z
		if in_y && in_z { return true }
	} else if v.x < -size.x {
		// test against max_x
		t := (size.x - s.x) / v.x
		p := s + t*v
		in_y := -size.y <= p.y && p.y <= size.y
		in_z := -size.z <= p.z && p.z <= size.z
		if in_y && in_z { return true }
	}


	if v.y > -size.y {
		// test against min_y
		t := (-size.y - s.y) / v.y
		p := s + t*v
		in_x := -size.x <= p.x && p.x <= size.x
		in_z := -size.z <= p.z && p.z <= size.z
		if in_x && in_z { return true }
	} else if v.y < -size.y {
		// test against max_y
		t := (size.y - s.y) / v.y
		p := s + t*v
		in_x := -size.x <= p.x && p.x <= size.x
		in_z := -size.z <= p.z && p.z <= size.z
		if in_x && in_z { return true }
	}

	if v.z > -size.z {
		// test against min_z
		t := (-size.z - s.z) / v.z
		p := s + t*v
		in_x := -size.x <= p.x && p.x <= size.x
		in_y := -size.y <= p.y && p.y <= size.y
		if in_x && in_y { return true }
	} else if v.z < -size.z {
		// test against max_z
		t := (size.z - s.z) / v.z
		p := s + t*v
		in_x := -size.x <= p.x && p.x <= size.x
		in_y := -size.y <= p.y && p.y <= size.y
		if in_x && in_y { return true }
	}
	
	return false
}

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

entity_with_id :: proc (id: Entity_ID) -> ^Entity {
	it := &globals._entity_storage[id]
	if .Allocated not_in it.flags {
		return nil // It was freed.
	}

	return it
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

// the basis size is the content size of the drawing.
// the scale controls both collider and visual.
collider_size :: proc (entity: ^Entity) -> Vec3 {
	return entity.scale * entity.collider.size
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

	switch &variant in entity.variant {
	case nil: // general-purpose entity
	case Text_State:   //step_text(entity, immediate=false)
	case Image_State:  step_image(entity, immediate=false)
	case Sprite_State: step_sprite(entity, immediate=false)
	case Timed_Effect_State(Empty_Struct): step_timed_effect(entity)
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

////////////////////////////////////////////////////////////////////////////////
// Timed_Effect
////////////////////////////////////////////////////////////////////////////////
// this is an entity variant, so putting T here could inflate entities.
// So some things are pointers that otherwise would not be.
Timed_Effect_State :: struct ($T: typeid) {
	data: ^T,
	step: proc(data: ^T, percent: f32),
	seconds_total: f64,
	seconds_left: f64,
	timeout: proc(^T),
	allocator: runtime.Allocator,
}

step_timed_effect :: proc (entity: ^Entity, dt: f64 = globals.dt) {
	it := &entity.variant.(Timed_Effect_State(Empty_Struct))

	it.seconds_left -= dt
	percent := clamp(1 - cast(f32) (it.seconds_left/it.seconds_total), 0, 1)
	it.step(it.data, percent)

	if it.seconds_left <= 0 {
		if it.timeout != nil {
			it.timeout(it.data)
		}
		free(it.data, it.allocator)
		free_entity(entity)
	}
}

timed_effect :: proc (
	data: $T,
	seconds_left: f64,
	step: proc(data: ^T, percent: f32),
	allocator := context.allocator
) -> ^Timed_Effect_State(T) {
	ent := make_entity()
	data_copy := new(T, allocator)
	data_copy^ = data
	effect := Timed_Effect_State(T) {
		data_copy,
		step,
		seconds_left,
		seconds_left,
		nil,
		allocator,
	}
	ent.variant = transmute(Timed_Effect_State(Empty_Struct))effect
	ent.flags += {.Hidden}
	return transmute(^Timed_Effect_State(T)) &ent.variant.(Timed_Effect_State(Empty_Struct))
}

Lerp :: struct {
	sink: ^f32,
	start: f32,
	target: f32,
}

Timed_Lerp :: Timed_Effect_State(Lerp)
timed_lerp :: proc (
	data: ^f32,
	target: f32,
	seconds_left: f64,
	allocator := context.allocator
) -> ^Timed_Lerp {
	ent := make_entity()
	managed_data := new(Lerp, allocator)
	managed_data^ = Lerp { sink=data, start=data^, target=target }
	effect := Timed_Effect_State(Lerp) {
		managed_data,
		proc (it: ^Lerp, percent: f32) {
			it.sink^ = cast(f32) lerp(it.start, it.target, percent)
		},
		seconds_left,
		seconds_left,
		nil,
		allocator,
	}
	ent.variant = transmute(Timed_Effect_State(Empty_Struct))effect
	ent.flags += {.Hidden}
	return transmute(^Timed_Effect_State(Lerp)) &ent.variant.(Timed_Effect_State(Empty_Struct))
}
