# Running the unit test suite locally (Windows / BYOND 516)

This documents the *working* way to run `code/modules/unit_tests` on a Windows dev
machine, learned the hard way on 2026-07-20. Read this before attempting a test run,
the obvious approaches fail silently.

**TL;DR: run `tools/run_unit_tests_local.sh` from Git Bash and read the summary.
Everything below is the "why".**

## Quick reference

| Thing | Value |
|---|---|
| One-shot runner | `tools/run_unit_tests_local.sh [port=1342] [boot_timeout=25m] [suite_timeout=25m]` |
| Compile | `tools\build\build.bat dm -DCIBUILDING` (~35 s) |
| Run | `cmd //c start "" //min //low "C:\Program Files (x86)\BYOND\bin\dd.exe" tgstation.dmb -port <port> -close -trusted -invisible -params "log-directory=ci"` |
| Results | `data/unit_tests.json`, per-test `status`: **0 = passed, 1 = failed, 2 = skipped** |
| Overall verdict | `data/logs/ci/clean_run.lk` exists **only** if the run was fully clean |
| Duration | ~35s compile; suite ~13 min idle-machine, much longer under load (trap #9). Trap #12 (`missing_icons` hang) was FIXED 2026-07-31, full runs complete again |

## How the suite is wired (for debugging)

- `-DCIBUILDING` on the compile command line ⇒ `code/_compile_options.dm:153` defines
  `UNIT_TESTS` (unless `OPENDREAM`), which compiles in the test datums and
  `REFERENCE_TRACKING` (the `qdel.dm:22 #warn` during compile proves it's active).
- Boot chain: `world/New()` → `RunUnattendedFunctions()` (`code/game/world.dm:177`) →
  `HandleTestRun()` sets `SSticker.start_immediately = TRUE` and registers a callback →
  **10 seconds after roundstart**, `RunUnitTests()` (`code/modules/unit_tests/unit_test.dm:365`)
  runs every `/datum/unit_test` subtype → writes `data/unit_tests.json` →
  `SSticker.force_ending` → `world/FinishTestRun()` (`code/game/world.dm:288`).
- `FinishTestRun()` only writes `clean_run.lk` if **both** zero failed tests **and**
  `GLOB.total_runtimes == 0`. Any runtime in the whole round fails the verdict, even if
  every test "passes".

## The traps (all observed, all cost real time)

1. **DreamDaemon on Windows produces no stdout.** It's a GUI app; everything printed to
   `world.log` goes to its window only. Worse, this codebase defines
   `USE_CUSTOM_ERROR_HANDLER` unconditionally, so `world.log` is *never* redirected to a
   file unless TGS is present (`code/game/world.dm:246-251`). Consequence: a test run is a
   black box, no `::group::` output, no progress, nothing. To get live output, temporarily
   add `world.log = "data/boot_debug.log"` as the first line of `world/New()` and tail that
   file (revert afterwards).
2. **Juke's `dm-test` target is a poor local experience.** It only checks for
   `clean_run.lk` after DreamDaemon exits, so all you ever see is "Test run was not clean".
   Use the runner script instead, which parses `unit_tests.json` and prints the actual
   failures.
3. **Launch DreamDaemon detached** (`cmd //c start "" //min ...`). Launched attached to a
   shell, `dd.exe` can stall at ~22 MB before `world/New()` ever runs, no logs, no error,
   forever. If `data/boot_debug.log`/round logs don't appear within ~60–90 s of launch, kill
   it and relaunch detached.
4. **Do not close the DD window mid-run, and do not connect a client to the test world.**
   Killing the window kills the suite; a connected player can interfere with round flow and
   even keep the world alive past the suite.
5. **Logs land in `data/logs/YYYY/MM/DD/round-<id>/`**, not in `data/logs/ci/`, only
   `clean_run.lk` honors the `log-directory=ci` param. Round logging requires the DB, so a
   local MySQL must be up (same as for normal local servers) for round ids.
6. The suite runs on the **live default map** (voidcrew overmap + ships), not a dedicated
   test map. Several tg-inherited tests assume a station map and fail in this fork
   (`mapping_nearstation_test`, `area_contents`, `mapload_space_verification`,
   `required_map_items`, `job_roundstart_spawnpoints`, `cargo_dep_order_locations`,
   `log_mapping`). Treat those as baseline noise unless you're working on them; compare
   against `data/unit_tests.json` from a known-good commit when in doubt.
7. After the suite, the world force-ends and DD exits on its own (`-close`). If a
   `dreamdaemon.exe` lingers afterwards, it's a zombie. Kill it by PID, but check
   `Get-CimInstance Win32_Process -Filter "Name='dreamdaemon.exe'"` creation times first so
   you don't kill someone's live dev server.
8. **Concurrent sprite regeneration breaks compiles.** If an icon pipeline (e.g. the
   sprite generator stage) is running, it rewrites `.dmi` files in place and DreamMaker
   fails with `'icons/map_icons/...': invalid expression` on whichever files are mid-write.
   The files look fine afterwards. The failure is the race, not the files. Wait for the
   pipeline to finish, then recompile.
9. **World boot time is wildly variable under load** (observed 1–16 min before the first
   log line). Heavy local processes, other running worlds, the sprite pipeline, AV scans
   of the freshly compiled `.rsc`. Can make a world sit at ~22 MB for many minutes before
   `world/New()`. It usually recovers on its own; the runner script's phase-1 wait (boot
   detection via `data/logs/ci/game.log` appearing) exists for exactly this. Don't kill a
   young DD just because it's small. Give it the boot timeout.
10. **Juke can silently skip the compile as "up to date"** (observed 2026-07-23): the
   runner's `build.bat dm -DCIBUILDING` step printed `:: Skipping 'dm' (up to date)` even
   though many `.dm` files had changed, so the suite booted a stale **non-test** dmb.
   World runs as a normal game, `unit_tests.json` never appears, phase 2 times out. Check
   the runner's compile output for the skip line; if present, delete `tgstation.dmb` (or
   compile a copy: `cp tgstation.dme unit_test_run.dme && dm.exe -DCIBUILDING
   unit_test_run.dme`, then launch DD on `unit_test_run.dmb`. This also avoids stomping a
   dev build someone is actively using).
