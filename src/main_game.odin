package main

import "base:runtime"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"
import "core:mem/virtual"
import "core:sys/windows"
import "core:math/rand"
import "core:fmt"
import "core:time"
import "core:log"
import "sugar"

@export
hot_reload :: proc (engine_globals: ^Globals, engine_gs: ^Game_State) {
	ensure(engine_gs != nil)
	ensure(engine_globals != nil)
	gs = engine_gs
	globals = engine_globals
	sugar.set_memory(&globals.sugar)
	sugar.load_gl()
	globals.hot_reloaded_this_frame = true
}

////////////////////////////////////////////////////////////////////////////////
// Brainless Minigame Jam: Simpler Times                                Jan 2026
////////////////////////////////////////////////////////////////////////////////
// RG35SP_RES: Vec2 = {640, 480}
// STEAM_DECK_RES: Vec2 = {1280, 800}
RES :: Vec2 {640, 400} // 1/2 of Steam Deck, and pretty close to RG35SP

gs: ^Game_State

import gl "angle"
game_init :: proc () {
	// gl.BindSampler(cast(u32) Texture_Unit.Framebuffer_Texture, globals.ren.nearest_sampler)
	// gl.BindSampler(cast(u32) Texture_Unit.Texture,             globals.ren.nearest_sampler)
	// gl.BindSampler(cast(u32) Texture_Unit.Font,                globals.ren.nearest_sampler)
	globals.cursor = make_entity()
	globals.cursor.flags += {.Hidden}
	globals.cursor.position.xy = globals.mouse_position.xy
	globals.draw_colliders = false
	globals.canvas_size_px = {640,400}
	globals.canvas_scaling = .None
	globals.canvas_stretching = .Integer_Aspect
	globals.canvas_stretching = .Integer_Aspect

	r := rand.create(10)
	context.random_generator = rand.default_random_generator(&r)
	// How many ore, food, water to spawn?
	// Where to spawn them?
	// Well, there are 936 tiles.
	// if 1% chance for food, water, ore each, I'd get 9 of each.
	// So there's a relation between N tiles and N desired resources.
	// Let's say I want to spawn 5 things, SOMEWHAT evenly spaced through the tiles.
	// So I don't really want randomness...
	ore_remaining := 6
	water_remaining := 6
	food_remaining := 6

	gs = new(Game_State)
	err := virtual.arena_init_growing(&gs.preview_arena, 2*Kilobyte); assert(err == nil)
	gs.preview_allocator = virtual.arena_allocator(&gs.preview_arena)
	gs.tiles = make([]Tile, TILES)
	gs.next_action_id = 1
	for i in 0..<TILES {
		tile: ^Tile = &gs.tiles[i]
		tile.index = i
		tile.column_row = {i % COLUMNS, i / COLUMNS}
		tile.neighbors = make_neighbors(tile.column_row, context.allocator)
		tile.resource = .Grass
		f01 := rand.float32()
		if f01 <= 0.005 && ore_remaining > 0 {
			tile.resource = .Ore
			ore_remaining -= 1
		} else if f01 <= 0.01 && food_remaining > 0 {
			tile.resource = .Food
			food_remaining -= 1
		} else if f01 < 0.015 && water_remaining > 0 {
			tile.resource = .Water
			water_remaining -= 1
		}
	}

	// Start tiles
	gs.tiles[0].resource = .Barracks
	gs.tiles[0].owner = .Player
	gs.tiles[TILES-1].resource = .Barracks
	gs.tiles[TILES-1].owner = .Enemy
	// Starting stats
	gs.player.food = 0
	gs.player.water = 0
	gs.player.ore = 0
	gs.player.leaders = 1
	gs.player.workers = 1
}

PANEL_SIZE_MAX: Vec2 = {120, 400}
SPACER :: 16

