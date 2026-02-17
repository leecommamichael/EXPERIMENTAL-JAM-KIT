package main

import "audio"

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

Game_State :: struct {
	sfx_sink:   audio.Sink,
	music_sink: audio.Sink,
}
