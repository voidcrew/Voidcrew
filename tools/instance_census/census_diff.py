#!/usr/bin/env python3
"""Diff SSinstance_census snapshots to rank types by instance growth.

The game writes one JSON object per line to <round log dir>/instance_census.ndjson
(see voidcrew/controllers/subsystem/instance_census.dm). Address space in the
32-bit DreamDaemon is consumed by whatever grows here - absolute growth is what
matters, not percentages.

Usage:
  census_diff.py CENSUS.ndjson                 # diff first vs last snapshot
  census_diff.py CENSUS.ndjson -a 2 -b 7      # diff census #2 vs census #7
  census_diff.py CENSUS.ndjson --trend        # per-snapshot totals table
  census_diff.py early.json late.json         # diff two raw Count-Atoms JSONs
                                              # (the admin verb's download format)
  -n 50        show top 50 rows (default 40)
  --datums     diff the datum_types dicts instead of atom types
  --by-z       also diff the movables_by_z dict
"""
import argparse
import json
import sys


def load_ndjson(path):
    snaps = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                snaps.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"warning: skipping unparseable line: {e}", file=sys.stderr)
    return snaps


def load_raw_counts(path):
    """A raw Count Atoms/Datums admin-verb download: one flat {type: count} dict."""
    with open(path, encoding="utf-8", errors="replace") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: expected a JSON object of type -> count")
    return data


def pick_snapshot(snaps, census_number):
    if census_number is None:
        return None
    for snap in snaps:
        if snap.get("census") == census_number:
            return snap
    raise SystemExit(f"no snapshot with census == {census_number} "
                     f"(have {[s.get('census') for s in snaps]})")


def diff_counts(early, late, top_n, label):
    keys = set(early) | set(late)
    rows = []
    for key in keys:
        before = early.get(key, 0)
        after = late.get(key, 0)
        if before != after:
            rows.append((after - before, before, after, key))
    rows.sort(key=lambda r: r[0], reverse=True)

    total_before = sum(early.values())
    total_after = sum(late.values())
    print(f"\n== {label}: {total_before:,} -> {total_after:,} "
          f"({total_after - total_before:+,}) across {len(rows)} changed keys ==")
    print(f"{'delta':>12}  {'before':>10}  {'after':>10}  key")
    for delta, before, after, key in rows[:top_n]:
        print(f"{delta:>+12,}  {before:>10,}  {after:>10,}  {key}")
    shrunk = [r for r in rows if r[0] < 0]
    if shrunk and top_n < len(rows):
        print(f"  ... plus {len(rows) - top_n} more changed keys "
              f"({len(shrunk)} shrank; largest shrink: {shrunk[-1][0]:+,} {shrunk[-1][3]})")


def print_trend(snaps):
    cols = ["census", "realtime", "clients", "atoms_total", "maxz",
            "map_zones", "simulated_ships", "atom_walk_seconds"]
    print("  ".join(f"{c:>16}" for c in cols))
    for snap in snaps:
        print("  ".join(f"{snap.get(c, ''):>16}" for c in cols))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="+")
    parser.add_argument("-a", type=int, default=None, help="census number of the early snapshot")
    parser.add_argument("-b", type=int, default=None, help="census number of the late snapshot")
    parser.add_argument("-n", type=int, default=40, help="rows to show")
    parser.add_argument("--trend", action="store_true", help="print per-snapshot totals")
    parser.add_argument("--datums", action="store_true", help="diff datum_types instead of types")
    parser.add_argument("--by-z", action="store_true", help="also diff movables_by_z")
    args = parser.parse_args()

    if len(args.files) == 2:
        early, late = load_raw_counts(args.files[0]), load_raw_counts(args.files[1])
        diff_counts(early, late, args.n, "raw counts")
        return

    snaps = load_ndjson(args.files[0])
    if not snaps:
        raise SystemExit("no snapshots found")
    if args.trend:
        print_trend(snaps)
        return

    early = pick_snapshot(snaps, args.a) or snaps[0]
    late = pick_snapshot(snaps, args.b) or snaps[-1]
    if early is late:
        raise SystemExit("need two different snapshots (only one in file?)")
    print(f"diffing census #{early.get('census')} ({early.get('realtime')}, "
          f"{early.get('clients')} clients) -> #{late.get('census')} "
          f"({late.get('realtime')}, {late.get('clients')} clients)")

    key = "datum_types" if args.datums else "types"
    if key not in early or key not in late:
        raise SystemExit(f"snapshot lacks '{key}' (datum passes are opt-in: "
                         "set SSinstance_census.include_datums_next_fire = TRUE)")
    diff_counts(early[key], late[key], args.n, key)
    if args.by_z:
        diff_counts(early.get("movables_by_z", {}), late.get("movables_by_z", {}),
                    args.n, "movables by z")


if __name__ == "__main__":
    main()
