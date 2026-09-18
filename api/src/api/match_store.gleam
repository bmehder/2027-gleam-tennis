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
  Undo(reply_with: Subject(Result(Snapshot, Nil)))
  Redo(reply_with: Subject(Result(Snapshot, Nil)))
}

type State {
  State(past: List(Player), future: List(Player))
}

pub fn start() -> Result(Store, actor.StartError) {
  actor.new(State(past: [], future: []))
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

pub fn undo(store: Store) -> Result(Snapshot, Nil) {
  let Store(subject) = store
  process.call(subject, waiting: 1000, sending: Undo)
}

pub fn redo(store: Store) -> Result(Snapshot, Nil) {
  let Store(subject) = store
  process.call(subject, waiting: 1000, sending: Redo)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  let State(past, future) = state

  case message {
    Current(reply_with) -> {
      process.send(reply_with, replay(past))
      actor.continue(state)
    }

    AwardPoint(player, reply_with) ->
      case replay(past) {
        Completed(_) -> {
          process.send(reply_with, Error(Nil))
          actor.continue(state)
        }

        InProgress(_) -> {
          let next_past = list.append(past, [player])
          process.send(reply_with, Ok(replay(next_past)))
          actor.continue(State(past: next_past, future: []))
        }
      }

    Undo(reply_with) ->
      case list.reverse(past) {
        [] -> {
          process.send(reply_with, Error(Nil))
          actor.continue(state)
        }
        [latest, ..remaining_reversed] -> {
          let next_past = list.reverse(remaining_reversed)
          process.send(reply_with, Ok(replay(next_past)))
          actor.continue(State(past: next_past, future: [latest, ..future]))
        }
      }

    Redo(reply_with) ->
      case future {
        [] -> {
          process.send(reply_with, Error(Nil))
          actor.continue(state)
        }
        [next, ..remaining] -> {
          let next_past = list.append(past, [next])
          process.send(reply_with, Ok(replay(next_past)))
          actor.continue(State(past: next_past, future: remaining))
        }
      }
  }
}

fn replay(points: List(Player)) -> Snapshot {
  list.fold(points, InProgress(match.initial()), advance)
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
