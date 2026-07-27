// RULES.md §"Delivery decides the audience once, and it decides it twice over":
// `selectRecipients` seeds its result with the sender unconditionally
// (`{ uid: senderUid, distanceM: 0, isOwn: true }`) before it looks at a single
// candidate, so the list it returns always carries one entry that is not an
// audience member. The `recipientCount` the callable reports — written into the
// message doc and shown to the sender as "delivered to N people nearby" — is
// therefore `recipients.length - 1`. The two facts are in different files and
// only agree by hand: drop the seed and the count is one too low; drop the
// subtraction and the sender counts themselves as an audience of one. Neither
// tier's compiler sees it, and index.ts has no unit tests (it needs the
// emulator), so the drift ships as a number that quietly lies.
//
// Both halves are static signatures — a literal array initializer and a literal
// subtraction — so the arithmetic converts to a check; that the sender's copy is
// the RIGHT copy at runtime stays the business of recipients.test.ts.
//
// Parsed rather than grepped (the skill's rule): the count is only the count if
// it is taken from the `selectRecipients` result itself, and the seed size is
// counted from the initializer's top-level elements rather than assumed to be 1.
//
// Dependency-free by design (a local pack's checks must load without the shared
// mount): it builds plain finding objects instead of importing the engine helper.

const TS_ROOT = 'firebase/functions/src/';

