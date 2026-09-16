import api/match_json
import gleam/json
import gleeunit/should
import tennis/match

pub fn initial_match_json_test() {
  match.initial()
  |> match_json.in_progress
  |> json.to_string
  |> should.equal(
    "{\"status\":\"in_progress\",\"server\":\"player_one\",\"sets\":[],\"games\":{\"player_one\":0,\"player_two\":0},\"phase\":\"regular_game\",\"points\":{\"player_one\":\"0\",\"player_two\":\"0\"},\"winner\":null}",
  )
}
