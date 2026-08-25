/**
 * NT Customs Patrol - NTSV Vigilant
 *
 * A Nanotrasen customs corvette dispatched by mission code (first customer: the
 * drug smuggling mission) to hunt a specific player ship across the overmap.
 * Unlike regular pirates it never scans for prey - it only ever fights the
 * quarry it was dispatched against.
 *
 * Flow: dispatch_nt_patrol() spawns the ship 4-6 tiles from the quarry and
 * opens with a hail (holopad negotiation: pay the exact fine set by the mission
 * or surrender the demanded contraband). Refusal/flight escalates through the
 * standard interdiction -> boarding waves -> boss pipeline. When disabled (boss
 * killed) the ship warps out and despawns - no loot, no claim. A
 * /datum/nt_patrol_director babysits the hunt: re-engages after the quarry
 * docks and flies again, and breaks off after a cumulative DRUG_COP_GIVEUP_TIME
 * without a target.
 */

/// How often the hunt director re-evaluates the chase
#define NT_PATROL_TICK_INTERVAL (30 SECONDS)
/// Delay between the boss dying (ship disabled) and the emergency warp-out
#define NT_PATROL_DISABLED_WARP_DELAY (15 SECONDS)
/// Delay between a paid fine / surrendered contraband and departure
#define NT_PATROL_SATISFIED_WARP_DELAY (8 SECONDS)
/// Preferred spawn distance band from the quarry (overmap tiles)
#define NT_PATROL_SPAWN_DIST_MIN 4
#define NT_PATROL_SPAWN_DIST_MAX 6
/// Widened search radius if the preferred band is fully blocked
#define NT_PATROL_SPAWN_DIST_FALLBACK 10

// ==================== THE SHIP ====================

/obj/structure/overmap/ship/npc/pirate/nt_patrol
	name = "NTSV Vigilant"
	desc = "A Nanotrasen customs enforcement corvette. Its transponder broadcasts an active contraband interdiction warrant."

	shuttle_template = /datum/map_template/shuttle/voidcrew/nt_patrol
	ship_color = NPC_COLOR_NANOTRASEN

	// Hunter, not a predator: never scans for prey, only fights its assigned
	// quarry (the director hands it a target directly)
	hostile = FALSE
	// Chases the quarry across zone lines
	zone_confined = FALSE
	// Never lose the quarry to range checks once assigned
	territory_range = 99

	// Well-funded corporate engines - slightly faster than the pirate rabble
	speed_limit = 0.6
	thrust_power = 0.35

	// Combat stats - balanced against the standard pirate loadout
	lock_time = 5 SECONDS
	laser_cooldown_time = 6 SECONDS
	missile_cooldown_time = 15 SECONDS
	npc_cloak_duration = 5 SECONDS

	// Customs assesses fines, it does not siphon accounts
	siphon_goal_percent = 0

	// Crew configuration - NT customs enforcement detail
	crew_min = 3
	crew_max = 5
	captain_type = /mob/living/basic/trooper/nanotrasen/ranged/assault/customs
	crew_types = list(
		/mob/living/basic/trooper/nanotrasen/customs,
		/mob/living/basic/trooper/nanotrasen/ranged/smg/customs,
		/mob/living/basic/trooper/nanotrasen/ranged/smg/customs,
	)

	// Negotiation - the "fine". Dispatch overwrites both bounds with the exact
	// fine so calculate_demand()'s clamp always lands on it; these are inert
	// placeholders for any patrol that somehow spawns outside dispatch.
	accepts_negotiation = TRUE
	negotiation_dialog_type = /datum/pirate_faction_dialog/nt_patrol
	min_negotiation_demand = 5000
	max_negotiation_demand = 5000
	pirate_faction = "nt_patrol"

	// Fines collected earlier on the patrol route, sitting in the corvette's own
	// accounts. Robbing a customs vessel is exactly as legal as it sounds.
	hold_credits_min = 2000
	hold_credits_max = 4000

	// Boarding pods during open ship combat - compliance teams
	boarding_pods_enabled = TRUE
	boarding_pods_min = 1
	boarding_pods_max = 2
	boarding_pod_cooldown_time = 30 SECONDS
	boarding_pod_mob_types = list(
		/mob/living/basic/trooper/nanotrasen/customs,
		/mob/living/basic/trooper/nanotrasen/ranged/smg/customs,
	)

	// Phased combat - compliance action waves, then the Director
	uses_boarding_phases = TRUE
	boarding_wave_sizes = list(
		list(2, 3),  // Wave 1
		list(3, 4),  // Wave 2
		list(3, 5),  // Wave 3
	)
	boss_type = /mob/living/basic/trooper/pirate/faction/boss/nt_patrol
	wave_taunts = list(
		list(  // Wave 1 -> 2 cooldown
			"Compliance teams are inbound. This is a billable action.",
			"Casualties among our personnel have been added to your invoice.",
		),
		list(  // Wave 2 -> 3 cooldown
			"Your continued resistance has been escalated to Asset Recovery.",
			"Be advised: destruction of Nanotrasen property carries a per-unit surcharge.",
		),
		list(  // Boss spawn
			"All field teams expended. The Compliance Director is en route to close your file personally.",
			"Escalation approved. The Director will conduct your exit interview in person.",
		),
	)

	/// Set while the emergency warp is in progress - makes warp_out() idempotent
	var/warping_out = FALSE

