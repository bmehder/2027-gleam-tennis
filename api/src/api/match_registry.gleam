import api/match_id.{type MatchId}
import api/match_store
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/result

pub type CreatedMatch {
  CreatedMatch(id: MatchId, store: match_store.Store)
}

pub opaque type Registry {
  Registry(Subject(Message))
}

type State {
  State(next_id: Int, matches: Dict(String, match_store.Store))
}

type Message {
  Create(reply_with: Subject(Result(CreatedMatch, actor.StartError)))
  Find(id: MatchId, reply_with: Subject(Result(match_store.Store, Nil)))
}

pub fn start() -> Result(Registry, actor.StartError) {
  actor.new(State(next_id: 1, matches: dict.new()))
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { Registry(started.data) })
}

pub fn create(registry: Registry) -> Result(CreatedMatch, actor.StartError) {
  let Registry(subject) = registry
  process.call(subject, waiting: 1000, sending: Create)
}

pub fn find(registry: Registry, id: MatchId) -> Result(match_store.Store, Nil) {
  let Registry(subject) = registry
  process.call(subject, waiting: 1000, sending: fn(reply_with) {
    Find(id, reply_with)
  })
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  let State(next_id, matches) = state

  case message {
    Create(reply_with) ->
      case match_store.start() {
        Error(error) -> {
          process.send(reply_with, Error(error))
          actor.continue(state)
        }

        Ok(store) -> {
          let id = match_id.generate(next_id)
          let next_matches = dict.insert(matches, match_id.to_string(id), store)
          process.send(reply_with, Ok(CreatedMatch(id, store)))
          actor.continue(State(next_id + 1, next_matches))
        }
      }

    Find(id, reply_with) -> {
      process.send(reply_with, dict.get(matches, match_id.to_string(id)))
      actor.continue(state)
    }
  }
}
