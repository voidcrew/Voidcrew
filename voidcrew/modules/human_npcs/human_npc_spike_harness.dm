// Measurement harness for the human NPC spike. Compiled only with -DHUMAN_NPC_SPIKE_HARNESS;
// nothing here exists in a normal build.
//
// Boots a clientless world, starts the round, builds a walled, lit, breathable test room in a
// turf reservation, then spawns NPCs of one kind (world.params "spike_kind": human,
// human_untrimmed or trooper) in steps of 20, 50 and 100. At each step it measures them dormant
// (no player on their z-level), awake with nothing to fight, and in combat against damage-proof
// human dummies; then their corpses; then a 25 vs 25 fight to the death. Results go to
// data/human_npc_spike_<kind>_*: a CSV of per-phase numbers, BYOND profiler dumps, and instance
// censuses. The current phase name is written to data/human_npc_spike_<kind>_phase.txt so an
// outside sampler can tag process memory readings with it.
#ifdef HUMAN_NPC_SPIKE_HARNESS

/// Mobs the harness spawned and controls, assoc mob -> TRUE.
GLOBAL_LIST_EMPTY(human_npc_spike_mobs)
/// Whether the harness pretends a player is on the test room's z-level.
GLOBAL_VAR_INIT(human_npc_spike_awake, FALSE)
/// Human NPC Life() calls that got past the dormancy guard (counted in human_npc.dm under this define).
GLOBAL_VAR_INIT(human_npc_spike_life_passes, 0)

/// Same NPC with every Life() trim switched off, to measure what the trims save.
/mob/living/carbon/human/npc/sample/laser/spike_untrimmed
	npc_trim_life = FALSE

/mob/living/carbon/human/npc/npc_players_on_level()
	if(GLOB.human_npc_spike_mobs[src])
		return GLOB.human_npc_spike_awake
	return ..()

// A clientless world has no clients on any z-level, so every AI would be off. While "awake", the
// harness's own mobs get the status a mob near a player would get.
/datum/ai_controller/get_expected_ai_status()
	if(GLOB.human_npc_spike_awake && GLOB.human_npc_spike_mobs[pawn])
		var/mob/living/living_pawn = pawn
		if(living_pawn.stat != DEAD && able_to_run && !on_failed_planning_timeout && isturf(living_pawn.loc) && !living_pawn.client)
			return AI_STATUS_ON
	return ..()

#define SPIKE_ROOM_W 30
#define SPIKE_ROOM_H 36

SUBSYSTEM_DEF(human_npc_spike)
	name = "Human NPC Spike Harness"
	flags = SS_NO_FIRE
	/// human, human_untrimmed or trooper
	var/kind = "human"
	var/mob_type
	var/out_prefix
	var/csv_path
	var/phase_path
	var/datum/turf_reservation/reservation
	/// Bottom-left floor turf of the test room.
	var/turf/origin
	var/list/turf/room_turfs = list()
	var/list/mob/living/npcs = list()
	var/list/mob/living/dummies = list()

/datum/controller/subsystem/human_npc_spike/Initialize()
	Master.sleep_offline_after_initializations = FALSE
	var/list/params = world.params
	kind = params?["spike_kind"] || "human"
	switch(kind)
		if("trooper")
			mob_type = /mob/living/basic/trooper/pirate/ranged
		if("human_untrimmed")
			mob_type = /mob/living/carbon/human/npc/sample/laser/spike_untrimmed
		else
			kind = "human"
			mob_type = /mob/living/carbon/human/npc/sample/laser
	if(params?["spike_mode"] == "dormancy")
		kind = "[kind]_dormancy"
	out_prefix = "data/human_npc_spike_[kind]"
	csv_path = "[out_prefix]_results.csv"
	phase_path = "[out_prefix]_phase.txt"
	fdel(csv_path)
	rustg_file_write("kind,phase,n,metric,value\n", csv_path)
	set_phase("init")
	SSticker.start_immediately = TRUE
	if(params?["spike_mode"] == "dormancy")
		INVOKE_ASYNC(src, PROC_REF(run_dormancy_proof))
	else
		INVOKE_ASYNC(src, PROC_REF(run_spike))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/human_npc_spike/proc/set_phase(label)
	rustg_file_write(label, phase_path)
	log_world("human_npc_spike: phase [label]")

/datum/controller/subsystem/human_npc_spike/proc/record(phase, n, metric, value)
	rustg_file_append("[kind],[phase],[n],[metric],[value]\n", csv_path)

