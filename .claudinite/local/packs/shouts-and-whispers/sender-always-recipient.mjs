// RULES.md §"Delivery decides the audience once, and it decides it twice over":
// `selectRecipients` seeds its result with the sender before it looks at a single
// candidate (DESIGN.md §1.5) — the sender's own copy does not depend on their
// presence doc existing or being fresh. The caller then reports
// `recipientCount = recipients.length - 1`, and the `- 1` is only correct
// BECAUSE of that seed. The two facts live in different files and move together:
// drop the seed and the count under-reports by one (and the sender stops
// receiving their own message); change the seed's size and the count lies.
//
// Both halves are static signatures — the seed lives in `selectRecipients` in
// firebase/functions/src/recipients.ts, the offset is a literal in the
// `recipientCount` expression in firebase/functions/src/index.ts — so the
// agreement between them converts to a check.
//
// "Unconditionally" is what makes it mechanical, and it is what the check reads:
// a seed counts only if it sits at the top level of the function body — an
// element of the recipients-array initializer, or a `recipients.push(...)` at
// brace depth one. A seed behind an `if` is by definition conditional, which is
// exactly the regression the rule exists to catch.
//
// So the check parses rather than greps: it brace-matches `selectRecipients`'
// body, splits the array initializer at bracket depth zero, and tracks depth
// across the body to tell a top-level push from a guarded one. Grepping for
// `isOwn: true` would match the candidate loop's `isOwn: false` sibling shape,
// any conditional push, and every future call site.
//
// Dependency-free by design (a local pack's checks must load without the shared
// mount): it builds plain finding objects instead of importing the engine helper.

const SELECTOR_FILE = 'firebase/functions/src/recipients.ts';
const CALLER_FILE = 'firebase/functions/src/index.ts';
const SELECTOR_FN = 'selectRecipients';
const COUNT_NAME = 'recipientCount';

