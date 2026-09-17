import api/match_id
import api/match_json
import api/match_registry
import api/match_store
import envoy
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/erlang/application
import gleam/erlang/process
import gleam/http.{Get, Options, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/option.{None}
import gleam/result
import mist.{type Connection, type ResponseData}
import tennis/player.{type Player, PlayerOne, PlayerTwo}

pub fn main() -> Nil {
  let assert Ok(registry) = match_registry.start()
  let assert Ok(_) =
    fn(request) { handle_request(request, registry) }
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port())
    |> mist.start

  process.sleep_forever()
}

fn port() -> Int {
  case envoy.get("PORT") {
    Ok(value) -> int.parse(value) |> result.unwrap(4000)
    Error(Nil) -> 4000
  }
}

fn handle_request(
  request: Request(Connection),
  registry: match_registry.Registry,
) -> Response(ResponseData) {
  case request.method, request.path_segments(request) {
    Options, _ -> preflight_response()
    Get, ["health"] ->
      json_response(200, json.object([#("status", json.string("ok"))]))
    Get, ["demo"] -> demo_response()
    Post, ["matches"] -> create_match(registry)
    Get, ["matches", id] -> get_match(registry, match_id.from_string(id))
    Post, ["matches", id, "points"] ->
      award_point(request, registry, match_id.from_string(id))
    Post, ["matches", id, "undo"] ->
      time_travel(registry, match_id.from_string(id), match_store.undo, "undo")
    Post, ["matches", id, "redo"] ->
      time_travel(registry, match_id.from_string(id), match_store.redo, "redo")
    _, _ -> not_found()
  }
}

fn time_travel(
  registry: match_registry.Registry,
  id: match_id.MatchId,
  move: fn(match_store.Store) -> Result(match_store.Snapshot, Nil),
  direction: String,
) -> Response(ResponseData) {
  case match_registry.find(registry, id) {
    Error(Nil) -> not_found()
    Ok(store) ->
      case move(store) {
        Ok(snapshot) -> json_response(200, snapshot_json(snapshot))
        Error(Nil) ->
          json_response(
            409,
            json.object([
              #("error", json.string("Nothing to " <> direction)),
            ]),
          )
      }
  }
}

fn demo_response() -> Response(ResponseData) {
  case application.priv_directory("tennis_api") {
    Error(Nil) -> not_found()
    Ok(priv_directory) ->
      case
        mist.send_file(priv_directory <> "/demo.html", offset: 0, limit: None)
      {
        Error(_) -> not_found()
        Ok(body) ->
          response.new(200)
          |> response.set_header("content-type", "text/html; charset=utf-8")
          |> response.set_body(body)
          |> with_cors
      }
  }
}

fn create_match(registry: match_registry.Registry) -> Response(ResponseData) {
  case match_registry.create(registry) {
    Error(_) ->
      json_response(
        500,
        json.object([#("error", json.string("Could not create match"))]),
      )

    Ok(match_registry.CreatedMatch(id, store)) ->
      json_response(
        201,
        json.object([
          #("id", json.string(match_id.to_string(id))),
          #("match", snapshot_json(match_store.current(store))),
        ]),
      )
  }
}

fn get_match(
  registry: match_registry.Registry,
  id: match_id.MatchId,
) -> Response(ResponseData) {
  case match_registry.find(registry, id) {
    Error(Nil) -> not_found()
    Ok(store) -> json_response(200, snapshot_json(match_store.current(store)))
  }
}

fn award_point(
  request: Request(Connection),
  registry: match_registry.Registry,
  id: match_id.MatchId,
) -> Response(ResponseData) {
  case match_registry.find(registry, id) {
    Error(Nil) -> not_found()
    Ok(store) -> award_point_to_match(request, store)
  }
}

fn award_point_to_match(
  request: Request(Connection),
  store: match_store.Store,
) -> Response(ResponseData) {
  case point_winner(request) {
    Error(_) -> invalid_player()
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

fn invalid_player() -> Response(ResponseData) {
  json_response(
    400,
    json.object([
      #("error", json.string("Expected player_one or player_two")),
    ]),
  )
}

fn not_found() -> Response(ResponseData) {
  json_response(404, json.object([#("error", json.string("Not found"))]))
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
  |> with_cors
}

fn preflight_response() -> Response(ResponseData) {
  response.new(204)
  |> response.set_body(mist.Bytes(bytes_tree.new()))
  |> with_cors
}

fn with_cors(response: Response(body)) -> Response(body) {
  response
  |> response.set_header("access-control-allow-origin", "*")
  |> response.set_header("access-control-allow-methods", "GET, POST, OPTIONS")
  |> response.set_header("access-control-allow-headers", "content-type")
}
