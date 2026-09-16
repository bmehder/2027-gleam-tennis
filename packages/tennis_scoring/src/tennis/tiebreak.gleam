import tennis/player.{type Player, PlayerOne, PlayerTwo, opponent}

pub type TiebreakScore {
  TiebreakScore(player_one: Int, player_two: Int)
}

/// An unfinished tiebreak and the player who served its first point.
pub opaque type Tiebreak {
  Tiebreak(score: TiebreakScore, first_server: Player)
}

pub type TiebreakResult {
  TiebreakContinues(Tiebreak)
  TiebreakWon(winner: Player, score: TiebreakScore, first_server: Player)
}

pub fn initial(first_server: Player) -> Tiebreak {
  Tiebreak(TiebreakScore(0, 0), first_server)
}

pub fn point_won(tiebreak: Tiebreak, by player: Player) -> TiebreakResult {
  let Tiebreak(score, first_server) = tiebreak
  let updated_score = increment(score, player)

  case is_won_by(updated_score, player) {
    True -> TiebreakWon(player, updated_score, first_server)
    False -> TiebreakContinues(Tiebreak(updated_score, first_server))
  }
}

pub fn score(tiebreak: Tiebreak) -> TiebreakScore {
  tiebreak.score
}

/// Return the server for the next point.
///
/// The first player serves once. Service then alternates every two points.
pub fn server(tiebreak: Tiebreak) -> Player {
  let Tiebreak(TiebreakScore(player_one, player_two), first_server) = tiebreak
  let points_played = player_one + player_two

  case points_played % 4 {
    1 | 2 -> opponent(first_server)
    _ -> first_server
  }
}

fn increment(score: TiebreakScore, player: Player) -> TiebreakScore {
  case score, player {
    TiebreakScore(player_one, player_two), PlayerOne ->
      TiebreakScore(player_one + 1, player_two)
    TiebreakScore(player_one, player_two), PlayerTwo ->
      TiebreakScore(player_one, player_two + 1)
  }
}

fn is_won_by(score: TiebreakScore, player: Player) -> Bool {
  let TiebreakScore(player_one, player_two) = score
  let #(winner_points, loser_points) = case player {
    PlayerOne -> #(player_one, player_two)
    PlayerTwo -> #(player_two, player_one)
  }

  winner_points >= 7 && winner_points - loser_points >= 2
}
