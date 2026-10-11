"""Podsumowanie logu progresji (user://progress_log.txt, QuizRpgProgressLog) w tabelę Markdown.

Użycie:  python tools/progress_summary.py plik1.txt [plik2.txt ...]
Log zwykle leży w %APPDATA%\\Godot\\app_userdata\\<nazwa projektu>\\progress_log.txt (kilku testerów = kilka plików).

Na sesję: tabela map (czas, walki: wygrane / ucieczki / porażki, XP z walk, poziom na wejściu i na wyjściu) i lista awansów
(po ilu walkach i jakim czasie od poprzedniego). Cel balansu: poziom przy bossie, liczba walk i czas przejścia mapy
(docs/kontekst/poziomy_i_xp.md).
"""
import re
import sys

LINE = re.compile(r"^\[(\d+):(\d+):(\d+)\] (.*?) \| (\S+) \| (.*)$")
LV = re.compile(r"Lv (\d+)")
XP = re.compile(r"xp \+(\d+)")


def seconds(m):
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3))


def fmt(s):
    return "%d:%02d:%02d" % (s // 3600, (s // 60) % 60, s % 60)


def parse(path):
    sessions = []
    cur = None
    with open(path, encoding="utf-8") as f:
        for raw in f:
            raw = raw.rstrip("\n")
            if raw.startswith("===== SESJA"):
                cur = {"title": raw.strip("= ").strip(), "events": []}
                sessions.append(cur)
                continue
            m = LINE.match(raw)
            if m and cur is not None:
                lv = LV.search(m.group(4))
                cur["events"].append({
                    "t": seconds(m), "lv": int(lv.group(1)) if lv else 0,
                    "kind": m.group(5), "detail": m.group(6),
                })
    return sessions


def summarize(session):
    maps = []
    awans = []
    last_t = 0
    boss = []
    for e in session["events"]:
        last_t = max(last_t, e["t"])
        if e["kind"] == "mapa":
            maps.append({"name": e["detail"].rsplit("/", 1)[-1], "t0": e["t"], "lv0": e["lv"], "t1": None, "lv1": e["lv"],
                         "win": 0, "flee": 0, "lose": 0, "xp": 0})
        elif maps and e["kind"].startswith("walka-"):
            m = maps[-1]
            outcome = e["kind"][6:]
            key = {"wygrana": "win", "ucieczka": "flee", "porazka": "lose", "porażka": "lose"}.get(outcome, "lose")
            m[key] += 1
            xp = XP.search(e["detail"])
            if xp:
                m["xp"] += int(xp.group(1))
            m["lv1"] = e["lv"]
            if e["detail"].startswith("BOSS"):
                boss.append((m["name"], e["t"], e["lv"], outcome))
        elif e["kind"] == "AWANS":
            awans.append(e)
            if maps:
                maps[-1]["lv1"] = e["lv"]
    for i, m in enumerate(maps):
        m["t1"] = maps[i + 1]["t0"] if i + 1 < len(maps) else last_t
    return maps, awans, boss


def main(paths):
    sys.stdout.reconfigure(encoding="utf-8")
    for path in paths:
        for s in parse(path):
            maps, awans, boss = summarize(s)
            print("## %s  (%s)\n" % (s["title"], path))
            if maps:
                print("| mapa | czas | walki (W / U / P) | XP z walk | poziom wejście → wyjście |")
                print("|---|---|---|---|---|")
                for m in maps:
                    print("| %s | %s | %d / %d / %d | %d | %d → %d |" % (
                        m["name"], fmt(m["t1"] - m["t0"]), m["win"], m["flee"], m["lose"], m["xp"], m["lv0"], m["lv1"]))
            else:
                print("(brak wejść na mapy)")
            if boss:
                print("\nBossowie: " + "; ".join("%s o %s (lv %d, %s)" % (n, fmt(t), lv, o) for n, t, lv, o in boss))
            if awans:
                print("\nAwanse:\n")
                for e in awans:
                    print("- %s: %s" % (fmt(e["t"]), e["detail"]))
            print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1:])
