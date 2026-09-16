import gleeunit/should
import tennis/player.{PlayerOne, PlayerTwo}
import time_travel

pub fn timeline_round_trips_test() {
  let timeline =
    time_travel.Timeline(past: [PlayerOne, PlayerTwo, PlayerTwo], future: [
      PlayerOne,
    ])

  timeline
  |> time_travel.serialize
  |> time_travel.deserialize
  |> should.equal(Ok(timeline))
}

pub fn previous_point_array_format_is_still_loaded_test() {
  time_travel.deserialize("[\"player_one\",\"player_two\"]")
  |> should.equal(Ok(time_travel.Timeline([PlayerOne, PlayerTwo], [])))
}

pub fn malformed_stored_data_is_rejected_test() {
  time_travel.deserialize("not json")
  |> should.equal(Error(time_travel.InvalidTimeline))
}

pub fn unknown_players_are_rejected_test() {
  time_travel.deserialize("[\"player_one\",\"player_three\"]")
  |> should.equal(Error(time_travel.InvalidTimeline))
}
