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

## Churn soak (planet packing lifecycle)

`churn_soak.dm` + `run_churn_soak.sh` are a headless build/teardown soak for the multi-tenant
z-level work ("planet packing"). Unit tests cover the geometry; this covers the **memory**
claim, which needs repetition rather than assertions: repeated site builds and teardowns must
not grow `world.maxz` and must not leak instances.

Each cycle stands up eight tenants through the production entry points — four flat encounters
(`new /obj/structure/overmap/planet/empty` + `load_level()`, the `dock_in_empty_space()` path)
and four terrain planets, two lava and two ice (`SSovermap.spawn_dynamic_planet()` +
`load_level()`, the chart-contact path) — then tears every one of them down through
`unload_level()`. Since the mixed-biome wave all terrain planets share one packed class
(`MAP_TENANT_CLASS_PLANET`, capacity 4), so all four land on **one** z-level whatever their
biome; with the flat lattice that is **two** z-levels minted on cycle 1, and they must be
**re-dealt, not re-minted**, on every cycle after that.

Verdict lines written to the soak log:

1. `world.maxz` identical from cycle 2 onward.
2. Every map-zone slot free at the end (occupancy back to the pre-soak baseline).
3. Post-teardown instance counts flat across cycles 2..N, per counter, within a tolerance.
   Instances, never bytes — BYOND's arena quantization makes memory figures wobble.
   (On a long run this becomes a regression over the whole series — see *Overnight mode*.)
4. Planet surface ground carries no ungated lighting objects — measured at LOAD, not
   post-teardown, because a build that allocates thousands and a teardown that frees them
   again is perfectly flat cycle to cycle and so invisible to criterion 3.
5. The known ambient-lighting residue is still bounded.

```bash
bash tools/instance_census/run_churn_soak.sh              # from the repo root
SOAK_CYCLES=4 SOAK_TIMEOUT_MIN=30 bash tools/instance_census/run_churn_soak.sh
```

The script copies `tgstation.dme` to `soakcheck.dme`, appends the include of `churn_soak.dm`
(**never** add it to `tgstation.dme` — it hijacks `world/New()` and starts the round with no
players), compiles, launches DreamDaemon detached on port **5597**, polls for the verdict,
kills the world by PID and deletes `soakcheck.*`. Exit code 0 only on PASS.

Where the output lands (the soak log is never deleted):

- `data/churn_soak_<timestamp>.log` — the transcript: per-cycle instance tables, WARN/WATCH
  lines, the PASS/FAIL verdict.
- `data/churn_soak_dd.log` — `world.log` redirected from the first line of `world/New()`.
  DreamDaemon has no stdout on Windows and never writes `world.log` to a file on its own, so
  without this redirect a run is completely invisible; runtimes land here.
- `data/logs/churn_soak_<timestamp>/instance_census.ndjson` — one census snapshot per cycle,
  triggered on demand from `SSinstance_census`. Rank per-type growth the usual way:
  `python census_diff.py data/logs/churn_soak_<ts>/instance_census.ndjson --trend`.

Runtime is roughly 3-6 minutes per cycle (four terrain planet builds dominate), so ten cycles
will not fit the script's default 45-minute timeout on a busy machine. The harness has its own
35-minute wall budget and stops after whichever cycle it is on, writing a verdict over the
cycles it completed — three cycles is enough for every criterion. Raise `SOAK_TIMEOUT_MIN` for
the full ten, or set `SOAK_CYCLES=4` for a quick answer.

Known non-findings, so a FAIL is read correctly: `/area/overmap_encounter` instances created by
`fill_in()` are never qdel'd (pre-existing, tracked under the OOM initiative), which is why
`encounter_areas`, `areas`, `atoms` and `datums` carry a per-cycle tolerance while the
structural counters (`z_levels`, `map_zones`, `slots_used`, `map_footprints`, `docking_ports`,
`pipelines`) must return exactly. Counters that stay inside tolerance but rise on *every* cycle
are reported on a `WATCH` line rather than failed.

### The content zoo

