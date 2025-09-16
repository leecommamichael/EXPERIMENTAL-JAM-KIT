// Save up to 5MB total of data on the user's machine.
// https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage
function kv5_create_module(mem) {
	return {
		kv5_store: (key, value) {
			try {
				const key_str = mem.loadString(key)
				const val_str = mem.loadString(value)
				localStorage.setItem(key_str, val_str)
				return true
			} catch (e) {
				if (e instanceof QuotaExceededError) {
					console.error(`kv5 ran out of space in LocalStorage. You may see this if the user disabled storage for the site.`)
				}
				console.error(`kv5.store(${key}, ${value}) threw an exception: ${e.toString()}`)
				return false
			}
		},

		kv5_measure: (key) {
			try {
				const key_str = mem.loadString(key)
				const value_utf16 = localStorage.getItem(key_str)
				const value_utf8 = new TextEncoder().encode(value_utf16)
				return value_utf8.length
			} catch (e) {
				console.error(`kv5.load(${key, out_value, out_len}) threw an exception: ${e.toString()}`)
				return false
			}
		},

		kv5_load: (key, out_value, out_len) {
			try {
				const key_str = mem.loadString(key)
				if (out_len) {
					mem.storeInt(out_len, value_utf8.length)
				} else if (!out_value) {
					// Neither len nor value.
					console.error(`kv5.load(${key_str}, ${out_value || "MISSING"}, ${out_len || "MISSING"}) is missing a parameter.`)
					return false
				}
				if (out_value) {
					const value_utf16 = localStorage.getItem(key_str)
					const value_utf8 = new TextEncoder().encode(value_utf16)
					mem.storeString(out_value, value_utf8)
				}
				return true
			} catch (e) {
				console.error(`kv5.load(${key, out_value, out_len}) threw an exception: ${e.toString()}`)
				return false
			}
		},

		kv5_delete: (key) {
			try {
				const key_str = mem.loadString(key)
				mem.removeItem(key_str)
			} catch (e) {
				console.error(`kv5.delete(${key}) threw an exception: ${e.toString()}`)
			}
		},
	}
}