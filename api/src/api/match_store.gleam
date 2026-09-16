import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import gleam/result
import tennis/match
import tennis/player.{type Player}

pub type Snapshot {
  InProgress(match.Match)
  Completed(match.CompletedMatch)
}

pub opaque type Store {
  Store(Subject(Message))
}

type Message {
  Current(reply_with: Subject(Snapshot))
  AwardPoint(player: Player, reply_with: Subject(Result(Snapshot, Nil)))
}

pub fn start() -> Result(Store, actor.StartError) {
  actor.new([])
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { Store(started.data) })
}

pub fn current(store: Store) -> Snapshot {
  let Store(subject) = store
  process.call(subject, waiting: 1000, sending: Current)
}

pub fn point_won(store: Store, player: Player) -> Result(Snapshot, Nil) {
  let Store(subject) = store
  process.call(subject, waiting: 1000, sending: fn(reply_with) {
    AwardPoint(player, reply_with)
  })
}

fn handle_message(
  events: List(Player),
  message: Message,
) -> actor.Next(List(Player), Message) {
  case message {
    Current(reply_with) -> {
      process.send(reply_with, replay(events))
      actor.continue(events)
    }

    AwardPoint(player, reply_with) ->
      case replay(events) {
        Completed(_) -> {
          process.send(reply_with, Error(Nil))
          actor.continue(events)
        }

        InProgress(_) -> {
          let next_events = list.append(events, [player])
          process.send(reply_with, Ok(replay(next_events)))
          actor.continue(next_events)
        }
      }
  }
}

fn replay(events: List(Player)) -> Snapshot {
  list.fold(events, InProgress(match.initial()), advance)
}

fn advance(snapshot: Snapshot, player: Player) -> Snapshot {
  case snapshot {
    Completed(_) -> snapshot
    InProgress(current_match) ->
      case match.point_won(current_match, player) {
        match.MatchContinues(next_match) -> InProgress(next_match)
        match.MatchWon(completed_match) -> Completed(completed_match)
      }
  }
}
