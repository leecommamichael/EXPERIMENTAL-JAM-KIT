package main

import "core:fmt"

////////////////////////////////////////////////////////////////////////////////
// Entity 
////////////////////////////////////////////////////////////////////////////////
// Think of this as "create_or_get_map_entry."
//
// Get an entity based on a hash. 
// - Creates and returns a new entity if the hash was unused.
// - `framework_step` frees the entity when its hash is not seen in one `game_step`
// - `hash_input` uniquely identifies the entity you 
// - `hash_input_creator_loc` is the location which will be implicated in an error
//                            if the provided hash_input builds a duplicate hash.
//
// NOTE: If the caller supplies a (non-default) hash_input, they must not manually
//       pass a hash_input_source.
//
// NOTE: Don't persist the ^Entity between frames unless you know when it frees.
get_entity :: proc (
	hash_input: Hash = #caller_location
) -> (entity: ^Entity, is_new: bool) {
	hash: u64 = compute_entity_hash(hash_input)

	exists: bool
	entity, exists = globals.immediate_entities[hash]
	if exists {
		if invalid_entity_hash(entity) {
			raise_error_hash_collision(entity, hash_input)
		}
	} else {
		entity = make_entity()
		set_debug_name_from_hash_inputs(entity, hash_input)

		entity.flags += { .Immediate_Mode, .Immediate_In_Use }
		entity.hash = hash
		globals.immediate_entities[hash] = entity
		return entity, true
	}
	entity.flags += { .Immediate_In_Use }
	return entity, false
}

////////////////////////////////////////////////////////////////////////////////
// Entity Hashing
////////////////////////////////////////////////////////////////////////////////
// Below are some convenient procs to build a unique hash for your entities.
Hash :: Located_Hash_Input

raw_hash :: proc (
	hash_input: u64,
	loc := #caller_location,
) -> Located(u64) {
	return {
		hash_input,
		loc,
	}
}

loop_hash :: proc (
	tag: string,
	index: int,
	loc := #caller_location,
) -> Located(Tagged_Index) {
	return  {
		Tagged_Index{tag,index},
		loc,
	}
}

string_hash :: proc (
	tag: string, // This is used by-value, so it's safe to tprint into it.
	loc := #caller_location,
) -> Located(Tagged_Index) {
	return {
		Tagged_Index{tag, 0}, // TODO don't waste hash-space on that int.
		loc,
	}
}

////////////////////////////////////////////////////////////////////////////////
// Color
////////////////////////////////////////////////////////////////////////////////
// Entities take [4]f32 with elements in the range of 0..1
// These functions build those values.

// The examples are equivalent. They all produce solid-white.
color :: proc {
	_raw_color,  // color(1.0, 0.0, 0.0, 1.0)
	color_bytes, // color(255, 0, 0, 255)
	color_string,  // color("#f00")
	color_hex,     // color(0xf00)
}

// This is here for refactoring/leverage so you don't have to delete your color() call.
// You don't need a proc to assign 0..1 floats to an entity.
_raw_color :: proc (r: f32, g: f32, b: f32, a: f32 = 1) -> Color4 {
	return {r,g,b,a} 
}

color_bytes :: proc (r: u8, g: u8, b: u8, a: u8 = 1) -> Color4 {
	return array_cast([4]u8{r,g,b,a}, f32) / 255
}

color_hex :: proc (hex: u32) -> Color4 {
	bytes := transmute([4]u8) hex
	return array_cast(bytes, f32) / 255
}

