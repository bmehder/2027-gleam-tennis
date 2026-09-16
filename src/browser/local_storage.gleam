import time_travel.{type Timeline}

// Keep this key stable so existing saved matches continue to load.
const storage_key = "lustre-tennis-point-history"

pub fn load() -> Timeline {
  case load_item(storage_key) {
    "" -> time_travel.empty
    stored ->
      case time_travel.deserialize(stored) {
        Ok(timeline) -> timeline
        Error(_) -> time_travel.empty
      }
  }
}

pub fn save(timeline: Timeline) -> Nil {
  save_item(storage_key, time_travel.serialize(timeline))
}

pub fn clear() -> Nil {
  remove_item(storage_key)
}

@external(javascript, "./local_storage_ffi.mjs", "load")
fn load_item(key: String) -> String

@external(javascript, "./local_storage_ffi.mjs", "save")
fn save_item(key: String, value: String) -> Nil

@external(javascript, "./local_storage_ffi.mjs", "remove")
fn remove_item(key: String) -> Nil