@export
game_step :: proc () {
	// root := sized(RES, row(
	// 	sized(PANEL_SIZE_MAX, column(
	// 		row( label("Hello"), label("Hello"), label("Hello") ),
	// 		row( label("ooooooooooooo"), label("123") ),
	// 		expander(),
	// 		label("Hello"),
	// 	)), // column
	// 	sized_by_parent(rect()),
	// )) // row
	// ui_layout(root)
	// if true do return

	gs.state_changed_this_frame = false
	gs.events = {}

	if sugar.on_button_press(.Y) || sugar.on_key_press(.E) {
		gs.zoom = !gs.zoom
	}

	//////////////////////////////////////////////////////////////////////////////
	// Arrow movement.
	//////////////////////////////////////////////////////////////////////////////
	switch gs.state {
	case .Selecting_Tile:
		// TODO: Wraps to 0 and TILES-1 on vertical movement.
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			gs.focused_tile = clamp(gs.focused_tile + COLUMNS, 0, TILES-1)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			gs.focused_tile = clamp(gs.focused_tile - COLUMNS, 0, TILES-1)
		}
		if sugar.on_button_press(.Left) || sugar.on_key_press(.A) {
			row := gs.focused_tile / COLUMNS 
			row_min := row * COLUMNS
			row_max := row_min + COLUMNS - 1
			gs.focused_tile = clamp(gs.focused_tile - 1, row_min, row_max)
		}
		if sugar.on_button_press(.Right) || sugar.on_key_press(.D) {
			row := gs.focused_tile / COLUMNS 
			row_min := row * COLUMNS
			row_max := row_min + COLUMNS - 1
			gs.focused_tile = clamp(gs.focused_tile + 1, row_min, row_max)
		}
	case .Panel_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.panel_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.panel_menu_state)
		}
	case .Build_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.build_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.build_menu_state)
		}
	case .Upgrade_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.upgrade_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.upgrade_menu_state)
		}
	case .Mission_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.mission_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.mission_menu_state)
		}
	} // switch

	//////////////////////////////////////////////////////////////////////////////
	// Vet actions of selected states for the UI and input.
	//////////////////////////////////////////////////////////////////////////////
	focused_tile := get_focused_tile()
	gs.has_focused_action = false
	gs.action_fully_vetted = false
	switch gs.state {
	case .Selecting_Tile:
		if gs.tile_select_mode == .Actor {
			actor := focused_tile
			gs.action_fully_vetted = vet_full_action(actor, gs.selected_action, gs.target)
			if gs.action_fully_vetted {
				set_path(actor, gs.target, .Player, gs.selected_action.cost.leaders > 0)
			}
		} else if gs.tile_select_mode == .Target {
			target := focused_tile
			gs.action_fully_vetted = vet_full_action(gs.actor, gs.selected_action, target)
			if gs.action_fully_vetted {
				set_path(gs.actor, target, .Player, gs.selected_action.cost.leaders > 0)
			}
		}
	case .Panel_Menu:
	case .Build_Menu:
		gs.has_focused_action = true
		gs.focused_action = action_for_building(gs.build_menu_state)
	case .Upgrade_Menu:
		gs.has_focused_action = true
		gs.focused_action = action_for_upgrade(gs.upgrade_menu_state)
	case .Mission_Menu:
		gs.has_focused_action = true
		gs.focused_action = action_for_mission(gs.mission_menu_state)
	} // switch

	if gs.has_focused_action {
		gs.cost_estimate = estimate_cost(gs.focused_action.cost)
	}

	//////////////////////////////////////////////////////////////////////////////
	// Try to select actions
	//////////////////////////////////////////////////////////////////////////////
	switch gs.state {
	case .Selecting_Tile:
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			switch gs.tile_select_mode {
			case .First_Tile:
				deselect_action()
				if focused_tile == nil do break

				if focused_tile.resource == .Barracks\
				&& focused_tile.owner == .Player {
					// Given this is the first selection, infer this to be a SOURCE.
					gs.actor = focused_tile
					set_state(.Panel_Menu) // Select an action, then a target
					gs.events += {.Panel_Focused}
					gs.tile_select_mode = .Target
				} else {
					// Assume the tile was intended to be the target of an action.
					gs.target = focused_tile
					set_state(.Panel_Menu) // Select an action, then a source
					gs.events += {.Panel_Focused}
					gs.tile_select_mode = .Actor
				}
			case .Actor, .Target:
				if gs.action_fully_vetted {
					if gs.tile_select_mode == .Actor do gs.actor = focused_tile
					if gs.tile_select_mode == .Target do gs.target = focused_tile
					buy_action(gs.selected_action)
					add_new_action()
				}
			}//switch
		}

		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			switch gs.tile_select_mode {
			case .First_Tile:
				// Nothing to do.
			case .Actor, .Target:
				// Go back to the panel-menu we came from.
				switch gs.panel_menu_state {
				case .Build_Menu:     set_state(.Build_Menu)
				case .Upgrade_Menu:   set_state(.Upgrade_Menu)
				case .Mission_Menu:   set_state(.Mission_Menu)
				}
				gs.events += {.Panel_Focused}
			}
		}
	case .Panel_Menu:
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			switch gs.panel_menu_state {
			case .Build_Menu:     set_state(.Build_Menu)
			case .Upgrade_Menu:   set_state(.Upgrade_Menu)
			case .Mission_Menu:   set_state(.Mission_Menu)
			}
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			gs.events += {.Panel_Dropped_Focus}
			set_state(.Selecting_Tile)
			gs.tile_select_mode = .First_Tile
		}
	case .Build_Menu, .Upgrade_Menu, .Mission_Menu:
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			action := gs.focused_action // Need to mutate it if substituting leaders for workers.
			cost_estimate := estimate_cost(action.cost)
			switch {
			case gs.cost_estimate.can_simply_afford:
				set_selected_action(action)
				gs.cost_estimate = cost_estimate
				set_state(.Selecting_Tile) // ASSUME: tile_select_mode preconfigured
			case gs.cost_estimate.can_afford_with_subs:
				action.one_off = true // the game won't let you spend all your leaders permanently
				action.cost.workers = gs.cost_estimate.sub_worker_cost
				action.cost.leaders = gs.cost_estimate.sub_leaders_to_reimburse
				action.leaders_to_reimburse = gs.cost_estimate.sub_leaders_to_reimburse
				action.workers_to_reimburse = gs.cost_estimate.sub_workers_to_reimburse
				set_selected_action(action)
				gs.cost_estimate = cost_estimate
				set_state(.Selecting_Tile) // ASSUME: tile_select_mode preconfigured
			}
		}

		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			set_state(.Panel_Menu)
		}
	} // switch to select actions

	//////////////////////////////////////////////////////////////////////////////
	// Build Panel
	//////////////////////////////////////////////////////////////////////////////
	bg := rect()
	bg.basis.scale.xy = globals.canvas_size_px
	bg.color = bg_color

	panel := rect()
	panel.basis.scale.xy = PANEL_SIZE_MAX
	panel.color = panel_color

	//////////////////////////////////////////////////////////////////////////////
	// Build Tile Grid
	//////////////////////////////////////////////////////////////////////////////
	for i in 0..< TILES {
		basis: Transform
		basis.scale = TILE_SIZE_PX * tile_scale()
		basis.position.xy = Vec2{TILE_SIZE_PX * 8 - 2, 5}
		tile: ^Tile = &gs.tiles[i]
		is_neighbor: bool; for n in focused_tile.neighbors do if n.index == i { is_neighbor = true; break }
		tile.focused = gs.focused_tile == i
		it := tile_entity(basis, tile, loop_hash("tile", i))
		gs.tiles[i].entity = it
	}

	//////////////////////////////////////////////////////////////////////////////
	// Dispatch Actions
	//////////////////////////////////////////////////////////////////////////////
	#reverse for &action in gs.actions {
		asset := "worker.ase" if action.cost.leaders > 0 else "lil_worker.ase"
		entity := sprite(asset, hash=loop_hash("action", action.id))
		sprite_state := &entity.variant.(Sprite_State)
		sprite_state.repetitions = max(int)
		tile := action.path[action.move_path_index]
		tile_position := tile.entity.position.xy + tile.entity.basis.position.xy
		entity.position.xy = tile_position - entity.basis.scale.xy/2
		switch action.state {
		case .Will_Leave_Home:
			entity.flags -= {.Hidden}
			action.state = .Moving_To_Target
		case .Moving_To_Target:
			action.move_time += globals.tick
			if action.move_time > action.move_tiles_per_second {
				action.move_time -= action.move_tiles_per_second
				action.move_path_index += 1
			}
			if action.target == action.path[action.move_path_index] {
				action.state = .Working
				// maybe set an animation
			}
		case .Working:
			action.work_time += globals.tick
			if action_completion_pct(action) >= 1.0 {
				action.state = .Moving_Home
				if menu_option, ok := action.build_result.(Build_Menu); ok {
					new_type: Tile_Type
					switch menu_option {
					case .Build_Barracks: new_type = Tile_Type.Barracks
					case .Build_Workshop: new_type = Tile_Type.Workshop
					case .Build_Path:     new_type = Tile_Type.Path
					}
					action.target.resource = new_type
				}
			} // if complete
		case .Fighting: unimplemented() // TODO
		case .Moving_Home:
			action.move_time += globals.tick
			if action.move_time > action.move_tiles_per_second {
				action.move_time -= action.move_tiles_per_second
				action.move_path_index -= 1
			}
			if action.actor == action.path[action.move_path_index] {
				entity.flags += {.Hidden}
				action.state = .Will_Get_Home
			}
		case .Will_Get_Home:
			if mission, ok := action.mission.?; ok {
				#partial switch mission {
				case .Laner_Gather_Resource:
					#partial switch action.target.resource {
					case .Ore:   gs.player.ore += 1
					case .Water: gs.player.water += 1
					case .Food:  gs.player.food += 1
					}
				}
			}
			if action.one_off {
				// Substitution & reimbursement only happens on one-off actions.
				gs.player.leaders += action.leaders_to_reimburse
				gs.player.workers += action.workers_to_reimburse
				unordered_remove_action(&action)
			} else {
				action.work_time = 0
				action.state = .Will_Leave_Home
			}
		} // switch state
	} // #reverse for action

	//////////////////////////////////////////////////////////////////////////////
	// Build Panel Menu
	//////////////////////////////////////////////////////////////////////////////
	menu := make([dynamic]^Entity, context.temp_allocator)
	icon_bg :: proc (icon: ^Entity, hash := #caller_location) -> ^Entity {
		icon_bg := rect(hash=hash)
		icon_bg.basis = icon.basis
		icon_bg.color.a = 0.1
		icon_bg.position.xy = icon.position.xy
		icon_bg.position.z = icon.position.z - 1
		return icon
	}
	resource_panel :=
		pad_all(column(
			(row(
				icon_bg(image("leader16.ase")),
				label("LEADER:"),
				expander(),
				text(fmt.tprintf("%03d", gs.player.leaders), .bold_pixel),
				wh_sizers=SIZERS_FLEX_ROW
			)),
			// pad_all(row(
			// 	label("X"),label("X"),expander(),label("X"),
			// 	wh_sizers=SIZERS_FLEX_ROW
			// ), 0),
			// pad_all(row(
			// 	label("WORKER"),
			// 	label("X"),
			// 	expander(),
			// 	label("001"),
			// 	wh_sizers=SIZERS_FLEX_ROW
			// ), 0),
			// pad_all(row(
			// 	label("X"),label("X"),expander(),label("X"),
			// 	wh_sizers=SIZERS_FLEX_ROW
			// ), 0),
			pad_all(row(
				icon_bg(image("hammer16.ase")),
				label("WORKER:"),
				expander(),
				text(fmt.tprintf("%03d", gs.player.workers), .bold_pixel),
				wh_sizers=SIZERS_FLEX_ROW
			), 0),
			(row(
				icon_bg(image("ore16.ase")),
				label("ORE:"),
				expander(),
				text(fmt.tprintf("%03d", gs.player.ore), .bold_pixel),
				wh_sizers=SIZERS_FLEX_ROW
			)),
			(row(
				icon_bg(image("food16.ase")),
				label("FOOD:"),
				expander(),
				text(fmt.tprintf("%03d", gs.player.food), .bold_pixel),
				wh_sizers=SIZERS_FLEX_ROW
			)),
			pad_all(row(
				icon_bg(image("water16.ase")),
				label("WATER:"),
				expander(),
				text(fmt.tprintf("%03d", gs.player.water), .bold_pixel),
				wh_sizers=SIZERS_FLEX_ROW
			), 0),
			wh_sizers=SIZERS_FLEX_WIDE_COLUMN
		), 4) // column

	h_separator :: proc(hash:=#caller_location)->^Entity{
		separator := rect(hash=hash)
		separator.basis.scale.x = PANEL_SIZE_MAX.x
		separator.basis.scale.y = 4
		separator.color = bg_color
		return separator
	}
	v_separator :: proc(height: f32, hash:=#caller_location)->^Entity{
		separator := rect(hash=hash)
		separator.basis.scale.x = 4
		separator.basis.scale.y = height
		separator.color = bg_color
		return separator
	}
	append(&menu,
		resource_panel,
		// spacer(8),
		h_separator(),
	)
	switch gs.state {
	case .Selecting_Tile: append(&menu, label("  ACTIONS:"))
	case .Panel_Menu:     append(&menu, label("  ACTIONS:"))
	case .Build_Menu:     append(&menu, label("< BUILD:"))
	case .Upgrade_Menu:   append(&menu, label("< UPGRADE:"))
	case .Mission_Menu:   append(&menu, label("< MISSION:"))
	}
	append(&menu,spacer(4))
	menu_start: int = len(menu)
	if contains([]States{.Selecting_Tile, .Panel_Menu}, gs.state) {
		append(&menu, 
			text("  Mission", .bold_pixel),
			text("  Build", .bold_pixel),
			text("  Upgrade", .bold_pixel),
			spacer(8),
		)
	}
	switch gs.state {
	case .Selecting_Tile:
	case .Panel_Menu:
	case .Build_Menu:
		append(&menu,
			build_menu_list_item("  Barracks", .Build_Barracks),
			build_menu_list_item("  Workshop", .Build_Workshop),
			build_menu_list_item("  Path", .Build_Path),
		)
	case .Upgrade_Menu:
		append(&menu,
			upgrade_menu_list_item("  Unit Speed", .Unit_Speed),
			upgrade_menu_list_item("  Unit Health", .Unit_Health),
			upgrade_menu_list_item("  Unit Power", .Unit_Power),
			upgrade_menu_list_item("  Unit Capacity", .Unit_Capacity),
		)
	case .Mission_Menu:
		append(&menu,
			mission_menu_list_item("  Gather Once", .Leader_Gather_Resource),
			mission_menu_list_item("  Gather", .Laner_Gather_Resource),
			mission_menu_list_item("  Conquer", .Laner_Fight),
			mission_menu_list_item("  Spy on Tile", .Spy_Tile),
			mission_menu_list_item("  Sabotage Tile", .Spy_Sabotage_Tile),
		)
	} // switch

	cost_leaders: int
	cost_workers: int
	cost_ore: int
	cost_food: int
	cost_water: int
	gain_leaders: int
	gain_workers: int
	gain_ore: int
	gain_food: int
	gain_water: int
	// make a list of losses and gains.
	action: ^Action
	if gs.has_focused_action do action = &gs.focused_action
	if gs.has_selected_action do action = &gs.selected_action
	if action != nil {
		if valid := vet_action(action^); valid {
			cost_leaders = action.cost.leaders
			cost_workers = action.cost.workers
			cost_ore     = action.cost.ore
			cost_food    = action.cost.food
			cost_water   = action.cost.water

			if mission, ok := action.mission.?; ok {
				#partial switch mission {
				case .Laner_Gather_Resource, .Leader_Gather_Resource:
					if action.target != nil {
						#partial switch action.target.resource {
						case .Ore:   gain_ore += 1
						case .Water: gain_water += 1
						case .Food:  gain_food += 1
						}
					}
				} // switch mission
			} // if mission
		} // if focused

		cost_icon :: proc (
			id: int,
			icon_name: string,
			cost: int,
			hash := #caller_location
		) -> ^Entity {
			_color: Color4
			switch {
			case cost < 0:  _color = red
			case cost == 0: _color = color("fffa")
			case cost > 0:  _color = green
			}
			icon := image(icon_name, loop_hash("cost_icon", id))
			elem := (row(
				icon, label(fmt.tprintf("%+d", cost), _color, loop_hash("cost_label", id)),
				hash=loop_hash("cost_row", id)
			))
			icon_bg(icon, hash)

			return elem
		}

		lose_column := make([dynamic]^Entity, context.temp_allocator)
		append(&lose_column,
			label("LOSE",red),
			spacer(8),
		)
		if cost_leaders > 0 do append(&lose_column, cost_icon(1, "leader16.ase", -1*cost_leaders))
		if cost_workers > 0 do append(&lose_column, cost_icon(2, "hammer16.ase", -1*cost_workers))
		if cost_ore     > 0 do append(&lose_column, cost_icon(3, "ore16.ase",    -1*cost_ore))
		if cost_food    > 0 do append(&lose_column, cost_icon(4, "food16.ase",   -1*cost_food))
		if cost_water   > 0 do append(&lose_column, cost_icon(5, "water16.ase",  -1*cost_water))
		append(&lose_column, spacer(8))

		gain_column := make([dynamic]^Entity, context.temp_allocator)
		append(&gain_column,
			label("GAIN", green),
			spacer(8),
			expander()
		)
		if gain_leaders > 0 do append(&gain_column, label(fmt.tprintf("%+d", gain_leaders), green))
		if gain_workers > 0 do append(&gain_column, label(fmt.tprintf("%+d", gain_workers), green))
		if gain_ore     > 0 do append(&gain_column, label(fmt.tprintf("%+d", gain_ore), green))
		if gain_food    > 0 do append(&gain_column, label(fmt.tprintf("%+d", gain_food), green))
		if gain_water   > 0 do append(&gain_column, label(fmt.tprintf("%+d", gain_water), green))
		append(&gain_column, spacer(8))

		v_sep := v_separator(12)
		v_sep.ui.sizer.y = Sizer.Flexed_By_Parent
		lose_gain_panel := (row(
			spacer(12),
			(column(..lose_column[:])),
			spacer(14),
			v_sep,
			spacer(10),
			(column(..gain_column[:], wh_sizers=SIZERS_FLEX_COLUMN)),
		))

		append(&menu,
			spacer(8),
			h_separator(),
			lose_gain_panel,
			h_separator(),
			spacer(8),
		)
	} // has focused action
	append(&menu,
		expander(),
		h_separator(),
		spacer(4),
		label("ON THIS TILE:"),
		text(fmt.tprintf("  %v", focused_tile.resource), .bold_pixel),
			spacer(8),
	)

	panel_ctx := ui_context(PANEL_SIZE_MAX)
	col := column(..menu[:])
	col.basis.scale = panel_ctx.basis.scale

	ui_layout(PANEL_SIZE_MAX, col)

	////////////////////////////////////////////////////////////////////////////////////////
	// Build Panel Menu Highlight
	////////////////////////////////////////////////////////////////////////////////////////
	menu_offset: int
	switch gs.state {
	case .Selecting_Tile:
	case .Panel_Menu:   menu_offset = cast(int) gs.panel_menu_state
	case .Build_Menu:   menu_offset = cast(int) gs.build_menu_state
	case .Upgrade_Menu: menu_offset = cast(int) gs.upgrade_menu_state
	case .Mission_Menu: menu_offset = cast(int) gs.mission_menu_state
	}
	hovered_text := menu[menu_start + menu_offset]
	menu_highlight := rect()
	@static is_animating := false
	menu_highlight_size := vec3({PANEL_SIZE_MAX.x, 16}, 1)
	menu_highlight.transform.scale = menu_highlight_size
	menu_highlight.transform.position.xy = hovered_text.position.xy - { 0, 4}
	// If the two objects have different bases, can't interpolate and store in xform.
	// The object will appear to come from the wrong location.

	menu_highlight.color = color("ff6")
	sinbh :: proc (theta: f32) -> f32 { return ((sin(theta) + 1) / 4) + 0.2 }
	@static time: f32; time += globals.tick
	menu_highlight.color.a = sinbh(2*time) * 0.5

	if gs.has_focused_action {
		if valid := vet_action(gs.focused_action); valid && gs.has_focused_action {
			menu_highlight.color = color("f223")
			switch {
			case !valid: break
			case gs.cost_estimate.can_simply_afford: // no change to UI
			case gs.cost_estimate.can_afford_with_subs:
				menu_highlight.color = color("fff4")
				top_hat := image("leader16.ase")
				top_hat.flags += {.Skip_Interpolation}
				// top_hat.position.xy = hovered_text.position.xy - {5, 4}
			}
		}
	}

	Transform_Lerp_Data :: struct { sink: ^Transform, start: Transform, end: Transform }
	switch {
	case .Panel_Focused in gs.events:
		menu_highlight.flags += {.Skip_Next_Interpolation}
		lerp_data: Transform_Lerp_Data = {
			sink  = &menu_highlight.transform,
			start = transform_add(focused_tile.entity.basis, focused_tile.entity.transform),
			end   = { menu_highlight.position, {}, menu_highlight_size },
		}
		effect := timed_effect(lerp_data, 0.1, proc (data: ^Transform_Lerp_Data, percent: f32) {
			data.sink^ = lerp_transform(data.start, data.end, percent)
		})
	case .Panel_Dropped_Focus in gs.events:
		menu_highlight.flags += {.Skip_Next_Interpolation}
		lerp_data: Transform_Lerp_Data = {
			sink  = &menu_highlight.transform,
			start = { menu_highlight.position, {}, menu_highlight_size },
			end   = transform_add(focused_tile.entity.basis, focused_tile.entity.transform),
		}
		effect := timed_effect(lerp_data, 0.1, proc (data: ^Transform_Lerp_Data, percent: f32) {
			data.sink^ = lerp_transform(data.start, data.end, percent)
			is_animating = true
		})
		effect.timeout = proc (data: ^Transform_Lerp_Data) {
			is_animating = false
		}
	} // switch

	if gs.state == .Selecting_Tile && !is_animating {
		menu_highlight.color.a = 0	
	}
	////////////////////////////////////////////////////////////////////////////////////////
	// ...
	////////////////////////////////////////////////////////////////////////////////////////
} // game step

