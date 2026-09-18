import api/match_registry
import api/match_store
import gleeunit/should
import tennis/game
import tennis/match
import tennis/player.{PlayerOne}
import tennis/set

pub fn matches_have_independent_timelines_test() {
  let assert Ok(registry) = match_registry.start()
  let assert Ok(match_registry.CreatedMatch(_, first)) =
    match_registry.create(registry)
  let assert Ok(match_registry.CreatedMatch(_, second)) =
    match_registry.create(registry)

  let assert Ok(_) = match_store.point_won(first, PlayerOne)

  point_score(first)
  |> should.equal(game.GameScoreText("15", "0"))

  point_score(second)
  |> should.equal(game.GameScoreText("0", "0"))
}

fn point_score(store: match_store.Store) -> game.GameScoreText {
  let assert match_store.InProgress(current_match) = match_store.current(store)
  let assert set.RegularGame(score) =
    current_match
    |> match.current_set
    |> set.point_score
  score
}
