/**
 * # Ghost round: a scripted hour of a full server, driven headless
 *
 * NOT part of tgstation.dme, and it must never be. `tools/instance_census/run_ghost_round.sh`
 * copies the dme, appends an include of this file to the COPY, and compiles that. Because the
 * include lands LAST, every duplicate proc below chains OUTSIDE the upstream one (DM chains
 * duplicate procs; the last include wins the outermost frame). That is the entire mechanism
 * this harness runs on, and it is also why nothing here is allowed to exist in production.
 *
 * ## The question
 *
 * "What does an hour of a seventy-player round actually cost?" Twelve player hulls founded
 * through the real ship-load path, ~70 human mobs with minds crewing them, planets AND space
 * ruins AND asteroid fields loaded and occupied CONCURRENTLY, NPC pirates at their live
 * target, real ship-to-ship combat with hull kills and crash sites, storms, an ascension
 * arena, and an attrition phase that puts wiped crews' hulls through the production derelict
 * pipeline while other sites stay occupied.
 *
 * ## THE ONE THING THIS CANNOT MEASURE
 *
 * DM cannot fake a /client. There is no way to construct one, and every per-client cost -
 * SendMaps (the per-viewer map streaming), view() computation, statpanel updates, the whole
 * `sendmaps` profiler category - is therefore ABSENT from these numbers. On a real 70-player
 * host that is a large and load-bearing share of the tick. Everything else measured here is
 * real: MC tick usage, time dilation, per-subsystem cost, atmos, AI, mob processing, combat,
 * worldgen, garbage collection and memory. Read every figure in this harness as
 * "server-side cost excluding sendmaps", and read the perf CSV's `maptick` column - which
 * will sit near zero for the whole run - as the proof that the exclusion is total.
 *
 * ## Occupancy shims: the validity argument
 *
 * ~70 mobs with minds but no clients are invisible to every player-presence primitive in the
 * codebase, because those all scan GLOB.player_list or dereference .client. Left unshimmed
 * the round would be wrong in the WORST direction: sites would read as empty and release
 * under the crews standing on them, hulls would be force-undocked, spawners and AI wakeup
 * would idle, and the measured hour would be a quiet one. So this file chain-overrides each
 * primitive to return `(original result) UNION (sim crew matching the same predicate)`.
 *
 * Every shim mirrors its production predicate exactly - same liveness test, same geometry,
 * same area membership - and each one is listed in the report. Sim crew are deliberately NOT
 * inserted into GLOB.player_list or SSmobs.clients_by_zlevel: downstream code dereferences
 * `.client` on the members of both and would runtime on the first read.
 *
 * ## Measurement
 *
 * * The production perf CSV (`data/logs/<run>/perf-*.csv`, written by SStime_track every 10s)
 *   is primary for time dilation - untouched, so the numbers are the ones a live host writes.
 * * A 1-SECOND sampler (SSghost_sampler) writes a parallel CSV. Ten-second resolution smears
 *   a 30-second asteroid field build into two rows; the load bursts are the events worth
 *   measuring and they need finer cuts than that.
 * * Every site load is bracketed with a LOAD WINDOW record (type, label, z, start, end,
 *   duration), so the final profile can cut the sampler series to exactly the generation
 *   bursts and compare them against the surrounding steady state.
 * * SSprofiler dumps bracket the big bursts; an instance census runs every 15 minutes; the
 *   driver-side memory sampler runs from the shell script.
 *
 * ## Time dilation
 *
 * Computed exactly as SStime_track computes it (code/controllers/subsystem/time_track.dm:100):
 *
 *     tick_drift = max(0, ((realtime_delta) - (byondtime_delta)) / world.tick_lag)
 *     TD%        = tick_drift / ticks_elapsed * 100
 *
 * TD is therefore a PERCENTAGE OF EXTRA WALL TIME per byond tick, and the glide multiplier a
 * player would see is `1 + TD/100`. The three thresholds this harness reports against are the
 * glide multipliers named in the brief:
 *
 *     TD >   5%  ->  1.05x  (perceptible)
 *     TD >  25%  ->  1.25x  (bad)
 *     TD > 100%  ->  2.00x  (the round is on fire)
 *
 * TD IS HARDWARE-RELATIVE. These are dev-box numbers on a machine that may also be running a
 * churn soak and the owner's own client. They are a shape, not a server SLA.
 */

// ---------------------------------------------------------------------------------------
// Tunables
// ---------------------------------------------------------------------------------------

/// Player hulls to found. Four arrive through the roundstart fleet scaler, the rest are
/// requisitioned from the join menu's own path, which is how a 70-player round gets past
/// SSovermap.roundstart_max_ships (4) in the first place.
#define GHOST_SHIPS_DEFAULT 12
/// Sim crew across the whole fleet.
#define GHOST_CREW_DEFAULT 70
/// Round length in minutes. The profile is written at the end of this.
#define GHOST_BUDGET_MIN_DEFAULT 70

/// Crew per hull is dealt from this range, so hulls are unevenly manned like a real fleet.
#define GHOST_CREW_MIN_PER_SHIP 4
#define GHOST_CREW_MAX_PER_SHIP 8

/// Sampler period. One second: a 30-second field build must land in ~30 rows, not 3.
#define GHOST_SAMPLE_PERIOD 10
/// Crew driver period. Two seconds per crew member is roughly a deliberate player's action
/// rate and keeps the driver's own cost off the top of the profile - which is measured and
/// reported either way, because a harness that dominates the tick measures itself.
#define GHOST_CREW_TICK 20

/// Phase boundaries, in minutes from the moment the round is armed.
#define GHOST_PHASE_LAUNCH_END 10
#define GHOST_PHASE_PEAK_END 40
#define GHOST_PHASE_ATTRITION_END 60

/// Concurrency floors for the peak phase. The whole point of the scenario is that these hold
/// SIMULTANEOUSLY - a round where four planets are up and the ruins have all been released is
/// not the round being modelled.
#define GHOST_TARGET_PLANETS 4
#define GHOST_TARGET_RUINS 3
#define GHOST_TARGET_FIELDS 2

/// How long one site is given to load before the beat gives up on it.
#define GHOST_LOAD_TIMEOUT (6 MINUTES)
/// How long a ship is given to fly a leg before the beat stops waiting.
#define GHOST_FLIGHT_TIMEOUT (5 MINUTES)
/// How long a dock sequence is given to complete.
#define GHOST_DOCK_TIMEOUT (3 MINUTES)
/// How long to wait for the round to reach a runnable state.
#define GHOST_BOOT_TIMEOUT (25 MINUTES)
/// The watchdog fires when the driver has not stamped progress for this long. A DM runtime
/// unwinds the driver silently and there is no `finally` in this language, so a frozen
/// progress stamp is the only symptom an exception has. try/catch is deliberately not used:
/// a caught runtime inside a map template load leaves dead maps behind.
#define GHOST_WATCHDOG_STALL (14 MINUTES)

/// Census snapshot period.
#define GHOST_CENSUS_EVERY (15 MINUTES)
/// SSprofiler dump period. Bursts get their own extra brackets on top of this.
#define GHOST_PROFILE_EVERY (10 MINUTES)
/// How often the whole analysis is written mid-run as insurance. See snapshot_recorder().
#define GHOST_SNAPSHOT_EVERY (15 MINUTES)

// ---------------------------------------------------------------------------------------
// Sustained mode (`ghost-round-sustain=1`, implied by any budget over 100 minutes)
//
// The 70-minute script runs launch -> peak -> attrition once and stops. A three-hour round is
// not that script stretched; a real server does not spend its second hour in one long
// attrition phase. Sustained mode keeps the launch phase, then LOOPS the peak/attrition
// dynamics for the rest of the budget: hulls and crew are replenished as fast as attrition
// removes them, crews keep rotating between sites, a worldgen burst fires about hourly, and
// crews keep getting wiped on a timer.
//
// The deliverable question is "does hour 3 look like hour 1" - plateau or creep, in BOTH
// memory and tick cost - so the round has to be in the same state at minute 170 as at minute
// 20, with only the accumulated wreckage differing. Corpses and derelicts are deliberately NOT
// cleaned up: their accumulation is the thing under test.
// ---------------------------------------------------------------------------------------

// ---------------------------------------------------------------------------------------
// CHURN REGIMES  (`ghost-round-regime=stress|ordinary|real`)
//
//   stress    THE DEFAULT, and what runs 1-4 were measured on. The GHOST_SUSTAIN_* clocks as
//             written, churn_scale 1: founding wave every 20m, crew wipe every 8m, worldgen
//             burst every 20m, mission dwell 80-160s.
//   ordinary  the same clocks at churn_scale 3: 60m / 24m / 60m, mission dwell 240-480s.
//   real      the measured cadence of a production 70-player round - a hull founded every 5.0m,
//             a crew wiped every 14.4m, and site loads on a CONTINUOUS TRICKLE rather than in
//             waves. See THE REAL REGIME below.
//
// A run that passes no regime flag gets `stress` and behaves exactly as it did before this
// block was written, which is what keeps runs 1-4 comparable.
//
// WHAT THIS BLOCK USED TO CLAIM, AND WHY IT IS GONE.
//
// It said the harness ran "roughly THREE TIMES the rate an ordinary round would" and that it was
// "DELIBERATELY HOTTER THAN A REAL ROUND on worldgen", because "a real seventy-player server does
// not load a new site every couple of minutes for three hours". Three production rounds were
// then measured against it (scratchpad/real-round-churn-calibration.md) and all three claims
// were wrong:
//
//   * A real seventy-player server does exactly that. Round-7 loaded a site every 1.9 minutes
//     (median) for 2.4 hours at a median of 70 concurrent players - ~32/h, which is 1.27x what
//     EITHER harness regime produced. On total site-load volume the harness is an UNDER-estimate
//     of a real round; only its CLUMPING is more extreme than reality.
//   * churn_scale never reached the thing that actually drives site loads. It multiplied the
//     burst, founding and wipe clocks only, while the mission-rotation dwell was a hardcoded
//     rand(80, 160) SECONDS - so the two regimes produced the SAME site-load rate, 23.2/h
//     against 23.3/h. A 3x knob moved worldgen volume by 0.4%. dwell_scale() now applies
//     churn_scale to the dwell as well, which is what finally makes the legacy regimes differ
//     from each other on worldgen.
//   * As a geometric mean of the real/harness ratios across foundings, losses and site loads,
//     STRESS is ~1.2x a real 70-player round and ORDINARY is ~0.7x. Not 3x and 1x: the old
//     labels were off by about 2.5x in both directions.
//
// What survives is the useful half. Stress is still a FASTER LEAK DETECTOR on hull churn and
// attrition - 21 foundings/h and 6.6 wipes/h against a real round's 12.1 and 4.2 - so anything
// that accumulates per hull-cycle still shows up in a fraction of the wall time. It is simply
// not an upper bound on worldgen, and TD figures from it must not be read as one.
//
// The per-hour churn columns in the trend table exist to quantify exactly that: they put the
// intensity next to the memory and TD numbers so the two are never read apart.
// ---------------------------------------------------------------------------------------

/// A replacement hull may be founded at most this often. Rate-capped so a bad patch of
/// attrition cannot become a template-load storm that measures itself, but short enough to keep
/// up with the elevated wipe rate.
#define GHOST_REFOUND_COOLDOWN (90 SECONDS)
/// A latejoin WAVE - a new hull and its crew founded on the clock, whether or not the fleet is
/// short. This is the "players keep founding ships" half of a live server, and at this cadence
/// it is the main driver of hull churn.
#define GHOST_SUSTAIN_FOUND_EVERY (20 MINUTES)
/// First founding wave. After the fleet is up and rotating.
#define GHOST_SUSTAIN_FOUND_FIRST (12 MINUTES)
/// Hard ceiling on live player hulls. Founding waves may push the fleet above `ships_target`
/// transiently; without a ceiling the fleet would grow unbounded over three hours and the round
/// would stop being a seventy-player round at all.
#define GHOST_SHIPS_HARD_CAP 16
/// How often the sustain loop wipes a crew once the round is up to speed. ~20 wipes across
/// three hours, matching the elevated founding rate so the fleet churns rather than shrinks.
#define GHOST_SUSTAIN_WIPE_EVERY (8 MINUTES)
/// First wipe is held back this long, so the fleet is fully crewed and rotating before
/// anything starts killing it.
#define GHOST_SUSTAIN_WIPE_FIRST (15 MINUTES)
/// A worldgen burst this often. This is the repeated confirmation vehicle for the worldgen
/// queue-timeout fix: the SAME five-site composition that failed on the 70-minute run (2 ruins
/// + 2 fields + 1 planet) must come back 5/5 ok EVERY time. At this cadence a three-hour round
/// runs it about nine times instead of three.
#define GHOST_SUSTAIN_BURST_EVERY (20 MINUTES)
/// The first burst. Late enough that the launch phase's own burst and the twelve template loads
/// are finished and the world is at its steady-state site population.
#define GHOST_SUSTAIN_BURST_FIRST (12 MINUTES)
/// Any budget at or above this switches sustained mode on by itself.
#define GHOST_SUSTAIN_AUTO_MIN 100

/// The three regime names, as `ghost-round-regime` accepts them.
#define GHOST_REGIME_STRESS "stress"
#define GHOST_REGIME_ORDINARY "ordinary"
#define GHOST_REGIME_REAL "real"
/// `ghost-round-regime=ordinary` IS `ghost-round-churn-scale=3` - the ordinary regime has never
/// been anything else, and naming it does not change what it does.
#define GHOST_REGIME_ORDINARY_CHURN_SCALE 3

// ---------------------------------------------------------------------------------------
// THE REAL REGIME (`ghost-round-regime=real`)
//
// Cadences calibrated to production round-7 - median 70 concurrent players, peak 78,
// 2026-08-16, 143.9 minutes. It is the only measured round that sits AT this harness's own
// GHOST_CREW_DEFAULT of 70, so nothing below is pop-scaled; the report is explicit that these
// metrics do NOT scale linearly with headcount and that scaling the lower-pop rounds up to 70
// makes them look hotter than the actual 70-player round, which is the tell that the model is
// wrong. Source: scratchpad/real-round-churn-calibration.md, sections 2, 3 and 4.
//
//   hull foundings   12.1/h  (player-founded, median gap 2.6 min)  -> one hull every 5.0 min
//   hull losses      4.17/h  (crewless -> claimable)               -> one every 14.4 min
//   first hull loss  +76 min (round-7); the 30-minute SHIP_CREWLESS_ABANDON_TIME puts the
//                    actual crew death around +46 min
//   site loads       ~32.1/h CONTINUOUS - median inter-arrival 1.9 min, 69% of 5-minute
//                    windows carrying two or more, busiest window 4, only 2 of 29 empty
//   planet builds    5.0/h, inside that 32 - the rest are ruins, flat encounters and fields
//   deaths           28.4/h, latejoins 45.4/h (context; neither is a clock here)
//
// FOUNDINGS ARE SINGLES, NOT WAVES. founding_wave() already founds exactly one hull per fire,
// which is what a real server does - players press the button one at a time - so the real regime
// changes only how often it fires, never how much it founds at once.
// ---------------------------------------------------------------------------------------

/// Real regime: one hull founded every 5 minutes (12.1/h measured at 70 players).
#define GHOST_REAL_FOUND_EVERY (5 MINUTES)
/// First founding, once the launch phase has finished standing the fleet up.
#define GHOST_REAL_FOUND_FIRST (12 MINUTES)
/// Real regime: one crew wiped every 14.4 minutes (4.17 hull losses/h measured).
#define GHOST_REAL_WIPE_EVERY (864 SECONDS)
/// A real round has essentially NO hull losses in its first hour - round-7 logged its first at
/// +76 min, which is a crew that died around +46. GHOST_SUSTAIN_WIPE_FIRST's 15 minutes
/// front-loads attrition a real round does not have.
#define GHOST_REAL_WIPE_FIRST (45 MINUTES)

// ---------------------------------------------------------------------------------------
// THE SITE-LOAD TRICKLE
//
// The defect this replaces: in the legacy regimes every scheduled site load arrives as a 5-site
// burst inside one tick, then nothing for 20-60 minutes. Measured against three production
// rounds that shape is wrong in both directions - a real round never loads 5 sites in a tick
// (busiest 5-minute window across all three rounds: 6) and never goes quiet for twenty minutes
// (2 of round-7's 29 windows were empty). The burst design tests the worldgen queue's BURST
// tolerance well and its SUSTAINED tolerance badly, which is the wrong way round for a run whose
// deliverable is "does hour 3 look like hour 1".
//
// So in the real regime the sustain loop schedules the NEXT load on a randomized interval
// instead of firing waves:
//
//   90% of fires      one site
//    8% of fires      two sites in the same tick
//    2% of fires      three
//   95% of intervals  rand(70, 145) SECONDS
//    5% of intervals  rand(300, 540) SECONDS  - the occasional genuine lull
//
// DERIVATION. Two of round-7's reported shape statistics cannot both be true of any one process:
// a median inter-arrival of 1.9 min against a 32/h rate describes a nearly REGULAR stream (a
// median at or above the mean), while "69% of windows carry 2+, 6.9% empty" describes a
// dispersed one. They disagree because they are measured on different event sets - the ruin
// count is the report's one estimated component (observed "Space-Ruin ... loaded" lines x1.43),
// so the RATE is quoted for all 77 events while the window histogram and the inter-arrival
// median can only have been computed on the 61 events that actually carry timestamps.
//
// The parameters above were fitted on that reading and then verified by simulation (600+
// simulated rounds per candidate over a grid of ~700). The full stream delivers the true rate;
// thinned to the observed fraction (61/77 = 0.792) it reproduces every measured statistic:
//
//   statistic, on round-7's observed events    | round-7 | this distribution, thinned
//   ------------------------------------------ | ------- | --------------------------
//   loads/h                                    |  25.4   |  25.9
//   median inter-arrival                       |  1.90 m |  1.90 m
//   5-min windows with >= 2 loads              |   69%   |   73%
//   5-min windows empty                        |  6.9%   |  8.0%
//   busiest 5-min window                       |    4    |   4.6
//
// and the full stream itself runs at 32.6 loads/h (measured 32.1), median gap 1.75 min, busiest
// 5-minute window 5.3 - i.e. it never produces the 10-site tick the burst regimes do.
//
// SITE MIX. Weighted to round-7's own composition instead of the burst's fixed 2 ruins + 2
// fields + 1 planet: 16% planet, 6% asteroid field, 78% space ruin. At 32.6 loads/h that is
// 5.2 planet builds/h (measured 5.0), 2.0 fields/h (measured 1.7) and 25.5 ruins/h (measured
// 25.4 - round-7's 44 ruins plus its 17 flat "Empty Space"/"Crashed Ship" encounters, which are
// template loads into a lattice slot exactly as a ruin is and which this harness has no separate
// site kind for).
//
// CEILINGS AND TEARDOWN ARE NOT TOUCHED. The trickle decides only WHEN a load happens.
// site_cap_for() still decides whether there is room, sites are still released the way they
// always were - by a crew undocking - and a fire whose drawn kind is at its ceiling falls
// through to the other two kinds before giving up. Refusals are counted and reported, because
// "the trickle wanted to load and the ceiling said no" is precisely the measurement that tells
// the next run whether the ceilings or the release rate is the binding constraint on site
// volume.
// ---------------------------------------------------------------------------------------

/// Trickle interval, the common case, in seconds.
#define GHOST_REAL_TRICKLE_MIN 70
#define GHOST_REAL_TRICKLE_MAX 145
/// ...and the occasional lull, which is what puts empty 5-minute windows in the stream.
#define GHOST_REAL_TRICKLE_LULL_PCT 5
#define GHOST_REAL_TRICKLE_LULL_MIN 300
#define GHOST_REAL_TRICKLE_LULL_MAX 540
/// Percent of fires that place two sites at once, and three. Kept small on purpose: clusters
/// are what a burst regime has too much of, and every extra site in a cluster is a zero-length
/// inter-arrival that drags the median away from the measured 1.9 minutes.
#define GHOST_REAL_TRICKLE_PAIR_PCT 8
#define GHOST_REAL_TRICKLE_TRIPLE_PCT 2
/// Site mix, in percent. Ruins take whatever these two leave (78%).
#define GHOST_REAL_MIX_PLANET_PCT 16
#define GHOST_REAL_MIX_FIELD_PCT 6
/// How long a trickle worker waits for lattice capacity before dropping its load. A production
/// ship refused for capacity stays on the chart and re-asks indefinitely; the harness bounds
/// the wait so unmet demand is COUNTED (as a slot-wait timeout in the closing line) rather
/// than deferred into a pile of immortal waiters that would misreport the round's true rate.
#define GHOST_TRICKLE_SLOT_PATIENCE (15 MINUTES)
/// Retry cadence while waiting on capacity - roughly a ship's docking re-attempt cadence.
#define GHOST_TRICKLE_SLOT_RETRY (30 SECONDS)

/// Fallback paths when the launcher passed none.
#define GHOST_LOG_DEFAULT "data/ghost_round.log"
#define GHOST_DD_LOG "data/ghost_round_dd.log"
#define GHOST_POINTER "data/ghost_round_latest.txt"

/// Everything the sim crew is. One flat global so every shim has one list to consult and
/// the cost of consulting it is a single list walk.
GLOBAL_LIST_EMPTY(ghost_round_crew)
/// Set TRUE once the shims are meant to be live. Before this the world is booting and the
/// crew list is empty anyway, but an explicit latch keeps the shims free during init.
GLOBAL_VAR_INIT(ghost_round_active, FALSE)

// ---------------------------------------------------------------------------------------
// World-level overrides. These chain outside the upstream definitions.
// ---------------------------------------------------------------------------------------

/world/New()
	// Before ..(): the upstream body loads config, sets up logs and runs the whole of
	// Master.Initialize(). Everything any of that writes is invisible otherwise.
	ghost_round_preserve_previous_logs()
	world.log = file(GHOST_DD_LOG)
	..()
	// SetupLogs() reassigns world.log partway through the parent call. Take it back.
	world.log = file(GHOST_DD_LOG)

/**
 * A REBOOT IS A RUN-ENDING EVENT, NEVER A RESTART.
 *
 * Inherited wholesale from the churn soak, which lost seven hours of overnight data to an MC
 * recovery that called world.Reboot(): the profile at the end of the driver was jumped over,
 * a second round started on the same params and churned on top of the first, and everything
 * keyed on the round id was reopened from scratch. Write the profile off whatever the round
 * managed, flush, and take the world DOWN rather than bringing it back up.
 */
/world/Reboot(reason = 0, fast_track = FALSE)
	if(SSghost_round && SSghost_round.launched && !SSghost_round.profile_written)
		SSghost_round.ghost_log("=== GHOST ROUND: UNEXPECTED REBOOT ===")
		SSghost_round.ghost_log("world.Reboot(reason=[reason ? reason : "none"]) mid-round - almost always Master Controller recovery. Writing the profile off the minutes completed so far, then shutting down rather than letting a second round start on top of this one.")
		SSghost_round.ghost_log("world runtimes at reboot: [GLOB.total_runtimes]; last beat: [SSghost_round.progress_label]")
		SSghost_round.write_profile("world.Reboot() mid-round (MC recovery) - the hour was cut short here")
		// Never reach ..(). Every write above is synchronous (rustg_file_append), so a
		// shutdown with no sleep loses nothing, and a sleep that never resumes on a dead MC
		// would leave DreamDaemon alive and idle until the driver's timeout.
		qdel(world)
		return
	return ..()

/// Copies an existing transcript aside before this boot can touch it. Same insurance the
/// churn soak takes: a second boot on the same params must not be able to destroy the first
/// run's evidence even if the Reboot override above is somehow bypassed.
/proc/ghost_round_preserve_previous_logs()
	var/list/launch_params = world.params
	var/wanted = launch_params ? launch_params["ghost-round-log"] : null
	if(!istext(wanted) || !length(wanted))
		wanted = GHOST_LOG_DEFAULT
	for(var/path in list(wanted, GHOST_DD_LOG))
		if(!fexists(path))
			continue
		var/existing = rustg_file_read(path)
		if(!length(existing))
			continue
		for(var/attempt in 1 to 20)
			var/snapshot = "[path].prev[attempt]"
			if(fexists(snapshot))
				continue
			rustg_file_write(existing, snapshot)
			rustg_file_append("\[[time_stamp()]\] === a new world booted on this log path; the [length(existing)] bytes before this line were copied to [snapshot] ===\n", path)
			break

/world/RunUnattendedFunctions()
	..()
	ghost_round_arm_unattended()

/**
 * Turns a clientless world into one that will actually run a round.
 *
 * Same shape as setup_autowiki() and the churn soak, which are this codebase's own
 * headless-harness precedents: opt out of the post-init tick suspend, start the round without
 * waiting for players, and hang the work off the roundstart callback so it runs at
 * RUNLEVEL_GAME. SSlighting, SSweather, SSplanet_mobs and SSnpc_ships do not fire in the
 * lobby, and a round driven from the lobby would measure an empty machine.
 */
/proc/ghost_round_arm_unattended()
	// A clientless world SUSPENDS its tick after init; every sleep and timer here would
	// freeze at the first yield.
	Master.sleep_offline_after_initializations = FALSE
	// A playerless round declares itself over and reboots a few seconds later.
	SSticker.delay_end = TRUE
	SSticker.start_immediately = TRUE
	CONFIG_SET(number/round_end_countdown, 0)
	SSticker.OnRoundstart(CALLBACK(SSghost_round, TYPE_PROC_REF(/datum/controller/subsystem/ghost_round, arm)))

