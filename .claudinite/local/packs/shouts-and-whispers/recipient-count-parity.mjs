// RULES.md §"Delivery decides the audience once, and it decides it twice over":
// the sender is a recipient UNCONDITIONALLY — `selectRecipients` seeds its list
// with the sender (`distanceM: 0`, `isOwn: true`) before it looks at a single
// candidate (DESIGN.md §1.5) — and `recipientCount` is therefore
// `recipients.length - 1`. The two facts move together: change the seeding and
// the count reported back to the sender starts lying, in the other file, with
// nothing in the toolchain to notice. Both tiers compile, every test passes, and
// the sender is told they reached one more (or one fewer) person than they did.
//
// This is a static signature — two committed literals in two files that must
// agree — so it converts: the number of guaranteed sender seats the declaration
// of `recipients` carries must equal the number `recipientCount` subtracts.
// Seeding AT THE DECLARATION is what makes the seat unconditional by
// construction (a `const` cannot be initialised inside an `if` and still be in
// scope after it), so the guard reads the initializer and nothing else.
//
// It does NOT check that the sender is delivered to, or that the count is
// reported to the right caller — that is runtime behaviour and stays with
// firebase/functions/test/recipients.test.ts.
//
// Dependency-free by design (a local pack's checks must load without the shared
// mount): it builds plain finding objects instead of importing the engine helper.

const SELECT_FILE = 'firebase/functions/src/recipients.ts';
const COUNT_FILE = 'firebase/functions/src/index.ts';

