// Round metrics for combat: hit and kill tallies, player deaths and revivals.
// See voidcrew/modules/metrics/metrics_helpers.dm for record_metric() and tally_metric().
//
// EVENT CATALOG
//
// Hits, METRIC_COMBAT, tallied (one row per key per minute, quantity = hits).
// Fired from log_combat() (code/__HELPERS/logging/attack.dm) through metric_combat_hit() for
// the log lines that mean a living mob was really hit: melee weapons, fists and kicks, mob
// claws and bites, thrown items, projectiles, mech fists and a few special weapons (see
// metric_is_combat_hit()). Hits on yourself, on old corpses and between two NPCs are skipped.
// <class> is how the hit landed: "melee" (a weapon or mech), "unarmed" (fists, kicks,
// martial arts, NPC claws and bites), "thrown" or "ranged" (a projectile).
//   pvp_hit_<class>     A player hit another player. ckey = attacker, other_ckey = victim,
//                       zone = the attacker's, subject = weapon or projectile type, or its
//                       name when only a name was logged, or "unarmed".
//   npc_hit_<class>     A player hit an NPC. ckey = attacker, zone = the attacker's,
//                       subject = the NPC's type.
//   hit_by_npc_<class>  An NPC hit a player. other_ckey = victim, zone = the victim's,
//                       subject = the NPC's type.
//
// Kills, METRIC_COMBAT, tallied (quantity = kills).
//   npc_killed          An NPC died with a player's hit on it from the last
//                       METRIC_KILL_CREDIT_WINDOW, or a player landed the killing blow.
//                       ckey = the player with the last hit, zone = theirs at that hit,
//                       subject = the NPC's type.
//
// Deaths and revivals, METRIC_DEATH.
//   player_died         A mob a player controls died: it has a ckey, or its mind still has
//                       the player's key (ghosted or disconnected). ckey = victim,
//                       other_ckey = killer when the cause is pvp, ship = victim's crew ship,
//                       zone = where they died, quantity = 1, subject = cause:
//                         suicide      used the suicide verb
//                         pvp          last hit by a player within METRIC_KILL_CREDIT_WINDOW
//                         npc          last hit by an NPC within METRIC_KILL_CREDIT_WINDOW
//                         gibbed       gibbed or dusted, nobody hit them recently
//                         vacuum       died on a turf below HAZARD_LOW_PRESSURE, nobody hit them
//                         brain        brain damage at BRAIN_DAMAGE_DEATH
//                         suffocation, burn, toxin, brute   the largest damage type, nobody
//                                      hit them (brute covers explosions, falls, crushing)
//                         unknown      no damage at all (instant kills, smites)
//                       details: job, area, brute, burn, tox, oxy, brain, pressure (kPa, on a
//                       turf only), gibbed, suit, helmet and modsuit (worn types), chest
//                       armor_melee, armor_bullet and armor_laser, mob (type, when not human),
//                       and this life's last hit when it had one: attacker_ckey,
//                       attacker_type, weapon, hit_seconds_ago.
//   player_died_repeat  Tallied in place of player_died once one body has written
//                       METRIC_BURST_LIMIT death rows within METRIC_BURST_WINDOW (death
//                       loops). ckey, other_ckey, ship, zone, subject = cause, quantity = deaths.
//   revived             A dead player's body came back to life. ckey, ship, zone, quantity = 1,
//                       points = seconds dead, subject = method: defibrillator,
//                       reviver_implant, nanites, legion_core, strange_reagent, surgery,
//                       reagent, admin, cloning_vat or other. details: via = the proc that
//                       called revive(), read off the call stack.
//   revived_repeat      Tallied in place of revived for revive loops, same limit as deaths.
//                       ckey, zone, subject = method, quantity = revivals,
//                       points = seconds dead summed.
//   respawned           A player who died joined a ship's crew again without being revived.
//                       ckey, ship, zone, subject = job title, quantity = 1,
//                       points = seconds since the death.