/**
 * Disabled endpoint override: a boarded-and-beheaded customs corvette is not a
 * prize. Instead of sitting there claimable it spools emergency FTL and
 * warp_out()s after a short delay. Deliberately does NOT call parent -
 * parent's version announces "you may now board and claim the vessel".
 */
/obj/structure/overmap/ship/npc/pirate/nt_patrol/set_disabled_state()
	if(is_disabled)
		return
	is_disabled = TRUE
	// Not claimable - it will be gone in moments
	can_board = FALSE

	var/datum/ai_controller/npc_ship/controller = ai_controller
	if(controller)
		var/obj/structure/overmap/ship/target = controller.get_target()
		if(target && !QDELETED(target))
			target.ship_notify("[name]'s command element is down! The vessel is spooling emergency FTL - it will not be boardable.", "COMBAT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		controller.set_combat_state(NPC_COMBAT_DISABLED)

	ship_notify("Command element lost. Emergency extraction authorized.", "CRITICAL", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)

	addtimer(CALLBACK(src, PROC_REF(warp_out)), NT_PATROL_DISABLED_WARP_DELAY)

/**
 * The single despawn seam for the patrol (a deeper police system can replace
 * the body of this proc later). Brief visual flourish, then the ship - and its
 * interior, via /obj/structure/overmap/ship/Destroy() -> shuttle.intoTheSunset()
 * - is deleted. No loot, no claim.
 *
 * Refuses to fire while players are aboard the patrol's interior (deleting the
 * shuttle would delete them too); retries shortly after instead.
 */
/obj/structure/overmap/ship/npc/pirate/nt_patrol/proc/warp_out()
	if(warping_out || QDELETED(src))
		return
	if(has_players_aboard())
		// Boarders are still inside - try again once they have (or haven't) left
		addtimer(CALLBACK(src, PROC_REF(warp_out)), NT_PATROL_TICK_INTERVAL)
		return
	warping_out = TRUE
	// One-off ship: no pirate replacement, no bounty bookkeeping
	spawner_resolved = TRUE

	var/turf/our_turf = get_turf(src)
	if(our_turf)
		playsound(our_turf, 'sound/effects/magic/wand_teleport.ogg', 75, TRUE)
		do_sparks(3, FALSE, src)
	visible_message(span_notice("[src] flares blue-white and jumps out of the sector."))

	qdel(src)

/// Whether any player-controlled living mob is inside the patrol's interior
/obj/structure/overmap/ship/npc/pirate/nt_patrol/proc/has_players_aboard()
	if(!shuttle?.shuttle_areas)
		return FALSE
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/mob/living/occupant in shuttle_area)
			if(occupant.client)
				return TRUE
	return FALSE