const rule = {
  id: 'shouts-and-whispers/sender-always-recipient',
  severity: 'blocking',
  description: 'selectRecipients seeds the sender unconditionally, and recipientCount subtracts exactly that seed',
  doc: '.claudinite/local/packs/shouts-and-whispers/RULES.md',
  why: 'the sender always receives their own copy, so the count reported back to them must exclude exactly the seeded sender — the seed and the offset live in different files, and a change to either alone either drops the sender from their own feed or reports a recipient count that is quietly wrong',

  run(ctx) {
    const out = [];
    const say = (file, line, what, fix) => out.push({
      rule: rule.id, severity: rule.severity, file, line,
      what, why: rule.why, fix, doc: rule.doc,
    });

    const selectorText = ctx.read(SELECTOR_FILE);
    const callerText = ctx.read(CALLER_FILE);

    // Staleness guard, the idiom the pack's other checks already use: a guard
    // that quietly stops finding its subject is worse than no guard.
    for (const [file, text] of [[SELECTOR_FILE, selectorText], [CALLER_FILE, callerText]]) {
      if (text === null) {
        say(file, null, `the sender-seed guard cannot read ${file}`,
          'restore the file, or point the guard at its new home (the paths live at the top of the pack\'s sender-always-recipient.mjs)');
        return out;
      }
    }

    const body = functionBody(selectorText, SELECTOR_FN);
    if (body === null) {
      say(SELECTOR_FILE, null,
        `no ${SELECTOR_FN}(...) declaration found in ${SELECTOR_FILE} — the sender-seed guard has nothing to read`,
        `keep recipient selection in a ${SELECTOR_FN} function here, or point the guard at its new home`);
      return out;
    }

    const seed = unconditionalSeeds(selectorText, body);
    if (seed === null) {
      say(SELECTOR_FILE, body.line,
        `${SELECTOR_FN} no longer builds its recipients from an array literal the guard can read — it cannot tell whether the sender is seeded`,
        'declare the result as an array literal (`const recipients: Recipient[] = [{ uid: senderUid, distanceM: 0, isOwn: true }]`), or point the guard at its new shape');
      return out;
    }

    // The seed must actually be the sender: its own copy, at distance zero.
    if (!seed.entries.some(isSenderSeed)) {
      say(SELECTOR_FILE, seed.line,
        `${SELECTOR_FN} adds no unconditional sender recipient (no top-level \`distanceM: 0, isOwn: true\` entry)${seed.conditional ? ' — the only sender-shaped entry sits behind a condition' : ''}`,
        'seed the sender before the candidate loop and outside any branch — their own copy must not depend on their presence doc existing or being fresh (DESIGN.md §1.5)');
      return out;
    }

    // The caller's count is only correct because of that seed, so it must
    // subtract exactly as many elements as the seed puts in.
    const count = countExpression(callerText);
    if (count === null) {
      say(CALLER_FILE, null,
        `no \`${COUNT_NAME} = <recipients>.length [- n]\` expression found in ${CALLER_FILE} — the guard cannot check that the seeded sender is excluded from the reported count`,
        `derive ${COUNT_NAME} from the selected recipients' length here, or point the guard at its new home`);
      return out;
    }

    const selected = selectedVariable(callerText);
    if (selected !== null && count.base !== selected) {
      say(CALLER_FILE, count.line,
        `${COUNT_NAME} counts \`${count.base}\` but ${SELECTOR_FN} returns \`${selected}\` — the reported count is not derived from the selected recipients`,
        `compute ${COUNT_NAME} from ${SELECTOR_FN}' result (\`${selected}.length - ${seed.entries.length}\`), so the seeded sender is the only thing excluded`);
      return out;
    }

    if (count.offset !== seed.entries.length) {
      say(CALLER_FILE, count.line,
        `${SELECTOR_FN} seeds ${seed.entries.length} recipient${seed.entries.length === 1 ? '' : 's'} (the sender) but ${COUNT_NAME} subtracts ${count.offset} — the count reported to the sender is off by ${Math.abs(seed.entries.length - count.offset)}`,
        `keep the two in step: \`${COUNT_NAME} = ${count.base}.length - ${seed.entries.length}\` (the count excludes the sender, DESIGN.md §1.5)`);
    }

    return out;
  },
};

// The body of `function NAME(...)`, brace-matched — so the guard reads the one
// function the rule is about instead of the whole module.
function functionBody(text, name) {
  const m = new RegExp(`\\bfunction\\s+${name}\\s*\\(`).exec(text);
  if (!m) return null;
  const open = text.indexOf('{', m.index + m[0].length);
  if (open === -1) return null;
  const close = matching(text, open, '{', '}');
  if (close === -1) return null;
  return {
    start: open,
    text: text.slice(open, close + 1),
    line: lineOf(text, m.index),
  };
}

