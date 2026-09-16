# Lustre Tennis

A browser-based tennis scoring app built with [Gleam](https://gleam.run/) and
[Lustre](https://lustre.build/).

This is the third version of the same idea. Earlier versions were written in
Elm and in TypeScript with fp-ts. Rebuilding it in Gleam was an experiment in
how clearly a small but rule-heavy domain could be modeled without sacrificing
correctness or maintainability.

## What it does

- Scores a best-of-three tennis match
- Handles regular games, deuce, and advantage
- Handles sets and 6–6 tiebreaks
- Tracks the server through games, tiebreaks, and sets
- Assumes Player One serves first in the match
- Persists the match in browser local storage
- Supports persistent undo and redo
- Imports and exports the time-travel timeline as JSON files
- Displays the completed match and starts a new one

## The modeling approach

The app is organized as a series of small state machines:

```text
Match → Set → Game or Tiebreak
```

Each module owns the rules for one level and reports a meaningful result to the
level above it. For example, awarding a point to a regular game produces either
a continuing game or a winner:

```gleam
pub type GameResult {
  GameContinues(Game)
  GameWon(Player)
}
```

A playable `Game` cannot also be a completed game. The same idea is repeated at
the set and match levels. This keeps callers from inspecting internal details or
reimplementing lower-level rules.

Opaque types strengthen those boundaries. A `Set` or `Match` can only be
created and advanced through its module's public functions, so outside code
cannot construct an impossible internal state.

The `Set` module is intentionally the busiest part of the domain. It coordinates
regular games and tiebreaks, updates the game count, changes servers, and decides
whether to begin another game, begin a tiebreak, or complete the set. `Match`
then stays small because it only needs to coordinate completed sets.

## From `lustre.simple` to `lustre.application`

The first working version used `lustre.simple`. At that stage, every message
could be handled by returning a new model:

```text
update: Model + Msg → Model
```

Local storage introduced communication with the outside world. Importing and
exporting files added more of the same. Those operations are effects, so the app
moved to `lustre.application`:

```text
update: Model + Msg → #(Model, Effect(Msg))
```

The update function still decides what should happen, but browser work is
described as an `Effect` and performed by the Lustre runtime. An effect can later
dispatch another message, such as `StoredTimelineLoaded` or `ImportedFileRead`,
and that message returns through the normal update loop.

This keeps the architecture explicit:

- The model contains application state.
- Messages describe events.
- Update performs deterministic state transitions and requests effects.
- Effects cross browser boundaries and report their results as messages.
- The view renders the current model.

`lustre.simple` was not a prototype that had to be discarded. It was the right
API while the application had no effects; `lustre.application` became the right
API when the application gained them.

## Persistence and time travel

The app does not serialize the opaque match model. It stores a timeline of point
winners instead:

```json
{
  "past": ["player_one", "player_two"],
  "future": ["player_one"]
}
```

When the page loads—or when the user undoes or redoes a point—the timeline is
replayed through the same domain functions used during normal scoring. That
means restored state is subject to the same rules as live state.

This event timeline also made undo and redo straightforward:

- Undo moves the latest point from `past` to `future`.
- Redo moves the next point from `future` back to `past`.
- Awarding a new point after an undo clears `future` and creates a new timeline.

Browser storage and file access are isolated in small JavaScript FFI files.
JSON encoding, decoding, validation, and storage policy remain in Gleam. The
timeline format is independent of local storage, so the same representation is
used for persistence, import, export, and tests.

## What we learned from the three versions

All three implementations can model the domain well, but they arrive there in
different ways.

| | Elm | TypeScript with fp-ts | Gleam |
|---|---|---|---|
| Algebraic data types | Native and especially concise | Encoded with TypeScript unions and conventions | Native and concise |
| Exhaustive pattern matching | Native | Requires TypeScript narrowing and careful construction | Native |
| Invalid state prevention | Excellent | Possible, but involves more type-level and library machinery | Excellent |
| Effects and UI architecture | Built into The Elm Architecture | Assembled from TypeScript and fp-ts abstractions | Lustre provides an Elm-like model/update/view structure |
| Escape hatches | Very few | Type assertions and untyped JavaScript can bypass guarantees | Normal Gleam code is strict; JavaScript FFI is the trust boundary |

Elm remains exceptionally elegant for this style of browser application. Its
syntax and type inference make domain modeling feel almost minimal.

The TypeScript/fp-ts version demonstrated that the same architecture is
possible in the JavaScript ecosystem, but more effort goes into recovering
ideas that Elm and Gleam provide directly: tagged alternatives, exhaustive
handling, immutable transformations, and explicit effects. TypeScript's
structural types and assertions also leave more ways to weaken the model.

Gleam landed close to Elm's clarity while remaining comfortable at JavaScript
boundaries. Custom types, pattern matching, inference, and opaque module types
were sufficient; the domain did not need a large supporting abstraction layer.
The result felt more direct than the TypeScript/fp-ts version without giving up
the guarantees that motivated it.

The larger lesson was architectural rather than language-specific: let each
layer own its valid states and return explicit outcomes. When that boundary is
right, the module above it becomes simpler. `Match` is small because `Set`
already knows how a set ends, and the Lustre application stays focused on UI,
persistence, and translating domain state for display.

## Project structure

```text
src/
├── lustre_tennis.gleam    # Lustre model, update, view, and presentation data
├── time_travel.gleam     # Reusable timeline type and JSON format
├── browser/
│   ├── local_storage.gleam
│   ├── local_storage_ffi.mjs
│   ├── file_transfer.gleam
│   └── file_transfer_ffi.mjs
└── tennis/
    ├── player.gleam
    ├── game.gleam
    ├── tiebreak.gleam
    ├── set.gleam
    └── match.gleam

test/
├── time_travel_test.gleam
└── tennis/
    ├── game_test.gleam
    ├── tiebreak_test.gleam
    ├── set_test.gleam
    └── match_test.gleam
```

## Development

Start the Lustre development server:

```sh
gleam run -m lustre/dev start
```

Run the tests:

```sh
gleam test
```

Create the static site in `dist`:

```sh
gleam run -m lustre/dev build
```

The generated `dist` directory can be served by any static host. This project
uses Vercel with the framework preset set to **Other** and the output directory
set to `dist`.