// "#fff"      => white
// "#fff5"     => transparent white
// "#ff00ff"   => purple
// "#ff00ff55" => transparent purple
color_string :: proc "contextless" (str: string) -> Color4 {
	NIBBLE :: 4 // half a byte
	if len(str) == 0 do return {}
	str := str
	if str[0] == '#' do str = str[1:] // strip optional leading symbol

	x :: hex_digit
	bytes: [4]u8 = {0,0,0,max(u8)}
	switch len(str) {
	case 0 ..< 3:
		for i in 0..< len(str) {
			bytes[i] = x(str[i]) << NIBBLE | x(str[i])
		}
	case 3 ..< 4:
		bytes.r = x(str[0]) << NIBBLE | x(str[0])
		bytes.g = x(str[1]) << NIBBLE | x(str[1])
		bytes.b = x(str[2]) << NIBBLE | x(str[2])
	case 4 ..< 6:
		bytes.r = x(str[0]) << NIBBLE | x(str[0])
		bytes.g = x(str[1]) << NIBBLE | x(str[1])
		bytes.b = x(str[2]) << NIBBLE | x(str[2])
		bytes.a = x(str[3]) << NIBBLE | x(str[3])
	case 6 ..< 8:
		bytes.r = x(str[0]) << NIBBLE | x(str[1])
		bytes.g = x(str[2]) << NIBBLE | x(str[3])
		bytes.b = x(str[4]) << NIBBLE | x(str[5])
	case:
		bytes.r = x(str[0]) << NIBBLE | x(str[1])
		bytes.g = x(str[2]) << NIBBLE | x(str[3])
		bytes.b = x(str[4]) << NIBBLE | x(str[5])
		bytes.a = x(str[6]) << NIBBLE | x(str[7])
	}

	return array_cast(bytes, f32) / 255
}

hex_digit :: proc "contextless" (char: u8) -> u8 {
	switch char {
	case '0' ..= '9': return char - '0'
	case 'a' ..= 'f': return char - 'a' + 10
	case 'A' ..= 'F': return char - 'A' + 10
	}
	return 0
}

////////////////////////////////////////////////////////////////////////////////
// Positioning
////////////////////////////////////////////////////////////////////////////////
// For 2D things, I don't want this to overwrite Z
transform :: proc {
	transform_assign,
	transform_offset,
}

transform_assign :: proc "contextless" (child: ^Entity, parent: Entity) {
	derived_z := child.position.z
	child.basis = parent.basis
	child.transform = parent.transform
	child.position.z = derived_z
}
transform_offset :: proc "contextless" (child: ^Entity, parent: Entity, offset: Transform) {
	transform_assign(child, parent)
	child.position  += offset.position
	child.scale     += offset.scale
	child.rotation  += offset.rotation
}
transform_add :: proc "contextless" (a,b: Transform) -> Transform {
	return {
		position = a.position + b.position,
		rotation = a.rotation + b.rotation,
		scale    = a.scale * b.scale,
	}
}

transform_subtract :: proc "contextless" (a,b: Transform) -> Transform {
	return {
		position = a.position - b.position,
		rotation = a.rotation - b.rotation,
		scale    = a.scale / b.scale,
	}
}
uncenter_rect :: proc "contextless" (entity: ^Entity) {
	entity.basis.position.xy = entity.basis.scale.xy/2
}

////////////////////////////////////////////////////////////////////////////////
// Collision Detection
////////////////////////////////////////////////////////////////////////////////

// Below: Query entity pairs.

they_touch :: proc (e1, e2: ^Entity) -> bool {
	return find_collision_involving_entities(globals.collisions[:], e1, e2)
}

they_started_touching :: proc (e1, e2: ^Entity) -> bool {
	return find_collision_involving_entities(globals.enter_collisions[:], e1, e2)
}

they_stopped_touching :: proc (e1, e2: ^Entity) -> bool {
	return find_collision_involving_entities(globals.exit_collisions[:], e1, e2)
}

// Below: Query all entities.

entity_collisions :: proc (entity: ^Entity) -> []Collision {
	return find_collisions_involving_entity(globals.collisions[:], entity)
}

enter_events :: proc (entity: ^Entity) -> []Collision {
	return find_collisions_involving_entity(globals.enter_collisions[:], entity)
}

exit_events :: proc (entity: ^Entity) -> []Collision {
	return find_collisions_involving_entity(globals.exit_collisions[:], entity)
}