////////////////////////////////////////////////////////////////////////////////
// UI Components
////////////////////////////////////////////////////////////////////////////////

tile_entity :: proc (
	basis: Transform,
	tile: ^Tile,
	hash: Hash = #caller_location,
) -> (^Entity, bool) #optional_ok {
	it, is_new := rect(hash=hash)
	it.basis = basis
	it.position.xy = array_cast(tile.column_row, f32) * (TILE_GAP + basis.scale.x)
	if tile.resource == .Ore {
		img := image("ore16.ase", loop_hash("ore", tile.index))
		transform(img, it^)
		it.color.rgb = resource_colors[.Grass]
	} else if tile.resource == .Food {
		img := image("food16.ase", loop_hash("food", tile.index))
		transform(img, it^)
		it.color.rgb = resource_colors[.Grass]
	} else if tile.resource == .Water {
		shape := circle(loop_hash("water", tile.index))
		shape.basis = basis
		shape.position.xy = it.position.xy
		shape.color.rgb = resource_colors[.Water]
		it.color.rgb = resource_colors[.Grass]
	} else if tile.resource == .Grass {
		it.color.rgb = resource_colors[tile.resource]
	} else if tile.resource == .Barracks {
		it.color.rgb = resource_colors[tile.resource]
	} else if tile.resource == .Path {
		it.color.rgb = resource_colors[tile.resource]
	} else {
		log.infof("undecorated resource: %v", tile.resource)
	}


	// if tile._search_distance > 0 && tile._search_distance < UNKNOWN_DISTANCE {
	// 	dist_label := text(fmt.tprintf("%.0f", 0.1*tile._search_distance), .bold_pixel, hash=loop_hash("search_dbg", tile.index))
	// 	dist_label.basis = basis
	// 	dist_label.basis.scale.xy = 12
	// 	dist_label.position.xy = it.position.xy
	// 	dist_label.position.x -= 7
	// 	dist_label.position.z += 100
	// }

	in_path: bool
	if gs.has_selected_action {
		for t in gs.selected_action.path do if tile.index == t.index { in_path = true; break }
	}
	if in_path {
		motion :: proc (theta: f32) -> f32 { return clamp(((sin(theta) + 1) / 2) + 0.2, 0.4, 0.7) }
		focus_alpha := motion(4*globals.uptime)
		// it.color.rgb += 0.5
		shape, is_new := circle(loop_hash("path_dots", tile.index))
		shape.basis = basis
		shape.basis.scale.xy = basis.scale.xy - 8
		shape.basis.position.xy += basis.scale.xy/2
		shape.position.xy = it.position.xy
		shape.position.z = next_z() + 1 // overtop the focus highlight
		shape.color = color("000")
		shape.color.a = focus_alpha
	}

	// TODO: Only do this if it's about building.
	// if tile.action.happening {
	// 	pct := action_completion_pct(tile.action)
	// 	it.basis.scale *= clamp(pct, 0, 1)
	// }

	if tile.focused {
		motion :: proc (theta: f32) -> f32 { return clamp(((sin(theta) + 1) / 2) + 0.2, 0.4, 0.7) }
		focus_alpha := motion(4*globals.uptime)
		tile_highlight := rect(hash=loop_hash("focus", tile.index))
		tile_highlight.basis = it.basis
		tile_highlight.position.xy = it.position.xy
		tile_highlight.color = color("af6")
		tile_highlight.color.a = focus_alpha
	}
	return it, is_new
}

