# Instance census — memory-growth diagnosis kit

Built for the 2026-08 OOM investigation: 32-bit DreamDaemon has a hard ~4096 MB
address-space ceiling, populated rounds were filling it in 2-3 hours, and nothing
recorded *which types* were growing. These tools make every round self-diagnosing.

## What the game now records (no setup needed)

1. **`SSinstance_census`** (`voidcrew/controllers/subsystem/instance_census.dm`)
   walks all atoms ~3 minutes after init (baseline; that snapshot also counts every
   datum, which blocks for a few seconds) and then every 30 minutes (atoms only,
   yielding — no hitch). Each snapshot appends one JSON line to
   `<round log dir>/instance_census.ndjson`: per-type counts, movables per z-level,
   totals, map-zone/ship counts.
   * To get a **datum** count later in a round (gas mixtures, lighting corners, and
     other non-atom datums), VV `SSinstance_census` and set
     `include_datums_next_fire = TRUE` — the next fire blocks for a few seconds.
2. **`SStime_track` perf CSV** gained columns (every 10 s):
   `world_contents, world_maxz, mob_count, alive_mobs, dead_mobs, overmap_ships,
   map_zones, gc_queue_total, gc_totaldels, gc_totalgcs`.
   A climbing `world_contents`/`map_zones` with flat player count is the leak
   signature; `gc_queue_total` climbing means qdel'd objects pile up unresolved.

## Host-side sampler (run on the server box)

```powershell
powershell -File sample-dd-mem.ps1 -OutFile dd-mem.csv -IntervalSeconds 30
```

Polls DreamDaemon's `VirtualMemorySize64` (the only number that matters on 32-bit;
the wall is 4096 MB) until the process dies, surviving TGS relaunches. Read-only.

## Analyzing after a round

```bash
# rank atom types by growth, first vs last snapshot
python census_diff.py instance_census.ndjson

# specific snapshots, more rows, datum types, per-z movables
python census_diff.py instance_census.ndjson -a 1 -b 6 -n 60 --datums --by-z

# per-snapshot totals (leak curve at a glance)
python census_diff.py instance_census.ndjson --trend

# also accepts two raw JSONs from the admin "Count Atoms/Datums" verb
python census_diff.py atoms_early.json atoms_late.json
```

Interpretation notes:

- Absolute growth is what fills address space — ignore percentages on small types.
- `movables_by_z` key `"0"` = contained in something or in nullspace. Growth there
  with flat on-map counts points at inventories/lists pinning deleted-ish objects.
- Pair the census timeline with `dd-mem.csv`: a type whose count tracks the MB
  curve is the leak; types that step once (a planet loading) are baseline cost.
- Cross-check with the round's `qdel.log` (hard-delete table, written only on
  clean shutdown) and the MC stat panel's SSgarbage queue/fail counts.
