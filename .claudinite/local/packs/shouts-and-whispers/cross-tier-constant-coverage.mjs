// RULES.md §"One table, two copies": adding a cross-tier constant is a
// four-part change — the docs/DESIGN.md §10 row, the server copy, the client
// copy, and the `PAIRS` map in cross-tier-constants.mjs. This guard covers the
// fourth part: "a value absent from PAIRS is a value nothing is guarding."
//
// cross-tier-constants compares the pairs that are ALREADY listed; nothing
// compares the list against the tiers. So the failure it cannot see is the
// quiet one: a new constant copied into both constants.ts and config.dart but
// never added to PAIRS compiles, passes every suite, and passes the pack's own
// checks — while the two copies are free to drift apart forever, which is the
// exact bug cross-tier-constants exists to catch.
//
// The datum reconciled is "this constant is carried by both tiers", written
// down twice: once as a declaration in each tier's constants file, once as an
// entry in PAIRS. Like the pack's other guards it dictates no value, shape, or
// behaviour — its finding reads "make the copies agree", never "restore this
// constant".
//
// Detection pairs by NAMING CONVENTION across the two files, not by grepping
// for a list of names: a server `export const SHOUT_RADIUS_M` is cross-tier
// exactly when config.dart declares its lowerCamel counterpart `shoutRadiusM`.
// That is why the single-tier constants stay quiet by construction rather than
// by exemption — PRESENCE_TTL_MS, SEND_COOLDOWN_MS and the client's heartbeat
// cadence have no counterpart to find, so they are never candidates. The known
// cost is the reverse: a pair deliberately named against the convention
// (REGION / functionsRegion) is invisible to the convention and is only seen
// because it is already in PAIRS. That is a miss, never a false alarm — a
// finding here is always a real both-tier constant nothing is guarding.
//
// Dependency-free by design (a local pack's checks must load without the shared
// mount): it builds plain finding objects instead of importing the engine helper.

const SERVER_FILE = 'firebase/functions/src/constants.ts';
const CLIENT_FILE = 'app/lib/config.dart';
const GUARD_FILE = '.claudinite/local/packs/shouts-and-whispers/cross-tier-constants.mjs';

// `export const NAME = <value>;` — the shape every entry in constants.ts uses.
const SERVER_DECL = /^export const ([A-Z][A-Z0-9_]*)\s*=/gm;
// `const int name = ...;` / `const Duration name = ...;` — config.dart's shape.
const CLIENT_DECL = /^const\s+\w+\s+([a-z]\w*)\s*=/gm;
// One `{ server: 'NAME', client: 'name' }` entry of the guard's PAIRS map.
const PAIR_ENTRY = /server:\s*'([^']+)'\s*,\s*client:\s*'([^']+)'/g;

const rule = {
  id: 'shouts-and-whispers/cross-tier-constant-coverage',
  severity: 'blocking',
  description: 'Every constant both tiers declare is listed in the cross-tier-constants guard\'s PAIRS map',
  doc: '.claudinite/local/packs/shouts-and-whispers/RULES.md',
  why: 'cross-tier-constants only compares the pairs it is given, so a constant copied into both tiers but never added to PAIRS is guarded by nothing — the two copies drift apart with every test still green, which is the very failure that guard exists to catch',

  run(ctx) {
    const out = [];
    const say = (file, what, fix) => out.push({
      rule: rule.id, severity: rule.severity, file, line: null,
      what, why: rule.why, fix, doc: rule.doc,
    });

    const serverText = ctx.read(SERVER_FILE);
    const clientText = ctx.read(CLIENT_FILE);
    const guardText = ctx.read(GUARD_FILE);

    // Staleness guard, the idiom the pack's other checks already use: a guard
    // that quietly stops finding its subject is worse than no guard.
    const missing = [SERVER_FILE, CLIENT_FILE, GUARD_FILE]
      .find((f, i) => [serverText, clientText, guardText][i] === null);
    if (missing) {
      say(missing,
        `the cross-tier constant coverage guard cannot read ${missing}`,
        'restore the file, or point the guard at its new home (the paths live at the top of the pack\'s cross-tier-constant-coverage.mjs)');
      return out;
    }

    const listed = new Set(names(guardText, PAIR_ENTRY, 1));
    if (!listed.size) {
      say(GUARD_FILE,
        `no PAIRS entries found in ${GUARD_FILE} — the coverage guard has nothing to compare the tiers against`,
        'keep the guarded pairs as literal `{ server: \'NAME\', client: \'name\' }` entries in the PAIRS map, or point this guard at its new home');
      return out;
    }

    const declared = names(serverText, SERVER_DECL, 1);
    if (!declared.length) {
      say(SERVER_FILE,
        `no exported constants found in ${SERVER_FILE} — the coverage guard has nothing to check`,
        'keep the server constants as top-level `export const NAME = ...` declarations, or point the guard at its new home');
      return out;
    }

    const onClient = new Set(names(clientText, CLIENT_DECL, 1));

    for (const name of declared) {
      if (listed.has(name)) continue;
      // Cross-tier by construction: the client declares the same constant under
      // the lowerCamel spelling of the same name. A server-only constant has no
      // counterpart here and is never a candidate.
      const counterpart = camel(name);
      if (!onClient.has(counterpart)) continue;

      say(SERVER_FILE,
        `${name} is declared in ${SERVER_FILE} and ${counterpart} in ${CLIENT_FILE}, but the pair is absent from the PAIRS map in ${GUARD_FILE}`,
        `add { server: '${name}', client: '${counterpart}' } to PAIRS — a cross-tier constant is a four-part change (the docs/DESIGN.md §10 row, both copies, and the PAIRS entry), and until the pair is listed nothing compares the two copies`);
    }

    return out;
  },
};

// Every capture-group-1 match of `pattern` in `text`, in source order.
function names(text, pattern, group) {
  const found = [];
  pattern.lastIndex = 0;
  let m;
  while ((m = pattern.exec(text)) !== null) found.push(m[group]);
  return found;
}

// SHOUT_RADIUS_M -> shoutRadiusM: the spelling convention the two tiers use for
// one constant (TypeScript SCREAMING_SNAKE, Dart lowerCamel).
function camel(screamingSnake) {
  return screamingSnake
    .toLowerCase()
    .split('_')
    .map((part, i) => (i === 0 ? part : part.charAt(0).toUpperCase() + part.slice(1)))
    .join('');
}

export default rule;
