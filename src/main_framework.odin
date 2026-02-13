package main

// Purpose: Provide small, simple, APIs to the game. Define `Entity`.

import "base:runtime"
import "core:log"
import "core:slice"
import "core:strings"
import "core:dynlib"
import "core:mem"
import "core:fmt"
import "core:reflect"
import "core:time"
import gl "angle"
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
	if size_of(Uniforms) >= 1<<14 {
		log.warn("2^16 is fine; but this is getting large and might not support all modern GPUs.")
	}
	globals.hot_reloaded_this_frame = true // INTENT: load live shaders
	globals.hot_reload = hot_reload
	globals.game_step = game_step
	globals.tick = 1./120.
	globals.canvas_scale = 1
	globals.canvas_scaling = .None
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
	debug_colliders.position.z = NEAR_Z - 10.0
	debug_colliders.debug_name = "Collider Visualization"
	debug_colliders.flags += {.Hidden}
	debug_colliders.draw_command = ren_make_basic_draw_cmd(
		globals.instance_buffer,
		cast(int) debug_colliders.id, {},{})
	debug_colliders.color = vec4(0.33, 0.45, 0.9, 0.55)
	globals.collider_visualization = debug_colliders
	gl.BindSampler(cast(u32) Texture_Unit.Framebuffer_Texture, globals.ren.linear_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Texture,             globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Font,                globals.ren.linear_sampler)
	game_init()
	assert(globals.canvas_size_px != 0)
	set_canvas_size(array_cast(globals.canvas_size_px, int))
}

