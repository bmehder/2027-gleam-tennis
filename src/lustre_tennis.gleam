import gleam/int
import gleam/list
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import tennis/game
import tennis/match
import tennis/player.{type Player, PlayerOne, PlayerTwo}
import tennis/set
import tennis/tiebreak

type Model {
  Playing(match.Match)
  Finished(match.CompletedMatch)
}

type Msg {
  UserAwardedPoint(Player)
  UserStartedNewMatch
}

type PlayerScore {
  PlayerScore(
    player: Player,
    name: String,
    sets: SetColumns,
    points: String,
    is_serving: Bool,
    is_winner: Bool,
  )
}

type Scoreboard {
  Scoreboard(
    player_one: PlayerScore,
    player_two: PlayerScore,
    match_is_complete: Bool,
  )
}

type SetColumns {
  SetColumns(first: SetCell, second: SetCell, third: SetCell)
}

type SetCell {
  SetCell(games: String, tiebreak_points: String)
}

pub fn main() -> Nil {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#tennis-match", Nil)
  Nil
}

fn init(_arguments) -> Model {
  Playing(match.initial())
}

fn update(model: Model, message: Msg) -> Model {
  case model, message {
    Playing(current_match), UserAwardedPoint(player) ->
      case match.point_won(current_match, player) {
        match.MatchContinues(next_match) -> Playing(next_match)
        match.MatchWon(completed_match) -> Finished(completed_match)
      }

    Finished(_), UserAwardedPoint(_) -> model
    _, UserStartedNewMatch -> Playing(match.initial())
  }
}

fn view(model: Model) -> Element(Msg) {
  case model {
    Playing(current_match) -> view_playing(current_match)
    Finished(completed_match) -> view_finished(completed_match)
  }
}

fn view_playing(current_match: match.Match) -> Element(Msg) {
  view_scoreboard(to_playing_scoreboard(current_match))
}

fn view_finished(completed_match: match.CompletedMatch) -> Element(Msg) {
  view_scoreboard(to_finished_scoreboard(completed_match))
}

fn view_scoreboard(scoreboard: Scoreboard) -> Element(Msg) {
  let Scoreboard(player_one, player_two, match_is_complete) = scoreboard

  html.main([attribute.class("scoreboard")], [
    html.p([attribute.class("eyebrow")], [html.text("CENTRE COURT")]),
    html.h1([], [html.text("Lustre Tennis")]),
    html.section([attribute.class("score-table")], [
      html.div([attribute.class("score-row score-header")], [
        html.span([], []),
        html.span([], [html.text("Player")]),
        html.span([], [html.text("1")]),
        html.span([], [html.text("2")]),
        html.span([], [html.text("3")]),
        html.span([], [html.text("Pts")]),
      ]),
      player_row(player_one),
      player_row(player_two),
    ]),
    case match_is_complete {
      True ->
        html.button(
          [attribute.class("new-match"), event.on_click(UserStartedNewMatch)],
          [html.text("Start a new match")],
        )
      False -> point_controls(player_one, player_two)
    },
  ])
}

fn player_row(score: PlayerScore) -> Element(Msg) {
  let SetColumns(first, second, third) = score.sets
  let row_class = case score.is_winner {
    True -> "score-row player-row match-winner"
    False -> "score-row player-row"
  }

  html.div([attribute.class(row_class)], [
    html.span([attribute.class("serve-marker")], [
      html.text(case score.is_serving {
        True -> "●"
        False -> ""
      }),
    ]),
    html.span([attribute.class("player-name")], [html.text(score.name)]),
    set_cell(first),
    set_cell(second),
    set_cell(third),
    html.span([attribute.class("points-score")], [html.text(score.points)]),
  ])
}

fn point_controls(
  player_one: PlayerScore,
  player_two: PlayerScore,
) -> Element(Msg) {
  html.div([attribute.class("point-controls")], [
    point_button(player_one),
    point_button(player_two),
  ])
}

fn point_button(score: PlayerScore) -> Element(Msg) {
  html.button([event.on_click(UserAwardedPoint(score.player))], [
    html.text("Point for " <> score.name),
  ])
}

fn set_cell(cell: SetCell) -> Element(msg) {
  let SetCell(games, tiebreak_points) = cell

  html.span([attribute.class("set-score")], [
    html.text(games),
    case tiebreak_points {
      "" -> element.none()
      points -> html.sup([], [html.text(points)])
    },
  ])
}