// ==================== INTERIOR DEFENSE TURRETS ====================
// Referenced by ship_nt_patrol.dmm - same pattern as the pirate turrets in
// faction_pirate_equipment.dm, but keyed to the NT crew's faction so they
// don't gun down their own officers.
//
// req_access is deliberately an access nobody aboard carries. The crew are
// basic mobs with no ID cards, so the swipe lock only ever gates boarders -
// and the inherited ACCESS_SYNDICATE gated it the wrong way round, since
// voidcrew's syndicate job outfits hand players that access at roundstart.
// The counterplay is the turretid console, which ship_nt_patrol.dmm maps
// unlocked on purpose.

/obj/machinery/porta_turret/syndicate/nt_patrol
	name = "corporate security turret"
	desc = "A ballistic auto-turret keyed to Nanotrasen security transponders."
	faction = list(ROLE_DEATHSQUAD)
	req_access = list(ACCESS_CENT_GENERAL)

/obj/machinery/porta_turret/syndicate/energy/nt_patrol
	name = "corporate laser turret"
	desc = "An energy blaster auto-turret keyed to Nanotrasen security transponders."
	faction = list(ROLE_DEATHSQUAD)
	req_access = list(ACCESS_CENT_GENERAL)

// ==================== CREW MOBS ====================
// Space-capable customs variants of the upstream NT troopers
// (code/modules/mob/living/basic/trooper/nanotrasen.dm). Mirrors what
// /mob/living/basic/trooper/pirate/faction does for pirate crews: atmos
// immunity + TRAIT_SPACEWALK so ship interiors and boarding actions work.

/// Customs guard - melee escort with a stun baton
/mob/living/basic/trooper/nanotrasen/customs
	name = "\improper Nanotrasen Customs Officer"
	desc = "A Nanotrasen customs officer, here to search your ship. The baton is standard issue."
	maxHealth = 110
	health = 110
	melee_damage_lower = 12
	melee_damage_upper = 18
	attack_verb_continuous = "batons"
	attack_verb_simple = "baton"
	attack_sound = 'sound/items/weapons/genhit1.ogg'
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	minimum_survivable_temperature = 0
	r_hand = /obj/item/melee/baton/security

/mob/living/basic/trooper/nanotrasen/customs/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)

/// Customs inspector - SMG-armed ranged officer
/mob/living/basic/trooper/nanotrasen/ranged/smg/customs
	name = "\improper Nanotrasen Customs Inspector"
	desc = "A Nanotrasen customs inspector. Authorized to conduct searches, seizures, and suppressive fire."
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	minimum_survivable_temperature = 0

/mob/living/basic/trooper/nanotrasen/ranged/smg/customs/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)

/// Customs sergeant - assault-rifle captain of the patrol (carries the ship key)
/mob/living/basic/trooper/nanotrasen/ranged/assault/customs
	name = "\improper Nanotrasen Customs Sergeant"
	desc = "The ranking customs officer aboard. Personally responsible for this quarter's seizure figures."
	maxHealth = 120
	health = 120
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	minimum_survivable_temperature = 0

/mob/living/basic/trooper/nanotrasen/ranged/assault/customs/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)

// ==================== THE BOSS ====================
// Subtypes /mob/living/basic/trooper/pirate/faction/boss because
// create_boss_boarding_pod() (boarding_pod.dm) writes boss.parent_ship and the
// boss death hook lives on that type - an upstream NT trooper would runtime.
// Flavor and loadout are pure Nanotrasen.

/mob/living/basic/trooper/pirate/faction/boss/nt_patrol
	name = "NT Compliance Director"
	desc = "A senior Nanotrasen compliance executive in body armor, sent out when the paperwork stops working."
	maxHealth = 350
	health = 350
	melee_damage_lower = 20
	melee_damage_upper = 25
	armour_penetration = 25
	attack_verb_continuous = "restructures"
	attack_verb_simple = "restructure"
	attack_sound = 'sound/items/weapons/genhit1.ogg'
	attack_vis_effect = ATTACK_EFFECT_PUNCH
	faction = list(ROLE_DEATHSQUAD)
	mob_spawner = /obj/effect/mob_spawn/corpse/human/nanotrasenelitesoldier
	corpse = /obj/effect/mob_spawn/corpse/human/nanotrasenelitesoldier
	r_hand = /obj/item/gun/energy/e_gun
	loot_pool = list(/obj/item/gun/energy/e_gun, /obj/item/melee/baton/security/loaded)
	plunder_credits = 2000
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 3
	var/ranged_cooldown = 5 SECONDS

