/**
 * Outpost police soak: the fights. The harness is in voidcrew_outpost_police_soak.dm, the quieter scenarios in
 * voidcrew_outpost_police_soak_scenarios.dm.
 *
 * The owner's round 17.22.26 (Quartermain): arrested, stripped and jailed, they gave themselves the "Shuttle Nuclear
 * Operative" outfit in the cell, emagged the cell door, shot their way out with its Bulldog, took a stimulant, killed
 * officers up to four stars and was shot into soft crit, then crawled off. These scenarios play that and the fights
 * round it with tg's own outfit, gun, emag, medipen and crawl. Nothing here sets a state on an officer.
 *
 * Fixtures that bend something, each said where it is done:
 * - the outfit's explosive implant is taken out (it gibs its wearer on death and would take the outpost apart);
 * - the outfit and emag come from nowhere, as the owner's admin tools gave them;
 * - five_star_heavy pins the heat at five stars if the fight has not got there by itself.
 */

/datum/police_soak_scenario/combat
	limit = 10 MINUTES
	/// world.time of the suspect's next crawl
	var/next_crawl = 0
	/// world.time of the suspect's next try at breaking a hold
	var/next_try = 0
	/// Whether the stimulant has gone in
	var/stimmed = FALSE
	/// Shots the suspect fired at officers
	var/shots = 0
	/// Officers who went down in the run (dead, crit or out), for the notes
	var/list/fallen = list()

/// The owner's outfit, as the admin "select equipment" gives it: everything worn goes, the outfit goes on
/datum/police_soak_scenario/combat/proc/arm(datum/police_soak/run, deploy_suit = FALSE)
	var/mob/living/carbon/human/body = run.suspect
	for(var/obj/item/worn as anything in body.get_equipped_items(INCLUDE_POCKETS | INCLUDE_HELD))
		qdel(worn)
	body.equipOutfit(/datum/outfit/shuttle_nukie)
	// Fixture: the explosive implant gibs its wearer on death (and blows up the room); the police never see it
	for(var/obj/item/implant/explosive/bomb in body.implants)
		bomb.removed(body, TRUE)
		qdel(bomb)
	if(deploy_suit)
		var/obj/item/mod/control/suit = body.back
		if(istype(suit))
			suit.quick_activation()
	var/obj/item/gun/gun = locate(/obj/item/gun/ballistic/shotgun/bulldog) in body.held_items
	if(!gun)
		return run.script_failed("the outfit put no Bulldog in the suspect's hands")
	if(body.get_active_held_item() != gun)
		body.swap_hand()
	body.set_combat_mode(TRUE)
	run.note(">>", "puts on the Shuttle Nuclear Operative outfit[deploy_suit ? " and seals its suit" : ""] and draws the Bulldog")
	return TRUE

/// The Bulldog in the suspect's hands, or null
/datum/police_soak_scenario/combat/proc/gun(datum/police_soak/run)
	return locate(/obj/item/gun/ballistic/shotgun/bulldog) in run.suspect.held_items

/// A fresh drum from the bag into an empty Bulldog, by the gun's own reload. FALSE with none left.
/datum/police_soak_scenario/combat/proc/reload(datum/police_soak/run, obj/item/gun/ballistic/gun)
	var/obj/item/ammo_box/magazine/drum
	for(var/obj/item/ammo_box/magazine/m12g/spare in run.suspect.get_all_contents())
		if(spare.loc != gun && spare != gun.magazine && spare.ammo_count())
			drum = spare
			break
	if(!drum)
		return FALSE
	if(gun.magazine)
		gun.eject_magazine(run.suspect, FALSE)
	if(!gun.insert_magazine(run.suspect, drum, FALSE))
		return run.script_failed("the Bulldog would not take a fresh drum")
	if(!gun.chambered)
		gun.chamber_round()
	run.note(">>", "reloads the Bulldog")
	return TRUE

/// The stimulant medipen from the pocket, into themselves: in the round it went in once they were hurt
/datum/police_soak_scenario/combat/proc/stim(datum/police_soak/run)
	stimmed = TRUE
	var/mob/living/carbon/human/body = run.suspect
	var/obj/item/reagent_containers/hypospray/medipen/stimulants/pen = locate() in body.get_all_contents()
	if(!pen)
		run.note(">>", "has no stimulant to take")
		return FALSE
	var/obj/item/gun = gun(run)
	if(gun)
		body.swap_hand()
	var/obj/item/in_hand = body.get_active_held_item()
	if(in_hand)
		body.dropItemToGround(in_hand)
	body.temporarilyRemoveItemFromInventory(pen)
	body.put_in_active_hand(pen)
	run.click(body)
	run.note(">>", "injects the stimulant medipen at [round(body.health)] health")
	body.dropItemToGround(pen)
	if(gun && body.get_active_held_item() != gun)
		body.swap_hand()
	return TRUE

