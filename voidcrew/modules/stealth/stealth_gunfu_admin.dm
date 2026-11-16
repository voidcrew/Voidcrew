/**
 * # Gun-fu admin tool (stealth step 3c, decision 15)
 *
 * "Gun-fu Moves" (Debug): fires any gun-fu move on demand between two people in view, the shoulder flip above all
 * (the owner expects it to need a lot of testing). It sets up what the move needs through tg's own procs: the chip
 * (installed as an admin install), a pistol in the mover's hand, and the grab (tg's grippedby(), instantly), then
 * runs the move itself, cooldown aside. Every use is logged.
 */

ADMIN_VERB(gunfu_moves, R_DEBUG, "Gun-fu Moves", "Make someone in view do a gun-fu move on someone else, on demand.", ADMIN_CATEGORY_DEBUG)
	var/mob/watcher = user.mob
	var/list/people = list()
	for(var/mob/living/carbon/human/person in view(world.view, get_turf(watcher)))
		people["[person] ([person.ckey || "npc"]) [dir2text(get_dir(watcher, person)) || "here"]"] = person
	if(length(people) < 2)
		to_chat(user, span_warning("You need two people in view."), confidential = TRUE)
		return
	var/move = tgui_input_list(user, "Which move?", "Gun-fu Moves", list(GUNFU_MOVE_FLIP, GUNFU_MOVE_HIP_THROW, GUNFU_MOVE_WALL_SLAM, GUNFU_MOVE_DISARM, GUNFU_MOVE_SHIELD))
	if(isnull(move))
		return
	var/mover_key = tgui_input_list(user, "Who does it?", "Gun-fu Moves", sort_list(people))
	if(isnull(mover_key))
		return
	var/mob/living/carbon/human/mover = people[mover_key]
	people -= mover_key
	var/victim_key = tgui_input_list(user, "On whom?", "Gun-fu Moves", sort_list(people))
	if(isnull(victim_key))
		return
	var/mob/living/carbon/human/victim = people[victim_key]
	var/direction
	if(move == GUNFU_MOVE_FLIP || move == GUNFU_MOVE_HIP_THROW)
		direction = tgui_input_list(user, "Which way?", "Gun-fu Moves", list("ahead", "north", "south", "east", "west"))
		if(isnull(direction))
			return
	if(QDELETED(mover) || QDELETED(victim))
		return
	var/result = gunfu_admin_do(mover, victim, move, direction == "ahead" ? null : text2dir(direction))
	to_chat(user, span_notice("Gun-fu [move]: [result]"), confidential = TRUE)
	message_admins("[key_name_admin(user)] made [ADMIN_LOOKUPFLW(mover)] do a gun-fu [move] on [ADMIN_LOOKUPFLW(victim)]: [result]")
	log_admin("[key_name(user)] made [key_name(mover)] do a gun-fu [move] on [key_name(victim)]: [result]")
	BLACKBOX_LOG_ADMIN_VERB("Gun-fu Moves")

/// Sets up and runs one gun-fu move. `direction` is where a throw or flip goes (null: the way the mover faces). Returns
/// what happened, for the admin. Also used by tests and recordings.
/proc/gunfu_admin_do(mob/living/carbon/human/mover, mob/living/carbon/human/victim, move, direction)
	var/setup = gunfu_admin_setup(mover, victim, move)
	if(setup)
		return setup
	switch(move)
		if(GUNFU_MOVE_HIP_THROW, GUNFU_MOVE_FLIP)
			var/turf/toward = get_ranged_target_turf(mover, direction || mover.dir, GUNFU_HIP_THROW_RANGE)
			if(move == GUNFU_MOVE_FLIP)
				return mover.gunfu_flip(victim, toward) ? "done" : "refused"
			return mover.gunfu_hip_throw(victim, toward) ? "done" : "refused"
		if(GUNFU_MOVE_WALL_SLAM, GUNFU_MOVE_DISARM)
			var/obj/item/gun/gun = mover.get_active_held_item()
			var/shove_dir = get_dir(mover, victim)
			var/solid = mover.gunfu_solid_behind(victim, get_step(victim, shove_dir), shove_dir)
			if(move == GUNFU_MOVE_WALL_SLAM && !solid)
				return "nothing solid behind them"
			if(move == GUNFU_MOVE_DISARM && solid)
				return "something solid behind them makes it a wall slam"
			return mover.gunfu_shove(victim, gun) ? "done" : "refused (are they holding anything?)"
		if(GUNFU_MOVE_SHIELD)
			return mover.gunfu_shield_body() == victim ? "holding them up" : "refused"
	return "unknown move"

/// Gives `mover` what `move` needs: the chip, a gun in hand, and the grab. Returns a reason it can't, or null.
/proc/gunfu_admin_setup(mob/living/carbon/human/mover, mob/living/carbon/human/victim, move)
	if(mover.stat != CONSCIOUS || mover.body_position != STANDING_UP)
		return "the mover can't stand and fight"
	if(isnull(mover.gunfu_chip()))
		var/obj/item/organ/cyberimp/cyberware/gun_kata/chip = new
		if(!chip.Insert(mover, special = TRUE))
			qdel(chip)
			return "the chip wouldn't go in"
	if(!isgun(mover.get_active_held_item()))
		var/obj/item/gun/ballistic/automatic/pistol/pistol = new(get_turf(mover))
		if(!mover.put_in_active_hand(pistol))
			qdel(pistol)
			return "the mover's active hand is full"
	if(get_dist(mover, victim) > 1)
		return "they need to be next to each other"
	var/wanted = GRAB_PASSIVE
	switch(move)
		if(GUNFU_MOVE_HIP_THROW)
			wanted = GRAB_AGGRESSIVE
		if(GUNFU_MOVE_FLIP, GUNFU_MOVE_SHIELD)
			wanted = GRAB_NECK
		if(GUNFU_MOVE_WALL_SLAM, GUNFU_MOVE_DISARM)
			if(mover.pulling == victim)
				mover.stop_pulling()
			if(victim.loc == mover.loc)
				return "they're on the same tile"
			return null
	if(mover.pulling != victim)
		mover.start_pulling(victim, supress_message = TRUE)
	var/tries = 0
	while(mover.pulling == victim && mover.grab_state < wanted && tries++ < 3)
		victim.grippedby(mover, instant = TRUE)
	if(mover.pulling != victim || mover.grab_state < wanted)
		return "couldn't get the grab"
	mover.gunfu_next_move = 0
	if(move == GUNFU_MOVE_SHIELD)
		mover.set_pull_offsets(victim, mover.grab_state)
	return null
