# Claudinite runs — conduct of this repo's unattended scheduled tasks

What an executor session, or the subagent it dispatches, must do **before** it authors
work and **before** it writes to GitHub. The task *procedures* are the mounted canon's
(`.claudinite/shared/packs/`), and the product invariants are the `shouts-and-whispers`
pack's; what is left, and what is here, is the handful of run-conduct habits this repo
has actually paid for.

## A task's tracker issue is an input, not only an output

- **Read the tracker's prior comments first — before choosing a candidate, not after
  building one.** Every task file lists "log to the tracker" as its *last* step, which
  reads as "the tracker is somewhere to write". It is also the only durable record of
  what the owner has already **rejected**: earlier runs' dated comments name the
  candidate, the PR it shipped as, and the verdict it got. So the moment you have found
  the tracker by its exact title, pull its comments (one `issue_read` / `get_comments`)
  and strike every already-rejected candidate off the list — *then* start authoring.
  Nothing else in the repo carries that history: the rejected work was reverted, so
  neither `main`, nor the pack, nor `git log` shows it was ever tried.

  The 2026-07-28 `prose-to-checks-sweep` run (#33) picked the sender-seed /
  `recipientCount` arithmetic rule, then built it in full — check module, seven
  fixtures, `pack.mjs` registration, `RULES.md` and two `README.md` edits — before
  reading tracker #22 and finding the owner had rejected exactly that conversion the day
  before (PR #32, "a feature test in disguise") with an explicit do-not-re-attempt note.
  It reverted all of it, correctly. Cost: **2 min 39 s of a 9 min 03 s run (29%) and 16
  tool calls**, undone by a **0.4-second** call made three minutes too late.

## Never write a timestamp you did not just read from the clock

- **Shell out for the time (`date -u +"%Y-%m-%dT%H:%M:%SZ"`) before putting one in a
  comment, a commit, a log line, or a filename.** A model does not know the current time,
  and a plausible-looking stamp it invents is indistinguishable from a real one to every
  later reader — including the audit trail these runs exist to leave. The same 2026-07-28
  run stamped its claim comment on #33 `2026-07-28T00:00:00Z` and had to post a second
  comment to correct it; the wrong stamp is still the first thing a reader of that issue
  sees. A correction cannot unpublish the original, so the clock read has to come first.
