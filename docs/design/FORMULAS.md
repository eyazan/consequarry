# Simulation Formulas & Assumptions

All simulation math is **integer-only** (no floats in state). `pct(v, p) = floor((v*p + 50) / 100)` (round half up). Parameters live in `data/content.json` → `rules`.

## Resolution order (deterministic)
1. `begin_turn`: AP = actions_per_turn (+1 and −15 reserve if reserve ≥ 15); reset cushions and process usage; tick crisis cooldowns; spawn this season's (pre-rolled) events; roll next season's forecast.
2. Player interventions, applied immediately in the order taken and logged.
3. `end_turn`:
   1. Land every pending consequence with `land_turn ≤ turn`, sorted by id ascending.
   2. Apply causal effects queued last season.
   3. Queue new causal effects from post-landing health.
   4. Regeneration.
   5. Scars, then cascades (queued for next season — no in-turn recursion).
   6. Instability decay (−3).
   7. Snapshot, evaluate, advance.

## Landing a consequence of magnitude m, type t on system s
- Surplus: `heal = pct(m, 100)`; health capped at max; overflow above max → Reserve.
- Harm:
  - `absorbed = min(m, remaining_cushion(s))`, `excess = m − absorbed`
  - spill if `excess ≥ 2·spill_min (4)` and `depth < spill_max_depth (2)` and an outgoing non-collapsed neighbour exists: `spill = floor(excess/2)` → new child to strongest outgoing neighbour next season; Instability +2.
  - `landed = m − spill`
  - `effect = pct(absorbed, vuln·80/100) + pct(landed − absorbed, vuln)`; then `effect = pct(effect, 100 − resilience(s))`
  - health −= effect (min 0 → collapse, permanent).
- Conservation: `landed + Σchildren = m` (I1).

## Interventions
- Redirect (m ≥ 3): `leak = max(1, pct(m, 20))`; child `m − leak` → target, child `leak` stays. m < 3 reroutes whole.
- Split: `keep = m − floor(m/2)`, `half = floor(m/2)`.
- Delay: land_turn += 1; new root consequence `ceil(m·25/100)` same type/destination/land_turn.
- Transform: `out = clamp(pct(m, eff + adaptation), 1, m−1)`, residue = m − out.
- Crisis cost: `2 + crises_used`; gain = `pct(base, max(40, 100 − 20·prior))`; instability += `base_instability + 3·prior`.

## Causal edges (applied next season)
- support: collapsed source → `−ceil(30·w/100)`; else `raw = (h−50)·w`; raw ≥ 0 → `min(2, floor(raw/400))`; raw < 0 → `max(−8, −ceil(−raw/200))`.
- pressure: `−min(3, floor(max(0, h−60)·w/200))`.

## Regeneration
health ≥ 30: +1 if health < 75, +0 otherwise (diminishing returns).

## Cascades & scars
- health < 20 (first time): max_health −10 (scar).
- 0 < health < 20: Damage `4 + floor((20 − h)/3)` → strongest support dependent, next season; Instability +4.
- Newly collapsed: Damage 10 → strongest support dependent.

## Events
- count = 1; +1 if instability ≥ 45; +1 with 40% chance from season 3; max 3; no duplicates per season.
- weight ×10 base; focus collapsed → ÷2; focus health < 45 → ×1.5.
- magnitude = `pct(pct(base, 100 + 8·(turn−1) + instability/5), 100 − familiarity)`, min 1.

## World memory
resilience = `min(25, absorbed_harm/8)`; adaptation = `min(20, 5·transforms)`; capacity loss = `floor(redirects_in/2)`, capacity floor 4; crisis yield `max(40, 100 − 20·prior)`; familiarity `min(30, 10·seen)`.

## Assumptions
- Values are prototype placeholders tuned by bots only; no human data yet.
- Start health varies ±4 by seed.
