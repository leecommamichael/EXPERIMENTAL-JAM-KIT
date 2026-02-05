package main

import "base:runtime"
import "core:log"

Axis :: enum { Horizontal, Vertical }

// Alignment :: enum { Start, Center, End }

Direction :: enum { Left, Right, Up, Down }

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
	main_axis: Axis,
	// main_alignment:  Alignment,
	// cross_alignment: Alignment,
	// padding:         [Direction]f32,
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
SIZERS_FIXED_COLUMN :: [2]Sizer {.Max_Child, .Sum_Children}
SIZERS_FLEX_ROW     :: [2]Sizer {.Flexed_By_Parent, .Max_Child}
SIZERS_FLEX_COLUMN  :: [2]Sizer {.Max_Child, .Flexed_By_Parent}

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
	entity.ui.sizer = Sizer.Flexed_By_Parent
	entity.basis.scale = 0
	entity.basis.position = 0
	entity.position.z = next_z()
	return entity
}

// ASSUMES: because the children exist they are measured.
// This means leaf-Entities need to measure themselves immediately upon creation.
// Create trees for focus and parent/child traversal (for layout)
init_ui_container :: proc (entity: ^Entity) {
	cross_axis := entity.ui.main_axis == .Horizontal ? Axis.Vertical : Axis.Horizontal
	max_child_main:  f32
	max_child_cross: f32
	sum_main:  f32
	sum_cross: f32
	num_unknowns_main:  f32
	num_unknowns_cross: f32
	num_children := len(entity.children)
	children := &entity.children
	for i in 0..< num_children { child := children[i];
		switch sizer_along_axis(child, entity.ui.main_axis) {
		case .Specified, .Sum_Children, .Max_Child: // In these cases, assume it's computed.
			main_axis_size := size_along_axis(child, entity.ui.main_axis)
			sum_main += main_axis_size
			if main_axis_size > max_child_main do max_child_main = main_axis_size
		case .Flexed_By_Parent:
			num_unknowns_main += 1
		}
		switch sizer_along_axis(child, cross_axis) {
		case .Specified, .Sum_Children, .Max_Child: // In these cases, assume it's computed.
			cross_axis_size := size_along_axis(child, entity.ui.main_axis == .Horizontal ? Axis.Vertical : Axis.Horizontal)
			sum_cross += cross_axis_size
			if cross_axis_size > max_child_cross do max_child_cross = cross_axis_size
		case .Flexed_By_Parent:
			num_unknowns_cross += 1
		}

		next_or_wrap := i+1 if i+1 < num_children else 0
		next_main: Direction = .Right if entity.ui.main_axis == .Horizontal else .Down
		child.ui.focus[next_main] = children[next_or_wrap]

		previous_or_wrap := i-1 if i-1 >= 0 else i
		prev_main: Direction = .Left if entity.ui.main_axis == .Horizontal else .Up
		child.ui.focus[prev_main] = children[previous_or_wrap]

		child.parent = entity
	}
	switch main_axis_sizer(entity) {
	case .Specified:
	 // NOOP, in fact there's room to save work above.
	case .Sum_Children:
		axis_ptr(entity.ui.main_axis, &entity.basis.scale)^ = sum_main
	case .Max_Child:
		axis_ptr(entity.ui.main_axis, &entity.basis.scale)^ = max_child_main
	case .Flexed_By_Parent:
		// NOOP, deferred for the tree-pass.
	}
	switch cross_axis_sizer(entity) {
	case .Specified:
		// NOOP, in fact there's room to save work above.
	case .Sum_Children:
		axis_ptr(cross_axis, &entity.basis.scale)^ = sum_cross
	case .Max_Child:
		axis_ptr(cross_axis, &entity.basis.scale)^ = max_child_cross
	case .Flexed_By_Parent:
		// NOOP, deferred for the tree-pass.
	}
}

measure_entity :: proc (entity: ^Entity) -> Vec2 {
	switch {
	// case entity.ui.main_axis == .Horizontal:
	// 	size: Vec2
	// 	for child in entity.children {
	// 		child_size := measure_entity(child)
	// 		size.x += child_size.x
	// 		if child_size.y > size.y { size.y = child_size.y }
	// 	}
	// 	return size
	// case entity.ui.main_axis == .Vertical:
	// 	size: Vec2
	// 	for child in entity.children {
	// 		child_size := measure_entity(child)
	// 		size.y += child_size.y
	// 		if child_size.x > size.x { size.x = child_size.x }
	// 	}
	// 	return size
	case: // Not a UI element, but some we can measure.
		switch variant in entity.variant {
		case nil:
			return entity.basis.scale.xy * entity.scale.xy
		case Image_State:
			return entity.basis.scale.xy * entity.scale.xy
		case Sprite_State:
			return entity.basis.scale.xy * entity.scale.xy
		case Text_State:
			return measure_text(entity^)
		case Timed_Effect_State(Empty_Struct): // not visual
			return 0
		}
	}

	log.panicf("Exhaustive Switch %v %s", entity.variant, entity.debug_name)
}
// switch widget.ui.sizer.x {
// case .Specified:        // just count unknowns
// case .Flexed_By_Parent: // should already be sized. same as .specified += unknown
// case .Sum_Children:     // just add similar dimension
// case .Max_Child:        // max of children
// case .Measured:         //
// } // switch sizer.x