/// The officer to shoot: standing, awake and in the suspect's sight, the nearest first; null if none
/datum/police_soak_scenario/combat/proc/mark(datum/police_soak/run, range = 8)
	var/best_distance = INFINITY
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in run.officers_up())
		if(officer.z != run.suspect.z || officer.body_position == LYING_DOWN || HAS_TRAIT(officer, TRAIT_CRITICAL_CONDITION))
			continue
		var/distance = get_dist(officer, run.suspect)
		if(distance > range || distance >= best_distance || !can_see(run.suspect, officer, range))
			continue
		best_distance = distance
		. = officer

/// Notes every officer that went down since the last look
/datum/police_soak_scenario/combat/proc/count_fallen(datum/police_soak/run)
	for(var/mob/living/body as anything in run.tracks)
		if(!is_outpost_police_npc(body) || (body in fallen))
			continue
		if(body.stat != CONSCIOUS || HAS_TRAIT(body, TRAIT_CRITICAL_CONDITION))
			fallen += body
			run.note(">>", "[run.who(body)] is down ([body.stat == DEAD ? "dead" : "crit"]) at [run.where(body)]; stars [run.police.get_stars(run.suspect.mind)]")

/**
 * The suspect fights: shoots the nearest officer in sight, reloads, takes the stimulant once hurt, and with nobody in
 * sight walks towards the nearest officer. Until `limit` runs out, they cannot fight on, or `done` (a proc on this
 * scenario, called with the run) says to stop. TRUE if `done` stopped it.
 */
/datum/police_soak_scenario/combat/proc/fight(datum/police_soak/run, limit, done)
	var/until = world.time + limit
	while(!run.finished && world.time < until && run.suspect_able() && !run.suspect.handcuffed && !HAS_TRAIT(run.suspect, TRAIT_RESTRAINED))
		count_fallen(run)
		if(done && call(src, done)(run))
			return TRUE
		if(!stimmed && run.suspect.health < 75)
			stim(run)
		var/obj/item/gun/ballistic/gun = gun(run)
		if(!gun)
			run.script_failed("lost the Bulldog in the fight")
			return FALSE
		if(!gun.get_ammo() && !reload(run, gun))
			run.note(">>", "is out of shells")
			return FALSE
		var/mob/living/target = mark(run)
		if(target)
			if(run.click(target))
				shots++
			sleep(1 SECONDS)
			continue
		var/mob/living/nearest = run.nearest_officer()
		if(nearest && get_dist(nearest, run.suspect) > 3)
			run.go_to(nearest, 3, 3 SECONDS)
		else
			sleep(1 SECONDS)
	count_fallen(run)
	return FALSE

/// One crawl of the suspect's in soft crit away from the nearest officer, as their player's key press would make it
/datum/police_soak_scenario/combat/proc/crawl(datum/police_soak/run)
	var/mob/living/carbon/human/crawler = run.suspect
	if(world.time < next_crawl || QDELETED(crawler) || crawler.stat != SOFT_CRIT || crawler.buckled || !isturf(crawler.loc) || !(crawler.mobility_flags & MOBILITY_MOVE))
		return FALSE
	if(crawler.pulledby)
		if(world.time < next_try)
			return FALSE
		if(crawler.resist_grab(TRUE))
			next_try = world.time + 4 SECONDS
			run.note(">>", "tries to crawl off and fails to break the hold")
			return FALSE
	var/mob/living/officer = run.nearest_officer()
	var/turf/best
	var/best_distance = -1
	for(var/direction in shuffle(GLOB.cardinals.Copy()))
		var/turf/open/next = get_step(crawler, direction)
		if(!istype(next) || next.is_blocked_turf(TRUE))
			continue
		var/distance = officer ? get_dist(next, officer) : 0
		if(distance > best_distance)
			best = next
			best_distance = distance
	if(!best)
		return FALSE
	next_crawl = world.time + max(3 SECONDS, crawler.cached_multiplicative_slowdown)
	SEND_SIGNAL(crawler, COMSIG_MOB_CLIENT_PRE_MOVE, list(best, get_dir(crawler, best)))
	crawler.Move(best, get_dir(crawler, best))
	if(crawler.loc != best)
		return FALSE
	run.own_step_at = world.time
	run.note(">>", "crawls a tile, to [run.where(crawler)]")
	return TRUE

