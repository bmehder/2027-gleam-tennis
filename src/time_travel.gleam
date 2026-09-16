import gleam/dynamic/decode
import gleam/json
import tennis/player.{type Player, PlayerOne, PlayerTwo}

pub type Timeline {
  Timeline(past: List(Player), future: List(Player))
}

pub type TimelineError {
  InvalidTimeline
}

pub const empty = Timeline([], [])

pub fn serialize(timeline: Timeline) -> String {
  let Timeline(past, future) = timeline

  json.object([
    #("past", json.array(past, of: encode_player)),
    #("future", json.array(future, of: encode_player)),
  ])
  |> json.to_string
}

pub fn deserialize(stored: String) -> Result(Timeline, TimelineError) {
  case json.parse(stored, timeline_decoder()) {
    Ok(timeline) -> Ok(timeline)
    Error(_) -> Error(InvalidTimeline)
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

fn timeline_decoder() -> decode.Decoder(Timeline) {
  let players = decode.list(of: player_decoder())
  let current_format = {
    use past <- decode.field("past", players)
    use future <- decode.field("future", players)
    decode.success(Timeline(past, future))
  }
  let previous_format = players |> decode.map(fn(past) { Timeline(past, []) })

  decode.one_of(current_format, or: [previous_format])
}
