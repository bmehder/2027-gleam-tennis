import api/match_json
import api/match_store
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/result
import mist.{type Connection, type ResponseData}
import tennis/player.{type Player, PlayerOne, PlayerTwo}

const port = 4000

pub fn main() -> Nil {
  let assert Ok(store) = match_store.start()
  let assert Ok(_) =
    fn(request) { handle_request(request, store) }
    |> mist.new
    |> mist.bind("localhost")
    |> mist.port(port)
    |> mist.start

  process.sleep_forever()
}

fn handle_request(
  request: Request(Connection),
  store: match_store.Store,
) -> Response(ResponseData) {
  case request.method, request.path {
    Get, "/match" ->
      json_response(200, snapshot_json(match_store.current(store)))
    Post, "/point" -> award_point(request, store)
    _, _ ->
      json_response(404, json.object([#("error", json.string("Not found"))]))
  }
}

fn award_point(
  request: Request(Connection),
  store: match_store.Store,
) -> Response(ResponseData) {
  case point_winner(request) {
    Error(_) ->
      json_response(
        400,
        json.object([
          #("error", json.string("Expected player_one or player_two")),
        ]),
      )

    Ok(player) ->
      case match_store.point_won(store, player) {
        Ok(snapshot) -> json_response(200, snapshot_json(snapshot))
        Error(Nil) ->
          json_response(
            409,
            json.object([
              #("error", json.string("The match is already complete")),
            ]),
          )
      }
  }
}

fn point_winner(request: Request(Connection)) -> Result(Player, Nil) {
  use request <- result.try(
    mist.read_body(request, max_body_limit: 1024)
    |> result.map_error(fn(_) { Nil }),
  )

  json.parse_bits(request.body, player_decoder())
  |> result.map_error(fn(_) { Nil })
}

fn player_decoder() -> decode.Decoder(Player) {
  use winner <- decode.field("winner", decode.string)

  case winner {
    "player_one" -> decode.success(PlayerOne)
    "player_two" -> decode.success(PlayerTwo)
    _ -> decode.failure(PlayerOne, expected: "player_one or player_two")
  }
}

fn snapshot_json(snapshot: match_store.Snapshot) -> json.Json {
  case snapshot {
    match_store.InProgress(current_match) ->
      match_json.in_progress(current_match)
    match_store.Completed(completed_match) ->
      match_json.completed(completed_match)
  }
}

fn json_response(status: Int, body: json.Json) -> Response(ResponseData) {
  response.new(status)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(json.to_string(body))))
}
