package main

import "base:runtime"
import "core:fmt"
import "core:time"
import "core:log"
import "core:sys/windows"
import "core:math/rand"
import "sugar"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

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
// Brainless Minigame Jam: Simpler Times
////////////////////////////////////////////////////////////////////////////////
// RG35SP_RES: Vec2 = {640, 480}
// STEAM_DECK_RES: Vec2 = {1280, 800}
TILE_GAP :: 1
ROWS :: 23
COLUMNS :: 30
TILES :: ROWS * COLUMNS
TILE_SIZE_PX :: 16

gs: ^Game_State

Game_State :: struct {
	state_changed_this_frame: bool,
	prev_state:     States,
	state:          States,
	panel_menu_state:  Panel_Menu_State,
	//
	build_menu_state:   Build_Menu,
	upgrade_menu_state: Upgrade_Menu,
	mission_menu_state: Mission_Menu,
	//
	focused_tile: int,
	player: Resources,
	enemy:  Resources,
	tiles:  [TILES]Tile,
	zoom:   bool,
}

States :: enum {
	Overworld,
	Panel_Menu,
	Build_Menu,
	Upgrade_Menu,
	Mission_Menu,
}

Panel_Menu_State :: enum {
	Build_Menu,
	Upgrade_Menu,
	Mission_Menu,
}

Build_Menu :: enum {
	Build_Barracks,
	Build_Workshop,
	Build_Path,
	Build_Aqueduct,
	Build_Train,
}
Upgrade_Menu :: enum {
	Unit_Speed,
	Unit_Health,
	Unit_Power,
	Unit_Capacity,
}
Mission_Menu :: enum {
	Laner_Gather_Resource,
	Laner_Fight, // Retreats at low health. If speed too low, can die.
	Spy_Tile,
	Spy_Sabotage_Tile,
}

// The last user to work the improvement.
Tile_Owner :: enum {
	None,
	Player,
	Enemy,
}

Tile :: struct {
	index:    int,
	resource: Tile_Type,
	owner:    Tile_Owner, // Determines who is doing the project.
	project:  Project,
	entity:   ^Entity,
}

Tile_Type :: enum {
	Grass,
	// Resources
	Ore,         // Build roads, workshop, markets, barracks
	Food, Water, // Modulates spawn rate
	// Buildings
	Workshop,    // improve/unlock units/resources
	Market,      // strengthen population
	Barracks,    // raise population
	Path,        // Allows non-scout units to move fast.
	// Enhanced water source. Maybe auto resource.
	Canal,
}

Project :: struct {
	start_time:    time.Tick,
	cost:          Resources,
	new_tile_type: Tile_Type,
	happening:     bool,
	finished:      bool,
}

Resources :: struct #all_or_none {
	ore:     int,
	food:    int,
	water:   int,
	workers: int,
	leaders: int, // Only exists cause you can soft-lock otherwise (use all workers)
	time:    time.Duration, // time dwelling on-location (not traversal)
}

project_completion_pct :: proc (it: Project) -> f32 {
	return f32(time.tick_diff(it.start_time, time.tick_now())) / f32(it.cost.time)
}

Affordability :: enum {
	No, Simple, With_Subs
}
get_affordability :: proc (cost: Resources) -> Affordability {
	if can_simply_afford(cost) {
		return .Simple
	} else if ok, subs := can_afford_subbing_workers_with_leaders(cost); ok {
		return .With_Subs
	} else {
		return .No
	}
}

can_simply_afford :: proc (cost: Resources) -> bool {
	return gs.player.ore >= cost.ore\
	&&     gs.player.food >= cost.food\
	&&     gs.player.water >= cost.water\
	&&     gs.player.workers >= cost.workers
}

can_afford_subbing_workers_with_leaders :: proc (
	cost: Resources
) -> (ok: bool, leaders_needed: int) {
	leaders_needed = cost.workers - gs.player.workers

	ok = gs.player.ore >= cost.ore\
	&&   gs.player.food >= cost.food\
	&&   gs.player.water >= cost.water\
	&&   gs.player.leaders >= leaders_needed
	return
}