// `const recipients: Recipient[] = [{ uid: senderUid, distanceM: 0, isOwn: true }];`
const SEED_DECL = /const\s+recipients\b[^=;]*=\s*\[/;
// `const recipientCount = recipients.length - 1;`
const COUNT_DECL = /const\s+recipientCount\s*=\s*([^;]+);/;
// The derivation the rule allows: the list length, less a literal number of
// non-candidate seats.
const COUNT_SHAPE = /^recipients\s*\.\s*length(?:\s*-\s*(\d+))?$/;

const rule = {
  id: 'shouts-and-whispers/recipient-count-parity',
  severity: 'blocking',
  description: 'recipientCount subtracts exactly the sender seats selectRecipients always seeds',
  doc: '.claudinite/local/packs/shouts-and-whispers/RULES.md',
  why: 'the sender is a recipient unconditionally and the count reported back to them excludes exactly that seat; the two facts live in different files, so changing one without the other compiles, keeps every test green, and quietly reports the wrong audience size to every sender',

  run(ctx) {
    const out = [];
    const say = (file, line, what, fix) => out.push({
      rule: rule.id, severity: rule.severity, file, line,
      what, why: rule.why, fix, doc: rule.doc,
    });

    const selectText = ctx.read(SELECT_FILE);
    const countText = ctx.read(COUNT_FILE);

    // Staleness guard, the idiom the pack's other checks already use: a guard
    // that quietly stops finding its subject is worse than no guard.
    if (selectText === null || countText === null) {
      const missing = selectText === null ? SELECT_FILE : COUNT_FILE;
      say(missing, null,
        `the recipient count parity guard cannot read ${missing}`,
        'restore the file, or point the guard at its new home (the paths live at the top of the pack\'s recipient-count-parity.mjs)');
      return out;
    }

    const seed = seedSeats(selectText);
    if (seed === null) {
      say(SELECT_FILE, null,
        'the guard no longer finds the `recipients` list being seeded at its declaration in selectRecipients',
        'seed the sender at the declaration — `const recipients: Recipient[] = [{ uid: senderUid, distanceM: 0, isOwn: true }]` — which is what makes the sender\'s seat unconditional by construction; if the shape genuinely changed, re-point the guard in the pack\'s recipient-count-parity.mjs');
      return out;
    }

    const derivation = COUNT_DECL.exec(countText);
    const shape = derivation && COUNT_SHAPE.exec(derivation[1].trim());
    if (!shape) {
      say(COUNT_FILE, derivation ? lineOf(countText, derivation.index) : null,
        derivation
          ? `recipientCount is no longer derived from the recipient list length (\`${derivation[1].trim()}\`)`
          : 'the guard no longer finds recipientCount being derived in sendMessage',
        'keep the count as `recipients.length - <sender seats>` so it stays visibly tied to the seats selectRecipients seeds, or re-point the guard in the pack\'s recipient-count-parity.mjs');
      return out;
    }

    const subtracted = shape[1] === undefined ? 0 : Number(shape[1]);
    if (subtracted !== seed.seats) {
      say(COUNT_FILE, lineOf(countText, derivation.index),
        `recipientCount subtracts ${subtracted} from the recipient list, but ${SELECT_FILE} seeds ${seed.seats} sender seat${seed.seats === 1 ? '' : 's'} before the candidate loop`,
        seed.seats === 0
          ? 'the sender is a recipient unconditionally (DESIGN.md §1.5) — restore the seat in the declaration of `recipients`, or, if the sender is genuinely no longer seeded, stop subtracting it'
          : `subtract ${seed.seats} in ${COUNT_FILE} so the count reported to the sender excludes exactly the seats that are not candidates`);
      return out;
    }

    if (seed.seats > 0 && !seed.own) {
      say(SELECT_FILE, seed.line,
        'the seeded sender seat is not marked `isOwn: true` / `distanceM: 0`',
        'the sender\'s own copy is flagged `isOwn: true` at distance 0 (DESIGN.md §1.5) — the client renders it as "you" from those two fields');
    }

    return out;
  },
};

// The declaration's array literal → how many entries it seeds for the sender,
// and whether they carry the sender's own-copy marking. Null when the list is
// no longer seeded at its declaration at all (a staleness case, not a defect).
function seedSeats(text) {
  const decl = SEED_DECL.exec(text);
  if (!decl) return null;

  const open = decl.index + decl[0].length - 1;
  const literal = balanced(text, open);
  if (literal === null) return null;

  const entries = topLevelEntries(literal);
  // Only entries that seat the SENDER count: an initializer holding something
  // else is a shape this guard was not written for, and says so rather than
  // guessing.
  if (entries.some((e) => !/\buid\s*:\s*senderUid\b/.test(e))) return null;

  return {
    seats: entries.length,
    own: entries.every((e) => /\bisOwn\s*:\s*true\b/.test(e) && /\bdistanceM\s*:\s*0\b/.test(e)),
    line: lineOf(text, decl.index),
  };
}

// The text between `[` at `open` and its matching `]`, string-aware so a bracket
// inside a literal cannot close it early.
function balanced(text, open) {
  let depth = 0;
  let quote = null;
  for (let i = open; i < text.length; i += 1) {
    const c = text[i];
    if (quote) {
      if (c === '\\') i += 1;
      else if (c === quote) quote = null;
      continue;
    }
    if (c === '\'' || c === '"' || c === '`') quote = c;
    else if (c === '[' || c === '{' || c === '(') depth += 1;
    else if (c === ']' || c === '}' || c === ')') {
      depth -= 1;
      if (depth === 0) return text.slice(open + 1, i);
    }
  }
  return null;
}

// Split an array literal's body on its TOP-LEVEL commas — the commas inside each
// `{ ... }` entry separate fields, not entries.
function topLevelEntries(body) {
  const entries = [];
  let depth = 0;
  let quote = null;
  let start = 0;
  for (let i = 0; i < body.length; i += 1) {
    const c = body[i];
    if (quote) {
      if (c === '\\') i += 1;
      else if (c === quote) quote = null;
      continue;
    }
    if (c === '\'' || c === '"' || c === '`') quote = c;
    else if (c === '[' || c === '{' || c === '(') depth += 1;
    else if (c === ']' || c === '}' || c === ')') depth -= 1;
    else if (c === ',' && depth === 0) {
      entries.push(body.slice(start, i));
      start = i + 1;
    }
  }
  entries.push(body.slice(start));
  return entries.filter((e) => e.trim() !== '');
}

function lineOf(text, index) {
  return text.slice(0, index).split('\n').length;
}

export default rule;
