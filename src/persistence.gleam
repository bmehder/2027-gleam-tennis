import match_history.{type History}

const storage_key = "lustre-tennis-point-history"

pub fn load() -> History {
  case load_item(storage_key) {
    "" -> match_history.empty
    stored ->
      case match_history.deserialize(stored) {
        Ok(history) -> history
        Error(_) -> match_history.empty
      }
  }
}

pub fn save(history: History) -> Nil {
  save_item(storage_key, match_history.serialize(history))
}

pub fn clear() -> Nil {
  remove_item(storage_key)
}

@external(javascript, "./persistence_ffi.mjs", "load")
fn load_item(key: String) -> String

@external(javascript, "./persistence_ffi.mjs", "save")
fn save_item(key: String, value: String) -> Nil

@external(javascript, "./persistence_ffi.mjs", "remove")
fn remove_item(key: String) -> Nil
