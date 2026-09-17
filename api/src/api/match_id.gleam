import gleam/int

pub opaque type MatchId {
  MatchId(String)
}

pub fn generate(number: Int) -> MatchId {
  MatchId("match-" <> int.to_string(number))
}

pub fn from_string(value: String) -> MatchId {
  MatchId(value)
}

pub fn to_string(id: MatchId) -> String {
  let MatchId(value) = id
  value
}
