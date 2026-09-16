import gleam/int
import gleam/json
import tennis/game
import tennis/match
import tennis/player.{type Player, PlayerOne, PlayerTwo}
import tennis/set
import tennis/tiebreak

pub fn in_progress(current_match: match.Match) -> json.Json {
  let current_set = match.current_set(current_match)
  let set.SetScore(player_one_games, player_two_games) = set.score(current_set)
  let #(phase, player_one_points, player_two_points) =
    point_score(set.current_game(current_set))

  json.object([
    #("status", json.string("in_progress")),
    #("server", player(match.server(current_match))),
    #(
      "sets",
      json.array(match.completed_sets(current_match), of: completed_set),
    ),
    #(
      "games",
      player_scores(json.int(player_one_games), json.int(player_two_games)),
    ),
    #("phase", json.string(phase)),
    #(
      "points",
      player_scores(
        json.string(player_one_points),
        json.string(player_two_points),
      ),
    ),
    #("winner", json.null()),
  ])
}

pub fn completed(completed_match: match.CompletedMatch) -> json.Json {
  let match.CompletedMatch(winner, sets) = completed_match

  json.object([
    #("status", json.string("completed")),
    #("server", json.null()),
    #("sets", json.array(sets, of: completed_set)),
    #("games", json.null()),
    #("phase", json.null()),
    #("points", json.null()),
    #("winner", player(winner)),
  ])
}

fn completed_set(completed: set.CompletedSet) -> json.Json {
  case completed {
    set.RegularSet(winner, score) ->
      set_score("regular", winner, score, json.null())

    set.TiebreakSet(winner, score, tiebreak_score) ->
      set_score("tiebreak", winner, score, tiebreak_json(tiebreak_score))
  }
}

fn set_score(
  kind: String,
  winner: Player,
  score: set.SetScore,
  tiebreak_score: json.Json,
) -> json.Json {
  let set.SetScore(player_one, player_two) = score

  json.object([
    #("kind", json.string(kind)),
    #("winner", player(winner)),
    #("games", player_scores(json.int(player_one), json.int(player_two))),
    #("tiebreak", tiebreak_score),
  ])
}

fn point_score(current_game: set.CurrentGame) -> #(String, String, String) {
  case current_game {
    set.RegularGame(current_game) -> {
      let game.GameScoreText(player_one, player_two) =
        game.score_text(current_game)
      #("regular_game", player_one, player_two)
    }

    set.Tiebreak(tiebreak.TiebreakScore(player_one, player_two)) -> #(
      "tiebreak",
      int.to_string(player_one),
      int.to_string(player_two),
    )
  }
}

fn tiebreak_json(score: tiebreak.TiebreakScore) -> json.Json {
  let tiebreak.TiebreakScore(player_one, player_two) = score
  player_scores(json.int(player_one), json.int(player_two))
}

fn player_scores(player_one: json.Json, player_two: json.Json) -> json.Json {
  json.object([
    #("player_one", player_one),
    #("player_two", player_two),
  ])
}

fn player(player: Player) -> json.Json {
  case player {
    PlayerOne -> json.string("player_one")
    PlayerTwo -> json.string("player_two")
  }
}