/// A kill (or a death's cause) goes to whoever hit the victim within this long before it died.
/// Long enough to cover bleeding out in crit after being downed.
#define METRIC_KILL_CREDIT_WINDOW (2 MINUTES)
/// How long a mob's overmap zone is reused for its hit tallies before it is looked up again.
#define METRIC_ZONE_CACHE_TIME (30 SECONDS)
/// Full death or revival rows one body may write per METRIC_BURST_WINDOW. The rest are tallied.
#define METRIC_BURST_LIMIT 3
#define METRIC_BURST_WINDOW (1 MINUTES)

GLOBAL_DATUM_INIT(combat_metrics, /datum/combat_metrics, new)

// Per-mob state. Only numbers, text and typepaths, never references, so nothing here can hold
// a deleted atom. Unset vars cost no memory per mob.
/mob/living
	/// ckey of the player who last hit this mob. Null when the last hit came from an NPC.
	var/metric_hit_ckey
	/// Type of the mob that last hit this mob.
	var/metric_hit_attacker
	/// Weapon type (or logged name) of the last hit. Null for unarmed hits.
	var/metric_hit_weapon
	/// world.time of the last hit this life. 0 when there was none.
	var/metric_hit_time = 0
	/// Zone the last hit was tallied under.
	var/metric_hit_zone
	/// This mob's zone, reused by metric_cached_zone() until metric_zone_expires.
	var/metric_zone_cached
	var/metric_zone_expires = 0
	/// Burst limiter for death rows: when the current window began and how many rows it holds.
	var/metric_death_burst_start = 0
	var/metric_death_burst_count = 0
	/// Burst limiter for revival rows.
	var/metric_revive_burst_start = 0
	var/metric_revive_burst_count = 0

/**
 * Tallies one hit. Called from log_combat() for every combat log line, so it bails before doing
 * anything for lines that aren't hits and for fights between NPCs, and never looks up a zone
 * that isn't cached.
 */
/proc/metric_combat_hit(atom/user, atom/target, what_done, object)
	if(!SSmetrics?.accepting || user == target || !isliving(user) || !isliving(target) || !metric_is_combat_hit(what_done))
		return
	var/mob/living/attacker = user
	var/mob/living/victim = target
	var/attacker_ckey = metric_ckey(attacker)
	var/victim_ckey = metric_ckey(victim)
	if(!attacker_ckey && !victim_ckey)
		return
	// Most attacks log after their damage, so the blow that kills logs on a mob that died this
	// same tick. Anything later is someone beating a corpse.
	var/killing_blow = FALSE
	if(victim.stat == DEAD)
		if(victim.timeofdeath != world.time)
			return
		killing_blow = TRUE
	var/weapon = metric_hit_weapon(attacker, object)
	var/hit_class = metric_hit_class(weapon, what_done)
	var/zone
	if(attacker_ckey)
		zone = metric_cached_zone(attacker)
		if(victim_ckey)
			tally_metric(METRIC_COMBAT, "pvp_hit_[hit_class]", ckey = attacker_ckey, other_ckey = victim_ckey, zone = zone, subject = weapon || "unarmed")
		else
			tally_metric(METRIC_COMBAT, "npc_hit_[hit_class]", ckey = attacker_ckey, zone = zone, subject = victim.type)
	else
		zone = metric_cached_zone(victim)
		tally_metric(METRIC_COMBAT, "hit_by_npc_[hit_class]", other_ckey = victim_ckey, zone = zone, subject = attacker.type)
	victim.metric_hit_ckey = attacker_ckey
	victim.metric_hit_attacker = attacker.type
	victim.metric_hit_weapon = weapon
	victim.metric_hit_time = world.time
	victim.metric_hit_zone = zone
	if(killing_blow)
		GLOB.combat_metrics.note_killing_blow(victim, attacker_ckey, victim_ckey)