/mob/living/basic/trooper/pirate/faction/boss/nt_patrol/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

// ==================== NEGOTIATION DIALOG ====================

/datum/pirate_faction_dialog/nt_patrol
	faction_name = "Nanotrasen Customs Enforcement"
	demand_multiplier = 1.0
	patience_modifier = 1.0

	greetings = list(
		"This is Nanotrasen Customs Enforcement. Your vessel has been flagged under Controlled Substances Directive 7-C.",
		"NTSV Vigilant to unidentified trafficker. Cut your engines. A compliance inspection is now in progress.",
		"Attention vessel. Nanotrasen Customs. We have reviewed your cargo manifest and it is not complete.",
	)
	demand_lines = list(
		"You are in violation of Nanotrasen Controlled Substances Directive 7-C. A compliance fine of %CREDITS% credits has been assessed. Alternatively, surrender %QUANTITY% %ITEM% for destruction. Payment resolves this incident.",
		"Per Directive 7-C, your outstanding compliance fine is %CREDITS% credits. Surrender of %QUANTITY% %ITEM% will also be accepted as remediation in kind.",
		"Your options, per corporate policy: remit %CREDITS% credits, or transfer %QUANTITY% %ITEM% to our custody. Choose promptly - processing windows are billed.",
	)
	barter_demand_lines = list(
		"Your accounts cannot cover the assessed fine. Directive 7-C permits remediation in kind. Transfer %QUANTITY% %ITEM% to our custody.",
		"Insufficient funds on file. This incident may still be resolved by surrendering %QUANTITY% %ITEM% for destruction.",
		"We are unable to collect a fine from an empty account. Surrender %QUANTITY% %ITEM% and the file closes.",
	)
	barter_escalation_lines = list(
		"Processing delay noted. Your remediation requirement is now %QUANTITY% %ITEM%.",
		"The compliance window is billed by the minute. Revised requirement: %QUANTITY% %ITEM%.",
	)
	acceptance_lines = list(
		"Payment processed. This incident is resolved. Nanotrasen thanks you for your cooperation.",
		"Remediation received. Your compliance record has been annotated accordingly. You are free to proceed.",
		"Transaction logged. Consider retaining a licensed customs broker in future. Good day.",
	)
	rejection_lines = list(
		"Refusal noted for the record. Escalating to compliance action. Boarding teams are launching, and you are paying for them.",
		"Non-payment has been logged as an admission of liability. Commencing asset recovery.",
		"Very well. Your file goes to Enforcement. They don't negotiate.",
	)
	timeout_lines = list(
		"Your payment window has closed. We do this the expensive way now.",
		"Processing window expired. Escalating per standard operating procedure.",
	)
	impatience_lines = list(
		"Be advised: your compliance window closes in %SECONDS% seconds.",
		"%SECONDS% seconds remain on this offer. Interest accrues thereafter.",
	)
	flee_warning_lines = list(
		"Leaving an active inspection is its own violation. Interdiction engaged, and your fine just went up.",
		"Running from customs is a Class II infraction. You are not going anywhere, and that just cost you extra.",
	)
	movement_betrayal_lines = list(
		"Second evasion attempt logged. Lethal enforcement is authorized. You will be billed for that as well.",
		"You were warned. Weapons free. The paperwork will describe this as 'aggressive remediation'.",
	)
	escape_warning_lines = list(
		"Do not attempt to flee or target this vessel. Any hostile act will be met with immediate enforcement action.",
		"For the record: running or shooting during an inspection voids your right to arbitration.",
	)

// ==================== CAPTAIN HOLOGRAM PRESET ====================
// Wired into pirate_hologram.dm's get_faction_holoimage() "nt_patrol" case.

/datum/preset_holoimage/pirate_captain/nt_patrol
	outfit_type = /datum/outfit/centcom/centcom_official

