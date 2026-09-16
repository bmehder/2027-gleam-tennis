import gleeunit/should
import match_history
import tennis/player.{PlayerOne, PlayerTwo}

pub fn point_history_round_trips_test() {
  let history =
    match_history.History(past: [PlayerOne, PlayerTwo, PlayerTwo], future: [
      PlayerOne,
    ])

  history
  |> match_history.serialize
  |> match_history.deserialize
  |> should.equal(Ok(history))
}

pub fn previous_point_array_format_is_still_loaded_test() {
  match_history.deserialize("[\"player_one\",\"player_two\"]")
  |> should.equal(Ok(match_history.History([PlayerOne, PlayerTwo], [])))
}

pub fn malformed_stored_data_is_rejected_test() {
  match_history.deserialize("not json")
  |> should.equal(Error(match_history.InvalidHistory))
}

pub fn unknown_players_are_rejected_test() {
  match_history.deserialize("[\"player_one\",\"player_three\"]")
  |> should.equal(Error(match_history.InvalidHistory))
}