// A recipient entry the function adds no matter what happened: an element of the
// result array's initializer, or a `<result>.push(...)` at the top level of the
// body (brace depth one — anything deeper is inside a branch or the candidate
// loop). Returns null when the result isn't an array literal the guard can read.
function unconditionalSeeds(text, body) {
  const decl = /\b(?:const|let|var)\s+(\w+)\s*(?::[^=;]*)?=\s*\[/.exec(body.text);
  if (!decl) return null;

  const open = body.start + decl.index + decl[0].length - 1; // the `[`
  const close = matching(text, open, '[', ']');
  if (close === -1) return null;

  const entries = splitTopLevel(text.slice(open + 1, close)).map((e) => e.trim()).filter(Boolean);
  const pushes = pushArguments(body.text, decl[1]);

  return {
    line: lineOf(text, body.start + decl.index),
    entries: [...entries, ...pushes.filter((p) => p.unconditional).map((p) => p.argument)],
    // A sender-shaped entry that *is* guarded: named in the finding, because it
    // is the likeliest way this rule gets broken.
    conditional: pushes.some((p) => !p.unconditional && isSenderSeed(p.argument)),
  };
}

// Every `<name>.push(<argument>)` in a function body, flagged unconditional when
// it is a statement at the top level of that body: brace depth one (not inside a
// block, a branch, or the candidate loop) AND at the start of its statement (so
// a braceless `if (x) recipients.push(...)` or `x && recipients.push(...)` is not
// mistaken for one).
function pushArguments(bodyText, name) {
  const found = [];
  const call = new RegExp(`\\b${name}\\.push\\s*\\(`, 'g');
  let m;
  while ((m = call.exec(bodyText)) !== null) {
    const paren = m.index + m[0].length - 1;
    const end = matching(bodyText, paren, '(', ')');
    if (end === -1) continue;
    found.push({
      unconditional: braceDepth(bodyText, m.index) === 1 && atStatementStart(bodyText.slice(0, m.index)),
      argument: bodyText.slice(paren + 1, end).trim(),
    });
  }
  return found;
}

// How many unclosed `{` precede `index` — 1 is the top level of a function body
// (which starts at its own `{`), anything more is inside a nested block.
function braceDepth(text, index) {
  let depth = 0;
  for (let i = 0; i < index; i += 1) {
    if (text[i] === '{') depth += 1;
    else if (text[i] === '}') depth -= 1;
  }
  return depth;
}

// True when everything between the previous statement boundary and here is
// whitespace or comments — i.e. this is a statement, not the consequent of a
// braceless `if` or the right-hand side of a `&&`.
function atStatementStart(prefix) {
  let s = prefix;
  for (;;) {
    s = s.replace(/\s+$/, '');
    if (s.endsWith('*/')) {
      const at = s.lastIndexOf('/*');
      if (at === -1) return false;
      s = s.slice(0, at);
      continue;
    }
    const lineStart = s.lastIndexOf('\n') + 1;
    const comment = s.slice(lineStart).indexOf('//');
    if (comment !== -1) {
      s = s.slice(0, lineStart + comment);
      continue;
    }
    break;
  }
  return s === '' || ';{}'.includes(s[s.length - 1]);
}

// The sender's own copy: distance zero, flagged as their own.
const isSenderSeed = (entry) =>
  /\bisOwn\s*:\s*true\b/.test(entry) && /\bdistanceM\s*:\s*0\b/.test(entry);

// `const recipientCount = <base>.length - <n>;` (the `- n` optional).
function countExpression(text) {
  const m = new RegExp(`\\b${COUNT_NAME}\\s*=\\s*(\\w+)\\.length\\s*(?:-\\s*(\\d+))?\\s*;`).exec(text);
  if (!m) return null;
  return { base: m[1], offset: m[2] === undefined ? 0 : Number(m[2]), line: lineOf(text, m.index) };
}

// The variable the caller assigns `selectRecipients(...)` to, so the count can be
// tied to the selection rather than to any array that happens to be in scope.
function selectedVariable(text) {
  const m = new RegExp(`\\b(?:const|let|var)\\s+(\\w+)\\s*(?::[^=]+)?=\\s*(?:await\\s+)?${SELECTOR_FN}\\s*\\(`).exec(text);
  return m ? m[1] : null;
}

function matching(text, open, openChar, closeChar) {
  let depth = 0;
  for (let i = open; i < text.length; i += 1) {
    if (text[i] === openChar) depth += 1;
    else if (text[i] === closeChar) {
      depth -= 1;
      if (depth === 0) return i;
    }
  }
  return -1;
}

function splitTopLevel(inner) {
  const parts = [];
  let depth = 0;
  let last = 0;
  for (let i = 0; i < inner.length; i += 1) {
    const c = inner[i];
    if (c === '{' || c === '[' || c === '(') depth += 1;
    else if (c === '}' || c === ']' || c === ')') depth -= 1;
    else if (c === ',' && depth === 0) {
      parts.push(inner.slice(last, i));
      last = i + 1;
    }
  }
  parts.push(inner.slice(last));
  return parts;
}

const lineOf = (text, index) => text.slice(0, index).split('\n').length;

export default rule;