/**
 * Down after the fight: the shape of the round. In soft crit they crawl away from the nearest officer every few
 * seconds until an officer takes hold of them or cuffs them. Fails the script if nobody takes them in 60 s, if it
 * takes over 30 s, or if an officer says a search line with them lying in its sight. A zone that finishes the
 * downed (the Undertow) is only noted.
 */
/datum/police_soak_scenario/combat/proc/down_and_crawl(datum/police_soak/run)
	if(run.finished || QDELETED(run.suspect))
		return
	var/mob/living/carbon/human/body = run.suspect
	var/stars = run.police.get_stars(body.mind)
	if(body.stat == CONSCIOUS)
		run.note(">>", "is still up at [stars] stars when the fight ends ([body.handcuffed ? "in cuffs" : "not cuffed"])")
		return
	if(body.stat != SOFT_CRIT)
		run.note(">>", "went past soft crit at once ([body.stat == DEAD ? "dead" : "stat [body.stat]"]) at [stars] stars; no crawl")
		return
	var/finished_off = run.police.finishes_downed(body, null)
	var/downed_at = world.time
	var/list/shooters = list()
	for(var/list/event as anything in run.force_events)
		shooters |= event[2]
	run.note(">>", "is in soft crit at [run.where(body)] at [stars] stars, [length(fallen)] officers down; crawls away from the nearest officer every few seconds")
	var/list/said_seen = list()
	var/taken_at = 0
	var/until = world.time + 60 SECONDS
	while(world.time < until && !run.finished && !QDELETED(body) && body.stat != DEAD)
		count_fallen(run)
		if(!taken_at && (body.handcuffed || run.police.arrest_cuffing(body) || is_outpost_police_npc(body.pulledby)))
			taken_at = world.time
			run.note(">>", "is taken hold of or cuffed [round((taken_at - downed_at) / (1 SECONDS))]s after going down")
		if(body.handcuffed)
			break
		// Nobody looks for someone lying in front of them
		if(!finished_off)
			for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in run.officers_up())
				var/datum/police_soak_track/found = run.tracks[officer]
				if(!found || found.said_at <= downed_at || said_seen[officer] == found.said_at)
					continue
				said_seen[officer] = found.said_at
				if((found.said_kind == "stealth_search" || found.said_kind == "lost" || found.said_kind == "stealth_give_up") && run.police.perception.sees(officer, body))
					run.script_failed("[run.who(officer)][(officer in shooters) ? ", who shot them down," : ""] said \"[found.said_text]\" ([found.said_kind]) with the suspect down in its sight at [run.where(body)]")
		if(!taken_at)
			crawl(run)
		sleep(5)
	if(finished_off)
		run.note(">>", "the Undertow: [body.stat == DEAD ? "finished where they lay" : "still alive"]")
	else if(!taken_at)
		run.script_failed("nobody took hold of or cuffed a suspect in soft crit within 60s of going down (at [run.where(body)], [run.police.arrest_on(body) ? "an arrest open" : "no arrest open"])")
	else if(taken_at - downed_at > 30 SECONDS)
		run.script_failed("the cuffs took [round((taken_at - downed_at) / (1 SECONDS))]s to come out for a suspect shot down at [stars] stars")

// =========================================================================
// THE ROUND: JAILED, ARMED IN THE CELL, OUT, SHOOTING, DOWN, CRAWLING
// =========================================================================

/datum/unit_test/voidcrew_police_soak/jailbreak_shootout
	scenario_type = /datum/police_soak_scenario/combat/jailbreak_shootout

/datum/police_soak_scenario/combat/jailbreak_shootout
	name = "jailbreak_shootout"