Map zones are one allocation surface. Each cycle also stands up and tears down one of
everything else a live round pays for, on top of the planets rather than instead of them —
all through production entry points:

| module | what it churns | teardown |
| --- | --- | --- |
| **ship** | an NPC pirate hull from `SSnpc_ships.spawn_pirate()`: shuttle template load, **transit reservation**, mobile docking port, pipenets, areas, machinery, crew mobs | odd cycles `enter_integrity_failure()` → crash site → `abandon_ship()` + `despawn_derelict()`; even cycles `despawn_derelict()` straight from flight |
| **ruin** | a space ruin encounter: turf **reservation**, static `.dmm`, two stationary docks. Template varied per cycle | `release_interior()` |
| **field** | a landable asteroid field: reservation carved by a live map **generator**, ore seeding, loot, mob spawners. Severity rotated | `unload_level()` |
| **arena** | a vestige ascension arena: reservation, `.dmm`, a boss mob. Host rotated | `qdel(run)` (which *is* the production teardown) |
| **weather** | a real storm on one planet's own `/datum/weather_site`, via the scheduler's own `SSweather.run_weather()` call | `end()` before the planets go |

The ship module is the important one: it is the only thing here that churns shuttle template
loads and transit reservations. `SSnpc_ships.pirate_count_target` is pinned to **0** for the
soak so the reconcile does not spawn a replacement behind the harness's back.

Because a crash site is itself a flat-class tenant, an odd cycle stands up five flat tenants
against a four-slot lattice and mints a **second** flat level — so `world.maxz` reads one
higher than a zoo-less run. Minted once on cycle 1, re-dealt forever after.

Compile the zoo out with `DM_DEFINES=-DCHURN_SOAK_NO_ZOO`, or turn it off at runtime with
`SOAK_ZOO=0`.

### Overnight mode

```bash
SOAK_OVERNIGHT=1 SOAK_BUDGET_MIN=480 SOAK_NAME=soaknight SOAK_KEEP_DD=1 \
  bash tools/instance_census/run_churn_soak.sh
```

Bounded by the clock rather than a cycle count (~5 minutes per cycle, so ~90 cycles in eight
hours). The census walk drops to one per `SOAK_CENSUS_EVERY` cycles (5 by default overnight),
the script's timeout becomes `SOAK_BUDGET_MIN + SOAK_GRACE_MIN`, and `SOAK_KEEP_DD=1` stops
the script's exit trap from killing a world that is supposed to outlive its babysitter.

Once there are **8 or more** post-teardown samples the flatness criterion switches from an
endpoint comparison to a **least-squares regression** over cycles 3..N, and the slope in
instances/cycle is compared against the same per-cycle tolerance. Multiplying a per-cycle
noise floor by fifty spans makes every gate a rubber stamp, and two endpoints on a fifty-sample
oscillating series measure endpoint luck rather than a leak. Below 8 samples the original
endpoint gate runs unchanged.

Criterion 5 gates the **known ambient-lighting residue** separately (disowned light sources and
detached lighting corners): exempt from the flatness gate, but only for as long as the drift
stays inside 10% of the first reading.

Every knob is also a `world.params` key, so one `.dmb` serves both a smoke run and the real
thing: `churn-soak-budget-min`, `churn-soak-overnight`, `churn-soak-census-every`,
`churn-soak-zoo`, `churn-soak-cycles`, `churn-soak-log`.

**A crash is a result.** If DreamDaemon dies mid-run (usually the 4 GB wall), the script
preserves the soak log and the memory CSV and writes a `=== CHURN SOAK: CRASHED ===` block
naming the last cycle, the last full `SAMPLE` counter line and the last `virtMB`.

## Ghost round (a whole round, headless)

`ghost_round.dm` + `run_ghost_round.sh` are the soak's sibling. The soak asks "does a
build/teardown cycle leak?"; the ghost round asks "what does an hour of a full server actually
**cost**" — MC tick usage, time dilation, subsystem costs, atmos, AI, combat, memory — with a
dozen player hulls, ~70 crew mobs with minds, real pirates, and planets *and* ruins *and*
asteroid fields loaded concurrently. It cannot measure per-client cost: DM cannot fake a
`/client`, so SendMaps is absent from every figure.