/datum/controller/subsystem/human_npc_spike/proc/run_spike()
	UNTIL(SSticker.current_state == GAME_STATE_PLAYING)
	SSticker.delay_end = TRUE
	SSprofiler.can_fire = FALSE
	world.Profile(PROFILE_STOP)
	set_phase("settle_roundstart")
	sleep(60 SECONDS)
	if(!build_room())
		set_phase("failed_room")
		return
	sleep(10 SECONDS)
	census("baseline")
	measure("baseline", 0, 30 SECONDS)
	profile("baseline", 0, 15 SECONDS)

	for(var/n in list(20, 50, 100))
		spawn_npcs_to(n)
		set_awake(FALSE)
		settle("spawned", n, 20 SECONDS)
		if(n == 100)
			census("spawned_100")
		measure("dormant", n, 30 SECONDS)
		set_awake(TRUE)
		settle("awake_settle", n, 10 SECONDS)
		measure("awake", n, 30 SECONDS)
		profile("awake", n, 15 SECONDS)
		spawn_dummies()
		settle("combat_settle", n, 10 SECONDS)
		measure("combat", n, 45 SECONDS)
		profile("combat", n, 15 SECONDS)
		clear_dummies()
		set_awake(FALSE)
		settle("post_combat", n, 10 SECONDS)
		clear_debris()

	bulk_memory(400)

	// Corpses: kill every NPC the way a fight would, then measure the bodies left behind.
	set_awake(TRUE)
	kill_npcs()
	settle("corpse_settle", 100, 20 SECONDS)
	census("corpses_100")
	measure("corpses_awake", 100, 30 SECONDS)
	profile("corpses_awake", 100, 15 SECONDS)
	set_awake(FALSE)
	measure("corpses_dormant", 100, 30 SECONDS)
	clear_room()
	settle("cleared", 0, 20 SECONDS)
	census("cleared")

	team_fight(25)
	settle("after_fight", 0, 10 SECONDS)
	clear_room()
	settle("cleared_fight", 0, 15 SECONDS)

	bench_spawn_and_kill(20)
	clear_room()
	settle("cleared_bench", 0, 10 SECONDS)
	bench_hits(/obj/projectile/bullet/c9mm, 150)
	bench_hits(/obj/projectile/beam/laser, 150)
	clear_room()
	settle("cleared_hits", 0, 15 SECONDS)

	// The same fight again under the profiler, to see where its time goes.
	world.Profile(PROFILE_CLEAR)
	world.Profile(PROFILE_START)
	team_fight(25, "fight_profiled")
	var/fight_profile = world.Profile(PROFILE_REFRESH, format = "json")
	world.Profile(PROFILE_STOP)
	rustg_file_write(fight_profile, "[out_prefix]_profile_fight_25.json")
	settle("after_fight_profiled", 0, 10 SECONDS)
	set_phase("done")

/**
 * spike_mode=dormancy: a short run for the production base. Queues 100 NPCs through
 * spawn_human_npc() and records how many were built per tick, then measures their Life() and AI
 * cost dormant, awake, and as corpses without and with a player on the z-level, counting the Life()
 * calls that got past the dormancy guard in each phase, and checks that a waking corpse catches up
 * the organ decay it slept through.
 */
/datum/controller/subsystem/human_npc_spike/proc/run_dormancy_proof()
	UNTIL(SSticker.current_state == GAME_STATE_PLAYING)
	SSticker.delay_end = TRUE
	SSprofiler.can_fire = FALSE
	world.Profile(PROFILE_STOP)
	set_phase("settle_roundstart")
	sleep(45 SECONDS)
	if(!build_room())
		set_phase("failed_room")
		return
	sleep(10 SECONDS)
	census("baseline")
	measure("baseline", 0, 20 SECONDS)
	queue_npcs(100)
	set_awake(FALSE)
	settle("spawned", 100, 15 SECONDS)
	life_phase("dormant", 100, 30 SECONDS)
	set_awake(TRUE)
	settle("awake_settle", 100, 5 SECONDS)
	life_phase("awake", 100, 30 SECONDS)
	kill_npcs()
	set_awake(FALSE)
	settle("corpse_settle", 100, 10 SECONDS)
	life_phase("corpses_dormant", 100, 30 SECONDS)
	var/mob/living/carbon/human/sample_corpse
	for(var/mob/living/carbon/human/npc/body as anything in npcs)
		if(!QDELETED(body) && body.stat == DEAD)
			sample_corpse = body
			break
	var/obj/item/organ/brain/brain = sample_corpse?.get_organ_slot(ORGAN_SLOT_BRAIN)
	record("decay", 100, "brain_damage_asleep", brain?.damage)
	set_awake(TRUE)
	life_phase("corpses_awake", 100, 30 SECONDS)
	record("decay", 100, "brain_damage_after_waking", brain?.damage)
	set_phase("done")