// ---------------------------------------------------------------------------------------
// Environment
//
// Deliberately almost empty, unlike the churn soak. The soak pins pirates to zero and turns
// roundstart planets off because it is measuring a lifecycle in isolation; this harness is
// measuring a ROUND, so the roundstart planet contacts, the pirate pool, the derelict sweep
// and the weather scheduler are all left exactly as a live server runs them.
// ---------------------------------------------------------------------------------------

/datum/controller/subsystem/profiler
	// The profiler is off by default (config flag/auto_profile). The harness turns it on
	// itself at arm time and dumps on its own schedule; leaving the subsystem's own 300s
	// fire on top of that would double the dumps and put profiler write cost in the middle
	// of the burst windows being measured.
	can_fire = FALSE

// ---------------------------------------------------------------------------------------
// The sim crew's kit
// ---------------------------------------------------------------------------------------

/**
 * What every sim crewmate wears.
 *
 * Sealed and on internals, because the scenario sends crews into space ruins and asteroid
 * fields as well as onto planet surfaces. Voidcrew planet ground is breathable
 * (OPENTURF_DEFAULT_ATMOS on dirt, grass and wasteland), so a suit is not needed there - but a
 * space ruin is vacuum, and an unsuited crew would asphyxiate inside two minutes and
 * hand the profile a dead round instead of a busy one. Players suit up for EVA; so does this
 * crew.
 *
 * `internals_slot` is the load-bearing line. /datum/outfit/space does NOT set it, so its
 * wearer is pressure-sealed and still suffocates - the tank is never opened. The suit-store
 * tank plus ITEM_SLOT_SUITSTORE is the combination that actually breathes.
 *
 * A KINETIC ACCELERATOR goes in the active hand, and it is not decoration. The first smoke run
 * put the crew down with a pickaxe and nothing else, and 100% of both landing parties were dead
 * inside four minutes - five of five on an ice planet, two of two on a lava planet. That is not
 * a realistic round, it is a measurement of respawn churn: the driver would have spent the hour
 * creating replacement crew and burying the memory figures under hundreds of corpses, and no
 * site would ever have held an occupied crew long enough to test anything. A real miner carries
 * a ranged weapon, and this one does too. No pickaxe: the mining path calls gets_drilled()
 * directly and needs no tool, and a free hand is what lets the accelerator be the active one.
 */
/datum/outfit/ghost_round_crew
	name = "Ghost Round Crew"
	uniform = /obj/item/clothing/under/color/grey
	shoes = /obj/item/clothing/shoes/sneakers/black
	suit = /obj/item/clothing/suit/space
	head = /obj/item/clothing/head/helmet/space
	mask = /obj/item/clothing/mask/breath
	glasses = /obj/item/clothing/glasses/meson
	back = /obj/item/storage/backpack
	suit_store = /obj/item/tank/internals/oxygen
	internals_slot = ITEM_SLOT_SUITSTORE

// ---------------------------------------------------------------------------------------
// OCCUPANCY SHIMS
//
// The sim's validity argument lives in this block. ~70 mobs with minds and no clients are
// invisible to every player-presence primitive, and left unshimmed the measured hour would be
// quiet in exactly the ways that matter: sites released under the crews standing on them,
// hulls force-undocked, fauna asleep, spawners idle, pirates unable to see a target.
//
// There are two families of primitive and they get two different treatments.
//
// FAMILY 1 - SSmobs.clients_by_zlevel. One root shim covers all of it.
//
//   /mob/living/update_z() (code/modules/mob/living/living.dm:1912) is the ONLY place that
//   list is written, and its whole gate is one line: `if(isnull(client)) ... return`. Shim
//   that one proc for sim crew and eight downstream gates become correct at once, each one
//   running its own unmodified production code against a correctly populated list:
//
//     * /datum/ai_controller/get_expected_ai_status()       - basic-mob AI wakes up
//     * /mob/living/simple_animal/hostile/ListTargetsLazy() - fauna can see the crew
//     * SSplanet_mobs.check_players()                       - planet fauna spawns and stays
//     * /datum/component/spawner's client gate               - dens and nests fire
//     * SSidlenpcpool.rebuild_client_pools()                 - idle animals wake
//     * turf_footprint_has_players()                         - ruins and fields do not unload
//     * /datum/weather/send_alert()                          - storm telegraphs reach the crew
//     * /datum/survey_datum living_player_count              - surveys read occupied sites
//
//   This was audited before it was used: every consumer of clients_by_zlevel in the tree was
//   read, and NONE of them dereferences `.client` on a member. They call QDELETED(), get_turf(),
//   get_dist(), to_chat(), SEND_SOUND() and playsound_local(), all of which are safe or
//   self-guarding on a clientless mob. There are also two in-tree precedents for writing that
//   list by hand: voidcrew/modules/npc_ships/code/admin_verbs.dm:165 and
//   code/modules/unit_tests/voidcrew_simple_mob_ai.dm:29.
//
// FAMILY 2 - GLOB.player_list. Shimmed one proc at a time, never by insertion.
//
//   GLOB.player_list is written only by /mob/proc/add_to_player_list(), whose second line is
//   an unguarded `client.holder` - it is a client-only list by construction, and putting a
//   clientless mob in it would runtime on the first read. So each consumer is chain-overridden
//   to return (original result) UNION (sim crew matching the same predicate), with the
//   predicate copied line for line from the parent.
//
// NOT shimmed, on purpose, and listed in the report as blind spots: anything whose only effect
// is chat, sound or admin messaging (ship_event_announce, venue_message, rad-storm end
// announcements), and the pirate raid's start_tracking_player_crew(), which feeds a
// "pirates win" tracker whose real verdict is computed elsewhere.
// ---------------------------------------------------------------------------------------

/**
 * FAMILY 1, the root shim: register sim crew in SSmobs.clients_by_zlevel.
 *
 * Mirrors /mob/living/update_z (code/modules/mob/living/living.dm:1912-1942) exactly - the
 * same de-registration, the same "last one out turns the AI off", the same "first one in wakes
 * the AI up" - with two differences, both forced:
 *
 * 1. The `if(isnull(client))` bail is dropped for sim crew. That is the entire point.
 * 2. A null `new_z` is re-derived from the mob's own turf. /mob/living/Life() (life.dm:37-39)
 *    calls `update_z(null)` on any clientless mob holding a z-registration, every single
 *    SSmobs tick - it exists to clean up exactly the state this shim creates deliberately.
 *    Re-deriving keeps a crewmate standing on a turf registered, and still de-registers one
 *    that is genuinely nowhere (dead in nullspace, mid-teardown), because get_turf() returns
 *    null for those and new_z stays null.
 *
 * Non-sim mobs take the parent unchanged, so real clients and ordinary fauna are untouched.
 * The membership test is an assoc lookup rather than a list scan because this proc runs on
 * every z change of every living mob in the world.
 */
/mob/living/update_z(new_z)
	if(!GLOB.ghost_round_active || !GLOB.ghost_round_crew[src])
		return ..()

	if(isnull(new_z))
		var/turf/standing_on = get_turf(src)
		new_z = standing_on ? standing_on.z : null

	if(registered_z == new_z)
		return
	if(registered_z && registered_z <= length(SSmobs.clients_by_zlevel))
		SSmobs.clients_by_zlevel[registered_z] -= src

	// Parent's shape: how many were left on the level we are leaving, excluding us - we are
	// already out of the list by this point.
	var/old_level_new_clients = (registered_z && registered_z <= length(SSmobs.clients_by_zlevel)) ? length(SSmobs.clients_by_zlevel[registered_z]) : null
	if(registered_z && old_level_new_clients == 0)
		for(var/datum/ai_controller/controller as anything in GLOB.ai_controllers_by_zlevel[registered_z])
			controller.set_ai_status(AI_STATUS_OFF)

	if(new_z && new_z <= length(SSmobs.clients_by_zlevel))
		var/new_level_old_clients = length(SSmobs.clients_by_zlevel[new_z])
		SSmobs.clients_by_zlevel[new_z] += src
		if(new_level_old_clients == 0)
			for(var/datum/ai_controller/controller as anything in GLOB.ai_controllers_by_zlevel[new_z])
				controller.set_ai_status(controller.get_expected_ai_status())

	registered_z = new_z

/**
 * FAMILY 2 shim: get_event_crew().
 *
 * Production predicate (voidcrew/modules/dynamic_events/ship_event_helpers.dm:16): member of
 * GLOB.player_list, isliving(), stat != DEAD, and get_area() is in shuttle.shuttle_areas.
 * Mirrored below with GLOB.player_list swapped for the sim crew and nothing else changed.
 *
 * This is the highest-consequence shim in the file. SSovermap.sweep_derelicts() reads
 * occupancy once a minute through has_active_crew(), whose first clause is this proc; without
 * the shim every one of the twelve hulls is abandoned after SHIP_CREWLESS_ABANDON_TIME and
 * despawned twenty minutes later, taking its crew, its map zone and its berth with it. The
 * predicate's second clause (roster alive on the hull's z) never fires for sim crew - they
 * carry no client - so this shim alone is what keeps the fleet crewed. It is also what the
 * whole dynamic-events family counts through crewed_ship_count().
 */
/obj/structure/overmap/ship/get_event_crew()
	. = ..()
	if(!GLOB.ghost_round_active || !shuttle || !shuttle.shuttle_areas)
		return
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(QDELETED(sim))
			continue
		if(!isliving(sim))
			continue
		if(sim.stat == DEAD)
			continue
		var/area/mob_area = get_area(sim)
		if(mob_area && (mob_area in shuttle.shuttle_areas))
			. |= sim

/**
 * FAMILY 2 shim: site_has_living_players().
 *
 * Production predicate (voidcrew/modules/overmap/code/modules/overmap/ship.dm:1435): resolve
 * the site's z values and XY rectangle from the site's own map footprint (every site kind
 * answers with one now, via get_interior_footprint()) - then look for a member of
 * GLOB.player_list that is living, not dead, and standing inside it.
 *
 * The parent is called FIRST and short-circuits on TRUE, so a real client is still the fast
 * answer; only when the production scan comes back empty is the sim crew walked against the
 * identical geometry, which is resolved by the shared helper below rather than by a second
 * copy of the branch ladder.
 *
 * Consequence of getting this wrong: SSovermap's check_dead_site_undock() reads every berthed
 * hull as parked at a dead site and force-undocks it after SHIP_SITE_DEAD_UNDOCK_TIME, so no
 * crew ever stays anywhere and the concurrency targets are unreachable.
 */
/obj/structure/overmap/ship/site_has_living_players(obj/structure/overmap/site)
	if(..())
		return TRUE
	if(!GLOB.ghost_round_active)
		return FALSE
	var/list/bounds = ghost_round_site_bounds(site)
	if(!bounds)
		return FALSE
	var/list/site_z_values = bounds["z"]
	var/bounded = bounds["bounded"]
	var/min_x = bounds["min_x"]
	var/min_y = bounds["min_y"]
	var/max_x = bounds["max_x"]
	var/max_y = bounds["max_y"]
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(QDELETED(sim) || !isliving(sim) || sim.stat == DEAD)
			continue
		// get_turf() rather than the mob's own z, exactly as the parent does: a mob inside a
		// locker, a mech or a bodybag reads z 0 off itself.
		var/turf/sim_turf = get_turf(sim)
		if(!sim_turf)
			continue
		if(!(sim_turf.z in site_z_values))
			continue
		if(bounded && (sim_turf.x < min_x || sim_turf.x > max_x || sim_turf.y < min_y || sim_turf.y > max_y))
			continue
		return TRUE
	return FALSE

/**
 * The geometry half of site_has_living_players(), lifted from the parent so the shim cannot
 * drift from it. Returns null when the site has no interior to stand in - which the parent
 * treats as "empty", not as "blocking", and so does the caller above.
 */
/obj/structure/overmap/ship/proc/ghost_round_site_bounds(obj/structure/overmap/site)
	var/list/site_z_values
	var/min_x = 0
	var/min_y = 0
	var/max_x = 0
	var/max_y = 0
	var/bounded = FALSE
	// Branch ladder lifted verbatim from the parent (ship.dm:1445-1460) so the shim cannot
	// drift from it. Every site with an interior now answers with a map footprint - space
	// ruins and asteroid fields moved off private turf reservations onto the slot lattice
	// with everything else, so there is no reservation branch left to write here. A planet
	// with a map zone but no footprint (allocated outside the slot register) still answers
	// with its whole level.
	var/datum/map_footprint/site_footprint = site?.get_interior_footprint()
	if(site_footprint && !isnull(site_footprint.low_x) && site_footprint.z_value)
		min_x = site_footprint.low_x
		min_y = site_footprint.low_y
		max_x = site_footprint.high_x
		max_y = site_footprint.high_y
		site_z_values = list(site_footprint.z_value)
		bounded = TRUE
	else if(istype(site, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet_site = site
		if(planet_site.mapzone)
			site_z_values = list()
			for(var/datum/space_level/zlevel as anything in planet_site.mapzone.z_levels)
				site_z_values += zlevel.z_value

	if(!length(site_z_values))
		return null
	return list("z" = site_z_values, "bounded" = bounded, "min_x" = min_x, "min_y" = min_y, "max_x" = max_x, "max_y" = max_y)

/**
 * FAMILY 2 shim: despawn_derelict()'s "anybody aboard" refusal.
 *
 * Production predicate (ship.dm:1292): any member of GLOB.player_list that isliving() and
 * is_aboard(). Deliberately MORE generous than get_event_crew - dead bodies count too, because
 * a corpse with a player behind it may be mid-rescue.
 *
 * Two things go wrong without this shim, and the second is worse than the first. A hull with
 * crew aboard would despawn; and the terminal loop of the production body (ship.dm:1347-1355)
 * walks every turf of the hull and ghostize()s then qdel()s every living mob it finds, on the
 * reasoning that nothing with a player behind it could have got that far. Seventy sim crew
 * would be deleted mid-round by the code whose guard was supposed to stop it.
 *
 * The scripted attrition phase still drives real despawns - it wipes the crew FIRST, so the
 * predicate is honestly false by the time the pipeline runs.
 */
/obj/structure/overmap/ship/despawn_derelict()
	if(GLOB.ghost_round_active)
		for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
			if(QDELETED(sim) || !isliving(sim))
				continue
			if(is_aboard(sim))
				return FALSE
	return ..()

/**
 * FAMILY 2 shim: /datum/map_footprint/has_living_players().
 *
 * Production predicate (voidcrew/datums/map_footprint.dm:194): GLOB.player_list, isliving(),
 * stat != DEAD, contains_turf(). The footprint's sibling get_mind_mobs() is MIND-based and
 * already sees the sim crew unshimmed - this is the client-based one next to it, and shimming
 * both keeps the pair answering the same question about the same people.
 */
/datum/map_footprint/has_living_players()
	. = ..()
	if(. || !GLOB.ghost_round_active)
		return .
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(QDELETED(sim) || !isliving(sim) || sim.stat == DEAD)
			continue
		if(contains_turf(get_turf(sim)))
			return TRUE
	return FALSE

/**
 * FAMILY 2 shim: the pirate AI's headcount of a target hull.
 *
 * Production predicate (voidcrew/modules/npc_ships/code/npc_ship_controller.dm:1171): members
 * of GLOB.player_list that are not DEAD, are carbon or silicon, and whose area is one of the
 * target's shuttle areas.
 *
 * This is the LAST filter in scan_threats (ship_combat_behaviors.dm:56), and it rejects on zero
 * rather than on -1 - so without this shim every pirate in the world scans every sim hull,
 * decides its crew is dead, and moves on. No engagements, no boarding raids, no hull kills, and
 * the combat half of the scenario measures nothing. Everything upstream of it - the distance,
 * zone, line-of-sight and tribute checks - is left to run untouched, so the pirates still pick
 * their targets for their own reasons.
 */
/datum/ai_controller/npc_ship/count_living_crew(obj/structure/overmap/ship/target)
	. = ..()
	if(!GLOB.ghost_round_active || . < 0)
		return .
	if(!target || !target.shuttle || !target.shuttle.shuttle_areas)
		return .
	var/list/shuttle_areas = target.shuttle.shuttle_areas
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(QDELETED(sim) || sim.stat == DEAD)
			continue
		if(!iscarbon(sim) && !issilicon(sim))
			continue
		var/area/crew_area = get_area(sim)
		if(!crew_area || !shuttle_areas[crew_area])
			continue
		.++

// ---------------------------------------------------------------------------------------
// SSghost_sampler - the one-second series
//
// The production perf CSV is the primary time-dilation record and is left alone, but
// SStime_track fires every ten seconds, and an asteroid field generates in about thirty.
// Three rows is not a measurement of a burst. This subsystem writes a parallel CSV at 1 Hz
// and keeps four of its columns in memory as flat parallel lists, so the final profile can cut
// the series to a named load window and compare it against the surrounding steady state.
//
// Cheap on purpose: list lengths, four world vars, one rustg_file_append. Its own cost is
// measured and reported next to the driver's.
// ---------------------------------------------------------------------------------------

SUBSYSTEM_DEF(ghost_sampler)
	name = "Ghost Sampler"
	wait = GHOST_SAMPLE_PERIOD
	priority = FIRE_PRIORITY_DEFAULT
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	flags = SS_BACKGROUND | SS_POST_FIRE_TIMING

	/// Where the 1 Hz CSV goes.
	var/csv_path = "data/ghost_round_ticks.csv"
	/// TRUE once the header has been written.
	var/header_written = FALSE
	/// Time dilation is a DELTA measurement; these hold the previous sample's clocks.
	var/last_realtime = 0
	var/last_byondtime = 0
	/// The in-memory series the profile cuts windows out of. Flat parallel lists rather than a
	/// list of assoc lists: 4200 samples of an hour is 4200 tiny lists otherwise, and the
	/// harness has no business allocating that against a memory measurement.
	var/list/sample_time = list()
	var/list/sample_td = list()
	var/list/sample_cpu = list()
	var/list/sample_tick = list()
	/// Rolling accumulators the driver reads for its per-phase summary, reset at each phase.
	var/phase_label = "boot"
	/// Cost of the harness itself, in milliseconds, accumulated across the run.
	var/sampler_cost_ms = 0
	var/crew_cost_ms = 0

/datum/controller/subsystem/ghost_sampler/fire(resumed = FALSE)
	var/timer = TICK_USAGE_REAL

	var/current_realtime = REALTIMEOFDAY
	var/current_byondtime = world.time

	// The SStime_track formula (code/controllers/subsystem/time_track.dm:100), applied over a
	// one-second window instead of a ten-second one. Same definition of drift, finer cut.
	var/td = 0
	if(last_realtime)
		var/real_delta = current_realtime - last_realtime
		var/byond_delta = current_byondtime - last_byondtime
		var/ticks_elapsed = byond_delta / world.tick_lag
		if(ticks_elapsed > 0)
			var/tick_drift = max(0, (real_delta - byond_delta) / world.tick_lag)
			td = tick_drift / ticks_elapsed * 100
	last_realtime = current_realtime
	last_byondtime = current_byondtime

	var/cpu = world.cpu
	var/tick_usage = world.tick_usage

	sample_time += current_byondtime
	sample_td += td
	sample_cpu += cpu
	sample_tick += tick_usage

	if(!header_written)
		header_written = TRUE
		rustg_file_write("time,phase,td_pct,cpu,map_cpu,tick_usage,timers,maxz,map_zones,slots_used,mobs,alive,dead,crew_alive,crew_dead,ships,npc_ships,planets_live,ruins_live,fields_live,crash_sites,arenas,air_active,air_cost,gc_queue,ai_on\n", csv_path)

	var/list/live = SSghost_round ? SSghost_round.live_site_counts() : list("planet" = 0, "ruin" = 0, "field" = 0, "crash" = 0, "arena" = 0)
	var/crew_alive = 0
	var/crew_dead = 0
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(QDELETED(sim))
			continue
		if(sim.stat == DEAD)
			crew_dead++
		else
			crew_alive++

	var/slots_used = 0
	for(var/datum/map_zone/zone as anything in SSovermap.map_zones)
		if(QDELETED(zone))
			continue
		slots_used += zone.used_slot_count()

	var/gc_queued = 0
	if(SSgarbage.queues)
		for(var/list/queue in SSgarbage.queues)
			gc_queued += length(queue)

	rustg_file_append("[current_byondtime],[phase_label],[td],[cpu],[world.map_cpu],[tick_usage],[length(SStimer.timer_id_dict)],[world.maxz],[length(SSovermap.map_zones)],[slots_used],[length(GLOB.mob_list)],[length(GLOB.alive_mob_list)],[length(GLOB.dead_mob_list)],[crew_alive],[crew_dead],[length(SSovermap.simulated_ships)],[length(SSnpc_ships.active_ships)],[live["planet"]],[live["ruin"]],[live["field"]],[live["crash"]],[live["arena"]],[length(SSair.active_turfs)],[SSair.cost_turfs],[gc_queued],[length(GLOB.ai_controllers_by_status[AI_STATUS_ON])]\n", csv_path)

	sampler_cost_ms += TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer)

/**
 * avg / p95 / max of one of the in-memory series across [from_time, to_time] in world.time.
 * Returns an assoc list, or null when the window caught no samples.
 *
 * p95 by sorted index rather than by interpolation: the series is one sample a second and the
 * question being asked is "how bad did it get, ignoring the single worst spike", which the
 * nearest-rank definition answers honestly and cheaply.
 */
/datum/controller/subsystem/ghost_sampler/proc/window_stats(from_time, to_time, list/series)
	var/list/picked = list()
	for(var/index in 1 to length(sample_time))
		var/stamp = sample_time[index]
		if(stamp < from_time)
			continue
		if(stamp > to_time)
			break
		picked += series[index]
	if(!length(picked))
		return null
	sortTim(picked, GLOBAL_PROC_REF(cmp_numeric_asc))
	var/total = 0
	for(var/value in picked)
		total += value
	var/p95_index = max(1, round(length(picked) * 0.95))
	return list(
		"n" = length(picked),
		"avg" = total / length(picked),
		"p95" = picked[p95_index],
		"max" = picked[length(picked)],
	)

/// Share of samples in a window whose time dilation is at or above `threshold` percent.
/// The three thresholds the profile reports (5, 25, 100) are the 1.05x, 1.25x and 2.0x glide
/// multipliers - see the header note on how TD maps onto glide.
/datum/controller/subsystem/ghost_sampler/proc/window_td_share(from_time, to_time, threshold)
	var/counted = 0
	var/over = 0
	for(var/index in 1 to length(sample_time))
		var/stamp = sample_time[index]
		if(stamp < from_time)
			continue
		if(stamp > to_time)
			break
		counted++
		if(sample_td[index] >= threshold)
			over++
	if(!counted)
		return -1
	return over / counted * 100

// ---------------------------------------------------------------------------------------
// SSghost_crew - the crew driver
//
// Seventy human mobs with no clients do nothing on their own: a player-type mob has no
// ai_controller and never gets one. Something has to make them act, and the choice of WHAT is
// a measurement decision, not a convenience one.
//
// A real /datum/ai_controller per crewmate was considered and rejected. The only carbon-capable
// controllers in the tree are the monkey family (five subtrees, oview() target scans) and the
// lich thrall; SSai_behaviors runs at 10 Hz, so 70 monkey controllers would have become the
// largest single line in the profile and the round would have measured the harness. This
// driver instead does what a player does - step, swing, dig - at a deliberate player's rate of
// one action every two seconds, and its own cost is measured (crew_cost_ms) and reported
// beside the sampler's so the reader can subtract it.
//
// What is NOT approximated: the crew's actions go through the production chains. step() runs
// /mob/living/Move() with its atmos, area and lighting consequences; ClickOn() runs the real
// attack chain with its cooldowns; gets_drilled() is the proc a pickaxe click ends at. The
// fauna fighting back are ordinary ai_controller mobs woken by the FAMILY 1 shim, so the combat
// load on the other side of every exchange is completely real.
// ---------------------------------------------------------------------------------------

SUBSYSTEM_DEF(ghost_crew)
	name = "Ghost Crew"
	wait = GHOST_CREW_TICK
	priority = FIRE_PRIORITY_NPC
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	flags = SS_BACKGROUND | SS_POST_FIRE_TIMING | SS_NO_INIT

	var/list/currentrun = list()
	/// Actions taken, by kind, for the profile.
	var/list/action_tally = list("step" = 0, "attack" = 0, "mine" = 0, "flee" = 0)
	/// crewmate -> the mineral wall they are walking to. Holding a target is what turns
	/// wandering into mining; see drive_crewmate().
	var/list/mining_targets = list()

/datum/controller/subsystem/ghost_crew/fire(resumed = FALSE)
	if(!GLOB.ghost_round_active)
		return
	var/timer = TICK_USAGE_REAL
	if(!resumed)
		currentrun = GLOB.ghost_round_crew.Copy()

	while(length(currentrun))
		var/mob/living/carbon/human/crewmate = currentrun[length(currentrun)]
		currentrun.len--
		if(QDELETED(crewmate) || crewmate.stat == DEAD)
			continue
		drive_crewmate(crewmate)
		if(MC_TICK_CHECK)
			break

	SSghost_sampler.crew_cost_ms += TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer)