try_start_project :: proc (tile: ^Tile, project: Project) -> (started: bool) {
	if tile == nil\
	|| tile.project.happening {
	 return false 
	}

	if can_simply_afford(project.cost) {
		simply_buy_project(project)
	} else if ok, subs := can_afford_subbing_workers_with_leaders(project.cost); ok {
		buy_project_subbing_workers_with_leaders(project, subs)
	} else {
		return false
	}
	start_project(tile, project)
	return true
}

simply_buy_project :: proc (project: Project) {
	gs.player.ore -= project.cost.ore
	gs.player.food -= project.cost.food
	gs.player.water -= project.cost.water
	gs.player.workers -= project.cost.workers
	gs.player.leaders -= project.cost.leaders
}

buy_project_subbing_workers_with_leaders :: proc (project: Project, leaders_subbing: int) {
	gs.player.ore -= project.cost.ore
	gs.player.food -= project.cost.food
	gs.player.water -= project.cost.water
	gs.player.workers -= project.cost.workers - leaders_subbing
	gs.player.leaders -= leaders_subbing
}

start_project :: proc (tile: ^Tile, project: Project) {
	ensure(tile.owner != .Enemy && !tile.project.happening)
	tile.project = project
	tile.project.happening = true
	tile.owner = .Player
	// INTENT: When a project starts through the menu, put them on the map
	//         such that it's easy to pick a new tile for a project.
	set_state(States.Overworld)
}

finish_project :: proc (tile: ^Tile) {
	ensure(tile.owner == .Player && !tile.project.finished)
	tile.project.happening = false
	tile.project.finished = true
	tile.resource = tile.project.new_tile_type
	gs.player.leaders += 1
}