/// Queues `count` NPCs through the production spawn queue and records how fast it builds them.
/datum/controller/subsystem/human_npc_spike/proc/queue_npcs(count)
	set_phase("queueing_[count]")
	var/start_built = SShuman_npcs.spawned_total
	var/start_time = world.time
	var/first_slot = length(npcs)
	for(var/i in 1 to count)
		spawn_human_npc(mob_type, npc_slot(first_slot + i), on_spawned = CALLBACK(src, PROC_REF(adopt_npc)))
	var/most_in_one_tick = 0
	var/last_built = start_built
	var/ticks = 0
	while(SShuman_npcs.spawned_total - start_built < count && ticks < 4000)
		sleep(world.tick_lag)
		ticks++
		most_in_one_tick = max(most_in_one_tick, SShuman_npcs.spawned_total - last_built)
		last_built = SShuman_npcs.spawned_total
	record("spawn_queue", count, "built", SShuman_npcs.spawned_total - start_built)
	record("spawn_queue", count, "ticks", ticks)
	record("spawn_queue", count, "seconds", (world.time - start_time) / 10)
	record("spawn_queue", count, "most_built_in_one_tick", most_in_one_tick)

/datum/controller/subsystem/human_npc_spike/proc/adopt_npc(mob/living/npc)
	npcs += npc
	GLOB.human_npc_spike_mobs[npc] = TRUE
	RegisterSignal(npc, COMSIG_QDELETING, PROC_REF(forget_mob))

/// measure(), plus how many Life() calls got past the dormancy guard.
/datum/controller/subsystem/human_npc_spike/proc/life_phase(label, n, duration)
	GLOB.human_npc_spike_life_passes = 0
	var/start = world.time
	measure(label, n, duration)
	var/seconds = max((world.time - start) / 10, 1)
	record(label, n, "life_passes", GLOB.human_npc_spike_life_passes)
	record(label, n, "life_passes_per_npc_per_s", GLOB.human_npc_spike_life_passes / max(n, 1) / seconds)

/datum/controller/subsystem/human_npc_spike/proc/settle(label, n, duration)
	set_phase("[label]_[n]")
	sleep(duration)

/datum/controller/subsystem/human_npc_spike/proc/build_room()
	reservation = SSmapping.request_turf_block_reservation(SPIKE_ROOM_W + 8, SPIKE_ROOM_H + 8, requester = "human NPC spike harness")
	if(!reservation)
		log_world("human_npc_spike: no reservation")
		return FALSE
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	origin = locate(bottom_left.x + 4, bottom_left.y + 4, bottom_left.z)
	var/area/misc/testroom/room_area = GLOB.areas_by_type[/area/misc/testroom] || new
	for(var/dx in -1 to SPIKE_ROOM_W)
		for(var/dy in -1 to SPIKE_ROOM_H)
			var/turf/spot = locate(origin.x + dx, origin.y + dy, origin.z)
			var/edge = dx == -1 || dy == -1 || dx == SPIKE_ROOM_W || dy == SPIKE_ROOM_H
			if(edge)
				spot = spot.ChangeTurf(/turf/closed/indestructible)
			else
				spot = spot.ChangeTurf(/turf/open/floor/iron)
				room_turfs += spot
			spot.change_area(spot.loc, room_area)
		CHECK_TICK
	record("room", 0, "z", origin.z)
	return TRUE

/// Spawn slot `index` (1-100): four columns, 25 rows, front column first.
/datum/controller/subsystem/human_npc_spike/proc/npc_slot(index, x_front = 9, x_step = -1)
	var/col = round((index - 1) / 25)
	var/row = (index - 1) % 25
	return locate(origin.x + x_front + col * x_step, origin.y + 5 + row, origin.z)

/datum/controller/subsystem/human_npc_spike/proc/add_npc(turf/where, list/faction)
	var/mob/living/npc = new mob_type(where)
	if(faction)
		npc.faction = faction.Copy()
	npcs += npc
	GLOB.human_npc_spike_mobs[npc] = TRUE
	RegisterSignal(npc, COMSIG_QDELETING, PROC_REF(forget_mob))
	return npc

