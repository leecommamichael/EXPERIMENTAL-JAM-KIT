package main

import "core:time"

// Iterators:
//   (T, bool: more_data)
//   (T, int, bool)
//
// Naming:
//   init - takes a pointer
//   new - returns a pointer and initialized to zero
//
//   make - returns a value (maybe containing pointers)
//   create - returns a pointer and initialized
//   
//   destroy - takes a pointer to deinitialize (and sometimes free if necessary)
//   free - takes a pointer (frees the pointer) but not destroy/deinit
//   delete - takes a value (frees a pointer)

////////////////////////////////////////////////////////////////////////////////
// Types
////////////////////////////////////////////////////////////////////////////////

Event :: enum {
	Panel_Focused,
	Panel_Dropped_Focus,
}

Game_State :: struct {
	next_action_id: int, // zero is reserved as invalid.
	player: Resources,
	enemy:  Resources,
	tiles:  []Tile,
	actions: [dynamic]Action,
	//
	events:  bit_set[Event],
	state_changed_this_frame: bool,
	prev_state:     States,
	state:          States,
	// Pending Selections
	focused_tile:     int,
	tile_select_mode: Tile_Select_Mode,
	actor:  ^Tile,
	target: ^Tile,
	action: Action,
	panel_menu_state: Panel_Menu_State,
	build_menu_state:   Build_Menu,
	upgrade_menu_state: Upgrade_Menu,
	mission_menu_state: Mission_Menu,
	//
	zoom:   bool,
}

Tile_Select_Mode :: enum {
	First_Tile,
	Actor,
	Target,
}

States :: enum {
	Selecting_Tile,
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
Team :: enum {
	None,
	Player,
	Enemy,
}

Tile :: struct {
	entity:      ^Entity,
	neighbors:   []^Tile,
	index:       int,
	column_row:  [2]int,
	resource:    Tile_Type,
	owner:       Team, // Determines who is doing the action.
	focused:          bool,
	focus_neighbor:   bool,
	_search_visited:  bool,
	_search_distance: int,
}

Tile_Type :: enum {
	Grass,
	// Resources
	Ore,         // Build roads, workshop, markets, barracks
	Food, Water, // Modulates spawn rate
	// Buildings
	Workshop,    // improve/unlock units/resources
	Barracks,    // raise population
	Path,        // Allows non-scout units to move fast.
}
IMPOSSIBLE_TERRAIN :: bit_set[Tile_Type]{.Ore, .Water}
ROUGH_TERRAIN :: bit_set[Tile_Type]{.Grass}
BUILDINGS :: bit_set[Tile_Type]{.Workshop, .Barracks}
TRANSPORT :: bit_set[Tile_Type]{.Path}

// To have a global array and add target param or not?
// Would happening and finish need to exist?
// Some actions are recurring. So a state-machine would make sense.

Action_State :: enum {
	Unplanned, // No workers heading in.
	Awaiting_Assignees,
	In_Progress,
}

// TODO? rename Fleet, Unit, Pawn, Piece, Command, Job
// This is like a command from which units spawn.
Action :: struct {
	id: int,
	// output/yield/result
	target:         ^Tile,
	build_result:   Maybe(Build_Menu),
	upgrade_result: Maybe(Upgrade_Menu),
	mission:        Maybe(Mission_Menu),
	// input
	cost:           Resources,
	one_off:        bool,
	// transient state
	state: Action_State,
	workers_to_reimburse: int,
	leaders_to_reimburse: int,
	work_start_time:      time.Tick, // start_action, finish_action
}

Unit_State :: enum {
	Invisible,
	Moving_To_Target,
	Working,
	Fighting,
	Moving_Home,
	Delivering,
}

Resources :: struct #all_or_none {
	ore:     int,
	food:    int,
	water:   int,
	workers: int,
	leaders: int,
	time:    time.Duration, // time dwelling on-location (not traversal)
}

Cost_Estimate :: struct {
	can_simply_afford: bool,
	can_afford_with_subs: bool,
	sub_worker_cost: int,
	sub_leaders_to_reimburse: int,
	sub_workers_to_reimburse: int,
}

////////////////////////////////////////////////////////////////////////////////
// Data
////////////////////////////////////////////////////////////////////////////////

TILE_GAP :: 1
ROWS :: 23
COLUMNS :: 30
TILES :: ROWS * COLUMNS
TILE_SIZE_PX :: 16

BONKERS_RESOURCES :: Resources {
	ore     = max(int),
	food    = max(int),
	water   = max(int),
	workers = max(int),
	leaders = max(int),
	//
	time = 0,
}

resource_colors: [Tile_Type]Color3 = {
	.Grass    = {0.412, 0.651, 0.255},

	.Ore      = {0.859, 0.686, 0.235},
	.Food     = {0.761, 0.494, 0.184},
	.Water    = {0.208, 0.514, 0.749},

	.Workshop = {0.451, 0.224, 0.176},
	.Barracks = {0.769, 0.561, 0.376},

	.Path     = {0.541, 0.290, 0.192},
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
	time = 1300 * time.Millisecond,
}
workshop_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond,
}
// Gathering cost is 1 worker + distance / speed
path_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond,
}
aqueduct_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond,

}
train_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond,
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
	time = 5300 * time.Millisecond,
}
unit_health_cost ::  Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 5300 * time.Millisecond,
}
unit_power_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 5300 * time.Millisecond,
}
unit_capacity_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 5300 * time.Millisecond,
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
