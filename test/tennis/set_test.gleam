import gleeunit/should
import tennis/game
import tennis/player.{type Player, PlayerOne, PlayerTwo}
import tennis/set
import tennis/tiebreak

pub fn set_starts_at_zero_all_with_the_given_server_test() {
  let set = set.initial(PlayerOne)

  set.score(set)
  |> should.equal(set.SetScore(0, 0))

  set.server(set)
  |> should.equal(PlayerOne)
}

pub fn server_alternates_after_a_regular_game_test() {
  let set = set.initial(PlayerOne)
  let assert set.SetContinues(after_game) = win_game(set, PlayerOne)

  set.score(after_game)
  |> should.equal(set.SetScore(1, 0))

  set.server(after_game)
  |> should.equal(PlayerTwo)
}

pub fn current_game_exposes_the_regular_game_score_test() {
  let current_set = set.initial(PlayerOne)

  set.current_game(current_set)
  |> should.equal(set.RegularGame(game.LoveAll))
}

pub fn set_is_won_at_six_games_with_a_two_game_lead_test() {
  let result =
    win_games(set.initial(PlayerOne), [
      PlayerOne,
      PlayerOne,
      PlayerOne,
      PlayerOne,
      PlayerOne,
      PlayerOne,
    ])

  result
  |> should.equal(set.SetWon(
    set.RegularSet(PlayerOne, set.SetScore(6, 0)),
    PlayerOne,
  ))
}

pub fn six_games_all_starts_a_tiebreak_with_the_next_server_test() {
  let result =
    win_games(set.initial(PlayerOne), [
      PlayerOne,
      PlayerTwo,
      PlayerOne,
      PlayerTwo,
      PlayerOne,
      PlayerTwo,
      PlayerOne,
      PlayerTwo,
      PlayerOne,
      PlayerTwo,
      PlayerOne,
      PlayerTwo,
    ])
  let assert set.SetContinues(at_tiebreak) = result

  set.score(at_tiebreak)
  |> should.equal(set.SetScore(6, 6))
  set.is_tiebreak(at_tiebreak)
  |> should.be_true
  set.server(at_tiebreak)
  |> should.equal(PlayerOne)
}

pub fn completed_tiebreak_reports_the_next_set_server_test() {
  let games = [
    PlayerOne,
    PlayerTwo,
    PlayerOne,
    PlayerTwo,
    PlayerOne,
    PlayerTwo,
    PlayerOne,
    PlayerTwo,
    PlayerOne,
    PlayerTwo,
    PlayerOne,
    PlayerTwo,
  ]
  let assert set.SetContinues(at_tiebreak) =
    win_games(set.initial(PlayerOne), games)

  let result =
    win_points(at_tiebreak, [
      PlayerOne,
      PlayerOne,
      PlayerOne,
      PlayerOne,
      PlayerOne,
      PlayerOne,
      PlayerOne,
    ])

  result
  |> should.equal(set.SetWon(
    set.TiebreakSet(PlayerOne, set.SetScore(7, 6), tiebreak.TiebreakScore(7, 0)),
    PlayerTwo,
  ))
}

fn win_games(current_set: set.Set, winners: List(Player)) -> set.SetResult {
  case winners {
    [] -> set.SetContinues(current_set)
    [winner, ..rest] ->
      case win_game(current_set, winner), rest {
        set.SetWon(..) as result, _ -> result
        result, [] -> result
        set.SetContinues(next_set), rest -> win_games(next_set, rest)
      }
  }
}

fn win_game(current_set: set.Set, winner: Player) -> set.SetResult {
  win_points(current_set, [winner, winner, winner, winner])
}

fn win_points(current_set: set.Set, winners: List(Player)) -> set.SetResult {
  case winners {
    [] -> set.SetContinues(current_set)
    [winner, ..rest] ->
      case set.point_won(current_set, winner), rest {
        set.SetWon(..) as result, _ -> result
        result, [] -> result
        set.SetContinues(next_set), rest -> win_points(next_set, rest)
      }
  }
}