/datum/controller/subsystem/human_npc_spike/proc/forget_mob(mob/living/gone)
	SIGNAL_HANDLER
	npcs -= gone
	dummies -= gone
	GLOB.human_npc_spike_mobs -= gone

/datum/controller/subsystem/human_npc_spike/proc/spawn_npcs_to(n)
	set_phase("spawning_[n]")
	while(length(npcs) < n)
		add_npc(npc_slot(length(npcs) + 1))
		CHECK_TICK
	record("spawn", n, "npcs", length(npcs))
	if(length(npcs))
		var/mob/living/sample = npcs[1]
		record("spawn", n, "atoms_in_one_npc", length(sample.get_all_contents()))

/datum/controller/subsystem/human_npc_spike/proc/set_awake(awake)
	GLOB.human_npc_spike_awake = awake
	for(var/mob/living/npc as anything in GLOB.human_npc_spike_mobs)
		var/datum/ai_controller/controller = npc.ai_controller
		if(!controller)
			continue
		controller.can_idle = !awake
		controller.reset_ai_status()

/// BYOND reuses freed heap, so a few dozen mobs barely move the process's private bytes. Spawns
/// `count` more dormant NPCs in the free half of the room so the outside sampler sees a real step,
/// counts the world, then deletes them again.
/datum/controller/subsystem/human_npc_spike/proc/bulk_memory(count)
	set_phase("bulk_spawning")
	set_awake(FALSE)
	var/list/bulk = list()
	for(var/i in 1 to count)
		var/turf/where = locate(origin.x + 12 + (i - 1) % 18, origin.y + round((i - 1) / 18), origin.z)
		bulk += add_npc(where)
		CHECK_TICK
	settle("bulk", length(npcs), 25 SECONDS)
	census("bulk_[length(npcs)]")
	settle("bulk_after_census", length(npcs), 15 SECONDS)
	set_phase("bulk_deleting")
	for(var/mob/living/npc as anything in bulk)
		qdel(npc)
		CHECK_TICK
	settle("bulk_deleted", length(npcs), 30 SECONDS)

/// Damage-proof clientless humans the NPCs see as hostile. Every hit lands and is processed, but
/// deals nothing, so they never fall and the fight never ends.
/datum/controller/subsystem/human_npc_spike/proc/spawn_dummies()
	for(var/k in 0 to 4)
		var/turf/where = locate(origin.x + 11, origin.y + 6 + k * 6, origin.z)
		var/mob/living/carbon/human/dummy_target = new(where)
		dummy_target.faction = list("spike_target")
		var/datum/physiology/body = dummy_target.physiology
		body.brute_mod = 0
		body.burn_mod = 0
		body.tox_mod = 0
		body.oxy_mod = 0
		body.stamina_mod = 0
		body.bleed_mod = 0
		dummies += dummy_target
		RegisterSignal(dummy_target, COMSIG_QDELETING, PROC_REF(forget_mob))

/datum/controller/subsystem/human_npc_spike/proc/clear_dummies()
	for(var/mob/living/dummy_target as anything in dummies.Copy())
		qdel(dummy_target)
	dummies.Cut()

/// Deletes blood, casings, dropped items and scorch marks left on the floor.
/datum/controller/subsystem/human_npc_spike/proc/clear_debris()
	var/removed = 0
	for(var/turf/spot as anything in room_turfs)
		for(var/atom/movable/thing as anything in spot)
			if(istype(thing, /obj/effect/decal) || isitem(thing))
				qdel(thing)
				removed++
		CHECK_TICK
	record("debris", length(npcs), "removed", removed)

/// Deletes everything in the room that isn't a client's mob.
/datum/controller/subsystem/human_npc_spike/proc/clear_room()
	for(var/turf/spot as anything in room_turfs)
		for(var/atom/movable/thing as anything in spot)
			if(ismob(thing))
				var/mob/thing_mob = thing
				if(thing_mob.client)
					continue
			qdel(thing)
		CHECK_TICK
	npcs.Cut()
	GLOB.human_npc_spike_mobs.Cut()

/// Kills every NPC with a big chest hit, as a fight would. Troopers leave their human corpse.
/datum/controller/subsystem/human_npc_spike/proc/kill_npcs()
	set_phase("killing")
	for(var/mob/living/npc as anything in npcs.Copy())
		if(QDELETED(npc))
			continue
		npc.apply_damage(300, BRUTE, BODY_ZONE_CHEST)
		if(!QDELETED(npc) && npc.stat != DEAD)
			npc.death()
		CHECK_TICK
	var/corpses = 0
	for(var/turf/spot as anything in room_turfs)
		for(var/mob/living/body in spot)
			if(body.stat == DEAD)
				corpses++
	record("corpses", 100, "corpses_in_room", corpses)

