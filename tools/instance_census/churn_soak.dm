/**
 * # Planet-packing memory churn soak
 *
 * NOT part of tgstation.dme, and it must never be. `tools/instance_census/run_churn_soak.sh`
 * copies the dme, appends an include of this file to the COPY, and compiles that. Because
 * the include lands LAST, the duplicate `/world/New()` and `/world/RunUnattendedFunctions()`
 * definitions below chain OUTSIDE the upstream ones (DM chains duplicate procs; the last
 * include wins the outermost frame), which is what lets the log redirect happen before
 * anything else in the boot writes a line.
 *
 * ## What it proves
 *
 * The packing waves claim that a site build followed by a site teardown is memory-neutral:
 * z-levels are minted once and then recycled, map-zone slots come back, and the instances a
 * build creates (lighting objects, light sources, pipelines, docking ports, mobs) are all
 * gone again afterwards. Geometry is covered by `/datum/unit_test/voidcrew_map_packing`.
 * This covers the lifecycle claim, which a unit test cannot: it needs repetition.
 *
 * Each cycle stands up 8 tenants through the production entry points, waits for them, tears
 * them all down through the production teardowns, and samples instance counts on both sides:
 *
 *   4 flat encounters  - `new /obj/structure/overmap/planet/empty(overmap_turf)` then
 *                        `load_level()`, exactly what `dock_in_empty_space()` does. Class
 *                        `flat`, so all four pack onto ONE z-level.
 *   2 lava planets     - `SSovermap.spawn_dynamic_planet()` then `load_level()`, exactly what
 *   2 ice planets        the chart contact + a docking ship do. Terrain planets all share one
 *                        packed class (`planet`, capacity 4) since the mixed-biome wave, so
 *                        all FOUR land on ONE z-level regardless of biome - which is the
 *                        point: every cycle exercises mixed-biome co-tenancy.
 *
 * Two z-levels are therefore minted on cycle 1 (one flat lattice, one planet lattice) and must
 * be re-dealt, not re-minted, on every cycle after that. That is the headline assertion.
 *
 * With the content zoo on there is a THIRD level, and it is expected: a crash site is itself
 * a flat-class tenant, so an odd (crash-variant) cycle stands up five flat tenants against a
 * lattice that holds four, and the fifth mints a second flat level. That level is minted once
 * on cycle 1 and re-dealt forever after, exactly like the first two - so `world.maxz` reads
 * one higher than a zoo-less run and is still identical from cycle 2 onward, which is what
 * criterion 1 actually asserts. If the number climbs past that, the packing is re-minting.
 *
 * ## Verdict
 *
 * Written to the soak log as `CHURN SOAK VERDICT: PASS` / `FAIL`, preceded by one PASS/FAIL
 * line per criterion:
 *
 *   1. `world.maxz` identical across cycles 2..N (cycle 1 legitimately mints the lattice).
 *   2. Every map-zone slot free at the end - occupancy back to the pre-soak baseline.
 *   3. Post-teardown instance counts flat across cycles 2..N, within a per-counter
 *      tolerance. Instances are counted, never bytes: BYOND's arena quantization makes
 *      memory figures wobble, instance counts do not.
 *
 * ## The content zoo (`-DCHURN_SOAK_NO_ZOO` to compile it out)
 *
 * Map zones are only one of the surfaces a live round allocates against, so each cycle also
 * stands up and tears down one of everything else, all through production entry points:
 *
 *   ships    - an NPC pirate hull from `SSnpc_ships.spawn_pirate()`, killed two different
 *              ways on alternating cycles: hull-kill into a crash site on odd cycles,
 *              straight `abandon_ship()` + `despawn_derelict()` on even ones. This is the
 *              only module that churns shuttle template loads, TRANSIT reservations, mobile
 *              docking ports, pipenets and mob rosters.
 *   ruins    - a space ruin encounter (lattice slot + static .dmm), template varied.
 *   fields   - a landable asteroid field (lattice slot + a live map GENERATOR, ore
 *              seeding, loot and mob spawners), severity varied.
 *   arenas   - a vestige ascension arena (turf reservation + .dmm + a boss mob), host
 *              varied. See build_vestige_arena() for the one thing headless cannot do.
 *   weather  - a real storm on one planet's own `/datum/weather_site`, ended before the
 *              planets are torn down.
 *
 * ## Overnight mode (`-DCHURN_SOAK_OVERNIGHT`, or `churn-soak-overnight=1` in params)
 *
 * The run is bounded by a wall-clock budget (default 8 hours, `churn-soak-budget-min`)
 * instead of a cycle count, the census walk drops to one per `CHURN_SOAK_CENSUS_EVERY`
 * cycles, and the flatness verdict switches from an endpoint comparison to a REGRESSION
 * over the whole series once there are 8 or more samples - see judge_by_regression() for
 * why multiplying a per-cycle tolerance by fifty spans is the wrong gate.
 *
 * ## Not covered (the soak's blind spots)
 *
 * * No crew is ever on a site, and no PLAYER ship docks anywhere: the hull the zoo spawns
 *   dies where it stands. The crewed-teardown refusal, the dock-claim handshake and
 *   SSovermap's own derelict sweep are all untested - the sweep is actively suppressed so a
 *   crewless roundstart hull cannot despawn mid-soak and pollute the counts.
 * * Roundstart planet contacts are disabled (`spawn_planets = FALSE`) so the map-zone pool
 *   starts empty and every zone in the verdict is one the soak itself dealt.
 * * The planet markers are qdel'd after their teardown rather than left as relocated
 *   contacts, so `GLOB.overmap_planets` does not grow by 4 a cycle and drown the deltas.
 * * Player outposts (`MAP_TENANT_CLASS_OUTPOST`) and SOLO-class encounters are not driven.
 */

#ifndef CHURN_SOAK_CYCLES
/// How many build/teardown cycles to run. Cycle 1 is the lattice-minting cycle and is
/// excluded from every "did it grow" comparison, so 2 is the practical minimum.
#define CHURN_SOAK_CYCLES 10
#endif

#ifndef CHURN_SOAK_FLATS_PER_CYCLE
/// One full lattice of flat encounters (MAP_SLOT_LATTICE_CAPACITY).
#define CHURN_SOAK_FLATS_PER_CYCLE 4
#endif

#ifndef CHURN_SOAK_SURFACE_LIT_SHARE
/// Coarse backstop: largest share of one planet footprint's ambient-lit GROUND that may
/// still carry a /datum/lighting_object. This is NOT the leak detector - `gate_miss` is,
/// with a tolerance of zero. This one exists only to catch a wholesale regression back to
/// per-turf surface lighting even if the classifier itself broke, which is why the ceiling
/// is generous.
///
/// Calibrated, not guessed. The first post-port 5-cycle soak
/// (data/churn_soak_20260818-221424.log) measured 20 planet builds: aggregate
/// 9620/123432 = 7.8%, per-planet range 1.3% - 16.3%, and the spread tracks which ruins
/// the RNG dealt rather than anything systematic (cycle 3 alone ran 1.3% and 9.5% on two
/// planets of the same biome). Every survivor lights itself: self-lit basalt on lava
/// ground, lava rivers, the fallout zone's green, /lit tiles a ruin .dmm placed directly,
/// and the ruin-daylight sources light_ruin_terrain() puts back on outdoor ruin yards.
/// RECALIBRATED 2026-08-19 on a 10x larger sample. The 20-build calibration above could
/// not see the tail. The 52-cycle soak (data/churn_soak_20260819-143611.log) measured
/// **208** planet builds: aggregate 125611/1241714 = 10.1%, mean 10.12%, sd 4.89,
/// median 9.4%, p95 19.1%, p99 21.1%, max 25.5%. The old 0.25 ceiling sat at mean+3.0sd,
/// so ~1 build in 370 clears it by chance alone - at 208 builds per run that is an
/// expected 0.6 false failures every run, and the run duly produced 2 (cycle 1 Frozen
/// Planet II 25.5%, cycle 42 Lava Planet II 25.3%). Both were legitimate content: the
/// `gate_miss` and `bleed` detectors that actually find leaks read 0 on all 208 builds,
/// and every survivor on those two planets was self-lit lava or plasma ground.
///
/// 0.35 is mean+5.1sd - no expected false failure in a run of this length - while still
/// roughly a third of the ~100% a wholesale regression produces, which is all this
/// backstop was ever meant to catch. Raise the sample, not the ceiling, if it fires again.
#define CHURN_SOAK_SURFACE_LIT_SHARE 0.35
#endif

#ifndef CHURN_SOAK_WALL_BUDGET_MIN
#ifdef CHURN_SOAK_OVERNIGHT
/// Overnight default: eight hours of churn. The driver's own timeout must be this plus a
/// grace period, or the shell script reaps a run that was still working.
#define CHURN_SOAK_WALL_BUDGET_MIN 480
#else
#define CHURN_SOAK_WALL_BUDGET_MIN 35
#endif
#endif

/// Real-time budget for the whole cycle loop. When a completed cycle leaves less than a
/// cycle's worth of budget, the loop stops early and writes its verdict over however many
/// cycles it managed - a short PASS/FAIL beats a run the shell script has to time out.
/// In OVERNIGHT mode this is the ONLY stop condition; the cycle count is effectively
/// unlimited. Overridable at runtime with `churn-soak-budget-min` in world.params, which is
/// what the driver actually uses (a numeric -D is not portable across dm.exe versions).
#define CHURN_SOAK_WALL_BUDGET (CHURN_SOAK_WALL_BUDGET_MIN MINUTES)

#ifndef CHURN_SOAK_CENSUS_EVERY
#ifdef CHURN_SOAK_OVERNIGHT
/// One NDJSON census snapshot every N cycles. Every cycle is right for a 4-cycle run and
/// wrong for a 60-cycle one: the walk is the most expensive thing the soak does and 60
/// snapshots of a 700k-atom world is a lot of disk for no extra signal.
#define CHURN_SOAK_CENSUS_EVERY 5
#else
#define CHURN_SOAK_CENSUS_EVERY 1
#endif
#endif

// ---------------------------------------------------------------------------------------
// The content zoo
//
// Everything above this line churns MAP ZONES (flats and planets). The zoo churns the
// other four allocation surfaces a live round actually pays for, all through production
// entry points:
//
//   SHIPS   - a real NPC hull loaded from its shuttle template, then killed two different
//             ways on alternating cycles. This is the big one: it churns shuttle template
//             loads, transit reservations, mobile docking ports, pipenets, atmos machinery
//             and mob rosters, none of which the map-zone soak touches at all.
//   RUINS   - a space ruin encounter: turf RESERVATION (not a map zone), static template
//             stamp, two stationary docks. Template varies per cycle.
//   FIELDS  - a landable asteroid field: a lattice slot carved by a live map GENERATOR
//             plus ore seeding, loot crates and mob spawners. Severity varies per cycle.
//   ARENAS  - a vestige ascension arena: turf reservation, static template, a boss mob,
//             torn down through the run datum's own Destroy(). See churn_arena() for the
//             one thing this cannot drive headless.
//   WEATHER - a real storm on one planet's own /datum/weather_site, so storm datums, area
//             overlay caches and the impacted-area lookups churn with the planets.
//
// Compile the zoo out with -DCHURN_SOAK_NO_ZOO to get the original map-zone-only soak.
// ---------------------------------------------------------------------------------------

#ifdef CHURN_SOAK_NO_ZOO
#define CHURN_SOAK_ZOO 0
#else
#define CHURN_SOAK_ZOO 1
#endif

/// Post-teardown samples needed before the verdict judges flatness by REGRESSION over the
/// whole series instead of by comparing two endpoints. Below this the series is too short
/// for a slope to mean anything and the original endpoint gate is the better test; above
/// it, endpoint comparison is actively misleading (see judge_by_regression).
#define CHURN_SOAK_REGRESSION_MIN_CYCLES 8

/// How long one zoo tenant (hull, ruin, field, arena) is given to stand up.
#define CHURN_SOAK_ZOO_LOAD_TIMEOUT (5 MINUTES)
/// How long one zoo tenant is given to go away again.
#define CHURN_SOAK_ZOO_TEARDOWN_TIMEOUT (3 MINUTES)

/// How long one site is given to finish loading before the soak calls it a timeout.
#define CHURN_SOAK_LOAD_TIMEOUT (6 MINUTES)
/// How long one site is given to finish tearing down.
#define CHURN_SOAK_TEARDOWN_TIMEOUT (5 MINUTES)
/// How long to wait for the round to reach a state the soak can run in.
#define CHURN_SOAK_BOOT_TIMEOUT (20 MINUTES)
/// The watchdog fires when the driver has not ticked its progress stamp for this long.
/// A DM runtime unwinds the driver silently and there is no `finally` in this language, so
/// a stalled progress stamp is how an exception is detected. try/catch is deliberately NOT
/// used - a caught runtime inside a map template load leaves dead maps behind.
#define CHURN_SOAK_WATCHDOG_STALL (12 MINUTES)

/// Fallback log path when the launcher did not pass one in `-params`.
#define CHURN_SOAK_DEFAULT_LOG "data/churn_soak.log"
/// Where the world's own log (runtimes, stack traces, log_world) is redirected. DreamDaemon
/// has no stdout on Windows and never writes world.log to a file on its own.
#define CHURN_SOAK_DD_LOG "data/churn_soak_dd.log"
/// Written at boot with the resolved soak log path, so a launcher that did not choose one
/// can still find it.
#define CHURN_SOAK_POINTER "data/churn_soak_latest.txt"

// ---------------------------------------------------------------------------------------
// World-level overrides. These chain outside the upstream definitions.
// ---------------------------------------------------------------------------------------

/world/New()
	// Before ..(): the upstream body loads config, sets up logs and runs the whole of
	// Master.Initialize(). Everything any of that writes is invisible otherwise.
	churn_soak_preserve_previous_logs()
	world.log = file(CHURN_SOAK_DD_LOG)
	..()
	// SetupLogs() reassigns world.log to the round's dd.log partway through the parent
	// call. Take it back so the soak's runtimes land in one predictable file.
	world.log = file(CHURN_SOAK_DD_LOG)

/**
 * A REBOOT IS A RUN-ENDING EVENT, NEVER A RESTART.
 *
 * Overnight run of 2026-08-19: the Master Controller died at 07:39 under a flood of atmos
 * runtimes and its recovery path called world.Reboot(). That did three separate kinds of
 * damage, and this override exists to stop all three:
 *
 * 1. The seven hours of counters that had already been collected were never judged - the
 *    verdict lives at the end of run_cycles() and the reboot jumped over it.
 * 2. The world came back up on the SAME params, re-armed itself and ran a second, pointless
 *    soak on top of the first ("the ghost run"), which is what the morning actually found.
 * 3. Everything keyed on the round - the census NDJSON, the per-round log directory - was
 *    reopened from scratch and the night's history went with it.
 *
 * So: write the verdict off whatever cycles DID complete, flush, and take the world down
 * instead of bringing it back up. `qdel(world)` is the same clean headless exit the normal
 * end of run_cycles() uses, and the driver already treats "DreamDaemon gone" as a run end -
 * except now there is a verdict in the log when it looks.
 *
 * Guarded on `launched` so this only ever fires on a live soak; a reboot before the round
 * starts (there should be none, delay_end is set) still behaves normally.
 */