/// TRUE when a log_combat() verb means a living mob was hit. Grabs, shoves, surgery, cuffs, feeding,
/// misses and "fired at" (a shot that hasn't landed yet) don't count.
/proc/metric_is_combat_hit(what_done)
	var/static/list/hit_verbs = list(
		// Weapons, mob and alien attacks, bites, mech fists
		"attacked" = TRUE,
		"shot" = TRUE,
		"threw and hit" = TRUE,
		"stunned" = TRUE,
		"slashed" = TRUE,
		"stabbed" = TRUE,
		"zapped" = TRUE,
		"power fisted" = TRUE,
		"flamethrowered" = TRUE,
		"drilled" = TRUE,
		"broke the kneecaps of" = TRUE,
		"run over" = TRUE,
		"ran over" = TRUE,
		// Unarmed
		"punched" = TRUE,
		"kicked" = TRUE,
		"grapple punched" = TRUE,
		// Martial arts
		"punched (boxing) " = TRUE,
		"punched (Sleeping Carp)" = TRUE,
		"strong punched (Sleeping Carp)" = TRUE,
		"launchkicked (Sleeping Carp)" = TRUE,
		"dropkicked (Sleeping Carp)" = TRUE,
		"slammed (CQC)" = TRUE,
		"kicked (CQC)" = TRUE,
		"pressured (CQC)" = TRUE,
		"snapped neck" = TRUE,
		"neck chopped" = TRUE,
		"body-slammed" = TRUE,
		"headbutted" = TRUE,
		"leg-dropped" = TRUE,
		// Voidcrew cyberware and unique weapons
		"piston-punched" = TRUE,
		"mantis-lunged" = TRUE,
		"punched (scrapper's knuckles)" = TRUE,
		"redlined a bypassed unarmed strike on" = TRUE,
		"crushed with a Meteor Piledriver landing" = TRUE,
		"breached" = TRUE,
		"siphoned with" = TRUE,
	)
	return istext(what_done) && hit_verbs[what_done]

/**
 * The weapon behind a hit: the type of the item, projectile or mech handed to log_combat().
 * Item attacks log only the item's name, so a held item with that name stands in for it; any
 * other name is kept as text. Null for unarmed and natural attacks.
 */
/proc/metric_hit_weapon(mob/living/attacker, object)
	if(istext(object))
		var/obj/item/held = attacker.get_active_held_item()
		if(held?.name == object)
			return held.type
		return object
	if(istype(object, /datum))
		var/datum/used = object
		return used.type
	return null

/// How a hit landed, from metric_hit_weapon()'s result: "ranged", "thrown", "melee" or "unarmed".
/proc/metric_hit_class(weapon, what_done)
	if(ispath(weapon, /obj/projectile))
		return "ranged"
	if(what_done == "threw and hit")
		return "thrown"
	if(weapon)
		return "melee"
	return "unarmed"

/// A mob's zone, looked up at most once per METRIC_ZONE_CACHE_TIME. Hits are too frequent for
/// metric_zone(), and a ship takes far longer than that to cross into another zone.
/proc/metric_cached_zone(mob/living/player)
	if(world.time < player.metric_zone_expires)
		return player.metric_zone_cached
	player.metric_zone_cached = metric_zone(player)
	player.metric_zone_expires = world.time + METRIC_ZONE_CACHE_TIME
	return player.metric_zone_cached

/**
 * Why a player died, for the subject of a player_died row. Pass the killer only when their hit
 * landed within METRIC_KILL_CREDIT_WINDOW of the death. `pressure` is null when unknown.
 */
/proc/metric_death_cause(suicided, gibbed, killer_ckey, killer_type, brute = 0, burn = 0, tox = 0, oxy = 0, brain = 0, pressure = null)
	if(suicided)
		return "suicide"
	if(killer_ckey)
		return "pvp"
	if(killer_type)
		return "npc"
	if(gibbed)
		return "gibbed"
	if(!isnull(pressure) && pressure < HAZARD_LOW_PRESSURE)
		return "vacuum"
	if(brain >= BRAIN_DAMAGE_DEATH)
		return "brain"
	var/worst = max(brute, burn, tox, oxy)
	if(worst <= 0)
		return "unknown"
	if(oxy == worst)
		return "suffocation"
	if(burn == worst)
		return "burn"
	if(tox == worst)
		return "toxin"
	return "brute"

/**
 * Finds what called revive(), by walking up the call stack from a COMSIG_LIVING_REVIVE handler
 * to the first proc above revive() and heal_and_revive(). Returns list(that proc's src, its name,
 * its path), or null. Only runs when a dead player comes back, so the walk is cheap enough.
 */
