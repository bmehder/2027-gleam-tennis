pub fn download(filename: String, contents: String) -> Nil {
  download_text(filename, contents)
}

pub fn choose_json(on_read: fn(String) -> Nil, on_error: fn() -> Nil) -> Nil {
  choose_json_file(on_read, on_error)
}

@external(javascript, "./file_transfer_ffi.mjs", "downloadText")
fn download_text(filename: String, contents: String) -> Nil

@external(javascript, "./file_transfer_ffi.mjs", "chooseJsonFile")
fn choose_json_file(on_read: fn(String) -> Nil, on_error: fn() -> Nil) -> Nil
