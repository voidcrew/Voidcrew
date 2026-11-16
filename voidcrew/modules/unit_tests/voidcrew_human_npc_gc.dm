/**
 * # Human NPCs garbage collect
 *
 * Every family of human NPC must be released when it is deleted, after a fight and killed by gunfire
 * or a blade, and so must a body whose cut limb was severed and left lying apart from it (a slash
 * wound's scar held the body it came off). A leftover reference means a hard delete on a live
 * server: a planet or ruin unloading dozens of them froze the world for seconds at a time.
 * On a failure the reference finder runs and logs the holder to the runtime log.
 */
/datum/unit_test/voidcrew_human_npc_gc
	/// One of each family that has hard-deleted on a live server
	var/static/list/families = list(
		/mob/living/carbon/human/npc/ruin/trooper/syndicate,
		/mob/living/carbon/human/npc/ruin/trooper/russian/gunner,
		/mob/living/carbon/human/npc/ruin/trooper/pirate,
		/mob/living/carbon/human/npc/ruin/trooper/pirate/beach/gunner,
		/mob/living/carbon/human/npc/ruin/hermit,
		/mob/living/carbon/human/npc/ruin/hermit/hunter,
		/mob/living/carbon/human/npc/faction_pirate/grey/melee,
		/mob/living/carbon/human/npc/faction_pirate/skeleton/captain,
		/mob/living/carbon/human/npc/bounty_criminal/decoy,
		/mob/living/carbon/human/npc/ambient_npc/outpost/drinker,
		/mob/living/carbon/human/npc/ambient_npc/outpost/angler,
		/mob/living/carbon/human/npc/ambient_npc/outpost/customer,
	)

/datum/unit_test/voidcrew_human_npc_gc/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z)
	var/turf/near = locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/stranger = allocate(/mob/living/carbon/human/consistent, near)
	// The controls: a plain body must pass the same check, and one held in a list must fail it,
	// or the count below is off
	var/mob/living/carbon/human/consistent/control = new(spot)
	TEST_ASSERT(npc_gc_check(control, "control", report = FALSE), "A plain human was counted as held: the expected reference count is wrong")
	control = new(spot)
	var/list/holder = list(control)
	TEST_ASSERT(!npc_gc_check(control, "held control", report = FALSE), "A human held in a list was counted as released: the check can't see a leak")
	holder.Cut()
	control = null
	// A cut limb severed and left lying apart from the body, with a cut that worsened first and one that didn't
	var/turf/apart = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	for(var/worsened in list(FALSE, TRUE))
		var/mob/living/carbon/human/npc/body = new /mob/living/carbon/human/npc/ruin/hermit/hunter(spot)
		var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
		arm.force_wound_upwards(/datum/wound/slash/flesh/moderate)
		if(worsened)
			arm.force_wound_upwards(/datum/wound/slash/flesh/severe)
		TEST_ASSERT(arm.dismember(), "The arm wasn't severed")
		arm.forceMove(apart)
		npc_gc_check(body, "a body whose [worsened ? "worsened " : ""]cut arm lies apart from it")
		body = null
		qdel(arm)
	// Someone on the level, so their Life() and AI run as they would near a player
	SSmobs.clients_by_zlevel[spot.z] += stranger
	for(var/npc_type in families)
		for(var/how in list("shot", "cut"))
			var/datum/npc_spawn_context/context = new(null, null, "auto", FALSE, spot)
			var/datum/human_npc_order/order = spawn_human_npc(npc_type, spot, context = context, immediate = TRUE)
			var/mob/living/carbon/human/npc/npc = order.spawned_ref?.resolve()
			order = null
			if(!istype(npc, /mob/living/carbon/human/npc))
				TEST_FAIL("[npc_type] did not spawn")
				continue
			stranger.revive(ADMIN_HEAL_ALL)
			stranger.forceMove(near)
			// A fight with the stranger in view, then the stranger kills it
			run_ai(npc, 50)
			stranger.revive(ADMIN_HEAL_ALL)
			if(how == "shot")
				shoot_dead(stranger, npc)
			else
				cut_dead(stranger, npc)
			sleep(5)
			npc_gc_check(npc, "[npc_type] ([how], dead [npc.stat == DEAD])", via_empty = (how == "cut"))
			npc = null
			qdel(context)
			for(var/obj/item/held in stranger.held_items)
				qdel(held)
	SSmobs.clients_by_zlevel[spot.z] -= stranger

