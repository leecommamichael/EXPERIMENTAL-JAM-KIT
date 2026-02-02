package audio

Clip :: struct {
	bytes: []u8 `cbor:"-" fmt:"-"`,
	samples: int,
	seconds: f64,
	channels: int,
	sample_rate: int,
}
