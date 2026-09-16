import api/match_store
import gleeunit/should
import tennis/game
import tennis/match
import tennis/player.{PlayerTwo}
import tennis/set

pub fn awarded_point_is_remembered_test() {
  let assert Ok(store) = match_store.start()
  let assert Ok(match_store.InProgress(_)) =
    match_store.point_won(store, PlayerTwo)
  let assert match_store.InProgress(current_match) = match_store.current(store)
  let assert set.RegularGame(current_game) =
    current_match
    |> match.current_set
    |> set.current_game

  current_game
  |> game.score_text
  |> should.equal(game.GameScoreText("0", "15"))
}