/// Times making `count` NPCs one by one, then killing each with one big hit (a trooper's kill
/// includes building its human corpse). A synchronous call can't span ticks, so the tick usage
/// delta of each call is its whole cost.
/datum/controller/subsystem/human_npc_spike/proc/bench_spawn_and_kill(count)
	set_phase("bench_spawn_kill")
	set_awake(FALSE)
	var/list/made = list()
	var/spawn_usage = 0
	for(var/i in 1 to count)
		var/turf/where = npc_slot(i)
		var/start = TICK_USAGE_REAL
		made += add_npc(where)
		spawn_usage += TICK_USAGE_REAL - start
		stoplag()
	var/kill_usage = 0
	for(var/mob/living/npc as anything in made)
		if(QDELETED(npc))
			continue
		var/start = TICK_USAGE_REAL
		npc.apply_damage(300, BRUTE, BODY_ZONE_CHEST)
		if(!QDELETED(npc) && npc.stat != DEAD)
			npc.death()
		kill_usage += TICK_USAGE_REAL - start
		stoplag()
	record("bench", count, "ms_per_spawn", TICK_DELTA_TO_MS(spawn_usage) / count)
	record("bench", count, "ms_per_kill", TICK_DELTA_TO_MS(kill_usage) / count)

/// Times `hits` hits of `projectile_type` from a human shooter on NPCs of the kind under test,
/// aimed at random zones. Each hit is processed the way a fired projectile's impact is (armour
/// check, bullet_act, wounds, gore). Damage carries between hits; an NPC that drops to hard crit
/// or dies is replaced, untimed.
/datum/controller/subsystem/human_npc_spike/proc/bench_hits(projectile_type, hits)
	set_phase("bench_hits")
	set_awake(FALSE)
	var/turf/shooter_turf = locate(origin.x + 20, origin.y + 18, origin.z)
	var/turf/target_turf = locate(origin.x + 20, origin.y + 20, origin.z)
	var/mob/living/carbon/human/shooter = new(shooter_turf)
	shooter.faction = list("spike_shooter")
	var/mob/living/target
	var/usage = 0
	var/replaced = 0
	for(var/i in 1 to hits)
		if(QDELETED(target) || target.stat >= HARD_CRIT)
			if(!QDELETED(target))
				qdel(target)
			target = add_npc(target_turf)
			replaced++
		var/obj/projectile/shot = new projectile_type(target_turf)
		shot.firer = shooter
		shot.fired_from = shooter
		shot.starting = shooter_turf
		shot.def_zone = human_npc_pick_aim_zone()
		var/start = TICK_USAGE_REAL
		target.projectile_hit(shot, shot.def_zone)
		usage += TICK_USAGE_REAL - start
		qdel(shot)
		stoplag()
	qdel(shooter)
	var/projectile_name = replacetext("[projectile_type]", "/obj/projectile/", "")
	record("bench", hits, "ms_per_hit:[projectile_name]", TICK_DELTA_TO_MS(usage) / hits)
	record("bench", hits, "targets_used:[projectile_name]", replaced)

/// Two teams of `per_side`, the kind under test on both, fight until one side is down.
/datum/controller/subsystem/human_npc_spike/proc/team_fight(per_side, label = "fight")
	var/list/team_a = list()
	var/list/team_b = list()
	for(var/i in 1 to per_side)
		team_a += add_npc(npc_slot(i, x_front = 9, x_step = -1), list("spike_a"))
		team_b += add_npc(npc_slot(i, x_front = 13, x_step = 1), list("spike_b"))
	settle("[label]_spawned", per_side, 10 SECONDS)
	set_awake(TRUE)
	var/datum/callback/fight_over = CALLBACK(src, PROC_REF(fight_over), team_a, team_b)
	measure(label, per_side, 180 SECONDS, fight_over)
	record(label, per_side, "a_standing", count_standing(team_a))
	record(label, per_side, "b_standing", count_standing(team_b))
	var/dead = 0
	for(var/turf/spot as anything in room_turfs)
		for(var/mob/living/body in spot)
			if(body.stat == DEAD)
				dead++
	record(label, per_side, "dead_bodies", dead)
	set_awake(FALSE)

/datum/controller/subsystem/human_npc_spike/proc/count_standing(list/team)
	. = 0
	for(var/mob/living/member as anything in team)
		if(!QDELETED(member) && member.stat == CONSCIOUS)
			.++

