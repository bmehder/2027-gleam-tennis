import gleam/list
import tennis/player.{type Player, PlayerOne}
import tennis/set

/// A best-of-three match that can still receive a point.
pub opaque type Match {
  Match(completed_sets: List(set.CompletedSet), current_set: set.Set)
}

pub type CompletedMatch {
  CompletedMatch(winner: Player, sets: List(set.CompletedSet))
}

pub type MatchResult {
  MatchContinues(Match)
  MatchWon(CompletedMatch)
}

/// Start a match with Player One serving the first game.
pub fn initial() -> Match {
  Match(completed_sets: [], current_set: set.initial(PlayerOne))
}

pub fn point_won(match: Match, by player: Player) -> MatchResult {
  let Match(completed_sets, current_set) = match

  case set.point_won(current_set, player) {
    set.SetContinues(next_set) ->
      MatchContinues(Match(completed_sets, next_set))

    set.SetWon(completed_set, next_server) -> {
      let updated_sets = list.append(completed_sets, [completed_set])
      let winner = set.winner(completed_set)

      case sets_won_by(updated_sets, winner) == 2 {
        True -> MatchWon(CompletedMatch(winner, updated_sets))
        False -> MatchContinues(Match(updated_sets, set.initial(next_server)))
      }
    }
  }
}

pub fn completed_sets(match: Match) -> List(set.CompletedSet) {
  match.completed_sets
}

pub fn current_set(match: Match) -> set.Set {
  match.current_set
}

pub fn server(match: Match) -> Player {
  set.server(match.current_set)
}

fn sets_won_by(sets: List(set.CompletedSet), player: Player) -> Int {
  sets
  |> list.filter(fn(completed) { set.winner(completed) == player })
  |> list.length
}
