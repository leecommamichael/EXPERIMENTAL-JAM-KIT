package audio

import "core:c"
import "core:log"
import "core:slice"
import "core:sys/windows"
import xa2 "vendor:windows/XAudio2"
import stbv "vendor:stb/vorbis"
import win "../windows"

// TODO: Only expose Sink_Handle and Source_Handle?
// TODO: System -> Memory (consider fully type-erased.)

System :: struct {
	xaudio: ^xa2.IXAudio2,
	mastering_voice: ^xa2.IXAudio2MasteringVoice,
	sources: []xa2.IXAudio2SourceVoice,
	sinks:   []xa2.IXAudio2SubmixVoice,
}

init :: proc () -> (sys: System, ok: bool) {
	// assert CoInitializeEx called already.
	// false means it's already initialized.
	// RPC_E_CHANGED_MODE is the only documented error, but it's not defined in Odin.
	result := windows.CoInitializeEx()
assert(result == windows.S_OK || result == windows.S_FALSE)
	result, ok = win.ok(xa2.Create(&sys.xaudio))
	// This result is logged, it's just unclear whether Create will cause an error.
assert(ok)
	result, ok = win.ok(sys.xaudio->CreateMasteringVoice(&sys.mastering_voice))
assert(ok)
	return
}

make_sink :: proc () -> Sink {
	return {}
}

load_from_bytes :: proc (bytes: []u8) -> (clip: Clip, ok: bool) {
	sample_data: [^]u8
	clip.samples = cast(int) stbv.decode_memory(raw_data(bytes),
																					cast(c.int) len(bytes),
																					cast(^c.int) &clip.channels,
																					cast(^c.int) &clip.sample_rate,
																					cast(^[^]c.short) &sample_data)
	clip.bytes = sample_data[:clip.samples]
	if clip.samples < 1 {
		return {}, false
	}
	// PULLING INPUT API
	err: stbv.Error
	decoder: ^stbv.vorbis = stbv.open_memory(raw_data(bytes), cast(c.int) clip.samples, &err, nil)
	if err != nil {
		return {}, false
	}
	clip.seconds = cast(f64) clip.samples / cast(f64) clip.sample_rate
	assert(clip.seconds > 0)
	return clip, true
}

make_source_from_clip :: proc (sys: System, it: Clip) -> Source {
	wave_format: xa2.WAVEFORMATEX
	wave_format.wFormatTag = windows.WAVE_FORMAT_PCM
	wave_format.nChannels  = cast(u16) it.channels
	wave_format.wBitsPerSample = 16 // bits per sample
	wave_format.nSamplesPerSec = cast(c.uint) it.sample_rate
	wave_format.nBlockAlign = wave_format.nChannels * wave_format.wBitsPerSample / 8 // block align 2 channels sending 16bits (kind of a stride)
	wave_format.nAvgBytesPerSec = wave_format.nSamplesPerSec * u32(wave_format.nBlockAlign) //avgbytes/sec

	buffer: xa2.BUFFER
	buffer.AudioBytes = cast(u32) it.samples * (2 * 16 / 8)
	buffer.pAudioData = raw_data(it.bytes)
	buffer.Flags = { .END_OF_STREAM }
	source_voice: ^xa2.IXAudio2SourceVoice
	result := sys.xaudio->CreateSourceVoice(&source_voice, &wave_format)
  switch result {
	case xa2.INVALID_CALL        : assert(false)
	case xa2.XMA_DECODER_ERROR   : assert(false)
	case xa2.XAPO_CREATION_FAILED: assert(false)
	case xa2.DEVICE_INVALIDATED  : assert(false)
  }
  ok: bool
	result, ok = win.ok(source_voice->SubmitSourceBuffer(&buffer))
assert(ok)
	return {}
}

play :: proc (sys: System, sink: Sink, src: Source) {
	result, ok := win.ok(sys.sources[src.id]->Start())
assert(ok)
}