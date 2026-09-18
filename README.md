# Lustre Tennis

A tennis scoring project built with [Gleam](https://gleam.run/), with a
[Lustre](https://lustre.build/) browser application and a small
[Mist](https://hexdocs.pm/mist/) REST API running on the BEAM.

- [Lustre application](https://2027-gleam-tennis.vercel.app/)
- [REST API demo](https://gleam-tennis-api.onrender.com/demo)
- [GitHub repository](https://github.com/bmehder/2027-gleam-tennis)

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
- Includes a multi-match REST API proof of concept running on the BEAM
- Accepts point events and returns the newly derived match as JSON
- Supports undo and redo through the API and its browser demo

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

The public vocabulary is consistent across the state machines:

- `game.point_won`, `tiebreak.point_won`, `set.point_won`, and
  `match.point_won` advance their respective states.
- `game.score`, `tiebreak.score`, and `set.score` expose the score appropriate
  to each level.
- `set.point_score` exposes either the regular-game score or tiebreak score
  currently shown within a set, without exposing the set's internal game.
- `set.winner` reads the winner from a completed set.

That naming is intentionally module-oriented. At a call site, `set.score(value)`
or `game.score(value)` says both which layer owns the operation and what is being
requested.

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

## Shared scoring across two targets

The repository now contains two applications built around one scoring library:

- The Lustre application compiles to JavaScript and runs in the browser.
- The REST API compiles to Erlang and runs on the BEAM with Mist.
- The target-neutral `tennis_scoring` package supplies the domain model to both.

The API is deliberately an in-memory proof of concept. A registry actor creates
an independent actor and ID for each match. Every match actor owns a timeline
with `past` and `future` point-winner events and handles requests one at a time.
Awarding a point appends it to `past` and clears `future`; undo and redo move an
event between the two sides. The actor replays `past` through `match.initial()`
to derive each response. It never serializes or mutates the opaque match value.

```text
match ID → registry → timeline actor → replay scoring rules → JSON response
```

This separation lets another UI use the same scoring behavior without depending
on Lustre. Database persistence, authentication, and event versioning are
intentionally outside the proof of concept.

## Project structure

```text
2027-lustre-tennis/          # JavaScript-targeted Lustre application
├── src/
│   ├── lustre_tennis.gleam
│   ├── time_travel.gleam
│   └── browser/
├── packages/
│   └── tennis_scoring/     # Target-neutral scoring library
│       ├── src/tennis/
│       └── test/tennis/
└── api/                    # Erlang-targeted Mist application
    ├── priv/
    │   └── demo.html
    ├── src/
    │   ├── tennis_api.gleam
    │   └── api/
    │       ├── match_id.gleam
    │       ├── match_registry.gleam
    │       ├── match_store.gleam
    │       ├── match_json.gleam
    │       └── server.gleam
    └── test/api/
```

The applications depend on `tennis_scoring` through local path dependencies.
The browser package therefore sees only browser dependencies, the API package
sees only BEAM dependencies, and the scoring package can be tested on either
target without either application.

## Requirements

The project currently uses:

- Gleam 1.18.1
- Bun 1.4.2 for Lustre's JavaScript bundle and JavaScript-targeted tests
- Erlang/OTP for the API and Erlang-targeted scoring tests

The Docker image used for deployment pins Gleam 1.18.1 and includes its Erlang
runtime. Local development requires Gleam and Erlang; Bun is also required to
build or run the Lustre application with this repository's configuration.

## Development

Start the Lustre development server:

```sh
gleam run -m lustre/dev start
```

Run the tests:

```sh
gleam test
```

This exercises the Lustre application and browser-facing timeline logic.

Run the scoring-library tests from `packages/tennis_scoring`:

```sh
gleam test --target javascript --runtime bun
gleam test --target erlang
```

Running the scoring tests on both targets verifies that the shared domain model
behaves the same when compiled to JavaScript and Erlang.

Run the API tests or start the local API from `api`:

```sh
gleam test
gleam run
```

The API uses port `4000` locally. When `PORT` is present, it uses that value
instead so it can run as a Render web service.

With the API running, create a match, read it, award a point, or move through
its timeline:

```sh
curl -X POST http://localhost:4000/matches

curl http://localhost:4000/matches/match-1

curl -X POST \
  -H "content-type: application/json" \
  -d '{"winner":"player_two"}' \
  http://localhost:4000/matches/match-1/points

curl -X POST http://localhost:4000/matches/match-1/undo

curl -X POST http://localhost:4000/matches/match-1/redo
```

Restarting the API resets its in-memory timelines.

The proof-of-concept API permits cross-origin `GET` and `POST` requests and
responds to browser `OPTIONS` preflight requests. A UI served from another local
development server—or opened directly as an HTML file—can therefore call it at
`http://localhost:4000` without additional proxy configuration.

A dependency-free client is packaged at `api/priv/demo.html` and served by the
API at `/demo`. It currently calls the deployed Render API, including when the
HTML is served by a local API process. Match creation is explicit, and a second
browser window can load the displayed match ID to interact with the same match
actor.

The deployed proof of concept is available at:

- [Browser demo](https://gleam-tennis-api.onrender.com/demo)
- [Health check](https://gleam-tennis-api.onrender.com/health)

The API routes are:

```text
GET  /health
GET  /demo
POST /matches
GET  /matches/:id
POST /matches/:id/points
POST /matches/:id/undo
POST /matches/:id/redo
```

Creating a match returns its generated ID and initial snapshot:

```json
{
  "id": "match-1",
  "match": {
    "status": "in_progress",
    "server": "player_one",
    "sets": [],
    "games": { "player_one": 0, "player_two": 0 },
    "phase": "regular_game",
    "points": { "player_one": "0", "player_two": "0" },
    "winner": null
  }
}
```

Reading a match, awarding a point, undoing, and redoing return the updated match
snapshot directly. Completed snapshots set `server`, `games`, `phase`, and
`points` to `null`, populate `winner`, and retain the completed sets.

The API uses conventional response statuses:

- `201 Created` when a match is created
- `200 OK` for a successful read, point, undo, or redo
- `204 No Content` for a CORS preflight request
- `400 Bad Request` for an invalid point-winner body
- `404 Not Found` for an unknown route or match ID
- `409 Conflict` when a match is complete or no undo/redo move is available

The API and browser app deliberately have different persistence behavior. The
Lustre app stores its timeline in the browser and can import or export it. API
matches live only in BEAM actors and disappear whenever the API process stops.

## Verification

A useful manual smoke test for the Lustre application is to score regular
games, reach a 6–6 tiebreak, complete a best-of-three match, move backward and
forward across game or set boundaries, reload the page, and export then import
the timeline.

For the API, create two matches, award points independently, complete a game to
confirm that the server changes, undo and redo across that game boundary, then
award a different point after undoing to confirm that the redo path is cleared.
The automated suites cover the detailed game, tiebreak, set, match, timeline,
actor, registry, and JSON behavior.

## Deploying the API to Render

The repository includes a Dockerfile and Render Blueprint for the Erlang API.
In Render, create a new Blueprint, select this repository, and deploy the
`gleam-tennis-api` service on the Free plan. Render builds the container,
checks `/health`, and assigns the API an `onrender.com` URL.

The free service sleeps after a period without traffic. Matches are currently
held in memory, so they are reset whenever Render sleeps, restarts, or redeploys
the service. This is intentional for the proof of concept.

Create the static site in `dist`:

```sh
gleam run -m lustre/dev build
```

The generated `dist` directory can be served by any static host. This project
uses Vercel with the framework preset set to **Other** and the output directory
set to `dist`.
