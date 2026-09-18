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
  let #(phase, points) = point_score_json(set.point_score(current_set))

  json.object([
    #("status", json.string("in_progress")),
    #("server", player_json(match.server(current_match))),
    #(
      "sets",
      json.array(match.completed_sets(current_match), of: completed_set_json),
    ),
    #(
      "games",
      player_scores_json(json.int(player_one_games), json.int(player_two_games)),
    ),
    #("phase", json.string(phase)),
    #("points", points),
    #("winner", json.null()),
  ])
}

pub fn completed(completed_match: match.CompletedMatch) -> json.Json {
  let match.CompletedMatch(winner, sets) = completed_match

  json.object([
    #("status", json.string("completed")),
    #("server", json.null()),
    #("sets", json.array(sets, of: completed_set_json)),
    #("games", json.null()),
    #("phase", json.null()),
    #("points", json.null()),
    #("winner", player_json(winner)),
  ])
}

fn completed_set_json(completed: set.CompletedSet) -> json.Json {
  case completed {
    set.RegularSet(winner, score) ->
      set_json("regular", winner, score, json.null())

    set.TiebreakSet(winner, score, tiebreak_score) ->
      set_json("tiebreak", winner, score, tiebreak_score_json(tiebreak_score))
  }
}

fn set_json(
  kind: String,
  winner: Player,
  score: set.SetScore,
  tiebreak_score: json.Json,
) -> json.Json {
  let set.SetScore(player_one, player_two) = score

  json.object([
    #("kind", json.string(kind)),
    #("winner", player_json(winner)),
    #("games", player_scores_json(json.int(player_one), json.int(player_two))),
    #("tiebreak", tiebreak_score),
  ])
}

fn point_score_json(point_score: set.PointScore) -> #(String, json.Json) {
  case point_score {
    set.RegularGame(game.GameScoreText(player_one, player_two)) -> {
      #(
        "regular_game",
        player_scores_json(json.string(player_one), json.string(player_two)),
      )
    }

    set.Tiebreak(tiebreak.TiebreakScore(player_one, player_two)) -> #(
      "tiebreak",
      player_scores_json(
        json.string(int.to_string(player_one)),
        json.string(int.to_string(player_two)),
      ),
    )
  }
}

fn tiebreak_score_json(score: tiebreak.TiebreakScore) -> json.Json {
  let tiebreak.TiebreakScore(player_one, player_two) = score
  player_scores_json(json.int(player_one), json.int(player_two))
}

fn player_scores_json(
  player_one: json.Json,
  player_two: json.Json,
) -> json.Json {
  json.object([
    #("player_one", player_one),
    #("player_two", player_two),
  ])
}

fn player_json(player: Player) -> json.Json {
  case player {
    PlayerOne -> json.string("player_one")
    PlayerTwo -> json.string("player_two")
  }
}
