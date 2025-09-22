package audio

import "core:c"
import "core:log"
import "core:slice"
import "core:sys/windows"
import xa2 "vendor:windows/XAudio2"
import stbv "vendor:stb/vorbis"
import win "../windows"

System :: struct {
	xaudio: ^xa2.IXAudio2,
	mastering_voice: ^xa2.IXAudio2MasteringVoice,
}

init :: proc () -> (sys: System, ok: bool) {
	// assert CoInitializeEx called already.
	result := windows.CoInitializeEx()
// false means it's already initialized.
// RPC_E_CHANGED_MODE is the only documented error, but it's not defined in Odin.
assert(result == windows.S_OK || result == windows.S_FALSE)
	result, ok = win.ok(xa2.Create(&sys.xaudio))
	// This result is logged, it's just unclear whether Create will cause an error.
assert(ok)
	result, ok = win.ok(sys.xaudio->CreateMasteringVoice(&sys.mastering_voice))
assert(ok)
	return
}
// A clip. A collection of samples.
Clip :: struct {
	bytes: []u8,
	samples: int,
	seconds: f64,
	channels: int,
	sample_rate: int,
}

load_from_bytes :: proc (bytes: []u8) -> (clip: Clip, ok: bool) {
	oggv_out: [^]c.short
	clip.samples = cast(int) stbv.decode_memory(raw_data(bytes),
																					cast(c.int) len(bytes),
																					cast(^c.int) &clip.channels,
																					cast(^c.int) &clip.sample_rate,
																					&oggv_out)
	clip.bytes = slice.reinterpret([]u8, oggv_out[:clip.samples])
	// taking ptr address of rawdata doesnt make sense for c interop. it cant init a slice.
	if clip.samples < 1 {
		return {}, false
	}
	// PULLING INPUT API
	err: stbv.Error
	decoder: ^stbv.vorbis = stbv.open_memory(raw_data(bytes), cast(c.int) clip.samples, &err, nil)
	if err != nil {
		return {}, false
	}
	clip.seconds = cast(f64) stbv.stream_length_in_seconds(decoder)
	return clip, true
}

play :: proc (sys: System, it: Clip) {
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
	result, ok = win.ok(source_voice->Start())
assert(ok)
}