axis_ptr :: #force_inline proc "contextless" (axis: Axis, arr: ^[$N]f32) -> ^f32 {
	return axis == .Horizontal ? &arr.x : &arr.y
}
main_axis_ptr :: #force_inline proc "contextless" (e: ^Entity, arr: ^[$N]f32) -> ^f32 {
	return e.ui.main_axis == .Horizontal ? &arr.x : &arr.y
}
cross_axis_ptr :: #force_inline proc "contextless" (e: ^Entity, arr: ^[$N]f32) -> ^f32 {
	return e.ui.main_axis == .Vertical ? &arr.x : &arr.y
}
main_axis_sizer :: #force_inline proc "contextless" (e: ^Entity) -> Sizer {
	return e.ui.main_axis == .Horizontal ? e.ui.sizer.x : e.ui.sizer.y
}
cross_axis_sizer :: #force_inline proc "contextless" (e: ^Entity) -> Sizer {
	return e.ui.main_axis == .Vertical ? e.ui.sizer.x : e.ui.sizer.y
}

sizer_along_axis :: #force_inline proc "contextless" (
	entity: ^Entity,
	axis: Axis
) -> Sizer {
	return axis == .Vertical ? entity.ui.sizer.y : entity.ui.sizer.x
}

size_along_axis :: #force_inline proc "contextless" (
	entity: ^Entity,
	axis: Axis
) -> f32 {
	return axis == .Vertical ? entity.basis.scale.y : entity.basis.scale.x
}

child_sizer_along_parent_main_axis :: #force_inline proc "contextless" (
	parent: ^Entity,
	child: ^Entity
) -> Sizer {
	return parent.ui.main_axis == .Horizontal ? child.ui.sizer.x : child.ui.sizer.y
}

child_sizer_along_parent_cross_axis :: #force_inline proc "contextless" (
	parent: ^Entity,
	child: ^Entity
) -> Sizer {
	return parent.ui.main_axis == .Vertical ? child.ui.sizer.x : child.ui.sizer.y
}


// Flexed_By_Parent cannot be a child of Sum_Children or Max_Child
layout_span :: proc (
	widget: ^Entity
) {
	z := next_z() // Don't think this is right
	main_axis_size:    ^f32 = main_axis_ptr(widget, &widget.basis.scale)
	cross_axis_size:   ^f32 = cross_axis_ptr(widget, &widget.basis.scale)
	main_axis_sizer :=  main_axis_sizer(widget)
	cross_axis_sizer := cross_axis_sizer(widget)
	main_axis_size_remaining: f32
	num_flex_children:        f32

	// // Pass 1: Size the children, and possibly the container.
	// switch main_axis_sizer {
	// case .Specified:
	// 	switch cross_axis_sizer {
	// 	case .Specified:        // The container's height and width are specified.
	// 	case .Flexed_By_Parent: unimplemented()
	// 	case .Sum_Children:     unimplemented()
	// 	case .Max_Child:        unimplemented()
	// 	}
	// case .Flexed_By_Parent:
	// 	switch cross_axis_sizer {
	// 	case .Specified:        // The container's height and width are specified.
	// 	case .Flexed_By_Parent: // should already be sized. same as .specified += unknown
	// 	case .Sum_Children:     // just add similar dimension
	// 	case .Max_Child:        // max of children
	// 	}
	// case .Sum_Children:     // just add similar dimension
	// 	switch cross_axis_sizer {
	// 	case .Specified:        // The container's height and width are specified.
	// 	case .Flexed_By_Parent: // should already be sized. same as .specified += unknown
	// 	case .Sum_Children:     // just add similar dimension
	// 	case .Max_Child:        // max of children
	// 	}
	// case .Max_Child:        // max of children
	// 	switch cross_axis_sizer {
	// 	case .Specified:        // The container's height and width are specified.
	// 	case .Flexed_By_Parent: // should already be sized. same as .specified += unknown
	// 	case .Sum_Children:     // just add similar dimension
	// 	case .Max_Child:        // max of children
	// 	}
	// }
	for child in widget.children {
		switch {
		case widget.ui.sizer.x == .Sum_Children: fallthrough
		case widget.ui.sizer.x == .Max_Child:    fallthrough
		case widget.ui.sizer.y == .Sum_Children: fallthrough
		case widget.ui.sizer.y == .Max_Child:    
			switch {
			case child.ui.sizer.x == .Flexed_By_Parent: fallthrough
			case child.ui.sizer.y == .Flexed_By_Parent:
				raise_error("CHILDISH-PARENT & FLEXED-CHILD",
					"The parent's size is based on the child, and the child based on the parent.")
			}
		}

		if child.ui.sizer.y == .Flexed_By_Parent {
			cross_axis_ptr(child, &child.basis.scale)^ = cross_axis_size^
		} else {
			// known height. child uses min of self-size and parentsize.
			// TODO: position it vertically. overflow-check.
		}
		if child.ui.sizer.x == .Flexed_By_Parent {
			num_flex_children += 1
		} else {
			// ASSUME: a width is measureable to deduct from the main axis.
			child_size := measure_entity(child)
			main_axis_size_remaining -= child_size.x
		}
	}

	inferred_width := main_axis_size_remaining / num_flex_children

	// TODO: offset elements on main axis alignment according to extra space.

	// Pass 2: Provide size to children, position them, and recurse.
	main_axis_offset: f32 = widget.position.x
	for child in widget.children {
		child.position.z = z
		child.position.x = main_axis_offset
		child.position.y = widget.position.y

		ui_layout(child) // now it's sized and positioned, so layout below.
		if child.ui.sizer.x == .Flexed_By_Parent {
			child.basis.scale.x = inferred_width // <---------------------- child width
			main_axis_offset += inferred_width
		} else {
			child_size := measure_entity(child) // TODO: measures everything twice.
			main_axis_offset += child_size.x
		}
	}
}