import gl "angle"
game_init :: proc () {
	gl.BindSampler(cast(u32) Texture_Unit.Framebuffer_Texture, globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Texture,             globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Font,                globals.ren.nearest_sampler)
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

	for i in 0..<TILES {
		tile: ^Tile = &gs.tiles[i]
		tile.index = i
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
	gs.player.workers = 0
	gs.player.food = 0
	gs.player.water = 0
	gs.player.ore = 0
	gs.player.leaders = 1
}

PANEL_SIZE: Vec2 = {120, 400}
SPACER :: 16

set_state :: proc (new_state: States) {
	if new_state != gs.state {
		gs.state_changed_this_frame = true
		gs.prev_state = gs.state
		gs.state = new_state
	}
}

state_changed :: proc () -> bool {
	if !gs.state_changed_this_frame do return false
	return gs.prev_state != gs.state
}

state_changed_from_to :: proc (prev, current: States) -> bool {
	if !gs.state_changed_this_frame do return false
	return prev == gs.prev_state && current == gs.state
}

get_focused_tile :: proc () -> ^Tile {
	return &gs.tiles[gs.focused_tile]
}

@export
game_step :: proc () {
	gs.state_changed_this_frame = false
	switch gs.state {
	case .Overworld:
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
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			set_state(.Panel_Menu)
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			// On tiles, nothing to go back to.
		}
	//////////////////////////////////////////////////////////////////////////////
	case .Panel_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.panel_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.panel_menu_state)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			switch gs.panel_menu_state {
			case .Build_Menu:     set_state(.Build_Menu)
			case .Upgrade_Menu:   set_state(.Upgrade_Menu)
			case .Mission_Menu:   set_state(.Mission_Menu)
			}
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			set_state(.Overworld)
		}
	//////////////////////////////////////////////////////////////////////////////
	case .Build_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.build_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.build_menu_state)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			switch gs.build_menu_state {
			case .Build_Barracks:
			case .Build_Workshop:
			case .Build_Path:
				try_start_project(get_focused_tile(), {
					time.tick_now(),
					path_cost,
					.Path,
					false,
					false,
				})
			case .Build_Aqueduct:
			case .Build_Train:
			}
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			set_state(.Panel_Menu)
		}
	//////////////////////////////////////////////////////////////////////////////
	case .Upgrade_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.upgrade_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.upgrade_menu_state)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			switch gs.upgrade_menu_state {
			case .Unit_Speed:
			case .Unit_Health:
			case .Unit_Power:
			case .Unit_Capacity:
			}
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			set_state(.Panel_Menu)
		}
	//////////////////////////////////////////////////////////////////////////////
	case .Mission_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.mission_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.mission_menu_state)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			switch gs.mission_menu_state {
			case .Laner_Gather_Resource:
				// Check the tile:
				// If the tile isn't reachable by path, send a leader.
				// If the tile _is_ reachable, send workers.
			case .Laner_Fight: // Retreats at low health. If speed too low, can die.
			case .Spy_Tile:
			case .Spy_Sabotage_Tile:
			}
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			set_state(.Panel_Menu)
		}
	} // switch //////////////////////////////////////////////////////////////////

	if sugar.on_button_press(.Y) || sugar.on_key_press(.E) {
		gs.zoom = !gs.zoom
	}

	bg := rect()
	bg.basis.scale.xy = globals.canvas_size_px
	uncenter_rect(bg)
	bg.color = color("#234")

	panel := rect()
	panel.basis.scale.xy = PANEL_SIZE
	uncenter_rect(panel)
	panel.color = color("#0126")

	for i in 0..< TILES {
		basis: Transform
		basis.scale = TILE_SIZE_PX * tile_scale()
		basis.position.xy = basis.scale.x/2 + Vec2{TILE_SIZE_PX * 8 - 2, 5}
		tile: ^Tile = &gs.tiles[i]
		if tile.project.happening {
			if project_completion_pct(tile.project) >= 1.0 {
				finish_project(tile)
			}
		}
		it := tile_entity(basis, tile, loop_hash("tile", i))
		gs.tiles[i].entity = it
	}

	focused_tile := get_focused_tile()

	tile_highlight := rect()
	tile_highlight.basis = focused_tile.entity.basis
	tile_highlight.position.xy = focused_tile.entity.position.xy
	tile_highlight.position.z += 100 // KILL
	// sin01 :: proc (theta: f32) -> f32 { return (sin(theta) + 1) / 2 }
	// sinq2q :: proc (theta: f32) -> f32 { return ((sin(theta) + 1) / 4) + 0.25 }
	sinbh :: proc (theta: f32) -> f32 { return ((sin(theta) + 1) / 4) + 0.2 }
	@static time: f32; time += globals.tick
	tile_highlight.color = color("ff6")
	tile_highlight.color.a = sinbh(2*time)

	menu := make([dynamic]^Entity, context.temp_allocator)
	append(&menu, 
		pad_box(16),
		section_list_item("ORE:", fmt.tprintf("%d", gs.player.ore)),
		section_list_item("FOOD:", fmt.tprintf("%d", gs.player.food)),
		section_list_item("WATER:", fmt.tprintf("%d", gs.player.water)),
		section_list_item("WORKER:", fmt.tprintf("%d", gs.player.workers)),
		pad_box(16),
		section_list_item("THIS TILE:", fmt.tprintf("%v", focused_tile.resource)),
		pad_box(16),
	)
	switch gs.state {
	case .Overworld:    append(&menu, text("  ACTIONS:", .bold_pixel))
	case .Panel_Menu:   append(&menu, text("  ACTIONS:", .bold_pixel))
	case .Build_Menu:   append(&menu, text("< BUILD:", .bold_pixel))
	case .Upgrade_Menu: append(&menu, text("< UPGRADE:", .bold_pixel))
	case .Mission_Menu: append(&menu, text("< MISSION:", .bold_pixel))
	}
	menu_start: int = len(menu)
	if contains([]States{.Overworld, .Panel_Menu}, gs.state) {
		append(&menu, 
			text("  Build", .bold_pixel),
			text("  Upgrade", .bold_pixel),
			text("  Mission", .bold_pixel),
		)
	}
	switch gs.state {
	case .Overworld:
	//////////////////////////////////////////////////////////////////////////////
	case .Panel_Menu:
	//////////////////////////////////////////////////////////////////////////////
	case .Build_Menu:
		append(&menu,
			build_menu_list_item("  Barracks", .Build_Barracks),
			build_menu_list_item("  Workshop", .Build_Workshop),
			build_menu_list_item("  Path", .Build_Path),
			build_menu_list_item("  Aqueduct", .Build_Aqueduct),
			build_menu_list_item("  Train", .Build_Train),
		)
	//////////////////////////////////////////////////////////////////////////////
	case .Upgrade_Menu:
		append(&menu,
			upgrade_menu_list_item("  Unit Speed", .Unit_Speed),
			upgrade_menu_list_item("  Unit Health", .Unit_Health),
			upgrade_menu_list_item("  Unit Power", .Unit_Power),
			upgrade_menu_list_item("  Unit Capacity", .Unit_Capacity),
		)
	//////////////////////////////////////////////////////////////////////////////
	case .Mission_Menu:
		append(&menu,
			mission_menu_list_item("  Gather", .Laner_Gather_Resource),
			mission_menu_list_item("  Conquer", .Laner_Fight),
			mission_menu_list_item("  Spy on Tile", .Spy_Tile),
			mission_menu_list_item("  Sabotage Tile", .Spy_Sabotage_Tile),
		)
	} // switch //////////////////////////////////////////////////////////////////

	panel_list := column(..menu[:])
	panel_list_size := measure_entity(panel_list)
	height_to_pin_atop := PANEL_SIZE.y - panel_list_size.y
	col := ui_element(
		panel_list,
		position = Vec2{6, height_to_pin_atop},
	)

	// lerp a highlighter from the tile to the menu
	menu_highlight := rect()
	// Transform_Lerp_Data :: struct { sink: ^Transform, start: Transform, end: Transform }
	// if state_changed_from_to(.Overworld, .Panel_Menu) {
	// 	lerp_data: Transform_Lerp_Data = {
	// 		sink  = &menu_highlight.transform,
	// 		start = transform_combine(tile_highlight.basis, tile_highlight.transform),
	// 		end   = { {0,0,0}, {}, {PANEL_SIZE.x,44,0}},
	// 	}
	// 	lerp_data.end.position.x = lerp_data.end.scale.x / 2 + 6
	// 	timed_effect(lerp_data, 0.2, proc (data: ^Transform_Lerp_Data, percent: f32) {
	// 		data.sink^ = lerp_transform(data.start, data.end, percent)
	// 		// data.sink.position.z = next_z()
	// 	})
	// }
	uncenter_rect(menu_highlight)
	menu_highlight.basis.scale.xy = {PANEL_SIZE.x, 16}
	menu_offset: int
	switch gs.state {
	case .Overworld:
	case .Panel_Menu:   menu_offset = cast(int) gs.panel_menu_state
	case .Build_Menu:   menu_offset = cast(int) gs.build_menu_state
	case .Upgrade_Menu: menu_offset = cast(int) gs.upgrade_menu_state
	case .Mission_Menu: menu_offset = cast(int) gs.mission_menu_state
	}
	hovered_text := menu[menu_start + menu_offset]
	menu_highlight.position.y = hovered_text.position.y - 4
	menu_highlight.color = color("ff6")
	menu_highlight.color.a = sinbh(2*time) * 0.5

	if hovered_cost, hovered := hovered_action_cost(); hovered {
		if can_simply_afford(hovered_cost) {
			// no change
		} else if ok, subs := can_afford_subbing_workers_with_leaders(hovered_cost); ok {
			menu_highlight.color = color("fff4")
			tophat:=image("leader16.ase")
			tophat.flags += {.Skip_Interpolation}
			tophat.position.xy = hovered_text.position.xy - {5, 4}
		} else {
			menu_highlight.color = color("f223")
		}
	}
	if gs.state == .Overworld {
		menu_highlight.color.a = 0	
	}
} // game step

