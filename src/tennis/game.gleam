import tennis/player.{type Player, PlayerOne, PlayerTwo}

/// Every score at which a regular tennis game can still receive a point.
pub type Game {
  LoveAll
  FifteenLove
  LoveFifteen
  FifteenAll
  ThirtyLove
  LoveThirty
  ThirtyFifteen
  FifteenThirty
  ThirtyAll
  FortyLove
  LoveForty
  FortyFifteen
  FifteenForty
  FortyThirty
  ThirtyForty
  Deuce
  Advantage(Player)
}

/// The result of awarding one point in a regular game.
///
/// A completed game is an outcome, not another playable `Game` state.
pub type GameResult {
  GameContinues(Game)
  GameWon(Player)
}

pub type DisplayScore {
  DisplayScore(player_one: String, player_two: String)
}

pub const initial = LoveAll

/// Award one point to a player in a regular tennis game.
pub fn point_won(game: Game, by player: Player) -> GameResult {
  case game, player {
    LoveAll, PlayerOne -> GameContinues(FifteenLove)
    LoveAll, PlayerTwo -> GameContinues(LoveFifteen)

    FifteenLove, PlayerOne -> GameContinues(ThirtyLove)
    FifteenLove, PlayerTwo -> GameContinues(FifteenAll)
    LoveFifteen, PlayerOne -> GameContinues(FifteenAll)
    LoveFifteen, PlayerTwo -> GameContinues(LoveThirty)
    FifteenAll, PlayerOne -> GameContinues(ThirtyFifteen)
    FifteenAll, PlayerTwo -> GameContinues(FifteenThirty)

    ThirtyLove, PlayerOne -> GameContinues(FortyLove)
    ThirtyLove, PlayerTwo -> GameContinues(ThirtyFifteen)
    LoveThirty, PlayerOne -> GameContinues(FifteenThirty)
    LoveThirty, PlayerTwo -> GameContinues(LoveForty)
    ThirtyFifteen, PlayerOne -> GameContinues(FortyFifteen)
    ThirtyFifteen, PlayerTwo -> GameContinues(ThirtyAll)
    FifteenThirty, PlayerOne -> GameContinues(ThirtyAll)
    FifteenThirty, PlayerTwo -> GameContinues(FifteenForty)
    ThirtyAll, PlayerOne -> GameContinues(FortyThirty)
    ThirtyAll, PlayerTwo -> GameContinues(ThirtyForty)

    FortyLove, PlayerOne -> GameWon(PlayerOne)
    FortyLove, PlayerTwo -> GameContinues(FortyFifteen)
    LoveForty, PlayerOne -> GameContinues(FifteenForty)
    LoveForty, PlayerTwo -> GameWon(PlayerTwo)
    FortyFifteen, PlayerOne -> GameWon(PlayerOne)
    FortyFifteen, PlayerTwo -> GameContinues(FortyThirty)
    FifteenForty, PlayerOne -> GameContinues(ThirtyForty)
    FifteenForty, PlayerTwo -> GameWon(PlayerTwo)
    FortyThirty, PlayerOne -> GameWon(PlayerOne)
    FortyThirty, PlayerTwo -> GameContinues(Deuce)
    ThirtyForty, PlayerOne -> GameContinues(Deuce)
    ThirtyForty, PlayerTwo -> GameWon(PlayerTwo)

    Deuce, player -> GameContinues(Advantage(player))
    Advantage(PlayerOne), PlayerOne -> GameWon(PlayerOne)
    Advantage(PlayerOne), PlayerTwo -> GameContinues(Deuce)
    Advantage(PlayerTwo), PlayerOne -> GameContinues(Deuce)
    Advantage(PlayerTwo), PlayerTwo -> GameWon(PlayerTwo)
  }
}

pub fn display_score(game: Game) -> DisplayScore {
  case game {
    LoveAll -> DisplayScore("0", "0")
    FifteenLove -> DisplayScore("15", "0")
    LoveFifteen -> DisplayScore("0", "15")
    FifteenAll -> DisplayScore("15", "15")
    ThirtyLove -> DisplayScore("30", "0")
    LoveThirty -> DisplayScore("0", "30")
    ThirtyFifteen -> DisplayScore("30", "15")
    FifteenThirty -> DisplayScore("15", "30")
    ThirtyAll -> DisplayScore("30", "30")
    FortyLove -> DisplayScore("40", "0")
    LoveForty -> DisplayScore("0", "40")
    FortyFifteen -> DisplayScore("40", "15")
    FifteenForty -> DisplayScore("15", "40")
    FortyThirty -> DisplayScore("40", "30")
    ThirtyForty -> DisplayScore("30", "40")
    Deuce -> DisplayScore("40", "40")
    Advantage(PlayerOne) -> DisplayScore("AD", "40")
    Advantage(PlayerTwo) -> DisplayScore("40", "AD")
  }
}
