// Red-first fixtures for this pack's checks: each check is exercised against a
// violating input (it must fire) and a clean one (it must stay quiet), plus the
// staleness case where the guard can no longer find what it guards.
//
// Run with the Node test runner — no dependency, no install:
//   node --test .claudinite/local/packs/shouts-and-whispers/pack.test.mjs
//
// The last case in each block runs the check against the REAL repo tree, so a
// check that has silently stopped matching the project's actual files fails here
// rather than passing vacuously in CI.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

import crossTierConstants from './cross-tier-constants.mjs';
import geohashPrecisionParity from './geohash-precision-parity.mjs';
import geohashVectorParity from './geohash-vector-parity.mjs';
import recipientCountParity from './recipient-count-parity.mjs';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');

// A minimal stand-in for the engine's check context: the two accessors these
// dependency-free checks use.
const ctxOf = (files) => ({
  files: Object.keys(files),
  read: (p) => (p in files ? files[p] : null),
});

// The real tree, as the engine would present it.
const realCtx = () => ({
  files: execFileSync('git', ['ls-files'], { cwd: repoRoot, encoding: 'utf8' })
    .split('\n').filter(Boolean),
  read(p) {
    try { return readFileSync(join(repoRoot, p), 'utf8'); } catch { return null; }
  },
});

const CONSTANTS_TS = (whisper) => `
export const WHISPER_RADIUS_M = ${whisper};
export const SHOUT_RADIUS_M = 1500;
export const MAX_TEXT_LEN = 500;
export const REGION = 'us-central1';
`;

const CONFIG_DART = `
const int whisperRadiusM = 150;
const int shoutRadiusM = 1500;
const int maxTextLen = 500;
const String functionsRegion = 'us-central1';
`;

const DESIGN_MD = `
## 10. Constants (single source of truth)

| constant          | value  | lives in |
|-------------------|--------|----------|
| \`WHISPER_RADIUS_M\`| 150    | both     |
| \`SHOUT_RADIUS_M\`  | 1500   | both     |
| \`MAX_TEXT_LEN\`    | 500    | both     |
`;

const constantsFiles = (whisper) => ({
  'firebase/functions/src/constants.ts': CONSTANTS_TS(whisper),
  'app/lib/config.dart': CONFIG_DART,
  'docs/DESIGN.md': DESIGN_MD,
});

test('cross-tier-constants: fires when the server radius drifts from the client', () => {
  const findings = crossTierConstants.run(ctxOf(constantsFiles(200)));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /whisperRadiusM is 150 but .* is 200/);
  assert.equal(findings[0].severity, 'blocking');
});

test('cross-tier-constants: fires when both tiers agree but §10 does not', () => {
  const files = constantsFiles(150);
  files['docs/DESIGN.md'] = DESIGN_MD.replace('| 150 ', '| 250 ');
  const findings = crossTierConstants.run(ctxOf(files));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].file, 'docs/DESIGN.md');
  assert.match(findings[0].what, /documents WHISPER_RADIUS_M as 250/);
});

test('cross-tier-constants: quiet when every pair agrees', () => {
  assert.deepEqual(crossTierConstants.run(ctxOf(constantsFiles(150))), []);
});

test('cross-tier-constants: fires when a guarded constant is renamed away', () => {
  const files = constantsFiles(150);
  files['app/lib/config.dart'] = CONFIG_DART.replace('maxTextLen', 'maxMessageLen');
  const findings = crossTierConstants.run(ctxOf(files));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /no longer finds maxTextLen/);
});

test('cross-tier-constants: quiet on the real repo', () => {
  assert.deepEqual(crossTierConstants.run(realCtx()), []);
});

const geohashFiles = (clientPrecision, serverPrecision) => ({
  'app/lib/adapters/geolocator_location_adapter.dart':
    `'geohash': geohash.encode(p.lat, p.lng, precision: ${clientPrecision}),`,
  'firebase/functions/src/index.ts':
    `const geohash = geohashForLocation([lat, lng], ${serverPrecision});`,
});

test('geohash-precision-parity: fires when the tiers encode at different precisions', () => {
  const findings = geohashPrecisionParity.run(ctxOf(geohashFiles(9, 10)));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /precision disagrees across the tiers/);
  assert.equal(findings[0].file, 'firebase/functions/src/index.ts');
  assert.equal(findings[0].line, 1);
});

test('geohash-precision-parity: quiet when both tiers encode at 9', () => {
  assert.deepEqual(geohashPrecisionParity.run(ctxOf(geohashFiles(9, 9))), []);
});