/// (Defaults copied from the parent on purpose: omitting them would hand `null` to every
/// caller that relies on them, including the `..()` below.)
/world/Reboot(reason = 0, fast_track = FALSE)
	if(SSchurn_soak && SSchurn_soak.launched && !SSchurn_soak.verdict_written)
		SSchurn_soak.soak_log("=== CHURN SOAK: UNEXPECTED REBOOT ===")
		SSchurn_soak.soak_log("world.Reboot(reason=[reason ? reason : "none"]) was called mid-soak - almost always Master Controller recovery. Writing the verdict off the cycles completed so far, then shutting the world down rather than letting a second soak start on top of this one.")
		SSchurn_soak.soak_log("world runtimes at reboot: [GLOB.total_runtimes]; last progress: [SSchurn_soak.progress_label]")
		SSchurn_soak.write_verdict("world.Reboot() mid-run (MC recovery) - the run was cut short here, the counters above cover only the completed cycles")
		// Never reach ..(): rebooting is exactly what must not happen. No sleep before the
		// shutdown either - a reboot here usually means the MC is already dead, and a sleep
		// that never resumes would leave DreamDaemon alive and idle until the driver's
		// timeout. Every write above is synchronous (rustg_file_append), so nothing is lost.
		qdel(world)
		return
	return ..()

/**
 * Copies an existing soak transcript and world log aside before this boot can touch them.
 *
 * The soak log is append-only (rustg_file_append), but the overnight run still came back in
 * the morning holding nothing but the post-reboot hours, so something in the reboot path
 * truncates it. Rather than find out which layer did it, take the cheap insurance: if either
 * file already has content when a world boots, snapshot it to `<name>.prev<N>` first. A
 * second boot on the same params - the exact ghost-run signature - therefore cannot destroy
 * the first run's evidence even if this override of /world/Reboot() is somehow bypassed.
 *
 * Runs before ..() and before SSchurn_soak exists, so it re-reads the path out of world.params
 * itself rather than asking the subsystem.
 */
/proc/churn_soak_preserve_previous_logs()
	var/list/launch_params = world.params
	var/soak_path = launch_params ? launch_params["churn-soak-log"] : null
	if(!istext(soak_path) || !length(soak_path))
		soak_path = CHURN_SOAK_DEFAULT_LOG
	for(var/path in list(soak_path, CHURN_SOAK_DD_LOG))
		if(!fexists(path))
			continue
		var/existing = rustg_file_read(path)
		if(!length(existing))
			continue
		// Never overwrite an earlier snapshot: a third boot must not eat the second's.
		for(var/attempt in 1 to 20)
			var/snapshot = "[path].prev[attempt]"
			if(fexists(snapshot))
				continue
			rustg_file_write(existing, snapshot)
			rustg_file_append("\[[time_stamp()]\] === a new world booted on this log path; the [length(existing)] bytes written before this line were copied to [snapshot] ===\n", path)
			break

// Override form (no `proc/`) of the existing /world/proc/RunUnattendedFunctions - the
// duplicate definition chains, and being last in the dme this body is the outer one.
/world/RunUnattendedFunctions()
	..()
	churn_soak_arm_unattended()

/**
 * Turns a clientless world into one that will actually run the soak.
 *
 * Same shape as `setup_autowiki()`, which is the codebase's own headless-harness precedent:
 * opt out of the post-init tick suspend, start the round without waiting for players, and
 * hang the work off the roundstart callback so it runs at RUNLEVEL_GAME (SSlighting,
 * SSweather and SSplanet_mobs do not fire in the lobby, and a planet build that waits on a
 * lighting queue nothing is draining just burns its whole timeout).
 */
/proc/churn_soak_arm_unattended()
	// A clientless world SUSPENDS its tick after init; every sleep and timer in the soak
	// would freeze at the first yield.
	Master.sleep_offline_after_initializations = FALSE
	// A playerless round declares itself over and reboots the world a few seconds later.
	SSticker.delay_end = TRUE
	SSticker.start_immediately = TRUE
	CONFIG_SET(number/round_end_countdown, 0)
	SSticker.OnRoundstart(CALLBACK(SSchurn_soak, TYPE_PROC_REF(/datum/controller/subsystem/churn_soak, arm)))

// ---------------------------------------------------------------------------------------
// Environment overrides
// ---------------------------------------------------------------------------------------

/datum/controller/subsystem/overmap
	// The soak deals every map zone itself, so the pool has to start empty: with the
	// roundstart contacts on, five prebuilt planets hold SOLO slots for the whole run and
	// "all slots free at the end" stops being a question anyone can answer. The soak spawns
	// its own markers through spawn_dynamic_planet(), which is the same proc setup_planets()
	// uses, so the production placement path is still the one under test.
	spawn_planets = FALSE

/datum/controller/subsystem/npc_ships
	// The soak spawns and kills its own hull every cycle through spawn_pirate(), which is
	// the production path. Leaving the roundstart pool at 4 would put the reconcile in a
	// fight with the soak: every hull the soak kills reads as a pool vacancy and gets a
	// replacement spawned behind our back, so the ship counters would measure the
	// reconcile's mood rather than the lifecycle.
	//
	// Zero is load-bearing in three places, all verified against spawner_subsystem.dm:
	// initialize_pirates() spawns nothing; on_pirate_resolved() bails at its
	// `count_pool_ships() >= pirate_count_target` check (0 >= 0); and reconcile_pool()'s
	// deficit map comes out empty or negative, and `deficit <= 0` skips every band. The
	// reconcile still SWEEPS - dead refs dropped, crew wipes resolved, stalled claims
	// expired - so the production bookkeeping the soak's hull passes through is intact.
	// It simply never tops up.
	pirate_count_target = 0

// ---------------------------------------------------------------------------------------
// The soak itself
// ---------------------------------------------------------------------------------------

SUBSYSTEM_DEF(churn_soak)
	name = "Churn Soak"
	flags = SS_NO_FIRE

	/// Resolved path of this run's transcript.
	var/log_path = CHURN_SOAK_DEFAULT_LOG
	/// Cycles to run. `churn-soak-cycles` in world.params overrides the compile-time default.
	var/cycles = CHURN_SOAK_CYCLES
	/// Sample taken before cycle 1 - what "back to where we started" means.
	var/list/baseline
	/// Post-teardown sample per cycle, indexed by cycle number.
	var/list/cycle_samples = list()
	/// world.maxz observed at the end of each cycle, indexed by cycle number.
	var/list/cycle_maxz = list()
	/// Criteria that failed. Non-zero means the verdict is FAIL.
	var/failures = 0
	/// Cycles that needed a forced teardown or lost a tenant. Reported, not fatal on its own.
	var/degraded_cycles = 0
	/// Latched so the watchdog and the driver cannot both write a verdict.
	var/verdict_written = FALSE
	/// world.time of the driver's last visible step, for the stall watchdog.
	var/progress_stamp = 0
	/// What the driver was doing at that stamp.
	var/progress_label = "not started"
	/// world.realtime the cycle loop began.
	var/started_realtime = 0
	/// TRUE once launch() has been entered, so a duplicate roundstart callback is ignored.
	var/launched = FALSE
	/// TRUE when the cycle loop stopped on its wall-clock budget rather than finishing.
	var/stopped_early = FALSE
	/// One entry per planet measured by measure_surface_lighting(), each an assoc list of
	/// "cycle", "label", "ambient", "with_object", "share". Read by the verdict.
	var/list/surface_lighting_samples = list()

	// ---- overnight mode -------------------------------------------------------------
	/// Real-time budget for the cycle loop, in deciseconds. `churn-soak-budget-min`
	/// in world.params overrides the compile-time default.
	var/wall_budget = CHURN_SOAK_WALL_BUDGET
	/// TRUE when the run is bounded by `wall_budget` rather than by `cycles`.
	var/overnight = FALSE
	/// Take an NDJSON census snapshot on cycles where `cycle % census_every == 0`.
	var/census_every = CHURN_SOAK_CENSUS_EVERY
	/// TRUE when the content zoo (ships, ruins, fields, arenas, weather) is being driven.
	var/zoo_enabled = CHURN_SOAK_ZOO

	// ---- zoo bookkeeping ------------------------------------------------------------
	/// "module" -> assoc list of "built", "torn_down", "forced", "skipped". Reported at the
	/// end so a module that quietly stopped doing anything on cycle 6 is visible rather
	/// than looking like a clean flat run.
	var/list/zoo_tally = list()
	/// Per-cycle lighting residue readings, each list("cycle", "disowned", "detached").
	/// The lighting port leaves a known, CONSTANT residue (6 pinned sources + 61 detached
	/// corners per planet z). Exempt from the flatness gate, but tracked here so "constant"
	/// stays a measured claim rather than an assumption.
	var/list/lighting_residue_samples = list()

/datum/controller/subsystem/churn_soak/Initialize()
	resolve_log_path()
	// Belt and braces: RunUnattendedFunctions() sets this too, but if a future edit moves
	// the arming, a suspended tick is the failure that produces no output at all.
	Master.sleep_offline_after_initializations = FALSE
	soak_log("=== CHURN SOAK: boot ===")
	soak_log("mode=[overnight ? "OVERNIGHT" : "fixed-cycle"] cycles=[overnight ? "unlimited" : "[cycles]"] flats_per_cycle=[CHURN_SOAK_FLATS_PER_CYCLE] wall_budget=[wall_budget / 600]min census_every=[census_every] zoo=[zoo_enabled ? "on" : "off"]")
	soak_log("byond=[world.byond_version].[world.byond_build] maxz_at_boot=[world.maxz]")
	// Safety net for the arming: if the round never starts, the roundstart callback never
	// fires and the run would produce no verdict at all. arm() is idempotent.
	INVOKE_ASYNC(src, PROC_REF(arm_fallback))
	return SS_INIT_SUCCESS

/// Reads the launcher's chosen log path out of world.params, falling back to a fixed name,
/// and drops a pointer file so a launcher that chose nothing can still find the transcript.
/datum/controller/subsystem/churn_soak/proc/resolve_log_path()
	var/list/launch_params = world.params
	var/wanted = launch_params ? launch_params["churn-soak-log"] : null
	if(istext(wanted) && length(wanted))
		log_path = wanted
	var/wanted_cycles = launch_params ? launch_params["churn-soak-cycles"] : null
	if(istext(wanted_cycles) && text2num(wanted_cycles) >= 1)
		cycles = round(text2num(wanted_cycles))

	// Overnight mode. The compile-time -DCHURN_SOAK_OVERNIGHT sets the default; the param
	// lets one .dmb serve both the smoke run and the real thing.
#ifdef CHURN_SOAK_OVERNIGHT
	overnight = TRUE
#endif
	var/wanted_overnight = launch_params ? launch_params["churn-soak-overnight"] : null
	if(istext(wanted_overnight) && length(wanted_overnight))
		overnight = (text2num(wanted_overnight) ? TRUE : FALSE)

	var/wanted_budget = launch_params ? launch_params["churn-soak-budget-min"] : null
	if(istext(wanted_budget) && text2num(wanted_budget) >= 1)
		wall_budget = round(text2num(wanted_budget)) MINUTES

	var/wanted_census = launch_params ? launch_params["churn-soak-census-every"] : null
	if(istext(wanted_census) && text2num(wanted_census) >= 1)
		census_every = round(text2num(wanted_census))

	var/wanted_zoo = launch_params ? launch_params["churn-soak-zoo"] : null
	if(istext(wanted_zoo) && length(wanted_zoo))
		zoo_enabled = (text2num(wanted_zoo) ? TRUE : FALSE)

	// Overnight runs are bounded by the clock, not by a count. A number is still needed
	// for the loop bound and for the "of N requested" line; make it unreachable.
	if(overnight)
		cycles = 100000

	rustg_file_write("[log_path]\n", CHURN_SOAK_POINTER)

/// One transcript line. rustg_file_append rather than world.log: the shell script polls this
/// file, and world.log is fought over by SetupLogs(). Mirrored to log_world() so the
/// redirected dd log carries the same story next to any runtime that interleaves with it.
/datum/controller/subsystem/churn_soak/proc/soak_log(text)
	rustg_file_append("\[[time_stamp()]\] [text]\n", log_path)
	log_world("CHURN SOAK: [text]")

/// PASS/FAIL line for one verdict criterion.
/datum/controller/subsystem/churn_soak/proc/verdict_line(ok, label, detail)
	if(!ok)
		failures++
	soak_log("[ok ? "PASS" : "FAIL"] [label][detail ? " - [detail]" : ""]")

/// Marks forward progress; the watchdog reads this to tell "slow" from "dead".
/datum/controller/subsystem/churn_soak/proc/mark_progress(label)
	progress_stamp = world.time
	progress_label = label

/// "elapsed 142 min of 480" - on an overnight run every cycle boundary should say how much
/// night is left, so a morning read of the log can tell "finished" from "got killed".
/datum/controller/subsystem/churn_soak/proc/elapsed_label()
	if(!started_realtime)
		return "not started"
	var/elapsed = world.realtime - started_realtime
	return "elapsed [round(elapsed / 600)] min of [round(wall_budget / 600)]"

/// One line of zoo bookkeeping. `outcome` is one of "built", "torn_down", "forced",
/// "skipped" - see the zoo_tally doc.
/datum/controller/subsystem/churn_soak/proc/tally_zoo(module, outcome)
	var/list/counts = zoo_tally[module]
	if(!counts)
		counts = list("built" = 0, "torn_down" = 0, "forced" = 0, "skipped" = 0)
		zoo_tally[module] = counts
	counts[outcome] += 1

// ---------------------------------------------------------------------------------------
// Launch
// ---------------------------------------------------------------------------------------

/// Roundstart callback target. Kept trivial so nothing long-running happens inside the
/// ticker's own call stack.
/datum/controller/subsystem/churn_soak/proc/arm()
	if(launched)
		return
	launched = TRUE
	INVOKE_ASYNC(src, PROC_REF(launch))
	INVOKE_ASYNC(src, PROC_REF(watchdog))

/// Arms the soak even if SSticker never delivers its roundstart callback, so a world that
/// fails to start the round still writes a FAIL verdict instead of sitting there.
/datum/controller/subsystem/churn_soak/proc/arm_fallback()
	var/deadline = world.time + CHURN_SOAK_BOOT_TIMEOUT
	while(world.time < deadline)
		if(launched)
			return
		if(SSticker.current_state >= GAME_STATE_PLAYING)
			break
		sleep(10 SECONDS)
	if(!launched)
		soak_log("roundstart callback never arrived - arming the soak from the fallback path (ticker state [SSticker.current_state])")
	arm()

/datum/controller/subsystem/churn_soak/proc/launch()
	mark_progress("launch")
	soak_log("=== CHURN SOAK: launch (ticker state [SSticker.current_state], maxz [world.maxz]) ===")

	// Hold the round open for the whole run, not just at boot: anything that clears
	// delay_end mid-run reboots the world out from under us.
	SSticker.delay_end = TRUE

	if(!wait_for_ready())
		write_verdict("world never reached a runnable state")
		return

	// Let the roundstart load settle - the fleet spawn, SSatoms' queue and SSlighting's
	// first sweep all land in the seconds after roundstart, and sampling on top of them
	// would put their cost in cycle 1's baseline.
	sleep(30 SECONDS)

	baseline = take_sample()
	log_sample("baseline", 0, baseline)

	started_realtime = world.realtime
	run_cycles()
	write_verdict()

/// Waits for a state the soak can actually drive in. Bounded: a world that never gets there
/// must produce a FAIL, not a hang.
/datum/controller/subsystem/churn_soak/proc/wait_for_ready()
	var/deadline = world.time + CHURN_SOAK_BOOT_TIMEOUT
	while(world.time < deadline)
		if(SSticker.current_state >= GAME_STATE_PLAYING && SSovermap.initialized)
			soak_log("world ready: ticker state [SSticker.current_state], overmap initialized, maxz [world.maxz]")
			return TRUE
		sleep(5 SECONDS)
	soak_log("FAIL TIMEOUT waiting for the round to start (ticker state [SSticker.current_state], overmap initialized [SSovermap.initialized ? "yes" : "no"])")
	failures++
	return FALSE