fn to_playing_scoreboard(current_match: match.Match) -> Scoreboard {
  let current_set = match.current_set(current_match)
  let #(player_one_points, player_two_points) = point_scores(current_set)
  let server = match.server(current_match)
  let completed_sets = match.completed_sets(current_match)

  Scoreboard(
    player_one: PlayerScore(
      player: PlayerOne,
      name: player_name(PlayerOne),
      sets: playing_set_columns(completed_sets, current_set, PlayerOne),
      points: player_one_points,
      is_serving: server == PlayerOne,
      is_winner: False,
    ),
    player_two: PlayerScore(
      player: PlayerTwo,
      name: player_name(PlayerTwo),
      sets: playing_set_columns(completed_sets, current_set, PlayerTwo),
      points: player_two_points,
      is_serving: server == PlayerTwo,
      is_winner: False,
    ),
    match_is_complete: False,
  )
}

fn to_finished_scoreboard(completed_match: match.CompletedMatch) -> Scoreboard {
  let match.CompletedMatch(winner, completed_sets) = completed_match

  Scoreboard(
    player_one: PlayerScore(
      player: PlayerOne,
      name: player_name(PlayerOne),
      sets: completed_set_columns(completed_sets, PlayerOne),
      points: "–",
      is_serving: False,
      is_winner: winner == PlayerOne,
    ),
    player_two: PlayerScore(
      player: PlayerTwo,
      name: player_name(PlayerTwo),
      sets: completed_set_columns(completed_sets, PlayerTwo),
      points: "–",
      is_serving: False,
      is_winner: winner == PlayerTwo,
    ),
    match_is_complete: True,
  )
}

fn playing_set_columns(
  completed_sets: List(set.CompletedSet),
  current_set: set.Set,
  player: Player,
) -> SetColumns {
  completed_sets
  |> list.map(completed_set_cell(_, player))
  |> list.append([current_set_cell(current_set, player)])
  |> to_set_columns
}

fn completed_set_columns(
  completed_sets: List(set.CompletedSet),
  player: Player,
) -> SetColumns {
  completed_sets
  |> list.map(completed_set_cell(_, player))
  |> to_set_columns
}

fn current_set_cell(current_set: set.Set, player: Player) -> SetCell {
  let set.SetScore(player_one, player_two) = set.score(current_set)
  SetCell(int.to_string(for_player(player, player_one, player_two)), "")
}

fn completed_set_cell(completed: set.CompletedSet, player: Player) -> SetCell {
  case completed {
    set.RegularSet(_, set.SetScore(player_one, player_two)) ->
      SetCell(int.to_string(for_player(player, player_one, player_two)), "")

    set.TiebreakSet(
      _,
      set.SetScore(player_one, player_two),
      tiebreak.TiebreakScore(player_one_points, player_two_points),
    ) -> {
      let games = for_player(player, player_one, player_two)
      let tiebreak_points = case games == 6 {
        True -> for_player(player, player_one_points, player_two_points)
        False -> 0
      }

      SetCell(int.to_string(games), case games == 6 {
        True -> int.to_string(tiebreak_points)
        False -> ""
      })
    }
  }
}

fn to_set_columns(cells: List(SetCell)) -> SetColumns {
  let empty = SetCell("–", "")

  case list.append(cells, [empty, empty, empty]) {
    [first, second, third, ..] -> SetColumns(first, second, third)
    _ -> SetColumns(empty, empty, empty)
  }
}

fn for_player(player: Player, player_one: value, player_two: value) -> value {
  case player {
    PlayerOne -> player_one
    PlayerTwo -> player_two
  }
}

fn point_scores(current_set: set.Set) -> #(String, String) {
  case set.current_game(current_set) {
    set.RegularGame(current_game) -> {
      let game.DisplayScore(player_one, player_two) =
        game.display_score(current_game)
      #(player_one, player_two)
    }

    set.Tiebreak(current_tiebreak) -> {
      let tiebreak.TiebreakScore(player_one, player_two) = current_tiebreak
      #(int.to_string(player_one), int.to_string(player_two))
    }
  }
}

fn player_name(player: Player) -> String {
  case player {
    PlayerOne -> "Player One"
    PlayerTwo -> "Player Two"
  }
}