/**
 * One crewmate's turn. Strict priority order, cheapest test first, exactly one action.
 *
 * The order is the one a player uses: stay alive, hit what is hitting you, work the thing you
 * came here for, otherwise move. Everything below routes through a production proc.
 */
/datum/controller/subsystem/ghost_crew/proc/drive_crewmate(mob/living/carbon/human/crewmate)
	var/turf/here = get_turf(crewmate)
	if(!here)
		return

	// 1. Flee when hurt. A player runs; so does this. Running is a step AWAY from the nearest
	//    hostile, which is also what makes fauna chase and keeps the combat moving.
	//
	//    The threshold is 65%, not the 40% this started at. The smoke run measured six crew
	//    deaths in the first four minutes on the surface, which is not a realism win: a real
	//    miner has armour, a ranged weapon and a medkit, and this crew has a pickaxe. At 40%
	//    they stood and traded blows with goliaths and lost, and a round where the entire
	//    landing party is replaced every few minutes measures crew RESPAWN churn instead of
	//    crew activity - and buries the memory figures under hundreds of corpses. Backing off
	//    earlier is the cheapest way to model the equipment they are not carrying.
	var/mob/living/threat = nearest_hostile(crewmate, here)
	if(threat && crewmate.health < crewmate.maxHealth * 0.65)
		step_away(crewmate, threat, 4)
		action_tally["flee"]++
		return

	// 2. Shoot it, through the real click chain. ClickOn() resolves the active hand: with a
	//    kinetic accelerator in it that is a ranged shot at anything in the driver's 4-tile
	//    awareness radius, and an unarmed swing if the crewmate has somehow lost the weapon.
	//    ClickOn() self-rate-limits on next_move and next_click, so calling it every tick is
	//    free when it is on cooldown - exactly how a player holding down the trigger behaves.
	if(threat)
		crewmate.set_combat_mode(TRUE)
		crewmate.ClickOn(threat)
		action_tally["attack"]++
		return

	// 3. Mine.
	//
	//    A miner walks TO the rock. The first smoke run drilled exactly one wall in eight
	//    minutes because the driver only checked the eight tiles it was already standing next
	//    to and otherwise wandered at random - so the crews spent the round strolling past ore
	//    they never touched, and the mining half of the scenario measured nothing. Now each
	//    crewmate holds a target rock and walks to it.
	//
	//    The scan is the expensive part, so it is paid for rarely: only when the crewmate has
	//    no target, and only on a minority of those ticks. Seventy crew scanning 49 turfs every
	//    tick would put the harness at the top of its own profile.
	var/turf/closed/mineral/target_rock = mining_targets[crewmate]
	// The z check is not paranoia: a crewmate is recalled to their hull and flown to another
	// site while still holding a rock from the last one, and step_towards() to a turf on a
	// different z-level moves them nowhere at all. Without this they would stand still for the
	// rest of the round, mining nothing and generating no movement either.
	if(QDELETED(target_rock) || !ismineralturf(target_rock) || target_rock.z != here.z)
		mining_targets -= crewmate
		target_rock = null
		if(prob(35))
			for(var/turf/closed/mineral/candidate in RANGE_TURFS(3, here))
				target_rock = candidate
				mining_targets[crewmate] = candidate
				break

	if(target_rock)
		if(get_dist(crewmate, target_rock) <= 1)
			// gets_drilled() rather than a pickaxe attackby(): attackby routes through
			// use_tool(), which SLEEPS for the tool delay, and a sleeping subsystem fire is not
			// something to put inside a tick-usage measurement. The dig delay is wall-clock time
			// the PLAYER pays, not work the SERVER does - the server-side cost of mining is
			// exactly what gets_drilled() does (spawn the ore stack and the boulder, fire
			// COMSIG_MOB_MINED, ScrapeAway the turf), and that is what runs here. exp_multiplier
			// 1 so the mining skill path runs too; the crew have minds, so its unguarded mind
			// deref is safe.
			target_rock.gets_drilled(crewmate, 1)
			mining_targets -= crewmate
			action_tally["mine"]++
			return
		step_towards(crewmate, target_rock)
		action_tally["step"]++
		return

	// 4. Wander. A plain step through /mob/living/Move(), which is the whole point - the
	//    per-move cost of area entry, atmos and lighting is a real share of a busy round.
	step(crewmate, pick(GLOB.cardinals))
	action_tally["step"]++

/**
 * The nearest living hostile within a short radius, or null.
 *
 * view() is deliberately not used: it is one of the most expensive things a busy tick can do,
 * and doing it seventy times every two seconds would put the harness at the top of the profile.
 * A range-limited turf walk over a radius of 4 is a fraction of the cost and answers the only
 * question the driver asks - "is something here trying to kill me".
 */
/datum/controller/subsystem/ghost_crew/proc/nearest_hostile(mob/living/carbon/human/crewmate, turf/here)
	var/mob/living/closest
	var/closest_dist = 99
	for(var/mob/living/candidate in range(4, here))
		if(candidate == crewmate || QDELETED(candidate) || candidate.stat == DEAD)
			continue
		// Never each other: sim crew brawling in a corridor is not the load being modelled.
		if(GLOB.ghost_round_crew[candidate])
			continue
		if(!candidate.faction || (FACTION_STATION in candidate.faction))
			continue
		var/dist = get_dist(crewmate, candidate)
		if(dist < closest_dist)
			closest = candidate
			closest_dist = dist
	return closest

// ---------------------------------------------------------------------------------------
// SSghost_round - the driver
// ---------------------------------------------------------------------------------------

SUBSYSTEM_DEF(ghost_round)
	name = "Ghost Round"
	flags = SS_NO_FIRE

	var/log_path = GHOST_LOG_DEFAULT
	var/budget_min = GHOST_BUDGET_MIN_DEFAULT
	var/ships_target = GHOST_SHIPS_DEFAULT
	var/crew_target = GHOST_CREW_DEFAULT
	var/smoke = FALSE
	/// Loop the peak/attrition dynamics for the whole budget instead of running the 70-minute
	/// script once. Set by `ghost-round-sustain`, or implied by a budget over GHOST_SUSTAIN_AUTO_MIN.
	var/sustain = FALSE
	/// Which cadence regime the sustain loop runs (`ghost-round-regime`). See the CHURN REGIMES
	/// block. Defaults to stress so a run with no flag is byte-for-byte the behaviour runs 1-4
	/// were measured on.
	var/regime = GHOST_REGIME_STRESS
	/// Multiplier on the LEGACY regimes' cadences (`ghost-round-churn-scale`): the four sustain
	/// clocks - founding, wipe, burst and, since the calibration pass, the mission-rotation dwell.
	/// 1 is the stress regime the GHOST_SUSTAIN_* defines encode, 3 is the ordinary regime. The
	/// real regime does not use it at all; its cadences are absolute measured numbers.
	var/churn_scale = 1
	/// Set when churn_scale came off the command line, so `ghost-round-regime=ordinary` can supply
	/// its default of 3 without ever overwriting a number the operator asked for.
	var/churn_scale_explicit = FALSE
	/// Trickle bookkeeping (real regime only), reported in the closing beat: how many times the
	/// scheduler fired, how many site loads it dispatched, and how many it had to drop because
	/// every kind was at its concurrency ceiling.
	var/trickle_fires = 0
	var/trickle_dispatched = 0
	var/trickle_ceiling_skips = 0
	/// Slot-availability waits (real regime): how many trickle workers had to wait for lattice
	/// capacity, the seconds they spent waiting in total, and how many exhausted their patience
	/// and dropped the load. Together with trickle_ceiling_skips these account for every load
	/// the regime wanted but the world did not immediately take - the run's unmet-demand meter.
	var/trickle_slot_waits = 0
	var/trickle_slot_wait_secs = 0
	var/trickle_slot_timeouts = 0
	/// Trickle loads dispatched and not yet finished, by kind. Counted against the ceiling
	/// alongside the live count: the workers are async, so without this two of them can both pass
	/// a ceiling check that only one of them had room for.
	var/list/trickle_inflight = list("planet" = 0, "ruin" = 0, "field" = 0)
	/// world.time of the last replacement hull founded, for the rate cap.
	var/last_refound = 0
	/// Hulls whose crew were deliberately wiped. They are handed to the derelict pipeline and
	/// must never be re-crewed by the replenisher on the way out, or the wipe never takes.
	var/list/wiped_hulls = list()
	/// Replenishment tallies for the profile.
	var/hulls_refounded = 0
	var/crew_replaced = 0
	/// Purchasable hull classes, ordered cheap/expensive alternating. See build_hull_rotation().
	var/list/hull_rotation = list()
	var/rotation_index = 0
	/// class name -> assoc of "founded"/"killed"/"despawned". Proves class coverage.
	var/list/class_tally = list()
	/// Cumulative churn counters, snapshotted into every bucket so the hour trend can diff them.
	var/site_loads = 0
	var/site_teardowns = 0
	var/hulls_founded_total = 0
	/// Sites seen loaded on the previous keeper pass, for teardown detection.
	var/list/loaded_last_pass = list()

	var/launched = FALSE
	var/profile_written = FALSE
	var/started_realtime = 0
	var/started_worldtime = 0
	var/progress_stamp = 0
	var/progress_label = "not started"
	var/running = FALSE

	/// The fleet. Player hulls only - SSovermap.simulated_ships also holds the pirates.
	var/list/player_ships = list()
	/// Sites the driver stood up, by kind. Entries can go stale (a site can release itself),
	/// so every read filters QDELETED.
	var/list/site_planets = list()
	var/list/site_ruins = list()
	var/list/site_fields = list()
	/// The ascension arena run, if one opened.
	var/datum/vestige_ascension_run/arena

	/// One entry per site load: assoc of kind, label, z, start, end, duration, burst.
	var/list/load_windows = list()
	/// Named bursts: assoc of label, start, end, planned count, actual count.
	var/list/burst_windows = list()
	/// The narrative. One line per scripted beat, so the hour can be reconstructed.
	var/list/timeline = list()
	/// Per-bucket rows for the final profile.
	var/list/buckets = list()
	/// Hull kills observed, whether scripted or emergent.
	var/hull_kills = 0
	var/crews_wiped = 0
	var/ships_despawned = 0
	/// Per-ship dwell bookkeeping so the report can say where crews actually were.
	var/list/ship_missions = list()

/datum/controller/subsystem/ghost_round/Initialize()
	resolve_params()
	// Belt and braces: RunUnattendedFunctions() sets this too, but a suspended tick is the
	// failure mode that produces no output at all.
	Master.sleep_offline_after_initializations = FALSE
	ghost_log("=== GHOST ROUND: boot ===")
	ghost_log("scenario=[smoke ? "SMOKE" : "FULL"] ships=[ships_target] crew=[crew_target] budget=[budget_min]min regime=[regime][regime == GHOST_REGIME_REAL ? "" : " churn_scale=[churn_scale]"]")
	ghost_log("byond=[world.byond_version].[world.byond_build] maxz_at_boot=[world.maxz] tick_lag=[world.tick_lag]")
	ghost_log("NOTE: DM cannot construct a /client. Every per-client cost - SendMaps, view() computation, statpanel updates - is ABSENT from this run. The perf CSV's maptick column staying near zero is the proof.")
	INVOKE_ASYNC(src, PROC_REF(arm_fallback))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/ghost_round/proc/resolve_params()
	var/list/launch_params = world.params
	var/wanted = launch_params ? launch_params["ghost-round-log"] : null
	if(istext(wanted) && length(wanted))
		log_path = wanted
	var/wanted_budget = launch_params ? launch_params["ghost-round-budget-min"] : null
	if(istext(wanted_budget) && text2num(wanted_budget) >= 1)
		budget_min = round(text2num(wanted_budget))
	var/wanted_ships = launch_params ? launch_params["ghost-round-ships"] : null
	if(istext(wanted_ships) && text2num(wanted_ships) >= 1)
		ships_target = round(text2num(wanted_ships))
	var/wanted_crew = launch_params ? launch_params["ghost-round-crew"] : null
	if(istext(wanted_crew) && text2num(wanted_crew) >= 1)
		crew_target = round(text2num(wanted_crew))
	var/wanted_smoke = launch_params ? launch_params["ghost-round-smoke"] : null
	if(istext(wanted_smoke) && length(wanted_smoke))
		smoke = (text2num(wanted_smoke) ? TRUE : FALSE)
	// Any long budget is a sustained round by default: the one-shot script has nothing to do
	// after its attrition phase, and two silent hours would measure an empty machine.
	sustain = (budget_min >= GHOST_SUSTAIN_AUTO_MIN)
	var/wanted_sustain = launch_params ? launch_params["ghost-round-sustain"] : null
	if(istext(wanted_sustain) && length(wanted_sustain))
		sustain = (text2num(wanted_sustain) ? TRUE : FALSE)
	var/wanted_churn = launch_params ? launch_params["ghost-round-churn-scale"] : null
	if(istext(wanted_churn) && text2num(wanted_churn) > 0)
		churn_scale = text2num(wanted_churn)
		churn_scale_explicit = TRUE
	// Regime last, so it can supply a churn_scale default without stepping on an explicit one.
	// An unrecognised name is NOT silently coerced: a typo that quietly ran the default regime
	// would produce a run labelled `real` in the report and stress cadences in the data.
	var/wanted_regime = launch_params ? launch_params["ghost-round-regime"] : null
	if(istext(wanted_regime) && length(wanted_regime))
		switch(lowertext(wanted_regime))
			if(GHOST_REGIME_REAL)
				regime = GHOST_REGIME_REAL
			if(GHOST_REGIME_ORDINARY)
				regime = GHOST_REGIME_ORDINARY
			if(GHOST_REGIME_STRESS)
				regime = GHOST_REGIME_STRESS
			else
				ghost_log("WARN: unknown ghost-round-regime '[wanted_regime]' - staying on '[regime]'. Valid: [GHOST_REGIME_STRESS], [GHOST_REGIME_ORDINARY], [GHOST_REGIME_REAL].")
	if(regime == GHOST_REGIME_ORDINARY && !churn_scale_explicit)
		churn_scale = GHOST_REGIME_ORDINARY_CHURN_SCALE
	rustg_file_write("[log_path]\n", GHOST_POINTER)
	SSghost_sampler.csv_path = "[replacetext(log_path, ".log", "")]_ticks.csv"

/// One transcript line. rustg_file_append rather than world.log: the shell script polls this
/// file, and world.log is fought over by SetupLogs().
/datum/controller/subsystem/ghost_round/proc/ghost_log(text)
	rustg_file_append("\[[time_stamp()]\] [text]\n", log_path)
	log_world("GHOST ROUND: [text]")

/// A scripted beat. Every one of these is a line the timeline can be reconstructed from, and
/// the shell driver echoes the most recent one so a long run is not silent.
/datum/controller/subsystem/ghost_round/proc/beat(text)
	var/stamp = elapsed_min()
	timeline += "T+[stamp]m [text]"
	ghost_log("BEAT T+[stamp]m [text]")

/datum/controller/subsystem/ghost_round/proc/mark_progress(label)
	progress_stamp = world.time
	progress_label = label

/// Minutes since the round was armed, to one decimal place.
/datum/controller/subsystem/ghost_round/proc/elapsed_min()
	if(!started_worldtime)
		return 0
	return round((world.time - started_worldtime) / 60) / 10

/// Deciseconds of round budget left.
/datum/controller/subsystem/ghost_round/proc/budget_left()
	if(!started_worldtime)
		return budget_min MINUTES
	return (started_worldtime + (budget_min MINUTES)) - world.time

// ---------------------------------------------------------------------------------------
// Launch
// ---------------------------------------------------------------------------------------

/datum/controller/subsystem/ghost_round/proc/arm()
	if(launched)
		return
	launched = TRUE
	INVOKE_ASYNC(src, PROC_REF(launch))
	INVOKE_ASYNC(src, PROC_REF(watchdog))

/// Arms even if SSticker never delivers its roundstart callback, so a world that fails to start
/// still writes a profile instead of sitting there.
/datum/controller/subsystem/ghost_round/proc/arm_fallback()
	var/deadline = world.time + GHOST_BOOT_TIMEOUT
	while(world.time < deadline)
		if(launched)
			return
		if(SSticker.current_state >= GAME_STATE_PLAYING)
			break
		sleep(10 SECONDS)
	if(!launched)
		ghost_log("roundstart callback never arrived - arming from the fallback path (ticker state [SSticker.current_state])")
	arm()

/datum/controller/subsystem/ghost_round/proc/launch()
	mark_progress("launch")
	ghost_log("=== GHOST ROUND: launch (ticker state [SSticker.current_state], maxz [world.maxz]) ===")
	SSticker.delay_end = TRUE

	if(!wait_for_ready())
		write_profile("world never reached a runnable state")
		return

	// Let the roundstart load settle before the clock starts: the fleet spawn, SSatoms' queue
	// and SSlighting's first sweep all land in the seconds after roundstart, and starting the
	// measurement on top of them would put boot cost in minute zero.
	sleep(20 SECONDS)

	started_realtime = world.realtime
	started_worldtime = world.time
	running = TRUE
	GLOB.ghost_round_active = TRUE
	SSghost_sampler.phase_label = "launch"

	// The profiler is driven by this harness, not by its own fire. The compile-time
	// `can_fire = FALSE` in the environment block is not enough on its own - SSprofiler's
	// OnConfigLoad() re-enables it when the config has auto_profile set, which is how the
	// 70-minute run ended up with 44 dumps of 2.5 MB each instead of the eight it asked for.
	// Clearing it here, after config load, is the one that holds.
	SSprofiler.StartProfiling()
	SSprofiler.can_fire = FALSE

	ghost_log("clock started. TD thresholds: 5% = 1.05x glide, 25% = 1.25x, 100% = 2.0x.")
	beat("round armed - [length(GLOB.overmap_planets)] roundstart planet contact\s on the chart, [length(SSnpc_ships.active_ships)] pirate hull\s in the pool (target [SSnpc_ships.pirate_count_target])")

	INVOKE_ASYNC(src, PROC_REF(bucket_recorder))
	INVOKE_ASYNC(src, PROC_REF(census_recorder))
	INVOKE_ASYNC(src, PROC_REF(profiler_recorder))
	INVOKE_ASYNC(src, PROC_REF(kill_watcher))
	INVOKE_ASYNC(src, PROC_REF(snapshot_recorder))

	phase_launch()
	if(sustain)
		// The launch phase already stood the fleet and the site mix up; from here the round
		// just keeps being a round until the budget runs out.
		INVOKE_ASYNC(src, PROC_REF(replenisher))
		sustain_loop()
	else
		phase_peak()
		phase_attrition()

	running = FALSE
	GLOB.ghost_round_active = FALSE
	write_profile()

/datum/controller/subsystem/ghost_round/proc/wait_for_ready()
	var/deadline = world.time + GHOST_BOOT_TIMEOUT
	while(world.time < deadline)
		if(SSticker.current_state >= GAME_STATE_PLAYING && SSovermap.initialized)
			ghost_log("world ready: ticker state [SSticker.current_state], overmap initialized, maxz [world.maxz]")
			return TRUE
		sleep(5 SECONDS)
	ghost_log("FAIL TIMEOUT waiting for the round to start (ticker state [SSticker.current_state], overmap init [SSovermap.initialized ? "yes" : "no"])")
	return FALSE

/**
 * Independent stall detector. A DM runtime unwinds the driver without running anything on the
 * way out, so the only symptom is a frozen progress stamp. Writes the profile itself, so the
 * shell script gets an answer instead of a timeout.
 */
/datum/controller/subsystem/ghost_round/proc/watchdog()
	while(!profile_written)
		sleep(30 SECONDS)
		if(profile_written)
			return
		if(!progress_stamp)
			continue
		if(world.time - progress_stamp <= GHOST_WATCHDOG_STALL)
			continue
		ghost_log("FAIL EXCEPTION - the driver has not made progress for [(world.time - progress_stamp) / 600] minutes; last step was '[progress_label]'")
		ghost_log("FAIL EXCEPTION context: maxz=[world.maxz] worldgen=[SSovermap.worldgen_owner ? "'[SSovermap.worldgen_label]'" : "idle"] queue=[SSovermap.worldgen_queue_length()] runtimes=[GLOB.total_runtimes]")
		running = FALSE
		GLOB.ghost_round_active = FALSE
		write_profile("driver stalled at '[progress_label]' (probable runtime - see [GHOST_DD_LOG])")
		return

/// Hull kills are worth a narrative line whether the driver arranged them or a pirate did.
/// COMSIG_SHIP_DESTROYED has exactly one consumer in production (the bounty datum), so this
/// registers its own rather than reading anybody else's bookkeeping.
/datum/controller/subsystem/ghost_round/proc/kill_watcher()
	var/list/watched = list()
	while(running)
		for(var/obj/structure/overmap/ship/hull as anything in player_ships)
			if(QDELETED(hull) || watched[hull])
				continue
			watched[hull] = TRUE
			RegisterSignal(hull, COMSIG_SHIP_DESTROYED, PROC_REF(on_hull_killed))
		sleep(20 SECONDS)

/datum/controller/subsystem/ghost_round/proc/on_hull_killed(obj/structure/overmap/ship/source)
	SIGNAL_HANDLER
	hull_kills++
	tally_class(hull_class(source), "killed")
	beat("HULL KILL: '[source.name]' class '[hull_class(source)]' lost integrity ([source.integrity]/[source.max_integrity]) and is crash-landing")

// ---------------------------------------------------------------------------------------
// Founding the fleet
// ---------------------------------------------------------------------------------------

/**
 * Twelve player hulls, through the production ship-load path.
 *
 * Four arrive through SSovermap.scale_roundstart_fleet(), which is the pop-scaled roundstart
 * fleet SSticker.create_characters() calls - it is capped at roundstart_max_ships (4), so a
 * seventy-player round does not get twelve hulls that way and neither does this one. The other
 * eight are requisitioned through spawn_free_hull(track_as_initial = FALSE), which is the exact
 * proc /mob/dead/new_player/requisition_free_hull() calls from the join menu. Both roll a random
 * modular hull, a random theme and a random module in every upgrade slot, drawing hull classes
 * without replacement while the pool lasts - so the fleet is varied by construction.
 *
 * SSshuttle.create_ship() sleeps twice (a global shuttle_loading latch and the template load)
 * and is deliberately NOT parallelised: setup_shuttle_late() documents a measured leak of 4
 * mobile ports, 4 stationary ports, 2 turf reservations and 32 pipelines from a single
 * interleaved template load. Founding is therefore serial, which is also how a real round does
 * it - players do not all press the button on the same tick.
 */
/datum/controller/subsystem/ghost_round/proc/found_roundstart_hulls()
	mark_progress("founding the roundstart fleet")
	var/roundstart_wanted = min(ships_target, SSovermap.roundstart_max_ships)
	SSovermap.scale_roundstart_fleet(crew_target)
	for(var/obj/structure/overmap/ship/hull as anything in SSovermap.initial_ships)
		if(QDELETED(hull) || !hull.shuttle)
			continue
		register_hull(hull, "roundstart fleet")
		if(length(player_ships) >= roundstart_wanted)
			break
	beat("roundstart fleet: [length(player_ships)] hull\s - [fleet_manifest()]")

/**
 * The other eight, requisitioned from the join menu's own path.
 *
 * Bracketed as its own window because it IS a load storm and deserves to be measured as one:
 * eight shuttle template loads, eight transit reservations, eight sets of pipenets and areas and
 * machinery, all serialised through SSshuttle's global latch. On a real server this is what the
 * first ten minutes of a 70-player round look like as people found ships, and it is the single
 * densest block of allocation in the hour.
 */
/datum/controller/subsystem/ghost_round/proc/requisition_hulls()
	if(length(player_ships) >= ships_target)
		return
	var/list/window = list(
		"label" = "hull-requisition-storm",
		"start" = world.time,
		"end" = 0,
		"planned" = ships_target - length(player_ships),
		"ruins" = 0,
		"fields" = 0,
		"planets" = 0,
		"done" = 0,
	)
	burst_windows += list(window)
	beat("BURST 'hull-requisition-storm' begins: [window["planned"]] more hull\s to found through the join menu path")

	while(length(player_ships) < ships_target)
		if(budget_left() < 5 MINUTES)
			ghost_log("WARN: out of budget while founding the fleet at [length(player_ships)] of [ships_target] hulls")
			break
		mark_progress("founding hull [length(player_ships) + 1]")
		var/list/load_window = record_load_start("hull", "requisition [length(player_ships) + 1]", "hull-requisition-storm")
		var/obj/structure/overmap/ship/hull = found_hull_from_rotation("requisitioned from the join menu")
		record_load_end(load_window, 0, istype(hull))
		if(!istype(hull))
			ghost_log("WARN: no hull founded at slot [length(player_ships) + 1] - the catalogue may be exhausted")
			break
		window["done"]++

	window["end"] = world.time
	beat("fleet complete: [length(player_ships)] hull\s in [(window["end"] - window["start"]) / 10]s - [fleet_manifest()]")

