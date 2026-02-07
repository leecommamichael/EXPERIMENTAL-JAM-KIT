package main

import "base:runtime"
import "core:log"

Axis :: enum { Horizontal, Vertical }

// Alignment :: enum { Start, Center, End }

Direction :: enum {
	Left,
	Right,
	Up,
	Down,
	//
	Top = Up,
	Bottom = Down,
}

UI_Element_Flag :: enum {
	Hovered,
	Pressed
}

Sizer :: enum {
	Specified,
	Sum_Children,
	Max_Child,
	Flexed_By_Parent,
}

UI_Element :: struct {
	// size:        Vec2,
	sizer: [2]Sizer,
	flags:  UI_Flags,
	focus:  [Direction]^Entity,
	padding: [Direction]f32,
	main_axis: Axis,
	// main_alignment:  Alignment,
	// cross_alignment: Alignment,
}

UI_Flags :: bit_set[UI_Element_Flag]

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

sized :: proc (size: Vec2, entity: ^Entity) -> ^Entity {
	entity.basis.scale.xy = size
	return entity
}

sized_by_parent :: proc (entity: ^Entity) -> ^Entity {
	entity.ui.sizer = Sizer.Flexed_By_Parent
	return entity
}

SIZERS_FIXED_ROW    :: [2]Sizer {.Sum_Children, .Max_Child}
SIZERS_FLEX_ROW     :: [2]Sizer {.Flexed_By_Parent, .Max_Child}

SIZERS_FIXED_COLUMN      :: [2]Sizer {.Max_Child, .Sum_Children}
SIZERS_FLEX_WIDE_COLUMN  :: [2]Sizer {.Flexed_By_Parent, .Sum_Children}
SIZERS_FLEX_COLUMN       :: [2]Sizer {.Max_Child, .Flexed_By_Parent}

row :: proc (
	children: ..^Entity,
	wh_sizers := SIZERS_FIXED_ROW,
	hash: Hash = #caller_location
) -> ^Entity {
	entity, is_new := get_entity(hash)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	entity.ui.main_axis = .Horizontal
	entity.ui.sizer = wh_sizers
	copy(entity.children, children)
	entity.flags += { .Hidden, .Skip_Interpolation }
	init_ui_container(entity)
	return entity
}

column :: proc (
	children: ..^Entity,
	wh_sizers := SIZERS_FIXED_COLUMN,
	hash: Hash = #caller_location
) -> ^Entity {
	entity, is_new := get_entity(hash)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	entity.ui.main_axis = .Vertical
	entity.ui.sizer = wh_sizers
	copy(entity.children, children)
	entity.flags += { .Hidden, .Skip_Interpolation }
	init_ui_container(entity)
	return entity
}

// stack :: proc (children: ..^Entity, hash: Hash = #caller_location) -> ^Entity {
// 	entity, is_new := get_entity(hash)
// 	entity.ui.type = .Column
// 	entity.children = make([]^Entity, len(children), context.temp_allocator)
// 	copy(entity.children, children)
// 	entity.flags += { .Hidden }
// 	init_ui_container(entity, .Vertical)
// 	return entity
// }