/proc/metric_revive_site()
	var/callee/frame = caller
	var/seen_revive = FALSE
	for(var/depth in 1 to 16)
		if(isnull(frame))
			return null
		var/path = "[frame.proc]"
		var/proc_name = copytext(path, findlasttext(path, "/") + 1)
		if(proc_name == "revive" || proc_name == "heal_and_revive")
			seen_revive = TRUE
		else if(seen_revive)
			return list(frame.src, proc_name, path)
		frame = frame.caller
	return null

/// Names the revival method from metric_revive_site()'s src and proc name.
/proc/metric_revive_method(datum/site_src, proc_name)
	if(proc_name == "do_strange_reagent_revival")
		return "strange_reagent"
	if(istype(site_src, /obj/item/shockpaddles))
		return "defibrillator"
	if(istype(site_src, /obj/item/organ/cyberimp/chest/reviver))
		return "reviver_implant"
	if(istype(site_src, /datum/nanite_program))
		return "nanites"
	if(istype(site_src, /obj/item/organ/monster_core/regenerative_core))
		return "legion_core"
	if(istype(site_src, /datum/surgery_step))
		return "surgery"
	if(istype(site_src, /datum/reagent))
		return "reagent"
	if(istype(site_src, /datum/admins) || istype(site_src, /datum/admin_verb) || istype(site_src, /datum/secrets_menu))
		return "admin"
	return "other"

/// A cloning vat woke a dead player up in a fresh body. Called from /obj/machinery/cloning_vat/proc/claim().
/proc/metric_clone_revival(mob/living/clone, mob/old_body)
	if(!SSmetrics.accepting)
		return
	var/player_ckey = metric_ckey(clone)
	if(!player_ckey)
		return
	var/died_at = GLOB.combat_metrics.last_death_by_ckey[player_ckey]
	if(isliving(old_body))
		var/mob/living/corpse = old_body
		if(corpse.stat == DEAD)
			died_at = corpse.timeofdeath
	GLOB.combat_metrics.record_revival(clone, player_ckey, "cloning_vat", died_at ? world.time - died_at : 0)

/// Watches deaths, revivals and crew joins. Hits come in through metric_combat_hit().
/datum/combat_metrics
	/**
	 * Deaths waiting for the rest of their tick, keyed by REF() of the mob. Most attacks log after
	 * their damage, so the killing blow reaches metric_combat_hit() just after the death signal.
	 * Written out on the next tick. Records hold no references except a weakref to the ship.
	 */
	var/list/pending_deaths = list()
	/// TRUE while a write of pending_deaths is scheduled.
	var/flush_scheduled = FALSE
	/// world.time of each player's last death, by ckey, until they are revived or join again.
	var/list/last_death_by_ckey = list()

/datum/combat_metrics/New()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH, PROC_REF(on_mob_death))
	RegisterSignal(SSdcs, COMSIG_GLOB_CREWMEMBER_JOINED, PROC_REF(on_crewmember_joined))

/// Every mob death. Planets kill NPCs by the thousand, so one no player touched returns at once.
/datum/combat_metrics/proc/on_mob_death(datum/source, mob/living/died, gibbed)
	SIGNAL_HANDLER
	if(!SSmetrics.accepting)
		return
	var/victim_ckey = metric_ckey(died)
	if(!victim_ckey)
		if(died.metric_hit_ckey && world.time - died.metric_hit_time <= METRIC_KILL_CREDIT_WINDOW)
			add_pending_death(died)
		return
	var/list/record = add_pending_death(died)
	record["ckey"] = victim_ckey
	record["repeat"] = over_burst_limit(died, revival = FALSE)
	record["suicide"] = HAS_TRAIT(died, TRAIT_SUICIDED)
	record["gibbed"] = gibbed
	var/obj/structure/overmap/ship/ship = metric_crew_ship(died)
	if(ship)
		record["ship"] = WEAKREF(ship)
	record["zone"] = metric_zone(died)
	record["details"] = death_details(died, gibbed)
	last_death_by_ckey[victim_ckey] = world.time
	RegisterSignal(died, COMSIG_LIVING_REVIVE, PROC_REF(on_revive), override = TRUE)

