// The project's own pack: the cross-tier delivery contract of Shouts & Whispers
// — the invariants that hold between the Flutter client and the Cloud Functions
// and that no canon pack owns (flutter/firebase/node cover their platforms,
// spec-driven-product and executable-requirements cover the loop and the spec
// harness; none of them knows that a presence geohash written by one tier is
// range-queried by the other).
//
// A local pack is declared by hand, never fingerprinted or seeded, so `detect`
// and `marker` stay null; it activates from the `local/shouts-and-whispers`
// token in .claudinite-checks.json.
import crossTierConstants from './cross-tier-constants.mjs';
import geohashPrecisionParity from './geohash-precision-parity.mjs';

export default {
  id: 'shouts-and-whispers',
  detect: null,
  marker: null,
  prose: 'RULES.md',
  rules: [crossTierConstants, geohashPrecisionParity],
};
