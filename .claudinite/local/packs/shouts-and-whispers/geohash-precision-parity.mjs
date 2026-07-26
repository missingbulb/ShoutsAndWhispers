// RULES.md §"Two encoders, one contract": presence geohashes are written by the
// Flutter client (app/lib/geo/geohash.dart, hand-rolled) and read back by the
// Cloud Function's geohash range queries (geofire-common). The two only meet if
// they encode at the SAME precision — a 9-char client hash never falls inside the
// bounds of a 10-char server query, so a precision changed on one side alone
// makes sendMessage find nobody, silently, with every test still green.
//
// The precision is a literal at the call sites, so it is a static signature and
// converts to a check; that the two ENCODERS agree character-for-character is not
// static and stays prose plus the known-vector suites both tiers commit.
//
// Dependency-free by design (a local pack's checks must load without the shared
// mount): it builds plain finding objects instead of importing the engine helper.

// `geohash.encode(p.lat, p.lng, precision: 9)` in the Flutter client.
const DART_CALL = /\bencode\s*\(([^)]*)precision:\s*(\d+)\s*\)/g;
// `geohashForLocation([lat, lng], 9)` in the Cloud Functions source.
const TS_CALL = /\bgeohashForLocation\s*\(\s*\[[^\]]*\]\s*,\s*(\d+)\s*\)/g;

const DART_ROOT = 'app/lib/';
const TS_ROOT = 'firebase/functions/src/';

const rule = {
  id: 'shouts-and-whispers/geohash-precision-parity',
  severity: 'blocking',
  description: 'The client heartbeat and the Cloud Functions encode presence geohashes at the same precision',
  doc: '.claudinite/local/packs/shouts-and-whispers/RULES.md',
  why: 'the server queries presence by geohash range, so a precision that differs from the one the client wrote makes every range query miss its recipients — no error, no failing test, just messages delivered to nobody',

  run(ctx) {
    const out = [];
    const say = (file, line, what, fix) => out.push({
      rule: rule.id, severity: rule.severity, file, line,
      what, why: rule.why, fix, doc: rule.doc,
    });

    const client = sites(ctx, (f) => f.startsWith(DART_ROOT) && f.endsWith('.dart'), DART_CALL, 2);
    const server = sites(ctx, (f) => f.startsWith(TS_ROOT) && f.endsWith('.ts'), TS_CALL, 1);

    // Staleness guard, the idiom app/test/import_boundary_test.dart already uses:
    // if either side's call site has moved out of the scanned tree the guard is
    // no longer guarding anything, and that must be loud.
    if (!client.length || !server.length) {
      say(
        !client.length ? `${DART_ROOT}geo/geohash.dart` : `${TS_ROOT}index.ts`,
        null,
        `no explicit geohash precision found under ${!client.length ? DART_ROOT : TS_ROOT} — the parity guard has nothing to compare`,
        'keep the precision an explicit literal at the encode call site (never an implicit library default), or point the guard at its new home',
      );
      return out;
    }

    const values = [...new Set([...client, ...server].map((s) => s.precision))];
    if (values.length > 1) {
      const where = [...client, ...server]
        .map((s) => `${s.file}:${s.line} → ${s.precision}`)
        .join(', ');
      for (const site of server) {
        say(
          site.file, site.line,
          `presence geohash precision disagrees across the tiers (${where})`,
          'encode at one precision on both sides (DESIGN.md §3 fixes it at 9), and extend the known-vector tests on both tiers to the new precision',
        );
      }
    }

    return out;
  },
};

function sites(ctx, matches, pattern, group) {
  const found = [];
  for (const file of ctx.files.filter(matches)) {
    const text = ctx.read(file);
    if (text === null) continue;
    pattern.lastIndex = 0;
    let m;
    while ((m = pattern.exec(text)) !== null) {
      found.push({
        file,
        line: text.slice(0, m.index).split('\n').length,
        precision: Number(m[group]),
      });
    }
  }
  return found;
}

export default rule;
