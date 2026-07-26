// RULES.md §"One table, two copies": the delivery constants that both tiers must
// agree on live in docs/DESIGN.md §10 and are copied into the server's
// constants.ts and the client's config.dart — files that cannot share an import
// (TypeScript and Dart). This guard compares the copies BY NAME PAIR, so a value
// changed on one side and forgotten on the other is a finding rather than a
// production bug that only shows up as messages silently not delivered.
//
// Why not the canon `shared-constants` guard: that one counts occurrences of a
// declared literal per file. Here the literals collide as substrings ("150" is
// inside "1500"), the paired identifiers differ by language convention
// (WHISPER_RADIUS_M / whisperRadiusM), and a value only stays guarded as long as
// someone remembers to declare it. Pairing the declarations by name needs no
// per-value upkeep and reads the same table docs/DESIGN.md §10 publishes.
//
// Dependency-free by design (a local pack's checks must load without the shared
// mount): it builds plain finding objects instead of importing the engine helper.

const SERVER_FILE = 'firebase/functions/src/constants.ts';
const CLIENT_FILE = 'app/lib/config.dart';
const DESIGN_FILE = 'docs/DESIGN.md';

// The cross-tier constants: server name ↔ client name. A server-only constant
// (PRESENCE_TTL_MS, SEND_COOLDOWN_MS) or a client-only one (the heartbeat
// cadence) has no pair and is deliberately absent — only values BOTH tiers
// carry can drift apart.
const PAIRS = [
  { server: 'WHISPER_RADIUS_M', client: 'whisperRadiusM' },
  { server: 'SHOUT_RADIUS_M', client: 'shoutRadiusM' },
  { server: 'MAX_TEXT_LEN', client: 'maxTextLen' },
  { server: 'REGION', client: 'functionsRegion' },
];

const rule = {
  id: 'shouts-and-whispers/cross-tier-constants',
  severity: 'blocking',
  description: 'The delivery constants the client and the Cloud Functions both carry hold the same value, and match docs/DESIGN.md §10',
  doc: '.claudinite/local/packs/shouts-and-whispers/RULES.md',
  why: 'the two tiers cannot share an import, so a radius or limit changed on one side and forgotten on the other compiles, passes every test, and only shows up as messages quietly reaching the wrong people',

  run(ctx) {
    const out = [];
    const say = (file, what, fix) => out.push({
      rule: rule.id, severity: rule.severity, file, line: null,
      what, why: rule.why, fix, doc: rule.doc,
    });

    const serverText = ctx.read(SERVER_FILE);
    const clientText = ctx.read(CLIENT_FILE);
    const designText = ctx.read(DESIGN_FILE);

    // Staleness guard, the idiom app/test/import_boundary_test.dart already uses:
    // a guard that quietly stops finding its subject is worse than no guard.
    if (serverText === null || clientText === null) {
      say(
        serverText === null ? SERVER_FILE : CLIENT_FILE,
        `the cross-tier constants guard cannot read ${serverText === null ? SERVER_FILE : CLIENT_FILE}`,
        'restore the file, or point the guard at its new home (the paths live at the top of the pack\'s cross-tier-constants.mjs)',
      );
      return out;
    }

    for (const pair of PAIRS) {
      const server = serverValue(serverText, pair.server);
      const client = clientValue(clientText, pair.client);

      if (server === null || client === null) {
        say(
          server === null ? SERVER_FILE : CLIENT_FILE,
          `the guard no longer finds ${server === null ? pair.server : pair.client} in ${server === null ? SERVER_FILE : CLIENT_FILE}`,
          'a cross-tier constant was renamed or removed on one side — rename it on both, then update the PAIRS map in the pack check',
        );
        continue;
      }

      if (server !== client) {
        say(
          CLIENT_FILE,
          `${pair.client} is ${client} but ${SERVER_FILE}'s ${pair.server} is ${server}`,
          `make both copies agree with the docs/DESIGN.md §10 row (the server value is the one delivery actually uses)`,
        );
        continue;
      }

      // The doc table is the source both copies transcribe. Only a bare integer
      // cell is comparable — the table also carries prose cells ("5 min").
      const documented = designValue(designText, pair.server);
      if (documented !== null && /^\d+$/.test(documented) && documented !== server) {
        say(
          DESIGN_FILE,
          `§10 documents ${pair.server} as ${documented}, but both tiers carry ${server}`,
          'update the §10 row, or the two copies — the table is the single source of truth the copies transcribe',
        );
      }
    }

    return out;
  },
};

// `export const NAME = <value>;` — the shape every entry in constants.ts uses.
function serverValue(text, name) {
  const m = new RegExp(`^export const ${name}\\s*=\\s*([^;]+);`, 'm').exec(text);
  return m ? normalize(m[1]) : null;
}

// `const int name = <value>;` / `const String name = '<value>';` — config.dart's shape.
function clientValue(text, name) {
  const m = new RegExp(`^const\\s+\\w+\\s+${name}\\s*=\\s*([^;]+);`, 'm').exec(text);
  return m ? normalize(m[1]) : null;
}

// The §10 table row: | `NAME` | value | lives in ... |
function designValue(text, name) {
  if (text === null) return null;
  const m = new RegExp(`^\\|\\s*\`${name}\`\\s*\\|([^|]*)\\|`, 'm').exec(text);
  return m ? normalize(m[1]) : null;
}

// Compare values, not spelling: strip whitespace and one layer of quotes so
// 'us-central1' and "us-central1" are the same value.
function normalize(raw) {
  const v = raw.trim();
  const quoted = /^(['"])(.*)\1$/.exec(v);
  return quoted ? quoted[2] : v;
}

export default rule;