tile_scale :: proc () -> f32 { return 2.0 if gs.zoom else 1.0 }

build_menu_list_item :: proc (
	label: string,
	value: Build_Menu,
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))
	_label.color = color("#aaa")

	estimate: Cost_Estimate
	switch value {
	case .Build_Barracks: estimate = estimate_cost(barracks_cost)
	case .Build_Workshop: estimate = estimate_cost(workshop_cost)
	case .Build_Path:     estimate = estimate_cost(path_cost)
	}
	switch {
	case estimate.can_simply_afford:
		_label.color = color("#fff")
	case estimate.can_afford_with_subs:
		_label.color = color("#fff7")
	case:
		_label.color = color("#fff2")
	}
	return _label
}

upgrade_menu_list_item :: proc (
	label: string,
	value: Upgrade_Menu,
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))
	_label.color = color("#aaa")

	estimate: Cost_Estimate
	switch value {
	case .Unit_Speed:    estimate = estimate_cost(unit_speed_cost)
	case .Unit_Health:   estimate = estimate_cost(unit_health_cost)
	case .Unit_Power:    estimate = estimate_cost(unit_power_cost)
	case .Unit_Capacity: estimate = estimate_cost(unit_capacity_cost)
	}
	switch {
	case estimate.can_simply_afford:
		_label.color = color("#fff")
	case estimate.can_afford_with_subs:
		_label.color = color("#fff7")
	case:
		_label.color = color("#fff2")
	}
	return _label
}

mission_menu_list_item :: proc (
	label: string,
	value: Mission_Menu,
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))

	estimate: Cost_Estimate
	switch value {
	case .Leader_Gather_Resource: estimate = estimate_cost(leader_gather_cost)
	case .Laner_Gather_Resource: estimate = estimate_cost(laner_gather_cost)
	case .Laner_Fight:           estimate = estimate_cost(fight_cost)
	case .Spy_Tile:              estimate = estimate_cost(spy_cost)
	case .Spy_Sabotage_Tile:     estimate = estimate_cost(sabotage_cost)
	}
	switch {
	case estimate.can_simply_afford:
		_label.color = color("#fff")
	case estimate.can_afford_with_subs:
		_label.color = color("#fff7")
	case:
		_label.color = color("#fff2")
	}
	return _label
}

label :: proc (
	label: string,
	_color: Color4 = {},
	hash: Hash = #caller_location
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=hash)
	if _color == {} {
		_label.color = color("aaa")
	} else {
		_label.color = _color
	}
	return _label
}