test('geohash-precision-parity: fires when a call site drops the explicit precision', () => {
  const files = geohashFiles(9, 9);
  files['firebase/functions/src/index.ts'] =
    'const geohash = geohashForLocation([lat, lng]);';
  const findings = geohashPrecisionParity.run(ctxOf(files));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /no explicit geohash precision found/);
});

test('geohash-precision-parity: quiet on the real repo', () => {
  assert.deepEqual(geohashPrecisionParity.run(realCtx()), []);
});

// The paired known-vector suites. Each fixture carries the deliberately
// UNPAIRED assertions too — the client's explicit-precision cases and the
// server's default-precision (10-char) ones — so the fixtures prove the guard
// reads only the shared precision-9 vectors and not every geohash literal in
// sight.
const GEOHASH_DART = (extra = '') => `
test('canonical Wikipedia vector', () {
  expect(encode(57.64911, 10.40744), 'u4pruydqq');
  expect(encode(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
});
test('bisection midpoints', () {
  expect(encode(0, 0), '7zzzzzzzz');
});${extra}
`;

const GEOHASH_TS = (extra = '') => `
it('encodes the Wikipedia reference point', () => {
  expect(geohashForLocation([57.64911, 10.40744])).toBe('u4pruydqqv');
});
it('matches the client encoder at the shared precision 9', () => {
  expect(geohashForLocation([57.64911, 10.40744], 9)).toBe('u4pruydqq');
  expect(geohashForLocation([0, 0], 9)).toBe('7zzzzzzzz');
});${extra}
`;

const vectorFiles = (dart, ts) => ({
  'app/test/geohash_test.dart': dart,
  'firebase/functions/test/geohash-compat.test.ts': ts,
});

test('geohash-vector-parity: fires when a vector is added to the client suite only', () => {
  const findings = geohashVectorParity.run(ctxOf(vectorFiles(
    GEOHASH_DART("\ntest('Sydney', () { expect(encode(-33.8688, 151.2093), 'r3gx2f77b'); });"),
    GEOHASH_TS(),
  )));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].file, 'firebase/functions/test/geohash-compat.test.ts');
  assert.match(findings[0].what, /asserts \(-33\.8688, 151\.2093\) → 'r3gx2f77b'.*carries no precision-9 vector/);
  assert.equal(findings[0].severity, 'blocking');
});

test('geohash-vector-parity: fires when a vector is added to the server suite only', () => {
  const findings = geohashVectorParity.run(ctxOf(vectorFiles(
    GEOHASH_DART(),
    GEOHASH_TS("\nit('London', () => { expect(geohashForLocation([51.5074, -0.1278], 9)).toBe('gcpvj0duq'); });"),
  )));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].file, 'app/test/geohash_test.dart');
  assert.match(findings[0].what, /carries no precision-9 vector/);
});

test('geohash-vector-parity: fires once when the suites expect different hashes', () => {
  const findings = geohashVectorParity.run(ctxOf(vectorFiles(
    GEOHASH_DART(),
    GEOHASH_TS().replace("'7zzzzzzzz'", "'s00000000'"),
  )));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /disagree on \(0, 0\).*expects '7zzzzzzzz'.*expects 's00000000'/);
});

test('geohash-vector-parity: quiet when both suites carry the same precision-9 vectors', () => {
  assert.deepEqual(geohashVectorParity.run(ctxOf(vectorFiles(GEOHASH_DART(), GEOHASH_TS()))), []);
});

test('geohash-vector-parity: fires when a suite stops carrying precision-9 vectors', () => {
  const findings = geohashVectorParity.run(ctxOf(vectorFiles(
    GEOHASH_DART(),
    "it('encodes at the default precision', () => {\n  expect(geohashForLocation([0, 0])).toBe('7zzzzzzzzz');\n});",
  )));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /no precision-9 known vectors found/);
});

test('geohash-vector-parity: fires when a suite moves out from under the guard', () => {
  const files = vectorFiles(GEOHASH_DART(), GEOHASH_TS());
  delete files['app/test/geohash_test.dart'];
  const findings = geohashVectorParity.run(ctxOf(files));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /cannot read app\/test\/geohash_test\.dart/);
});

test('geohash-vector-parity: quiet on the real repo', () => {
  assert.deepEqual(geohashVectorParity.run(realCtx()), []);
});