/// Starts a pending death from the mob's last hit, and schedules the write.
/datum/combat_metrics/proc/add_pending_death(mob/living/died)
	var/list/record = list(
		"type" = died.type,
		"died_at" = world.time,
		"killer_ckey" = died.metric_hit_ckey,
		"killer_type" = died.metric_hit_attacker,
		"weapon" = died.metric_hit_weapon,
		"hit_time" = died.metric_hit_time,
		"hit_zone" = died.metric_hit_zone,
	)
	pending_deaths[REF(died)] = record
	if(!flush_scheduled)
		flush_scheduled = TRUE
		addtimer(CALLBACK(src, PROC_REF(flush_pending_deaths)), 1)
	return record

/// The hit that just landed on a mob that died this tick: it becomes the killer.
/datum/combat_metrics/proc/note_killing_blow(mob/living/victim, attacker_ckey, victim_ckey)
	var/list/record = pending_deaths[REF(victim)]
	if(!record)
		// A player's blow on an NPC nobody else had credit for. add_pending_death() reads the hit
		// metric_combat_hit() just stored on the mob.
		if(attacker_ckey && !victim_ckey)
			add_pending_death(victim)
		return
	record["killer_ckey"] = victim.metric_hit_ckey
	record["killer_type"] = victim.metric_hit_attacker
	record["weapon"] = victim.metric_hit_weapon
	record["hit_time"] = victim.metric_hit_time
	record["hit_zone"] = victim.metric_hit_zone

/// Writes the deaths gathered since the last tick.
/datum/combat_metrics/proc/flush_pending_deaths()
	flush_scheduled = FALSE
	var/list/records = pending_deaths
	pending_deaths = list()
	if(!SSmetrics.accepting)
		return
	for(var/key in records)
		var/list/record = records[key]
		var/credited = record["hit_time"] && record["died_at"] - record["hit_time"] <= METRIC_KILL_CREDIT_WINDOW
		if(!record["ckey"])
			if(credited && record["killer_ckey"])
				tally_metric(METRIC_COMBAT, "npc_killed", ckey = record["killer_ckey"], zone = record["hit_zone"], subject = record["type"])
			continue
		write_player_death(record, credited)

/datum/combat_metrics/proc/write_player_death(list/record, credited)
	var/killer_ckey = credited ? record["killer_ckey"] : null
	var/list/details = record["details"]
	var/cause = metric_death_cause(record["suicide"], record["gibbed"], killer_ckey, credited ? record["killer_type"] : null, details["brute"], details["burn"], details["tox"], details["oxy"], details["brain"] || 0, details["pressure"])
	var/pvp_killer = cause == "pvp" ? killer_ckey : null
	var/datum/weakref/ship_ref = record["ship"]
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	if(record["repeat"])
		tally_metric(METRIC_DEATH, "player_died_repeat", ckey = record["ckey"], other_ckey = pvp_killer, ship = ship, zone = record["zone"], subject = cause)
		return
	if(record["hit_time"])
		if(record["killer_ckey"])
			details["attacker_ckey"] = record["killer_ckey"]
		details["attacker_type"] = "[record["killer_type"]]"
		if(record["weapon"])
			details["weapon"] = "[record["weapon"]]"
		details["hit_seconds_ago"] = round((record["died_at"] - record["hit_time"]) / 10)
	record_metric(METRIC_DEATH, "player_died", ckey = record["ckey"], other_ckey = pvp_killer, ship = ship, zone = record["zone"], subject = cause, quantity = 1, details = details)