11. **A CIBUILDING world boots MetaStation, not the voidcrew overmap** (see
   `perf-*-MetaStation.csv` and "Failed to load engraved messages on map MetaStation" in
   the ci logs). Init is slow (~1 min Atoms, ~1 min Lighting) but normal. Also: unit-test
   `.dm` files compile at their `code\modules\unit_tests` include position, **before**
   `voidcrew\_DEFINES\`: fork defines are undefined vars inside tests; use literals with
   a comment (the `voidcrew_loot.dm` convention).
12. **`missing_icons` HANGS rather than fails, and takes the whole suite with it**
   (observed 2026-07-24; it merely *failed* in the 2026-07-21 baseline, so this is a
   regression from 07-22..24 content work). It is early in the alphabet, so phase 2 always
   times out there and **no `unit_tests.json` is ever written. You get zero results for
   the entire suite, not just this test.** Diagnosis that proved it: focus five tests
   (trap #13) and `runtime.log` ends on a single `::group::/datum/unit_test/missing_icons`
   marker with nothing after it. Not caused by new module icons: the test only walks
   `icons/obj/` and `icons/effects/` (`missing_icons.dm:9-23`), so DMIs under
   `voidcrew/modules/*/icons/` are never opened by it. Prime suspect is its `flist()`
   recursion, which treats every non-`.dmi` entry as a directory and so descends into the
   thousands of `.png`/`.png.toml` icon-cutter sources under those roots. **Until it is
   fixed, the only way to get any test signal locally is a focused run.**
13a. **Use `dd.exe`, not `dreamdaemon.exe`, while a Dream Daemon panel window is open**
   (observed 2026-07-31, three times in a row): with an idle DD control panel running,
   every `dreamdaemon.exe <dmb>` launch parked at ~21 MB with **zero CPU ever**, not slow,
   never started; it appears to wait on the panel's single-instance management. The
   standalone `dd.exe` daemon is immune (it's how a second local world coexists with the
   panel at all). The runner script now launches `dd.exe` with `-port <port>` for exactly
   this reason. Diagnosis that proved it: sample the process twice
   (`Get-Process` `TotalProcessorTime`), a booting world accumulates CPU continuously; a
   parked one stays at 0.00 from birth.

13. **Running a subset: `TEST_FOCUS`.** Append `TEST_FOCUS(/datum/unit_test/foo)` lines to
   the **end** of `code/modules/unit_tests/_unit_tests.dm`, after the final `#endif`,
   `TEST_FOCUS` is deliberately left un-`#undef`ed for exactly this (see the comment at
   `_unit_tests.dm:336`), and by that point the test types already exist. With **any** test
   focused, only focused tests run, and they run alphabetically. Two rules: **revert the
   block before committing** (otherwise CI silently runs a handful of tests instead of 361),
   and `rm tgstation.dmb` first or you hit trap #10.

## Baseline (2026-07-21)

335 passed / 26 failed of 361 executed (2026-07-20 run: 337/24. The overnight sprite work
added `gloves_and_shoes_armor` and `worn_icons`). Notable real (non-mapping) failures:
`missing_icons`, `turf_icons`, `modify_fantasy_variable`, `create_and_destroy`
(icon issues in `voidcrew/icons/turf/floors/lava_grass_red.dmi`,
`voidcrew/modules/loot/icons/uniques.dmi`, `icons/obj/card.dmi`), `design_source`,
`spell_names`, `shapeshift_spell`, `shapeshift_health`, `outfit_sanity`,
`reagent_container_defaults`, `subsystem_init` (TTS), `closets`, `mob_faction`,
`strange_reagent`, `space_dragon_expiration`, `simple_animal_freeze`,
`dcs_check_list_arguments`. Regenerate with the runner script before trusting this list.
It drifts with content work.

**This prose list is currently the ONLY surviving baseline.** `data/unit_tests.json` was
deleted on 2026-07-24 during the trap #12 investigation, and it cannot be regenerated until
`missing_icons` stops hanging, because no run completes. Until then, compare focused-run
results against the names in this list. One entry is already stale: `missing_icons` is
listed above as a failure, which was true on 07-21 but it now hangs instead.

Script exit codes: 0 = fully clean (rare until the baseline is fixed), 1 = suite completed
but failures/runtimes exist (the normal current state), 2 = timeout/boot-stall. A
background task reporting "failed" for exit 1 is expected, not a script bug.
