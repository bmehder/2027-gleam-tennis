import gleeunit/should
import tennis/game
import tennis/player.{PlayerOne, PlayerTwo}

pub fn regular_game_starts_at_love_all_test() {
  game.initial
  |> should.equal(game.LoveAll)
}

pub fn ordinary_points_advance_the_score_test() {
  game.point_won(game.LoveAll, PlayerOne)
  |> should.equal(game.GameContinues(game.FifteenLove))

  game.point_won(game.ThirtyFifteen, PlayerTwo)
  |> should.equal(game.GameContinues(game.ThirtyAll))
}

pub fn a_close_game_reaches_deuce_test() {
  game.point_won(game.ThirtyForty, PlayerOne)
  |> should.equal(game.GameContinues(game.Deuce))

  game.point_won(game.FortyThirty, PlayerTwo)
  |> should.equal(game.GameContinues(game.Deuce))
}

pub fn deuce_leads_to_advantage_and_can_return_to_deuce_test() {
  game.point_won(game.Deuce, PlayerOne)
  |> should.equal(game.GameContinues(game.Advantage(PlayerOne)))

  game.point_won(game.Advantage(PlayerOne), PlayerTwo)
  |> should.equal(game.GameContinues(game.Deuce))
}

pub fn a_game_can_be_won_before_or_after_deuce_test() {
  game.point_won(game.FortyLove, PlayerOne)
  |> should.equal(game.GameWon(PlayerOne))

  game.point_won(game.Advantage(PlayerTwo), PlayerTwo)
  |> should.equal(game.GameWon(PlayerTwo))
}

pub fn regular_game_scores_have_a_text_projection_test() {
  game.score_text(game.LoveAll)
  |> should.equal(game.GameScoreText("0", "0"))

  game.score_text(game.Advantage(PlayerOne))
  |> should.equal(game.GameScoreText("AD", "40"))

  game.score_text(game.Advantage(PlayerTwo))
  |> should.equal(game.GameScoreText("40", "AD"))
}
