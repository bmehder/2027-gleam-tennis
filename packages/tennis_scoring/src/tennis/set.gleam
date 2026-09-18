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

/// The point score currently displayed within a set.
pub type PointScore {
  RegularGame(game.GameScoreText)
  Tiebreak(tiebreak.TiebreakScore)
}

pub fn initial(server: Player) -> Set {
  PlayingGame(SetScore(0, 0), game.initial, server)
}

pub fn point_won(current_set: Set, by player: Player) -> SetResult {
  case current_set {
    PlayingGame(score, current_game, server) ->
      after_regular_game_point(
        score,
        server,
        game.point_won(current_game, player),
      )

    PlayingTiebreak(current_tiebreak) ->
      after_tiebreak_point(tiebreak.point_won(current_tiebreak, player))
  }
}

pub fn score(current_set: Set) -> SetScore {
  case current_set {
    PlayingGame(score, ..) -> score
    PlayingTiebreak(_) -> SetScore(6, 6)
  }
}

pub fn server(current_set: Set) -> Player {
  case current_set {
    PlayingGame(_, _, server) -> server
    PlayingTiebreak(current_tiebreak) -> tiebreak.server(current_tiebreak)
  }
}

pub fn is_tiebreak(current_set: Set) -> Bool {
  case current_set {
    PlayingGame(..) -> False
    PlayingTiebreak(_) -> True
  }
}

pub fn point_score(current_set: Set) -> PointScore {
  case current_set {
    PlayingGame(_, current_game, _) -> RegularGame(game.score(current_game))
    PlayingTiebreak(current_tiebreak) ->
      Tiebreak(tiebreak.score(current_tiebreak))
  }
}

pub fn winner(completed: CompletedSet) -> Player {
  case completed {
    RegularSet(winner, _) -> winner
    TiebreakSet(winner, _, _) -> winner
  }
}

fn after_regular_game_point(
  score: SetScore,
  server: Player,
  result: game.GameResult,
) -> SetResult {
  case result {
    game.GameContinues(next_game) ->
      SetContinues(PlayingGame(score, next_game, server))

    game.GameWon(winner) -> after_game_won(score, server, winner)
  }
}

fn after_game_won(
  score: SetScore,
  server: Player,
  winner: Player,
) -> SetResult {
  let updated_score = award_game(score, winner)
  let next_server = opponent(server)

  case is_set_won_by(updated_score, winner), updated_score {
    True, _ -> SetWon(RegularSet(winner, updated_score), next_server)
    False, SetScore(6, 6) ->
      SetContinues(PlayingTiebreak(tiebreak.initial(next_server)))
    False, _ ->
      SetContinues(PlayingGame(updated_score, game.initial, next_server))
  }
}

fn after_tiebreak_point(result: tiebreak.TiebreakResult) -> SetResult {
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

fn award_game(score: SetScore, player: Player) -> SetScore {
  case score, player {
    SetScore(player_one, player_two), PlayerOne ->
      SetScore(player_one + 1, player_two)
    SetScore(player_one, player_two), PlayerTwo ->
      SetScore(player_one, player_two + 1)
  }
}

fn is_set_won_by(score: SetScore, player: Player) -> Bool {
  let SetScore(player_one, player_two) = score
  let #(winner_games, loser_games) = case player {
    PlayerOne -> #(player_one, player_two)
    PlayerTwo -> #(player_two, player_one)
  }

  winner_games >= 6 && winner_games - loser_games >= 2
}
