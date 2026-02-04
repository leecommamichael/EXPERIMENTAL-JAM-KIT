package main

import "base:runtime"
import "core:log"

Axis :: enum { Horizontal, Vertical }

// Alignment :: enum { Start, Center, End }

Direction :: enum { Left, Right, Up, Down }

UI_Element_Flag :: enum {
	Parent_Picks_Width,  // expects it from parent. (Remaining_Width)
	Parent_Picks_Height, // expects it from parent. (Remaining_Height)
	Hovered,
	Pressed
}

UI_Element :: struct {
	flags: UI_Flags,
	focus: [Direction]^Entity,
	main_axis: Axis,
	// main_alignment:  Alignment,
	// cross_alignment: Alignment,
	// padding:              [Direction]f32,
}
UI_Flags :: bit_set[UI_Element_Flag]

// What region we're currently laying-out inside of. Layout_State.
UI_Context :: struct {
	size:   Vec2,
	offset: Vec2,
	z:      f32
}

ui_context :: proc (size: Vec2, hash: Hash = #caller_location) -> ^Entity {
	ctx, is_new := get_entity(hash)
	ctx.flags += {.Hidden, .Skip_Interpolation}
	ctx.transform = {}
	ctx.basis = {}
	ctx.basis.scale.xy = size
	ctx.basis.scale.z = 1 // TODO: TAP TARGET SIZE
	ctx.position.z = next_z()

	return ctx
}

row :: proc (children: ..^Entity, hash: Hash = #caller_location) -> ^Entity {
	entity, is_new := get_entity(hash)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	entity.ui.main_axis = .Horizontal
	copy(entity.children, children)
	entity.flags += { .Hidden, .Skip_Interpolation }
	init_list_children(entity)
	return entity
}

column :: proc (children: ..^Entity, hash: Hash = #caller_location) -> ^Entity {
	entity, is_new := get_entity(hash)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	entity.ui.main_axis = .Vertical
	copy(entity.children, children)
	entity.flags += { .Hidden, .Skip_Interpolation }
	init_list_children(entity)
	return entity
}

////////////////////////////////////////////////////////////////////////////////
// Modifiers
////////////////////////////////////////////////////////////////////////////////
ui_mod :: proc (entity: ^Entity, flags: UI_Flags) -> ^Entity {
	entity.ui.flags += flags
	return entity
}
flex_wh :: proc (entity: ^Entity) -> ^Entity {
	entity.ui.flags += {.Parent_Picks_Width, .Parent_Picks_Height}
	return entity
}
flex_w :: proc (entity: ^Entity) -> ^Entity {
	entity.ui.flags += {.Parent_Picks_Width}
	return entity
}
flex_h :: proc (entity: ^Entity) -> ^Entity {
	entity.ui.flags += {.Parent_Picks_Height}
	return entity
}

// stack :: proc (children: ..^Entity, hash: Hash = #caller_location) -> ^Entity {
// 	entity, is_new := get_entity(hash)
// 	entity.ui.type = .Column
// 	entity.children = make([]^Entity, len(children), context.temp_allocator)
// 	copy(entity.children, children)
// 	entity.flags += { .Hidden }
// 	init_list_children(entity, .Vertical)
// 	return entity
// }

pad_box :: proc (
	size: Vec2,
	hash: Hash = #caller_location
) -> ^Entity {
	entity, is_new := get_entity(hash)
	entity.flags += {.Hidden, .Skip_Interpolation }
	entity.basis.scale.xy = size
	entity.basis.position.xy = size/2
	entity.position.z = next_z()
	return entity
}

expander :: proc (
	hash: Hash = #caller_location
) -> ^Entity {
	entity, is_new := get_entity(hash)
	entity.flags += {.Hidden, .Skip_Interpolation }
	entity.ui.flags += {.Parent_Picks_Width, .Parent_Picks_Height}
	entity.basis.scale = 0
	entity.basis.position = 0
	entity.position.z = next_z()
	return entity
}

// Create trees for focus and parent/child traversal (for layout)
init_list_children :: proc (entity: ^Entity) {
	num_children := len(entity.children)
	children := entity.children
	for i in 0..< num_children {
		next_or_wrap := i+1 if i+1 < num_children else 0
		next_main: Direction = .Right if entity.ui.main_axis == .Horizontal else .Down
		children[i].ui.focus[next_main] = children[next_or_wrap]

		previous_or_wrap := i-1 if i-1 >= 0 else i
		prev_main: Direction = .Left if entity.ui.main_axis == .Horizontal else .Up
		children[i].ui.focus[prev_main] = children[previous_or_wrap]

		children[i].parent = entity
	}
}