/datum/controller/subsystem/human_npc_spike/proc/fight_over(list/team_a, list/team_b)
	return !count_standing(team_a) || !count_standing(team_b)

/// Measures `duration` of play: world.cpu per tick, time dilation, and each subsystem's CPU time
/// from the MC's rolling usage, which records the real tick usage of every fire.
/datum/controller/subsystem/human_npc_spike/proc/measure(label, n, duration, datum/callback/stop_when)
	set_phase("[label]_[n]")
	for(var/datum/controller/subsystem/subsystem as anything in Master.subsystems)
		subsystem.rolling_usage = list()
	Master.rolling_usage_length = 30 MINUTES
	Master.use_rolling_usage = TRUE
	var/start_time = world.time
	var/start_real = REALTIMEOFDAY
	var/end_time = world.time + duration
	var/list/cpu_samples = list()
	var/map_cpu_sum = 0
	while(world.time < end_time)
		sleep(world.tick_lag)
		cpu_samples += world.cpu
		map_cpu_sum += world.map_cpu
		if(stop_when?.Invoke())
			break
	Master.use_rolling_usage = FALSE
	var/game_seconds = max((world.time - start_time) / 10, 0.1)
	var/real_seconds = max((REALTIMEOFDAY - start_real) / 10, 0.1)
	var/samples = max(length(cpu_samples), 1)
	var/cpu_sum = 0
	for(var/sample in cpu_samples)
		cpu_sum += sample
	sortTim(cpu_samples, cmp = GLOBAL_PROC_REF(cmp_numeric_asc))
	record(label, n, "game_seconds", game_seconds)
	record(label, n, "real_seconds", real_seconds)
	record(label, n, "cpu_avg", cpu_sum / samples)
	record(label, n, "cpu_p95", length(cpu_samples) ? cpu_samples[max(1, round(length(cpu_samples) * 0.95))] : 0)
	record(label, n, "cpu_max", length(cpu_samples) ? cpu_samples[length(cpu_samples)] : 0)
	record(label, n, "map_cpu_avg", map_cpu_sum / samples)
	record(label, n, "mob_living_list", length(GLOB.mob_living_list))
	record(label, n, "ai_on", length(GLOB.ai_controllers_by_status[AI_STATUS_ON]))
	record(label, n, "npcs_alive", count_alive())
	var/total_ms = 0
	for(var/datum/controller/subsystem/subsystem as anything in Master.subsystems)
		var/list/usage = subsystem.rolling_usage
		var/sum = 0
		for(var/i in 2 to length(usage) step 2)
			sum += usage[i]
		subsystem.rolling_usage = list()
		if(!sum)
			continue
		var/ms_per_second = TICK_DELTA_TO_MS(sum) / game_seconds
		total_ms += ms_per_second
		record(label, n, "ss_ms_per_s:[subsystem.name]", ms_per_second)
	record(label, n, "ss_total_ms_per_s", total_ms)

/datum/controller/subsystem/human_npc_spike/proc/count_alive()
	. = 0
	for(var/mob/living/npc as anything in npcs)
		if(!QDELETED(npc) && npc.stat != DEAD)
			.++

/// Runs the BYOND profiler for `duration` and saves its JSON.
/datum/controller/subsystem/human_npc_spike/proc/profile(label, n, duration)
	set_phase("profile_[label]_[n]")
	world.Profile(PROFILE_CLEAR)
	world.Profile(PROFILE_START)
	sleep(duration)
	var/data = world.Profile(PROFILE_REFRESH, format = "json")
	world.Profile(PROFILE_STOP)
	rustg_file_write(data, "[out_prefix]_profile_[label]_[n].json")

/// Counts every atom and datum in the world by type and saves the totals.
/datum/controller/subsystem/human_npc_spike/proc/census(label)
	set_phase("census_[label]")
	var/list/atoms = count_atoms()
	var/list/datums = count_datums()
	var/atom_total = 0
	for(var/key in atoms)
		atom_total += atoms[key]
	var/datum_total = 0
	for(var/key in datums)
		datum_total += datums[key]
	record("census_[label]", 0, "atoms_total", atom_total)
	record("census_[label]", 0, "datums_total", datum_total)
	rustg_file_write(json_encode(list("atoms" = atoms, "datums" = datums)), "[out_prefix]_census_[label].json")

#undef SPIKE_ROOM_W
#undef SPIKE_ROOM_H

#endif