spacer :: proc (
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

// TODO
	// need these to compose, so the basis needs to be dumped somehow.
	// same would be true if I made a "scale" element.
pad_edges :: proc (e: ^Entity, edges: [Direction]f32) -> ^Entity {
	e.ui.padding = edges
	return e
}
pad_all :: proc (e: ^Entity, all: f32) -> ^Entity {
	e.ui.padding = {.Left = all, .Top = all, .Right = all, .Bottom = all}
	return e
}
// pad_h
// pad_v

expander :: proc (
	hash: Hash = #caller_location
) -> ^Entity {
	entity, is_new := get_entity(hash)
	entity.flags += {.Hidden, .Skip_Interpolation }
	entity.ui.sizer = Sizer.Flexed_By_Parent
	entity.basis.scale = 0
	entity.basis.position = 0
	entity.position.z = next_z()
	return entity
}

// ASSUMES: because the children exist, they are measured.
// This means leaf-Entities need to measure themselves immediately upon creation.
// Create trees for focus and parent/child traversal (for layout)
init_ui_container :: proc (entity: ^Entity) {
	cross_axis := cross_axis(entity.ui.main_axis)
	max_child_main:  f32
	max_child_cross: f32
	sum_main:  f32
	sum_cross: f32
	// num_unknowns_main:  f32
	// num_unknowns_cross: f32
	num_children := len(entity.children)
	children := &entity.children
	for i in 0..< num_children { child := children[i];
		switch sizer_along_axis(child, entity.ui.main_axis) {
		case .Specified, .Sum_Children, .Max_Child: // In these cases, assume it's computed.
			main_axis_size := size_along_axis(child, entity.ui.main_axis)
			sum_main += main_axis_size
			if main_axis_size > max_child_main do max_child_main = main_axis_size
		case .Flexed_By_Parent:
			// num_unknowns_main += 1
		}
		switch sizer_along_axis(child, cross_axis) {
		case .Specified, .Sum_Children, .Max_Child: // In these cases, assume it's computed.
			cross_axis_size := size_along_axis(child, cross_axis)
			sum_cross += cross_axis_size
			if cross_axis_size > max_child_cross do max_child_cross = cross_axis_size
		case .Flexed_By_Parent:
			// num_unknowns_cross += 1
		}

		next_or_wrap := i+1 if i+1 < num_children else 0
		next_main: Direction = .Right if entity.ui.main_axis == .Horizontal else .Down
		child.ui.focus[next_main] = children[next_or_wrap]

		previous_or_wrap := i-1 if i-1 >= 0 else i
		prev_main: Direction = .Left if entity.ui.main_axis == .Horizontal else .Up
		child.ui.focus[prev_main] = children[previous_or_wrap]

		child.parent = entity
	}

	entity_main_size: ^f32 = axis_ptr(entity.ui.main_axis, &entity.basis.scale)
	switch axis_sizer(entity.ui.main_axis, entity.ui.sizer) {
	case .Specified:
	 // NOOP, in fact there's room to save work above.
	case .Sum_Children:
		entity_main_size^ = sum_main
	case .Max_Child:
		entity_main_size^ = max_child_main
	case .Flexed_By_Parent:
		// NOOP, deferred for the tree-pass.
	}
	entity_cross_size: ^f32 = axis_ptr(cross_axis, &entity.basis.scale)
	switch axis_sizer(cross_axis, entity.ui.sizer) {
	case .Specified:
		// NOOP, in fact there's room to save work above.
	case .Sum_Children:
		entity_cross_size^ = sum_cross
	case .Max_Child:
		entity_cross_size^ = max_child_cross
	case .Flexed_By_Parent:
		// NOOP, deferred for the tree-pass.
	}
}

// Modifies the sizes and positions of elements.
ui_layout :: proc (
	bounds: Vec2,
	widget: ^Entity
) {
	main_axis  := widget.ui.main_axis
	cross_axis := cross_axis(main_axis)
	main_axis_size_remaining: f32 = axis_ptr(main_axis,  &widget.basis.scale)^ - padding_along_axis(widget, main_axis)
	num_unknowns_main: f32

	// Pass 1: Flex, count unknowns, apply padding.
	for child in widget.children {
		if sizer_along_axis(child, main_axis) == .Flexed_By_Parent {
			num_unknowns_main += 1
		} else {
			child_main := size_along_axis(child, main_axis)
			main_axis_size_remaining -= child_main
		}
		if sizer_along_axis(child, cross_axis) == .Flexed_By_Parent {
			axis_ptr(cross_axis, &child.basis.scale)^ = size_along_axis(widget, cross_axis) - padding_along_axis(widget, cross_axis);
		} else {
			// known height. child uses min of self-size and parentsize.
			// TODO: position it vertically. overflow-check.
		}
	}
	inferred_main := main_axis_size_remaining / num_unknowns_main

	// Pass 2: Provide size to children, position them, and recurse.
	main_axis_offset: f32 = axis_ptr(main_axis, &widget.position)^
	cross_axis_offset: f32 = axis_ptr(cross_axis, &widget.position)^
	num_children := len(widget.children)
	for _i in 0..<num_children {
		i := main_axis == .Vertical ? (num_children-1 -_i) : _i
		child := widget.children[i];
		child_main: ^f32 = axis_ptr(main_axis, &child.position)
		child_cross: ^f32 = axis_ptr(cross_axis, &child.position)
		main_leading, main_trailing := padding_components_along_axis(child, main_axis)
		// mainpad_sign: f32 = main_axis == .Vertical ? -1 : +1
		// main_leading  *= mainpad_sign
		// main_trailing *= mainpad_sign
		cross_leading, _ :=  padding_components_along_axis(child, cross_axis)
		// crosspad_sign: f32 = cross_axis == .Vertical ? -1 : +1
		// cross_leading *= crosspad_sign
		
		main_axis_offset += main_leading
		child_main^ = main_axis_offset
		child_cross^ = cross_axis_offset + cross_leading
		child.position.z = widget.position.z
		ui_layout(0, child) // now it's sized and positioned, so layout below.
		flexes_on_main_axis := sizer_along_axis(child, main_axis) == .Flexed_By_Parent
		if flexes_on_main_axis {
			axis_ptr(main_axis, &child.basis.scale)^ = inferred_main
			main_axis_offset += inferred_main
		} else {
			child_main_size := size_along_axis(child, main_axis) + padding_along_axis(child, main_axis)
			main_axis_offset += child_main_size
		}
		main_axis_offset -= main_trailing
	}
}

////////////////////////////////////////////////////////////////////////////////
// Utils
////////////////////////////////////////////////////////////////////////////////
cross_axis :: #force_inline proc (axis: Axis) -> Axis {
	return axis == .Horizontal ? .Vertical : .Horizontal
}
axis_ptr :: #force_inline proc (axis: Axis, arr: ^[$N]f32) -> ^f32 {
	return axis == .Horizontal ? &arr.x : &arr.y
}
axis_sizer :: #force_inline proc (axis: Axis, arr: [$N]Sizer) -> Sizer {
	return axis == .Horizontal ? arr.x : arr.y
}