/// Runs its AI for `ticks` with a stranger in view, as it would with a player near
/datum/unit_test/voidcrew_human_npc_gc/proc/run_ai(mob/living/carbon/human/npc/npc, ticks = 30)
	var/datum/ai_controller/controller = npc.ai_controller
	if(!istype(controller))
		return
	controller.set_ai_status(AI_STATUS_ON)
	for(var/i in 1 to ticks)
		if(QDELETED(npc))
			return
		sleep(1)

/// The stranger shoots it with a real pistol until it dies
/datum/unit_test/voidcrew_human_npc_gc/proc/shoot_dead(mob/living/carbon/human/stranger, mob/living/carbon/human/npc/npc)
	var/obj/item/gun/ballistic/automatic/pistol/m1911/gun
	for(var/i in 1 to 40)
		if(QDELETED(npc) || npc.stat == DEAD)
			return
		if(QDELETED(gun) || !gun.can_shoot())
			if(gun)
				qdel(gun)
			gun = new(get_turf(stranger))
			stranger.put_in_hands(gun)
		gun.fire_gun(npc, stranger, FALSE)
		sleep(3)
	if(!QDELETED(npc) && npc.stat != DEAD)
		npc.death()

/// The stranger hacks at it with a sword from beside it until it dies
/datum/unit_test/voidcrew_human_npc_gc/proc/cut_dead(mob/living/carbon/human/stranger, mob/living/carbon/human/npc/npc)
	var/obj/item/claymore/sword = new(get_turf(stranger))
	stranger.put_in_hands(sword)
	stranger.forceMove(get_step(get_turf(npc), EAST))
	for(var/i in 1 to 40)
		if(QDELETED(npc) || npc.stat == DEAD)
			break
		stranger.zone_selected = pick(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
		sword.melee_attack_chain(stranger, npc)
		sleep(1)
	if(!QDELETED(npc) && npc.stat != DEAD)
		npc.death()
	stranger.forceMove(locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z))

/// qdels it and fails, naming the holder in the runtime log, if anything else still holds it
/// TRUE when released. `report` FALSE only measures.
/datum/unit_test/voidcrew_human_npc_gc/proc/npc_gc_check(mob/living/carbon/human/npc, label, report = TRUE, via_empty = FALSE)
	if(via_empty)
		// What a planet or ruin unload does to every tile: everything on it, gear and loot included
		var/turf/where = get_turf(npc)
		where.empty(where.type)
		where = null
	else
		qdel(npc)
	// Locked gear lets go over the next tick or two; emote cooldown timers within a few seconds.
	// The garbage collector gives a deleted thing five minutes, so only what lasts longer is a leak.
	var/held = 0
	for(var/i in 1 to 30)
		sleep(i <= 5 ? 1 : 5)
		if(!npc)
			TEST_FAIL("[label] was hard deleted before it could be checked")
			return FALSE
		// refcount() counts the caller's local var, this proc's argument slot and the SSgarbage queue entry qdel made
		held = refcount(npc) - 3
		if(held <= 0)
			return TRUE
	if(!report)
		return FALSE
	log_world("## voidcrew_human_npc_gc: [label] [text_ref(npc)] held by [held] reference(s), searching")
	npc.find_references()
	TEST_FAIL("[label] was still held by [held] reference(s) after qdel: it would hard delete. The holders are in the runtime log (## REF SEARCH).")
	return FALSE