// ==================== HUNT DIRECTOR ====================

/**
 * Dispatch an NT customs patrol against a player ship.
 *
 * Spawns the NTSV Vigilant on a clear overmap tile 4-6 tiles from the quarry,
 * fixes its negotiation demand to the exact fine, opens the hail, and returns
 * a /datum/nt_patrol_director managing the hunt (null on spawn failure).
 *
 * May sleep (shuttle template load) - call from a sleepable context or via
 * INVOKE_ASYNC.
 *
 * @param quarry The player ship to hunt
 * @param fine_credits Exact credit fine demanded in negotiation
 * @param item_demand Optional list(type, quantity, name) - the item-surrender
 *   alternative (e.g. the contraband itself). Passed verbatim to
 *   fixed_item_demand; surrendered items are qdel'd by the negotiation.
 */
/proc/dispatch_nt_patrol(obj/structure/overmap/ship/quarry, fine_credits, list/item_demand)
	if(!quarry || QDELETED(quarry))
		return null

	var/turf/spawn_turf = find_nt_patrol_spawn_turf(quarry)
	if(!spawn_turf)
		log_shuttle("NT_PATROL: No clear overmap turf near [quarry.name] - dispatch aborted")
		return null

	var/obj/structure/overmap/ship/npc/pirate/nt_patrol/ship = SSnpc_ships.create_npc_ship(/datum/map_template/shuttle/voidcrew/nt_patrol, spawn_turf, /obj/structure/overmap/ship/npc/pirate/nt_patrol)
	if(!ship)
		log_shuttle("NT_PATROL: create_npc_ship failed - dispatch aborted")
		return null

	// Track like any other active NPC ship (create_npc_ship bypasses the
	// faction pool, so spawn_npc_ship's bookkeeping didn't run)
	SSnpc_ships.active_ships |= ship

	// One-off ship: pre-resolve so no pirate replacement ever spawns for it
	ship.spawner_resolved = TRUE

	// The fine: min == max means calculate_demand()'s clamp lands exactly here
	ship.min_negotiation_demand = fine_credits
	ship.max_negotiation_demand = fine_credits
	if(length(item_demand))
		ship.fixed_item_demand = item_demand

	var/datum/nt_patrol_director/director = new(ship, quarry)
	director.begin_hunt()

	log_shuttle("NT_PATROL: Dispatched [ship.name] against [quarry.name] at ([spawn_turf.x], [spawn_turf.y]) - fine [fine_credits] cr")
	return director

/**
 * Find a clear overmap turf 4-6 tiles from the quarry (widening to 10 if that
 * band is fully blocked). Clear = not pathfinding-blocked and holding no other
 * overmap structure.
 */
/proc/find_nt_patrol_spawn_turf(obj/structure/overmap/ship/quarry, max_dist = NT_PATROL_SPAWN_DIST_MAX)
	var/turf/origin = get_turf(quarry)
	if(!origin)
		return null

	var/list/candidates = list()
	for(var/turf/candidate as anything in RANGE_TURFS(max_dist, origin))
		if(get_dist(origin, candidate) < NT_PATROL_SPAWN_DIST_MIN)
			continue
		if(overmap_turf_blocked(candidate))
			continue
		if(locate(/obj/structure/overmap) in candidate)
			continue
		candidates += candidate

	if(length(candidates))
		return pick(candidates)

	// Preferred band fully blocked - widen the search once
	if(max_dist < NT_PATROL_SPAWN_DIST_FALLBACK)
		return find_nt_patrol_spawn_turf(quarry, NT_PATROL_SPAWN_DIST_FALLBACK)
	return null

/**
 * Self-contained hunt manager for one dispatched patrol.
 *
 * Owns a 30-second re-evaluation timer:
 * - quarry docked/landed (check_disengage cleared the target) -> lurk,
 *   accumulating targetless time, and re-sic when the quarry flies again
 *   (unless the fine was paid / tribute immunity is active)
 * - cumulative targetless time beyond DRUG_COP_GIVEUP_TIME -> break off and
 *   warp out
 * - fine paid or contraband surrendered (successful negotiation) -> depart
 *
 * The mission holds this ref and calls stand_down() when it ends; the director
 * never qdels itself, it only goes inert, so the mission-side ref stays valid.
 */
