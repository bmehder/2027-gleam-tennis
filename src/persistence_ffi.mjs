export function load(key) {
  try {
    return globalThis.localStorage.getItem(key) ?? "";
  } catch {
    return "";
  }
}

export function save(key, value) {
  try {
    globalThis.localStorage.setItem(key, value);
  } catch {
    // Storage can be unavailable or full. The in-memory app still works.
  }
}

export function remove(key) {
  try {
    globalThis.localStorage.removeItem(key);
  } catch {
    // Storage can be unavailable. The in-memory app still works.
  }
}