/// Adds a freshly created hull to the fleet, gives it a thruster it can rely on for an hour,
/// and logs what class it turned out to be.
/datum/controller/subsystem/ghost_round/proc/register_hull(obj/structure/overmap/ship/hull, provenance)
	if(hull in player_ships)
		return
	player_ships += hull
	ship_missions[hull] = list("legs" = 0, "docked_at" = "none", "kind" = "none")
	fit_void_thruster(hull)
	hulls_founded_total++
	tally_class(hull_class(hull), "founded")
	beat("ship founded: '[hull.name]' class '[hull_class(hull)]' (theme [hull.theme || "none"]) - [provenance]")

/**
 * Bolts one void thruster into a hull so it can still move at minute sixty.
 *
 * THIS IS A HARNESS AFFORDANCE AND IS REPORTED AS ONE. Stock hulls fly on fuelled or electric
 * engines, and over an hour a real crew refuels and repairs them; nobody aboard this fleet can
 * do either, and a fleet that runs dry at minute twenty stops generating the movement, docking
 * and site-rotation load the scenario is about. /obj/machinery/power/shuttle_engine/ship/void is
 * production code (voidcrew/modules/shuttle/engine/void.dm) whose return_fuel()/return_fuel_cap()
 * are both TRUE and whose burn_engine() needs no powernet.
 *
 * What this does NOT do is skip any part of the flight path: can_thrust(), burn_engines(),
 * tick_move() and the autopilot all run exactly as they do for a fuelled hull. It removes a
 * logistics chore, not a cost.
 */
/datum/controller/subsystem/ghost_round/proc/fit_void_thruster(obj/structure/overmap/ship/hull)
	if(!hull.shuttle)
		return
	var/turf/spot = hull.get_random_open_ship_turf()
	if(!spot)
		ghost_log("WARN: no open turf aboard '[hull.name]' for a thruster - it will fly on whatever the template gave it")
		return
	var/obj/machinery/power/shuttle_engine/ship/void/thruster = new(spot)
	thruster.set_anchored(TRUE)
	// refresh_engines() re-derives shuttle.engine_list geometrically and rebinds strays, which
	// is what actually registers the new machine with the hull.
	hull.refresh_engines()

/datum/controller/subsystem/ghost_round/proc/fleet_manifest()
	var/list/names = list()
	for(var/obj/structure/overmap/ship/hull as anything in player_ships)
		if(QDELETED(hull))
			continue
		names += "[hull.name]"
	return jointext(names, ", ")

// ---------------------------------------------------------------------------------------
// Crewing
// ---------------------------------------------------------------------------------------

/**
 * Deals the sim crew out across the fleet in crews of GHOST_CREW_MIN..MAX_PER_SHIP.
 *
 * Uneven on purpose: a real fleet has a stuffed flagship and a two-hand prospector, and the
 * concurrency the scenario is testing partly comes from crews of different sizes doing
 * different things.
 */
/datum/controller/subsystem/ghost_round/proc/crew_the_fleet()
	mark_progress("crewing the fleet")
	// Seeded from the crew that already exist, NOT from zero. This proc is called twice - once
	// for the roundstart hulls and again after the requisitioned ones arrive - and a counter
	// that restarts at zero would deal a second full complement, putting 140 mobs in a
	// seventy-crew round and quietly doubling the headline population the whole profile is
	// reported against.
	var/spawned = 0
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(!QDELETED(sim) && sim.stat != DEAD)
			spawned++
	var/starting = spawned
	// Deal only this pass's SHARE of the complement.
	//
	// crew_the_fleet() runs twice - once on the roundstart hulls, again after the requisitioned
	// ones arrive - and filling straight to `crew_target` on the first pass puts the entire crew
	// on the four hulls that exist at that moment. Both the 70-minute run and the first 3-hour
	// launch did exactly that: "70 new sim crew dealt out, 70 alive across 4 hulls", then "0 new
	// sim crew dealt out ... across 12 hulls". Eight hulls flew the round empty, which makes
	// every per-hull occupancy shim answer about four ships instead of twelve.
	//
	// The share is the fleet fraction that exists right now, so the first pass takes ~4/12 and
	// the second takes the rest. Ceiling'd and floored at one full crew so a single-hull fleet
	// still gets crewed.
	var/hulls_now = max(1, length(player_ships))
	var/share_target = crew_target
	if(hulls_now < ships_target)
		share_target = max(GHOST_CREW_MAX_PER_SHIP, CEILING(crew_target * (hulls_now / ships_target), 1))
	share_target = min(share_target, crew_target)
	// Always fill the EMPTIEST hull next, rather than dealing round-robin from index 1. On the
	// second call the first four hulls are already crewed and a round-robin would give them a
	// second helping before the eight new ones got anybody - which would leave most of the fleet
	// flying empty and every occupancy shim answering about four hulls instead of twelve.
	var/list/aboard_count = list()
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(QDELETED(sim) || sim.stat == DEAD)
			continue
		var/obj/structure/overmap/ship/home = GLOB.ghost_round_crew[sim]
		if(home)
			aboard_count[home] += 1

	while(spawned < share_target)
		var/obj/structure/overmap/ship/emptiest
		for(var/obj/structure/overmap/ship/hull as anything in player_ships)
			if(QDELETED(hull) || !hull.shuttle)
				continue
			if(!emptiest || aboard_count[hull] < aboard_count[emptiest])
				emptiest = hull
		if(!emptiest)
			break
		// Crews are uneven on purpose - a real fleet has a stuffed flagship and a two-hand
		// prospector, and crews of different sizes doing different things is part of the load
		// being modelled.
		var/wanted = min(rand(GHOST_CREW_MIN_PER_SHIP, GHOST_CREW_MAX_PER_SHIP), share_target - spawned)
		var/added = 0
		for(var/i in 1 to wanted)
			if(make_crewmate(emptiest))
				spawned++
				added++
		aboard_count[emptiest] += added
		if(!added)
			// This hull cannot take anybody (no open turf aboard). Drop it out of contention or
			// the loop spins on it forever.
			player_ships -= emptiest
			ghost_log("WARN: '[emptiest.name]' could not take crew - no open turf aboard; dropped from the fleet")
		CHECK_TICK
	beat("crew aboard: [spawned - starting] new sim crew dealt out (this pass's share was [share_target] for [hulls_now] of [ships_target] hulls), [spawned] alive across [length(player_ships)] hull\s ([length(GLOB.ghost_round_crew)] tracked)")

/**
 * One sim crewmate.
 *
 * Real /mob/living/carbon/human/consistent (deterministic DNA - seventy random genomes is
 * needless work), a real mind through /mob/proc/mind_initialize(), a real job off the hull's
 * own job_slots, a sealed EVA outfit, and registration into the hull's manifest and ship_team
 * through the production manifest_inject(). That last part is not cosmetic: SSovermap's
 * derelict sweep has a "never crewed" fast path that despawns a hull with an empty manifest and
 * an empty ship_team immediately, with no derelict window at all.
 *
 * mind_initialize() sets ever_had_mind for free (via mind.set_current), which is what the
 * weather system's mind || ever_had_mind filter reads - so storms target this crew without any
 * shim at all.
 *
 * The mob is NOT added to GLOB.player_list. See the shim block for why.
 */
/datum/controller/subsystem/ghost_round/proc/make_crewmate(obj/structure/overmap/ship/hull)
	var/turf/spot = hull.get_random_open_ship_turf()
	if(!spot && length(hull.shuttle ? hull.shuttle.spawn_points : null))
		spot = get_turf(pick(hull.shuttle.spawn_points))
	if(!spot)
		return null

	var/mob/living/carbon/human/consistent/crewmate = new(spot)
	crewmate.fully_replace_character_name(crewmate.real_name, "Crew [length(GLOB.ghost_round_crew) + 1]")
	crewmate.mind_initialize()

	var/datum/job/role = length(hull.job_slots) ? pick(hull.job_slots) : null
	if(istype(role))
		crewmate.mind.set_assigned_role(role)
	crewmate.equipOutfit(/datum/outfit/ghost_round_crew)
	// Into the ACTIVE hand specifically: ClickOn() resolves through whatever the active hand
	// holds, so an accelerator in the off-hand would be a decoration and the crew would still be
	// punching goliaths.
	crewmate.put_in_active_hand(new /obj/item/gun/energy/recharge/kinetic_accelerator(crewmate), forced = TRUE)

	GLOB.ghost_round_crew[crewmate] = hull
	// The z-registration the FAMILY 1 shim exists to allow. update_z() is normally driven by
	// Login(); nothing calls it for a mob that never logs in, so the first one is manual.
	crewmate.update_z(spot.z)

	// Production crew registration: manifest, ship_team membership, the death hook.
	hull.manifest_inject(crewmate, role)
	return crewmate

/// Replacement crew, the way a real round gets them: somebody dies and a new character joins.
/// Held back during the attrition phase, where the wipes are the measurement.
/datum/controller/subsystem/ghost_round/proc/top_up_crew()
	var/alive = 0
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(!QDELETED(sim) && sim.stat != DEAD)
			alive++
	if(alive >= crew_target)
		return
	var/wanted = min(crew_target - alive, 6)
	var/added = 0
	for(var/i in 1 to wanted)
		var/obj/structure/overmap/ship/hull = pick_crewable_hull()
		if(!hull)
			break
		if(make_crewmate(hull))
			added++
	crew_replaced += added
	if(added)
		beat("[added] latejoin crew replaced losses (alive [alive] -> [alive + added] of [crew_target])")

/// A hull a latejoiner could plausibly board. `wiped_hulls` is the load-bearing exclusion in
/// sustained mode: a hull whose crew was just wiped spends a minute or two crewless before the
/// sweep abandons it, and re-crewing it inside that window would undo the wipe and the derelict
/// pipeline would never run. Nobody latejoins onto a ship that has just been wiped.
/datum/controller/subsystem/ghost_round/proc/pick_crewable_hull()
	var/list/candidates = list()
	for(var/obj/structure/overmap/ship/hull as anything in player_ships)
		if(QDELETED(hull) || !hull.shuttle || hull.abandoned)
			continue
		if(wiped_hulls[hull])
			continue
		candidates += hull
	return length(candidates) ? pick(candidates) : null

// ---------------------------------------------------------------------------------------
// Sites
//
// Three kinds, and the difference between them is the whole reason the scenario insists on all
// three being resident at once:
//
//   PLANETS   claim a packed map-zone slot and are built by a live map generator. They go
//             through SSovermap's worldgen QUEUE, which serialises them BY DESIGN - the rule is
//             that a survey must never slow anything else down, so the queue exists to keep
//             generators off each other's tick, not to keep them off ruins.
//   RUINS     claim a SLOT on the map-zone lattice and stamp a static .dmm into it. Unqueued.
//   FIELDS    claim a lattice slot and carve it with a live generator, then seed ore, loot
//             and mob spawners. Unqueued.
//
// So the bursts below are a real test of two separate claims at once: that ruins and fields
// genuinely overlap each other, and that a queued planet build does not block them. Queue
// coupling where there should be none is a finding, and the load windows are recorded in enough
// detail to see it.
// ---------------------------------------------------------------------------------------

/// Opens a load window, runs `body`'s worth of loading, closes it. Every site load in the run
/// goes through record_load_start/record_load_end so the profile can cut the tick series to it.
/datum/controller/subsystem/ghost_round/proc/record_load_start(kind, label, burst_label)
	var/list/window = list(
		"kind" = kind,
		"label" = label,
		"burst" = burst_label,
		"start" = world.time,
		"end" = 0,
		"z" = 0,
		"ok" = FALSE,
	)
	load_windows += list(window)
	return window

/datum/controller/subsystem/ghost_round/proc/record_load_end(list/window, z, ok)
	if(!window)
		return
	window["end"] = world.time
	window["z"] = z
	window["ok"] = ok
	if(ok && window["kind"] != "hull")
		site_loads++
	ghost_log("LOADWINDOW kind=[window["kind"]] label='[window["label"]]' burst=[window["burst"] || "-"] start=[window["start"]] end=[window["end"]] duration_s=[(window["end"] - window["start"]) / 10] z=[z] ok=[ok ? "yes" : "no"]")

/**
 * One space ruin: a lattice slot and a static template. Unqueued, so several of these
 * genuinely overlap when started together.
 *
 * Template drawn uniformly over the pickable pool, mirroring spawn_replacement_ruin()'s filter
 * (`unpickable` is how a template says it must never be seeded). Ruins vary enormously in size
 * and content and a fixed template would measure one ruin's load and call it "ruins".
 */