hovered_action_cost :: proc () -> (cost: Resources, action_hovered: bool ) {
	switch gs.state {
	case .Overworld: fallthrough
	case .Panel_Menu: return {}, false
	case .Build_Menu:
		switch gs.build_menu_state {
		case .Build_Barracks: cost = barracks_cost; action_hovered = true
		case .Build_Workshop: cost = workshop_cost; action_hovered = true
		case .Build_Path:     cost = path_cost;     action_hovered = true
		case .Build_Aqueduct: cost = aqueduct_cost; action_hovered = true
		case .Build_Train:    cost = train_cost;    action_hovered = true
		}
	case .Upgrade_Menu:
		switch gs.upgrade_menu_state {
		case .Unit_Speed:    cost = unit_speed_cost; action_hovered = true
		case .Unit_Health:   cost = unit_health_cost; action_hovered = true
		case .Unit_Power:    cost = unit_power_cost; action_hovered = true
		case .Unit_Capacity: cost = unit_capacity_cost; action_hovered = true
		}
	case .Mission_Menu:
		switch gs.mission_menu_state {
		case .Laner_Gather_Resource: cost = gather_cost; action_hovered = true
		case .Laner_Fight:           cost = fight_cost; action_hovered = true
		case .Spy_Tile:              cost = spy_cost; action_hovered = true
		case .Spy_Sabotage_Tile:     cost = sabotage_cost; action_hovered = true
		}
	}
	return
}

