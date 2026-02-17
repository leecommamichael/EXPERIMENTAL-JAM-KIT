package audio

import stbv "vendor:stb/vorbis"
import "core:c"
import "core:log"

////////////////////////////////////////////////////////////////////////////////
// The valuable functionality
////////////////////////////////////////////////////////////////////////////////

play :: proc (sys: System, sink: Sink, clip_name: string) {
	src: ^Source
	for &s in sys.sources {
		if clip_name == s.clip.name do src = &s
	}
	if src == nil {
		log.errorf("[audio] %s() failed to find a source named %s.", #procedure, clip_name)
		return
	}
	platform_play(sys, sink, src^)
}

////////////////////////////////////////////////////////////////////////////////
// The entry-fee
////////////////////////////////////////////////////////////////////////////////

System :: struct {
	sources: []Source,
	using platform: Platform_System
}

init :: proc () -> (sys: System, ok: bool) {
	sys.sources = make([]Source, 10)
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
	clip.bytes = sample_data[:clip.samples]
	if clip.samples < 1 {
		return false
	}
	// PULLING INPUT API
	err: stbv.Error
	decoder: ^stbv.vorbis = stbv.open_memory(raw_data(bytes), cast(c.int) clip.samples, &err, nil)
	if err != nil {
		return false
	}
	clip.seconds = cast(f64) clip.samples / cast(f64) clip.sample_rate
	assert(clip.seconds > 0)
	return true
}

////////////////////////////////////////////////////////////////////////////////

Source :: struct {
	id: Source_Handle,
	using clip: Clip,
	using platform: Platform_Source,
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

////////////////////////////////////////////////////////////////////////////////

Sink :: struct {
	id: Sink_Handle,
	using platform: Platform_Sink,
}
Sink_Handle :: distinct int

make_sink :: proc () -> Sink {
	return {}
}
