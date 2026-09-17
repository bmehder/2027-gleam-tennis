import api/match_registry
import api/match_store
import gleeunit/should
import tennis/game
import tennis/match
import tennis/player.{PlayerOne}
import tennis/set

pub fn matches_have_independent_event_logs_test() {
  let assert Ok(registry) = match_registry.start()
  let assert Ok(match_registry.CreatedMatch(_, first)) =
    match_registry.create(registry)
  let assert Ok(match_registry.CreatedMatch(_, second)) =
    match_registry.create(registry)

  let assert Ok(_) = match_store.point_won(first, PlayerOne)

  current_game(first)
  |> game.score_text
  |> should.equal(game.GameScoreText("15", "0"))

  current_game(second)
  |> game.score_text
  |> should.equal(game.GameScoreText("0", "0"))
}

fn current_game(store: match_store.Store) -> game.Game {
  let assert match_store.InProgress(current_match) = match_store.current(store)
  let assert set.RegularGame(current_game) =
    current_match
    |> match.current_set
    |> set.current_game
  current_game
}
