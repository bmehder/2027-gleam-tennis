pub type Player {
  PlayerOne
  PlayerTwo
}

pub fn opponent(player: Player) -> Player {
  case player {
    PlayerOne -> PlayerTwo
    PlayerTwo -> PlayerOne
  }
}