sizer_along_axis :: #force_inline proc (entity: ^Entity, axis: Axis) -> Sizer {
	return axis == .Vertical ? entity.ui.sizer.y : entity.ui.sizer.x
}

size_along_axis :: #force_inline proc (entity: ^Entity, axis: Axis) -> f32 {
	return content_size_along_axis(entity, axis) + padding_along_axis(entity, axis)
}
content_size_along_axis :: #force_inline proc (entity: ^Entity, axis: Axis) -> f32 {
	return axis == .Vertical ? entity.basis.scale.y : entity.basis.scale.x
}
padding_along_axis :: #force_inline proc (entity: ^Entity, axis: Axis) -> f32 {
	switch axis {
	case .Horizontal:
		return entity.ui.padding[.Left] + entity.ui.padding[.Right]
	case .Vertical:
		return entity.ui.padding[.Top] + entity.ui.padding[.Bottom]
	}
	assert(false)
	return 0
}
padding_components_along_axis :: #force_inline proc (entity: ^Entity, axis: Axis) -> (leading, trailing: f32) {
	switch axis {
	case .Horizontal:
		return entity.ui.padding[.Left], entity.ui.padding[.Right]
	case .Vertical:
		return entity.ui.padding[.Top], entity.ui.padding[.Bottom]
	}
	assert(false)
	return 0, 0
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
