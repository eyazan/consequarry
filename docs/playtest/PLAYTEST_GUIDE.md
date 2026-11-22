# Playtest Guide (P0.5)

Goal: ≥30 independent testers. These are internal validation targets, not industry benchmarks.

## How testers play
- **iPhone / iPad / any phone or browser:** open the web build link the owner shares, rotate to landscape. (First load ≈ 40 MB.)
- **Windows / macOS / Linux:** download the zip for your platform from the owner.
  - macOS: the app is ad-hoc signed, not notarised. First launch: right-click → Open → Open.
  - Windows: SmartScreen may warn ("unknown publisher") → More info → Run anyway.

## Session protocol (owner)
1. Do **not** explain the game. Ask the tester to start with the Tutorial.
2. Watch silently for the first 5 minutes; note where they hesitate.
3. After the run ends, ask them to press **Copy run report** on the end screen and paste it into the form.
4. Ask the questions below.

## Feedback form (create as a free Google Form / Tally form; no account needed for testers)
1. In one sentence, what do you do in this game?  *(checks: mechanic understood unaided)*
2. Why did your weakest system lose health? *(checks: causal readability)*
3. Did you want to play another run right away? Yes / Maybe / No *(target ≥ 50% Yes)*
4. Which moment felt best? Which felt unfair or confusing?
5. Would you pay for a full version of this? No / Maybe at $5–10 / Yes at ~$13 / Yes at more
6. Device and browser / OS.
7. Paste your run report.

## What the run report contains
Seed, outcome, seasons survived, action counts per intervention type, final system health, platform and layout. No personal data, no network transmission — the tester pastes it themselves.

## Analysis
Track per tester: understood (Q1 correct), explained cause (Q2), replay intent (Q3), purchase interest (Q5). Note the seeds of runs that felt unfair; replay them (`--autostart p0_valley <seed>` or the Play-seed box).
