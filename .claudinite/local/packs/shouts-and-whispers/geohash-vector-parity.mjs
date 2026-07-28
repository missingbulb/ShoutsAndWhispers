// RULES.md §"Two encoders, one contract": the client's hand-rolled encoder
// (app/lib/geo/geohash.dart) and the server's geofire-common must produce
// IDENTICAL strings, and the only thing standing behind that claim is a pair of
// known-vector suites that carry the SAME vectors deliberately —
// app/test/geohash_test.dart and firebase/functions/test/geohash-compat.test.ts.
//
// The claim is only as good as the overlap. Add a vector to one suite and not
// the other and both suites still pass, on both tiers, forever: the new
// coordinate is asserted against one encoder and nothing compares it to the
// other. Nothing in either toolchain can see it — the files are in different
// languages, run by different runners, in different CI jobs.
//
// This is the "extending one vector list means extending the other" half of the
// section, and it is a static signature: two committed tables of literals that
// must agree, the same shape as this pack's cross-tier-constants guard. It does
// NOT check that the encoders agree — that is runtime behaviour, is what the
// suites themselves are for, and stays prose.
//
// Detection parses rather than greps: it reads only the assertions written at
// the shared production precision 9 (the client's default-precision `encode`
// calls, the server's explicit `geohashForLocation([lat, lng], 9)` calls), so
// the deliberately unpaired vectors — the client's precision 1/5/11/12 cases,
// the server's 10-char default-precision cases — are not mistaken for drift.
//
// Dependency-free by design (a local pack's checks must load without the shared
// mount): it builds plain finding objects instead of importing the engine helper.

const DART_FILE = 'app/test/geohash_test.dart';
const TS_FILE = 'firebase/functions/test/geohash-compat.test.ts';

// `expect(encode(57.64911, 10.40744), 'u4pruydqq');` — the two-argument form
// only, which is precision 9 by default (DESIGN.md §3). A call carrying an
// explicit `precision:` has a third argument and is deliberately not matched.
const DART_VECTOR =
  /expect\(\s*encode\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*'([0-9a-z]+)'\s*\)/g;
// `expect(geohashForLocation([57.64911, 10.40744], 9)).toBe('u4pruydqq');` — the
// explicit precision-9 form only; the default-precision calls encode 10 chars
// and have no client counterpart.
const TS_VECTOR =
  /expect\(\s*geohashForLocation\(\s*\[\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\]\s*,\s*9\s*\)\s*\)\s*\.toBe\(\s*'([0-9a-z]+)'\s*\)/g;

const rule = {
  id: 'shouts-and-whispers/geohash-vector-parity',
  severity: 'blocking',
  description: 'The two tiers\' known-vector geohash suites carry the same precision-9 vectors',
  doc: '.claudinite/local/packs/shouts-and-whispers/RULES.md',
  why: 'the paired suites are the only evidence that the client\'s hand-rolled encoder and the server\'s geofire-common agree; a vector asserted on one side alone is a coordinate nobody ever compared, and both suites stay green while the compatibility claim quietly stops covering it',

  run(ctx) {
    const out = [];
    const say = (file, line, what, fix) => out.push({
      rule: rule.id, severity: rule.severity, file, line,
      what, why: rule.why, fix, doc: rule.doc,
    });

    const dartText = ctx.read(DART_FILE);
    const tsText = ctx.read(TS_FILE);

    // Staleness guard, the idiom the pack's other checks already use: a guard
    // that quietly stops finding its subject is worse than no guard.
    if (dartText === null || tsText === null) {
      const missing = dartText === null ? DART_FILE : TS_FILE;
      say(missing, null,
        `the geohash vector parity guard cannot read ${missing}`,
        'restore the suite, or point the guard at its new home (the paths live at the top of the pack\'s geohash-vector-parity.mjs)');
      return out;
    }

    const dart = vectors(dartText, DART_VECTOR);
    const ts = vectors(tsText, TS_VECTOR);

    if (!dart.size || !ts.size) {
      const empty = !dart.size ? DART_FILE : TS_FILE;
      say(empty, null,
        `no precision-9 known vectors found in ${empty} — the parity guard has nothing to compare`,
        'keep the shared vectors as literal precision-9 assertions in both suites (the client\'s default-precision `encode`, the server\'s explicit `geohashForLocation([lat, lng], 9)`), or point the guard at its new home');
      return out;
    }

    for (const [coord, near] of pairwise(dart, ts)) {
      const other = near.opposite.get(coord);

      if (other === undefined) {
        const [have, want] = near.side === 'dart' ? [DART_FILE, TS_FILE] : [TS_FILE, DART_FILE];
        say(want, null,
          `${have} asserts (${coord}) → '${near.hash}' at precision 9, but ${want} carries no precision-9 vector for that coordinate`,
          `add the same coordinate to ${want} — the suites are the compatibility contract, so a vector only one tier asserts proves nothing about the other`);
        continue;
      }

      if (other.hash !== near.hash && near.side === 'dart') {
        say(TS_FILE, other.line,
          `the suites disagree on (${coord}): ${DART_FILE} expects '${near.hash}', ${TS_FILE} expects '${other.hash}'`,
          'the two encoders must produce identical strings, so one of these expectations is wrong — recompute the vector and fix the suite that is stale, never loosen one to match the other');
      }
    }

    return out;
  },
};

// coordinate key → { hash, line }, for every vector asserted at precision 9.
function vectors(text, pattern) {
  const found = new Map();
  pattern.lastIndex = 0;
  let m;
  while ((m = pattern.exec(text)) !== null) {
    // Compare coordinates as numbers, not spelling: 0 and 0.0 are one point.
    const key = `${Number(m[1])}, ${Number(m[2])}`;
    if (!found.has(key)) {
      found.set(key, { hash: m[3], line: text.slice(0, m.index).split('\n').length });
    }
  }
  return found;
}

// Every vector from both sides, tagged with the side it came from and handed
// the opposite side's table, so one loop covers "missing on the server",
// "missing on the client", and "the two expectations differ".
function* pairwise(dart, ts) {
  for (const [coord, v] of dart) yield [coord, { ...v, side: 'dart', opposite: ts }];
  for (const [coord, v] of ts) yield [coord, { ...v, side: 'ts', opposite: dart }];
}

export default rule;