/// What a player died with and in, snapshotted at the death since the body may be gibbed right after.
/datum/combat_metrics/proc/death_details(mob/living/died, gibbed)
	var/list/details = list(
		"brute" = round(died.getBruteLoss()),
		"burn" = round(died.getFireLoss()),
		"tox" = round(died.getToxLoss()),
		"oxy" = round(died.getOxyLoss()),
	)
	var/brain = round(died.get_organ_loss(ORGAN_SLOT_BRAIN))
	if(brain)
		details["brain"] = brain
	var/job = died.mind?.assigned_role?.title
	if(job)
		details["job"] = job
	var/area_name = get_area_name(died, format_text = TRUE)
	if(area_name)
		details["area"] = area_name
	if(gibbed)
		details["gibbed"] = TRUE
	// Only the open air they lay in. Inside a locker, mech or sleeper their exposure is unknown.
	if(isturf(died.loc))
		var/turf/location = died.loc
		var/datum/gas_mixture/air = location.return_air_readonly()
		if(air)
			details["pressure"] = round(air.return_pressure())
	if(!ishuman(died))
		details["mob"] = "[died.type]"
		return details
	var/mob/living/carbon/human/human_died = died
	if(human_died.wear_suit)
		details["suit"] = "[human_died.wear_suit.type]"
	if(human_died.head)
		details["helmet"] = "[human_died.head.type]"
	if(istype(human_died.back, /obj/item/mod/control))
		details["modsuit"] = "[human_died.back.type]"
	details["armor_melee"] = round(human_died.getarmor(BODY_ZONE_CHEST, MELEE))
	details["armor_bullet"] = round(human_died.getarmor(BODY_ZONE_CHEST, BULLET))
	details["armor_laser"] = round(human_died.getarmor(BODY_ZONE_CHEST, LASER))
	return details

/// Registered on a dead player's body. revive() sends this for every heal, dead or not.
/datum/combat_metrics/proc/on_revive(mob/living/source, full_heal_flags)
	SIGNAL_HANDLER
	if(source.stat == DEAD)
		return
	UnregisterSignal(source, COMSIG_LIVING_REVIVE)
	// A new life starts without the old killer.
	source.metric_hit_ckey = null
	source.metric_hit_attacker = null
	source.metric_hit_weapon = null
	source.metric_hit_time = 0
	source.metric_hit_zone = null
	if(!SSmetrics.accepting)
		return
	var/player_ckey = metric_ckey(source)
	if(!player_ckey)
		return
	var/list/site = metric_revive_site()
	var/method = metric_revive_method(site?[1], site?[2])
	record_revival(source, player_ckey, method, world.time - source.timeofdeath, site?[3])

/// Writes a revival, or tallies it when this body keeps coming back.
/datum/combat_metrics/proc/record_revival(mob/living/body, player_ckey, method, deciseconds_dead, via)
	last_death_by_ckey -= player_ckey
	var/seconds_dead = max(0, round(deciseconds_dead / 10))
	if(over_burst_limit(body, revival = TRUE))
		tally_metric(METRIC_DEATH, "revived_repeat", ckey = player_ckey, zone = metric_cached_zone(body), subject = method, points = seconds_dead)
		return
	record_metric(METRIC_DEATH, "revived", ckey = player_ckey, subject = method, points = seconds_dead, quantity = 1, details = via ? list("via" = via) : null, actor = body)

/// A player joined a crew. If they died and were never revived, that's a respawn.
/datum/combat_metrics/proc/on_crewmember_joined(datum/source, mob/living/character, rank)
	SIGNAL_HANDLER
	if(!SSmetrics.accepting)
		return
	var/player_ckey = metric_ckey(character)
	if(!player_ckey)
		return
	var/died_at = last_death_by_ckey[player_ckey]
	if(!died_at)
		return
	last_death_by_ckey -= player_ckey
	record_metric(METRIC_DEATH, "respawned", ckey = player_ckey, subject = rank, points = max(0, round((world.time - died_at) / 10)), quantity = 1, actor = character)

/// Counts one death or revival row for a body. TRUE once it is past METRIC_BURST_LIMIT this window.
/datum/combat_metrics/proc/over_burst_limit(mob/living/body, revival)
	if(revival)
		if(!body.metric_revive_burst_start || world.time - body.metric_revive_burst_start > METRIC_BURST_WINDOW)
			body.metric_revive_burst_start = world.time
			body.metric_revive_burst_count = 0
		body.metric_revive_burst_count++
		return body.metric_revive_burst_count > METRIC_BURST_LIMIT
	if(!body.metric_death_burst_start || world.time - body.metric_death_burst_start > METRIC_BURST_WINDOW)
		body.metric_death_burst_start = world.time
		body.metric_death_burst_count = 0
	body.metric_death_burst_count++
	return body.metric_death_burst_count > METRIC_BURST_LIMIT

#undef METRIC_KILL_CREDIT_WINDOW
#undef METRIC_ZONE_CACHE_TIME
#undef METRIC_BURST_LIMIT
#undef METRIC_BURST_WINDOW
