import api/match_store
import gleeunit/should
import tennis/game
import tennis/match
import tennis/player.{PlayerOne, PlayerTwo}
import tennis/set

pub fn awarded_point_is_remembered_test() {
  let assert Ok(store) = match_store.start()
  let assert Ok(match_store.InProgress(_)) =
    match_store.point_won(store, PlayerTwo)
  store
  |> game_score
  |> should.equal(game.GameScoreText("0", "15"))
}

pub fn undo_removes_the_latest_point_test() {
  let assert Ok(store) = match_store.start()
  let assert Ok(_) = match_store.point_won(store, PlayerTwo)
  let assert Ok(_) = match_store.undo(store)

  store
  |> game_score
  |> should.equal(game.GameScoreText("0", "0"))
}

pub fn redo_restores_an_undone_point_test() {
  let assert Ok(store) = match_store.start()
  let assert Ok(_) = match_store.point_won(store, PlayerTwo)
  let assert Ok(_) = match_store.undo(store)
  let assert Ok(_) = match_store.redo(store)

  store
  |> game_score
  |> should.equal(game.GameScoreText("0", "15"))
}

pub fn a_new_point_after_undo_clears_redo_test() {
  let assert Ok(store) = match_store.start()
  let assert Ok(_) = match_store.point_won(store, PlayerOne)
  let assert Ok(_) = match_store.point_won(store, PlayerTwo)
  let assert Ok(_) = match_store.undo(store)
  let assert Ok(_) = match_store.point_won(store, PlayerOne)

  store
  |> game_score
  |> should.equal(game.GameScoreText("30", "0"))

  match_store.redo(store)
  |> should.equal(Error(Nil))
}

pub fn an_empty_match_cannot_be_undone_test() {
  let assert Ok(store) = match_store.start()

  match_store.undo(store)
  |> should.equal(Error(Nil))
}

fn game_score(store: match_store.Store) -> game.GameScoreText {
  let assert match_store.InProgress(current_match) = match_store.current(store)
  let assert set.RegularGame(score) =
    current_match
    |> match.current_set
    |> set.point_score

  score
}