/datum/nt_patrol_director
	/// The dispatched patrol ship
	var/obj/structure/overmap/ship/npc/pirate/nt_patrol/patrol_ship
	/// The ship being hunted (weakref - the quarry may die on its own terms)
	var/datum/weakref/quarry_ref
	/// Cumulative time spent without a target (deciseconds)
	var/targetless_time = 0
	/// TRUE once the fine was paid or the contraband surrendered
	var/fine_paid = FALSE
	/// TRUE once the hunt has concluded (director inert, timer dead)
	var/hunt_over = FALSE
	/// Looping tick timer id
	var/timer_id

/datum/nt_patrol_director/New(obj/structure/overmap/ship/npc/pirate/nt_patrol/ship, obj/structure/overmap/ship/quarry)
	. = ..()
	patrol_ship = ship
	quarry_ref = WEAKREF(quarry)
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_ship_gone))
	RegisterSignal(ship, COMSIG_NEGOTIATION_ENDED, PROC_REF(on_negotiation_ended))

/datum/nt_patrol_director/Destroy()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	if(patrol_ship)
		UnregisterSignal(patrol_ship, list(COMSIG_QDELETING, COMSIG_NEGOTIATION_ENDED))
		patrol_ship = null
	quarry_ref = null
	return ..()

/**
 * Open the hunt: target the quarry, start the hail (mirrors what
 * scan_threats does when a red-zone pirate opens a hail - the hailing
 * behavior takes over announcements and the 20s grace period), and start the
 * re-evaluation timer.
 */