framework_step :: proc (dt: f32) {
	globals.uptime += globals.tick
	globals.ui_mouse_position = (globals.sugar.mouse_position / globals.canvas_stretch) 
	globals.mouse_position = (globals.sugar.mouse_position / globals.canvas_stretch)  // TODO camera offset
	globals.dt = dt
	globals.uniforms.time += f32(globals.dt)
	globals.uniforms.tau_time += f32(globals.dt)
	overflow := linalg.TAU - globals.uniforms.tau_time
	if overflow >= 0 {
		globals.uniforms.tau_time = overflow
	}

	clear(&globals.entities)
	clear(&globals.entities_2D)
	clear(&globals.entities_3D)
	for &e in globals._entity_storage {
		if .Allocated in e.flags {
			append(&globals.entities, &e)
			// Prior to entity motion, consider this the "old state"
			e.old_transform = e.transform
			e.old_basis = e.basis
			if .Immediate_In_Use in e.flags {
				// assume it is not used
				// after the game_step, if it is still not used, free it.
				e.flags -= { .Immediate_In_Use }
			}
		}
	}
// Hot reloading ///////////////////////////////////////////////////////////////
// - Only reloads the game_step: proc.
// - You need a rebuild if Source Files are newer than DLL, with the exception
//   that if engine is newer than the DLL, Then just use the static exe proc.
when !sugar.platform_calls_step { // When !web
	engine_stat, engine_err := sugar.stat("../engine.exe", context.temp_allocator)
	ensure(engine_err == nil)
	source_stat, source_err := sugar.stat("./main_game.odin", context.temp_allocator)
	ensure(source_err == nil)
	dll_stat, dll_err := sugar.stat("../game.dll", context.temp_allocator)
	ensure(dll_err == nil || dll_err == .Not_Exist)
	no_dll := dll_err == .Not_Exist
	code_newer_than_dll := dll_stat.modification_time._nsec < source_stat.modification_time._nsec
	code_newer_than_engine := engine_stat.modification_time._nsec < source_stat.modification_time._nsec
	if (no_dll || code_newer_than_dll) && code_newer_than_engine {
		if d,err := sugar.get_working_directory(context.temp_allocator); err == nil {
			log.infof("Running from %s", d)
		}
		// 1. emit a new DLL, if that works, swap it out.
		state, stdout, stderr, compile_err := sugar.process_exec({
			working_dir="..", // intended to be  .. from src
			command={"reload.bat", ".", "new_game"},
		}, context.temp_allocator)
		if compile_err != nil {
			log.infof("[RELOADER::STDerr] %s", stderr)
			log.panicf("[RELOADER] compilation failed. %v", compile_err)
		} else {
			log.infof("[RELOADER::STDerr] %s", stderr)
			log.infof("[RELOADER::STDOUT] %s", stdout)
		}

		if state.exit_code == 0 { // new_game.dll emitted.
			if globals.game_dll != nil {
				dynlib.unload_library(globals.game_dll)
				globals.game_dll = nil
			}
			mv_err := sugar.rename("../new_game.dll", "../game.dll")
			if mv_err != nil do log.panicf("%v", mv_err)
		  lib, lib_ok := dynlib.load_library(`./game.dll`)
		  ensure(lib_ok)
		  new_game_step, gs_ok := dynlib.symbol_address(lib, "game_step")
		  ensure(gs_ok)
		  new_hot_reload, hr_ok := dynlib.symbol_address(lib, "hot_reload")
		  ensure(hr_ok)
			globals.game_dll = lib
			globals.game_step = auto_cast new_game_step
			globals.hot_reload = auto_cast new_hot_reload
			globals.hot_reload(globals, gs)
			log.infof("Hot reloaded the game.")
		} else {
			log.errorf("Failed to compile new DLL.")
		}
	} else {
		// log.infof("DLL:%v, Code:%v", dll_stat.modification_time, source_stat.modification_time)
	}
}
	globals.game_step()
	globals.hot_reloaded_this_frame = false
	fbrect := framebuffer_quad(from = globals.ren.canvas.fbo, to = 0)
	fbrect.debug_name = "Framebuffer Rect"
	fbrect.scale.xy = array_cast(globals.framebuffer_size_px, f32)
	fbrect.basis.scale.y = -1 // because textures are flipped...
	fbrect.basis.position.xy = fbrect.scale.xy/2
	fbrect.flags += {.Is_UI, .Skip_Interpolation}
	fbrect.debug_name = "Canvas Rect"
////////////////////////////////////////////////////////////////////////////////
	reset_z_cursor()
	build_camera()
	physics_begin_frame()
	#reverse for &entity in globals.entities {
		if .Immediate_Mode in entity.flags \
		&& .Immediate_In_Use not_in entity.flags {
			delete_key(&globals.immediate_entities, entity.hash)
			free_entity(entity) // mutates this array, hence the #reverse.
		}

////////////////////////////////////////////////////////////////////////////////
		entity.ui = {}

		if .Allocated not_in entity.flags {
			continue
		}
		if entity.create_tick == globals.tick_counter {
			entity.old_basis = entity.basis
			entity.old_transform = entity.transform
		}
		if .Immediate_Mode not_in entity.flags {
			switch &variant in entity.variant {
			case nil: // general-purpose entity
			case Text_State:
			case Image_State:
			case Sprite_State: step_sprite(entity)
			case Timed_Effect_State(Empty_Struct): step_timed_effect(entity)
			}
		}
		if .Allocated not_in entity.flags {
			continue // in case a _step function changed something.
		}

////////////////////////////////////////////////////////////////////////////////
		if .Is_3D in entity.flags {
			append(&globals.entities_3D, entity)
			if .Collider_Enabled in entity.flags {
				// TODO 3D Collider Viz
			}
		} else {
			append(&globals.entities_2D, entity)
		}
		physics_integrate_tick(entity)
		physics_collide(entity)
	} // reverse entity loop
	physics_end_frame()
}

physics_begin_frame :: proc () {
	clear(&globals.exit_collisions)
	clear(&globals.enter_collisions)
	clear(&globals.old_collisions)
	append(&globals.old_collisions, ..globals.collisions[:])
	clear(&globals.collisions)
}
physics_end_frame :: proc () {
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
}

do_physics_integrate_tick :: proc (entity: ^Entity) {
	entity.velocity += f32(globals.tick) * entity.acceleration
	entity.position += f32(globals.tick) * entity.velocity
	entity.angular_velocity += entity.angular_acceleration
	entity.rotation += entity.angular_velocity
}
physics_integrate_tick :: proc (entity: ^Entity) {
	if .Physics_Skip_Integrate in entity.flags do return
	do_physics_integrate_tick(entity)
}
physics_collide :: proc (entity: ^Entity) {
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
}