/datum/police_soak_scenario/combat/jailbreak_shootout/play(datum/police_soak/run)
	if(!run.punch_townsperson(2))
		return
	run.give_up()
	if(!run.wait_for("uncuffed in a cell", 240 SECONDS))
		run.script_failed("was not in a cell with the cuffs off within 240s of giving up")
		return
	var/datum/outpost_police_cell/cell = run.police.cell_holding(run.suspect.mind)
	// In the round the jailer stood outside the cell for half a minute first ("Quiet in there?")
	run.stand(10 SECONDS)
	if(!arm(run))
		return
	// The emag in the other hand, as the admin tools gave it
	var/mob/living/carbon/human/body = run.suspect
	body.swap_hand()
	var/obj/item/card/emag/card = new(get_turf(body))
	body.put_in_active_hand(card)
	if(!body.Adjacent(cell.door))
		var/turf/beside
		for(var/turf/tile as anything in cell.tiles)
			if(get_dist(tile, cell.door) == 1 && (get_dir(tile, cell.door) in GLOB.cardinals) && !tile.is_blocked_turf(TRUE))
				beside = tile
				break
		if(!beside || !run.go_to(beside, 0, 10 SECONDS))
			run.script_failed("could not get beside the cell door at [run.where(cell.door)] from [run.where(body)]")
			return
	run.click(cell.door)
	// An emagged airlock sparks and opens 0.6 s later (airlock finish_emag_act()); the round: 17:27:46.2 to 47.4
	var/open_by = world.time + 5 SECONDS
	while(cell.door.density && world.time < open_by && !run.finished)
		sleep(2)
	run.note(">>", "emags the cell door at [run.where(cell.door)] from [run.where(body)] ([cell.door.density ? "still shut" : "open"], emagged [(cell.door.obj_flags & EMAGGED) ? "yes" : "no"])")
	body.dropItemToGround(card)
	body.swap_hand()
	if(cell.door.density)
		run.script_failed("the emag did not open the cell door")
		return
	fight(run, 150 SECONDS)
	run.note(">>", "the fight ends at [run.police.get_stars(body.mind)] stars, [length(fallen)] officers down, [shots] shots fired, suspect [body.stat == CONSCIOUS ? "up" : (body.stat == DEAD ? "dead" : "down")]")
	down_and_crawl(run)
	run.stand(30 SECONDS)

// =========================================================================
// KILL OFFICERS, THEN HIDE AND STAY PUT
// The search goes on round the last sighting, not round the bodies, and three stars and up never fade on the outpost.
// =========================================================================

/datum/unit_test/voidcrew_police_soak/kill_then_hide
	scenario_type = /datum/police_soak_scenario/combat/kill_then_hide

/datum/police_soak_scenario/combat/kill_then_hide
	name = "kill_then_hide"

/// Two officers down and the suspect at three stars or more: time to run
/datum/police_soak_scenario/combat/kill_then_hide/proc/enough(datum/police_soak/run)
	return length(fallen) >= 2 && run.police.get_stars(run.suspect.mind) >= 3

/datum/police_soak_scenario/combat/kill_then_hide/play(datum/police_soak/run)
	if(!arm(run))
		return
	if(!fight(run, 90 SECONDS, PROC_REF(enough)))
		run.note(">>", "never got two officers down at three stars while still up ([length(fallen)] down, [run.police.get_stars(run.suspect.mind)] stars, suspect [run.suspect_able() ? "up" : "down"])")
		down_and_crawl(run)
		run.stand(30 SECONDS)
		return
	var/stars = run.police.get_stars(run.suspect.mind)
	run.note(">>", "has [length(fallen)] officers down at [stars] stars; runs for it")
	var/turf/corner = run.far_corner()
	if(!corner)
		run.script_failed("no far corner of the concourse out of the officers' sight to run to")
		return
	if(!run.go_to(corner, 0, 60 SECONDS))
		run.note(">>", "could not run to the far corner at [run.where(corner)] (got to [run.where(run.suspect)])")
	if(!run.suspect_able())
		down_and_crawl(run)
		run.stand(30 SECONDS)
		return
	run.note(">>", "stays put at [run.where(run.suspect)], [get_dist(run.suspect, run.police.get_warrant(run.suspect.mind)?.last_seen_turf)] tiles from where the police last saw them")
	// Stays put, gun down. Shot at, they still stay put: the run is about the search, not the fight.
	var/until = world.time + 120 SECONDS
	var/lowest = stars
	while(world.time < until && !run.finished && !QDELETED(run.suspect))
		count_fallen(run)
		lowest = min(lowest, run.police.get_stars(run.suspect.mind))
		if(!run.suspect_able() || run.suspect.handcuffed)
			break
		sleep(1 SECONDS)
	if(lowest < 3 && !run.suspect.handcuffed && run.suspect.stat != DEAD)
		run.script_failed("hidden at [stars] stars, their stars fell to [lowest]")
	if(run.suspect.stat == SOFT_CRIT)
		down_and_crawl(run)
	run.stand(20 SECONDS)

// =========================================================================
// SHOT DOWN AT FOUR STARS, THEN CRAWLING
// Armed on the concourse, they fight until the tactical units are out and they are shot into soft crit, and crawl.
// =========================================================================