measure_entity :: proc (entity: ^Entity) -> Vec2 {
	return entity.basis.scale.xy * entity.scale.xy
	// switch {
	// // case entity.ui.main_axis == .Horizontal:
	// // 	size: Vec2
	// // 	for child in entity.children {
	// // 		child_size := measure_entity(child)
	// // 		size.x += child_size.x
	// // 		if child_size.y > size.y { size.y = child_size.y }
	// // 	}
	// // 	return size
	// // case entity.ui.main_axis == .Vertical:
	// // 	size: Vec2
	// // 	for child in entity.children {
	// // 		child_size := measure_entity(child)
	// // 		size.y += child_size.y
	// // 		if child_size.x > size.x { size.x = child_size.x }
	// // 	}
	// // 	return size
	// case: // Not a UI element, but some we can measure.
	// 	switch variant in entity.variant {
	// 	case nil:
	// 		return entity.basis.scale.xy * entity.scale.xy
	// 	case Image_State:
	// 		return entity.basis.scale.xy * entity.scale.xy
	// 	case Sprite_State:
	// 		return entity.basis.scale.xy * entity.scale.xy
	// 	case Text_State:
	// 		return measure_text(entity^)
	// 	case Timed_Effect_State(Empty_Struct): // not visual
	// 		return 0
	// 	}
	// }

	// log.panicf("Exhaustive Switch %v %s", entity.variant, entity.debug_name)
}

// Size comes from above, and is subdivided.
// Blocks can be unknown-size, but must be filled in before laying out other components.
//
// Bounded-size list. (max or size)
//   Case 1: Listing sized elements.           // trivial
//   Case 2: Listing sized & unsized elements. // give remaining size
//
// Modifies the sizes and positions of elements.
ui_layout :: proc (
	widget: ^Entity
) {
	z := next_z() // Don't think this is right
	switch {
	case widget.ui.main_axis == .Horizontal:
		main_axis_size_remaining: f32 = widget.basis.scale.x
		cross_axis_size:          f32 = widget.basis.scale.y
		num_elems_without_width:  f32
		// Pass 1: Collect metrics.
		for child in widget.children {
			if .Parent_Picks_Height in child.ui.flags {
				child.basis.scale.y = cross_axis_size; // <---------------- child height
			} else {
				// known height. 
				// TODO: position it vertically. overflow-check.
			}
			if .Parent_Picks_Width in child.ui.flags {
				num_elems_without_width += 1
			} else {
				// ASSUME: a width is measureable to deduct from the main axis.
				child_size := measure_entity(child)
				main_axis_size_remaining -= child_size.x
			}
		}
		child_width := main_axis_size_remaining / num_elems_without_width

		// TODO: offset elements on main axis alignment according to extra space.

		// Pass 2: Provide size to children, position them, and recurse.
		main_axis_offset: f32 = widget.position.x
		for child in widget.children {
			if .Parent_Picks_Width in child.ui.flags {
				child.basis.scale.x = child_width // <---------------------- child width
			}
			child.position.z = z
			child.position.x = main_axis_offset
			child.position.y = widget.position.y
			ui_layout(child) // now it's sized and positioned, so layout below.
			main_axis_offset += child.basis.scale.x
		}

	case widget.ui.main_axis == .Vertical: {
		main_axis_size_remaining: f32 = widget.basis.scale.y
		cross_axis_size:          f32 = widget.basis.scale.x
		num_elems_without_height: f32
		// Pass 1: Collect metrics.
		#reverse for child in widget.children { child := child;
			if .Parent_Picks_Width in child.ui.flags {
				child.basis.scale.x = cross_axis_size; // <---------------- child width
			} else {
				// known width. 
				// TODO: position it horizontally. overflow-check.
			}
			if .Parent_Picks_Height in child.ui.flags {
				num_elems_without_height += 1
			} else {
				// ASSUME: a width is measureable to deduct from the main axis.
				child_size := measure_entity(child)
				main_axis_size_remaining -= child_size.y
			}
		}
		child_height := main_axis_size_remaining / num_elems_without_height

		// TODO: offset elements on main axis alignment according to extra space.

		// Pass 2: Provide size to children, position them, and recurse.
		main_axis_offset: f32 = widget.position.y
		#reverse for child in widget.children { child := child;
			if .Parent_Picks_Height in child.ui.flags {
				child.basis.scale.y = child_height // <---------------------- child height
			}
			child.position.z = z
			child.position.y = main_axis_offset
			child.position.x = widget.position.x
			ui_layout(child) // now it's sized and positioned, so layout below.
			main_axis_offset += child.basis.scale.y
		}
}
	case:
		widget.position.z = z
	} // switch
}

import "sugar"
button :: proc (hash: Hash = #caller_location) -> ^Entity {
	entity, is_new := get_entity(hash)
	if is_new {
		entity.flags += {.Collider_Enabled}
		entity.collider.shape = .AABB
		entity.collider.size = 44 / globals.canvas_stretch.x
		// This gist is that the GPU always gets the transform and the shader uses it.
		mesh := geom_make_quad(1, context.temp_allocator)
		entity.draw_command = ren_make_basic_draw_cmd(
			globals.instance_buffer,
			cast(int) entity.id,
			mesh.vertices[:],
			mesh.indices[:]
		)
	}
	entity.position.z = next_z()

	if they_touch(globals.cursor, entity) {
		entity.ui.flags += {.Hovered}
		if sugar.is_key_pressed(.Left_Mouse) {
			entity.ui.flags += {.Pressed}
		}
	}

	return entity
}