framework_draw :: proc (alpha: f32) {
	// This is the soonest scope we can lerp the transforms and determine draw-order.
	for entity in globals.entities {
		instance: ^Any_Instance = entity.instance
		xform: Transform
		basis: Transform
		if .Skip_Interpolation in entity.flags\
		|| .Skip_Next_Interpolation in entity.flags {
			xform = entity.transform
			basis = entity.basis
		} else {
			xform = lerp_transform(entity.old_transform, entity.transform, alpha)
			basis = lerp_transform(entity.old_basis,     entity.basis,     alpha)
		}
		if .Is_3D not_in entity.flags {
			if invalid_entity_depth(entity) {
				raise_warning_bad_depth(entity)
			}
		}
		instance.model_transform =
			linalg.matrix4_translate(xform.position + basis.position)\
			* linalg.matrix4_from_euler_angles_xyz(expand_values(xform.rotation + basis.rotation))\
			* linalg.matrix4_scale(xform.scale * basis.scale)
		if .Is_3D in entity.flags {
	// TODO: Bucket Opaque from Transparent
	// ASSUME: Centroid is 0,0,0 in model coordinates
			centroid: Vec4 : { 0, 0, 0, 1 }
	    entity_centroid_in_world := instance.model_transform * centroid
			entity.distance_from_camera = distance(entity_centroid_in_world.xyz, globals.camera.position)
		} else {
			// 2D sort will deviate especially with things like Y-sort
			centroid: Vec4 : { 0, 0, 0, 1 }
	    entity_centroid_in_world := instance.model_transform * centroid
			entity.distance_from_camera = distance(entity_centroid_in_world.xyz, globals.camera.position)
		}
	}
////////////////////////////////////////////////////////////////////////////////
// THIS SORT DEFINES THE DEPTH BUFFER.       (TODO: It's also an unstable sort.)
////////////////////////////////////////////////////////////////////////////////
  slice.sort_by(globals.entities_3D[:], proc (i,j: ^Entity) -> bool {
    return i.distance_from_camera > j.distance_from_camera
  })
  slice.sort_by(globals.entities_2D[:], proc (i,j: ^Entity) -> bool {
    return i.position.z < j.position.z
  })

	ren_clear()
	ren_draw(globals.ren)
	sugar.swap_buffers()
	gl.glFinish()
}

// "next" in the sense that it will be in front of the prior draw's Z.
next_z :: proc () -> f32 {
	z := globals.z_cursor
	globals.z_cursor += 1.0 // after orthographic projection, adding is even LESS deep.
	assert(globals.z_cursor <= NEAR_Z && globals.z_cursor >= FAR_Z)
	return z
}

reset_z_cursor :: proc () {
	globals.z_cursor = FAR_Z + 10.0 // starts far.
	assert(globals.z_cursor <= NEAR_Z && globals.z_cursor >= FAR_Z)
}

////////////////////////////////////////////////////////////////////////////////
// Collision Detection
////////////////////////////////////////////////////////////////////////////////