////////////////////////////////////////////////////////////////////////////////
// Build Costs
////////////////////////////////////////////////////////////////////////////////

barracks_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond
}
workshop_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond
}
// Gathering cost is 1 worker + distance / speed
path_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond
}
aqueduct_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond
}
train_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond
}

////////////////////////////////////////////////////////////////////////////////
// Upgrade Costs
////////////////////////////////////////////////////////////////////////////////
unit_speed_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}
unit_health_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}
unit_power_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}
unit_capacity_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}

////////////////////////////////////////////////////////////////////////////////
// Mission Costs
////////////////////////////////////////////////////////////////////////////////
gather_cost :: Resources {
	ore     = 0,
	food    = 0,
	water   = 0,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}
fight_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}
spy_cost :: Resources {
	ore     = 0,
	food    = 0,
	water   = 0,
	workers = 0,
	leaders = 0,
	time = 1300 * time.Millisecond // maybe make this the duration of spying
}
sabotage_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}

menu_highlight :: proc (
	cost: Resources
) -> ^Entity {
	assert(false); return nil
}

////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////

build_menu_list_item :: proc (
	label: string,
	value: Build_Menu,
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))
	_label.color = color("#aaa")

	affordability: Affordability
	switch value {
	case .Build_Barracks: affordability = get_affordability(barracks_cost)
	case .Build_Workshop: affordability = get_affordability(workshop_cost)
	case .Build_Path:     affordability = get_affordability(path_cost)
	case .Build_Aqueduct: affordability = get_affordability(aqueduct_cost)
	case .Build_Train:    affordability = get_affordability(train_cost)
	}
	switch affordability {
	case .Simple:
		_label.color = color("#fff")
	case .With_Subs:
		_label.color = color("#fff7")
	case .No:
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

	affordability: Affordability
	switch value {
	case .Unit_Speed:    affordability = get_affordability(unit_speed_cost)
	case .Unit_Health:   affordability = get_affordability(unit_health_cost)
	case .Unit_Power:    affordability = get_affordability(unit_power_cost)
	case .Unit_Capacity: affordability = get_affordability(unit_capacity_cost)
	}
	switch affordability {
	case .Simple:
		_label.color = color("#fff")
	case .With_Subs:
		_label.color = color("#fff7")
	case .No:
		_label.color = color("#fff2")
	}
	return _label
}