// `const recipients: Recipient[] = [ ... ];` — the seeded result list.
const SEED_DECL = /\bconst\s+(\w+)\s*:\s*Recipient\[\]\s*=\s*(?=\[)/g;
// `const recipients = selectRecipients(` — the consumer's handle on that list.
const CONSUMER_DECL = /\bconst\s+(\w+)\s*=\s*(?:await\s+)?selectRecipients\s*\(/g;
// `const recipientCount = <expr>;` — the number reported to the sender.
const COUNT_DECL = /\bconst\s+recipientCount\s*=\s*([^;]+);/g;
// The recognised shapes of that expression: `xs.length` or `xs.length - N`.
const COUNT_EXPR = /^(\w+)\.length\s*(?:-\s*(\d+)\s*)?$/;

const rule = {
  id: 'shouts-and-whispers/sender-recipient-count-parity',
  severity: 'blocking',
  description: 'The sender seeded into the recipient list is the sender subtracted from the reported recipientCount',
  doc: '.claudinite/local/packs/shouts-and-whispers/RULES.md',
  why: 'selectRecipients always seeds its result with the sender, so recipientCount is the list length minus that seed — the two live in different files, nothing at compile time relates them, and the callable that reports the number has no unit tests, so a change to either one ships as a recipient count that quietly lies to the sender',

  run(ctx) {
    const out = [];
    const say = (file, line, what, fix) => out.push({
      rule: rule.id, severity: rule.severity, file, line,
      what, why: rule.why, fix, doc: rule.doc,
    });

    const seed = findSeed(ctx);
    const count = findCount(ctx);

    // Staleness guard, the idiom the sibling checks use: a guard that quietly
    // stops finding its subject is worse than no guard.
    if (!seed) {
      say(
        `${TS_ROOT}recipients.ts`, null,
        `no seeded \`Recipient[]\` initializer found under ${TS_ROOT} — the guard cannot tell how many non-audience entries the recipient list carries`,
        'keep the sender an unconditional literal seed of the returned list (`const recipients: Recipient[] = [{ uid: senderUid, ... }]`), or point the guard at its new home',
      );
      return out;
    }
    if (!count) {
      say(
        `${TS_ROOT}index.ts`, null,
        `no \`const recipientCount = <recipients>.length …\` found under ${TS_ROOT} — the guard cannot tell what the sender is being told`,
        'keep the reported count derived from the selectRecipients result in one literal expression, or point the guard at its new home',
      );
      return out;
    }

    if (seed.size > 0 && !seed.hasOwnFlag) {
      say(
        seed.file, seed.line,
        `the recipient list is seeded with ${seed.size} entr${seed.size === 1 ? 'y' : 'ies'}, but none of them is the sender's own copy (\`isOwn: true\`)`,
        "seed the list with the sender's own copy (`{ uid: senderUid, distanceM: 0, isOwn: true }`) — DESIGN.md §1.5 gives the sender their own message unconditionally",
      );
      return out;
    }

    if (count.expr === null) {
      say(
        count.file, count.line,
        `recipientCount is computed as \`${count.raw}\`, which is not the length of the selectRecipients result`,
        `report \`${count.listName}.length - ${seed.size}\` — the count excludes the ${seed.size} seeded sender entr${seed.size === 1 ? 'y' : 'ies'}, and any other derivation is a second, unguarded definition of the audience`,
      );
      return out;
    }

    if (count.subtracted !== seed.size) {
      say(
        count.file, count.line,
        `recipientCount subtracts ${count.subtracted} from the recipient list, but ${seed.file}:${seed.line} seeds it with ${seed.size} non-audience entr${seed.size === 1 ? 'y' : 'ies'}`,
        `make the two agree: either restore the unconditional sender seed, or report \`${count.listName}.length - ${seed.size}\` (the count the sender sees must exclude exactly the seeded entries)`,
      );
    }

    return out;
  },
};

/** The `const xs: Recipient[] = [ … ]` seed: how many entries, and is one the sender's. */
function findSeed(ctx) {
  for (const file of tsFiles(ctx)) {
    const text = ctx.read(file);
    if (text === null) continue;
    SEED_DECL.lastIndex = 0;
    const m = SEED_DECL.exec(text);
    if (!m) continue;
    const literal = bracketed(text, m.index + m[0].length);
    if (!literal) continue;
    const elements = topLevelElements(literal.inner);
    return {
      file,
      line: lineOf(text, m.index),
      name: m[1],
      size: elements.length,
      hasOwnFlag: /\bisOwn\s*:\s*true\b/.test(literal.inner),
    };
  }
  return null;
}

/** The `const recipientCount = …` the callable reports, tied to its selectRecipients result. */
function findCount(ctx) {
  for (const file of tsFiles(ctx)) {
    const text = ctx.read(file);
    if (text === null) continue;
    COUNT_DECL.lastIndex = 0;
    const m = COUNT_DECL.exec(text);
    if (!m) continue;

    CONSUMER_DECL.lastIndex = 0;
    const consumer = CONSUMER_DECL.exec(text);
    const listName = consumer ? consumer[1] : 'recipients';

    const raw = m[1].trim();
    const parsed = COUNT_EXPR.exec(raw);
    // Only the length of the selectRecipients result counts as the count.
    const expr = parsed && parsed[1] === listName ? parsed : null;
    return {
      file,
      line: lineOf(text, m.index),
      raw,
      listName,
      expr,
      subtracted: expr ? Number(expr[2] ?? 0) : null,
    };
  }
  return null;
}

function tsFiles(ctx) {
  return ctx.files.filter((f) => f.startsWith(TS_ROOT) && f.endsWith('.ts'));
}

function lineOf(text, index) {
  return text.slice(0, index).split('\n').length;
}

/** The text between `[` at `start` and its matching `]`, brackets and strings balanced. */
function bracketed(text, start) {
  let depth = 0;
  let quote = null;
  for (let i = start; i < text.length; i++) {
    const c = text[i];
    if (quote) {
      if (c === '\\') { i++; continue; }
      if (c === quote) quote = null;
      continue;
    }
    if (c === '"' || c === "'" || c === '`') { quote = c; continue; }
    if (c === '[' || c === '{' || c === '(') depth++;
    else if (c === ']' || c === '}' || c === ')') {
      depth--;
      if (depth === 0) return { inner: text.slice(start + 1, i), end: i };
      if (depth < 0) return null;
    }
  }
  return null;
}

/** Array-literal entries: split on commas at nesting depth 0, blanks dropped. */
function topLevelElements(inner) {
  const parts = [];
  let depth = 0;
  let quote = null;
  let current = '';
  for (let i = 0; i < inner.length; i++) {
    const c = inner[i];
    if (quote) {
      current += c;
      if (c === '\\') { current += inner[++i] ?? ''; continue; }
      if (c === quote) quote = null;
      continue;
    }
    if (c === '"' || c === "'" || c === '`') { quote = c; current += c; continue; }
    if (c === '[' || c === '{' || c === '(') depth++;
    else if (c === ']' || c === '}' || c === ')') depth--;
    else if (c === ',' && depth === 0) { parts.push(current); current = ''; continue; }
    current += c;
  }
  parts.push(current);
  return parts.map((p) => p.trim()).filter(Boolean);
}

export default rule;