// Half size. Entity.scale controls both collider and mesh. returns a half-size.
collider_size :: proc (entity: ^Entity) -> Vec3 {
	return entity.scale * entity.collider.size/2
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

point_in_aabb :: proc (point: Vec3, aabb: ^Entity) -> bool {
	half_size := collider_size(aabb)
	TR := aabb.position + half_size
	BL := aabb.position - half_size
	return BL.x <= point.x && point.x <= TR.x \
	    && BL.y <= point.y && point.y <= TR.y 
}

hit_test_aabb_aabb :: proc (box1, box2: ^Entity) -> bool {
	box1_half_size := collider_size(box1)
	TR := box1.position + collider_size(box1)
	if point_in_aabb(TR, box2) do return true
	BL := box1.position - collider_size(box1)
	if point_in_aabb(BL, box2) do return true
	TL := TR; TL.x = BL.x
	if point_in_aabb(TL, box2) do return true
	BR := BL; BR.x = TR.x
	return point_in_aabb(BR, box2)
}
hit_test_point_point   :: proc (p1, p2: ^Entity) -> bool {
	return is_nearly(p1.position, p2.position)
}
hit_test_aabb_circle   :: proc (box, circle: ^Entity) -> bool {
	// This isn't right, but it's OK for now.
	return hit_test_aabb_aabb(circle, box) // for some reason can't swap args.
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

init_entity :: proc (entity: ^Entity, id: Entity_ID) {
	entity^ = {} // zero all fields
	entity.id = id
	entity.flags = { .Allocated, .Skip_Next_Interpolation }
	entity.old_transform.scale = 1
	entity.transform.scale = 1
	entity.old_basis.scale = 1
	entity.basis.scale = 1
	entity.instance = &globals.instance_staging[entity.id]
	entity.color = 1
	entity.time_scale = 1
	entity.collider = {}
	entity.collider.layer = { .Default }
	entity.collider.mask  = { .Default }
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
			init_entity(&mem, cast(Entity_ID) i)
			entity := &mem
			entity.create_tick = globals.tick_counter
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

////////////////////////////////////////////////////////////////////////////////
// Entity Hashing Implementation
////////////////////////////////////////////////////////////////////////////////
Located_Hash_Input :: union {
	runtime.Source_Code_Location,
	Located(Tagged_Index),
	Located(u64),
}

Located :: struct($T: typeid) {
	value: T,
	location: runtime.Source_Code_Location
}

Tagged_Index :: struct {
	tag: string,
	index: int,
}

locate_hash_input_source :: proc (
	input: Located_Hash_Input
) -> (location: runtime.Source_Code_Location) {
	switch it in input {
	case runtime.Source_Code_Location: 
		location = it
	case Located(Tagged_Index):
		location = it.location
	case Located(u64):
		location = it.location
	}
	return
}

compute_entity_hash :: proc (input: Located_Hash_Input) -> (hash: u64) {
	switch it in input {
	case runtime.Source_Code_Location:
		hash = code_location_hash(it)
	case Located(Tagged_Index): 
		hash = compute_string_index_hash(it.value.tag, it.value.index)
	case Located(u64):
		hash = it.value
	}
	return hash
}

set_debug_name_from_hash_inputs :: proc (
	entity: ^Entity,
	hash_input: Located_Hash_Input,
) {
	switch it in hash_input {
	case runtime.Source_Code_Location:
		entity.debug_name = fmt.bprintf(
			globals._debug_name_storage[entity.id][:],
			"Entity(from_proc=%s, line=%d, file=%s)",
			string_start(it.procedure, 40),
			it.line,
			string_end(it.file_path, 40),
		);
	case Located(Tagged_Index):
		entity.debug_name = fmt.bprintf(
			globals._debug_name_storage[entity.id][:],
			`Entity(tag="%s", index=%d)`,
			it.value.tag,
			it.value.index,
		);
	case Located(u64):
		entity.debug_name = fmt.bprintf(
			globals._debug_name_storage[entity.id][:],
			"Entity(hash=%d)",
			it.value,
		);
		assert(entity.hash == it.value)
	}
}

// Forms a hash from the #caller_location and an index.
// Use this to keep hashes unique in a loop.
compute_index_hash :: proc (index: int, loc := #caller_location) -> u64 {
	index:  i32 = cast(i32) index
	line:   i32 = loc.line
	column: i32 = loc.column
	file_path := string_end(loc.file_path, 240 - 3*size_of(i32))

	@static backing: [240]u8
	builder := strings.builder_from_bytes(backing[:])
	strings.write_bytes(&builder, pointee_bytes(&line))
	strings.write_bytes(&builder, pointee_bytes(&column))
	strings.write_bytes(&builder, pointee_bytes(&index))
	strings.write_string(&builder, file_path)
	return hash240(builder.buf[:])
}

// Forms a hash from a string and int.
// Use this to keep "sub-entities" unique when the parent is built in a loop.
compute_string_index_hash :: proc (str: string, index: int) -> u64 {
	index: i32 = cast(i32) index
	str := string_end(str, 240 - 1*size_of(i32))

	@static backing: [240]u8
	builder := strings.builder_from_bytes(backing[:])
	strings.write_bytes(&builder, pointee_bytes(&index))
	strings.write_string(&builder, str)
	return hash240(builder.buf[:])
}

// Forms a hash from a varying number of value-types.
// Use this to prototype when provided hash-builders are insufficient.
//
// WARNING: Strings, slices, pointers won't hash their actual data.
// NOTE: Arrays are value-types.
compute_any_values_hash :: proc (args: ..any) -> u64 {
	@static buf: [240]u8
	offset: int = 0
	for arg in args {
		bytes: []u8 = reflect.as_bytes(arg)
		size := len(bytes)
		copy(buf[offset:size], bytes)
		offset += size
	}
	return hash240(buf[:])
}