# claudinite-runs (local pack)

The repo's own pack for **run conduct**: what an unattended Claudinite scheduled run —
the executor session and the subagent it dispatches — must do before it authors work and
before it writes to GitHub. Declared by hand in `.claudinite-checks.json` as
`local/claudinite-runs`; its `RULES.md` loads into every session via the pack-prose
SessionStart hook, which is the whole delivery mechanism (these rules only help if they
are read *before* the run starts, not looked up after it goes wrong).

## Why a separate pack

| Pack | Territory |
| --- | --- |
| `shouts-and-whispers` (local) | the cross-tier delivery contract — Flutter client ↔ Cloud Functions invariants |
| `.claudinite/shared/packs/*` (canon, read-only here) | the task procedures and the cross-project baseline |
| **`claudinite-runs`** (local) | how a run behaves while executing one of those procedures in this repo |

Agent-conduct rules folded into `shouts-and-whispers` would dilute prose that is meant to
read as the product's invariants; the canon is a read-only mount a consumer never edits.
A lesson here that turns out to hold for other repos is not this pack's to promote — the
growth lifecycle's promote stage lifts it into the shared canon centrally.

## Checks

None yet, deliberately. Both current rules are about what an agent does at run time
against the GitHub API, which no static check over this repo's files can observe — the
local promotion ladder's bottom rung (terse prose) is the strongest mechanism available
to them. If a rule here ever acquires a file-visible signature, it descends to a check in
this pack's `rules`, shipped red-first with a fixture, exactly as `shouts-and-whispers`
does it.

## Provenance

Rules land here from the `grow_with_claudinite/conversation-extract` daily task, which
mines the captured session logs on the `conversation-logs` branch. Each landed rule is
logged on the standing tracker issue `Claudinite tracker: Conversation Extract`, and
summarized on the issue the session was worked under.