/// Independent stall detector. A DM runtime unwinds the driver without running anything on
/// the way out, so the only symptom is that the progress stamp stops moving. Writes the
/// verdict itself so the shell script gets an answer instead of a timeout.
/datum/controller/subsystem/churn_soak/proc/watchdog()
	while(!verdict_written)
		sleep(30 SECONDS)
		if(verdict_written)
			return
		if(!progress_stamp)
			continue
		if(world.time - progress_stamp <= CHURN_SOAK_WATCHDOG_STALL)
			continue
		soak_log("FAIL EXCEPTION - the driver has not made progress for [(world.time - progress_stamp) / 600] minutes; last step was '[progress_label]'")
		soak_log("FAIL EXCEPTION context: maxz=[world.maxz] worldgen_owner=[SSovermap.worldgen_owner ? "[SSovermap.worldgen_owner.type] ('[SSovermap.worldgen_label]')" : "idle"] queue=[SSovermap.worldgen_queue_length()] total_runtimes=[GLOB.total_runtimes]")
		failures++
		write_verdict("driver stalled at '[progress_label]' (probable runtime - see [CHURN_SOAK_DD_LOG])")
		return

// ---------------------------------------------------------------------------------------
// The cycle loop
// ---------------------------------------------------------------------------------------

/datum/controller/subsystem/churn_soak/proc/run_cycles()
	for(var/cycle in 1 to cycles)
		// A crewless roundstart hull abandons at 30 minutes and despawns at an hour, taking
		// its own allocations with it. That has nothing to do with packing and everything to
		// do with confusing the deltas, so the sweep is pushed out of reach each cycle.
		SSovermap.next_derelict_sweep = world.time + 10 HOURS

		soak_log("--- cycle [cycle][overnight ? "" : "/[cycles]"] begin ([elapsed_label()]) ---")
		mark_progress("cycle [cycle] build")

		var/list/flats = build_flat_encounters(cycle)
		var/list/planets = build_planets(cycle)

		// The zoo stands up on top of the map zones, not instead of them: a live round has
		// planets AND hulls AND reservations resident at the same time, and the interesting
		// failures are the ones that only appear when they share a tick.
		var/list/zoo = zoo_enabled ? build_zoo(cycle, planets) : list()

		mark_progress("cycle [cycle] loaded")
		// Shallow: the datum walk cannot yield, and the verdict only ever reads post-teardown
		// samples. Datum-side counters read -1 here, meaning "not sampled".
		var/list/loaded_sample = take_sample(deep = FALSE)
		log_sample("loaded", cycle, loaded_sample)
		// Also AT LOAD, not only post-teardown: the orphaned-light-source hunt needs to know
		// whether a cycle's orphans are minted while the content is being built or while it is
		// being torn down, and one reading per cycle cannot tell those apart.
		log_disowned_source_shape("[cycle]-loaded")

		mark_progress("cycle [cycle] teardown")
		if(zoo_enabled)
			teardown_zoo(cycle, zoo)
		teardown_planets(cycle, planets)
		teardown_flats(cycle, flats)

		mark_progress("cycle [cycle] torn down")
		// The teardown sweeps qdel a great deal; give SSgarbage a chance to actually process
		// its queue before counting instances, or every sample reads the backlog rather than
		// the leak. Two GC_FILTER_QUEUE passes' worth of headroom.
		sleep(20 SECONDS)

		var/list/post = take_sample()
		cycle_samples["[cycle]"] = post
		cycle_maxz["[cycle]"] = world.maxz
		log_sample("post-teardown", cycle, post)
		log_forensics(cycle)
		record_lighting_residue(cycle)

		// On-demand census pass: the NDJSON snapshot is what census_diff.py ranks growth
		// from, and one per N cycles turns the soak into a per-type leak table for free.
		// Not every cycle on an overnight run - it is the most expensive thing here.
		if(!(cycle % census_every))
			mark_progress("cycle [cycle] census")
			take_census_now()

		soak_log("--- cycle [cycle][overnight ? "" : "/[cycles]"] end (maxz [world.maxz], [elapsed_label()]) ---")

		if(cycle >= cycles)
			break
		var/elapsed = world.realtime - started_realtime
		var/per_cycle = elapsed / cycle
		if(elapsed + per_cycle > wall_budget)
			soak_log("wall budget reached after [cycle] cycle\s ([elapsed / 600] min elapsed, ~[per_cycle / 600] min per cycle) - stopping [overnight ? "" : "early "]and writing the verdict")
			stopped_early = !overnight
			break

// ---------------------------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------------------------

/**
 * Four flat encounters, one per lattice slot, through the production path.
 *
 * `dock_in_empty_space()` does exactly this: find or make an /obj/structure/overmap/planet/empty
 * on the ship's overmap tile, then load_level(). load_level() routes a flat encounter into
 * spawn_dynamic_encounter() with tenant_class left null, so the encounter classifies itself
 * (`flat` - no baseturf, no weather trait, no mapgen, no ruin list) and all four land on one z.
 */
/datum/controller/subsystem/churn_soak/proc/build_flat_encounters(cycle)
	var/list/built = list()
	for(var/index in 1 to CHURN_SOAK_FLATS_PER_CYCLE)
		// Per-site, not per-phase: four sites each allowed six minutes is twenty-four
		// minutes of silence, and the stall watchdog fires at twelve.
		mark_progress("cycle [cycle] flat [index]")
		var/turf/spot = SSovermap.get_unused_overmap_square()
		if(!spot)
			soak_log("FAIL cycle [cycle]: no free overmap square for flat encounter [index]")
			failures++
			degraded_cycles++
			continue
		var/obj/structure/overmap/planet/empty/site = new(spot)
		var/refusal = site.load_level()
		if(!wait_for_load(site, "flat encounter [index]", cycle))
			degraded_cycles++
		if(!site.mapzone || !site.footprint)
			soak_log("FAIL cycle [cycle]: flat encounter [index] finished loading with no [site.mapzone ? "footprint" : "map zone"][refusal ? " (load_level said: [refusal])" : ""]")
			failures++
			degraded_cycles++
		else
			soak_log("cycle [cycle]: flat encounter [index] on [site.footprint.describe()]")
		built += site
	return built

/**
 * Two lava planets and two ice planets, through the production path.
 *
 * `spawn_dynamic_planet()` is the same proc `setup_planets()` uses to put an unloaded contact
 * on the chart; `load_level()` is what a docking ship or a survey shuttle calls, and it is the
 * proc that queues the build and calls build_planet(). Both real.
 *
 * Two biomes deliberately: terrain planets now share ONE packed slot class
 * (MAP_TENANT_CLASS_PLANET), so all four land on one z-level and a cycle exercises
 * MIXED-biome co-tenancy - per-footprint ground, per-site weather, per-instance areas - plus
 * the first-tenant/last-tenant-out teardown split.
 *
 * spawn_dynamic_planet() returns nothing, so the new marker is recovered by diffing
 * GLOB.overmap_planets, which Initialize() appends to.
 */
/datum/controller/subsystem/churn_soak/proc/build_planets(cycle)
	var/list/built = list()
	var/static/list/soak_biomes = list(
		/obj/structure/overmap/planet/lava,
		/obj/structure/overmap/planet/lava,
		/obj/structure/overmap/planet/ice,
		/obj/structure/overmap/planet/ice,
	)
	for(var/index in 1 to length(soak_biomes))
		mark_progress("cycle [cycle] planet [index]")
		var/marker_type = soak_biomes[index]
		var/list/before = GLOB.overmap_planets.Copy()
		// pass 2: pass 1 marks a contact for the lobby prebuild pass, which has already run
		// and must not be handed anything to do behind our back.
		SSovermap.spawn_dynamic_planet(marker_type, 2)
		var/obj/structure/overmap/planet/marker = null
		for(var/obj/structure/overmap/planet/candidate in GLOB.overmap_planets)
			if(candidate in before)
				continue
			marker = candidate
			break
		if(!marker)
			soak_log("FAIL cycle [cycle]: spawn_dynamic_planet([marker_type]) placed no contact (overmap full?)")
			failures++
			degraded_cycles++
			continue
		var/refusal = marker.load_level()
		if(!wait_for_load(marker, "planet [index] ([marker.name])", cycle))
			degraded_cycles++
		if(!marker.mapzone || !marker.footprint)
			soak_log("FAIL cycle [cycle]: planet [index] ([marker.name]) finished loading with no [marker.mapzone ? "footprint" : "map zone"][refusal ? " (load_level said: [refusal])" : ""]")
			failures++
			degraded_cycles++
		else
			soak_log("cycle [cycle]: planet [index] '[marker.name]' on [marker.footprint.describe()]")
		built += marker
	measure_surface_lighting(cycle, built)
	return built

/**
 * Counts the lighting objects standing on freshly built planet GROUND.
 *
 * Planet surfaces are ambient-lit: the area paints one BLEND_ADD overlay and its turfs carry
 * no /datum/lighting_object at all (voidcrew/edits/lighting.dm, /turf/proc/skips_lighting_object).
 * Before that landed, every one of a planet's ~14,000 surface tiles held an object plus the
 * corners it pulled into existence, which was the single largest block of memory a planet
 * owned. The gate has to hold at all four build sites or the win leaks away at whichever one
 * was missed - and a missed site is invisible to the flatness criterion, because a build that
 * allocates thousands and a teardown that frees them again is perfectly flat cycle to cycle.
 * This is the assertion that catches it, and it is measured at LOAD, not post-teardown.
 *
 * Scoped to turfs whose area is actually ambient-lit, so cave interiors, ruin interiors and a
 * landed hull are excluded by construction rather than by a fudge factor. The survivors that
 * are counted are the deliberate self-lit exceptions: a lava river, the fallout zone's hazard
 * green, and any /lit tile a ruin .dmm dropped straight onto surface ground. Those are a small
 * minority of a footprint even on the biomes that have them - hence 5%.
 */
/datum/controller/subsystem/churn_soak/proc/measure_surface_lighting(cycle, list/planets)
	for(var/obj/structure/overmap/planet/site as anything in planets)
		if(QDELETED(site) || !site.footprint)
			continue
		var/list/block_turfs = site.footprint.get_block()
		if(!length(block_turfs))
			continue
		var/ambient_turfs = 0
		var/with_object = 0
		// Why each survivor kept its object, so a threshold breach can be read without
		// re-running anything. A GATE MISS is the only one of these that is a bug: it means a
		// turf with no light of its own got an object anyway, i.e. some build site does not
		// consult skips_lighting_object(). "self-lit" is the deliberate exception (a lava
		// river, the fallout zone's green, basalt's own Initialize set_light, a /lit tile a
		// ruin .dmm dropped straight onto surface ground). "bleed" should be empty by
		// construction - AMBIENT_BLEED_RANGE is the sentinel skips_lighting_object() checks -
		// so anything here means the sentinel is not holding.
		var/gate_miss = 0
		var/self_lit = 0
		var/bleed_lit = 0
		var/list/lit_types = list()
		for(var/turf/checked as anything in block_turfs)
			var/area/checked_area = checked.loc
			if(!checked_area || !checked_area.ambient_lighting || checked_area.static_lighting || !checked_area.base_lighting_alpha)
				continue
			ambient_turfs++
			if(checked.lighting_object)
				with_object++
				if(!checked.light_range)
					gate_miss++
				else if(checked.light_range == AMBIENT_BLEED_RANGE)
					bleed_lit++
				else
					self_lit++
				lit_types["[checked.type]"] += 1
			CHECK_TICK
		if(with_object)
			soak_log("SURFACE LIGHTING cycle=[cycle] '[site.name]' survivors: gate_miss=[gate_miss] self_lit=[self_lit] bleed=[bleed_lit] :: [forensics_top(lit_types, 8)]")
		if(!ambient_turfs)
			soak_log("SURFACE LIGHTING cycle=[cycle] '[site.name]': no ambient-lit ground in the footprint - the surface area is not configured for ambient lighting")
			surface_lighting_samples += list(list(
				"cycle" = cycle,
				"label" = "[site.name] (no ambient ground)",
				"ambient" = 0,
				"with_object" = -1,
				"share" = 1,
				"gate_miss" = 0,
				"bleed_lit" = 0,
			))
			continue
		var/share = with_object / ambient_turfs
		soak_log("SURFACE LIGHTING cycle=[cycle] '[site.name]': [with_object]/[ambient_turfs] ambient-lit ground turfs still carry a lighting object ([round(share * 1000) / 10]%)")
		surface_lighting_samples += list(list(
			"cycle" = cycle,
			"label" = "[site.name]",
			"ambient" = ambient_turfs,
			"with_object" = with_object,
			"share" = share,
			"gate_miss" = gate_miss,
			"bleed_lit" = bleed_lit,
		))

/// Bounded wait on one site's `loading` flag plus the worldgen queue. load_level() is a
/// blocking call in both branches, so this normally returns on its first look; it exists for
/// the paths that hand the build off (queue timeout re-arms, watchdog force-releases).
/datum/controller/subsystem/churn_soak/proc/wait_for_load(obj/structure/overmap/planet/site, label, cycle)
	var/deadline = world.time + CHURN_SOAK_LOAD_TIMEOUT
	while(world.time < deadline)
		if(QDELETED(site))
			soak_log("FAIL cycle [cycle]: [label] was deleted while loading")
			failures++
			return FALSE
		if(!site.loading && SSovermap.worldgen_owner != site)
			return TRUE
		sleep(2 SECONDS)
	soak_log("FAIL TIMEOUT cycle [cycle]: [label] still loading after [CHURN_SOAK_LOAD_TIMEOUT / 600] minutes (worldgen queue: [SSovermap.worldgen_owner ? "'[SSovermap.worldgen_label]'" : "idle"], [SSovermap.worldgen_queue_length()] waiting)")
	failures++
	return FALSE

// ---------------------------------------------------------------------------------------
// Teardown
// ---------------------------------------------------------------------------------------

/**
 * Planets down through unload_level(), which is the proc the despawn countdown calls.
 *
 * It gates on can_release_interior() - no berth claimed, no ship inside, nobody with a mind
 * on our footprint - then queues, removes the docks, calls remove_mapzone() (per-slot ground
 * reset, then release_slot) and relocates the contact. The marker is qdel'd afterwards so
 * GLOB.overmap_planets does not grow by four a cycle; by then it holds neither a zone nor a
 * footprint, so Destroy()'s out-of-band release path is a no-op.
 */
/datum/controller/subsystem/churn_soak/proc/teardown_planets(cycle, list/planets)
	for(var/obj/structure/overmap/planet/marker in planets)
		if(QDELETED(marker))
			continue
		var/label = "planet '[marker.name]'"
		mark_progress("cycle [cycle] teardown [label]")
		marker.unload_level()
		if(!wait_for_teardown(marker, label, cycle))
			force_teardown(marker, label, cycle)
		qdel(marker)

/**
 * Flat encounters down through their own unload_level() override, which is what the
 * post-undock retry loop calls. It removes the docks, calls remove_mapzone()
 * (clear_to_uninitialized_space + release_slot) and then qdels itself - so unlike a planet
 * there is nothing left to delete afterwards.
 */
/datum/controller/subsystem/churn_soak/proc/teardown_flats(cycle, list/flats)
	for(var/obj/structure/overmap/planet/empty/site in flats)
		if(QDELETED(site))
			continue
		var/label = "flat encounter '[site.name]'"
		mark_progress("cycle [cycle] teardown [label]")
		site.unload_level()
		if(!wait_for_teardown(site, label, cycle))
			force_teardown(site, label, cycle)
			qdel(site)

