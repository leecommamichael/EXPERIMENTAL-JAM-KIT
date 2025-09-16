package kv5

foreign import "kv5"

@(default_calling_convention="contextless")
foreign kv5 {
	kv5_store   :: proc (key: string, value: string) -> (success: bool) ---
	kv5_load    :: proc (key: string, value: string) -> (success: bool) ---
	kv5_delete  :: proc (key: string) ---
	kv5_measure :: proc (key: string) -> (length: int) ---
}

// Fails if the 5MB quota is exceeded.
// Note that the web errors with "quota exceeded" if the user disables local-storage.
store :: kv5_store

// Can fail if the key is not found.
load :: proc (key: string, allocator := context.allocator) -> (data: string, found: bool) {
	len := kv5_measure(key)
	if len <= 0 {
		return "", false
	}
	str := make(string, len, allocator = allocator)
	kv5_load(key, data)
	return data, true
}

delete :: proc (key: string) {
	kv5_delete(key)
}

measure :: kv5_measure