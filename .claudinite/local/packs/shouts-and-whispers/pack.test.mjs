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
