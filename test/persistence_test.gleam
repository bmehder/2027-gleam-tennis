import gleeunit/should
import persistence
import tennis/player.{PlayerOne, PlayerTwo}

pub fn point_history_round_trips_test() {
  let history =
    persistence.History(past: [PlayerOne, PlayerTwo, PlayerTwo], future: [
      PlayerOne,
    ])

  history
  |> persistence.serialize
  |> persistence.deserialize
  |> should.equal(history)
}

pub fn previous_point_array_format_is_still_loaded_test() {
  persistence.deserialize("[\"player_one\",\"player_two\"]")
  |> should.equal(persistence.History([PlayerOne, PlayerTwo], []))
}

pub fn malformed_stored_data_is_ignored_test() {
  persistence.deserialize("not json")
  |> should.equal(persistence.History([], []))
}

pub fn unknown_players_are_ignored_test() {
  persistence.deserialize("[\"player_one\",\"player_three\"]")
  |> should.equal(persistence.History([], []))
}