/// Bounded wait for a site to have handed its slot back.
/datum/controller/subsystem/churn_soak/proc/wait_for_teardown(obj/structure/overmap/planet/site, label, cycle)
	var/deadline = world.time + CHURN_SOAK_TEARDOWN_TIMEOUT
	while(world.time < deadline)
		if(QDELETED(site))
			return TRUE
		if(!site.mapzone && !site.footprint && !site.unloading)
			return TRUE
		sleep(2 SECONDS)
	soak_log("FAIL TIMEOUT cycle [cycle]: [label] still holds [site.footprint ? site.footprint.describe() : "a map zone"] after [CHURN_SOAK_TEARDOWN_TIMEOUT / 600] minutes")
	failures++
	return FALSE

/**
 * Last resort when unload_level() refused or stalled: run the same teardown procs it would
 * have run, with the occupancy gate skipped. It is still remove_docks() + remove_mapzone(),
 * so the ground is swept and the slot handed back exactly as in production - the only thing
 * bypassed is the "is anybody home" question, which in a headless soak should always have
 * been "no". A run that needs this is reported as degraded, and whatever was standing in the
 * way is named in the log, because that refusal is itself a finding.
 */
/datum/controller/subsystem/churn_soak/proc/force_teardown(obj/structure/overmap/planet/site, label, cycle)
	if(QDELETED(site) || (!site.mapzone && !site.footprint))
		return
	degraded_cycles++
	var/blockers = ""
	if(site.mapzone)
		var/list/minds = site.mapzone.get_mind_mobs_in(site.footprint)
		blockers = "minds_on_site=[length(minds)] first_dock_taken=[site.first_dock_taken ? "yes" : "no"] second_dock_taken=[site.second_dock_taken ? "yes" : "no"] loading=[site.loading ? "yes" : "no"] unloading=[site.unloading ? "yes" : "no"] preserve=[site.preserve_level ? "yes" : "no"]"
	soak_log("WARN cycle [cycle]: [label] would not release through unload_level() - forcing the same teardown procs ([blockers])")
	site.unloading = TRUE
	site.concerned = TRUE
	site.remove_docks()
	site.remove_mapzone(throttled = FALSE)
	site.unloading = FALSE
	site.concerned = FALSE

// ---------------------------------------------------------------------------------------
// The content zoo
//
// Five modules, all driven through the same production entry points a live round uses.
// Each one is independently deadline-bounded, each one reports its own outcome into
// zoo_tally, and each one has a force path so a single stuck tenant degrades one cycle
// instead of eating the night.
//
// Nothing in here waits out a real-time gameplay clock. The derelict abandonment clock is
// 30 minutes and the despawn clock is an hour; the soak calls abandon_ship() and
// despawn_derelict() directly instead, which is what those clocks would eventually have
// called anyway.
// ---------------------------------------------------------------------------------------

/**
 * Stands up one of everything alongside the cycle's flats and planets.
 *
 * Deliberately built AFTER the map zones and torn down BEFORE them: a live round has
 * planets and hulls and turf reservations resident in the same tick, and the failures
 * worth catching are the ones that only show up when they share a z-level pool, a
 * worldgen queue and a garbage queue.
 *
 * Returns a bag the teardown reads back. Entries can come back null (a module that
 * skipped, or an atom that got hard-deleted out of the list - see the harddel note in
 * teardown_zoo), so every read is guarded.
 */
/datum/controller/subsystem/churn_soak/proc/build_zoo(cycle, list/planets)
	var/list/zoo = list()

	mark_progress("cycle [cycle] zoo: ship")
	build_npc_hull(cycle, zoo)

	mark_progress("cycle [cycle] zoo: space ruin")
	zoo["ruin"] = build_space_ruin(cycle)

	mark_progress("cycle [cycle] zoo: asteroid field")
	zoo["field"] = build_asteroid_field(cycle)

	mark_progress("cycle [cycle] zoo: vestige arena")
	zoo["arena"] = build_vestige_arena(cycle)

	mark_progress("cycle [cycle] zoo: weather")
	start_planet_storm(cycle, planets, zoo)

	return zoo

/// Everything build_zoo() stood up, in reverse. Weather first because a running storm
/// holds area instances the other teardowns are about to delete.
/datum/controller/subsystem/churn_soak/proc/teardown_zoo(cycle, list/zoo)
	mark_progress("cycle [cycle] zoo teardown: weather")
	stop_planet_storm(cycle, zoo)

	mark_progress("cycle [cycle] zoo teardown: vestige arena")
	teardown_vestige_arena(cycle, zoo["arena"])

	mark_progress("cycle [cycle] zoo teardown: asteroid field")
	teardown_asteroid_field(cycle, zoo["field"])

	mark_progress("cycle [cycle] zoo teardown: space ruin")
	teardown_space_ruin(cycle, zoo["ruin"])

	// Last: the hull's teardown can create and destroy a whole flat encounter of its own
	// (the crash site), and that wants the worldgen queue to itself.
	mark_progress("cycle [cycle] zoo teardown: ship")
	teardown_npc_hull(cycle, zoo)

// ---- SHIPS ----------------------------------------------------------------------------

/**
 * One NPC pirate hull, loaded from its shuttle template through the production spawner.
 *
 * This is the module that matters most. Everything above it churns map zones; a hull churns
 * a shuttle TEMPLATE LOAD, a TRANSIT RESERVATION, a mobile docking port, the ship's atmos
 * pipenets, its area set, its machinery and a crew roster of live mobs - an allocation
 * surface the map-zone soak never touches, and the one round 9 was leaking on.
 *
 * The two death paths alternate by cycle parity, because they free entirely different
 * things and only one of them is reachable from the other:
 *
 *   odd cycles, "crash"    - enter_integrity_failure() -> on_ship_destroyed() -> crash_land().
 *                            With no planet on the hull's overmap tile that lands in
 *                            make_crash_site(), which mints a whole /planet/empty/crashed_ship
 *                            encounter (its own map zone, its own docks) and force-docks the
 *                            hull into it. Torn down below by despawning the derelict, which
 *                            hands the berth back and lets the crash site delete itself -
 *                            the production sequence exactly.
 *   even cycles, "derelict"- the hull never crashes. abandon_ship(FALSE) then
 *                            despawn_derelict() straight from flight, which is what
 *                            SSovermap.sweep_derelicts() does an hour into a round.
 *
 * spawn_pirate() sleeps through the template load, so this may only be called from the
 * driver's own async stack (it is).
 */
/datum/controller/subsystem/churn_soak/proc/build_npc_hull(cycle, list/zoo)
	var/variant = (cycle % 2) ? "crash" : "derelict"
	zoo["hull_variant"] = variant

	var/faction = pick(SSnpc_ships.all_factions)
	// Same call the roundstart pool and every replacement spawn make. pirate_count_target
	// is pinned to 0 (see the subsystem override above), so this hull holds a pool slot
	// nothing is competing for and its death spawns no successor.
	var/obj/structure/overmap/ship/npc/hull = SSnpc_ships.spawn_pirate(faction, ZONE_YELLOW)
	if(QDELETED(hull))
		// Not a FAIL: get_spawn_turf() legitimately returns null when the yellow band has
		// no square that is both empty and 5+ tiles from a player hull. Degraded, reported.
		soak_log("WARN cycle [cycle]: no NPC hull spawned ([faction]) - no free spawn turf, or the template load failed")
		tally_zoo("ship", "skipped")
		degraded_cycles++
		return
	zoo["hull"] = hull
	tally_zoo("ship", "built")
	soak_log("cycle [cycle]: NPC hull '[hull.name]' ([faction]) loaded, death variant '[variant]'")

	if(variant != "crash")
		return

	// The hull kill. enter_integrity_failure() is the proc ship_damage.dm calls when
	// integrity actually reaches zero, so this is the real cascade: latch, stop the ship,
	// spark, crash_land(), COMSIG_SHIP_DESTROYED.
	hull.enter_integrity_failure()

	// make_crash_site() -> load_level() -> finish_crash_land() -> dock(instant). The dock
	// completes through a signal, so poll for it rather than assuming the stack finished.
	var/deadline = world.time + CHURN_SOAK_ZOO_LOAD_TIMEOUT
	while(world.time < deadline)
		if(QDELETED(hull) || hull.docked)
			break
		sleep(2 SECONDS)

	if(QDELETED(hull))
		soak_log("WARN cycle [cycle]: the hull was deleted during its crash landing")
		degraded_cycles++
		return

	var/obj/structure/overmap/landed = hull.docked
	if(!istype(landed, /obj/structure/overmap/planet/empty/crashed_ship))
		soak_log("WARN cycle [cycle]: hull '[hull.name]' did not reach a crash site after [CHURN_SOAK_ZOO_LOAD_TIMEOUT / 600] minutes (docked=[landed ? "[landed.type]" : "nothing"]) - the derelict teardown below still runs")
		degraded_cycles++
		return

	var/obj/structure/overmap/planet/empty/crashed_ship/crash_site = landed
	zoo["crash_site"] = crash_site
	soak_log("cycle [cycle]: hull '[hull.name]' crashed into '[crash_site.name]'[crash_site.footprint ? " on [crash_site.footprint.describe()]" : ""]")

/**
 * Abandons and despawns the hull, then makes sure the crash site went with it.
 *
 * despawn_derelict() is the whole teardown: it hands the berth flags back, sends
 * COMSIG_VOIDCREW_SHIP_UNDOCKED (which is what schedules the crash site's own unload),
 * clears the mobs aboard, and ends in intoTheSunset() -> jumpToNullSpace(), which is
 * where the transit reservation and the mobile port are actually freed. Calling it
 * directly is the point: waiting for SSovermap.sweep_derelicts() to reach the same call
 * would cost 30 minutes of abandonment clock plus an hour of despawn clock per cycle.
 */
/datum/controller/subsystem/churn_soak/proc/teardown_npc_hull(cycle, list/zoo)
	var/obj/structure/overmap/ship/npc/hull = zoo["hull"]
	var/obj/structure/overmap/planet/empty/crashed_ship/crash_site = zoo["crash_site"]

	if(!QDELETED(hull))
		// crash = FALSE: the crash variant has already crashed, and the derelict variant is
		// deliberately being despawned straight out of flight (which is what the sweep does).
		hull.abandon_ship(FALSE)
		if(!hull.despawn_derelict())
			// The only two refusals are "a connected player is aboard" and "a ship is docked
			// to us", neither of which can happen headless. If it ever does, say so and use
			// the force path rather than leaving a hull pinning a transit reservation.
			soak_log("WARN cycle [cycle]: despawn_derelict() refused for '[hull.name]' - forcing destroy_ship()")
			hull.destroy_ship(force = TRUE, ignore_crew = TRUE)
			tally_zoo("ship", "forced")
			degraded_cycles++
		else
			tally_zoo("ship", "torn_down")

	if(QDELETED(crash_site))
		return

	// The crash site deletes ITSELF: on_ship_undocked() arms a 3-second timer onto
	// try_unload_level(), which retries on a backoff until it succeeds. Give it room.
	var/deadline = world.time + CHURN_SOAK_ZOO_TEARDOWN_TIMEOUT
	while(world.time < deadline)
		if(QDELETED(crash_site))
			return
		sleep(2 SECONDS)

	soak_log("WARN cycle [cycle]: crash site '[crash_site.name]' still holds [crash_site.footprint ? crash_site.footprint.describe() : "a map zone"] after [CHURN_SOAK_ZOO_TEARDOWN_TIMEOUT / 600] minutes - forcing")
	force_teardown(crash_site, "crash site '[crash_site.name]'", cycle)
	qdel(crash_site)
	tally_zoo("ship", "forced")

// ---- SPACE RUINS -----------------------------------------------------------------------

/**
 * One space ruin encounter: a SLOT on the map-zone lattice (up to four sites to a z-level,
 * separated by cordon), a static .dmm stamped into it, buffer space initialized, two
 * stationary docks placed and home-marked.
 *
 * The template varies per cycle on purpose. Ruins differ enormously in size and content -
 * a 40x40 derelict and a 200x100 station allocate nothing like the same amount - so a
 * fixed template would measure one ruin's lifecycle and call it "ruins".
 */
/datum/controller/subsystem/churn_soak/proc/build_space_ruin(cycle)
	var/turf/spot = SSovermap.get_unused_overmap_square()
	if(!spot)
		soak_log("WARN cycle [cycle]: no free overmap square for a space ruin")
		tally_zoo("ruin", "skipped")
		degraded_cycles++
		return null

	var/datum/map_template/ruin/space/template = pick_soak_ruin_template(cycle)
	if(!template)
		soak_log("WARN cycle [cycle]: SSmapping.space_ruins_templates offered no pickable template")
		tally_zoo("ruin", "skipped")
		return null

	var/obj/structure/overmap/space_ruin/ruin = new(spot)
	ruin.set_ruin_template(template)
	// Blocking, and it takes the worldgen queue like any survey would.
	ruin.load_level()

	if(!ruin.mapzone)
		// load_level() has several honest refusals (template too large to ever fit, a
		// failed .dmm load, a queue timeout, no free slot at the z-level ceiling) and each
		// one cleans up after itself. Report which ruin bounced rather than calling it a
		// failure.
		soak_log("WARN cycle [cycle]: space ruin '[template.name]' did not load - see the mapping log for the reason")
		qdel(ruin)
		tally_zoo("ruin", "skipped")
		degraded_cycles++
		return null

	soak_log("cycle [cycle]: space ruin '[template.name]' ([template.width]x[template.height]) loaded into [ruin.footprint ? ruin.footprint.describe() : "a map zone"]")
	tally_zoo("ruin", "built")
	return ruin

/**
 * The ruin templates that carry a docking port of their own, drawn FIRST and in a fixed
 * order before the pool goes random.
 *
 * A ruin whose .dmm maps an /obj/docking_port/stationary with a roundstart_template
 * stamps a whole derelict shuttle into the slot when that port LateInitialize()s,
 * and those are the only ruins that exercise the two lifecycle bugs the 2026-08-19 run
 * found: the shuttle's mobile port vetoing the ruin's own teardown, and (with more than
 * one such berth) SSshuttle's preview singletons interleaving and stranding hulls. Left
 * to a uniform draw over ~90 templates, a 12-cycle run has a poor chance of seeing either
 * one, and "forced 0" would then prove nothing. The Syndicate Ambush maps four berths and
 * is the multi-berth case; the Cyborg Mothership maps one and is the single-berth case.
 *
 * Keyed by NAME, because that is what /datum/controller/subsystem/mapping populates
 * space_ruins_templates with (voidcrew/mapping/_mapping.dm: `space_ruins_templates[R.name]`).
 */
/datum/controller/subsystem/churn_soak/proc/soak_ruin_probe_order()
	var/static/list/probes = list("Space-Ruin Cyborg Mothership", "Space-Ruin Syndicate Ambush")
	return probes