/datum/nt_patrol_director/proc/begin_hunt()
	var/obj/structure/overmap/ship/quarry = quarry_ref?.resolve()
	var/datum/ai_controller/npc_ship/controller = patrol_ship?.ai_controller
	if(!quarry || QDELETED(quarry) || !controller)
		finish_hunt()
		return FALSE

	// Mirror scan_threats' hail start (ship_combat_behaviors.dm)
	controller.set_target(quarry)
	controller.set_combat_state(NPC_COMBAT_HAILING)
	controller.clear_blackboard_key(BB_NPC_HAILING_START)
	controller.clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
	controller.clear_blackboard_key("hailing_reminder_sent")
	SEND_SIGNAL(quarry, COMSIG_SHIP_BEING_TARGETED, patrol_ship)

	quarry.ship_notify("[patrol_ship.name]: \"Attention [quarry.name]. This is Nanotrasen Customs Enforcement. Cut your engines and stand by for inspection. Non-compliance gets expensive.\"", "CUSTOMS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn2.ogg', 25)

	timer_id = addtimer(CALLBACK(src, PROC_REF(hunt_tick)), NT_PATROL_TICK_INTERVAL, TIMER_STOPPABLE | TIMER_LOOP)
	return TRUE

/// Periodic hunt re-evaluation
/datum/nt_patrol_director/proc/hunt_tick()
	if(hunt_over)
		return

	if(!patrol_ship || QDELETED(patrol_ship))
		finish_hunt()
		return

	if(patrol_ship.is_disabled)
		// Boss killed - set_disabled_state() already scheduled the warp-out
		finish_hunt()
		return

	var/obj/structure/overmap/ship/quarry = quarry_ref?.resolve()
	if(!quarry || QDELETED(quarry))
		// Nobody left to hunt
		break_off(silent = TRUE)
		return

	var/datum/ai_controller/npc_ship/controller = patrol_ship.ai_controller
	if(!controller)
		break_off(silent = TRUE)
		return

	if(controller.get_target())
		return  // Actively hailing/fighting/boarding - nothing to manage

	// Targetless: the quarry docked, landed, cloaked, or broke tracking
	targetless_time += NT_PATROL_TICK_INTERVAL
	if(targetless_time >= DRUG_COP_GIVEUP_TIME)
		break_off()
		return

	if(fine_paid)
		return  // Satisfied - departure timer is already running
	if(quarry.state != OVERMAP_SHIP_FLYING)
		return  // Still docked/landed - keep lurking
	if(controller.has_tribute_immunity(quarry))
		return  // Tribute immunity window - leave them be

	// Quarry is flying again and the fine is unpaid: re-engage directly, no
	// second hail - they had their chance
	controller.set_target(quarry)
	controller.set_combat_state(NPC_COMBAT_ENGAGING)
	SEND_SIGNAL(quarry, COMSIG_SHIP_BEING_TARGETED, patrol_ship)
	patrol_ship.ship_notify("Quarry [quarry.name] is under way again. Resuming enforcement action.", "CUSTOMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	quarry.ship_notify("[patrol_ship.name] has reacquired your vessel! The interdiction warrant is still active.", "CUSTOMS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 25)

/**
 * Negotiation concluded. Success = the fine was paid or the contraband
 * surrendered - customs is satisfied and departs. Failure feeds the standard
 * boarding-phase pipeline and needs nothing from us.
 */
/datum/nt_patrol_director/proc/on_negotiation_ended(datum/source, datum/pirate_negotiation/negotiation, success)
	SIGNAL_HANDLER
	if(!success || fine_paid)
		return
	fine_paid = TRUE
	// Let the acceptance line play, then leave
	addtimer(CALLBACK(src, PROC_REF(depart_satisfied)), NT_PATROL_SATISFIED_WARP_DELAY)

/// Fine settled - the patrol leaves the sector
/datum/nt_patrol_director/proc/depart_satisfied()
	if(patrol_ship && !QDELETED(patrol_ship) && !patrol_ship.is_disabled)
		var/obj/structure/overmap/ship/quarry = quarry_ref?.resolve()
		quarry?.ship_notify("[patrol_ship.name] has logged your payment and is departing the sector.", "CUSTOMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		patrol_ship.warp_out()
	finish_hunt()

/// Cumulative patience exhausted (or nothing left to hunt) - the patrol leaves
/datum/nt_patrol_director/proc/break_off(silent = FALSE)
	if(patrol_ship && !QDELETED(patrol_ship))
		if(!silent)
			var/obj/structure/overmap/ship/quarry = quarry_ref?.resolve()
			quarry?.ship_notify("[patrol_ship.name]: \"You are costing us more than your fine is worth. Breaking off pursuit. Your file stays open.\"", "CUSTOMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		patrol_ship.warp_out()
	finish_hunt()

/**
 * Mission calls this when it ends (product sold, mission failed, etc.):
 * withdraw the patrol if it is still around, then delete the director.
 * Safe to call at any point in the hunt.
 */
/datum/nt_patrol_director/proc/stand_down()
	if(patrol_ship && !QDELETED(patrol_ship) && !patrol_ship.warping_out)
		// Deferred, never inline: surrendering the contraband reaches here
		// SYNCHRONOUSLY from inside the negotiation's own qdel chain
		// (process_item_payment -> quest-loss -> mission fail -> stand_down);
		// warping out right now would delete the patrol mid-payment and eat
		// the acceptance line. warp_out() is idempotent and self-retries.
		addtimer(CALLBACK(patrol_ship, TYPE_PROC_REF(/obj/structure/overmap/ship/npc/pirate/nt_patrol, warp_out)), NT_PATROL_SATISFIED_WARP_DELAY)
	qdel(src)

/// Stop managing: kill the timer and go inert (the mission still holds us)
/datum/nt_patrol_director/proc/finish_hunt()
	hunt_over = TRUE
	if(timer_id)
		deltimer(timer_id)
		timer_id = null

/// The patrol ship is being deleted (warped out, destroyed, admin-nuked)
/datum/nt_patrol_director/proc/on_ship_gone(datum/source)
	SIGNAL_HANDLER
	patrol_ship = null
	finish_hunt()

#undef NT_PATROL_TICK_INTERVAL
#undef NT_PATROL_DISABLED_WARP_DELAY
#undef NT_PATROL_SATISFIED_WARP_DELAY
#undef NT_PATROL_SPAWN_DIST_MIN
#undef NT_PATROL_SPAWN_DIST_MAX
#undef NT_PATROL_SPAWN_DIST_FALLBACK
