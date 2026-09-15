import tennis/game
import tennis/player.{type Player, PlayerOne, PlayerTwo, opponent}
import tennis/tiebreak

pub type SetScore {
  SetScore(player_one: Int, player_two: Int)
}

pub type CompletedSet {
  RegularSet(winner: Player, score: SetScore)
  TiebreakSet(
    winner: Player,
    score: SetScore,
    tiebreak_score: tiebreak.TiebreakScore,
  )
}

/// A set that can still receive a point.
pub opaque type Set {
  PlayingGame(score: SetScore, game: game.Game, server: Player)
  PlayingTiebreak(tiebreak: tiebreak.Tiebreak)
}

pub type SetResult {
  SetContinues(Set)
  SetWon(completed: CompletedSet, next_server: Player)
}

/// The point-scoring phase currently displayed within a set.
pub type CurrentGame {
  RegularGame(game.Game)
  Tiebreak(tiebreak.TiebreakScore)
}

pub fn initial(server: Player) -> Set {
  PlayingGame(SetScore(0, 0), game.initial, server)
}

pub fn point_won(set: Set, by player: Player) -> SetResult {
  case set {
    PlayingGame(score, current_game, server) ->
      finish_game(score, server, game.point_won(current_game, player))

    PlayingTiebreak(current_tiebreak) ->
      finish_tiebreak(tiebreak.point_won(current_tiebreak, player))
  }
}

pub fn score(set: Set) -> SetScore {
  case set {
    PlayingGame(score, ..) -> score
    PlayingTiebreak(_) -> SetScore(6, 6)
  }
}

pub fn server(set: Set) -> Player {
  case set {
    PlayingGame(_, _, server) -> server
    PlayingTiebreak(current_tiebreak) -> tiebreak.server(current_tiebreak)
  }
}

pub fn is_tiebreak(set: Set) -> Bool {
  case set {
    PlayingGame(..) -> False
    PlayingTiebreak(_) -> True
  }
}

pub fn current_game(set: Set) -> CurrentGame {
  case set {
    PlayingGame(_, game, _) -> RegularGame(game)
    PlayingTiebreak(current_tiebreak) ->
      Tiebreak(tiebreak.score(current_tiebreak))
  }
}

pub fn completed_winner(completed: CompletedSet) -> Player {
  case completed {
    RegularSet(winner, _) -> winner
    TiebreakSet(winner, _, _) -> winner
  }
}

fn finish_game(
  score: SetScore,
  server: Player,
  result: game.GameResult,
) -> SetResult {
  case result {
    game.GameContinues(next_game) ->
      SetContinues(PlayingGame(score, next_game, server))

    game.GameWon(winner) -> {
      let updated_score = increment(score, winner)
      let next_server = opponent(server)

      case is_won_by(updated_score, winner), updated_score {
        True, _ -> SetWon(RegularSet(winner, updated_score), next_server)
        False, SetScore(6, 6) ->
          SetContinues(PlayingTiebreak(tiebreak.initial(next_server)))
        False, _ ->
          SetContinues(PlayingGame(updated_score, game.initial, next_server))
      }
    }
  }
}

fn finish_tiebreak(result: tiebreak.TiebreakResult) -> SetResult {
  case result {
    tiebreak.TiebreakContinues(next_tiebreak) ->
      SetContinues(PlayingTiebreak(next_tiebreak))

    tiebreak.TiebreakWon(winner, tiebreak_score, first_server) -> {
      let final_score = case winner {
        PlayerOne -> SetScore(7, 6)
        PlayerTwo -> SetScore(6, 7)
      }

      SetWon(
        TiebreakSet(winner, final_score, tiebreak_score),
        opponent(first_server),
      )
    }
  }
}

fn increment(score: SetScore, player: Player) -> SetScore {
  case score, player {
    SetScore(player_one, player_two), PlayerOne ->
      SetScore(player_one + 1, player_two)
    SetScore(player_one, player_two), PlayerTwo ->
      SetScore(player_one, player_two + 1)
  }
}

fn is_won_by(score: SetScore, player: Player) -> Bool {
  let SetScore(player_one, player_two) = score
  let #(winner_games, loser_games) = case player {
    PlayerOne -> #(player_one, player_two)
    PlayerTwo -> #(player_two, player_one)
  }

  winner_games >= 6 && winner_games - loser_games >= 2
}