/// A pickable space ruin template, or null. Mirrors spawn_replacement_ruin()'s filter:
/// `unpickable` is how a template that must never be seeded says so. The first cycles draw
/// the docking-port-bearing probes above; everything after that is a uniform draw.
/datum/controller/subsystem/churn_soak/proc/pick_soak_ruin_template(cycle)
	var/list/probes = soak_ruin_probe_order()
	if(cycle >= 1 && cycle <= length(probes))
		var/datum/map_template/ruin/space/probe = SSmapping.space_ruins_templates[probes[cycle]]
		if(istype(probe))
			return probe
		soak_log("WARN cycle [cycle]: probe ruin template '[probes[cycle]]' not in SSmapping.space_ruins_templates - falling back to a random draw")

	var/list/pool = list()
	for(var/ruin_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/candidate = SSmapping.space_ruins_templates[ruin_id]
		if(!istype(candidate) || candidate.unpickable)
			continue
		pool += candidate
	return length(pool) ? pick(pool) : null

/**
 * Ruin down through release_interior(), which every production teardown path funnels
 * through - undock recycling, mission cleanup, event retirement. It re-checks occupancy on
 * both sides of the worldgen queue, then removes the docks and hands the slot back.
 *
 * The signal object is qdel'd afterwards rather than relocated: check_and_respawn() would
 * seed a REPLACEMENT ruin somewhere else on the chart, and GLOB.space_ruin_signals growing
 * by one a cycle would drown the deltas the same way the planet markers would.
 */
/datum/controller/subsystem/churn_soak/proc/teardown_space_ruin(cycle, obj/structure/overmap/space_ruin/ruin)
	if(QDELETED(ruin))
		return
	if(!ruin.release_interior())
		soak_log("WARN cycle [cycle]: space ruin '[ruin.name]' refused release_interior() (loading=[ruin.loading ? "yes" : "no"] docks=[ruin.first_dock_taken || ruin.second_dock_taken ? "claimed" : "free"]) - freeing the slot directly")
		// The same two procs release_interior() would have run, minus the occupancy gate.
		// remove_mapzone() is the whole sequence: reap_footprint_docking_ports(), then
		// clear_reservation() over the footprint, then release_slot().
		ruin.remove_docks()
		ruin.remove_mapzone()
		tally_zoo("ruin", "forced")
		degraded_cycles++
	else
		tally_zoo("ruin", "torn_down")
	qdel(ruin)

// ---- ASTEROID / METEOR FIELDS -----------------------------------------------------------

/**
 * One landable asteroid field. Same slot-and-berths shape as a space ruin, but the
 * interior is carved by a live /datum/map_generator instead of stamped from a .dmm, then
 * seeded with ore, a loot crate and roaming mob packs - so it exercises the generator and
 * the spawner paths a static template never touches.
 *
 * Severity rotates so all three generators, ore tables and mob budgets get driven.
 */
/datum/controller/subsystem/churn_soak/proc/build_asteroid_field(cycle)
	var/static/list/severities = list(
		/obj/structure/overmap/event/meteor/minor,
		/obj/structure/overmap/event/meteor,
		/obj/structure/overmap/event/meteor/majour,
	)
	var/field_type = severities[((cycle - 1) % length(severities)) + 1]

	var/turf/spot = SSovermap.get_unused_overmap_square()
	if(!spot)
		soak_log("WARN cycle [cycle]: no free overmap square for an asteroid field")
		tally_zoo("field", "skipped")
		degraded_cycles++
		return null

	var/obj/structure/overmap/event/meteor/field = new field_type(spot)
	field.load_level()

	if(!field.mapzone)
		soak_log("WARN cycle [cycle]: asteroid field '[field.name]' did not load")
		qdel(field)
		tally_zoo("field", "skipped")
		degraded_cycles++
		return null

	soak_log("cycle [cycle]: asteroid field '[field.name]' carved into [field.footprint ? field.footprint.describe() : "a map zone"]")
	tally_zoo("field", "built")
	return field

/**
 * Field down through its own unload_level(). Unlike a ruin the event object is never
 * deleted by production - only the lazily-loaded interior is freed - so the soak deletes
 * the marker itself afterwards to keep GLOB.meteor_fields flat.
 *
 * The force path stays: /obj/structure/overmap/event/meteor/Destroy() now releases the slot
 * defensively, but it deliberately does NOT sweep the ground (it can run mid-build and the
 * sweep yields), so a qdel on a field whose unload was refused would hand back a slot still
 * full of the last tenant's rock. Going through remove_mapzone() is what wipes it, and it is
 * also what frees the berths. unload_level() re-arms itself on a 30-second timer when it
 * refuses; once the map zone is gone that retry hits its own terminal `if(!mapzone) return`,
 * so it cannot become a heartbeat.
 */
/datum/controller/subsystem/churn_soak/proc/teardown_asteroid_field(cycle, obj/structure/overmap/event/meteor/field)
	if(QDELETED(field))
		return

	field.unload_level()

	var/deadline = world.time + CHURN_SOAK_ZOO_TEARDOWN_TIMEOUT
	while(world.time < deadline)
		if(QDELETED(field) || !field.mapzone)
			break
		sleep(2 SECONDS)

	// `concerned` means one of unload_level()'s own 30-second retries is inside the
	// worldgen queue RIGHT NOW. Yanking the slot out from under it would leave it
	// releasing a queue slot for ground that no longer exists, so give it a second window
	// to finish rather than forcing on top of it.
	if(!QDELETED(field) && field.mapzone && field.concerned)
		soak_log("cycle [cycle]: asteroid field '[field.name]' has a teardown in the worldgen queue - waiting another [CHURN_SOAK_ZOO_TEARDOWN_TIMEOUT / 600] minutes before forcing")
		deadline = world.time + CHURN_SOAK_ZOO_TEARDOWN_TIMEOUT
		while(world.time < deadline)
			if(QDELETED(field) || !field.mapzone)
				break
			sleep(5 SECONDS)

	if(QDELETED(field))
		tally_zoo("field", "torn_down")
		return

	if(field.mapzone)
		soak_log("WARN cycle [cycle]: asteroid field '[field.name]' still holds its slot after [CHURN_SOAK_ZOO_TEARDOWN_TIMEOUT / 600] minutes (concerned=[field.concerned ? "yes" : "no"] docks=[field.first_dock_taken || field.second_dock_taken ? "claimed" : "free"]) - freeing it directly")
		field.remove_docks()
		field.remove_mapzone()
		field.concerned = FALSE
		tally_zoo("field", "forced")
		degraded_cycles++
	else
		tally_zoo("field", "torn_down")

	qdel(field)

// ---- VESTIGE ASCENSION ARENAS -----------------------------------------------------------

/**
 * One vestige ascension arena: a turf reservation, a static arena .dmm, and the boss mob
 * standing on its landmark.
 *
 * ## What is driven, and what is approximated
 *
 * Production entry is `/mob/living/basic/vestige_patron/proc/offer_ascension()`, which is
 * gated on things a clientless world cannot produce: a mind, a `tgui_alert()` confirmation,
 * a soul record with every one of that patron's trials completed, and
 * `STATION_TIME_PASSED() >= VESTIGE_ASCENSION_UNLOCK_TIME`. Past that gate it does exactly
 * one thing - `new /datum/vestige_ascension_run(offer, user)` then `run.begin(user)`.
 *
 * So the soak drives the run datum directly, running `begin()`'s body in `begin()`'s order,
 * minus the four lines that need a supplicant:
 *
 *   DRIVEN     get_vestige_ascension() (the real GLOB singleton lookup, so no offer datum
 *              is leaked per cycle), `new offer.template_type()`, load_arena() - which is
 *              the reservation request, the template load and the buffer initialization -
 *              pick_landmark() for both landmarks, `new offer.boss_type(boss_spot)`, the
 *              two boss signal registrations, and teardown through the run's own Destroy(),
 *              which is the ONLY place production frees the reservation.
 *   APPROXIMATED  no supplicant. `watch_supplicant()`, the `forceMove` into the arena, the
 *              `VESTIGE_ASCENSION_TIME_LIMIT` deadline timer, and the endings that need a
 *              body (`consume_supplicant()`, `award_capstone()`, `open_the_gate()`,
 *              `send_home()`) are all unexercised. None of them allocate anything the
 *              reservation and the boss do not already dominate - the memory in an arena is
 *              the reserved block and the mob - but they are a genuine blind spot and are
 *              listed as one in the report.
 */
/datum/controller/subsystem/churn_soak/proc/build_vestige_arena(cycle)
	// The three hosts, rotated. Looked up by PATRON type through the production accessor,
	// which builds GLOB.vestige_ascensions_by_patron once and hands back the singleton.
	var/static/list/patron_types = list(
		/mob/living/basic/vestige_patron/magister,
		/mob/living/basic/vestige_patron/abductor,
		/mob/living/basic/vestige_patron/hollow_master,
	)
	var/patron_type = patron_types[((cycle - 1) % length(patron_types)) + 1]
	var/datum/vestige_ascension/offer = get_vestige_ascension(patron_type)
	if(!offer)
		soak_log("WARN cycle [cycle]: no ascension offer is hosted by [patron_type]")
		tally_zoo("arena", "skipped")
		return null

	var/datum/vestige_ascension_run/run = new(offer, null)
	// Instantiating parses the .dmm for its bounds; this is also the size preload.
	var/datum/map_template/vestige_arena/template = new offer.template_type()
	var/opened = run.load_arena(template)
	qdel(template)

	if(!opened)
		soak_log("WARN cycle [cycle]: vestige arena '[offer.name]' failed to open - see the mapping log")
		qdel(run)
		tally_zoo("arena", "skipped")
		degraded_cycles++
		return null

	var/turf/entry = run.pick_landmark(/obj/effect/landmark/vestige_arena/entry)
	var/turf/boss_spot = run.pick_landmark(/obj/effect/landmark/vestige_arena/boss)
	if(!entry || !boss_spot)
		// begin() treats this as fatal and returns FALSE - but it returns without freeing
		// the reservation, so the qdel below is doing what the caller would have to.
		soak_log("WARN cycle [cycle]: vestige arena '[offer.name]' is missing an [entry ? "boss" : "entry"] landmark")
		qdel(run)
		tally_zoo("arena", "skipped")
		degraded_cycles++
		return null

	run.boss = new offer.boss_type(boss_spot)
	run.RegisterSignal(run.boss, COMSIG_LIVING_DEATH, TYPE_PROC_REF(/datum/vestige_ascension_run, on_boss_death))
	run.RegisterSignal(run.boss, COMSIG_QDELETING, TYPE_PROC_REF(/datum/vestige_ascension_run, on_boss_deleted))

	soak_log("cycle [cycle]: vestige arena '[offer.name]' opened ([run.reservation.width]x[run.reservation.height] reservation, boss [offer.boss_type])")
	tally_zoo("arena", "built")
	return run

/**
 * Arena down through `qdel(run)`.
 *
 * That is not a shortcut: `/datum/vestige_ascension_run/Destroy()` IS the teardown -
 * it kills the deadline timer, qdels the boss and `QDEL_NULL`s the reservation - and
 * `finish()` reaches it with `qdel(src)` as its last line. With no supplicant to send
 * home, `finish()` and a bare qdel do the same work, so the qdel is called directly
 * rather than through a `finish()` that would only log a line first.
 */
/datum/controller/subsystem/churn_soak/proc/teardown_vestige_arena(cycle, datum/vestige_ascension_run/run)
	if(QDELETED(run))
		return
	qdel(run)
	tally_zoo("arena", "torn_down")

// ---- WEATHER ----------------------------------------------------------------------------

/**
 * Fires a real storm on one freshly built planet's own /datum/weather_site.
 *
 * Weather is per-SITE in this fork, not per-z: a packed planet registers its own
 * weather_site with its own weight table, its own cooldown and its own owned area
 * instances, and `SSweather.run_weather(type, z, null, site)` is the exact call the
 * scheduler makes at weather.dm:130. So this is the scheduler's own line, fired on demand
 * instead of waiting five to ten minutes for the site's cooldown to come round.
 *
 * A storm churns the storm datum, its `impacted_areas` / `impacted_areas_lookup` /
 * `impacted_areas_weighted` maps, and the per-area overlay cache - all of which are
 * allocated against area instances that the planet teardown is about to delete, which is
 * precisely why it is worth having a storm resident when the teardown runs.
 *
 * SSweather may have beaten us to it on its own schedule; if so that storm is adopted
 * rather than a second one forced onto the same site.
 */
/datum/controller/subsystem/churn_soak/proc/start_planet_storm(cycle, list/planets, list/zoo)
	for(var/obj/structure/overmap/planet/site as anything in planets)
		if(QDELETED(site))
			continue
		var/datum/weather_site/weather = site.weather_site
		if(QDELETED(weather) || !length(weather.weather_types))
			continue

		if(weather.has_active_weather())
			zoo["storm"] = weather.active_weather
			zoo["storm_site"] = weather
			soak_log("cycle [cycle]: adopted SSweather's own storm on '[site.name]' (site '[weather.id]')")
			tally_zoo("weather", "built")
			return

		var/datum/weather/storm_type = pick_weight(weather.weather_types)
		if(!storm_type)
			continue
		var/datum/weather/storm = SSweather.run_weather(storm_type, list(weather.z_value), null, weather)
		if(!storm)
			continue
		// The scheduler sets this on the line after run_weather(); without it the site does
		// not know it is storming and would roll a second storm on its next fire.
		weather.active_weather = storm
		zoo["storm"] = storm
		zoo["storm_site"] = weather
		soak_log("cycle [cycle]: storm '[storm.name]' ([storm_type]) telegraphing on '[site.name]' (site '[weather.id]', z[weather.z_value])")
		tally_zoo("weather", "built")
		return

	soak_log("WARN cycle [cycle]: no built planet offered a weather site with a weight table")
	tally_zoo("weather", "skipped")

/**
 * Ends the cycle's storm before anything else is torn down.
 *
 * `end()` is idempotent and safe from any stage: it drops the storm out of
 * SSweather.processing and calls update_areas(), which pulls the overlays back off the
 * area instances. As of the 2026-08-19 leak wave it ALSO releases the site's
 * `active_weather` back-ref and schedules its own deletion, because until then a finished
 * storm stayed pinned by that ref for the whole 5-10 minute site cooldown, holding every
 * area it had stormed over. This proc still calls it through the production path and does
 * not qdel anything itself.
 *
 * The `weather_datums` counter in the sample is there to prove that cycle after cycle; if
 * storms accumulate, that counter is where it will show, and judge_named_leaks() fails the
 * run on it with zero tolerance.
 */
/datum/controller/subsystem/churn_soak/proc/stop_planet_storm(cycle, list/zoo)
	var/datum/weather/storm = zoo["storm"]
	var/datum/weather_site/weather = zoo["storm_site"]

	if(!QDELETED(storm))
		storm.end()
		tally_zoo("weather", "torn_down")

	if(!QDELETED(weather))
		// Drop the scheduled follow-up too. The site is about to be unregistered by the
		// planet teardown; a live cooldown timer pointed at a site that is going away is
		// exactly the kind of thing that keeps a datum resident for the rest of the round.
		weather.clear_next_hit()
		weather.active_weather = null

// ---------------------------------------------------------------------------------------
// Sampling
// ---------------------------------------------------------------------------------------

/**
 * One instance sample. Two walks, mirroring what SSinstance_census does:
 *
 * * the atom walk yields (CHECK_TICK) and is where areas, docking ports and live mobs are
 *   counted - turfs are short-circuited first because they are the overwhelming majority;
 * * the datum walk cannot yield (the bare all-datums iterator's tolerance of create/delete
 *   while suspended is unknown, which is why the census subsystem makes it opt-in) and is
 *   where the lighting datums, pipelines, footprints and space levels are counted.
 *
 * INSTANCES, never bytes: BYOND's arena quantization makes a memory figure wobble by
 * megabytes between identical states, while an instance count that should be flat is flat.
 *
 * `deep = FALSE` skips the datum walk and leaves every datum-side counter at -1 ("not
 * sampled"). Used for the mid-cycle "loaded" snapshot, which is only ever informational -
 * the verdict is computed from post-teardown samples, which are always deep.
 */
/datum/controller/subsystem/churn_soak/proc/take_sample(deep = TRUE)
	var/list/counts = list(
		"maxz" = world.maxz,
		"z_levels" = length(SSmapping.z_list),
		"map_zones" = length(SSovermap.map_zones),
		"zones_taken" = 0,
		"slots_used" = 0,
		"overmap_planets" = length(GLOB.overmap_planets),
		"pipe_networks" = length(SSair.networks),
		// VOIDCREW ADDITION 2026-08-19: the whole of the +33 pipeline drift in the 52-cycle
		// soak was member-less orphans (FORENSICS said orphan 1 -> 34 while every z-anchored
		// bucket stayed flat). That was only visible in prose; promote it to a real counter
		// so the verdict can gate on it. `has_live_members()` rather than length() - a
		// hard-deleted machine leaves a null in the list instead of shortening it.
		"pipelines_orphan" = 0,
		// Cumulative count of what SSair.reap_orphan_pipelines() has cleaned up. Rising
		// while `pipelines_orphan` stays flat means the sweep is holding the line and the
		// source is still producing; both flat at 0 means the source guards did their job.
		"pipelines_reaped" = SSair.orphan_pipelines_reaped,
		"gc_queued" = 0,
		// ---- zoo counters. Cheap list lengths, so they cost nothing and they are the
		// counters that name WHICH module leaked when a total moves.
		"overmap_ships" = length(SSovermap.simulated_ships),
		"npc_ships" = length(SSnpc_ships.active_ships),
		"ruin_signals" = length(GLOB.space_ruin_signals),
		"meteor_fields" = length(GLOB.meteor_fields),
		"mobile_ports" = length(SSshuttle.mobile_docking_ports),
		"stationary_ports" = length(SSshuttle.stationary_docking_ports),
		// Transit reservations. A hull that despawns without freeing its transit dock is
		// the round-9 signature, and it is invisible in `docking_ports` (which counts every
		// port in the world) but obvious here.
		"transit_ports" = length(SSshuttle.transit_docking_ports),
		"transit_requesters" = length(SSshuttle.transit_requesters),
		// Reserved TURFS, not reservations: a reservation that is freed but whose turfs are
		// never handed back is a leak the datum count cannot see.
		"reserved_turfs" = length(SSmapping.used_turfs),
		// VOIDCREW ADDITION 2026-08-19: `reserved_turfs` grew +152/cycle across the 52-cycle
		// soak while `turf_reservations` stayed flat at 4-5, and an exhausted reservation
		// level is what mints a permanent 255x255 z-level (~48 MB each, twice in 5 h). This
		// names the shape directly: a used_turfs entry whose reservation is gone, or a turf
		// that is no longer flagged as reserved at all, is an entry nothing will ever hand
		// back. Should be 0; anything else is the z-mint driver.
		"used_turf_orphans" = 0,
		// VOIDCREW ADDITION 2026-08-19: total ENTRIES held in every area's turf bookkeeping
		// lists. This is the counter the 52-cycle soak most needed and did not have: ~80% of
		// its +600 MB was in no instance any counter could see, and the prime suspect is list
		// CONTENTS rather than list owners. /turf/change_area() appends unconditionally with
		// no dedup, teardown routes every footprint turf into the single global space area,
		// and SSarea_contents drains with an O(N) `-=` per entry against a list areas.dm
		// itself calls "HUGE" - so it falls permanently behind. Instances stay flat while
		// tens of millions of list entries pile up. Counting entries turns that estimate into
		// a measurement. Expect a LARGE number; what matters is whether it is flat per cycle.
		"area_turf_entries" = 0,
		"turf_reservations" = 0,
		"weather_datums" = 0,
		"ascension_runs" = 0,
		"atoms" = 0,
		"areas" = 0,
		"encounter_areas" = 0,
		"docking_ports" = 0,
		"living_mobs" = 0,
		"datums" = 0,
		"lighting_objects" = 0,
		"lighting_corners" = 0,
		"light_sources" = 0,
		"pipelines" = 0,
		"map_footprints" = 0,
		"space_level_datums" = 0,
		"weather_sites" = 0,
		"log_entries" = 0,
		"qdel_items" = 0,
	)

	for(var/datum/map_zone/zone as anything in SSovermap.map_zones)
		if(QDELETED(zone))
			continue
		var/used = zone.used_slot_count()
		counts["slots_used"] += used
		if(used)
			counts["zones_taken"]++

	// VOIDCREW ADDITION: member-less pipelines still standing in SSair.networks.
	for(var/datum/pipeline/net as anything in SSair.networks)
		if(isnull(net) || QDELETED(net))
			continue
		if(net.building)
			continue
		if(!net.has_live_members())
			counts["pipelines_orphan"]++

	// VOIDCREW ADDITION: used_turfs entries that nothing is going to hand back. `as anything`
	// because a hard-deleted reservation leaves a null value behind rather than dropping the
	// key, which is precisely one of the two shapes we are counting.
	for(var/turf/reserved_turf as anything in SSmapping.used_turfs)
		if(isnull(reserved_turf))
			counts["used_turf_orphans"]++
			continue
		var/datum/turf_reservation/holder = SSmapping.used_turfs[reserved_turf]
		// Deliberately NOT also testing turf_flags & RESERVATION_TURF: cordon turfs are
		// legitimately keyed here without it (generate_cordon() only clears
		// UNUSED_RESERVATION_TURF, and the /turf/cordon ChangeTurf that follows does not
		// set it), so that test would report every cordon ring as a false orphan.
		if(isnull(holder) || QDELETED(holder))
			counts["used_turf_orphans"]++

	// VOIDCREW ADDITION: sum the ENTRIES in every area's per-z turf lists. `as anything`
	// throughout - these lists carry harddel-nulled entries and we want those counted, since
	// a null still occupies a list slot and slot count is exactly what this measures.
	for(var/area/counted_area as anything in GLOB.areas)
		if(isnull(counted_area))
			continue
		for(var/list/per_z as anything in counted_area.turfs_by_zlevel)
			if(islist(per_z))
				counts["area_turf_entries"] += length(per_z)
		for(var/list/per_z as anything in counted_area.turfs_to_uncontain_by_zlevel)
			if(islist(per_z))
				counts["area_turf_entries"] += length(per_z)
		CHECK_TICK

	if(SSgarbage.queues)
		for(var/list/queue in SSgarbage.queues)
			counts["gc_queued"] += length(queue)

	for(var/atom/thing in world)
		counts["atoms"]++
		CHECK_TICK
		if(isturf(thing))
			continue
		if(isarea(thing))
			counts["areas"]++
			if(istype(thing, /area/overmap_encounter))
				counts["encounter_areas"]++
			continue
		if(isliving(thing))
			counts["living_mobs"]++
			continue
		if(istype(thing, /obj/docking_port))
			counts["docking_ports"]++

	if(!deep)
		for(var/datum_key in list("datums", "lighting_objects", "lighting_corners", "light_sources", "pipelines", "map_footprints", "space_level_datums", "weather_sites", "log_entries", "qdel_items", "turf_reservations", "weather_datums", "ascension_runs"))
			counts[datum_key] = -1
		return counts

	// No CHECK_TICK in here on purpose - see the proc doc.
	for(var/datum/thing)
		// Two pure-bookkeeping types are counted but held OUT of `datums`, which is a
		// judged counter. Neither has anything to do with the build/teardown lifecycle
		// this soak measures, and both swamped it (~+1,000 a cycle against a real
		// game-datum population that was going DOWN):
		// * /datum/log_entry - one per line the world logs, and this harness is by far the
		//   noisiest thing on a clientless world. Growth is a function of how much the
		//   soak itself writes.
		// * /datum/qdel_item - SSgarbage's per-TYPE statistics record. One per distinct
		//   type ever qdel'd, so it is bounded by the number of types in the game and
		//   grows only as the soak reaches types it has not touched before.
		// They are reported on their own lines so a genuine explosion in either is still
		// visible; they are simply not evidence of a lifecycle leak.
		if(istype(thing, /datum/log_entry))
			counts["log_entries"]++
			continue
		if(istype(thing, /datum/qdel_item))
			counts["qdel_items"]++
			continue
		counts["datums"]++
		if(istype(thing, /datum/lighting_object))
			counts["lighting_objects"]++
			continue
		if(istype(thing, /datum/lighting_corner))
			counts["lighting_corners"]++
			continue
		if(istype(thing, /datum/light_source))
			counts["light_sources"]++
			continue
		if(istype(thing, /datum/pipeline))
			counts["pipelines"]++
			continue
		if(istype(thing, /datum/map_footprint))
			counts["map_footprints"]++
			continue
		if(istype(thing, /datum/space_level))
			counts["space_level_datums"]++
			continue
		if(istype(thing, /datum/weather_site))
			counts["weather_sites"]++
			continue
		// The zoo's three datum-side lifecycles. Each one owns something expensive - a
		// reserved block, a set of area references, a reservation plus a boss - and each
		// one is freed by a different proc, so they are counted apart rather than being
		// left to move `datums` by an amount nobody can attribute.
		if(istype(thing, /datum/turf_reservation))
			counts["turf_reservations"]++
			continue
		if(istype(thing, /datum/weather))
			counts["weather_datums"]++
			continue
		if(istype(thing, /datum/vestige_ascension_run))
			counts["ascension_runs"]++

	return counts

/// The order counters are printed and compared in. A fixed list rather than the assoc list's
/// own order so every status line in the transcript lines up column for column.
/datum/controller/subsystem/churn_soak/proc/counter_order()
	var/static/list/order = list(
		"maxz", "z_levels", "map_zones", "zones_taken", "slots_used",
		"atoms", "areas", "encounter_areas", "docking_ports", "living_mobs",
		"overmap_planets", "datums", "lighting_objects", "lighting_corners",
		"light_sources", "pipelines", "pipe_networks", "pipelines_orphan",
		"pipelines_reaped", "map_footprints",
		"space_level_datums", "weather_sites",
		"overmap_ships", "npc_ships", "ruin_signals", "meteor_fields",
		"mobile_ports", "stationary_ports", "transit_ports", "transit_requesters",
		"reserved_turfs", "used_turf_orphans", "area_turf_entries", "turf_reservations", "weather_datums", "ascension_runs",
		"log_entries", "qdel_items", "gc_queued",
	)
	return order

/datum/controller/subsystem/churn_soak/proc/log_sample(phase, cycle, list/counts)
	var/list/parts = list()
	for(var/key in counter_order())
		parts += "[key]=[counts[key]]"
	soak_log("SAMPLE cycle=[cycle] phase=[phase] [jointext(parts, " ")]")

/**
 * Diagnostic-only breakdown of the counters the verdict can only report as totals.
 *
 * The per-type census answers "what atom grew"; it cannot answer "which light_source has no
 * owner left" or "which lighting_corner no turf points at any more", because those are
 * datums whose leak signature is a broken back-reference rather than a count. This walks
 * them once per post-teardown sample and logs the classification.
 *
 * Cheap enough to leave on: it is one extra all-datums pass beside the one take_sample()
 * already does, on a world with no clients.
 */
/datum/controller/subsystem/churn_soak/proc/log_forensics(cycle)
	// ---- light sources -----------------------------------------------------------------
	var/sources_total = 0
	var/sources_no_atom = 0
	var/sources_dead_atom = 0
	var/sources_disowned = 0 // owner alive but owner.light is not us: nothing will ever free it
	var/sources_qdeleted = 0
	var/list/sources_by_owner = list()
	var/list/sources_by_z = list()
	// Space-owned survivors, located precisely: z + area + region CLASS (footprint /
	// reservation / no-region) + a coordinate sample. "Owned by /turf/open/space" has
	// now supported two wrong hypotheses in a row (ship levels; hull rects) - the region
	// class is the discriminator, because it names the teardown that should have swept
	// the turf: a footprint's zone sweep, a reservation's Release(), or - no-region -
	// the departure-path cleanup itself.
	var/list/space_owned_where = list()
	var/list/space_owned_sample = list()
	for(var/datum/light_source/source)
		sources_total++
		if(QDELETED(source))
			sources_qdeleted++
		var/turf/source_turf = source.source_turf
		sources_by_z["z[source_turf ? source_turf.z : "-"]"]++
		var/atom/owner = source.source_atom
		if(isnull(owner))
			sources_no_atom++
			sources_by_owner["<no source_atom>"]++
			continue
		if(QDELETED(owner))
			sources_dead_atom++
		var/label = "[owner.type]"
		if(owner.light != source)
			sources_disowned++
			label = "DISOWNED [label]"
		sources_by_owner[label]++
		if(isspaceturf(owner))
			var/turf/owner_turf = owner
			var/datum/owner_region = map_region_for_turf(owner_turf)
			var/region_label = "no-region"
			if(istype(owner_region, /datum/map_footprint))
				region_label = "footprint"
			else if(istype(owner_region, /datum/turf_reservation))
				region_label = "reservation([owner_region.type])"
			var/area/owner_area = owner_turf.loc
			space_owned_where["z[owner_turf.z] [region_label] [owner_area ? "[owner_area.type]" : "null-area"]"]++
			if(length(space_owned_sample) < 30)
				space_owned_sample += "([owner_turf.x],[owner_turf.y],[owner_turf.z])"

	soak_log("FORENSICS cycle=[cycle] light_sources total=[sources_total] no_source_atom=[sources_no_atom] dead_source_atom=[sources_dead_atom] disowned=[sources_disowned] self_qdeleted=[sources_qdeleted]")
	soak_log("FORENSICS cycle=[cycle] light_sources by_z: [forensics_top(sources_by_z, 14)]")
	soak_log("FORENSICS cycle=[cycle] light_sources by_owner: [forensics_top(sources_by_owner, 16)]")
	soak_log("FORENSICS cycle=[cycle] space-owned sources by z/region/area: [forensics_top(space_owned_where, 12)]")
	soak_log("FORENSICS cycle=[cycle] space-owned sample: [jointext(space_owned_sample, " ")]")
	log_disowned_source_shape(cycle)
	log_pipeline_shape(cycle)

	// ---- lighting corners ---------------------------------------------------------------
	// `detached` is the duplicate-corner signature: ChangeTurf saves a turf's four corner
	// refs, lets the replacement turf build its own during Initialize(), then restores the
	// saved ones over the top. Whichever set loses is still held by the three neighbouring
	// turfs of its vertex and by every source that applied to it, and nothing will ever
	// idle it out.
	var/corners_total = 0
	var/corners_idle = 0
	var/corners_detached = 0
	var/list/corners_by_z = list()
	for(var/datum/lighting_corner/corner)
		corners_total++
		if(!LAZYLEN(corner.affecting))
			corners_idle++
		corners_by_z["z[corner.z]"]++
		var/turf/master_ne = corner.master_NE
		var/turf/master_se = corner.master_SE
		var/turf/master_sw = corner.master_SW
		var/turf/master_nw = corner.master_NW
		var/back_refs = 0
		if(master_ne?.lighting_corner_SW == corner)
			back_refs++
		if(master_se?.lighting_corner_NW == corner)
			back_refs++
		if(master_sw?.lighting_corner_NE == corner)
			back_refs++
		if(master_nw?.lighting_corner_SE == corner)
			back_refs++
		if(!back_refs)
			corners_detached++

	soak_log("FORENSICS cycle=[cycle] lighting_corners total=[corners_total] idle_no_affecting=[corners_idle] detached_no_turf_backref=[corners_detached]")
	soak_log("FORENSICS cycle=[cycle] lighting_corners by_z: [forensics_top(corners_by_z, 14)]")

	// ---- areas with no turfs left --------------------------------------------------------
	var/empty_areas = 0
	var/list/empty_areas_by_type = list()
	for(var/area/checked as anything in GLOB.areas)
		if(QDELETED(checked))
			continue
		if(checked.has_resident_turfs())
			continue
		empty_areas++
		empty_areas_by_type["[checked.type]"] += 1
	// Areas that have been qdel'd but are still allocated: /area/Destroy() drops them out
	// of GLOB.areas immediately, so the difference against the world walk is the set
	// SSgarbage is still holding (hard-delete backlog), not a reap failure.
	var/world_areas = 0
	for(var/area/walked in world)
		world_areas++
	soak_log("FORENSICS cycle=[cycle] areas live=[length(GLOB.areas)] in_world=[world_areas] destroyed_not_yet_freed=[world_areas - length(GLOB.areas)] with_no_resident_turfs=[empty_areas]: [forensics_top(empty_areas_by_type, 60)]")

	// ---- living mobs ---------------------------------------------------------------------
	var/list/mobs_by_key = list()
	for(var/mob/living/live_mob as anything in GLOB.mob_living_list)
		if(QDELETED(live_mob))
			continue
		mobs_by_key["[live_mob.type]@z[live_mob.z]"]++
	soak_log("FORENSICS cycle=[cycle] living mobs: [forensics_top(mobs_by_key, 20)]")

/**
 * Discriminates HOW a disowned /datum/light_source got disowned.
 *
 * `disowned` alone (owner.light != src) has two completely different causes and only one
 * fix each:
 *
 * * owner.light is NULL - the owning turf datum was REPLACED by a raw `new path(T)` swap.
 *   The replacement starts with a null `light` var, every ref to the old turf silently
 *   retargets onto it, and the old source is left applied to corners with nothing pointing
 *   at it. Fix is at the swap call site (free the light first).
 * * owner.light is ANOTHER source - the atom minted a second source without freeing the
 *   first. Fix is in the lighting code, not the map code.
 *
 * Also buckets by light_range, which names the emitter: starlight is GLOB.starlight_range,
 * an ambient bleed edge is AMBIENT_BLEED_RANGE, everything else is content.
 */
/datum/controller/subsystem/churn_soak/proc/log_disowned_source_shape(cycle)
	var/owner_light_null = 0
	var/owner_light_other = 0
	var/list/by_range = list()
	var/list/by_turf_now = list()
	var/list/by_state = list()
	var/list/by_area = list()
	var/list/samples = list()
	for(var/datum/light_source/source)
		var/atom/owner = source.source_atom
		if(isnull(owner) || owner.light == source)
			continue
		if(isnull(owner.light))
			owner_light_null++
		else
			owner_light_other++
		by_range["r[source.light_range]/p[source.light_power]"]++
		by_turf_now["[owner.type]@z[isturf(owner) ? owner.z : "-"]"]++
		if(isturf(owner))
			var/turf/spot = owner
			var/state = "loose"
			if(spot.turf_flags & UNUSED_RESERVATION_TURF)
				state = "reservation:UNUSED"
			else if(SSmapping.used_turfs[spot])
				state = "reservation:USED"
			else if(spot.turf_flags & RESERVATION_TURF)
				state = "reservation:CLAIMED-not-in-used_turfs"
			var/area/spot_area = spot.loc
			by_state["[state]@z[spot.z]"]++
			by_area["[spot_area ? spot_area.type : "no area"]"]++
			if(length(samples) < 12)
				samples += "([spot.x],[spot.y],[spot.z])[state == "loose" ? "" : " [state]"]"
	soak_log("FORENSICS cycle=[cycle] disowned shape: owner_light_null=[owner_light_null] owner_light_other=[owner_light_other] (starlight_range=[GLOB.starlight_range] bleed_range=[AMBIENT_BLEED_RANGE])")
	soak_log("FORENSICS cycle=[cycle] disowned by_range: [forensics_top(by_range, 10)]")
	soak_log("FORENSICS cycle=[cycle] disowned by_owner_now: [forensics_top(by_turf_now, 10)]")
	soak_log("FORENSICS cycle=[cycle] disowned by_reservation_state: [forensics_top(by_state, 10)]")
	soak_log("FORENSICS cycle=[cycle] disowned by_area: [forensics_top(by_area, 10)]")
	soak_log("FORENSICS cycle=[cycle] disowned sample coords: [jointext(samples, " ")]")

/**
 * Says WHERE the pipelines still in SSair.networks are standing.
 *
 * `pipe_networks` alone cannot tell a station pipenet from a derelict one left behind by a
 * teardown, and the two want opposite reactions. Every pipeline is anchored by the turf of
 * its first member (or of its first component, for a members-less machine net) - so the z
 * bucket names the site, and `orphan` counts the ones with nothing left at all, which is
 * the shape a leak takes: a /datum/pipeline that nothing but SSair.networks points at,
 * processed every tick for the rest of the round.
 */
/datum/controller/subsystem/churn_soak/proc/log_pipeline_shape(cycle)
	var/total = 0
	var/orphan = 0
	var/list/by_z = list()
	var/list/samples = list()
	for(var/datum/pipeline/net as anything in SSair.networks)
		if(QDELETED(net))
			continue
		total++
		var/obj/machinery/atmospherics/anchor
		if(length(net.members))
			anchor = net.members[1]
		else if(length(net.other_atmos_machines))
			anchor = net.other_atmos_machines[1]
		if(isnull(anchor))
			orphan++
			by_z["orphan"]++
			continue
		var/turf/spot = get_turf(anchor)
		if(isnull(spot))
			by_z["nullspace"]++
			continue
		var/area/spot_area = spot.loc
		by_z["z[spot.z]"]++
		if(length(samples) < 10)
			samples += "([spot.x],[spot.y],[spot.z]) [spot_area ? spot_area.type : "no area"] members=[length(net.members)]"
	soak_log("FORENSICS cycle=[cycle] pipelines total=[total] orphan=[orphan] husks_parked=[length(SSair.pipeline_husks)]")
	soak_log("FORENSICS cycle=[cycle] pipelines by_z: [forensics_top(by_z, 14)]")
	soak_log("FORENSICS cycle=[cycle] pipelines samples: [jointext(samples, " | ")]")

/// "key=count, key=count, ..." for the `top` largest entries of an assoc count list.
/datum/controller/subsystem/churn_soak/proc/forensics_top(list/counts, top)
	if(!length(counts))
		return "(none)"
	sortTim(counts, cmp = GLOBAL_PROC_REF(cmp_numeric_dsc), associative = TRUE)
	var/list/parts = list()
	var/shown = 0
	for(var/key in counts)
		parts += "[key]=[counts[key]]"
		shown++
		if(shown >= top)
			break
	if(length(counts) > shown)
		parts += "(+[length(counts) - shown] more)"
	return jointext(parts, ", ")

/// Runs the production census subsystem's own walk on demand rather than reimplementing it,
/// so the NDJSON the soak leaves behind is the same shape census_diff.py already reads.
/datum/controller/subsystem/churn_soak/proc/take_census_now()
	var/deadline = world.time + 2 MINUTES
	while(SSinstance_census.walk_in_progress && world.time < deadline)
		sleep(2 SECONDS)
	if(SSinstance_census.walk_in_progress)
		soak_log("WARN census pass skipped - a previous walk is still running")
		return
	SSinstance_census.take_census(include_datums = TRUE)

// ---------------------------------------------------------------------------------------
// Verdict
// ---------------------------------------------------------------------------------------

/// Per-counter allowance for TOTAL growth per cycle across cycles 2..N. Zero means the
/// counter must come back exactly; anything absent from this list is not judged, only
/// reported. The non-zero entries are noise floors, not licences: `encounter_areas` has a
/// known, documented leak (fill_in() news an area instance per build and nothing ever qdels
/// it - wave 3 report section 10), so it is tracked and reported but given room, and
/// `atoms`/`datums` inherit that same slack because those areas are counted inside them.
/datum/controller/subsystem/churn_soak/proc/growth_tolerances()
	var/static/list/tolerances = list(
		"z_levels" = 0,
		"map_zones" = 0,
		"zones_taken" = 0,
		"slots_used" = 0,
		"map_footprints" = 0,
		"space_level_datums" = 0,
		"weather_sites" = 0,
		"docking_ports" = 0,
		"pipelines" = 0,
		"pipe_networks" = 0,
		// VOIDCREW ADDITION: the shape the +33 pipeline drift actually took. Zero tolerance -
		// a pipeline with no live members is never legitimate outside the build window, and
		// the counter already excludes `building` ones.
		"pipelines_orphan" = 0,
		// `pipelines_reaped` is deliberately absent: it is cumulative and SUPPOSED to be able
		// to rise. It is reported, never judged.
		// VOIDCREW ADDITION: used_turfs entries whose reservation is gone. This is what was
		// silently filling the reservation z-level and minting new ones.
		"used_turf_orphans" = 0,
		"living_mobs" = 2,
		"lighting_objects" = 8,
		"lighting_corners" = 32,
		"light_sources" = 8,
		"overmap_planets" = 0,
		"encounter_areas" = 12,
		"areas" = 16,
		"atoms" = 128,
		"datums" = 512,
		// ---- zoo counters. Every one of these is a population that must come back to
		// exactly where it started, because the soak deletes its own markers: the hull, the
		// crash site, the ruin signal, the field and the arena run are all qdel'd by the
		// teardowns above. Anything left over is a lifecycle bug, not noise, so the
		// tolerance is zero and stays zero.
		"overmap_ships" = 0,
		"npc_ships" = 0,
		"ruin_signals" = 0,
		"meteor_fields" = 0,
		"mobile_ports" = 0,
		// Transit docks have an ASYNCHRONOUS reaper: SSshuttle sweeps ownerless transit
		// ports on its own schedule, which is longer than the 20-second settle before the
		// sample. A constant +1 in flight at sampling time is normal; accumulation is not,
		// and a per-cycle floor of 1 is the difference between the two.
		"transit_ports" = 1,
		"transit_requesters" = 1,
		"turf_reservations" = 0,
		"weather_datums" = 0,
		"ascension_runs" = 0,
		// Reserved turfs move in whole blocks, and a reservation freed one cycle can be
		// re-dealt to a differently-sized tenant the next, so the endpoint is legitimately
		// noisy while the TREND must be flat. The regression gate below is what judges it;
		// this is its per-cycle noise floor.
		"reserved_turfs" = 64,
		// Stationary ports: the reserve docks on planets and outposts are re-homed rather
		// than recreated, but a crash site mints two of its own per crash. Small floor.
		"stationary_ports" = 2,
	)
	return tolerances

/**
 * Least-squares slope of `key` over post-teardown cycles `from`..`to`, in instances per
 * cycle.
 *
 * The short-run verdict compares two endpoints, which is the right tool for three or four
 * samples and the wrong one for fifty: an oscillating series (`lighting_corners` is the
 * documented example - it swung 998 wide on a 5-cycle run purely on which cycle the ruin
 * RNG dealt a big footprint) will show whatever the endpoints happen to be, and multiplying
 * a per-cycle noise floor by fifty spans turns every gate into a rubber stamp.
 *
 * A regression over the whole series has neither problem. Endpoint luck averages out, and
 * the slope is directly comparable against the same per-cycle tolerance the short run uses,
 * because that tolerance was always expressed as "per cycle".
 */
/// (`to` is a DM keyword - hence the `_cycle` suffixes.)
/datum/controller/subsystem/churn_soak/proc/counter_slope(key, from_cycle, to_cycle)
	var/count = to_cycle - from_cycle + 1
	if(count < 2)
		return 0
	var/sum_x = 0
	var/sum_y = 0
	var/sum_xy = 0
	var/sum_xx = 0
	for(var/cycle in from_cycle to to_cycle)
		var/list/sample = cycle_samples["[cycle]"]
		if(!sample)
			continue
		var/y = sample[key]
		sum_x += cycle
		sum_y += y
		sum_xy += cycle * y
		sum_xx += cycle * cycle
	var/denominator = (count * sum_xx) - (sum_x * sum_x)
	if(!denominator)
		return 0
	return ((count * sum_xy) - (sum_x * sum_y)) / denominator

/**
 * The long-run flatness gate: judge the TREND, not the endpoints.
 *
 * For each judged counter, a least-squares slope is taken over post-teardown cycles
 * 3..N (cycle 1 mints the lattice and cycle 2 is still settling behind it) and compared
 * against the same per-cycle tolerance the short run uses. Zero-tolerance counters get one
 * concession: a slope alone cannot fail them, the last sample must also actually be above
 * the third. That stops a single one-off step - a type the world reached for the first time
 * on cycle 12 - from failing a counter that has been perfectly flat for the other forty.
 *
 * The known lighting residue is exempt HERE and measured separately in criterion 5: the
 * ambient-lighting port leaves 6 pinned light sources and 61 detached corners per planet
 * z-level, paid once on the first build and constant thereafter. Constant means slope zero,
 * so in practice it never trips this gate anyway - but it is named so nobody has to
 * rediscover why `light_sources` sits 6 above a clean world.
 */
/datum/controller/subsystem/churn_soak/proc/judge_by_regression(completed)
	var/list/tolerances = growth_tolerances()
	var/list/third = cycle_samples["3"]
	var/list/last = cycle_samples["[completed]"]
	var/spans = completed - 3
	var/list/breaches = list()
	var/list/watch = list()

	for(var/key in counter_order())
		if(!(key in tolerances))
			continue
		var/slope = counter_slope(key, 3, completed)
		var/drift = last[key] - third[key]
		var/allowed = tolerances[key]
		// Round to a tenth for the transcript; the comparison uses the raw value.
		var/shown_slope = round(slope * 1000) / 1000
		var/breached = FALSE
		if(allowed > 0)
			breached = (slope > allowed)
		else
			breached = (slope > 0 && drift > 0)
		if(breached)
			breaches += "[key] slope +[shown_slope]/cycle over [spans] span\s (allowed [allowed]/cycle), c3=[third[key]] -> c[completed]=[last[key]] (drift [drift > 0 ? "+" : ""][drift])"
		else if(slope > 0 && drift > 0)
			watch += "[key] +[shown_slope]/cycle (within [allowed]), c3=[third[key]] -> c[completed]=[last[key]]"

	verdict_line( \
		!length(breaches), \
		"post-teardown instance counts flat across cycles 3-[completed] (regression)", \
		length(breaches) ? jointext(breaches, "; ") : "no counter's trend exceeded its per-cycle tolerance over [spans] span\s" \
	)
	if(length(watch))
		soak_log("WATCH [jointext(watch, "; ")]")

/**
 * Records this cycle's lighting residue so the verdict can say whether the documented
 * bounded residue is still bounded.
 *
 * The ambient-lighting port left one known cost: ruin daylight pins ~6 /datum/light_source
 * and leaves ~61 detached /datum/lighting_corner on each planet z-level. Both were measured
 * IDENTICAL in every cycle of the port's own soak, i.e. a one-time price on the first build
 * rather than a per-cycle leak. That claim is worth re-testing over fifty cycles instead of
 * three, which is what this is for.
 */
/datum/controller/subsystem/churn_soak/proc/record_lighting_residue(cycle)
	var/disowned = 0
	var/detached = 0
	for(var/datum/light_source/source)
		var/atom/owner = source.source_atom
		if(owner && owner.light != source)
			disowned++
	for(var/datum/lighting_corner/corner)
		var/turf/master_ne = corner.master_NE
		var/turf/master_se = corner.master_SE
		var/turf/master_sw = corner.master_SW
		var/turf/master_nw = corner.master_NW
		if(master_ne?.lighting_corner_SW == corner)
			continue
		if(master_se?.lighting_corner_NW == corner)
			continue
		if(master_sw?.lighting_corner_NE == corner)
			continue
		if(master_nw?.lighting_corner_SE == corner)
			continue
		detached++
	lighting_residue_samples += list(list("cycle" = cycle, "disowned" = disowned, "detached" = detached))

/// PASS/FAIL for the known bounded lighting residue: exempt from the flatness gate, but
/// only for as long as it stays bounded. Judged on the trend for the same reason
/// everything else is.
/datum/controller/subsystem/churn_soak/proc/judge_lighting_residue()
	if(length(lighting_residue_samples) < 3)
		soak_log("REPORT lighting residue: only [length(lighting_residue_samples)] sample\s - not judged")
		return
	var/list/first = lighting_residue_samples[1]
	var/list/last = lighting_residue_samples[length(lighting_residue_samples)]
	var/disowned_drift = last["disowned"] - first["disowned"]
	var/detached_drift = last["detached"] - first["detached"]
	var/list/series = list()
	for(var/list/sample as anything in lighting_residue_samples)
		series += "c[sample["cycle"]]:[sample["disowned"]]/[sample["detached"]]"
	// Proportional, not absolute. The port's own soak measured 6 disowned sources and 61
	// detached corners because it built nothing but planets; with the content zoo the base
	// is an order of magnitude higher (ruins, arenas and asteroid fields all light
	// themselves), and a cycle that dealt more outdoor ruin yards legitimately swings it by
	// tens. A flat +4/+40 at that scale would cry wolf every night. 10% of the first
	// reading, floored at the original numbers, still catches a leak by a mile: anything
	// actually accumulating per cycle blows past 10% long before the budget is spent.
	var/disowned_allowance = max(4, round(first["disowned"] * 0.1))
	var/detached_allowance = max(40, round(first["detached"] * 0.1))
	var/bounded = (disowned_drift <= disowned_allowance) && (detached_drift <= detached_allowance)
	verdict_line( \
		bounded, \
		"the known ambient-lighting residue is still bounded", \
		"disowned light sources [first["disowned"]] -> [last["disowned"]] (drift [disowned_drift > 0 ? "+" : ""][disowned_drift], allowed [disowned_allowance]), detached corners [first["detached"]] -> [last["detached"]] (drift [detached_drift > 0 ? "+" : ""][detached_drift], allowed [detached_allowance]) over [length(lighting_residue_samples)] cycle\s. Series (disowned/detached): [jointext(series, " ")]" \
	)

/// Per-module build/teardown accounting. A module that silently stopped doing anything on
/// cycle 6 produces a beautifully flat run, so the counts have to be stated.
/**
 * Absolute, no-concessions gate on the counters a live leak hunt is watching.
 *
 * Criterion 3 judges these too, but through a regression whose zero-tolerance branch has a
 * deliberate concession ("a slope alone cannot fail it, the last sample must also be above
 * the third"), which is right for forty counters and wrong for a counter somebody is
 * currently trying to drive to zero. On the 2026-08-19 overnight these three drifted all
 * night and nobody got told, because the reboot ate the verdict before criterion 3 ran.
 *
 * This gate is deliberately dumber: the last post-teardown sample must be at or below
 * CYCLE 1's. Every one of these is a population the soak creates and destroys itself, so
 * "back to where we started" is the whole contract, and the full per-cycle series is printed
 * either way so a FAIL is diagnosable without a re-run.
 *
 * Cycle 1 rather than `baseline`: the baseline sample is taken before the soak has stood
 * anything up at all, and some of these counters legitimately settle one above it and then
 * stay there forever. `weather_datums` is the worked example - the baseline world has no
 * weather site, the first cycle's planets give it one, and a single resident storm datum
 * from then on is the correct steady state. Judged against the baseline it failed the
 * 2026-08-19 verification run on a series reading `c1:1 c2:1 ... c21:1`, which is precisely
 * the shape a leak does NOT have. Cycle 1 is also the same "cycle 1 mints, cycles 2..N are
 * compared" rule criteria 1 and 3 already use.
 */
/datum/controller/subsystem/churn_soak/proc/judge_named_leaks(completed)
	var/static/list/watched = list(
		"weather_datums" = "a finished /datum/weather that was never freed - each one also pins the areas it stormed over",
		"pipelines" = "every live /datum/pipeline instance - see the FORENSICS pipelines lines for where they stand",
		"pipelines_orphan" = "pipelines left in SSair.networks with no LIVE member and no LIVE machine, excluding ones still flagged `building`. This is the shape the 52-cycle soak's +33 drift took, and it is what SSair.reap_orphan_pipelines() exists to clear",
		"pipelines_reaped" = "cumulative pipelines SSair.reap_orphan_pipelines() has deleted. Reported, never judged - rising here while pipelines_orphan stays flat means the sweep is covering for a source that is still leaking",
		"area_turf_entries" = "total ENTRIES across every area's turfs_by_zlevel and turfs_to_uncontain_by_zlevel. Reported, not judged - the absolute number is legitimately huge. What matters is the per-cycle DELTA: if it climbs by ~100k a cycle, SSarea_contents is losing its race with /turf/change_area() and that is where the unexplained memory went",
		"used_turf_orphans" = "SSmapping.used_turfs entries whose /datum/turf_reservation is null or deleted - reserved turfs nothing will ever hand back. These fill the reservation z-level and make request_turf_block_reservation() mint a new permanent one",
		"pipe_networks" = "SSair.networks length itself",
	)
	var/list/first = cycle_samples["1"]
	if(!completed || !first)
		verdict_line(FALSE, "named leak counters flat from cycle 1", "no cycle 1 sample to compare against")
		return
	for(var/key in watched)
		var/list/series = list()
		for(var/cycle in 1 to completed)
			var/list/sample = cycle_samples["[cycle]"]
			if(sample)
				series += "c[cycle]:[sample[key]]"
		var/list/last = cycle_samples["[completed]"]
		var/start = first[key]
		var/end = last ? last[key] : -1
		verdict_line( \
			end <= start, \
			"[key] flat from cycle 1 (zero tolerance)", \
			"c1 [start] -> c[completed] [end] (drift [end - start > 0 ? "+" : ""][end - start]); [watched[key]]. Series: [jointext(series, " ")]" \
		)

/datum/controller/subsystem/churn_soak/proc/report_zoo_tally(completed)
	if(!zoo_enabled)
		soak_log("REPORT content zoo: DISABLED for this run (map zones only)")
		return
	if(!length(zoo_tally))
		soak_log("REPORT content zoo: enabled but no module ever reported - nothing was churned")
		failures++
		return
	for(var/module in zoo_tally)
		var/list/counts = zoo_tally[module]
		soak_log("REPORT zoo module '[module]': built [counts["built"]], torn down [counts["torn_down"]], forced [counts["forced"]], skipped [counts["skipped"]] over [completed] cycle\s")

/datum/controller/subsystem/churn_soak/proc/write_verdict(abort_reason)
	if(verdict_written)
		return
	verdict_written = TRUE

	soak_log("=== CHURN SOAK: verdict ===")
	if(abort_reason)
		soak_log("run did not complete normally: [abort_reason]")

	var/completed = length(cycle_samples)
	soak_log("cycles completed: [completed][overnight ? " in [round(wall_budget / 600)] min of budget" : " of [cycles] requested"][stopped_early ? " (stopped early on the wall-clock budget)" : ""]; degraded cycles: [degraded_cycles]; world runtimes: [GLOB.total_runtimes]")

	// --- 1. z-level lattice is minted once ---------------------------------------------
	if(completed < 2)
		verdict_line(FALSE, "world.maxz stable from cycle 2", "only [completed] cycle\s completed - needs at least 2")
	else
		var/reference = cycle_maxz["2"]
		var/stable = TRUE
		var/list/observed = list()
		for(var/cycle in 1 to completed)
			observed += "c[cycle]=[cycle_maxz["[cycle]"]]"
			if(cycle >= 2 && cycle_maxz["[cycle]"] != reference)
				stable = FALSE
		verdict_line(stable, "world.maxz identical from cycle 2 onward", "[jointext(observed, " ")] (cycle 1 mints the lattice)")

	// --- 2. every slot handed back ------------------------------------------------------
	var/list/final_sample = completed ? cycle_samples["[completed]"] : null
	if(!final_sample)
		verdict_line(FALSE, "all map-zone slots free at the end", "no post-teardown sample was taken")
	else
		var/baseline_slots = baseline ? baseline["slots_used"] : 0
		var/final_slots = final_sample["slots_used"]
		var/list/stragglers = list()
		for(var/datum/map_zone/zone as anything in SSovermap.map_zones)
			if(QDELETED(zone))
				continue
			var/used = zone.used_slot_count()
			if(used)
				stragglers += "'[zone.name]' [used]/[zone.slot_capacity] ([zone.tenant_class])"
		verdict_line(final_slots == baseline_slots, "all map-zone slots free at the end", "baseline [baseline_slots] occupied, final [final_slots] occupied across [length(SSovermap.map_zones)] zone\s[length(stragglers) ? "; still held: [jointext(stragglers, ", ")]" : ""]")

	// --- 3. instance counts flat across cycles 2..N -------------------------------------
	//
	// Two gates, and which one applies is decided by how many samples there are rather than
	// by which mode was asked for - a fixed-cycle run that happened to complete 30 cycles
	// deserves the better test, and an overnight run that crashed at cycle 4 must still get
	// an answer.
	if(completed < 3)
		verdict_line(FALSE, "post-teardown instance counts flat", "only [completed] cycle\s completed - needs at least 3 (cycle 1 mints, cycles 2..N are compared)")
	else if(completed >= CHURN_SOAK_REGRESSION_MIN_CYCLES)
		judge_by_regression(completed)
	else
		var/list/tolerances = growth_tolerances()
		var/list/first = cycle_samples["2"]
		var/list/last = cycle_samples["[completed]"]
		var/spans = completed - 2
		var/list/breaches = list()
		var/list/creeping = list()
		for(var/key in counter_order())
			if(!(key in tolerances))
				continue
			var/growth = last[key] - first[key]
			var/allowed = tolerances[key] * spans
			// A counter that goes up on EVERY cycle is a leak whatever its magnitude, so it
			// is called out even when the total stays inside the noise floor.
			var/monotonic = TRUE
			for(var/cycle in 3 to completed)
				var/list/this_cycle = cycle_samples["[cycle]"]
				var/list/previous_cycle = cycle_samples["[cycle - 1]"]
				if(this_cycle[key] <= previous_cycle[key])
					monotonic = FALSE
					break
			if(growth > allowed)
				breaches += "[key] +[growth] over [spans] cycle\s (allowed [allowed])[monotonic ? ", rising every cycle" : ""]"
			else if(monotonic && growth > 0)
				creeping += "[key] +[growth] (within tolerance [allowed]) but rising every cycle"
		verdict_line(!length(breaches), "post-teardown instance counts flat across cycles 2-[completed]", length(breaches) ? jointext(breaches, "; ") : "no counter grew past its tolerance")
		if(length(creeping))
			soak_log("WATCH [jointext(creeping, "; ")]")

	// --- 4. planet ground holds no lighting objects -------------------------------------
	// Additive criterion: nothing above it is relaxed. See measure_surface_lighting().
	if(!length(surface_lighting_samples))
		verdict_line(FALSE, "planet surface ground carries no lighting objects", "no planet was measured - build_planets() produced nothing with a footprint")
	else
		var/list/offenders = list()
		var/worst_share = 0
		var/total_ambient = 0
		var/total_with_object = 0
		var/total_gate_miss = 0
		var/total_bleed_lit = 0
		for(var/list/sample as anything in surface_lighting_samples)
			total_ambient += sample["ambient"]
			total_with_object += max(sample["with_object"], 0)
			total_gate_miss += sample["gate_miss"]
			total_bleed_lit += sample["bleed_lit"]
			worst_share = max(worst_share, sample["share"])
			if(sample["share"] > CHURN_SOAK_SURFACE_LIT_SHARE)
				offenders += "c[sample["cycle"]] [sample["label"]] [sample["with_object"]]/[sample["ambient"]] ([round(sample["share"] * 1000) / 10]%)"
		// 4a. The unambiguous bug, and the one this whole assertion exists to catch: a turf
		// with NO light of its own that got a lighting object anyway. Every legitimate
		// survivor lights itself; a dark one means some build site is not consulting
		// skips_lighting_object(). Tolerance is zero and must stay zero - unlike the share
		// below, this number does not depend on which biomes or ruins the RNG dealt.
		// bleed lights are folded in: AMBIENT_BLEED_RANGE is the sentinel the gate keys on,
		// so an edge turf holding an object means the sentinel is not holding either.
		verdict_line( \
			!total_gate_miss && !total_bleed_lit, \
			"no ungated lighting objects on planet surface ground", \
			"[total_gate_miss] turf\s with no light of their own and [total_bleed_lit] ambient-bleed edge turf\s still hold a lighting object across [length(surface_lighting_samples)] planet build\s (both must be 0 - see the SURFACE LIGHTING survivors lines for the types)" \
		)
		// 4b. Coarse backstop. Every planet was ~100% lit ground before the ambient port, so
		// this catches a wholesale regression even if 4a's classifier were itself broken.
		// The ceiling is generous because the legitimate survivor population is content -
		// self-lit basalt, lava rivers, fallout green, and /lit tiles ruin .dmms drop
		// straight onto surface ground - and varies by biome and by the ruin draw.
		verdict_line( \
			!length(offenders), \
			"planet surface ground is not wholesale lit", \
			"[total_with_object]/[total_ambient] ambient-lit ground turfs across [length(surface_lighting_samples)] planet build\s carry a lighting object (worst planet [round(worst_share * 1000) / 10]%, ceiling [CHURN_SOAK_SURFACE_LIT_SHARE * 100]%, pre-port was ~100%)[length(offenders) ? "; over ceiling: [jointext(offenders, ", ")]" : ""]" \
		)

	// --- 5. the known ambient-lighting residue is still bounded -------------------------
	// Exempted from criterion 3 by design, so it gets its own gate rather than a footnote.
	judge_lighting_residue()

	// --- 6. the two counters a leak wave is currently hunting --------------------------
	judge_named_leaks(completed)

	// --- Reported, not judged ------------------------------------------------------------
	report_zoo_tally(completed)

	// Full per-cycle table, so a FAIL can be read without re-running anything.
	if(baseline)
		log_sample("baseline", 0, baseline)
	for(var/cycle in 1 to completed)
		log_sample("post-teardown", cycle, cycle_samples["[cycle]"])

	soak_log("CHURN SOAK VERDICT: [failures ? "FAIL" : "PASS"] ([failures] failed criteri[failures == 1 ? "on" : "a"])")
	soak_log("=== CHURN SOAK: end ===")

	// Let the log writes and any trailing async work land before the world goes away.
	sleep(5 SECONDS)
	// Same clean headless exit the autowiki harness uses.
	qdel(world)

#undef CHURN_SOAK_CYCLES
#undef CHURN_SOAK_FLATS_PER_CYCLE
#undef CHURN_SOAK_WALL_BUDGET
#undef CHURN_SOAK_WALL_BUDGET_MIN
#undef CHURN_SOAK_CENSUS_EVERY
#undef CHURN_SOAK_ZOO
#undef CHURN_SOAK_ZOO_LOAD_TIMEOUT
#undef CHURN_SOAK_ZOO_TEARDOWN_TIMEOUT
#undef CHURN_SOAK_REGRESSION_MIN_CYCLES
#undef CHURN_SOAK_LOAD_TIMEOUT
#undef CHURN_SOAK_TEARDOWN_TIMEOUT
#undef CHURN_SOAK_BOOT_TIMEOUT
#undef CHURN_SOAK_WATCHDOG_STALL
#undef CHURN_SOAK_DEFAULT_LOG
#undef CHURN_SOAK_DD_LOG
#undef CHURN_SOAK_POINTER