/datum/controller/subsystem/ghost_round/proc/stand_up_ruin(burst_label)
	var/turf/spot = SSovermap.get_unused_overmap_square()
	if(!spot)
		ghost_log("WARN: no free overmap square for a space ruin")
		return null
	var/list/pool = list()
	for(var/ruin_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/candidate = SSmapping.space_ruins_templates[ruin_id]
		if(!istype(candidate) || candidate.unpickable)
			continue
		pool += candidate
	if(!length(pool))
		return null
	var/datum/map_template/ruin/space/template = pick(pool)

	var/obj/structure/overmap/space_ruin/ruin = new(spot)
	ruin.set_ruin_template(template)
	var/list/window = record_load_start("ruin", template.name, burst_label)
	ruin.load_level()
	record_load_end(window, ruin.footprint ? ruin.footprint.z_value : 0, !!ruin.mapzone)
	if(!ruin.mapzone)
		ghost_log("WARN: space ruin '[template.name]' did not load")
		qdel(ruin)
		return null
	site_ruins |= ruin
	return ruin

/**
 * One landable asteroid field: a lattice slot carved by a live map generator, then seeded
 * with ore, a loot crate and roaming mob packs. Unqueued, like a ruin, but with a generator's
 * cost profile - which is exactly the pairing the bursts are designed to expose.
 */
/datum/controller/subsystem/ghost_round/proc/stand_up_field(burst_label)
	var/static/list/severities = list(
		/obj/structure/overmap/event/meteor/minor,
		/obj/structure/overmap/event/meteor,
		/obj/structure/overmap/event/meteor/majour,
	)
	var/turf/spot = SSovermap.get_unused_overmap_square()
	if(!spot)
		ghost_log("WARN: no free overmap square for an asteroid field")
		return null
	var/field_type = pick(severities)
	var/obj/structure/overmap/event/meteor/field = new field_type(spot)
	var/list/window = record_load_start("field", "[field.name]", burst_label)
	field.load_level()
	record_load_end(window, field.footprint ? field.footprint.z_value : 0, !!field.mapzone)
	if(!field.mapzone)
		ghost_log("WARN: asteroid field '[field.name]' did not load")
		qdel(field)
		return null
	site_fields |= field
	return field

/**
 * One planet, through spawn_dynamic_planet() (the proc setup_planets() uses to place a contact)
 * and then load_level() (the proc a docking ship or a survey shuttle calls).
 *
 * Biome drawn from all seven, because terrain planets share ONE packed slot class - so a run
 * that only ever built lava planets would never exercise mixed-biome co-tenancy, which is where
 * per-footprint ground and per-site weather live.
 *
 * Pass 2, not 1: pass 1 marks a contact for the lobby prebuild sweep, which has already run and
 * must not be handed work behind the driver's back.
 */
/datum/controller/subsystem/ghost_round/proc/stand_up_planet(burst_label)
	var/static/list/biomes = list(
		/obj/structure/overmap/planet/lava,
		/obj/structure/overmap/planet/ice,
		/obj/structure/overmap/planet/beach,
		/obj/structure/overmap/planet/jungle,
		/obj/structure/overmap/planet/asteroid,
		/obj/structure/overmap/planet/wasteland,
	)
	// Use a charted contact first. SSovermap seeds ~10 unloaded roundstart planets, and a real
	// crew flies to one of those rather than conjuring a new world - so minting a fresh contact
	// on every claim would both misrepresent the round and grow GLOB.overmap_planets by one per
	// site, which quietly inflates every memory figure the run is here to measure.
	var/obj/structure/overmap/planet/marker = null
	for(var/obj/structure/overmap/planet/candidate as anything in GLOB.overmap_planets)
		if(QDELETED(candidate) || candidate.mapzone || candidate.loading || candidate.unloading)
			continue
		// Crash sites and flat encounters are not destinations; they are made by the round.
		if(istype(candidate, /obj/structure/overmap/planet/empty))
			continue
		// Deliberately NOT excluding contacts already in site_planets. A planet that has been
		// visited and released is relocated on the chart and becomes available again, exactly
		// as it does in a real round - and excluding it would force a brand-new contact for
		// every claim, growing GLOB.overmap_planets for the whole hour and inflating every
		// memory figure this run exists to measure. The mapzone/loading/unloading test above is
		// the real "is it in use" question.
		marker = candidate
		break

	if(!marker)
		var/list/before = GLOB.overmap_planets.Copy()
		SSovermap.spawn_dynamic_planet(pick(biomes), 2)
		for(var/obj/structure/overmap/planet/candidate in GLOB.overmap_planets)
			if(candidate in before)
				continue
			marker = candidate
			break
	if(!marker)
		ghost_log("WARN: no unloaded planet contact available and spawn_dynamic_planet() placed none - the chart may be full")
		return null
	var/list/window = record_load_start("planet", marker.name, burst_label)
	marker.load_level()
	record_load_end(window, marker.footprint ? marker.footprint.z_value : 0, !!marker.mapzone)
	if(!marker.mapzone)
		ghost_log("WARN: planet '[marker.name]' finished loading with no map zone")
		return null
	site_planets |= marker
	return marker

/**
 * A deliberate simultaneous-load burst.
 *
 * Each site is kicked off in its own async frame within the same tick, so the loads genuinely
 * overlap rather than queueing behind each other in the driver. The burst window brackets all
 * of them; the individual load windows nest inside it, and the profile reports both.
 *
 * `planet_count` is the interesting one. A planet build takes the worldgen queue; ruins and
 * fields do not. Firing them together is how the run demonstrates that the queue serialises
 * planets WITHOUT holding up anything else - and if it turns out it does hold them up, that is
 * the finding the whole burst design exists to catch.
 */
/datum/controller/subsystem/ghost_round/proc/fire_burst(label, ruin_count, field_count, planet_count)
	mark_progress("burst '[label]'")
	var/list/window = list(
		"label" = label,
		"start" = world.time,
		"end" = 0,
		"planned" = ruin_count + field_count + planet_count,
		"ruins" = ruin_count,
		"fields" = field_count,
		"planets" = planet_count,
		"done" = 0,
	)
	burst_windows += list(window)
	beat("BURST '[label]' fired: [ruin_count] ruin\s + [field_count] asteroid field\s + [planet_count] planet\s starting within the same tick")

	var/list/pending = list()
	for(var/i in 1 to ruin_count)
		pending += "ruin"
	for(var/i in 1 to field_count)
		pending += "field"
	for(var/i in 1 to planet_count)
		pending += "planet"

	// Bump a counter from each async frame; the burst is over when they have all reported.
	for(var/kind in pending)
		INVOKE_ASYNC(src, PROC_REF(burst_worker), kind, label, window)

	var/deadline = world.time + GHOST_LOAD_TIMEOUT
	while(world.time < deadline && window["done"] < window["planned"])
		sleep(2 SECONDS)
	window["end"] = world.time
	beat("BURST '[label]' settled after [(window["end"] - window["start"]) / 10]s - [window["done"]] of [window["planned"]] site\s stood up")

/datum/controller/subsystem/ghost_round/proc/burst_worker(kind, label, list/window)
	switch(kind)
		if("ruin")
			if(stand_up_ruin(label))
				window["done"]++
				return
		if("field")
			if(stand_up_field(label))
				window["done"]++
				return
		if("planet")
			if(stand_up_planet(label))
				window["done"]++
				return
	// A refusal still counts as reported, or the burst waits out its whole timeout on it.
	window["done"]++

/// Live, loaded site counts by kind. Read once a second by the sampler and once a bucket by the
/// profile, so it is deliberately all list walks and no geometry.
/datum/controller/subsystem/ghost_round/proc/live_site_counts()
	var/planets = 0
	var/ruins = 0
	var/fields = 0
	var/crashes = 0
	for(var/obj/structure/overmap/planet/marker as anything in site_planets)
		if(!QDELETED(marker) && marker.mapzone)
			planets++
	for(var/obj/structure/overmap/space_ruin/ruin as anything in site_ruins)
		if(!QDELETED(ruin) && ruin.mapzone)
			ruins++
	for(var/obj/structure/overmap/event/meteor/field as anything in site_fields)
		if(!QDELETED(field) && field.mapzone)
			fields++
	// Crash sites are minted by the production kill cascade, never by the driver, so they are
	// counted off the world rather than off a list the driver keeps.
	for(var/obj/structure/overmap/planet/empty/crashed_ship/wreck in GLOB.overmap_planets)
		if(!QDELETED(wreck) && wreck.mapzone)
			crashes++
	return list("planet" = planets, "ruin" = ruins, "field" = fields, "crash" = crashes, "arena" = (QDELETED(arena) ? 0 : 1))

/// Tops the resident site population back up to the concurrency floors. Called on a slow loop
/// through the peak and attrition phases, because sites DO release - a crew leaves, the site
/// unloads, and the floor has to be re-met by standing a fresh one up somewhere else. That
/// rotation is the point, not a nuisance.
/datum/controller/subsystem/ghost_round/proc/hold_concurrency_floor()
	// Prune first. Ruins and fields are qdel'd when they release, and a hard delete nulls list
	// entries IN PLACE rather than removing them - so these lists accumulate nulls for the whole
	// hour and every `as anything` walk over them would have to guard.
	site_ruins -= null
	site_fields -= null
	site_planets -= null
	count_teardowns()
	var/list/live = live_site_counts()
	var/planets_wanted = smoke ? 2 : GHOST_TARGET_PLANETS
	var/ruins_wanted = smoke ? 1 : GHOST_TARGET_RUINS
	var/fields_wanted = smoke ? 1 : GHOST_TARGET_FIELDS
	if(live["ruin"] < ruins_wanted)
		stand_up_ruin("floor")
	if(live["field"] < fields_wanted)
		stand_up_field("floor")
	if(live["planet"] < planets_wanted)
		stand_up_planet("floor")

// ---------------------------------------------------------------------------------------
// Ship missions
//
// One async frame per hull, running for the whole round. Each one picks a site, flies there
// under the production autopilot, docks, puts its crew on the ground, works the site for a
// while, recalls them and leaves - then picks a DIFFERENT KIND of site next time.
//
// The rotation is what produces the concurrent mix the scenario asks for. Twelve hulls each
// rotating through planet -> ruin -> field on their own dwell clocks means that at any moment
// some crews are arriving somewhere while others are leaving, which is what a real round looks
// like and what a serial "do all the planets, then all the ruins" script would not.
// ---------------------------------------------------------------------------------------

/// The site kinds a hull rotates through, offset per hull so the fleet does not move as a
/// block. Twelve hulls on a three-kind rotation gives four crews on each kind at any time,
/// which is the concurrency floor met by the ships rather than by the site keeper.
/datum/controller/subsystem/ghost_round/proc/mission_loop(obj/structure/overmap/ship/hull, offset)
	var/static/list/rotation = list("planet", "ruin", "field")
	var/leg = offset
	while(running && !QDELETED(hull))
		leg++
		var/kind = rotation[((leg - 1) % length(rotation)) + 1]
		var/list/mission = ship_missions[hull]
		if(mission)
			mission["legs"] = leg
			mission["kind"] = kind

		var/obj/structure/overmap/site = claim_site(kind)
		if(!site)
			// Nothing of that kind is standing; try again shortly rather than burning the leg.
			sleep(45 SECONDS)
			continue

		if(!fly_to(hull, site))
			sleep(30 SECONDS)
			continue
		if(!dock_at(hull, site))
			sleep(30 SECONDS)
			continue

		if(mission)
			mission["docked_at"] = "[site.name]"
		beat("'[hull.name]' docked at [kind] '[site.name]'")
		disembark(hull, site)

		// Dwell. Long enough for the crew to actually generate load on the site, short enough
		// that twelve hulls rotate several times across the hour.
		// ~3x shorter than the 70-minute run's 4-8 minutes. Dwell time is what sets how fast the
		// whole site population cycles - every departure releases a site and every arrival loads
		// one - so cutting it is the single biggest lever on load/teardown churn. Which is
		// exactly why it now scales with churn_scale: for four runs it did not, and a regime
		// switch that tripled three clocks and left this one alone moved total site-load volume
		// by 0.4%. See dwell_scale().
		var/dwell = smoke ? rand(45, 75) SECONDS : (rand(80, 160) SECONDS) * dwell_scale()
		var/leave_at = world.time + dwell
		while(running && world.time < leave_at && !QDELETED(hull) && !QDELETED(site))
			sleep(10 SECONDS)

		if(QDELETED(hull))
			return
		recall_crew(hull)
		if(mission)
			mission["docked_at"] = "none"
		leave_site(hull)

/**
 * The multiplier on the mission-rotation dwell.
 *
 * THE SECOND OF THE TWO CALIBRATION DEFECTS. `churn_scale` was documented as the regime knob but
 * was applied at exactly one place - the three sustain clocks - while the dwell, which is what
 * actually decides how often a site is released and therefore how often a new one is loaded, was
 * a hardcoded rand(80, 160) SECONDS. The consequence was measured on two real runs: STRESS
 * produced 23.2 site loads/h and ORDINARY produced 23.3, a 0.4% difference from a knob that was
 * supposed to be a factor of three. The dwell is now scaled with everything else.
 *
 * The real regime deliberately does NOT scale it. Its site-load cadence comes from the trickle
 * scheduler rather than from rotation demand, and the dwell's remaining job there is to keep
 * sites turning over fast enough that the trickle has ceiling headroom to load into. A longer
 * dwell would starve it. This is a known divergence from the real round it is calibrated
 * against, where a hull visits a site roughly every 26 minutes, and it is called out in the
 * report rather than hidden: the harness's crews rotate faster than real crews do, on purpose,
 * because they are the only teardown source it has.
 */
/datum/controller/subsystem/ghost_round/proc/dwell_scale()
	if(regime == GHOST_REGIME_REAL)
		return 1
	return churn_scale

/// An unoccupied loaded site of the wanted kind, or a fresh one. Occupancy is read off the
/// production berth flags rather than off driver bookkeeping, so a site a pirate or a crash
/// took is correctly seen as busy.
/datum/controller/subsystem/ghost_round/proc/claim_site(kind)
	var/list/pool
	switch(kind)
		if("planet")
			pool = site_planets
		if("ruin")
			pool = site_ruins
		if("field")
			pool = site_fields
	for(var/obj/structure/overmap/candidate as anything in pool)
		if(QDELETED(candidate))
			continue
		if(site_docks_full(candidate))
			continue
		if(!site_is_loaded(candidate))
			continue
		return candidate
	// CEILING on the resident site population.
	//
	// Every crew that wants a site and finds none free mints a new one, which is what a real
	// crew does - but with a dozen-plus hulls rotating on a 80-160 s dwell, demand outran
	// release and the first 3-hour run grew to 5 planets + 9 ruins + 11 asteroid fields, four
	// times the concurrency floors it was asked to hold. Site count is the dominant term in
	// `maxz` and `world.contents`, so that growth is most of why it walked into the 4 GB wall,
	// and it makes "did memory plateau" unanswerable: the round was not in a steady state.
	//
	// At the ceiling a crew waits for one to free up instead of minting another, which is also
	// what a real crew does when the chart is busy.
	var/list/live = live_site_counts()
	if(live[kind] >= site_cap_for(kind))
		return null

	// At the z ceiling a mint would fail against a full lattice. Answer "nothing free"
	// instead: the mission loop's existing 45-second retry is exactly the wait a real
	// crew makes when the chart is busy, and it costs no failed-load noise.
	if(!site_capacity_available(kind))
		return null

	switch(kind)
		if("planet")
			return stand_up_planet("mission")
		if("ruin")
			return stand_up_ruin("mission")
		if("field")
			return stand_up_field("mission")

/// Resident-site ceiling per kind. Two jobs by regime.
///
/// The legacy regimes (stress/ordinary) keep the tight 2x-floor caps: their runs exist to
/// answer "did memory plateau", which needs a forced steady state.
///
/// The REAL regime's caps were raised after run 5 (2026-08-20). With the tight caps the
/// trickle refused 50 of its 90 wanted loads - 13.3/h delivered against the measured 32.1/h -
/// and the binding constraint on site volume was the HARNESS, not the game. Production has no
/// such cap: rounds 7/8/9's residency climbed all round (maxz 32/34/35, monotonic) and the
/// only limiter the shipped build has is the MAX_Z_LEVELS ceiling over the packed lattice.
/// So in REAL the caps sit above anything that ceiling can ever admit (planets take a z each,
/// flat sites pack 4 to a z) and survive only as a runaway backstop; every refusal a REAL run
/// records is the game's own slot-availability wait, which is the thing being measured.
/datum/controller/subsystem/ghost_round/proc/site_cap_for(kind)
	if(smoke)
		return 2
	if(regime == GHOST_REGIME_REAL)
		switch(kind)
			if("planet")
				return 12 // production peak planet residency was 10 (round-9, the only round with teardown records)
			if("ruin")
				return 20
			if("field")
				return 8 // production loads fields at only ~1.7/h
		return 8
	switch(kind)
		if("planet")
			return GHOST_TARGET_PLANETS * 2
		if("ruin")
			return GHOST_TARGET_RUINS * 2
		if("field")
			return GHOST_TARGET_FIELDS * 3
	return 4

/**
 * Whether the packed lattice could take a load of this kind RIGHT NOW, read-only.
 *
 * Mirrors the claim the load will actually make: planets claim MAP_TENANT_CLASS_PLANET,
 * fields MAP_TENANT_CLASS_FLAT, and ruins FLAT for every template that fits a slot (112 of
 * 113 do - the sole SOLO outlier is a 0.9% draw and one failed attempt there is acceptable).
 * Below the z ceiling the answer is always yes, because a refused slot just mints a level.
 * At the ceiling it is yes only when find_free_slot() - which never sleeps - has a slot of
 * the class in hand.
 *
 * This precheck exists so a worker facing a full world WAITS QUIETLY instead of attempting:
 * a doomed attempt costs a worldgen-queue claim/release cycle, an overmap-object churn, a
 * WARN and an ok=no load window - at trickle cadence that noise would bury the report's
 * failure gate in false alarms that are really just "the world was full", which run 6
 * measures deliberately.
 */
/datum/controller/subsystem/ghost_round/proc/site_capacity_available(kind)
	if(!SSmapping.at_z_level_ceiling())
		return TRUE
	var/tenant_class = (kind == "planet") ? MAP_TENANT_CLASS_PLANET : MAP_TENANT_CLASS_FLAT
	return !!SSovermap.find_free_slot(tenant_class)

/// Both berths claimed? The berth flags are declared per site subtype rather than on
/// /obj/structure/overmap, so this cannot be read off a base-typed var and needs the ladder.
/datum/controller/subsystem/ghost_round/proc/site_docks_full(obj/structure/overmap/site)
	if(istype(site, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet_site = site
		return planet_site.first_dock_taken && planet_site.second_dock_taken
	if(istype(site, /obj/structure/overmap/space_ruin))
		var/obj/structure/overmap/space_ruin/ruin_site = site
		return ruin_site.first_dock_taken && ruin_site.second_dock_taken
	if(istype(site, /obj/structure/overmap/event/meteor))
		var/obj/structure/overmap/event/meteor/field_site = site
		return field_site.first_dock_taken && field_site.second_dock_taken
	return FALSE

/// One instance census snapshot into data/logs/<run>/instance_census.ndjson, which
/// tools/instance_census/census_diff.py ranks per-type growth from.
/datum/controller/subsystem/ghost_round/proc/take_census_now()
	if(!SSinstance_census)
		return
	SSinstance_census.take_census(include_datums = TRUE)

/datum/controller/subsystem/ghost_round/proc/site_is_loaded(obj/structure/overmap/site)
	if(istype(site, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet_site = site
		return !!planet_site.mapzone
	if(istype(site, /obj/structure/overmap/space_ruin))
		var/obj/structure/overmap/space_ruin/ruin_site = site
		return !!ruin_site.mapzone
	if(istype(site, /obj/structure/overmap/event/meteor))
		var/obj/structure/overmap/event/meteor/field_site = site
		return !!field_site.mapzone
	return FALSE

/**
 * Flies a hull to a site under the production autopilot, and waits for it.
 *
 * engage_autopilot() is the exact call the helm console makes (voidcrew/modules/shuttle/helm/
 * _helm.dm:983), including the dock target - so on arrival complete_autopilot() hands the site
 * to overmap_object_act() and the dock starts by itself. `user` is null, which the autopilot
 * supports: it is used only for a log line and an arrival-feedback weakref.
 *
 * The re-engage loop is not defensive padding. Combat interrupts a course for real reasons -
 * weapons lock, interdiction, hull damage, a hazard on the plotted route - and a fleet flying
 * through a pirate-infested overmap will hit all four. A player would re-plot; so does this.
 */
/datum/controller/subsystem/ghost_round/proc/fly_to(obj/structure/overmap/ship/hull, obj/structure/overmap/site)
	if(QDELETED(hull) || QDELETED(site))
		return FALSE
	if(hull.docked && !leave_site(hull))
		return FALSE

	var/deadline = world.time + GHOST_FLIGHT_TIMEOUT
	var/attempts = 0
	var/last_refusal
	while(running && world.time < deadline && !QDELETED(hull) && !QDELETED(site))
		if(hull.x == site.x && hull.y == site.y)
			return TRUE
		if(!hull.autopilot_engaged)
			attempts++
			if(attempts > 10)
				ghost_log("WARN: '[hull.name]' could not hold a course to '[site.name]' after 10 attempts (last refusal: '[last_refusal || "none"]', autopilot status: [hull.autopilot_status || "none"])")
				return FALSE
			// What a pilot does when the safe route does not exist: relax the flight policy and
			// go anyway. These are the production helm toggles (set_autopilot_pref's whitelist),
			// and the default `avoidHostiles = TRUE` genuinely makes some destinations
			// unplottable once four pirates are on the chart.
			if(attempts == 4)
				hull.set_autopilot_pref("avoidHostiles", FALSE)
				hull.set_autopilot_pref("hazardLanding", TRUE)
				ghost_log("'[hull.name]' relaxed its flight policy (hostile avoidance off, hazard landing on) after 3 refused courses to '[site.name]'")
			if(attempts == 7)
				hull.set_autopilot_pref("crossMeteor", TRUE)
				hull.set_autopilot_pref("crossElectric", TRUE)
			last_refusal = hull.engage_autopilot(site.x, site.y, "ghost round: [site.name]", null, site)
			if(findtext(last_refusal, "ERROR"))
				// A real refusal (no engine power, interdicted, concealed, no plottable route).
				sleep(15 SECONDS)
				continue
		sleep(5 SECONDS)
	if(!QDELETED(hull) && !QDELETED(site) && hull.x == site.x && hull.y == site.y)
		return TRUE
	ghost_log("WARN: '[hull.name]' did not reach '[site.name]' within [GHOST_FLIGHT_TIMEOUT / 600] minutes (autopilot status: [QDELETED(hull) ? "hull gone" : (hull.autopilot_status || "still flying")])")
	return FALSE

/**
 * Docks a hull at the site it is standing on.
 *
 * The autopilot's own arrival usually does this (it carries the dock target), so this normally
 * only has to wait. When it does have to act, overmap_object_act() is the ship-side gate a
 * player triggers from the chart, and it routes into the site's own ship_act() - which is what
 * calls request_site_load() for a site that is not loaded yet.
 */
/datum/controller/subsystem/ghost_round/proc/dock_at(obj/structure/overmap/ship/hull, obj/structure/overmap/site)
	var/deadline = world.time + GHOST_DOCK_TIMEOUT
	var/nudged = FALSE
	while(running && world.time < deadline && !QDELETED(hull) && !QDELETED(site))
		if(hull.docked == site)
			return TRUE
		if(hull.docked)
			// Docked at something else entirely - a crash site, most likely. Take it.
			return TRUE
		if(!nudged && hull.state == OVERMAP_SHIP_FLYING && hull.is_still())
			nudged = TRUE
			hull.overmap_object_act(null, site)
		sleep(5 SECONDS)
	return !QDELETED(hull) && !!hull.docked

/**
 * Puts a hull's crew on the ground.
 *
 * THE HARNESS'S ONE TELEPORT, and it is reported as one. A real crew walks out through an
 * airlock, which is a few dozen Move() calls - the driver generates that same movement cost
 * continuously once they are down there, so what is skipped is the pathing from berth to hatch,
 * not the cost of being on the site. Doing it properly would mean pathfinding seventy mobs
 * through docking geometry that varies per hull and per site, and a crew that got stuck in a
 * corridor would silently stop generating the load the whole scenario is about.
 *
 * Roughly two thirds go ashore; the rest stay aboard, which is both realistic and load-bearing
 * for the derelict shims - get_event_crew() has to keep answering yes while a landing party is
 * out.
 */
/datum/controller/subsystem/ghost_round/proc/disembark(obj/structure/overmap/ship/hull, obj/structure/overmap/site)
	var/landed = 0
	for(var/mob/living/carbon/human/crewmate as anything in GLOB.ghost_round_crew)
		if(QDELETED(crewmate) || crewmate.stat == DEAD)
			continue
		if(GLOB.ghost_round_crew[crewmate] != hull)
			continue
		if(!hull.is_aboard(crewmate))
			continue
		if(prob(35))
			continue
		var/turf/ground = random_site_turf(site)
		if(!ground)
			break
		crewmate.forceMove(ground)
		crewmate.update_z(ground.z)
		landed++
		CHECK_TICK
	if(landed)
		beat("'[hull.name]' put [landed] crew onto '[site.name]'")

/// Brings a hull's landing party back aboard before it leaves, the same way.
/datum/controller/subsystem/ghost_round/proc/recall_crew(obj/structure/overmap/ship/hull)
	var/recalled = 0
	var/stranded = 0
	for(var/mob/living/carbon/human/crewmate as anything in GLOB.ghost_round_crew)
		if(QDELETED(crewmate))
			continue
		if(GLOB.ghost_round_crew[crewmate] != hull)
			continue
		if(hull.is_aboard(crewmate))
			continue
		if(crewmate.stat == DEAD)
			// Bodies stay where they fell. Corpses on a site are part of a round, and leaving
			// them tests something real: a mind-holding corpse pins a map zone through
			// get_mind_mobs(), and the site cannot recycle until it is gone.
			stranded++
			continue
		var/turf/aboard = hull.get_random_open_ship_turf()
		if(!aboard)
			continue
		crewmate.forceMove(aboard)
		crewmate.update_z(aboard.z)
		recalled++
		CHECK_TICK
	if(recalled || stranded)
		beat("'[hull.name]' recalled [recalled] crew[stranded ? " and left [stranded] dead behind" : ""]")

/// A random open turf inside a site's interior, bounded to the site's own footprint - never
/// the whole z, which on a packed level is somebody else's planet.
/datum/controller/subsystem/ghost_round/proc/random_site_turf(obj/structure/overmap/site)
	var/list/bounds = ghost_round_bounds_of(site)
	if(!bounds)
		return null
	var/list/z_values = bounds["z"]
	if(!length(z_values))
		return null
	var/target_z = z_values[1]
	for(var/attempt in 1 to 40)
		var/turf/candidate = locate(rand(bounds["min_x"], bounds["max_x"]), rand(bounds["min_y"], bounds["max_y"]), target_z)
		if(!isopenturf(candidate) || candidate.is_blocked_turf())
			continue
		return candidate
	return null

/// Undocks a hull through the production undock(), which runs the warmup and the state machine
/// and ends in the same COMSIG_VOIDCREW_SHIP_UNDOCKED that releases a site when a crew leaves
/// under its own power. Refusals are real (undock cooldown, integrity lockout) and are waited
/// out rather than forced.
/datum/controller/subsystem/ghost_round/proc/leave_site(obj/structure/overmap/ship/hull)
	if(QDELETED(hull) || !hull.docked)
		return TRUE
	var/deadline = world.time + GHOST_DOCK_TIMEOUT
	while(running && world.time < deadline && !QDELETED(hull))
		if(!hull.docked)
			return TRUE
		if(hull.state == OVERMAP_SHIP_FLYING)
			return TRUE
		if(hull.state != OVERMAP_SHIP_UNDOCKING)
			hull.undock()
		sleep(10 SECONDS)
	return !QDELETED(hull) && !hull.docked

/// Free-proc form of the site-geometry resolver, so the driver can use it without a ship in
/// hand. Same body as /obj/structure/overmap/ship/proc/ghost_round_site_bounds().
/proc/ghost_round_bounds_of(obj/structure/overmap/site)
	var/min_x = 0
	var/min_y = 0
	var/max_x = 0
	var/max_y = 0
	// One footprint branch for every site kind: planets, flat encounters, space ruins and
	// asteroid fields all sit in a slot on the lattice now. Unlike the ship-side shim above
	// there is deliberately NO whole-level fallback here - this one hands back a rectangle to
	// pick random turfs out of, and on a packed level the level is somebody else's site.
	var/datum/map_footprint/site_footprint = site?.get_interior_footprint()
	if(!site_footprint || isnull(site_footprint.low_x) || !site_footprint.z_value)
		return null
	min_x = site_footprint.low_x
	min_y = site_footprint.low_y
	max_x = site_footprint.high_x
	max_y = site_footprint.high_y
	return list("z" = list(site_footprint.z_value), "min_x" = min_x, "min_y" = min_y, "max_x" = max_x, "max_y" = max_y)

// ---------------------------------------------------------------------------------------
// The hour
// ---------------------------------------------------------------------------------------

/**
 * 0 - 10 minutes. The founding storm.
 *
 * Twelve hulls found and crew up, an EARLY BURST goes off against a quiet world (which is the
 * control reading every later burst is compared against), the site keeper stands the mix up,
 * and every hull is handed a mission and starts flying. Everything after the burst runs
 * concurrently - the missions are async frames, so hulls are already under way while the site
 * keeper is still building.
 */
/datum/controller/subsystem/ghost_round/proc/phase_launch()
	SSghost_sampler.phase_label = "launch"
	mark_progress("phase: launch")
	beat("=== PHASE 1: LAUNCH (0-[num_1dp(phase_end(GHOST_PHASE_LAUNCH_END))]m) ===")

	// Order matters here. The roundstart hulls come up first, then the EARLY BURST goes off
	// against a world that is genuinely quiet - a handful of hulls, no crews on the ground,
	// nothing else generating - because that reading is the control every later burst is
	// compared against, and firing it on top of twelve serialised template loads would make it
	// a measurement of the template loads. The other eight hulls are requisitioned afterwards,
	// as their own bracketed load storm.
	build_hull_rotation()
	found_roundstart_hulls()
	crew_the_fleet()

	fire_burst("early-quiet", smoke ? 1 : 3, smoke ? 1 : 2, 0)

	requisition_hulls()
	crew_the_fleet()

	// Hand every hull a mission. Offsets stagger the rotation so the fleet does not move as a
	// block, and each frame runs for the rest of the round.
	var/offset = 0
	for(var/obj/structure/overmap/ship/hull as anything in player_ships)
		if(QDELETED(hull))
			continue
		INVOKE_ASYNC(src, PROC_REF(mission_loop), hull, offset)
		offset++
	beat("[offset] mission frame\s under way - hulls are flying to distinct destinations")

	INVOKE_ASYNC(src, PROC_REF(site_keeper))

	hold_until(phase_end(GHOST_PHASE_LAUNCH_END), "launch")

/**
 * 10 - 40 minutes. Peak.
 *
 * The concurrency floors hold (>= 4 planets, >= 3 ruins, >= 2 asteroid fields loaded and
 * occupied at once, plus the arena and whatever crash sites the pirates have made), crews are
 * mining and fighting fauna, storms fire on their own schedules, and the pirate pool is at its
 * live target with nothing suppressing it.
 *
 * Two more bursts land in here on purpose: one with crews live on other sites (the worst case
 * the scenario is really asking about), and one fired WHILE a planet is mid-build, which is the
 * queue-coupling probe.
 */
/datum/controller/subsystem/ghost_round/proc/phase_peak()
	SSghost_sampler.phase_label = "peak"
	mark_progress("phase: peak")
	beat("=== PHASE 2: PEAK ([num_1dp(phase_end(GHOST_PHASE_LAUNCH_END))]-[num_1dp(phase_end(GHOST_PHASE_PEAK_END))]m) ===")

	open_arena()

	// Burst 2: everything else is already running - crews landed, fauna awake, pirates hunting.
	hold_until(phase_end(16), "peak (pre-burst)")
	profile_dump("before-burst-loaded")
	fire_burst("peak-loaded", smoke ? 1 : 3, smoke ? 1 : 2, 0)
	profile_dump("after-burst-loaded")

	// Burst 3: the queue-coupling probe. A planet build takes the worldgen queue and the ruins
	// and fields alongside it do not, so if the ruins' load windows sit inside the planet's
	// instead of overlapping it, the queue is coupling things it is not supposed to couple.
	hold_until(phase_end(26), "peak (pre-queue-probe)")
	fire_burst("peak-during-planet-build", smoke ? 1 : 2, smoke ? 1 : 2, 1)

	hold_until(phase_end(GHOST_PHASE_PEAK_END), "peak")

/**
 * 40 - 60 minutes. Attrition.
 *
 * Two or three crews are wiped and their hulls go through the REAL derelict pipeline while
 * every other site stays occupied - which is the interesting half: a fleet-wide teardown proves
 * nothing that the churn soak has not already proved, and a teardown running alongside live
 * crews on other sites is where the lifecycle bugs live.
 *
 * The clocks are fast-forwarded, not bypassed. SHIP_CREWLESS_ABANDON_TIME is 30 minutes and
 * SHIP_DERELICT_DESPAWN_TIME another hour; rather than call abandon_ship() and despawn_derelict()
 * directly, the driver rewinds crewless_since and abandoned_at so that SSovermap.sweep_derelicts()
 * itself decides, on its own once-a-minute schedule, running its own unmodified code.
 */
/datum/controller/subsystem/ghost_round/proc/phase_attrition()
	SSghost_sampler.phase_label = "attrition"
	mark_progress("phase: attrition")
	beat("=== PHASE 3: ATTRITION ([num_1dp(phase_end(GHOST_PHASE_PEAK_END))]-[num_1dp(phase_end(GHOST_PHASE_ATTRITION_END))]m) ===")

	var/wipes = smoke ? 1 : 3
	for(var/i in 1 to wipes)
		wipe_a_crew()
		hold_until(phase_end(GHOST_PHASE_PEAK_END + ((GHOST_PHASE_ATTRITION_END - GHOST_PHASE_PEAK_END) * i / (wipes + 1))), "attrition (wipe [i])")

	hold_until(budget_min, "attrition")

/**
 * Kills one hull's crew and lets the production pipeline take the ship.
 *
 * death() rather than a qdel: the bodies stay, which is what a real wipe leaves behind, and
 * every mind-holding corpse aboard is exactly what despawn_derelict()'s teardown loop has to
 * deal with. The hull's manifest empties itself, and SSovermap's sweep picks it up on its
 * next pass with the clocks rewound underneath it.
 */
/datum/controller/subsystem/ghost_round/proc/wipe_a_crew()
	var/obj/structure/overmap/ship/victim
	var/best = 0
	for(var/obj/structure/overmap/ship/hull as anything in player_ships)
		if(QDELETED(hull) || hull.abandoned)
			continue
		var/aboard = length(hull.get_event_crew())
		if(aboard > best)
			best = aboard
			victim = hull
	if(!victim)
		ghost_log("WARN: no crewed hull left to wipe")
		return

	// Latch BEFORE the killing starts. The replenisher runs on its own once-a-minute frame and
	// would otherwise deal latejoiners onto this hull while it is being emptied, leaving it
	// crewed, never abandoned, and the wipe measuring nothing.
	wiped_hulls[victim] = TRUE

	var/killed = 0
	for(var/mob/living/carbon/human/crewmate as anything in GLOB.ghost_round_crew)
		if(QDELETED(crewmate) || crewmate.stat == DEAD)
			continue
		if(GLOB.ghost_round_crew[crewmate] != victim)
			continue
		crewmate.death()
		killed++
		CHECK_TICK
	crews_wiped++
	beat("CREW WIPE: '[victim.name]' lost all [killed] crew - handing it to the derelict pipeline")

	// Rewind the clocks so the production sweep does the work on its own schedule instead of
	// the driver reaching past it. crewless_since is set by the sweep itself for a hull with no
	// event crew; pre-setting it past SHIP_CREWLESS_ABANDON_TIME means its very next pass
	// abandons the hull, and the same trick on abandoned_at brings the despawn forward.
	victim.crewless_since = world.time - SHIP_CREWLESS_ABANDON_TIME - 10
	INVOKE_ASYNC(src, PROC_REF(watch_derelict), victim)

/// Follows one wiped hull through abandonment and despawn, rewinding the second clock once the
/// first has fired, and reports what the production pipeline actually did.
/datum/controller/subsystem/ghost_round/proc/watch_derelict(obj/structure/overmap/ship/hull)
	var/deadline = world.time + 12 MINUTES
	var/announced_abandon = FALSE
	// Read the class NOW: once the hull is deleted, source_template goes with it.
	var/despawning_class = hull_class(hull)
	while(running && world.time < deadline)
		if(QDELETED(hull))
			ships_despawned++
			tally_class(despawning_class, "despawned")
			beat("DERELICT DESPAWNED: a wiped hull of class '[despawning_class]' went all the way out ([live_summary()])")
			return
		if(hull.abandoned && !announced_abandon)
			announced_abandon = TRUE
			beat("DERELICT: '[hull.name]' abandoned by SSovermap.sweep_derelicts()")
			hull.abandoned_at = world.time - SHIP_DERELICT_DESPAWN_TIME - 10
		sleep(20 SECONDS)
	if(!QDELETED(hull))
		ghost_log("WARN: '[hull.name]' was still resident 12 minutes after its crew was wiped (abandoned=[hull.abandoned ? "yes" : "no"], docked=[hull.docked ? "yes" : "no"])")

/**
 * One vestige ascension arena, driven the way the churn soak drives it: the run datum's own
 * load_arena() plus the boss on its landmark. Production entry (offer_ascension) needs a mind,
 * a tgui_alert and a completed soul record, none of which a clientless world can produce.
 *
 * It is here for the allocation, not the fight: a reservation, a static .dmm and a boss mob
 * resident alongside everything else for the rest of the round.
 */
/datum/controller/subsystem/ghost_round/proc/open_arena()
	var/datum/vestige_ascension/offer = get_vestige_ascension(/mob/living/basic/vestige_patron/magister)
	if(!offer)
		ghost_log("WARN: no ascension offer is hosted by the magister - skipping the arena")
		return
	var/datum/vestige_ascension_run/run = new(offer, null)
	var/datum/map_template/vestige_arena/template = new offer.template_type()
	var/list/window = record_load_start("arena", offer.name, "peak")
	var/opened = run.load_arena(template)
	qdel(template)
	record_load_end(window, 0, opened)
	if(!opened)
		qdel(run)
		ghost_log("WARN: the ascension arena failed to open")
		return
	var/turf/boss_spot = run.pick_landmark(/obj/effect/landmark/vestige_arena/boss)
	if(boss_spot)
		run.boss = new offer.boss_type(boss_spot)
	arena = run
	beat("ascension arena '[offer.name]' opened ([run.reservation.width]x[run.reservation.height] reservation, boss [offer.boss_type])")

/// Holds the concurrency floors, retires the ghosted dead, and tops the crew up, on a slow
/// loop, for the rest of the round.
/datum/controller/subsystem/ghost_round/proc/site_keeper()
	while(running)
		sleep(60 SECONDS)
		if(!running)
			return
		hold_concurrency_floor()
		retire_the_dead()
		// In sustained mode the replenisher owns crew top-up on its own frame; calling it from
		// here as well would deal two batches a minute and overshoot the target.
		if(sustain)
			continue
		// No replacements during attrition - the wipes are the measurement there.
		if(SSghost_sampler.phase_label != "attrition")
			top_up_crew()

/**
 * Drops crew who have been dead for a while out of the sim-crew registry: the player ghosted.
 *
 * This is not tidying, it is a correctness fix, and getting it wrong deadlocks the attrition
 * phase. despawn_derelict()'s guard - and therefore the shim mirroring it - counts DEAD bodies
 * as blocking, on purpose: in production those are bodies a player is still sitting in, and one
 * may be mid-rescue. A player who has given up presses ghost, their body loses its client, and
 * it stops blocking. Sim crew have no ghost to press, so the registry has to model it - without
 * this, a hull whose crew was wiped is held by its own corpses and never reaches despawn, and
 * the whole attrition phase measures nothing.
 *
 * The BODIES stay exactly where they fell. Corpses are part of a round and they are left as
 * content: they still occupy turfs, still hold items, still rot. What is dropped is only the
 * claim that a live player is behind them.
 *
 * update_z(null) on the way out because the mob is leaving the shim's care: without it a corpse
 * keeps a clients_by_zlevel registration, which would hold that z's fauna AI awake forever.
 */
/datum/controller/subsystem/ghost_round/proc/retire_the_dead()
	var/retired = 0
	// Iterate a COPY: this is the only proc that removes from the registry, and removing the
	// current entry from the list being iterated shifts it and silently skips the next one.
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew.Copy())
		if(QDELETED(sim))
			GLOB.ghost_round_crew -= sim
			continue
		if(sim.stat != DEAD)
			continue
		// timeofdeath is world.time at death; two minutes is roughly how long a player stares
		// at the death screen before ghosting.
		if(sim.timeofdeath && (world.time - sim.timeofdeath) < (2 MINUTES))
			continue
		GLOB.ghost_round_crew -= sim
		sim.update_z(null)
		retired++
	if(retired)
		ghost_log("[retired] dead crew ghosted out of the sim registry (bodies left where they fell)")

/**
 * Sleeps until T+`minute`, stamping progress so the watchdog can tell slow from dead.
 *
 * Clamped to the round budget. Without the clamp a reduced-budget run (the smoke) would sit in
 * phase_peak's hold until T+40 on a twelve-minute budget and be reaped by the shell script's
 * timeout with no profile - the phases would outlive the round they are phases of.
 */
/datum/controller/subsystem/ghost_round/proc/hold_until(minute, label)
	var/target = min(started_worldtime + (minute MINUTES), started_worldtime + (budget_min MINUTES))
	while(running && world.time < target)
		mark_progress("[label] (T+[elapsed_min()]m of [minute]m)")
		sleep(20 SECONDS)

/**
 * Phase boundaries, scaled to the round budget.
 *
 * The constants are written for the seventy-minute round the scenario describes; a reduced
 * smoke run wants the same SHAPE at a smaller scale, not the same absolute minute marks. So the
 * boundaries are expressed as fractions of the full round and multiplied back out - a twelve
 * minute smoke gets launch/peak/attrition at 1.7/6.9/10.3 minutes, which exercises every
 * transition instead of never leaving phase one.
 */
/datum/controller/subsystem/ghost_round/proc/phase_end(full_round_minute)
	// In sustained mode the constants are absolute minutes, not fractions of the budget: the
	// launch phase is ten minutes whether the round is seventy minutes or three hours, because
	// it is bounded by how long twelve template loads take, not by how long the round is.
	if(sustain)
		return full_round_minute
	return budget_min * (full_round_minute / GHOST_BUDGET_MIN_DEFAULT)

// ---------------------------------------------------------------------------------------
// Sustained mode
// ---------------------------------------------------------------------------------------

/**
 * The rest of the round, after launch, for as long as the budget lasts.
 *
 * Independent clocks, all checked against world.time rather than counted in sleeps, so a slow
 * tick slides the schedule instead of silently dropping events:
 *
 *   BURSTS  - LEGACY REGIMES ONLY. The same five-site composition that failed on the 70-minute
 *             run (2 ruins + 2 fields + 1 planet), on the burst clock. This is the repeated
 *             confirmation vehicle for the worldgen queue-timeout fix, and firing it several
 *             times in one round is worth more than firing it once: the prediction is 5/5 ok
 *             EVERY time. The real regime replaces it with the trickle, and gets its one
 *             queue-coupling reading from phase_launch's `early-quiet` burst instead.
 *   TRICKLE - REAL REGIME ONLY. The next site load scheduled on a randomized interval whose
 *             median is ~1.9 minutes, which is what a real round's worldgen actually looks
 *             like. See THE SITE-LOAD TRICKLE.
 *   FOUND   - one hull founded on the clock, whether or not the fleet is short.
 *   WIPES   - a crew wiped on the clock, first one held back until the fleet is up to speed.
 *             Each one goes through the real derelict pipeline while every other site stays
 *             occupied.
 *   HOUR    - the sampler's phase label tracks the wall hour, which is what the hour-over-hour
 *             trend table in the final profile is cut on.
 *
 * Everything else - site rotation, the concurrency floors, crew top-up, storms, pirates - is
 * already running on its own loops from the launch phase and simply keeps going.
 */
/datum/controller/subsystem/ghost_round/proc/sustain_loop()
	var/real_regime = (regime == GHOST_REGIME_REAL)
	var/burst_every = GHOST_SUSTAIN_BURST_EVERY * churn_scale
	var/found_every = real_regime ? GHOST_REAL_FOUND_EVERY : (GHOST_SUSTAIN_FOUND_EVERY * churn_scale)
	var/wipe_every = real_regime ? GHOST_REAL_WIPE_EVERY : (GHOST_SUSTAIN_WIPE_EVERY * churn_scale)
	var/next_burst = started_worldtime + GHOST_SUSTAIN_BURST_FIRST
	var/next_wipe = started_worldtime + (real_regime ? GHOST_REAL_WIPE_FIRST : GHOST_SUSTAIN_WIPE_FIRST)
	var/next_found = started_worldtime + (real_regime ? GHOST_REAL_FOUND_FIRST : GHOST_SUSTAIN_FOUND_FIRST)
	// Relative to NOW, not to the round start: the launch phase has already run, and a schedule
	// anchored at T+0 would fire its whole backlog in one tick, which is the burst shape the
	// trickle exists to get rid of.
	var/next_trickle = world.time + trickle_interval()
	var/burst_index = 0
	var/finish_at = started_worldtime + (budget_min MINUTES)

	if(real_regime)
		beat("=== SUSTAINED ROUND: [budget_min] minutes, regime REAL - cadences calibrated to production round-7 (70 players, 2026-08). Fleet [ships_target] (cap [GHOST_SHIPS_HARD_CAP]) / crew [crew_target]; one hull founded every [found_every / 600]m (measured 12.1/h), one crew wiped every [wipe_every / 600]m from T+[GHOST_REAL_WIPE_FIRST / 600]m (measured 4.2 hull losses/h, first real loss +45..76m), and site loads on a CONTINUOUS TRICKLE - median gap ~1.9m, [100 - GHOST_REAL_TRICKLE_PAIR_PCT - GHOST_REAL_TRICKLE_TRIPLE_PCT]% single / [GHOST_REAL_TRICKLE_PAIR_PCT]% pair / [GHOST_REAL_TRICKLE_TRIPLE_PCT]% triple, mix [GHOST_REAL_MIX_PLANET_PCT]% planet / [100 - GHOST_REAL_MIX_PLANET_PCT - GHOST_REAL_MIX_FIELD_PCT]% ruin / [GHOST_REAL_MIX_FIELD_PCT]% field - instead of worldgen bursts (measured ~32 site loads/h of which ~5/h are planet builds). ===")
	else
		beat("=== SUSTAINED ROUND: [budget_min] minutes, regime [uppertext(regime)] (churn_scale [churn_scale]) - fleet [ships_target] (cap [GHOST_SHIPS_HARD_CAP]) / crew [crew_target], founding wave every [found_every / 600]m, worldgen burst every [burst_every / 600]m, crew wipe every [wipe_every / 600]m, mission dwell x[dwell_scale()]. MEASURED INTENSITY, not the old '3x/1x ordinary' labels: churn_scale 1 is ~1.2x a real 70-player round and churn_scale 3 is ~0.7x (production round-7, 2026-08); both were ~0.79x on site loads before the dwell was scaled with everything else. ===")

	while(running && world.time < finish_at)
		mark_progress("sustain (T+[elapsed_min()]m of [budget_min]m)")
		update_hour_label()

		// The trickle REPLACES the burst clock; a regime never runs both.
		if(real_regime)
			if(world.time >= next_trickle && (finish_at - world.time) > (3 MINUTES))
				next_trickle = world.time + trickle_interval()
				site_trickle()
				continue
		else if(world.time >= next_burst && (finish_at - world.time) > (6 MINUTES))
			burst_index++
			next_burst = world.time + burst_every
			// Deliberately the exact composition of the 70-minute run's failing burst.
			fire_burst("burst-[burst_index]", 2, 2, 1)
			continue

		if(world.time >= next_found && (finish_at - world.time) > (5 MINUTES))
			next_found = world.time + found_every
			founding_wave()
			continue

		if(world.time >= next_wipe && (finish_at - world.time) > (5 MINUTES))
			next_wipe = world.time + wipe_every
			wipe_a_crew()
			continue

		// Coarser in the legacy regimes, where the nearest clock is minutes away. The trickle's
		// median gap is 114 seconds, and quantising that to 30-second steps would flatten a
		// distribution that was fitted to a tenth of a minute.
		sleep(real_regime ? (10 SECONDS) : (30 SECONDS))

	var/closing = "=== SUSTAINED ROUND COMPLETE: [burst_index] worldgen burst\s, [crews_wiped] crew wipe\s, [hulls_refounded] hull\s founded, [crew_replaced] crew replaced, [site_loads] site load\s, [site_teardowns] site teardown\s"
	if(real_regime)
		var/elapsed_hours = max((world.time - started_worldtime) / 36000, 0.01)
		closing += " || TRICKLE: [trickle_fires] fire\s dispatched [trickle_dispatched] load\s ([num_1dp(trickle_dispatched / elapsed_hours)]/h scheduled against a measured 32.1/h), [trickle_ceiling_skips] refused at the concurrency ceiling || SLOTWAIT: [trickle_slot_waits] worker\s waited [num_1dp(trickle_slot_wait_secs)]s total ([trickle_slot_waits ? num_1dp(trickle_slot_wait_secs / trickle_slot_waits) : 0]s mean), [trickle_slot_timeouts] timed out and dropped"
	beat("[closing] ===")

/**
 * How long until the next trickle fires. See THE SITE-LOAD TRICKLE for the derivation.
 *
 * Two modes and nothing else: the common interval, and a lull. The lull is not decoration - it
 * is the only thing in the distribution that produces an empty five-minute window, and empty
 * windows are 7% of a real round.
 */
/datum/controller/subsystem/ghost_round/proc/trickle_interval()
	if(prob(GHOST_REAL_TRICKLE_LULL_PCT))
		return rand(GHOST_REAL_TRICKLE_LULL_MIN, GHOST_REAL_TRICKLE_LULL_MAX) SECONDS
	return rand(GHOST_REAL_TRICKLE_MIN, GHOST_REAL_TRICKLE_MAX) SECONDS

/**
 * One trickle fire: usually one site, occasionally two or three in the same tick.
 *
 * The loads go out through INVOKE_ASYNC, exactly as fire_burst()'s workers do, for two reasons.
 * A planet build blocks for a minute or more, and a scheduler that waited for it would have that
 * minute silently added to the next interval - the cadence would drift long every time a planet
 * came up, which is precisely the distribution this is trying to hold. And a cluster is supposed
 * to be simultaneous: two sites loading side by side is the thing being modelled, not two loading
 * back to back.
 */
/datum/controller/subsystem/ghost_round/proc/site_trickle()
	trickle_fires++
	var/roll = rand(1, 100)
	var/wanted = 1
	if(roll <= GHOST_REAL_TRICKLE_TRIPLE_PCT)
		wanted = 3
	else if(roll <= GHOST_REAL_TRICKLE_TRIPLE_PCT + GHOST_REAL_TRICKLE_PAIR_PCT)
		wanted = 2

	var/list/placed = list()
	var/refused = 0
	for(var/i in 1 to wanted)
		var/kind = trickle_pick_kind()
		if(!kind)
			refused++
			continue
		trickle_inflight[kind] += 1
		trickle_dispatched++
		placed += kind
		INVOKE_ASYNC(src, PROC_REF(trickle_worker), kind)
	if(refused)
		trickle_ceiling_skips += refused
	// One line per fire, so the realized cadence can be reconstructed from the transcript and
	// compared against the fitted one without needing the load windows.
	ghost_log("TRICKLE fire [trickle_fires]: wanted [wanted], dispatched [length(placed)] ([length(placed) ? jointext(placed, "+") : "none"])[refused ? ", [refused] refused at the ceiling" : ""]")
	if(wanted > 1 && length(placed) > 1)
		beat("TRICKLE cluster: [length(placed)] site\s ([jointext(placed, " + ")]) loading in the same tick")

/**
 * Which kind this trickle load should be, or null if every kind is at its ceiling.
 *
 * The mix is drawn first and the ceiling checked second, with the other two kinds as fallbacks
 * in a sensible order. That ordering matters: refusing outright whenever the drawn kind is full
 * would silently convert a ceiling on ONE kind into a cut in the TOTAL site-load rate, and the
 * total rate is the headline number this regime exists to reproduce.
 *
 * In-flight loads count against the ceiling. The workers are async, so two fires in the same
 * second would otherwise both read the same pre-load live count and both pass.
 */
/datum/controller/subsystem/ghost_round/proc/trickle_pick_kind()
	var/roll = rand(1, 100)
	var/list/order
	if(roll <= GHOST_REAL_MIX_PLANET_PCT)
		order = list("planet", "ruin", "field")
	else if(roll <= GHOST_REAL_MIX_PLANET_PCT + GHOST_REAL_MIX_FIELD_PCT)
		order = list("field", "ruin", "planet")
	else
		order = list("ruin", "field", "planet")
	var/list/live = live_site_counts()
	for(var/kind in order)
		if((live[kind] + trickle_inflight[kind]) < site_cap_for(kind))
			return kind
	return null

/// One trickle load, in its own frame. The stand_up_* procs are the SAME ones the bursts and the
/// mission claims use - the trickle changes when a load happens, never what a load is.
///
/// When the lattice is full (the z ceiling engaged and no free slot of the kind's class) the
/// worker WAITS for capacity rather than attempting a load that must fail: that is what the
/// production refusal means - site_load_refused_for_capacity() tells the waiting ship "not
/// right now" and the ship stays on the chart and re-asks. The wait's length is logged per
/// worker (SLOTWAIT lines) and totalled in the closing line, because "how long did production
/// demand wait for the packed world" is the headline measurement of a ceiling-riding run.
/// Patience is bounded: a worker that outlives GHOST_TRICKLE_SLOT_PATIENCE drops its load and
/// counts a timeout, so unmet demand is a number rather than a pile of immortal waiters.
/datum/controller/subsystem/ghost_round/proc/trickle_worker(kind)
	var/deadline = world.time + GHOST_TRICKLE_SLOT_PATIENCE
	var/waited_from = 0
	var/site = null
	while(running)
		if(site_capacity_available(kind))
			switch(kind)
				if("planet")
					site = stand_up_planet("trickle")
				if("ruin")
					site = stand_up_ruin("trickle")
				if("field")
					site = stand_up_field("trickle")
			if(site)
				break
			// Capacity said yes but the load still failed. Below the ceiling that is a
			// genuine failure - stand_up_* already logged it loud, and it stays a one-shot
			// exactly as in runs 1-5. At the ceiling it is almost always the slot being
			// sniped between the check and the claim by another worker or a mission mint,
			// so it re-enters the wait rather than dropping the fire.
			if(!SSmapping.at_z_level_ceiling())
				break
		else if(!waited_from)
			waited_from = world.time
			trickle_slot_waits++
			ghost_log("SLOTWAIT kind=[kind] began - world.maxz at its ceiling and no free '[kind == "planet" ? "planet" : "flat"]' slot")
		if(world.time >= deadline)
			break
		sleep(GHOST_TRICKLE_SLOT_RETRY)
	if(waited_from)
		var/waited_s = (world.time - waited_from) / 10
		trickle_slot_wait_secs += waited_s
		if(site)
			ghost_log("SLOTWAIT kind=[kind] ended after [num_1dp(waited_s)]s - slot freed, loaded")
		else
			trickle_slot_timeouts++
			ghost_log("SLOTWAIT kind=[kind] TIMEOUT after [num_1dp(waited_s)]s - patience exhausted, load dropped")
	trickle_inflight[kind] = max(trickle_inflight[kind] - 1, 0)

/**
 * A scheduled latejoin wave: a new hull and its crew, on the clock, whether or not the fleet is
 * short.
 *
 * This is the half of a live server the shortfall-driven replenisher does not model. Players do
 * not only replace losses - they found ships because they want one, and a seventy-player server
 * gains hulls through the round independently of how many it has lost. At this cadence it is
 * also the main source of hull churn, which is what makes template loads, transit reservations,
 * pipenets and area sets cycle fast enough to be a leak detector.
 *
 * The hard cap is what keeps this a seventy-player round rather than a fleet-growth experiment:
 * above GHOST_SHIPS_HARD_CAP the wave is skipped and the shortfall replenisher continues to be
 * the only source of new hulls.
 */
/datum/controller/subsystem/ghost_round/proc/founding_wave()
	var/live = live_hull_count()
	var/resident = resident_hull_count()
	if(live >= GHOST_SHIPS_HARD_CAP || resident >= GHOST_SHIPS_HARD_CAP)
		ghost_log("founding wave skipped - fleet at the hard cap ([live] live, [resident] resident incl. derelicts, cap [GHOST_SHIPS_HARD_CAP])")
		return
	last_refound = world.time
	hulls_refounded++
	var/obj/structure/overmap/ship/hull = found_hull_from_rotation("latejoin founding wave #[hulls_refounded] (fleet was [live] of [ships_target], cap [GHOST_SHIPS_HARD_CAP])")
	if(!istype(hull))
		ghost_log("WARN: founding wave could not found a hull (fleet at [live])")
		return
	crew_one_hull(hull)
	INVOKE_ASYNC(src, PROC_REF(mission_loop), hull, hulls_refounded)

/**
 * The hull-class rotation: every purchasable class, ordered so consecutive foundings alternate
 * small and large.
 *
 * `SSovermap.spawn_free_hull()` draws at random from `get_roundstart_hull_templates()`, which is
 * the STRICTER pool - modular hulls with upgrade slots only - and once that pool is exhausted it
 * re-picks from it uniformly. Over a three-hour run that gives a handful of classes over and
 * over and leaves most of the catalogue untouched. Hull classes differ enormously in turf count,
 * pipenet and atmos complexity, machinery load and berth footprint, so a mono-class fleet
 * under-tests exactly the teardown and memory variance this run exists to measure.
 *
 * So the harness rotates the full `is_player_purchasable_ship()` catalogue itself, and founds
 * through `SSshuttle.create_ship()` - the same proc `spawn_free_hull()` calls, with the same
 * random theme and random module roll, just choosing the class deterministically instead of
 * uniformly.
 *
 * ORDERING: cost-sorted (total part cost is the best available size proxy), then zipped
 * cheapest-most-expensive-second-cheapest-second-most-expensive. Two consequences, both wanted:
 * one full pass founds every class exactly once, and the live fleet is always a mix of sizes
 * rather than drifting into all-small or all-large.
 */
/datum/controller/subsystem/ghost_round/proc/build_hull_rotation()
	ensure_ship_catalog_initialized()
	var/list/by_cost = list()
	var/list/rejected = list()
	for(var/datum/map_template/shuttle/voidcrew/template as anything in GLOB.ship_catalog_templates)
		if(!is_player_purchasable_ship(template))
			continue
		// Curated oddities are on the shelf but are not fleet hulls, and the codebase says so
		// itself: is_roundstart_eligible_hull_type() excludes force_purchasable specifically so
		// that "the curated force_purchasable oddities (the pills) stay on the shelf but off the
		// starting line". The first 3-hour launch proved why - three Pill-class hulls were
		// founded and every one of them had NO OPEN TURF ABOARD, so it could take no thruster
		// ("it will fly on whatever the template gave it"), no crew, and could not move
		// ("ERROR: No engine power"). They still counted toward live_hull_count(), which
		// suppressed the shortfall replenisher, and they burned a mission frame each spinning on
		// an autopilot that could never engage. Two of seven rotation slots were dead weight.
		if(template.force_purchasable)
			rejected += "[template.name] (curated oddity)"
			continue
		// A hull with no upgrade slots has no modules to roll and is a legacy fixed hull.
		if(!length(template.upgrade_slot_ids))
			rejected += "[template.name] (no upgrade slots)"
			continue
		by_cost[template] = ship_template_total_part_cost(template)
	if(!length(by_cost))
		ghost_log("WARN: the ship catalogue offered no purchasable hulls - falling back to spawn_free_hull()")
		return
	sortTim(by_cost, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE)

	var/list/ordered = list()
	for(var/datum/map_template/shuttle/voidcrew/template as anything in by_cost)
		ordered += template

	// Zip the ends together: cheapest, dearest, next cheapest, next dearest...
	hull_rotation = list()
	var/low = 1
	var/high = length(ordered)
	while(low <= high)
		hull_rotation += ordered[low]
		if(low != high)
			hull_rotation += ordered[high]
		low++
		high--

	var/list/names = list()
	for(var/datum/map_template/shuttle/voidcrew/template as anything in hull_rotation)
		names += "[template.name] ([by_cost[template]])"
	ghost_log("HULL ROTATION built: [length(hull_rotation)] fleet-worthy class\s, alternating cheap/expensive - [jointext(names, ", ")]")
	if(length(rejected))
		ghost_log("HULL ROTATION rejected [length(rejected)] catalogue entr\s: [jointext(rejected, ", ")]")

/// The next class in the rotation, cycling forever.
/datum/controller/subsystem/ghost_round/proc/next_hull_template()
	if(!length(hull_rotation))
		build_hull_rotation()
	if(!length(hull_rotation))
		return null
	rotation_index++
	if(rotation_index > length(hull_rotation))
		rotation_index = 1
	return hull_rotation[rotation_index]

/**
 * Founds one hull of the next class in the rotation, through the production path.
 *
 * Mirrors `spawn_free_hull()`'s body exactly - roll a theme, roll a module for every slot, hand
 * the TYPE PATH (not the catalogue instance, which create_ship rewrites) to create_ship - with
 * the class chosen by the rotation instead of at random. Falls back to spawn_free_hull() if the
 * catalogue is unavailable, so a broken rotation degrades to the old behaviour rather than
 * stopping the round.
 */
/datum/controller/subsystem/ghost_round/proc/found_hull_from_rotation(provenance)
	var/datum/map_template/shuttle/voidcrew/template = next_hull_template()
	if(!template)
		var/obj/structure/overmap/ship/fallback = SSovermap.spawn_free_hull(track_as_initial = FALSE)
		if(istype(fallback))
			register_hull(fallback, "[provenance] (rotation unavailable, random draw)")
		return fallback

	var/datum/ship_theme/theme = roll_random_ship_theme(template.type)
	var/list/selections = roll_random_upgrade_selections(template, theme)
	var/obj/structure/overmap/ship/hull = SSshuttle.create_ship(template.type, selections, theme)
	if(!istype(hull))
		ghost_log("WARN: create_ship() returned nothing for [template.name] - skipping this rotation slot")
		return null

	// Safety net for anything the catalogue filter did not catch. A hull with no open turf
	// aboard cannot take a thruster, cannot take crew and cannot fly, but it WOULD still count
	// toward live_hull_count() and suppress the shortfall replenisher, and it would hold a
	// mission frame spinning on an autopilot that can never engage. Drop the class from the
	// rotation so it is never founded again, and take the hull straight back out.
	if(!hull.get_random_open_ship_turf())
		ghost_log("WARN: '[hull.name]' ([template.name]) has no open turf aboard - it cannot be crewed or flown. Dropping the class from the rotation and destroying the hull.")
		hull_rotation -= template
		if(rotation_index > length(hull_rotation))
			rotation_index = 0
		hull.destroy_ship(force = TRUE, ignore_crew = TRUE)
		return null

	register_hull(hull, provenance)
	return hull

/**
 * Counts sites that were loaded on the previous keeper pass and are not loaded now.
 *
 * There is no signal for "a site released itself" that covers all three kinds, and watching for
 * one per site would mean registering and unregistering across three lifecycles. A once-a-minute
 * set difference is cheap, needs no hooks, and cannot miss a teardown that lasts longer than a
 * minute - which all of them do. It CAN miss a load-and-release inside one minute; at this churn
 * rate that is possible, so the count is a floor, and it is labelled as one in the report.
 */
/datum/controller/subsystem/ghost_round/proc/count_teardowns()
	var/list/loaded_now = list()
	for(var/obj/structure/overmap/site as anything in (site_planets + site_ruins + site_fields))
		if(QDELETED(site) || !site_is_loaded(site))
			continue
		loaded_now[site] = TRUE
	for(var/site in loaded_last_pass)
		if(!loaded_now[site])
			site_teardowns++
	loaded_last_pass = loaded_now

/// Per-class bookkeeping, so hull-class coverage is provable rather than asserted.
/datum/controller/subsystem/ghost_round/proc/tally_class(class_name, outcome)
	if(!class_name)
		class_name = "unknown"
	var/list/counts = class_tally[class_name]
	if(!counts)
		counts = list("founded" = 0, "killed" = 0, "despawned" = 0)
		class_tally[class_name] = counts
	counts[outcome] += 1

/// The class name of a hull, for logging and tallies.
/datum/controller/subsystem/ghost_round/proc/hull_class(obj/structure/overmap/ship/hull)
	if(QDELETED(hull))
		return "unknown"
	return hull.source_template ? hull.source_template.name : "unknown"

/// Player hulls that are alive, loaded and not abandoned.
/datum/controller/subsystem/ghost_round/proc/live_hull_count()
	. = 0
	for(var/obj/structure/overmap/ship/hull as anything in player_ships)
		if(QDELETED(hull) || !hull.shuttle || hull.abandoned)
			continue
		.++

/**
 * Every player hull still resident, INCLUDING abandoned derelicts awaiting despawn.
 *
 * `live_hull_count()` deliberately excludes abandoned hulls so the replenisher replaces them -
 * but an abandoned hull is still a fully loaded shuttle occupying turfs, pipenets, areas and a
 * transit reservation until the sweep finishes with it. Counting only the live ones let the
 * first 3-hour run reach 27-31 resident hulls against a fleet target of 12, because every wipe
 * created a replacement while the derelict was still costing everything a hull costs.
 *
 * The replenisher is gated on this total, so the round holds a bounded amount of hull, not a
 * bounded amount of *crewed* hull.
 */
/datum/controller/subsystem/ghost_round/proc/resident_hull_count()
	. = 0
	for(var/obj/structure/overmap/ship/hull as anything in player_ships)
		if(QDELETED(hull) || !hull.shuttle)
			continue
		.++

/// Names the sampler's current phase after the wall hour, so the final profile can cut
/// hour-over-hour windows out of the 1 Hz series with the same machinery the 70-minute run
/// used for launch/peak/attrition.
/datum/controller/subsystem/ghost_round/proc/update_hour_label()
	if(!sustain)
		return
	var/elapsed = world.time - started_worldtime
	if(elapsed < (GHOST_PHASE_LAUNCH_END MINUTES))
		SSghost_sampler.phase_label = "launch"
		return
	SSghost_sampler.phase_label = "hour[1 + round(elapsed / (60 MINUTES))]"

/**
 * Keeps the fleet and the crew at their targets for the whole round.
 *
 * A three-hour round that starts with twelve hulls and seventy crew and is never topped up
 * ends with neither, and its third hour measures a nearly empty server - which would answer
 * "does hour 3 look like hour 1" with an artifact of the script rather than a property of the
 * game. Real servers replace losses: players found a new ship and latejoin onto it.
 *
 * Both replacements go through the SAME production paths as the originals -
 * SSovermap.spawn_free_hull(track_as_initial = FALSE) is the join menu's requisition proc, and
 * make_crewmate() is the same one the launch phase used - so a hull founded at minute 150 is
 * indistinguishable from one founded at minute 3.
 *
 * Rate-capped at one hull per GHOST_REFOUND_COOLDOWN. Uncapped, a patch of bad attrition
 * becomes a template-load storm, and the round would measure the replenisher.
 *
 * What is NOT cleaned up: corpses and despawned derelicts. Their accumulation is the thing
 * under test.
 */
/datum/controller/subsystem/ghost_round/proc/replenisher()
	while(running)
		sleep(60 SECONDS)
		if(!running)
			return
		mark_progress("replenishing (T+[elapsed_min()]m)")
		replenish_hulls()
		top_up_crew()

/// Founds at most one replacement hull per call, respecting the rate cap, and puts it straight
/// to work with its own crew and its own mission frame.
/datum/controller/subsystem/ghost_round/proc/replenish_hulls()
	var/live = 0
	for(var/obj/structure/overmap/ship/hull as anything in player_ships)
		if(QDELETED(hull) || !hull.shuttle || hull.abandoned)
			continue
		live++
	if(live >= ships_target)
		return
	// Derelicts awaiting despawn still cost everything a hull costs; do not stack replacements
	// on top of them.
	if(resident_hull_count() >= GHOST_SHIPS_HARD_CAP)
		return
	if(last_refound && (world.time - last_refound) < GHOST_REFOUND_COOLDOWN)
		return

	// Drop the dead out of the fleet list first, or it grows nulls for three hours and `live`
	// above has to keep re-filtering them.
	player_ships -= null
	for(var/obj/structure/overmap/ship/hull as anything in player_ships.Copy())
		if(QDELETED(hull))
			player_ships -= hull

	last_refound = world.time
	hulls_refounded++
	var/obj/structure/overmap/ship/replacement = found_hull_from_rotation("replacement hull #[hulls_refounded] (fleet was [live] of [ships_target])")
	if(!istype(replacement))
		ghost_log("WARN: replenisher could not found a replacement hull (fleet at [live] of [ships_target])")
		return
	// Crew it and send it out. Without its own mission frame a replacement hull sits at its
	// founding square doing nothing, which is worse than not founding it at all.
	crew_one_hull(replacement)
	INVOKE_ASYNC(src, PROC_REF(mission_loop), replacement, hulls_refounded)

/// Deals one hull's worth of crew onto a single hull. Used by the replenisher, which must not
/// call crew_the_fleet() - that fills to the FLEET target and would put a whole complement on
/// one new ship.
/datum/controller/subsystem/ghost_round/proc/crew_one_hull(obj/structure/overmap/ship/hull)
	// Respect the fleet-wide crew target. Without this check every founding adds 4-8 crew
	// unconditionally, and the first 3-hour run drifted from 70 to 106 living crew because
	// ~30 hulls were founded across two hours - inflating mob count, AI cost and memory well
	// past the scenario the profile is reported against.
	var/alive = 0
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(!QDELETED(sim) && sim.stat != DEAD)
			alive++
	if(alive >= crew_target)
		return 0
	var/wanted = min(rand(GHOST_CREW_MIN_PER_SHIP, GHOST_CREW_MAX_PER_SHIP), crew_target - alive)
	var/added = 0
	for(var/i in 1 to wanted)
		if(make_crewmate(hull))
			added++
	crew_replaced += added
	if(added)
		beat("[added] crew joined the replacement hull '[hull.name]'")
	return added

/datum/controller/subsystem/ghost_round/proc/live_summary()
	var/list/live = live_site_counts()
	return "planets [live["planet"]], ruins [live["ruin"]], fields [live["field"]], crash sites [live["crash"]], hulls [length(SSovermap.simulated_ships)]"

// ---------------------------------------------------------------------------------------
// Recorders
// ---------------------------------------------------------------------------------------

/**
 * Closes one profile bucket every minute for the first quarter of an hour, then every five.
 *
 * The fine early buckets are where the load storm lives - twelve template loads, the founding
 * burst and the first wave of site builds all land inside fifteen minutes, and a five-minute
 * bucket averages that into nothing.
 */
/datum/controller/subsystem/ghost_round/proc/bucket_recorder()
	var/bucket_start = world.time
	while(running)
		var/fine = (world.time - started_worldtime) < (15 MINUTES)
		var/width = fine ? (1 MINUTES) : (5 MINUTES)
		var/close_at = bucket_start + width
		while(running && world.time < close_at)
			sleep(10 SECONDS)
		close_bucket(bucket_start, min(world.time, close_at))
		bucket_start = world.time
	close_bucket(bucket_start, world.time)

/datum/controller/subsystem/ghost_round/proc/close_bucket(from_time, to_time)
	if(to_time <= from_time)
		return
	var/list/td = SSghost_sampler.window_stats(from_time, to_time, SSghost_sampler.sample_td)
	var/list/tick = SSghost_sampler.window_stats(from_time, to_time, SSghost_sampler.sample_tick)
	var/list/cpu = SSghost_sampler.window_stats(from_time, to_time, SSghost_sampler.sample_cpu)
	if(!td)
		return
	var/list/live = live_site_counts()
	var/crew_alive = 0
	var/crew_dead = 0
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(QDELETED(sim))
			continue
		if(sim.stat == DEAD)
			crew_dead++
		else
			crew_alive++
	var/list/row = list(
		"from_min" = round((from_time - started_worldtime) / 60) / 10,
		"to_min" = round((to_time - started_worldtime) / 60) / 10,
		// world.realtime so the shell script's memory CSV can be joined onto these buckets.
		"realtime" = world.realtime,
		"phase" = SSghost_sampler.phase_label,
		"td_avg" = td["avg"],
		"td_p95" = td["p95"],
		"td_max" = td["max"],
		"td_over_105" = SSghost_sampler.window_td_share(from_time, to_time, 5),
		"td_over_125" = SSghost_sampler.window_td_share(from_time, to_time, 25),
		"td_over_200" = SSghost_sampler.window_td_share(from_time, to_time, 100),
		"tick_avg" = tick ? tick["avg"] : 0,
		"tick_p95" = tick ? tick["p95"] : 0,
		"tick_max" = tick ? tick["max"] : 0,
		"cpu_avg" = cpu ? cpu["avg"] : 0,
		"planets" = live["planet"],
		"ruins" = live["ruin"],
		"fields" = live["field"],
		"crashes" = live["crash"],
		"arenas" = live["arena"],
		"ships" = length(SSovermap.simulated_ships),
		"npc" = length(SSnpc_ships.active_ships),
		"crew_alive" = crew_alive,
		"crew_dead" = crew_dead,
		"mobs" = length(GLOB.mob_list),
		"maxz" = world.maxz,
		"contents" = world.contents.len,
		"ai_on" = length(GLOB.ai_controllers_by_status[AI_STATUS_ON]),
		// Cumulative churn, snapshotted so the hour trend can diff consecutive hours and put the
		// intensity of the round next to its cost.
		"c_loads" = site_loads,
		"c_teardowns" = site_teardowns,
		"c_found" = hulls_founded_total,
		"c_kills" = hull_kills,
		"c_wipes" = crews_wiped,
		"c_despawns" = ships_despawned,
	)
	buckets += list(row)
	ghost_log("BUCKET [row["from_min"]]-[row["to_min"]]m phase=[row["phase"]] td_avg=[num_1dp(row["td_avg"])] td_p95=[num_1dp(row["td_p95"])] td_max=[num_1dp(row["td_max"])] over1.05=[num_1dp(row["td_over_105"])]% over1.25=[num_1dp(row["td_over_125"])]% over2.0=[num_1dp(row["td_over_200"])]% tick_avg=[num_1dp(row["tick_avg"])] tick_p95=[num_1dp(row["tick_p95"])] tick_max=[num_1dp(row["tick_max"])] planets=[row["planets"]] ruins=[row["ruins"]] fields=[row["fields"]] crash=[row["crashes"]] arena=[row["arenas"]] ships=[row["ships"]] npc=[row["npc"]] crew=[row["crew_alive"]]/[row["crew_alive"] + row["crew_dead"]] mobs=[row["mobs"]] ai_on=[row["ai_on"]] maxz=[row["maxz"]] contents=[row["contents"]]")

/// One decimal place, for log lines that would otherwise carry fifteen.
/proc/num_1dp(value)
	if(isnull(value))
		return "-"
	return "[round(value * 10) / 10]"

/**
 * Writes the whole analysis periodically DURING the run, not only at the end.
 *
 * The first 3-hour run is the reason this exists. It walked into the 4 GB address-space wall at
 * T+117m, and `write_profile()` then ran *inside the OOM death spiral*: it emitted its header
 * and caveat and then reported "0 hulls founded, 0 sim crew created ... 0 beats", because at
 * 97 % of the address space the driver's own lists could no longer be read. The run's most
 * valuable outputs - the hard-delete ranking this harness was extended to produce, the
 * prediction checks, the hour trend - were all in the part that never executed.
 *
 * On a harness whose binding constraint IS memory, end-of-run analysis is the one thing that
 * cannot be relied upon. So everything cheap and valuable is written every
 * GHOST_SNAPSHOT_EVERY, and the final profile becomes a nice-to-have rather than the only copy.
 * Each snapshot is a handful of list walks and file appends.
 */
/datum/controller/subsystem/ghost_round/proc/snapshot_recorder()
	while(running)
		sleep(GHOST_SNAPSHOT_EVERY)
		if(!running)
			return
		mark_progress("mid-run snapshot (T+[elapsed_min()]m)")
		ghost_log("")
		ghost_log("=== MID-RUN SNAPSHOT T+[elapsed_min()]m (insurance against an end-of-run death) ===")
		ghost_log("populations: [resident_hull_count()] resident player hull\s ([live_hull_count()] live), [length(SSnpc_ships.active_ships)] NPC, [live_summary()]")
		var/crew_alive = 0
		var/crew_dead = 0
		for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
			if(QDELETED(sim))
				continue
			if(sim.stat == DEAD)
				crew_dead++
			else
				crew_alive++
		// ALL corpses in the world, not just registry crew: pirates, fauna, and wiped crews
		// that fell off the registry all accumulate as by-design memory and must be visible
		// per-snapshot so the growth decomposition can price them.
		var/world_corpses = 0
		for(var/mob/living/body as anything in GLOB.mob_list)
			if(!QDELETED(body) && istype(body) && body.stat == DEAD)
				world_corpses++
		ghost_log("crew: [crew_alive] alive / [crew_dead] corpses on registry (target [crew_target]); world corpses [world_corpses] (all dead /mob/living); mobs [length(GLOB.mob_list)], maxz [world.maxz], contents [world.contents.len], runtimes [GLOB.total_runtimes]")
		ghost_log("churn so far: [site_loads] site loads, [site_teardowns] teardowns, [hulls_founded_total] hulls founded, [hull_kills] kills, [crews_wiped] wipes, [ships_despawned] despawns")
		ghost_log("[subsystem_cost_line()]")
		log_prediction_checks()
		log_harddel_top(10)

/datum/controller/subsystem/ghost_round/proc/census_recorder()
	while(running)
		sleep(GHOST_CENSUS_EVERY)
		if(!running)
			return
		mark_progress("census")
		take_census_now()
		ghost_log("CENSUS taken at T+[elapsed_min()]m ([live_summary()])")

/**
 * Periodic profiler exports.
 *
 * CUMULATIVE, not per-interval - and the 70-minute run's report got this wrong. Checking the
 * dumps it actually produced, `SSair`'s `real` reads 145.3 s / 415.3 s / 670.1 s across three
 * successive files: `world.Profile(PROFILE_REFRESH)` returns totals since profiling STARTED and
 * does not zero them. So a dump is a snapshot of the whole round so far, and per-hour cost is
 * obtained by DIFFING consecutive dumps, never by reading one alone. Bracketing a burst with two
 * dumps gives two cumulative totals to subtract, not one file containing the burst.
 *
 * Hourly in sustained mode (the brief's cadence, and the natural cut for the hour-over-hour
 * table), every ten minutes on the short script.
 */
/datum/controller/subsystem/ghost_round/proc/profiler_recorder()
	while(running)
		sleep(sustain ? (60 MINUTES) : GHOST_PROFILE_EVERY)
		if(!running)
			return
		profile_dump("T+[elapsed_min()]m")

/**
 * One SSprofiler dump plus a top-cost subsystem snapshot.
 *
 * SSprofiler.DumpFile() writes world.Profile(PROFILE_REFRESH) to
 * data/logs/<run>/profiler/profiler-<t>.json - the per-proc costs, which is what makes the cost
 * of concurrent generation attributable to actual procs rather than to "worldgen".
 *
 * The dumps are CUMULATIVE - see profiler_recorder()'s note. Read any single file as "the whole
 * round up to here", and get an interval by subtracting the previous file.
 *
 * The subsystem line beside it is the cheap answer to the same question. Every subsystem tracks
 * its own `cost` (ms per run) and `tick_usage` (percent of a tick), and reading them costs
 * nothing, so the profile can name the expensive subsystems even if a profiler JSON is missing.
 */
/datum/controller/subsystem/ghost_round/proc/profile_dump(label)
	SSprofiler.DumpFile()
	ghost_log("PROFILE DUMP [label] -> [GLOB.log_directory]/profiler/ | [subsystem_cost_line()]")

/// The ten most expensive subsystems right now, by average tick usage.
/datum/controller/subsystem/ghost_round/proc/subsystem_cost_line()
	var/list/ranked = list()
	for(var/datum/controller/subsystem/subsystem as anything in Master.subsystems)
		if(!subsystem.tick_usage && !subsystem.cost)
			continue
		ranked["[subsystem.name]"] = subsystem.tick_usage
	sortTim(ranked, GLOBAL_PROC_REF(cmp_numeric_dsc), associative = TRUE)
	var/list/parts = list()
	var/shown = 0
	for(var/name in ranked)
		parts += "[name]=[num_1dp(ranked[name])]%"
		shown++
		if(shown >= 10)
			break
	return "top subsystems by tick usage: [jointext(parts, " ")]"

/// Full per-subsystem table, written once at the end.
/datum/controller/subsystem/ghost_round/proc/log_subsystem_table()
	var/list/ranked = list()
	for(var/datum/controller/subsystem/subsystem as anything in Master.subsystems)
		ranked[subsystem] = subsystem.tick_usage
	sortTim(ranked, GLOBAL_PROC_REF(cmp_numeric_dsc), associative = TRUE)
	var/shown = 0
	for(var/datum/controller/subsystem/subsystem as anything in ranked)
		if(!subsystem.times_fired)
			continue
		ghost_log("SUBSYSTEM [subsystem.name]: tick_usage=[num_1dp(subsystem.tick_usage)]% cost=[num_1dp(subsystem.cost)]ms overrun=[num_1dp(subsystem.tick_overrun)]% fires=[subsystem.times_fired] wait=[subsystem.wait / 10]s")
		shown++
		if(shown >= 25)
			return

// ---------------------------------------------------------------------------------------
// The final profile
// ---------------------------------------------------------------------------------------

/**
 * Everything the hour measured, written once, in one block the shell script prints whole.
 *
 * Latched: the watchdog, the Reboot override and the normal end of the round can all reach
 * here, and only the first of them is allowed to write.
 */
/datum/controller/subsystem/ghost_round/proc/write_profile(cut_short_reason)
	if(profile_written)
		return
	profile_written = TRUE
	running = FALSE
	GLOB.ghost_round_active = FALSE
	SSghost_sampler.phase_label = "closing"

	// Cheap analysis FIRST, expensive dumps last. A death partway through this proc must not
	// cost the prediction checks and the hard-delete ranking, which is exactly what happened on
	// the first 3-hour run when profile_dump() and take_census_now() ran ahead of them under
	// memory exhaustion.
	ghost_log("=== GHOST ROUND: FINAL PROFILE ===")
	if(cut_short_reason)
		ghost_log("CUT SHORT: [cut_short_reason]. Everything below covers only the minutes that completed.")
	ghost_log("scenario: [smoke ? "SMOKE" : "FULL"] - [ships_target] hull\s requested, [crew_target] crew requested, [budget_min] minute budget")
	ghost_log("actual:   [length(player_ships)] hull\s founded, [length(GLOB.ghost_round_crew)] sim crew created, ran [elapsed_min()] minutes")

	// ---- the sendmaps caveat, restated where the numbers are ----------------------------
	ghost_log("")
	ghost_log("--- CAVEAT: NO CLIENTS ---")
	ghost_log("DM cannot construct a /client, so SendMaps - the per-viewer map streaming, view() computation and statpanel work that a real 70-player host pays every tick - contributed NOTHING to any figure below. The production perf CSV's `maptick` column is the receipt: on a real 70-player round it is a large share of the tick, and on this run it sits at zero. Every other cost here (MC scheduling, atmos, AI, mob Life, combat, worldgen, GC, memory) is real.")
	ghost_log("TD is also HARDWARE-RELATIVE. This is a dev box, and the run may have shared it with the owner's own client or a concurrent soak - see the BOX lines at the top of this log.")

	// ---- the timeline -------------------------------------------------------------------
	ghost_log("")
	ghost_log("--- TIMELINE AS EXECUTED ([length(timeline)] beats) ---")
	for(var/line in timeline)
		ghost_log("  [line]")

	// ---- per-bucket ---------------------------------------------------------------------
	ghost_log("")
	ghost_log("--- PROFILE BY BUCKET (1-minute to T+15m, 5-minute after) ---")
	ghost_log("  window       phase      TD avg/p95/max   %>1.05x %>1.25x %>2.0x   tick avg/p95/max   planets ruins fields crash arena  ships npc  crew  mobs  ai_on  maxz")
	for(var/list/row as anything in buckets)
		ghost_log("  [row["from_min"]]-[row["to_min"]]m  [row["phase"]]  [num_1dp(row["td_avg"])]/[num_1dp(row["td_p95"])]/[num_1dp(row["td_max"])]  [num_1dp(row["td_over_105"])]% [num_1dp(row["td_over_125"])]% [num_1dp(row["td_over_200"])]%  [num_1dp(row["tick_avg"])]/[num_1dp(row["tick_p95"])]/[num_1dp(row["tick_max"])]  [row["planets"]] [row["ruins"]] [row["fields"]] [row["crashes"]] [row["arenas"]]  [row["ships"]] [row["npc"]]  [row["crew_alive"]]/[row["crew_alive"] + row["crew_dead"]]  [row["mobs"]]  [row["ai_on"]]  [row["maxz"]]  realtime=[row["realtime"]]")

	// ---- per-phase ----------------------------------------------------------------------
	ghost_log("")
	ghost_log("--- PROFILE BY PHASE ---")
	if(sustain)
		log_phase_summary("launch", 0, GHOST_PHASE_LAUNCH_END)
		for(var/hour in 1 to CEILING(budget_min / 60, 1))
			log_phase_summary("hour [hour]", max(GHOST_PHASE_LAUNCH_END, (hour - 1) * 60), min(budget_min, hour * 60))
		log_hour_trend()
	else
		log_phase_summary("launch", 0, phase_end(GHOST_PHASE_LAUNCH_END))
		log_phase_summary("peak", phase_end(GHOST_PHASE_LAUNCH_END), phase_end(GHOST_PHASE_PEAK_END))
		log_phase_summary("attrition", phase_end(GHOST_PHASE_PEAK_END), budget_min)
	log_prediction_checks()
	log_phase_summary("whole round", 0, budget_min)

	// ---- worldgen bursts ----------------------------------------------------------------
	ghost_log("")
	ghost_log("--- WORLDGEN BURSTS ---")
	ghost_log("Site loads are short and expensive; five-minute buckets smear them away. Each window below is cut from the 1 Hz series to exactly the load, and compared against the 60 seconds of steady state before it began.")
	for(var/list/window as anything in burst_windows)
		log_burst(window)
	ghost_log("")
	ghost_log("--- INDIVIDUAL LOAD WINDOWS ([length(load_windows)] site loads) ---")
	ghost_log("Read the OVERLAP column against the burst design: ruins and asteroid fields load UNQUEUED and should overlap freely, while planet builds serialise through SSovermap's worldgen queue BY DESIGN (surveys must never slow ruins or empty space). Ruin/field windows nested inside a planet's rather than overlapping it would be queue coupling that should not exist, and is a finding.")
	for(var/list/window as anything in load_windows)
		log_load_window(window)

	// ---- subsystems ----------------------------------------------------------------------
	ghost_log("")
	ghost_log("--- TOP SUBSYSTEM COSTS AT ROUND END ---")
	log_subsystem_table()
	ghost_log("HARNESS OVERHEAD: sampler [num_1dp(SSghost_sampler.sampler_cost_ms)]ms total, crew driver [num_1dp(SSghost_sampler.crew_cost_ms)]ms total across [elapsed_min()] minutes. Crew actions: [SSghost_crew.action_tally["step"]] steps, [SSghost_crew.action_tally["attack"]] attacks, [SSghost_crew.action_tally["mine"]] rocks drilled, [SSghost_crew.action_tally["flee"]] retreats.")

	// ---- content endpoint ------------------------------------------------------------------
	var/list/live = live_site_counts()
	var/crew_alive = 0
	for(var/mob/living/sim as anything in GLOB.ghost_round_crew)
		if(!QDELETED(sim) && sim.stat != DEAD)
			crew_alive++
	ghost_log("")
	ghost_log("--- ENDPOINT ---")
	ghost_log("sites resident: planets [live["planet"]], space ruins [live["ruin"]], asteroid fields [live["field"]], crash sites [live["crash"]], arenas [live["arena"]]")
	ghost_log("hulls: [length(SSovermap.simulated_ships)] on the overmap ([length(player_ships)] player, [length(SSnpc_ships.active_ships)] NPC pool). Hull kills [hull_kills], crews wiped [crews_wiped], derelicts despawned [ships_despawned].")
	ghost_log("crew: [crew_alive] alive, [length(GLOB.ghost_round_crew)] still on the sim registry (the dead are retired off it two minutes after death - see retire_the_dead - so this is NOT the total ever created; [crew_replaced] were dealt as replacements)")
	if(sustain)
		ghost_log("replenishment: [hulls_refounded] replacement hull\s founded, [crew_replaced] replacement crew dealt, [crews_wiped] crew wipe\s")
	ghost_log("world: maxz [world.maxz], contents [world.contents.len], mobs [length(GLOB.mob_list)], map zones [length(SSovermap.map_zones)], timers [length(SStimer.timer_id_dict)], runtimes [GLOB.total_runtimes]")
	ghost_log("REFERENCE: round 9 measured 3.93 GB of a 4.0 GB address space at two hours with 70 REAL players. This run is one hour, no clients, and therefore no per-client allocation at all - so its memory endpoint is a FLOOR for a comparable real round, not a match. The driver's memory CSV carries the actual figures; join it to the buckets above on the realtime column.")
	flush_harddel_ranking()

	// Last, because they are the two most expensive things here and the least valuable if the
	// world dies mid-write: a full profiler serialisation and an all-atom census walk.
	profile_dump("final")
	take_census_now()

	ghost_log("=== GHOST ROUND COMPLETE ===")

	// Let the appends flush and the driver's sampler catch the tail, then take the world down
	// the same way the churn soak does. A reboot here would start a second round on the same
	// params and churn on top of this one's logs.
	sleep(10 SECONDS)
	qdel(world)

/**
 * Writes the per-type hard-delete ranking, and mirrors the worst offenders into the round log.
 *
 * `SSgarbage.items` accumulates a /datum/qdel_item per type - qdel count, Destroy() cost, hard
 * delete count, total and max hard-delete time - and the ONLY thing that ever writes it out is
 * `/datum/controller/subsystem/garbage/Shutdown()`. The 70-minute run ended with `qdel(world)`,
 * which does not run subsystem Shutdown()s, so its `qdel.log` came out at 82 bytes and the run
 * produced no ranked hard-delete data at all. Every future run would have repeated that blind
 * spot.
 *
 * Calling Shutdown() directly is safe here: its body only sorts `items`, builds a list and
 * writes `qdel.log`. It is called at the very end, after every other measurement is on disk,
 * and the world is about to be deleted regardless.
 *
 * The top-of-table mirror into the round log exists because hard deletes are the expensive
 * half of the GC - the 70-minute round spent 73.4 s in 172 of them, ~427 ms each, and each one
 * postpones every subsystem's next fire - so which TYPES are doing it is the actionable
 * question, and it should not require opening a second file to answer.
 */
/datum/controller/subsystem/ghost_round/proc/flush_harddel_ranking()
	ghost_log("")
	ghost_log("--- HARD DELETE RANKING ---")

	var/list/ranked = list()
	for(var/path in SSgarbage.items)
		var/datum/qdel_item/item = SSgarbage.items[path]
		if(!item || !item.hard_deletes)
			continue
		ranked[path] = item.hard_delete_time
	sortTim(ranked, GLOBAL_PROC_REF(cmp_numeric_dsc), associative = TRUE)

	var/total_hard = 0
	var/total_time = 0
	for(var/path in ranked)
		var/datum/qdel_item/item = SSgarbage.items[path]
		total_hard += item.hard_deletes
		total_time += item.hard_delete_time

	ghost_log("[length(ranked)] type\s hard-deleted at least once: [total_hard] hard deletes costing [num_1dp(total_time)] ms total ([total_hard ? num_1dp(total_time / total_hard) : 0] ms each). Every one of these postpones every subsystem's next fire by its own duration.")
	ghost_log("SSgarbage totals: [SSgarbage.totaldels] hard, [SSgarbage.totalgcs] soft ([SSgarbage.totalgcs ? num_1dp(SSgarbage.totaldels / (SSgarbage.totaldels + SSgarbage.totalgcs) * 100) : 0]% hard-delete rate)")

	log_harddel_top(25)

	// And the full table to qdel.log, through the production writer.
	SSgarbage.Shutdown()
	ghost_log("full per-type table written to [GLOB.log_directory]/qdel.log via SSgarbage.Shutdown()")

/**
 * The N types that have spent the most wall time hard-deleting, right now.
 *
 * Shared by the mid-run snapshot and the final profile. Hard deletes are the expensive half of
 * the GC - the first 3-hour run spent 186.9 s in 518 of them, 361 ms each, and every one
 * postpones every subsystem's next fire by its own duration - so WHICH TYPES do it is the
 * actionable question, and this is the answer that no run before this harness ever produced.
 */
/datum/controller/subsystem/ghost_round/proc/log_harddel_top(how_many)
	var/list/ranked = list()
	for(var/path in SSgarbage.items)
		var/datum/qdel_item/item = SSgarbage.items[path]
		if(!item || !item.hard_deletes)
			continue
		ranked[path] = item.hard_delete_time
	if(!length(ranked))
		ghost_log("HARDDEL: nothing has hard-deleted yet.")
		return
	sortTim(ranked, GLOBAL_PROC_REF(cmp_numeric_dsc), associative = TRUE)
	var/shown = 0
	for(var/path in ranked)
		var/datum/qdel_item/item = SSgarbage.items[path]
		ghost_log("  HARDDEL [path]: [item.hard_deletes] hard delete\s, [num_1dp(item.hard_delete_time)] ms total, [num_1dp(item.hard_delete_max)] ms worst, [item.qdels] qdel\s, [item.failures] failure\s")
		shown++
		if(shown >= how_many)
			break

/**
 * The deliverable table: does hour 3 look like hour 1?
 *
 * One row per wall hour, holding the two things that answer plateau-versus-creep - tick cost and
 * memory - beside the content counts that would explain either. Read DOWN the columns, not
 * across: a round in steady state should show flat TD and tick usage with a memory curve that
 * flattens, and a round that is creeping shows the same content counts with rising cost.
 *
 * The bucket rows already carry everything needed; this re-cuts them per hour so the comparison
 * is one table rather than an exercise for the reader. Memory is the exception - DM cannot read
 * its own process size, so the virtMB column stays empty here and is joined in from the driver's
 * sampler CSV afterwards on the `realtime` stamp each bucket carries.
 */
/datum/controller/subsystem/ghost_round/proc/log_hour_trend()
	ghost_log("")
	ghost_log("--- HOUR-OVER-HOUR TREND (the plateau-vs-creep question) ---")
	ghost_log("CHURN columns are per-hour DELTAS: how much work the hour did. Cost columns beside them are what it cost. Read them together - this round runs at ~3x ordinary rate, so a flat cost column next to a flat churn column is the plateau result, and a rising cost column next to a flat churn column is creep.")
	ghost_log("  hour  TD avg/p95  %>1.05x %>1.25x %>2.0x  tick avg/p95 || CHURN: loads teardowns founded kills wipes despawns || mobs corpses crew hulls  planets ruins fields  maxz  contents  gcQ")
	var/list/prev_row
	for(var/hour in 1 to CEILING(budget_min / 60, 1))
		var/from_min = (hour - 1) * 60
		var/to_min = min(budget_min, hour * 60)
		var/from_time = started_worldtime + (from_min MINUTES)
		var/to_time = started_worldtime + (to_min MINUTES)
		var/list/td = SSghost_sampler.window_stats(from_time, to_time, SSghost_sampler.sample_td)
		var/list/tick = SSghost_sampler.window_stats(from_time, to_time, SSghost_sampler.sample_tick)
		if(!td)
			ghost_log("  [hour]: no samples")
			continue
		// Content counts are taken from the LAST bucket that closed inside the hour, i.e. the
		// state the hour ended in - which is the right reading for an accumulation question.
		var/list/last_row
		for(var/list/row as anything in buckets)
			if(row["to_min"] <= to_min && row["to_min"] > from_min)
				last_row = row
		// Churn is a DELTA against the hour before, so each row says what that hour did rather
		// than what the round has done so far.
		var/d_loads = last_row ? (last_row["c_loads"] - (prev_row ? prev_row["c_loads"] : 0)) : 0
		var/d_teardowns = last_row ? (last_row["c_teardowns"] - (prev_row ? prev_row["c_teardowns"] : 0)) : 0
		var/d_found = last_row ? (last_row["c_found"] - (prev_row ? prev_row["c_found"] : 0)) : 0
		var/d_kills = last_row ? (last_row["c_kills"] - (prev_row ? prev_row["c_kills"] : 0)) : 0
		var/d_wipes = last_row ? (last_row["c_wipes"] - (prev_row ? prev_row["c_wipes"] : 0)) : 0
		var/d_despawns = last_row ? (last_row["c_despawns"] - (prev_row ? prev_row["c_despawns"] : 0)) : 0
		ghost_log("  [hour]     [num_1dp(td["avg"])]/[num_1dp(td["p95"])]     [num_1dp(SSghost_sampler.window_td_share(from_time, to_time, 5))]%  [num_1dp(SSghost_sampler.window_td_share(from_time, to_time, 25))]%  [num_1dp(SSghost_sampler.window_td_share(from_time, to_time, 100))]%   [num_1dp(tick ? tick["avg"] : 0)]/[num_1dp(tick ? tick["p95"] : 0)] || [d_loads] [d_teardowns] [d_found] [d_kills] [d_wipes] [d_despawns] || [last_row ? last_row["mobs"] : "-"] [last_row ? last_row["crew_dead"] : "-"] [last_row ? last_row["crew_alive"] : "-"] [last_row ? last_row["ships"] : "-"]  [last_row ? last_row["planets"] : "-"] [last_row ? last_row["ruins"] : "-"] [last_row ? last_row["fields"] : "-"]  [last_row ? last_row["maxz"] : "-"]  [last_row ? last_row["contents"] : "-"]  [last_row ? last_row["gc_queue"] : "-"]")
		if(last_row)
			prev_row = last_row
	ghost_log("Join the driver's memory CSV (data/ghost_round_<stamp>_mem.csv) onto the BUCKET lines' realtime stamps for the virtMB column; the plateau question needs both halves.")
	log_class_tally()

/**
 * Per-hull-class founded/killed/despawned, so class coverage is provable.
 *
 * The reason this matters is not bookkeeping: hull classes differ by an order of magnitude in
 * turf count, pipenet complexity, machinery count and berth footprint, and a run that founded
 * the same three classes twenty times would have measured one shape of teardown twenty times
 * and called it a fleet. A class with foundings but no deaths is untested on teardown; a class
 * that never appears at all is untested entirely.
 */
/datum/controller/subsystem/ghost_round/proc/log_class_tally()
	ghost_log("")
	ghost_log("--- HULL CLASS COVERAGE ---")
	ghost_log("[length(class_tally)] distinct player hull class\s appeared this round (rotation held [length(hull_rotation)] purchasable classes).")
	var/uncovered = 0
	for(var/datum/map_template/shuttle/voidcrew/template as anything in hull_rotation)
		if(!class_tally[template.name])
			uncovered++
	for(var/class_name in class_tally)
		var/list/counts = class_tally[class_name]
		ghost_log("  CLASS [class_name]: founded [counts["founded"]], killed [counts["killed"]], despawned [counts["despawned"]]")
	ghost_log("[uncovered] class\s in the rotation were never founded (0 is full coverage; anything else means the round was too short to complete a rotation pass).")
	ghost_log("NPC hull variety is SSnpc_ships' own: reconcile_pool() draws from `all_factions - active_faction_types` and only falls back to the full list when every faction is already flying, so the pirate pool rotates classes without harness help.")

/**
 * Explicit pass/fail against the perf wave's falsifiable predictions, so the run answers them
 * in its own log rather than leaving it to a later reading.
 *
 * These are checks the harness can make from inside DM. The two that need the profiler JSON -
 * `has_ship_combat_research` total under 0.1 s and `missions/fire` total under 0.5 s - are named
 * here with the file to read them from, because DM cannot parse its own dump cheaply.
 */
/datum/controller/subsystem/ghost_round/proc/log_prediction_checks()
	ghost_log("")
	ghost_log("--- PREDICTION CHECKS (perf wave) ---")

	// Finding 2 - SSmissions. The subsystem-table half of the prediction is checkable here.
	var/mission_overrun = SSmissions ? SSmissions.tick_overrun : -1
	var/mission_usage = SSmissions ? SSmissions.tick_usage : -1
	ghost_log("F2 SSmissions: tick_usage=[num_1dp(mission_usage)]% overrun=[num_1dp(mission_overrun)]% (PREDICTED overrun 0% or single digits, usage well under 100%; was 169.7%/159.5%)")
	ghost_log("F2 SSmissions.all_active_missions = [SSmissions ? length(SSmissions.all_active_missions) : -1] (PREDICTED: equals the live mission count, no qdel'd stragglers)")
	ghost_log("F2 PROFILER CHECK (read the last profiler JSON): has_ship_combat_research total PREDICTED < 0.1s (was 8.99s); missions/fire total PREDICTED < 0.5s (was 9.05s). Dumps are CUMULATIVE - read the last one directly, do not diff.")

	// Finding 1 - SSgarbage. The subsystem table's number is an EWMA snapshot and is expected to
	// look alarming; the profiler is the verdict.
	ghost_log("F1 SSgarbage: tick_usage=[num_1dp(SSgarbage.tick_usage)]% overrun=[num_1dp(SSgarbage.tick_overrun)]% - EXPECTED to look large; it is an EWMA of the last few fires, not a round cost.")
	ghost_log("F1 gc_totaldels=[SSgarbage.totaldels] gc_totalgcs=[SSgarbage.totalgcs] (PREDICTED hard deletes in the low hundreds per 70 min, soft in the millions. FALSIFIED if hard deletes reach the thousands, or profiler garbage/fire real exceeds ~10% of wall time.)")

	// Finding 3 - the worldgen queue timeout. Checkable directly from the load windows.
	// Count only CLOSED windows. record_load_start() seeds "ok" = FALSE and record_load_end()
	// sets it, so a window that is still building reads exactly like a failed one - which made
	// the mid-run snapshot report in-flight sites as failures ("Lava Planet II" was mid
	// planet-build in worldgen.log at the moment it was counted). `end` is the completion flag.
	var/failed_loads = 0
	var/closed_loads = 0
	var/in_flight = 0
	var/list/failed_labels = list()
	for(var/list/window as anything in load_windows)
		if(!window["end"])
			in_flight++
			continue
		closed_loads++
		if(!window["ok"])
			failed_loads++
			failed_labels += "[window["kind"]]:[window["label"]]"
	ghost_log("F3 load windows: [closed_loads] closed ([in_flight] still building), [failed_loads] with ok=no (PREDICTED ZERO. [failed_loads ? "FAILURES: [jointext(failed_labels, ", ")]" : "none"])")
	var/full_bursts = 0
	var/settled_bursts = 0
	for(var/list/window as anything in burst_windows)
		if(!window["end"])
			continue
		settled_bursts++
		if(window["planned"] && window["done"] >= window["planned"])
			full_bursts++
	ghost_log("F3 bursts: [full_bursts] of [settled_bursts] settled burst\s completed N/N (PREDICTED all of them; the last site's window should be roughly the SUM of the ones ahead of it, not a ~240s failure)")
	ghost_log("F3 NOTE: the authoritative falsifier is `note=\"queue-timeout\"` in worldgen.log, not this counter - an in-flight window is indistinguishable from a failed one until it closes.")

	// ---- F4: SSpathfinder, and how to read a profiler dump at all -----------------------
	//
	// READ THIS BEFORE QUOTING ANY SUBSYSTEM COST. There are three ways to get a wrong
	// subsystem cost out of this codebase and two of them have already produced retracted
	// headlines in this report:
	//
	//   1. `SS.cost * SS.times_fired` - cost is an MC_AVERAGE_FAST EWMA over the last ~10
	//      fires, times_fired is a round total. Multiplying them bills the whole round for
	//      whatever the subsystem was doing in the final half-second.
	//   2. The profiler's `real` or `total` on a subsystem fire() - BOTH include time the proc
	//      spent SUSPENDED. Subsystem fire()s are paused and resumed by the MC constantly, so
	//      these are dominated by suspension, not CPU. Measured here on the 2-hour run:
	//      pathfinder/fire self 1.272s but total 1518.520s and real 1518.590s. Quoting `real`
	//      is what produced the retracted "SSpathfinder = 20.8% of the round".
	//   3. Summing `total` across procs - it double-counts, because total includes children.
	//
	// The ONLY sound attribution is profiler `self`, which is exclusive CPU. As a sanity
	// check, the sum of `self` over every proc should come to somewhat less than round wall
	// time (it came to 5347.9s of a 7310s round, 73.2%).
	ghost_log("F4 SSpathfinder: tick_usage=[num_1dp(SSpathfinder ? SSpathfinder.tick_usage : -1)]% overrun=[num_1dp(SSpathfinder ? SSpathfinder.tick_overrun : -1)]% fires=[SSpathfinder ? SSpathfinder.times_fired : -1] - EWMA, NOT a round cost. Do not multiply by fires.")
	ghost_log("F4 PROFILER CHECK: /datum/controller/subsystem/pathfinder/fire SELF PREDICTED < 2s over 3h (2-hour run measured self 1.272s; its `total` of 1518s is suspension, not CPU). Micro-fixes landed 22:58 and are in this build.")
	ghost_log("F4 THE REAL PATHFINDING COST IS NOT IN fire(). On the 2-hour run the top two procs in the WHOLE round by self were JPS children: /turf/proc/LinkBlockedWithAccess 702.1s self over 508,878,420 calls, and /datum/pathfind/jps/proc/lateral_scan_spec 594.1s self over 22,065,918 calls (diag_scan_spec a further 70.4s). Together 25.6% of all measured CPU. Check those three by SELF, not SSpathfinder/fire.")

	// ---- F5: SSarea_contents, and the area-list drain fix --------------------------------
	ghost_log("F5 SSarea_contents: tick_usage=[num_1dp(SSarea_contents ? SSarea_contents.tick_usage : -1)]% overrun=[num_1dp(SSarea_contents ? SSarea_contents.tick_overrun : -1)]% fires=[SSarea_contents ? SSarea_contents.times_fired : -1] (EWMA again - the number that matters is profiler SELF)")
	ghost_log("F5 PROFILER CHECK: /datum/controller/subsystem/area_contents/fire SELF - round-1022 baseline 15.0s over 3,194 calls (4.7 ms/fire); this harness's 2-hour run measured 27.4s over 5,294 calls (5.2 ms/fire), i.e. a genuine per-fire constant and the #2 self-cost in the round after HardDelete. Tonight's area-list drain rewrite PREDICTS A LARGE DROP. Report before/after per-fire, not totals - fire counts differ between rounds.")
	ghost_log("F5 area_turf_entries=[count_area_turf_entries()] - total ENTRIES across every area's turfs_by_zlevel and turfs_to_uncontain_by_zlevel. The absolute number is legitimately huge (~world turf count); what matters is that it stays FLAT across snapshots. A climb of ~100k per site cycle means SSarea_contents is losing its race with /turf/change_area().")

/**
 * Total entries across every area's turf bookkeeping lists.
 *
 * Mirrors the churn soak's `area_turf_entries` counter (churn_soak.dm:1612-1621) so the two
 * harnesses report the same quantity - that file belongs to another agent and is not modified.
 * Nulls are counted deliberately: a hard-delete-nulled entry still occupies a list slot, and
 * slot count is exactly what this measures.
 */
/datum/controller/subsystem/ghost_round/proc/count_area_turf_entries()
	. = 0
	for(var/area/counted_area as anything in GLOB.areas)
		if(isnull(counted_area))
			continue
		for(var/list/per_z as anything in counted_area.turfs_by_zlevel)
			if(islist(per_z))
				. += length(per_z)
		for(var/list/per_z as anything in counted_area.turfs_to_uncontain_by_zlevel)
			if(islist(per_z))
				. += length(per_z)
		CHECK_TICK
	ghost_log("F3 also check worldgen.log for note=\"queue-timeout\" - PREDICTED zero. If one appears WITHOUT a nearby watchdog-release line, the no-progress detection is broken.")

/datum/controller/subsystem/ghost_round/proc/log_phase_summary(label, from_min, to_min)
	var/from_time = started_worldtime + (from_min MINUTES)
	var/to_time = started_worldtime + (to_min MINUTES)
	var/list/td = SSghost_sampler.window_stats(from_time, to_time, SSghost_sampler.sample_td)
	var/list/tick = SSghost_sampler.window_stats(from_time, to_time, SSghost_sampler.sample_tick)
	if(!td)
		ghost_log("  [label] ([from_min]-[to_min]m): no samples")
		return
	ghost_log("  [label] ([from_min]-[to_min]m, [td["n"]] samples): TD avg [num_1dp(td["avg"])]% p95 [num_1dp(td["p95"])]% max [num_1dp(td["max"])]% | over 1.05x [num_1dp(SSghost_sampler.window_td_share(from_time, to_time, 5))]%, over 1.25x [num_1dp(SSghost_sampler.window_td_share(from_time, to_time, 25))]%, over 2.0x [num_1dp(SSghost_sampler.window_td_share(from_time, to_time, 100))]% of ticks | tick usage avg [num_1dp(tick ? tick["avg"] : 0)]% p95 [num_1dp(tick ? tick["p95"] : 0)]% max [num_1dp(tick ? tick["max"] : 0)]%")

/// One burst, against the minute of steady state before it. The comparison is the point: a
/// tick-usage number with nothing to read it against says nothing about whether a burst hurt.
/datum/controller/subsystem/ghost_round/proc/log_burst(list/window)
	var/start = window["start"]
	var/end = window["end"] ? window["end"] : world.time
	var/list/td = SSghost_sampler.window_stats(start, end, SSghost_sampler.sample_td)
	var/list/tick = SSghost_sampler.window_stats(start, end, SSghost_sampler.sample_tick)
	var/list/base_td = SSghost_sampler.window_stats(max(started_worldtime, start - (1 MINUTES)), start, SSghost_sampler.sample_td)
	var/list/base_tick = SSghost_sampler.window_stats(max(started_worldtime, start - (1 MINUTES)), start, SSghost_sampler.sample_tick)
	if(!td)
		ghost_log("  burst '[window["label"]]': no samples")
		return
	ghost_log("  burst '[window["label"]]' ([window["ruins"]] ruin + [window["fields"]] field + [window["planets"]] planet, [window["done"]]/[window["planned"]] stood up, [(end - start) / 10]s):")
	ghost_log("     during: TD avg [num_1dp(td["avg"])]% p95 [num_1dp(td["p95"])]% max [num_1dp(td["max"])]% | tick avg [num_1dp(tick ? tick["avg"] : 0)]% p95 [num_1dp(tick ? tick["p95"] : 0)]% max [num_1dp(tick ? tick["max"] : 0)]% | over 2.0x [num_1dp(SSghost_sampler.window_td_share(start, end, 100))]% of ticks")
	ghost_log("     before: TD avg [num_1dp(base_td ? base_td["avg"] : 0)]% max [num_1dp(base_td ? base_td["max"] : 0)]% | tick avg [num_1dp(base_tick ? base_tick["avg"] : 0)]% max [num_1dp(base_tick ? base_tick["max"] : 0)]%  (the 60s of steady state before it fired)")

/// One site load, with the overlap count: how many OTHER load windows were open at the same
/// time. That number is what turns a list of durations into evidence about concurrency.
/datum/controller/subsystem/ghost_round/proc/log_load_window(list/window)
	var/start = window["start"]
	var/end = window["end"] ? window["end"] : world.time
	var/overlaps = 0
	var/list/overlap_names = list()
	for(var/list/other as anything in load_windows)
		if(other == window)
			continue
		var/other_end = other["end"] ? other["end"] : world.time
		if(other["start"] < end && other_end > start)
			overlaps++
			overlap_names += "[other["kind"]]"
	var/list/td = SSghost_sampler.window_stats(start, end, SSghost_sampler.sample_td)
	var/list/tick = SSghost_sampler.window_stats(start, end, SSghost_sampler.sample_tick)
	ghost_log("  [window["kind"]] '[window["label"]]' burst=[window["burst"] || "-"] dur=[(end - start) / 10]s z=[window["z"]] ok=[window["ok"] ? "yes" : "no"] overlapped=[overlaps]\[[jointext(overlap_names, ",")]\] TD avg/max [num_1dp(td ? td["avg"] : 0)]/[num_1dp(td ? td["max"] : 0)]% tick avg/max [num_1dp(tick ? tick["avg"] : 0)]/[num_1dp(tick ? tick["max"] : 0)]%")