/datum/unit_test/voidcrew_police_soak/four_star_crawl
	scenario_type = /datum/police_soak_scenario/combat/four_star_crawl

/datum/police_soak_scenario/combat/four_star_crawl
	name = "four_star_crawl"
	/// world.time the suspect first reached four stars
	var/four_at = 0

/datum/police_soak_scenario/combat/four_star_crawl/proc/note_four(datum/police_soak/run)
	if(!four_at && run.police.get_stars(run.suspect.mind) >= 4)
		four_at = world.time
		run.note(">>", "is at four stars with [length(fallen)] officers down")
	return FALSE

/datum/police_soak_scenario/combat/four_star_crawl/play(datum/police_soak/run)
	if(!arm(run))
		return
	fight(run, 180 SECONDS, PROC_REF(note_four))
	var/stars = run.police.get_stars(run.suspect.mind)
	run.note(">>", "the fight ends at [stars] stars, [length(fallen)] officers down, [shots] shots fired, suspect [run.suspect.stat == CONSCIOUS ? "up" : (run.suspect.stat == DEAD ? "dead" : "down")]")
	if(stars < 4)
		run.note(">>", "never reached four stars: the run did not test the shape it is for")
	down_and_crawl(run)
	run.stand(30 SECONDS)

// =========================================================================
// FIVE STARS: THE MARSHAL AND THE HEAVY TEAM ON THE FLOOR
// In the sealed suit, on foot (a script does not drive a mech). They fight, then stand off out of sight, then fight
// on. Whether the marshal and the heavy officers come, stall, or hit anyone but the suspect.
// =========================================================================

/datum/unit_test/voidcrew_police_soak/five_star_heavy
	scenario_type = /datum/police_soak_scenario/combat/five_star_heavy

/datum/police_soak_scenario/combat/five_star_heavy
	name = "five_star_heavy"
	/// Whether the heat was pinned to five stars (the fight did not get there by itself)
	var/pinned = FALSE

/// Fixture: five stars (OUTPOST_POLICE_STAR_HEAT 140), once the fight has made it at least three, as more killing would
/datum/police_soak_scenario/combat/five_star_heavy/proc/five(datum/police_soak/run)
	var/old_stars = run.police.get_stars(run.suspect.mind)
	if(old_stars >= 5 || old_stars < 3)
		return FALSE
	var/datum/outpost_warrant/warrant = run.test.police_pin_warrant(run.police, run.suspect.mind, 145)
	run.police.stars_changed(warrant, old_stars, run.police.get_stars(run.suspect.mind))
	if(!pinned)
		pinned = TRUE
		run.note(">>", "FIXTURE: heat pinned at five stars (was [old_stars])")
	return FALSE

/datum/police_soak_scenario/combat/five_star_heavy/play(datum/police_soak/run)
	if(!arm(run, TRUE))
		return
	fight(run, 60 SECONDS, PROC_REF(five))
	five(run)
	var/list/kinds = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in run.police.officers)
		kinds[officer.unit_kind]++
	var/list/kind_text = list()
	for(var/kind in kinds)
		kind_text += "[kind] [kinds[kind]]"
	run.note(">>", "after the first fight: [run.police.get_stars(run.suspect.mind)] stars, [length(fallen)] officers down, squad [kind_text.Join(", ")]")
	if(run.suspect_able())
		var/turf/corner = run.far_corner()
		if(corner)
			run.go_to(corner, 0, 30 SECONDS)
			run.note(">>", "stands off at [run.where(run.suspect)]")
			var/until = world.time + 45 SECONDS
			while(world.time < until && run.suspect_able() && !run.finished)
				count_fallen(run)
				sleep(1 SECONDS)
	if(run.suspect_able())
		fight(run, 90 SECONDS, PROC_REF(five))
	kinds = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in run.police.officers)
		kinds[officer.unit_kind]++
	kind_text = list()
	for(var/kind in kinds)
		kind_text += "[kind] [kinds[kind]]"
	run.note(">>", "the fight ends at [run.police.get_stars(run.suspect.mind)] stars, [length(fallen)] officers down, [shots] shots fired, squad [kind_text.Join(", ")], suspect [run.suspect.stat == CONSCIOUS ? "up" : (run.suspect.stat == DEAD ? "dead" : "down")]")
	if(!kinds["marshal"])
		run.note(">>", "no marshal on the roster at the end")
	if(!kinds["armour"])
		run.note(">>", "no heavy weapons officer on the roster at the end")
	down_and_crawl(run)
	run.stand(30 SECONDS)
