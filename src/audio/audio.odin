package audio

import stbv "vendor:stb/vorbis"
import "core:c"
import "core:log"

////////////////////////////////////////////////////////////////////////////////
// The valuable functionality
////////////////////////////////////////////////////////////////////////////////

// Play the entire clip. Spawn more sources if needed.
// ASSUMES: the "root" Source is first in the list (due to linear search)
play :: proc (sys: ^System, sink: Sink, clip_name: string, volume: f32 = 1) {
	player: ^Source
	for &s in sys.sources {
		if s.id == 0 do continue
		if clip_name == s.clip.name {
			player = &s
			break
		}
	}
	if player == nil {
		// Did you forget to add_source_from_clip
		log.errorf("[audio] %s() failed to find a source named %s.", #procedure, clip_name)
		return
	}
	found: bool; iter := make_source_iterator(player)
	for source, index in iterate_sources(&iter) {
		if !source.busy {
			player = source
			found = true
		}
	}
	PER_SOURCE_POLYPHONY :: 5 // i.e. we can only play N coin-grabs at a time.
	if found {
		platform_play(sys^, sink, player, volume)
	} else if iter.index < PER_SOURCE_POLYPHONY {
		new_source := new_source_ptr(sys)
		if new_source == nil {
			return
		}
		new_source.clip = player.clip
		init_platform_source(sys^, new_source)
		_append_source(sys, player, new_source)
		player = new_source
		platform_play(sys^, sink, player, volume)
	}
}

sink_set_volume :: proc (sink: Sink, volume: f32) {
	platform_sink_set_volume(sink, volume)
}


////////////////////////////////////////////////////////////////////////////////
// The entry-fee
////////////////////////////////////////////////////////////////////////////////

System :: struct {
	sources: []Source,
	using platform: Platform_System
}

init :: proc () -> (sys: System, ok: bool) {
	sys.sources = make([]Source, 100)
	ok = platform_init(&sys)
assert(ok)
	return
}

////////////////////////////////////////////////////////////////////////////////

Clip :: struct {
	bytes:       []u8 `cbor:"-" fmt:"-"`,
	name:        string,
	samples:     int,
	seconds:     f64,
	channels:    int,
	sample_rate: int,
}

init_clip_from_bytes :: proc (clip: ^Clip, bytes: []u8) -> (ok: bool) {
	sample_data: [^]u8
	clip.samples = cast(int) stbv.decode_memory(raw_data(bytes),
																					cast(c.int) len(bytes),
																					cast(^c.int) &clip.channels,
																					cast(^c.int) &clip.sample_rate,
																					cast(^[^]c.short) &sample_data)
	log.infof("%s Channels: %d", clip.name, clip.channels)
	clip.bytes = sample_data[:clip.samples * size_of(c.short) ]
	if clip.samples < 1 {
		return false
	}
	clip.seconds = cast(f64) clip.samples / cast(f64) clip.sample_rate
	return true
}

////////////////////////////////////////////////////////////////////////////////

Source :: struct {
	id: Source_Handle,
	busy: bool,
	using clip: Clip,
	using platform: Platform_Source,
	next: ^Source,
}
Source_Handle :: distinct int

add_source_from_clip :: proc (sys: ^System, clip: Clip) -> Source_Handle {
	src := new_source_ptr(sys)
	if src == nil do return 0

	src.clip = clip
	init_platform_source(sys^, src)
	return src.id
}

new_source_ptr :: proc (sys: ^System) -> ^Source {
	for &src, i in sys.sources {
		if i > 0 && src.id == 0 {
			src.id = Source_Handle(i)
			return &src
		}
	}
	log.errorf("[audio] %s() failed to find a free source.", #procedure)
	return nil
}

new_source :: proc (sys: ^System) -> Source_Handle {
	ptr := new_source_ptr(sys)
	if ptr == nil do return Source_Handle(0)
	return ptr.id
}

free_source :: proc (sys: ^System, handle: Source_Handle) {
	platform_destroy_source(sys, handle)
	sys.sources[handle].id = 0
}

Source_Iterator :: struct {
	link: ^Source,
	index: int,
}

make_source_iterator :: proc (src: ^Source) -> Source_Iterator {
	return { src, 0 }
}

iterate_sources :: proc (iter: ^Source_Iterator) -> (out: ^Source, idx: int, more: bool) {
	more = iter.link.next != nil
	idx = iter.index
	out = iter.link
	if more {
		iter.index += 1
		iter.link = iter.link.next
	}
	return
}

_append_source :: proc (sys: ^System, src: ^Source, child: ^Source) {
	if src.next == nil {
		src.next = child
	} else {
		_append_source(sys, src.next, child)
	}
}

////////////////////////////////////////////////////////////////////////////////

Sink :: struct {
	name: string,
	using platform: Platform_Sink,
}

make_sink :: proc (sys: ^System, name: string = "") -> (sink: Sink) {
	sink.name = name
	init_platform_sink(sys, &sink)
	return sink
}
