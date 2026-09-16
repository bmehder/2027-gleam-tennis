import gleam/int
import gleam/list
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event
import persistence
import tennis/game
import tennis/match
import tennis/player.{type Player, PlayerOne, PlayerTwo}
import tennis/set
import tennis/tiebreak

type MatchState {
  Playing(match.Match)
  Finished(match.CompletedMatch)
}

type Model {
  Model(state: MatchState, past: List(Player), future: List(Player))
}

type Msg {
  UserAwardedPoint(Player)
  UserChoseUndo
  UserChoseRedo
  UserStartedNewMatch
  StoredHistoryLoaded(persistence.History)
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
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#tennis-match", Nil)
  Nil
}

fn init(_arguments) -> #(Model, Effect(Msg)) {
  #(
    Model(Playing(match.initial()), [], []),
    effect.from(fn(dispatch) {
      persistence.load()
      |> StoredHistoryLoaded
      |> dispatch
    }),
  )
}

fn update(model: Model, message: Msg) -> #(Model, Effect(Msg)) {
  let Model(state, past, _future) = model

  case state, message {
    Playing(_), UserAwardedPoint(player) -> {
      let next_past = list.append(past, [player])
      let next_model = Model(award_point(state, player), next_past, [])
      #(next_model, save_history(next_past, []))
    }

    Finished(_), UserAwardedPoint(_) -> #(model, effect.none())

    _, UserChoseUndo -> undo(model)

    _, UserChoseRedo -> redo(model)

    _, UserStartedNewMatch -> #(
      Model(Playing(match.initial()), [], []),
      effect.from(fn(_) { persistence.clear() }),
    )

    _, StoredHistoryLoaded(persistence.History(stored_past, stored_future)) -> #(
      replay(stored_past, stored_future),
      effect.none(),
    )
  }
}

fn view(model: Model) -> Element(Msg) {
  let Model(state, past, future) = model
  let scoreboard = case state {
    Playing(current_match) -> to_playing_scoreboard(current_match)
    Finished(completed_match) -> to_finished_scoreboard(completed_match)
  }

  view_scoreboard(scoreboard, !list.is_empty(past), !list.is_empty(future))
}

fn award_point(state: MatchState, player: Player) -> MatchState {
  case state {
    Playing(current_match) ->
      case match.point_won(current_match, player) {
        match.MatchContinues(next_match) -> Playing(next_match)
        match.MatchWon(completed_match) -> Finished(completed_match)
      }

    Finished(_) -> state
  }
}

fn replay(past: List(Player), future: List(Player)) -> Model {
  let state = list.fold(past, Playing(match.initial()), award_point)
  Model(state, past, future)
}

fn undo(model: Model) -> #(Model, Effect(Msg)) {
  let Model(_, past, future) = model

  case list.reverse(past) {
    [] -> #(model, effect.none())
    [point, ..remaining_reversed] -> {
      let next_past = list.reverse(remaining_reversed)
      let next_future = [point, ..future]
      #(replay(next_past, next_future), save_history(next_past, next_future))
    }
  }
}

fn redo(model: Model) -> #(Model, Effect(Msg)) {
  let Model(_, past, future) = model

  case future {
    [] -> #(model, effect.none())
    [point, ..remaining] -> {
      let next_past = list.append(past, [point])
      #(replay(next_past, remaining), save_history(next_past, remaining))
    }
  }
}

fn save_history(past: List(Player), future: List(Player)) -> Effect(Msg) {
  effect.from(fn(_) { persistence.save(persistence.History(past, future)) })
}

fn view_scoreboard(
  scoreboard: Scoreboard,
  can_undo: Bool,
  can_redo: Bool,
) -> Element(Msg) {
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
    history_controls(can_undo, can_redo),
    repository_link(),
  ])
}

fn repository_link() -> Element(Msg) {
  html.a(
    [
      attribute.class("repository-link"),
      attribute.href("https://github.com/bmehder/2027-gleam-tennis"),
      attribute.target("_blank"),
      attribute.rel("noopener noreferrer"),
      attribute.aria_label("View the source code on GitHub"),
    ],
    [
      svg.svg(
        [
          attribute.attribute("viewBox", "0 0 24 24"),
          attribute.attribute("aria-hidden", "true"),
        ],
        [
          svg.path([
            attribute.attribute(
              "d",
              "M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.093.682-.217.682-.483 0-.237-.009-.866-.014-1.699-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.221-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.295 2.747-1.026 2.747-1.026.546 1.377.203 2.394.1 2.647.64.7 1.028 1.595 1.028 2.688 0 3.848-2.337 4.695-4.566 4.943.359.31.678.921.678 1.856 0 1.34-.012 2.421-.012 2.75 0 .268.18.58.688.481A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2Z",
            ),
          ]),
        ],
      ),
    ],
  )
}

fn history_controls(can_undo: Bool, can_redo: Bool) -> Element(Msg) {
  html.div([attribute.class("history-controls")], [
    html.button([attribute.disabled(!can_undo), event.on_click(UserChoseUndo)], [
      html.text("Undo"),
    ]),
    html.button([attribute.disabled(!can_redo), event.on_click(UserChoseRedo)], [
      html.text("Redo"),
    ]),
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
      let game.GameScoreText(player_one, player_two) =
        game.score_text(current_game)
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