// The sender's seat and the count that excludes it. The fixtures carry the
// candidate loop too — including a non-sender `recipients.push(...)` — so they
// prove the guard counts the SEEDED seats and not every recipient the function
// can produce.
const RECIPIENTS_TS = (seed) => `
export function selectRecipients(
  candidates: readonly Candidate[],
  center: [number, number],
  radiusM: number,
  nowMs: number,
  senderUid: string,
): Recipient[] {
  const recipients: Recipient[] = ${seed};
  const freshnessCutoffMs = nowMs - PRESENCE_TTL_MS;

  for (const candidate of candidates) {
    if (candidate.uid === senderUid) continue;
    recipients.push({ uid: candidate.uid, distanceM: Math.round(distanceM), isOwn: false });
  }

  return recipients;
}
`;

const SENDER_SEAT = '[{ uid: senderUid, distanceM: 0, isOwn: true }]';

const INDEX_TS = (derivation) => `
  const recipients = selectRecipients(candidates, [lat, lng], radiusM, nowMs, uid);
  const recipientCount = ${derivation};
`;

const countFiles = (seed, derivation) => ({
  'firebase/functions/src/recipients.ts': RECIPIENTS_TS(seed),
  'firebase/functions/src/index.ts': INDEX_TS(derivation),
});

test('recipient-count-parity: fires when the sender stops being seeded but the count still subtracts them', () => {
  const findings = recipientCountParity.run(ctxOf(countFiles('[]', 'recipients.length - 1')));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].file, 'firebase/functions/src/index.ts');
  assert.match(findings[0].what, /subtracts 1 from the recipient list, but .* seeds 0 sender seats/);
  assert.equal(findings[0].severity, 'blocking');
});

test('recipient-count-parity: fires when the count stops excluding the seeded sender', () => {
  const findings = recipientCountParity.run(ctxOf(countFiles(SENDER_SEAT, 'recipients.length')));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /subtracts 0 from the recipient list, but .* seeds 1 sender seat\b/);
  assert.equal(findings[0].line, 3);
});

test('recipient-count-parity: fires when the seeded sender loses their own-copy marking', () => {
  const findings = recipientCountParity.run(ctxOf(countFiles(
    '[{ uid: senderUid, distanceM: 0, isOwn: false }]',
    'recipients.length - 1',
  )));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].file, 'firebase/functions/src/recipients.ts');
  assert.match(findings[0].what, /not marked `isOwn: true`/);
});

test('recipient-count-parity: quiet when the seat and the subtraction agree', () => {
  assert.deepEqual(
    recipientCountParity.run(ctxOf(countFiles(SENDER_SEAT, 'recipients.length - 1'))),
    [],
  );
});

test('recipient-count-parity: fires when the seat is pushed after the declaration instead of seeded in it', () => {
  // Seeding AT THE DECLARATION is what makes the seat unconditional by
  // construction, so a push-based refactor is a finding, not a silent pass.
  const findings = recipientCountParity.run(ctxOf(countFiles(
    '[];\n  recipients.push({ uid: senderUid, distanceM: 0, isOwn: true })',
    'recipients.length - 1',
  )));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /seeds 0 sender seats/);
});

test('recipient-count-parity: fires when the count is no longer derived from the list length', () => {
  const findings = recipientCountParity.run(ctxOf(countFiles(SENDER_SEAT, 'candidates.length')));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].file, 'firebase/functions/src/index.ts');
  assert.match(findings[0].what, /no longer derived from the recipient list length/);
});

test('recipient-count-parity: fires when a guarded file moves out from under the guard', () => {
  const files = countFiles(SENDER_SEAT, 'recipients.length - 1');
  delete files['firebase/functions/src/recipients.ts'];
  const findings = recipientCountParity.run(ctxOf(files));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /cannot read firebase\/functions\/src\/recipients\.ts/);
});

test('recipient-count-parity: fires when the list is no longer seeded at its declaration', () => {
  const files = countFiles(SENDER_SEAT, 'recipients.length - 1');
  files['firebase/functions/src/recipients.ts'] =
    files['firebase/functions/src/recipients.ts'].replace(/const recipients: Recipient\[\] = .*/,
      'const recipients = buildRecipients(senderUid);');
  const findings = recipientCountParity.run(ctxOf(files));
  assert.equal(findings.length, 1);
  assert.match(findings[0].what, /no longer finds the `recipients` list being seeded at its declaration/);
});

test('recipient-count-parity: quiet on the real repo', () => {
  assert.deepEqual(recipientCountParity.run(realCtx()), []);
});
