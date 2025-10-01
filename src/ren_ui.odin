package main

Alignment :: enum { Start, Center, End }

Direction :: enum { Left, Right, Top, Bottom }

UI_Element_Type :: enum { Row, Column, Box, Root }

UI_Element :: struct {
	type:                 UI_Element_Type,
	main_axis_alignment:  Alignment,
	cross_axis_alignment: Alignment,
	padding:              [Direction]f32,
}

ui_element :: proc (child: ^Entity, loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	entity.children = make([]^Entity, 1, context.temp_allocator)
	entity.children[0] = child
	entity.variant = UI_Element {
		type = .Root
	}
	entity.flags += { .Hidden }
	return entity
}

row :: proc (children: ..^Entity, loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	copy(entity.children, children)
	entity.variant = UI_Element {
		type = .Row
	}
	entity.flags += { .Hidden }
	return entity
}

column :: proc (children: ..^Entity, loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	copy(entity.children, children)
	entity.variant = UI_Element {
		type = .Column
	}
	entity.flags += { .Hidden }
	return entity
}

measure_entity :: proc (entity: ^Entity) -> Vec2 {
	switch variant in entity.variant {
	case Image_State:
		return entity.basis.scale.xy + entity.scale.xy
	case Sprite_State:
		return entity.basis.scale.xy + entity.scale.xy
	case Text_State:
		return measure_text(entity^)
	case UI_Element:
		switch variant.type {
		case .Root: 
			return measure_entity(entity.children[0])
		case .Row:
			size: Vec2
			for child in entity.children {
				child_size := measure_entity(child)
				size.x += child_size.x
				if child_size.y > size.y { size.y = child_size.y }
			}
			return size
		case .Column:
			size: Vec2
			for child in entity.children {
				child_size := measure_entity(child)
				size.y += child_size.y
				if child_size.x > size.x { size.x = child_size.x }
			}
			return size
		case .Box:
			return entity.basis.scale.xy + entity.scale.xy
		}
	}
	panic("Exhaustive Switch")
}

// Modifies the sizes and positions of elements.
// To be done some time before render.
layout_subtree :: proc (root: ^Entity) {
	ui_element := root.variant.(UI_Element)
	size := measure_entity(root)
	switch ui_element.type {
	case .Root:
		root.children[0].position = root.position
		root.children[0].scale = root.scale
		layout_subtree(root.children[0])
	case .Row:
		// sizes := make([dynamic]Vec2, context.temp_allocator)
		// 	append(&sizes, measure_entity(child))
		main_axis_offset: f32
		max_cross_axis_size: f32
		for child in root.children {
			child.position.x = root.position.x + main_axis_offset
			child_size := measure_entity(child)
			main_axis_offset = child.position.x + child_size.x
			if child_size.y > max_cross_axis_size { max_cross_axis_size = child_size.y }
		}
		root.scale.x = main_axis_offset
		root.scale.y = max_cross_axis_size
		// step through children and position them
	case .Column: break
		// step through children and position them
	case .Box: break
	} 
}