```bash
bash tools/instance_census/run_ghost_round.sh                             # the default 70m round
GHOST_SMOKE=1 bash tools/instance_census/run_ghost_round.sh               # 12m reduced smoke
GHOST_REGIME=real GHOST_BUDGET_MIN=180 bash tools/instance_census/run_ghost_round.sh
```

Same build discipline as the soak: `ghost_round.dm` is **never** added to `tgstation.dme`, the
script copies the dme and appends the include. Port **5593**.

### Churn regimes

`GHOST_REGIME` (world param `ghost-round-regime`) picks the cadence set the sustained loop runs
on. Everything else — the fleet, the crew, the shims, the site kinds, the concurrency ceilings,
the teardown paths — is identical across all three.

| regime | founding | crew wipe | worldgen | mission dwell | vs a real 70-player round |
| --- | --- | --- | --- | --- | --- |
| `stress` *(default)* | wave every 20m | every 8m from T+15m | 5-site burst every 20m | 80–160s | **~1.2×** |
| `ordinary` | every 60m | every 24m from T+15m | 5-site burst every 60m | 240–480s | **~0.7×** |
| `real` | one hull every 5.0m | every 14.4m from T+45m | **continuous trickle**, median gap ~1.9m, ~32 loads/h | 80–160s | **1×, by construction** |

`real` is calibrated to production **round-7** (median 70 concurrent players, peak 78,
2026-08-16) — the only measured round that sits at the harness's own 70-crew default, so nothing
in it is pop-scaled. Measured targets: 12.1 hull foundings/h, 4.17 hull losses/h, ~32.1 site
loads/h of which ~5.0/h are full planet builds, median inter-arrival 1.9 min, 69% of 5-minute
windows carrying two or more loads. Its trickle draws one site 90% of fires, two 8%, three 2%,
on `rand(70,145)s` intervals with a 5% chance of a `rand(300,540)s` lull; the mix is 16% planet
/ 78% ruin / 6% asteroid field. The derivation and its simulated verification are in the
`THE SITE-LOAD TRICKLE` block at the top of `ghost_round.dm`.

`stress` stays the default so runs 1–4 remain comparable, and it is still the faster leak
detector on hull churn (21 foundings/h against a real 12.1). It is **not** an upper bound on
worldgen: on total site-load volume both legacy regimes are ~0.79× a real round.

`GHOST_CHURN_SCALE` still works and still means "multiply the legacy cadences" — `ordinary` is
exactly `GHOST_CHURN_SCALE=3`. Set explicitly it wins over the regime's default. It now also
scales the **mission-rotation dwell**, which it did not for the first four runs; that omission is
why `stress` and `ordinary` produced the same site-load rate (23.2/h vs 23.3/h) despite a 3×
knob. The `real` regime ignores `churn_scale` entirely.

## Host-side sampler (run on the server box)

```powershell
powershell -File sample-dd-mem.ps1 -OutFile dd-mem.csv -IntervalSeconds 30
powershell -File sample-dd-mem.ps1 -ProcessId 1234 -OutFile soak-mem.csv -IntervalSeconds 20
```

Polls DreamDaemon's `VirtualMemorySize64` (the only number that matters on 32-bit;
the wall is 4096 MB) until the process dies, surviving TGS relaunches. Read-only.

With `-ProcessId` it watches **exactly** that process and exits when it goes away. Use it on
any box where more than one world can be running — a unit-test suite, a playtest and a soak all
present at once make "newest dd.exe wins" pick the wrong one. `run_churn_soak.sh` starts the
sampler this way automatically against its own world and writes
`data/churn_soak_<timestamp>_mem.csv` next to the soak log, then appends a `REPORT memory` line
(first / last / peak virtMB, percentage of the wall, MB per hour over the run and over the
final half) to the transcript at the end. That line is **advisory**: arena quantization makes a
VM figure wobble, so the instance counters stay the hard gates and a VM slope is a lead to
follow with `census_diff.py`.

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