// Modifies the sizes and positions of elements.
ui_layout :: proc (
	widget: ^Entity
) {
	z := next_z() // Don't think this is right
	switch { // ROW ROW ROW ROW ROW ROW ROW ROW ROW ROW ROW ROW ROW ROW ROW ROW
	case widget.ui.main_axis == .Horizontal:
		main_axis_size:           f32 = widget.basis.scale.x
		main_axis_size_remaining: f32 = widget.basis.scale.x
		cross_axis_size:          f32 = widget.basis.scale.y
		num_elems_without_width:  f32
		// Pass 1: Collect metrics.
		for child in widget.children {

			if child.ui.sizer.y == .Flexed_By_Parent {
				child.basis.scale.y = cross_axis_size; // <---------------- child height
			} else {
				// known height. child uses min of self-size and parentsize.
				// TODO: position it vertically. overflow-check.
			}
			if child.ui.sizer.x == .Flexed_By_Parent {
				num_elems_without_width += 1
			} else {
				// ASSUME: a width is measureable to deduct from the main axis.
				child_size := measure_entity(child)
				main_axis_size_remaining -= child_size.x
			}
		}
		inferred_width := main_axis_size_remaining / num_elems_without_width

		// TODO: offset elements on main axis alignment according to extra space.

		// Pass 2: Provide size to children, position them, and recurse.
		main_axis_offset: f32 = widget.position.x
		for child in widget.children {
			child.position.z = z
			child.position.x = main_axis_offset
			child.position.y = widget.position.y

			ui_layout(child) // now it's sized and positioned, so layout below.
			if child.ui.sizer.x == .Flexed_By_Parent {
				child.basis.scale.x = inferred_width // <---------------------- child width
				main_axis_offset += inferred_width
			} else {
				child_size := measure_entity(child) // TODO: measures everything twice.
				main_axis_offset += child_size.x
			}
		}

	case widget.ui.main_axis == .Vertical: { // COLUMN COLUMN COLUMN COLUMN COLUMN
		main_axis_size_remaining: f32 = widget.basis.scale.y
		cross_axis_size:          f32 = widget.basis.scale.x
		num_elems_without_height: f32
		// Pass 1: Collect metrics.
		#reverse for child in widget.children { child := child;
			if child.ui.sizer.x == .Flexed_By_Parent {
				child.basis.scale.x = cross_axis_size; // <---------------- child width
			} else {
				// known width. 
				// TODO: position it horizontally. overflow-check.
			}
			if child.ui.sizer.y == .Flexed_By_Parent {
				num_elems_without_height += 1
			} else {
				// ASSUME: a width is measureable to deduct from the main axis.
				child_size := measure_entity(child)
				main_axis_size_remaining -= child_size.y
			}
		}
		inferred_height := main_axis_size_remaining / num_elems_without_height

		// TODO: offset elements on main axis alignment according to extra space.

		// Pass 2: Provide size to children, position them, and recurse.
		main_axis_offset: f32 = widget.position.y
		#reverse for child in widget.children { child := child;
			child.position.z = z
			child.position.y = main_axis_offset
			child.position.x = widget.position.x
			ui_layout(child) // now it's sized and positioned, so layout below.
			if child.ui.sizer.y == .Flexed_By_Parent {
				child.basis.scale.y = inferred_height // <---------------------- child height
				main_axis_offset += inferred_height
			} else {
				child_size := measure_entity(child) // TODO: measures everything twice.
				main_axis_offset += child_size.y
			}
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
