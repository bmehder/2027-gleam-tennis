import gleam/list
import gleeunit/should
import tennis/match
import tennis/player.{type Player, PlayerOne, PlayerTwo}

pub fn player_one_serves_first_test() {
  match.initial()
  |> match.server
  |> should.equal(PlayerOne)
}

pub fn next_set_uses_the_server_returned_by_the_completed_set_test() {
  let first_set_games = [
    PlayerOne,
    PlayerTwo,
    PlayerOne,
    PlayerOne,
    PlayerOne,
    PlayerOne,
    PlayerOne,
  ]
  let assert match.MatchContinues(after_first_set) =
    win_games(match.initial(), first_set_games)

  match.server(after_first_set)
  |> should.equal(PlayerTwo)
}

pub fn two_straight_sets_complete_the_match_test() {
  let assert match.MatchContinues(after_first_set) =
    win_games(match.initial(), six_games(PlayerOne))
  let assert match.MatchWon(match.CompletedMatch(winner, completed_sets)) =
    win_games(after_first_set, six_games(PlayerOne))

  winner
  |> should.equal(PlayerOne)
  completed_sets
  |> list.length
  |> should.equal(2)
}

pub fn split_first_two_sets_produce_a_third_set_test() {
  let assert match.MatchContinues(after_first_set) =
    win_games(match.initial(), six_games(PlayerOne))
  let assert match.MatchContinues(after_second_set) =
    win_games(after_first_set, six_games(PlayerTwo))

  match.completed_sets(after_second_set)
  |> list.length
  |> should.equal(2)
}

fn six_games(player: Player) -> List(Player) {
  [player, player, player, player, player, player]
}

fn win_games(
  current_match: match.Match,
  winners: List(Player),
) -> match.MatchResult {
  case winners {
    [] -> match.MatchContinues(current_match)
    [winner, ..rest] ->
      case win_game(current_match, winner), rest {
        match.MatchWon(_) as result, _ -> result
        result, [] -> result
        match.MatchContinues(next_match), rest -> win_games(next_match, rest)
      }
  }
}

fn win_game(current_match: match.Match, winner: Player) -> match.MatchResult {
  win_points(current_match, [winner, winner, winner, winner])
}

fn win_points(
  current_match: match.Match,
  winners: List(Player),
) -> match.MatchResult {
  case winners {
    [] -> match.MatchContinues(current_match)
    [winner, ..rest] ->
      case match.point_won(current_match, winner), rest {
        match.MatchWon(_) as result, _ -> result
        result, [] -> result
        match.MatchContinues(next_match), rest -> win_points(next_match, rest)
      }
  }
}
