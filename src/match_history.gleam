import gleam/dynamic/decode
import gleam/json
import tennis/player.{type Player, PlayerOne, PlayerTwo}

pub type History {
  History(past: List(Player), future: List(Player))
}

pub type HistoryError {
  InvalidHistory
}

pub const empty = History([], [])

pub fn serialize(history: History) -> String {
  let History(past, future) = history

  json.object([
    #("past", json.array(past, of: encode_player)),
    #("future", json.array(future, of: encode_player)),
  ])
  |> json.to_string
}

pub fn deserialize(stored: String) -> Result(History, HistoryError) {
  case json.parse(stored, history_decoder()) {
    Ok(history) -> Ok(history)
    Error(_) -> Error(InvalidHistory)
  }
}

fn encode_player(player: Player) -> json.Json {
  case player {
    PlayerOne -> json.string("player_one")
    PlayerTwo -> json.string("player_two")
  }
}

fn player_decoder() -> decode.Decoder(Player) {
  decode.string
  |> decode.then(fn(value) {
    case value {
      "player_one" -> decode.success(PlayerOne)
      "player_two" -> decode.success(PlayerTwo)
      _ -> decode.failure(PlayerOne, expected: "player_one or player_two")
    }
  })
}

fn history_decoder() -> decode.Decoder(History) {
  let players = decode.list(of: player_decoder())
  let current_format = {
    use past <- decode.field("past", players)
    use future <- decode.field("future", players)
    decode.success(History(past, future))
  }
  let previous_format = players |> decode.map(fn(past) { History(past, []) })

  decode.one_of(current_format, or: [previous_format])
}
