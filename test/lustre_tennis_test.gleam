import gleam/list
import gleeunit
import gleeunit/should
import tennis/game
import tennis/player.{PlayerOne, PlayerTwo}
import tennis/tiebreak

pub fn main() -> Nil {
  gleeunit.main()
}

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

pub fn regular_game_scores_have_a_display_projection_test() {
  game.display_score(game.LoveAll)
  |> should.equal(game.DisplayScore("0", "0"))

  game.display_score(game.Advantage(PlayerOne))
  |> should.equal(game.DisplayScore("AD", "40"))

  game.display_score(game.Advantage(PlayerTwo))
  |> should.equal(game.DisplayScore("40", "AD"))
}

pub fn tiebreak_starts_at_zero_all_with_its_first_server_test() {
  let tiebreak = tiebreak.initial(PlayerOne)

  tiebreak.score(tiebreak)
  |> should.equal(tiebreak.TiebreakScore(0, 0))

  tiebreak.server(tiebreak)
  |> should.equal(PlayerOne)
}

pub fn tiebreak_service_alternates_after_one_point_then_every_two_test() {
  let initial = tiebreak.initial(PlayerOne)
  let assert tiebreak.TiebreakContinues(after_one) =
    tiebreak.point_won(initial, PlayerOne)
  let assert tiebreak.TiebreakContinues(after_two) =
    tiebreak.point_won(after_one, PlayerOne)
  let assert tiebreak.TiebreakContinues(after_three) =
    tiebreak.point_won(after_two, PlayerOne)
  let assert tiebreak.TiebreakContinues(after_four) =
    tiebreak.point_won(after_three, PlayerOne)

  tiebreak.server(after_one) |> should.equal(PlayerTwo)
  tiebreak.server(after_two) |> should.equal(PlayerTwo)
  tiebreak.server(after_three) |> should.equal(PlayerOne)
  tiebreak.server(after_four) |> should.equal(PlayerOne)
}

pub fn tiebreak_is_won_at_seven_with_a_two_point_lead_test() {
  let initial = tiebreak.initial(PlayerOne)
  let assert tiebreak.TiebreakContinues(one) =
    tiebreak.point_won(initial, PlayerOne)
  let assert tiebreak.TiebreakContinues(two) =
    tiebreak.point_won(one, PlayerOne)
  let assert tiebreak.TiebreakContinues(three) =
    tiebreak.point_won(two, PlayerOne)
  let assert tiebreak.TiebreakContinues(four) =
    tiebreak.point_won(three, PlayerOne)
  let assert tiebreak.TiebreakContinues(five) =
    tiebreak.point_won(four, PlayerOne)
  let assert tiebreak.TiebreakContinues(six) =
    tiebreak.point_won(five, PlayerOne)

  tiebreak.point_won(six, PlayerOne)
  |> should.equal(tiebreak.TiebreakWon(
    PlayerOne,
    tiebreak.TiebreakScore(7, 0),
    PlayerOne,
  ))
}

pub fn tiebreak_continues_at_seven_six_test() {
  let points = [
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
    PlayerOne,
  ]
  let assert tiebreak.TiebreakContinues(state) = play_tiebreak(points)

  tiebreak.score(state)
  |> should.equal(tiebreak.TiebreakScore(7, 6))
}

fn play_tiebreak(points) -> tiebreak.TiebreakResult {
  points
  |> list.fold(
    tiebreak.TiebreakContinues(tiebreak.initial(PlayerOne)),
    fn(result, point_winner) {
      case result {
        tiebreak.TiebreakContinues(state) ->
          tiebreak.point_won(state, point_winner)
        tiebreak.TiebreakWon(..) -> result
      }
    },
  )
}