mission_menu_list_item :: proc (
	label: string,
	value: Mission_Menu,
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))

	affordability: Affordability
	switch value {
	case .Laner_Gather_Resource: affordability = get_affordability(gather_cost)
	case .Laner_Fight:           affordability = get_affordability(fight_cost)
	case .Spy_Tile:              affordability = get_affordability(spy_cost)
	case .Spy_Sabotage_Tile:     affordability = get_affordability(sabotage_cost)
	}
	switch affordability {
	case .Simple:
		_label.color = color("#fff")
	case .With_Subs:
		_label.color = color("#fff7")
	case .No:
		_label.color = color("#fff2")
	}
	return _label
}

section_list_item :: proc (
	label: string,
	value: string,
	hash: Hash = #caller_location
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))
	_label.color = color("#aaa")
	_value := text(value, .bold_pixel, hash=loop_hash(label, 2))
	return ui_element(
		column(
			_label,
			_value,
			hash = loop_hash(label, 3)
		)
	)
}

tile_scale :: proc () -> f32 { return 2.0 if gs.zoom else 1.0 }
// TBD
// row_column_of_index :: proc (index: int) -> (row, column: int) {
// 	row = index % COLUMNS
// 	column = index / COLUMNS
// }

// position_of_tile_at_index :: proc () {
// 		grid: Transform
// 		grid.scale = TILE_SIZE_PX * tile_scale()
// 		grid.position.xy = grid.scale.x/2 + Vec2{TILE_SIZE_PX * 8 - 2, 5}
// 		it := tile_entity(grid, &gs.tiles[i], loop_hash("tile", i))
// 		it.position.xy = {f32(row), f32(column)} * (TILE_GAP + basis.scale.x)
// }


tile_entity :: proc (
	basis: Transform,
	tile: ^Tile,
	hash: Hash = #caller_location,
) -> (^Entity, bool) #optional_ok {
	it, is_new := rect(hash)
	it.basis = basis
	row := tile.index % COLUMNS
	column := tile.index / COLUMNS
	it.position.xy = {f32(row), f32(column)} * (TILE_GAP + basis.scale.x)
	if tile.resource == .Ore {
		img := image("ore16.ase", loop_hash("ore", tile.index))
		transform(img, it^)
	} else if tile.resource == .Food {
		img := image("food16.ase", loop_hash("food", tile.index))
		transform(img, it^)
	} else if tile.resource == .Water {
		shape := circle(loop_hash("water", tile.index))
		shape.basis = basis
		shape.position.xy = it.position.xy
		shape.color.rgb = resource_colors[.Water]
		it.color.rgb = 0
	} else if tile.resource == .Grass {
		it.color.rgb = resource_colors[tile.resource]
	} else if tile.resource == .Barracks {
		it.color.rgb = resource_colors[tile.resource]
	} else if tile.resource == .Path {
		it.color.rgb = resource_colors[tile.resource]
	} else {
		log.infof("undecorated resource: %v", tile.resource)
	}

	if tile.project.happening {
		pct := project_completion_pct(tile.project)
		it.basis.scale *= clamp(pct, 0, 1)
	}

	return it, is_new
}

resource_colors: [Tile_Type]Color3 = {
	.Grass    = {0.412, 0.651, 0.255},

	.Ore      = {0.859, 0.686, 0.235},
	.Food     = {0.761, 0.494, 0.184},
	.Water    = {0.208, 0.514, 0.749},

	.Workshop = {0.451, 0.224, 0.176},
	.Market   = {0.580, 0.329, 0.239},
	.Barracks = {0.769, 0.561, 0.376},

	.Path     = {0.541, 0.290, 0.192},
	.Canal    = {0.208, 0.514, 0.749},
}
