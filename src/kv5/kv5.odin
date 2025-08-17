package kv5

// Save up to 5MB total of data on the user's machine.
// https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage

// throws QuotaExceededError:DOMException
// Can fail if the user has storage disabled for the site, quota is exceeded.
store :: proc (key: string16, value: string16) -> (ok: bool) {

}

load :: proc (key: string16) -> (ok: bool, data: string16) {

}

delete :: proc (key: string16) {

}

// CAVEAT: I can't support localStorage.clear() since I can't fill that for Desktop.
// TODO: Warn on desktop when they save more than 5MB, that it won't work on web.
// TODO: #config for web compatibility warnings.

// TODO: An easy version of the functions that allocate and use plain strings.