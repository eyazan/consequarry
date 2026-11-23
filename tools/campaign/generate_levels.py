#!/usr/bin/env python3
"""Generates data/campaign.json (30 short levels in 3 regions).

Star thresholds start as placeholders and are calibrated by
tools/campaign/calibrate.gd from bot runs (writes data/campaign_stars.json,
which this script merges in when present).
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ALL = ["energy", "industry", "infrastructure", "population", "agriculture", "environment"]
S3 = ["energy", "industry", "infrastructure"]
S4 = S3 + ["environment"]
S5 = S4 + ["population"]
E3 = ["industrial_accident", "blackout", "grid_surge", "labor_strike"]
E4 = E3 + ["toxic_spill"]
E5 = E4 + ["migration_wave"]
E6 = []  # all events
DRY = {"heatwave": 230, "wildfire": 210, "crop_blight": 150, "flood": 30}
BOOM = {"industrial_accident": 220, "toxic_spill": 200, "labor_strike": 180, "migration_wave": 160}

# (name, systems, events, allowed, turns, moves, leak, magnitude%, weights, intro, scripted)
L = [
 # --- River Valley: learn to move troubles
 ("First Spill", S3, E3, ["redirect"], 4, 2, 0, 80, {}, "Drag a trouble onto another district. Heat hurts factories, but barely touches power plants.", {"1": ["industrial_accident"], "2": ["blackout"]}),
 ("Hot Wires", S3, E3, ["redirect"], 4, 2, 0, 85, {}, "Every district is weak to something. Tap a district to see what hurts it.", {}),
 ("Never Clean", S3, E3, ["redirect"], 4, 2, 20, 90, {}, "From now on, moving a trouble leaves a small piece behind.", {}),
 ("Turbines", S4, E4, ["redirect", "transform"], 5, 2, 20, 85, {}, "Tap heat sitting on Energy to turn it into a green bonus. The smoke goes to Environment.", {"1": ["grid_surge"]}),
 ("Green Ledger", S4, E4, ["redirect", "transform"], 5, 2, 20, 90, {}, "Bonuses heal. Use them to keep weak districts alive.", {}),
 ("New Arrivals", S5, E5, ["redirect", "transform"], 5, 3, 20, 85, {}, "People arrive. If Population collapses, you lose.", {"1": ["migration_wave"]}),
 ("Overtime", S5, E5, ["redirect", "transform"], 5, 3, 20, 90, {}, "Unrest at Industry can be turned into work.", {}),
 ("Fields", ALL, E6, ["redirect", "transform"], 5, 3, 20, 85, {}, "Farms join the valley. Heat and pollution ruin crops.", {}),
 ("Full Valley", ALL, E6, ["redirect", "transform"], 5, 3, 20, 90, {}, "All six districts. Keep every one standing.", {}),
 ("River Test", ALL, E6, ["redirect", "transform"], 6, 3, 20, 95, {}, "A longer season run. Plan ahead with the forecast.", {}),
 # --- Dry Hills: share the load
 ("Dry Wind", ALL, E6, ["redirect", "transform", "split"], 5, 3, 20, 90, DRY, "Split a big trouble so two districts share it.", {}),
 ("Ember Ridge", ALL, E6, ["redirect", "transform", "split"], 5, 3, 20, 95, DRY, "Wildfires burn forests and fields. Spread the heat.", {}),
 ("Thirst", ALL, E6, ["redirect", "transform", "split"], 5, 3, 20, 100, DRY, "Weak districts attract more trouble. Heal them early.", {}),
 ("Later", ALL, E6, ["redirect", "transform", "split", "delay"], 5, 3, 20, 95, DRY, "Delay pushes a trouble to next season, but it grows a little.", {}),
 ("Dust Season", ALL, E6, ["redirect", "transform", "split", "delay"], 6, 3, 20, 100, DRY, "Use every tool. The forecast shows what comes next.", {}),
 ("Cracked Earth", ALL, E6, ["redirect", "transform", "split", "delay"], 5, 3, 20, 105, DRY, "Districts that took many hits grow tougher.", {}),
 ("Heat Dome", ALL, E6, ["redirect", "transform", "split", "delay"], 6, 3, 20, 105, DRY, "A long hot run. Keep Agriculture alive.", {}),
 ("Last Well", ALL, E6, ["redirect", "transform", "split", "delay"], 5, 3, 20, 110, DRY, "Every district you lean on gets a little weaker at absorbing.", {}),
 ("Firebreak", ALL, E6, ["redirect", "transform", "split", "delay"], 6, 3, 20, 110, DRY, "Think two seasons ahead.", {}),
 ("Dry Hills Test", ALL, E6, ["redirect", "transform", "split", "delay"], 6, 3, 20, 115, DRY, "The hardest dry season.", {}),
 # --- Boomtown: risky power
 ("Smokestacks", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 5, 3, 20, 95, BOOM, "Tap a district to start a controlled crisis: a big bonus now, a cost later.", {}),
 ("Night Shift", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 5, 3, 20, 100, BOOM, "Strikes and accidents everywhere. Turn unrest into work.", {}),
 ("Poison River", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 5, 3, 20, 105, BOOM, "Spills hit the Environment. Fields can absorb pollution.", {}),
 ("Boom", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 6, 3, 20, 105, BOOM, "Each crisis costs more than the last.", {}),
 ("Gridlock", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 5, 3, 20, 110, BOOM, "Watch the instability bar. At 100 the town falls apart.", {}),
 ("Overpressure", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 6, 3, 20, 110, BOOM, "A long, busy run.", {}),
 ("Company Town", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 6, 3, 20, 115, BOOM, "Keep the people on your side.", {}),
 ("Meltdown Eve", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 6, 3, 20, 115, BOOM, "Everything at once.", {}),
 ("Iron Winter", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 6, 3, 20, 120, BOOM, "Almost there.", {}),
 ("Boomtown Test", ALL, E6, ["redirect", "transform", "split", "delay", "crisis"], 6, 3, 20, 125, BOOM, "The final valley.", {}),
]
REGIONS = ["River Valley"] * 10 + ["Dry Hills"] * 10 + ["Boomtown"] * 10


def main():
    stars_path = os.path.join(ROOT, "data", "campaign_stars.json")
    calibrated = json.load(open(stars_path)) if os.path.exists(stars_path) else {}
    levels = []
    for i, (name, systems, events, allowed, turns, moves, leak, mag, weights, intro, scripted) in enumerate(L):
        lid = "lvl_%02d" % (i + 1)
        d = i / (len(L) - 1)  # 0 → 1 difficulty curve
        floor = int(round(25 + 8 * d))
        stars = calibrated.get(lid, {"min_health": floor, "two": 55, "three": 65})
        stars["min_health"] = floor
        content = json.load(open(os.path.join(ROOT, "data", "content.json")))
        start = {sd["id"]: int(sd["start_health"]) - int(round(8 * d)) for sd in content["systems"] if sd["id"] in systems}
        # Give each level a character: one district starts weak (rotates).
        weak = systems[(i * 2 + 1) % len(systems)] if i >= 1 else ""
        if weak:
            start[weak] -= 12
        mag = int(stars.get("magnitude_percent", mag))
        per_turn = 1 if i < 6 else 2
        levels.append({
            "id": lid, "number": i + 1, "name": name, "region": REGIONS[i], "description": intro, "weak": weak,
            "turns": turns, "actions_per_turn": moves, "systems": systems, "events": events,
            "allowed": allowed, "rules": {"redirect_leak_percent": leak},
            "magnitude_percent": mag, "magnitude_turn_scale": 4, "event_weights": weights,
            "events_per_turn": per_turn, "extra_event_instability": 55, "extra_event_from_turn": 99,
            "start_health": start,
            "win": {"avg_health": 0, "min_health": stars["min_health"]},
            "loss": {"max_collapsed": 1, "critical": ["population"], "max_instability": 100},
            "stars": {"two_avg": stars["two"], "three_avg": stars["three"]},
            "scripted_events": scripted,
        })
    json.dump({"version": 1, "levels": levels}, open(os.path.join(ROOT, "data", "campaign.json"), "w"), indent=1)
    print("wrote %d levels" % len(levels))


if __name__ == "__main__":
    main()
