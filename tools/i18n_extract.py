#!/usr/bin/env python3
"""Collects translatable strings into localization/strings.csv.

Keys are the English source strings. Translations live in
localization/<lang>.json ({"English key": "translation"}) and are merged in.
Usage: python3 tools/i18n_extract.py [--check]   (--check exits 1 if any key lacks a translation)
"""
import csv, glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ["tr"]
STR = r'"((?:[^"\\]|\\.)*)"'
PATTERNS = [
    r'Loc\.t\(' + STR, r'Msg\.make\(' + STR, r'note_msg\([^\n]*?, ' + STR + r', \[', r'_set_reason\(w, ' + STR,
    r'_action_button\(' + STR + r', ' + STR, r'_action_button\([^\n]*?, ' + STR + r', w, c\)',
    r'UIKit\.(?:label|button|rich)\(' + STR, r'\.text = ' + STR, r'tooltip_text = ' + STR,
    r'UIKit\.button\([^"\n]*?' + STR + r'\)\s*$',
    r'"text": ' + STR, r'_section\(vb, ' + STR,
]


FORCE = {" (in %d)"}  # short strings the word heuristic would skip
EXTRA = ["Pressure", "Music", "Sound effects", "Show a sensible move for this season", "20 more valleys: Dry Hills and Boomtown", "New moves: Split, Delay, Controlled Crisis", "Daily valley and Classic mode", "One-time purchase. No ads. No subscription.", "Purchases are not available in this build.", "Nothing to restore.", "The purchase did not complete.", "The store did not answer. Please try again."]  # keys chosen at runtime that the patterns cannot see


def unescape(s):
    return json.loads('"' + s + '"')


def placeholders(s):
    return re.findall(r'%[-+0-9.]*[sdif]', s.replace('%%', ''))


def has_words(s):
    body = re.sub(r'%[-+0-9.]*[sdif%]', '', s)
    body = re.sub(r'\[[^\]]*\]', '', body)
    return re.search(r'[A-Za-z]{3,}', body) is not None


def collect():
    keys = []
    def add(k):
        if k and (has_words(k) or k in FORCE) and not re.fullmatch(r"[a-z_:]+", k) and k not in keys:
            keys.append(k)
    files = glob.glob(os.path.join(ROOT, "src", "**", "*.gd"), recursive=True)
    for f in sorted(files):
        src = open(f, encoding="utf-8").read()
        for pat in PATTERNS:
            for m in re.finditer(pat, src, re.M):
                for g in m.groups():
                    if g is not None:
                        add(unescape(g))
        for const in re.finditer(r'const (?:SPEED|LAYOUT|LANGUAGE)_NAMES := \[(.*?)\]', src):
            for m in re.finditer(STR, const.group(1)):
                add(unescape(m.group(1)))
    for k in EXTRA:
        add(k)
    data = json.load(open(os.path.join(ROOT, "data", "content.json"), encoding="utf-8"))
    for group, fields in [("systems", ["name"]), ("consequence_types", ["name"]), ("events", ["name", "text"]),
                          ("transformations", ["name", "text"]), ("crises", ["name", "text"]), ("scenarios", ["name", "description"])]:
        for item in data[group]:
            for fld in fields:
                add(item[fld])
    for iv in data["interventions"].values():
        add(iv["name"])
    camp_path = os.path.join(ROOT, "data", "campaign.json")
    if os.path.exists(camp_path):
        for lv in json.load(open(camp_path, encoding="utf-8"))["levels"]:
            for fld in ("name", "description", "region"):
                add(lv[fld])
    return keys


def main():
    keys = collect()
    tables = {}
    for lang in LANGS:
        path = os.path.join(ROOT, "localization", lang + ".json")
        tables[lang] = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    out = os.path.join(ROOT, "localization", "strings.csv")
    with open(out, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["keys", "en"] + LANGS)
        for k in keys:
            w.writerow([k, k] + [tables[l].get(k, "") for l in LANGS])
    missing = {l: [k for k in keys if k not in tables[l]] for l in LANGS}
    bad = []
    for l in LANGS:
        for k, v in tables[l].items():
            if k in keys and placeholders(k) != placeholders(v):
                bad.append((l, k, v))
    for l, k, v in bad:
        print("PLACEHOLDER MISMATCH [%s]: %r -> %r" % (l, k, v))
    unused = {l: [k for k in tables[l] if k not in keys] for l in LANGS}
    print("keys: %d" % len(keys))
    for l in LANGS:
        print("%s: missing %d, unused %d" % (l, len(missing[l]), len(unused[l])))
    if "--list-missing" in sys.argv:
        for k in missing["tr"]:
            print(json.dumps(k, ensure_ascii=False))
    if "--check" in sys.argv and (any(missing.values()) or bad):
        sys.exit(1)


if __name__ == "__main__":
    main()
