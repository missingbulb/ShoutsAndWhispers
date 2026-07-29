// The repo's second local pack: how an unattended Claudinite run conducts
// itself *in this repo* — what a scheduled task's executor and its dispatched
// subagent must do before they author work and before they write to GitHub.
//
// Deliberately NOT the `shouts-and-whispers` pack: that one is the cross-tier
// delivery contract between the Flutter client and the Cloud Functions, and its
// prose loads into every session as the product's invariants. Agent-conduct
// rules mixed in there would dilute it. Deliberately not the mounted canon
// either (.claudinite/shared/packs/grow_with_claudinite/) — that is read-only
// here; a lesson that turns out to travel gets lifted centrally by the growth
// promote stage.
//
// Prose-only by construction: these rules are about what an agent does at run
// time against the GitHub API, which no static check over the repo's files can
// observe. If one of them ever acquires a file-visible signature, it descends
// the ladder to a check here.
//
// A local pack is declared by hand, never fingerprinted or seeded, so `detect`
// and `marker` stay null; it activates from the `local/claudinite-runs` token
// in .claudinite-checks.json.
export default {
  id: 'claudinite-runs',
  detect: null,
  marker: null,
  prose: 'RULES.md',
  rules: [],
};
