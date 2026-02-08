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
	child_spacing: f32,
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
	spacing:  f32 = 0,
	wh_sizers := SIZERS_FIXED_ROW,
	hash: Hash = #caller_location
) -> ^Entity {
	entity, is_new := get_entity(hash)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	entity.ui.main_axis = .Horizontal
	entity.ui.sizer = wh_sizers
	entity.ui.child_spacing = spacing
	copy(entity.children, children)
	entity.flags += { .Hidden, .Skip_Interpolation }
	init_ui_container(entity)
	return entity
}

column :: proc (
	children: ..^Entity,
	spacing:  f32 = 0,
	wh_sizers := SIZERS_FIXED_COLUMN,
	hash: Hash = #caller_location
) -> ^Entity {
	entity, is_new := get_entity(hash)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	entity.ui.main_axis = .Vertical
	entity.ui.sizer = wh_sizers
	entity.ui.child_spacing = spacing
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

pad :: proc (e: ^Entity, all: f32) -> ^Entity {
	e.ui.padding = {.Left = all, .Top = all, .Right = all, .Bottom = all}
	return e
}

pad_h :: proc (e: ^Entity, horizontal_padding: f32) -> ^Entity {
	e.ui.padding[.Left] = horizontal_padding
	e.ui.padding[.Right] = horizontal_padding
	return e
}

pad_v :: proc (e: ^Entity, vertical_padding: f32) -> ^Entity {
	e.ui.padding[.Top] = vertical_padding
	e.ui.padding[.Bottom] = vertical_padding
	return e
}

pad_edges :: proc (e: ^Entity, edges: [Direction]f32) -> ^Entity {
	e.ui.padding = edges
	return e
}

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
	entity.basis.position = {}
	entity.transform.position = {}
	cross_axis := cross_axis(entity.ui.main_axis)
	max_child_main:  f32
	max_child_cross: f32
	sum_main:  f32
	sum_cross: f32
	// num_unknowns_main:  f32
	// num_unknowns_cross: f32
	num_children := len(entity.children)
	children := &entity.children
	for i in 0..< num_children {
	child := children[i];
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

	main_size: ^f32 = axis_ptr(entity.ui.main_axis, &entity.basis.scale)
	switch axis_sizer(entity.ui.main_axis, entity.ui.sizer) {
	case .Specified:
	 // NOOP, in fact there's room to save work above.
	case .Sum_Children:
		main_size^ = sum_main
	case .Max_Child:
		main_size^ = max_child_main
	case .Flexed_By_Parent:
		// NOOP, deferred for the tree-pass.
	}
	if num_children > 1 do main_size^ += entity.ui.child_spacing * f32(num_children - 1)
	cross_size: ^f32 = axis_ptr(cross_axis, &entity.basis.scale)
	switch axis_sizer(cross_axis, entity.ui.sizer) {
	case .Specified:
		// NOOP, in fact there's room to save work above.
	case .Sum_Children:
		cross_size^ = sum_cross
	case .Max_Child:
		cross_size^ = max_child_cross
	case .Flexed_By_Parent:
		// NOOP, deferred for the tree-pass.
	}
}

// Modifies the sizes and positions of elements.
// FUTURE: Could introduce "bounds" param instead of modifying size in-place (for padding)
ui_layout :: proc (
	widget: ^Entity
) {
	main_axis  := widget.ui.main_axis
	cross_axis := cross_axis(main_axis)
	main_size:  ^f32 = axis_ptr(main_axis, &widget.basis.scale)
	cross_size: ^f32 = axis_ptr(cross_axis, &widget.basis.scale)
	pad_main_leading,  pad_main_trailing  := padding_components_along_axis(widget, main_axis)
	pad_cross_leading, pad_cross_trailing := padding_components_along_axis(widget, cross_axis)
	main_offset:  ^f32 = axis_ptr(main_axis,  &widget.position)
	cross_offset: ^f32 = axis_ptr(cross_axis, &widget.position)
// Step 1. Shrink container by padding and offset it by padding along leading-edge.
	main_size^  -= pad_main_leading  + pad_main_trailing
	cross_size^ -= pad_cross_leading + pad_cross_trailing
	main_offset^  += pad_main_leading
	cross_offset^ += pad_cross_leading
	num_children := len(widget.children)
	if num_children > 1 do main_size^ -= widget.ui.child_spacing * f32(num_children - 1)

// Step 2. Infer unknown child sizes. (everything is flex: 1)
	main_axis_size_remaining: f32 = main_size^
	num_unknowns_main: f32

	for child in widget.children {
		if sizer_along_axis(child, main_axis) == .Flexed_By_Parent {
			num_unknowns_main += 1
		} else {
			child_main := size_along_axis(child, main_axis)
			main_axis_size_remaining -= child_main
		}
		if sizer_along_axis(child, cross_axis) == .Flexed_By_Parent {
			axis_ptr(cross_axis, &child.basis.scale)^ = cross_size^
		} else {
			// known height. child uses min of self-size and parentsize.
			// TODO: position it vertically. overflow-check.
		}
	}

	inferred_main := main_axis_size_remaining / num_unknowns_main
	main_cursor := main_offset^

// Step 3: Provide size to children, position them, and recurse.
	for _i in 0..<num_children {
	i := main_axis == .Vertical ? (num_children-1 -_i) : _i
	child := widget.children[i];

		child_main_offset:  ^f32 = axis_ptr(main_axis,  &child.position)
		child_cross_offset: ^f32 = axis_ptr(cross_axis, &child.position)
		child_main_offset^ = main_cursor
		child_cross_offset^ = cross_offset^
		child.position.z = widget.position.z

		child_main_size:  f32 = size_along_axis(child, main_axis)
		child_cross_size: f32 = size_along_axis(child, cross_axis)
		
		if sizer_along_axis(child, main_axis) == .Flexed_By_Parent {
			axis_ptr(main_axis, &child.basis.scale)^ = inferred_main
			child_main_size = inferred_main
		}
		ui_layout(child) // now it's sized and positioned, so layout below.
		main_cursor += child_main_size + widget.ui.child_spacing
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
