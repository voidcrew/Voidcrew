/**
 * # Gorilla finishers (owner D39)
 *
 * A piston punch from a synced real pair, with both hands empty, on someone in crit or stunned, finishes
 * them instead. The aimed zone picks which:
 * - Head: the head clap. Hauled off the floor by the collar, a beat of kicking, then both fists meet on
 *   the head and it bursts (#509's burst; the brain is thrown out whole, so revival works). A helmet or
 *   plating crumples instead and the skull caves in. Needs gravity, or the brain would drift off.
 * - Arm (the aimed one, else the other): the limb rip. A boot on the body, both fists on the arm, it tears
 *   off at the shoulder with the spray running back over the bearer, and one blow to the head with it.
 *   Armour on the arm wrenches the shoulder out instead.
 * - Chest: the backbreaker. Pressed overhead, brought down across a knee, the back breaks and the body
 *   is rolled off still bent. Armour on the chest cracks the ribs instead.
 * The Atlas frame beats all three: nothing bursts, tears or breaks.
 *
 * The wind-up is the two bodies (owner D34: no mark): the puppet rig (chrome_puppet_rig.dm) poses the
 * bearer's arms and the victim. It can be stopped like any #509 finisher: enough damage on the bearer,
 * the bearer moving, stunned or cuffed, the victim pulled away or out of their stun, the arms falling
 * out of sync. The haymaker and the finishers share the pistons' cooldown: longer after a kill than
 * after being stopped. Starting one counts as aggression at a trader outpost.
 */

/**
 * Starts the Gorilla finisher [zone] picks (the bearer's aim when null), if one can start on [victim].
 * Returns TRUE if it did. The punch calls it with the aim; an AI can call it with a zone.
 */
/proc/gorilla_try_finisher(mob/living/carbon/human/source, mob/living/victim, zone)
	if(!iscarbon(victim) || !ishuman(source) || !gorilla_synced(source) || !gorilla_may_use_heavy_moves(source))
		return FALSE
	if(!TIMER_COOLDOWN_FINISHED(source, COOLDOWN_GORILLA_PISTONS) || source.chrome_finisher)
		return FALSE
	if(!chrome_finisher_valid_victim(source, victim))
		return FALSE
	zone = check_zone(zone || source.zone_selected)
	var/finisher_type
	switch(zone)
		if(BODY_ZONE_HEAD)
			finisher_type = /datum/hv_finisher/chrome/gorilla/clap
		if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
			finisher_type = /datum/hv_finisher/chrome/gorilla/rip
		if(BODY_ZONE_CHEST)
			finisher_type = /datum/hv_finisher/chrome/gorilla/backbreaker
	if(!finisher_type)
		return FALSE
	var/datum/hv_finisher/chrome/gorilla/finisher = new finisher_type(source, victim)
	finisher.aimed_zone = zone
	if(!finisher.start())
		qdel(finisher)
		return FALSE
	gorilla_register_aggression(victim, source)
	return TRUE

/datum/hv_finisher/chrome/gorilla
	name = "gorilla finisher"
	/// The zone the bearer aimed when it started
	var/aimed_zone
	/// The bearer's facing toward the victim, fixed at the start
	var/facing
	/// The bearer's puppets
	var/datum/chrome_rig/bearer_rig
	/// The victim's puppets
	var/datum/chrome_rig/victim_rig

/datum/hv_finisher/chrome/gorilla/can_start()
	if(!..())
		return FALSE
	if(!ishuman(user) || !gorilla_synced(user) || !TIMER_COOLDOWN_FINISHED(user, COOLDOWN_GORILLA_PISTONS))
		return FALSE
	var/mob/living/carbon/human/bearer = user
	for(var/obj/item/held in bearer.held_items)
		return FALSE
	var/list/arms = gorilla_heavy_arms(bearer)
	if(length(arms) < 2)
		return FALSE
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in arms)
		if(!arm.gorilla_running())
			return FALSE
	return can_start_on(victim)

/// What this finisher needs of the victim besides being down.
/datum/hv_finisher/chrome/gorilla/proc/can_start_on(mob/living/carbon/target)
	return TRUE

/datum/hv_finisher/chrome/gorilla/safety_check()
	. = ..()
	if(!. && !completed && !gorilla_synced(user))
		return HV_FINISHER_ATTACKER_DOWN

/datum/hv_finisher/chrome/gorilla/stop(reason)
	if(!running)
		return
	var/finished = completed
	// The parent deletes the finisher, which clears these
	var/mob/living/bearer = user
	var/mob/living/body = victim
	. = ..()
	cleanup_rigs()
	if(!QDELETED(bearer))
		gorilla_spend_pistons(bearer, finished ? GORILLA_PISTONS_COOLDOWN : GORILLA_PISTONS_INTERRUPTED)
		if(finished && !QDELETED(body))
			hv_execution_witnesses(bearer, body)

/datum/hv_finisher/chrome/gorilla/Destroy()
	cleanup_rigs()
	return ..()

/// Takes every puppet down and shows both bodies.
/datum/hv_finisher/chrome/gorilla/proc/cleanup_rigs()
	QDEL_NULL(bearer_rig)
	QDEL_NULL(victim_rig)

/// The bearer's rig, made on first use: the body without arms and both arms on their own puppets.
/datum/hv_finisher/chrome/gorilla/proc/rig_bearer()
	if(bearer_rig || QDELETED(user))
		return bearer_rig
	user.face_atom(victim)
	facing = user.dir
	bearer_rig = new(user, facing)
	if(!bearer_rig.rig_arms())
		QDEL_NULL(bearer_rig)
	return bearer_rig

/// Whether the bearer is seen from the side (facing east or west).
/datum/hv_finisher/chrome/gorilla/proc/side_view()
	return facing == EAST || facing == WEST

// The one gate on who may use the Gorilla's heavy moves (gorilla_punch.dm).
/datum/hv_finisher/chrome/gorilla/user_may_finish()
	return gorilla_may_use_heavy_moves(user)

/// Pixels from the victim's tile to the bearer's.
/datum/hv_finisher/chrome/gorilla/proc/to_bearer()
	return list((user.x - victim.x) * ICON_SIZE_X, (user.y - victim.y) * ICON_SIZE_Y)

/// Both of the bearer's arms to [angle], with [reach] pixels of piston.
/datum/hv_finisher/chrome/gorilla/proc/arms_to(angle, time, reach = 0)
	bearer_rig?.swing_arm("l", angle, time, reach)
	bearer_rig?.swing_arm("r", angle, time, reach)

/// The bearer's punching hand, the attacking item for #509's hooks.
/datum/hv_finisher/chrome/gorilla/proc/fist()
	var/mob/living/carbon/bearer = user
	return bearer.get_active_hand() || bearer.get_bodypart(BODY_ZONE_R_ARM)

/// The bearer's arm on [which] ("near" or "far" to the viewer in a side view) to [angle], with [reach].
/datum/hv_finisher/chrome/gorilla/proc/arm_to(which, angle, time, reach = 0)
	if(!bearer_rig)
		return
	var/near = bearer_rig.near_side()
	var/side = which == "near" ? near : (near == "l" ? "r" : "l")
	bearer_rig.swing_arm(side, angle, time, reach)

/// The bearer's arm puppet on [which] ("near" or "far"), or null.
/datum/hv_finisher/chrome/gorilla/proc/arm_puppet(which)
	if(!bearer_rig)
		return null
	var/near = bearer_rig.near_side()
	return bearer_rig.puppet("arm_[which == "near" ? near : (near == "l" ? "r" : "l")]")

/// The beat a stage begins with: poses and sounds. Lines come from enter_line().
/datum/hv_finisher/chrome/gorilla/proc/pose(key)
	return

/// A stage's beat: damage, gore, poses.
/datum/hv_finisher/chrome/gorilla/proc/beat(key)
	return

/// The line the room sees as a stage begins, or null.
/datum/hv_finisher/chrome/gorilla/proc/enter_line(key)
	return null

/// The line the victim sees as a stage begins, or null for the room's.
/datum/hv_finisher/chrome/gorilla/proc/enter_self_line(key)
	return null

/// The flash, sparks, ring and shake of a killing blow on [where]. Only the victim flashes; the arms keep their look.
/datum/hv_finisher/chrome/gorilla/proc/hit_stop(atom/movable/where, heavy = TRUE, spark_z = 0)
	victim_rig?.flash()
	var/obj/effect/abstract/cyberware_anim/sparks = gorilla_play_impact(user, where, "impact_gorilla")
	if(sparks && spark_z)
		sparks.pixel_z += spark_z
	var/turf/spot = get_turf(where)
	if(spot)
		new /obj/effect/temp_visual/circle_wave/cyberware_slam(spot, heavy ? 1 : 0.6)
	for(var/mob/living/viewer in range(4, spot))
		if(viewer.client)
			shake_camera(viewer, heavy ? 3 : 2, heavy ? 2 : 1)

// ---- The stages: each one hands its key to the finisher ----

/datum/hv_finisher_stage/hold/gorilla
	lunge = 0
	effect_severity = 0
	/// What the finisher does in this stage
	var/key

/datum/hv_finisher_stage/hold/gorilla/enter()
	. = ..()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	finisher.pose(key)

/datum/hv_finisher_stage/hold/gorilla/effect()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	finisher.beat(key)

/datum/hv_finisher_stage/hold/gorilla/enter_message()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	return finisher.enter_line(key)

/datum/hv_finisher_stage/hold/gorilla/enter_self_message()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	return finisher.enter_self_line(key)

/datum/hv_finisher_stage/kill/gorilla
	lunge = 0
	effect_delay = 0
	duration = 1 SECONDS
	var/key

/datum/hv_finisher_stage/kill/gorilla/enter()
	. = ..()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	finisher.pose(key)

/datum/hv_finisher_stage/kill/gorilla/effect()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	finisher.beat(key)

/datum/hv_finisher_stage/kill/gorilla/enter_message()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	return finisher.enter_line(key)

/datum/hv_finisher_stage/recover/gorilla
	duration = 0.8 SECONDS
	var/key

/datum/hv_finisher_stage/recover/gorilla/enter()
	. = ..()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	finisher.pose(key)

/datum/hv_finisher_stage/recover/gorilla/effect()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	finisher.beat(key)

/datum/hv_finisher_stage/recover/gorilla/enter_message()
	var/datum/hv_finisher/chrome/gorilla/finisher = host
	return finisher.enter_line(key)

/**
 * Keeps #509's heavy-hit spray and its lost-limb spray off [victim] for the blow being dealt now. A
 * finisher lays its own blood; #509's full fan from a held body reads as blood out of nowhere.
 */
/proc/gorilla_hold_spray(mob/living/victim)
	victim.hv_blood_spray_until = max(victim.hv_blood_spray_until, world.time + 1)
	victim.hv_blood_spray_strength = INFINITY

/// One short line of [victim]'s blood toward [direction], [tiles] long, and nothing more from #509 for this blow.
/proc/gorilla_short_spray(mob/living/victim, direction, tiles = 2)
	victim.hv_blood_throw(direction, tiles)
	gorilla_hold_spray(victim)

// =========================================================================
// (A) THE HEAD CLAP
// =========================================================================

/datum/hv_finisher/chrome/gorilla/clap
	name = "gorilla head clap"
	zone_preference = list(BODY_ZONE_HEAD)
	stages = list(
		/datum/hv_finisher_stage/hold/gorilla/clap_hoist,
		/datum/hv_finisher_stage/hold/gorilla/clap_squeeze,
		/datum/hv_finisher_stage/hold/gorilla/clap_toss,
		/datum/hv_finisher_stage/kill/gorilla/clap,
		/datum/hv_finisher_stage/recover/gorilla/clap,
	)

/datum/hv_finisher_stage/hold/gorilla/clap_hoist
	key = "hoist"
	duration = 0.65 SECONDS

/datum/hv_finisher_stage/hold/gorilla/clap_squeeze
	key = "squeeze"
	duration = 1 SECONDS

/datum/hv_finisher_stage/hold/gorilla/clap_toss
	key = "toss"
	duration = 0.3 SECONDS

/datum/hv_finisher_stage/kill/gorilla/clap
	key = "clap"
	// The fists meet, a beat of hit-stop, then the head goes
	effect_delay = 0.15 SECONDS

/datum/hv_finisher_stage/recover/gorilla/clap
	key = "recover"

// With nothing to hold the brain down it would drift off for good.
/datum/hv_finisher/chrome/gorilla/clap/can_start_on(mob/living/carbon/target)
	var/turf/spot = get_turf(target)
	return !isnull(target.get_bodypart(BODY_ZONE_HEAD)) && spot?.has_gravity()

/datum/hv_finisher/chrome/gorilla/clap/pick_zone()
	target_zone = BODY_ZONE_HEAD
	return target_zone

/datum/hv_finisher/chrome/gorilla/clap/enter_line(key)
	switch(key)
		if("hoist")
			return "[user] hauls [victim] off the floor by the collar!"
		if("squeeze")
			return "[victim] chokes and kicks in [user]'s grip."

/datum/hv_finisher/chrome/gorilla/clap/enter_self_line(key)
	switch(key)
		if("hoist")
			return "[user] hauls you off the floor by the collar!"
		if("squeeze")
			return "You choke and kick in [user]'s grip."

/// Every puppet of the body held in the clap.
/datum/hv_finisher/chrome/gorilla/clap/proc/held_parts()
	. = list()
	for(var/key_name in victim_rig?.puppets)
		. += victim_rig.puppets[key_name]

/datum/hv_finisher/chrome/gorilla/clap/pose(key)
	switch(key)
		if("hoist")
			rig_bearer()
			victim_rig = new(victim, REVERSE_DIR(facing || user.dir))
			if(victim_rig.snapshot())
				// The head on its own puppet, so it can strain and crush while the body hangs
				victim_rig.add_puppet("body", victim_rig.cut_at_neck(FALSE), TRUE)
				victim_rig.add_puppet("head", victim_rig.cut_at_neck(TRUE), TRUE)
				victim_rig.conceal()
				var/list/toward = to_bearer()
				for(var/obj/effect/abstract/chrome_puppet/held as anything in held_parts())
					// The held body is in front of the bearer, unless he faces away from the viewer. Held up to his
				// face when he faces the viewer, so its head is between the fists.
					held.layer = facing == NORTH ? user.layer - 0.02 : user.layer + 0.02
					animate(held, transform = matrix(), pixel_x = round(toward[1] * 0.7), pixel_y = round(toward[2] * 0.7), pixel_w = 0, pixel_z = facing == SOUTH ? 15 : 6, time = 0.4 SECONDS, easing = SINE_EASING | EASE_OUT)
			else
				QDEL_NULL(victim_rig)
			if(side_view())
				// The near fist holds the shirt front, over the held body; the far one is behind the bearer.
				var/obj/effect/abstract/chrome_puppet/near_arm = arm_puppet("near")
				if(near_arm)
					near_arm.layer = user.layer + 0.03
				arm_to("near", 125, 0.4 SECONDS, 2)
				arm_to("far", 60, 0.4 SECONDS)
			else
				// Seen from the front or back: both hands on the shoulders of the body held in front. The arms
				// are over the bearer's body and under the held one (which is behind him when he faces away).
				for(var/side in list("l", "r"))
					var/obj/effect/abstract/chrome_puppet/arm = bearer_rig?.puppet("arm_[side]")
					if(arm)
						arm.layer = user.layer + 0.01
				arms_to(-25, 0.4 SECONDS)
		if("squeeze")
			// The fists close on the head and press. The body hangs still; the head strains and gives between them.
			if(side_view())
				arm_to("near", 122, 0.3 SECONDS, 3)
				arm_to("far", 122, 0.3 SECONDS, 3)
			else if(facing == NORTH)
				arms_to(165, 0.3 SECONDS, 7)
			else
				arms_to(160, 0.3 SECONDS, -2)
			// After the swings: the tremble runs alongside them
			bearer_rig?.tremble(1 SECONDS)
			if(facing != SOUTH)
				for(var/obj/effect/abstract/chrome_puppet/held as anything in held_parts())
					animate(held, pixel_z = 1, time = 0.3 SECONDS, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
			var/obj/effect/abstract/chrome_puppet/head = victim_rig?.puppet("head")
			if(head)
				// Narrower in steps, a strain jerk between each
				var/list/jerks = list(-5, 4, -4, 5, -3, 0)
				for(var/i in 1 to length(jerks))
					var/give = 1 - 0.05 * i
					var/matrix/pressed = side_view() 						? chrome_rig_turn(jerks[i], 0, CHROME_RIG_HEAD_PIVOT_Y, 0, 0, 1 + (1 - give) * 0.5, give) 						: chrome_rig_turn(jerks[i], 0, CHROME_RIG_HEAD_PIVOT_Y, 0, 0, give, 1 + (1 - give) * 0.3)
					if(i == 1)
						animate(head, transform = pressed, time = 0.2 SECONDS, easing = SINE_EASING)
					else
						animate(transform = pressed, time = 0.15 SECONDS, easing = SINE_EASING)
			playsound(victim, 'sound/mobs/humanoids/human/gasp/gasp_male1.ogg', 30, TRUE)
		if("toss")
			for(var/obj/effect/abstract/chrome_puppet/held as anything in held_parts())
				// A small jolt as the fists let go. Seen from the front he stays up, so his head is where the fists
				// meet behind it.
				animate(held, pixel_z = facing == SOUTH ? 17 : 4, time = 0.15 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
				animate(pixel_z = facing == SOUTH ? 15 : 2, time = 0.15 SECONDS, easing = SINE_EASING | EASE_IN)
			// The fists come off the head a little, for the clap
			if(side_view())
				arm_to("near", 95, 0.15 SECONDS)
				arm_to("far", 100, 0.15 SECONDS)
			else if(facing == NORTH)
				arms_to(135, 0.15 SECONDS)
			else
				arms_to(125, 0.15 SECONDS)
		if("clap")
			if(side_view())
				// ...and close on the head as the body drops into them: the near fist over it, the far one
				// behind it
				arm_to("near", 120, 0.08 SECONDS, 3)
				arm_to("far", 120, 0.08 SECONDS, 3)
			else if(facing == NORTH)
				// Seen from behind: both fists up past his head onto the one held beyond it
				arms_to(165, 0.08 SECONDS, 7)
			else
				// Seen from the front: the arms come up behind the held body, the fists on either side of its head
				arms_to(160, 0.08 SECONDS, -2)
			if(facing != SOUTH)
				for(var/obj/effect/abstract/chrome_puppet/held as anything in held_parts())
					animate(held, pixel_z = 0, time = 0.08 SECONDS, easing = SINE_EASING | EASE_IN, flags = ANIMATION_PARALLEL)
			var/obj/effect/abstract/chrome_puppet/head = victim_rig?.puppet("head")
			if(head)
				// The fists close and the head gives between them
				animate(head, transform = chrome_rig_turn(0, 0, CHROME_RIG_HEAD_PIVOT_Y, 0, 0, side_view() ? 1.2 : 0.55, side_view() ? 0.6 : 1.15), time = 0.08 SECONDS, easing = SINE_EASING | EASE_IN)
			// The sparks go where the fists meet, on the head
			hit_stop(head || victim, TRUE, 9)
		if("recover")
			arms_to(0, 0.5 SECONDS)

/datum/hv_finisher/chrome/gorilla/clap/beat(key)
	if(key != "clap" || QDELETED(victim))
		return
	playsound(victim, 'sound/effects/wounds/crack2.ogg', 80, TRUE)
	gorilla_head_clap(victim, user, fist(), get_dir(user, victim) || facing)
	// The body drops back to its own tile.
	QDEL_NULL(victim_rig)
	if(!QDELETED(victim) && victim.stat == DEAD)
		victim.hv_death_throes()

/**
 * Both fists meet on [victim]'s head. Bursts it (#509), or on a helmet or plating crumples the helmet and
 * caves the skull in, or on the Atlas frame does heavy damage and nothing breaks. Returns what happened:
 * "burst", "helmet", "frame" or "crit".
 */
/proc/gorilla_head_clap(mob/living/carbon/victim, mob/living/user, obj/item/fist, direction)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(isnull(head))
		return null
	victim.hv_hold_attack_message("[user] claps both fists together on [victim]'s head!", "[user] claps both fists together on your head!", "You clap both fists together on [victim]'s head!", user, vision_range = DEFAULT_MESSAGE_RANGE)
	. = "burst"
	if(HAS_TRAIT(victim, TRAIT_NODISMEMBER) && HAS_TRAIT(victim, TRAIT_CYBERWARE_UNBREAKABLE_BONES))
		// The Atlas frame: nothing bursts and nothing breaks
		victim.apply_damage(35, BRUTE, head, victim.run_armor_check(head, MELEE), wound_bonus = CANT_WOUND)
		victim.adjustOrganLoss(ORGAN_SLOT_BRAIN, 20)
		victim.hv_add_hit_line("[victim]'s frame holds!", HV_LINE_BOLD, "Your frame holds!")
		. = "frame"
	else if(HAS_TRAIT(victim, TRAIT_HEAD_INJURY_BLOCKED) || hv_crit_cover_rating(victim, head, MELEE) >= GORILLA_CLAP_HELMET_ARMOUR)
		// A helmet or plating: no burst. It crumples and the skull caves in under it.
		// No attack direction: a sealed helmet throws no blood
		victim.apply_damage(35, BRUTE, head, wound_bonus = CANT_WOUND)
		var/obj/item/clothing/helmet
		if(ishuman(victim))
			var/mob/living/carbon/human/human_victim = victim
			helmet = human_victim.head
		if(istype(helmet))
			helmet.take_damage(40, BRUTE, MELEE, FALSE)
			if(!QDELETED(helmet))
				gorilla_helmet_dent(victim)
			victim.hv_add_hit_line("[victim]'s helmet crumples!", HV_LINE_BOLD, "Your helmet crumples!", DEFAULT_MESSAGE_RANGE)
		if(hv_crit_apply_wound(head, /datum/wound/blunt/bone/critical/hv_skull, direction, fist))
			victim.hv_add_hit_line("[victim]'s skull caves in!", HV_LINE_HUGE, "Your skull caves in!", DEFAULT_MESSAGE_RANGE)
		. = "helmet"
	else
		// No attack direction: the burst lays its own blood (gorilla_clap_burst())
		victim.apply_damage(30, BRUTE, head, victim.run_armor_check(head, MELEE), wound_bonus = CANT_WOUND)
		if(QDELETED(victim) || isnull(victim.get_bodypart(BODY_ZONE_HEAD)))
			. = "burst"
		else if(!gorilla_clap_burst(victim, direction))
			// A head that can't come off: the skull caves in instead
			if(hv_crit_apply_wound(head, /datum/wound/blunt/bone/critical/hv_skull, direction, fist))
				victim.hv_add_hit_line("[victim]'s skull caves in!", HV_LINE_HUGE, "Your skull caves in!", DEFAULT_MESSAGE_RANGE)
			. = "crit"
	if(!QDELETED(victim))
		victim.hv_flush_hit()
	playsound(victim, 'sound/effects/wounds/splatter.ogg', 60, TRUE)
	log_combat(user, victim, "head-clapped", "gorilla arms", "([.])")

/**
 * #509's head burst (hv_burst_head_apart()) sized for two fists at arm's length: the gibs and splatter
 * stay round the head, one short line of blood goes out along [burst_dir], the eyes, ears and tongue
 * drop on the spot or a tile out and the brain lands a tile or two away, whole, for revival.
 * Returns TRUE if the head burst.
 */
/proc/gorilla_clap_burst(mob/living/carbon/victim, burst_dir)
	if(HAS_TRAIT(victim, TRAIT_GODMODE))
		return FALSE
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(!head || !head.can_dismember())
		return FALSE
	if(!burst_dir)
		burst_dir = pick(GLOB.alldirs)
	var/turf/here = get_turf(victim)
	var/organic = IS_ORGANIC_LIMB(head)
	var/bleeds = head.can_bleed()
	var/list/blood_dna = bleeds ? victim.get_blood_dna_list() : null
	var/blood_color = bleeds ? victim.get_bloodtype()?.get_color() : null
	var/list/obj/item/organ/loose = list()
	for(var/obj/item/organ/organ in head)
		if(!(organ.organ_flags & ORGAN_UNREMOVABLE))
			loose += organ
	// One short line; the lost-limb spray the dismember would add is held off
	gorilla_short_spray(victim, burst_dir, GORILLA_CLAP_SPRAY_TILES)
	if(!head.dismember(BRUTE, silent = TRUE))
		return FALSE
	// dismember() throws the head; a burst head comes apart where it was
	if(isturf(here) && head.loc != here)
		head.forceMove(here)
	// No violent removal: the brain has to stay good for revival
	head.drop_organs()
	qdel(head)
	if(isturf(here))
		if(!organic)
			new /obj/effect/gibspawner/robot(here, victim)
		else if(bleeds)
			gorilla_clap_gibs(here, burst_dir, blood_dna)
			hv_head_burst_splatter(here, burst_dir, blood_color)
		playsound(here, 'sound/effects/wounds/splatter.ogg', 80, TRUE)
	for(var/obj/item/organ/organ as anything in loose)
		if(QDELETED(organ) || !isturf(organ.loc))
			continue
		if(istype(organ, /obj/item/organ/brain))
			var/datum/callback/landed = blood_dna ? CALLBACK(organ, TYPE_PROC_REF(/obj/item/organ, hv_landed), blood_dna) : null
			hv_fling_organ(organ, burst_dir, GORILLA_CLAP_BRAIN_MIN, GORILLA_CLAP_BRAIN_MAX, landed)
		else if(prob(50))
			hv_fling_organ(organ, turn(burst_dir, pick(-45, 0, 45)), 1, 1)
	victim.hv_add_hit_line(pick("[victim]'s head bursts apart!", "[victim]'s skull bursts open!"), HV_LINE_HUGE, range = DEFAULT_MESSAGE_RANGE)
	return TRUE

/**
 * The clap's gibs: piled round the head, one a tile out along [burst_dir]. #509's burst gibs streak up to
 * three tiles across a cone, which from two fists at arm's length reads as a blast.
 */
/proc/gorilla_clap_gibs(turf/where, burst_dir, list/blood_dna)
	for(var/i in 1 to 3)
		var/obj/effect/decal/cleanable/blood/gibs/gib = new(where, null, blood_dna)
		if(!QDELETED(gib))
			gib.pixel_x = rand(-8, 8)
			gib.pixel_y = rand(-8, 8)
	var/turf/ahead = get_step(where, burst_dir)
	if(ahead && !isgroundlessturf(ahead) && !hv_blood_spray_blocked(ahead))
		new /obj/effect/decal/cleanable/blood/gibs(ahead, null, blood_dna)
	new /obj/effect/decal/cleanable/blood/gibs/core(where, null, blood_dna)

/// A crumpled dent drawn over the helmet for a while.
/proc/gorilla_helmet_dent(mob/living/carbon/victim)
	var/mutable_appearance/dent = mutable_appearance(GORILLA_GORE_ICON, "helmet_dent", -(HEAD_LAYER - 0.1))
	victim.add_overlay(dent)
	addtimer(CALLBACK(victim, TYPE_PROC_REF(/atom, cut_overlay), dent), 10 SECONDS)

// =========================================================================
// (B) THE LIMB RIP
// =========================================================================

/datum/hv_finisher/chrome/gorilla/rip
	name = "gorilla limb rip"
	stages = list(
		/datum/hv_finisher_stage/hold/gorilla/rip_plant,
		/datum/hv_finisher_stage/hold/gorilla/rip_strain,
		/datum/hv_finisher_stage/kill/gorilla/rip,
		/datum/hv_finisher_stage/recover/gorilla/rip_club,
		/datum/hv_finisher_stage/recover/gorilla/rip,
	)
	/// The torn-off arm, held until it is dropped on the victim's tile
	var/obj/item/bodypart/held_limb
	/// "l" or "r": the side of the victim's body the arm is on
	var/side

/datum/hv_finisher_stage/hold/gorilla/rip_plant
	key = "plant"
	duration = 0.5 SECONDS
	enter_sound = 'sound/effects/gravhit.ogg'
	enter_volume = 40

/datum/hv_finisher_stage/hold/gorilla/rip_strain
	key = "strain"
	duration = 1.35 SECONDS

/datum/hv_finisher_stage/kill/gorilla/rip
	key = "tear"
	duration = 0.8 SECONDS

/datum/hv_finisher_stage/recover/gorilla/rip_club
	key = "club"
	duration = 0.45 SECONDS
	effect_delay = 0.3 SECONDS

/datum/hv_finisher_stage/recover/gorilla/rip
	key = "recover"

/datum/hv_finisher/chrome/gorilla/rip/Destroy()
	drop_held_limb()
	return ..()

/datum/hv_finisher/chrome/gorilla/rip/stop(reason)
	if(!running)
		return
	. = ..()
	drop_held_limb()

/// The aimed arm, else the other one.
/datum/hv_finisher/chrome/gorilla/rip/pick_zone()
	var/other = aimed_zone == BODY_ZONE_L_ARM ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
	target_zone = victim.get_bodypart(aimed_zone) ? aimed_zone : (victim.get_bodypart(other) ? other : null)
	side = target_zone == BODY_ZONE_L_ARM ? "l" : "r"
	return target_zone

/datum/hv_finisher/chrome/gorilla/rip/can_start_on(mob/living/carbon/target)
	return !isnull(target.get_bodypart(BODY_ZONE_L_ARM)) || !isnull(target.get_bodypart(BODY_ZONE_R_ARM))

/datum/hv_finisher/chrome/gorilla/rip/enter_line(key)
	switch(key)
		if("plant")
			return "[user] plants a boot on [victim] and grabs [victim.p_their()] arm!"
		if("strain")
			return "[user] hauls back on [victim]'s arm!"

/datum/hv_finisher/chrome/gorilla/rip/enter_self_line(key)
	switch(key)
		if("plant")
			return "[user] plants a boot on you and grabs your arm!"
		if("strain")
			return "[user] hauls back on your arm!"

/datum/hv_finisher/chrome/gorilla/rip/pose(key)
	var/list/toward = to_bearer()
	switch(key)
		if("plant")
			rig_bearer()
			victim_rig = new(victim, victim.dir)
			if(victim_rig.snapshot())
				victim_rig.add_puppet("body", victim_rig.cut_without_arms(side), TRUE)
				victim_rig.add_puppet("arm", victim_rig.cut("rig_arm_[side]"), TRUE)
				victim_rig.conceal()
			else
				QDEL_NULL(victim_rig)
			arms_to(side_view() ? 45 : 30, 0.3 SECONDS, 3)
			// A boot on the body: the bearer leans over them, arms and all (after the swing, which would cut
			// the lean short on the arms)
			for(var/key_name in bearer_rig?.puppets)
				var/obj/effect/abstract/chrome_puppet/part = bearer_rig.puppets[key_name]
				animate(part, pixel_x = part.pixel_x - round(toward[1] * 0.08), pixel_y = part.pixel_y - round(toward[2] * 0.08), time = 0.3 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
		if("strain")
			var/obj/effect/abstract/chrome_puppet/arm = victim_rig?.puppet("arm")
			if(arm)
				// The arm comes out of the shoulder toward the bearer, five pixels over the strain
				animate(arm, pixel_x = arm.pixel_x + round(toward[1] / 32 * 5), pixel_y = arm.pixel_y + round(toward[2] / 32 * 5), time = 1.3 SECONDS, easing = SINE_EASING | EASE_IN, flags = ANIMATION_PARALLEL)
			var/obj/effect/abstract/chrome_puppet/body = victim_rig?.puppet("body")
			if(body)
				body.Shake(1, 1, 1.3 SECONDS)
			arms_to(side_view() ? 25 : 15, 1.3 SECONDS, 1)
			bearer_rig?.tremble(1.3 SECONDS)
		if("tear")
			arms_to(side_view() ? -20 : 0, 0.1 SECONDS)
		if("club")
			var/obj/effect/abstract/chrome_puppet/club = bearer_rig?.puppet("club")
			if(club)
				// Up behind the head, then down on theirs
				animate(club, pixel_z = 14, transform = matrix().Turn(160), time = 0.2 SECONDS, easing = SINE_EASING | EASE_OUT)
				animate(pixel_x = club.pixel_x - round(toward[1] * 0.6), pixel_y = club.pixel_y - round(toward[2] * 0.6), pixel_z = 2, transform = matrix().Turn(60), time = 0.1 SECONDS, easing = SINE_EASING | EASE_IN)
			arms_to(side_view() ? 150 : 165, 0.2 SECONDS, 2)
		if("recover")
			bearer_rig?.drop_puppet("club")
			arms_to(0, 0.5 SECONDS)

/datum/hv_finisher/chrome/gorilla/rip/beat(key)
	if(QDELETED(victim))
		return
	switch(key)
		if("tear")
			hit_stop(victim_rig?.puppet("arm") || victim)
			var/outcome = gorilla_limb_rip(victim, target_zone, user, fist())
			if(outcome == "torn")
				held_limb = gorilla_last_torn_limb(victim, target_zone)
				// The arm goes with the bearer's fist; the body drops back to the floor
				var/obj/effect/abstract/chrome_puppet/arm = victim_rig?.puppet("arm")
				if(arm && bearer_rig)
					victim_rig.puppets -= "arm"
					bearer_rig.puppets["club"] = arm
					arm.forceMove(get_turf(user))
					arm.pixel_x = 0
					arm.pixel_y = 0
					arm.pixel_z = 6
					arm.transform = matrix().Turn(100)
					arm.layer = user.layer + 0.03
				for(var/key_name in bearer_rig?.puppets)
					var/obj/effect/abstract/chrome_puppet/part = bearer_rig.puppets[key_name]
					animate(part, pixel_w = -2, time = 0.1 SECONDS, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
					animate(pixel_w = 2, time = 0.3 SECONDS, flags = ANIMATION_RELATIVE)
			QDEL_NULL(victim_rig)
		if("club")
			if(!held_limb)
				return
			var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
			victim.hv_hold_attack_message("[user] beats [victim] with [victim.p_their()] own arm!", "[user] beats you with your own arm!", "You beat [victim] with [victim.p_their()] own arm!", user, vision_range = DEFAULT_MESSAGE_RANGE)
			victim.apply_damage(15, BRUTE, head || BODY_ZONE_CHEST, victim.run_armor_check(head, MELEE), wound_bonus = CANT_WOUND, attack_direction = get_dir(user, victim), attacking_item = fist())
			victim.hv_flush_hit()
			playsound(victim, 'sound/effects/wounds/splatter.ogg', 60, TRUE)
			gorilla_play_impact(user, victim, "impact_gorilla")
			victim.Shake(2, 1, 0.2 SECONDS)
			if(held_limb.can_bleed())
				victim.add_splatter_floor(get_turf(victim), small_drip = TRUE)

/// Puts the torn arm down on the victim's tile, wherever the finisher stopped.
/datum/hv_finisher/chrome/gorilla/rip/proc/drop_held_limb()
	if(isnull(held_limb))
		return
	var/obj/item/bodypart/limb = held_limb
	held_limb = null
	if(QDELETED(limb))
		return
	var/turf/spot = get_turf(victim) || get_turf(user)
	if(spot)
		limb.forceMove(spot)
		if(limb.can_bleed())
			new /obj/effect/decal/cleanable/blood/splatter(spot, null, limb.blood_dna_info)

/// The arm just torn from [victim] at [zone], waiting in nullspace, or null.
/proc/gorilla_last_torn_limb(mob/living/carbon/victim, zone)
	var/obj/item/bodypart/limb = victim.gorilla_torn_limb?.resolve()
	victim.gorilla_torn_limb = null
	if(QDELETED(limb) || limb.body_zone != zone)
		return null
	return limb

/mob/living/carbon
	/// The last arm a Gorilla tore off this body, until the finisher takes it.
	var/datum/weakref/gorilla_torn_limb

/**
 * Tears [victim]'s arm at [zone] off, or wrenches the shoulder out of its socket when it's armoured, or
 * does nothing but hurt on the Atlas frame or a limb that can't come off. Returns "torn",
 * "dislocated" or "held".
 */
/proc/gorilla_limb_rip(mob/living/carbon/victim, zone, mob/living/user, obj/item/fist)
	var/obj/item/bodypart/limb = victim.get_bodypart(zone)
	if(isnull(limb))
		return null
	var/toward_bearer = get_dir(victim, user)
	if(!limb.can_dismember() || HAS_TRAIT(victim, TRAIT_CYBERWARE_UNBREAKABLE_BONES))
		victim.hv_hold_attack_message("[user] wrenches at [victim]'s [limb.plaintext_zone]!", "[user] wrenches at your [limb.plaintext_zone]!", null, user)
		victim.apply_damage(25, BRUTE, limb, victim.run_armor_check(limb, MELEE), wound_bonus = CANT_WOUND, attack_direction = toward_bearer)
		victim.hv_add_hit_line("[victim]'s arm holds!", HV_LINE_BOLD, "Your arm holds!")
		victim.hv_flush_hit()
		log_combat(user, victim, "failed to tear off the arm of", "gorilla arms")
		return "held"
	if(hv_crit_cover_rating(victim, limb, MELEE) >= GORILLA_RIP_ARMOUR)
		victim.hv_hold_attack_message("[user] wrenches at [victim]'s [limb.plaintext_zone]!", "[user] wrenches at your [limb.plaintext_zone]!", null, user)
		victim.apply_damage(25, BRUTE, limb, victim.run_armor_check(limb, MELEE), wound_bonus = CANT_WOUND, attack_direction = toward_bearer)
		if(hv_crit_apply_wound(limb, /datum/wound/blunt/bone/moderate, toward_bearer, fist))
			victim.hv_add_hit_line("[victim]'s shoulder wrenches out of its socket!", HV_LINE_BOLD, "Your shoulder wrenches out of its socket!")
		victim.hv_flush_hit()
		do_sparks(2, TRUE, victim)
		log_combat(user, victim, "dislocated the arm of", "gorilla arms")
		return "dislocated"
	// The spray runs back at the bearer: the last hit on the body came from them.
	victim.hv_hold_attack_message("[user] tears [victim]'s [limb.plaintext_zone] off at the shoulder!", "[user] tears your [limb.plaintext_zone] off at the shoulder!", "You tear [victim]'s [limb.plaintext_zone] off at the shoulder!", user, vision_range = DEFAULT_MESSAGE_RANGE)
	victim.apply_damage(10, BRUTE, limb, wound_bonus = CANT_WOUND, attack_direction = toward_bearer)
	// One straight line back at the bearer, who takes it; no fan past him
	if(limb.can_bleed())
		gorilla_short_spray(victim, toward_bearer, 2)
	var/obj/item/bodypart/torn = gorilla_tear_limb(victim, limb, toward_bearer)
	victim.hv_flush_hit()
	if(isnull(torn))
		return "held"
	if(!torn.can_bleed())
		do_sparks(3, TRUE, victim)
	playsound(victim, 'sound/effects/wounds/crackandbleed.ogg', 80, TRUE)
	victim.gorilla_torn_limb = WEAKREF(torn)
	log_combat(user, victim, "tore off the [torn.plaintext_zone] of", "gorilla arms")
	return "torn"

/**
 * Takes [limb] off as tg's dismember() does (chest damage, scream, sound, mood, memory, bleeding, the
 * floor splatter, the wet stump and the spray along the last blow), but keeps it out of the world instead
 * of flinging it: the finisher holds it, then drops it on the victim's tile. Returns the limb or null.
 */
/proc/gorilla_tear_limb(mob/living/carbon/victim, obj/item/bodypart/limb, direction)
	if(isnull(limb) || limb.owner != victim || !limb.can_dismember() || HAS_TRAIT(victim, TRAIT_GODMODE))
		return null
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	chest?.receive_damage(clamp(limb.brute_dam / 2 * chest.body_damage_coeff, 15, 50), wound_bonus = CANT_WOUND)
	INVOKE_ASYNC(victim, TYPE_PROC_REF(/mob, emote), "scream")
	playsound(get_turf(victim), 'sound/effects/dismember.ogg', 80, TRUE)
	victim.add_mood_event("dismembered_[limb.body_zone]", /datum/mood_event/dismembered, limb)
	victim.add_mob_memory(/datum/memory/was_dismembered, lost_limb = limb)
	LAZYSET(victim.body_zone_dismembered_by, limb.body_zone, WOUND_BLUNT)
	var/bleeds = limb.can_bleed()
	if(bleeds)
		victim.bleed(rand(20, 40))
	var/turf/spot = get_turf(victim)
	limb.drop_limb(FALSE, TRUE)
	victim.update_equipment_speed_mods()
	if(bleeds && isturf(spot))
		victim.add_splatter_floor(spot)
	if(QDELETED(limb))
		return null
	limb.moveToNullspace()
	return limb

// =========================================================================
// (C) THE BACKBREAKER
// =========================================================================

/datum/hv_finisher/chrome/gorilla/backbreaker
	name = "gorilla backbreaker"
	zone_preference = list(BODY_ZONE_CHEST)
	stages = list(
		/datum/hv_finisher_stage/hold/gorilla/back_hoist,
		/datum/hv_finisher_stage/hold/gorilla/back_press,
		/datum/hv_finisher_stage/kill/gorilla/backbreaker,
		/datum/hv_finisher_stage/recover/gorilla/backbreaker,
	)
	/// TRUE once the back broke: the body is rolled off still bent
	var/broke = FALSE

/datum/hv_finisher_stage/hold/gorilla/back_hoist
	key = "hoist"
	duration = 0.85 SECONDS

/datum/hv_finisher_stage/hold/gorilla/back_press
	key = "press"
	duration = 1 SECONDS

/datum/hv_finisher_stage/kill/gorilla/backbreaker
	key = "slam"
	effect_delay = 0.18 SECONDS
	duration = 0.6 SECONDS

/datum/hv_finisher_stage/recover/gorilla/backbreaker
	key = "roll"
	duration = 0.8 SECONDS

/datum/hv_finisher/chrome/gorilla/backbreaker/pick_zone()
	target_zone = BODY_ZONE_CHEST
	return target_zone

/datum/hv_finisher/chrome/gorilla/backbreaker/can_start_on(mob/living/carbon/target)
	return !isnull(target.get_bodypart(BODY_ZONE_CHEST))

/datum/hv_finisher/chrome/gorilla/backbreaker/enter_line(key)
	switch(key)
		if("hoist")
			return "[user] hoists [victim] over [user.p_their()] head!"
		if("press")
			return "[victim] thrashes in [user]'s grip."
		if("roll")
			return "[user] drops [victim] off [user.p_their()] knee."

/datum/hv_finisher/chrome/gorilla/backbreaker/enter_self_line(key)
	switch(key)
		if("hoist")
			return "[user] hoists you over [user.p_their()] head!"
		if("press")
			return "You thrash in [user]'s grip."

/// Where the belt sits, from the icon's centre: halves turn about it.
#define BACK_WAIST_PIVOT_Y -7

/datum/hv_finisher/chrome/gorilla/backbreaker/pose(key)
	var/list/toward = to_bearer()
	switch(key)
		if("hoist")
			rig_bearer()
			victim_rig = new(victim, SOUTH)
			if(victim_rig.snapshot())
				for(var/half in list("upper", "lower"))
					var/obj/effect/abstract/chrome_puppet/part = victim_rig.add_puppet(half, victim_rig.cut("rig_[half]"), TRUE, user.layer + 0.05)
					// Overhead on his back, flat, held clear above the bearer's head
					animate(part, pixel_x = toward[1], pixel_y = toward[2], pixel_w = 0, pixel_z = 29, transform = chrome_rig_turn(90, 0, BACK_WAIST_PIVOT_Y), time = 0.55 SECONDS, easing = SINE_EASING | EASE_OUT)
				victim_rig.conceal()
			else
				QDEL_NULL(victim_rig)
			// Fists up under the body
			if(side_view())
				arm_to("near", 166, 0.5 SECONDS, 6)
				arm_to("far", 174, 0.5 SECONDS, 6)
			else
				arms_to(170, 0.5 SECONDS, 3)
		if("press")
			bearer_rig?.tremble(1 SECONDS)
			var/obj/effect/abstract/chrome_puppet/upper = victim_rig?.puppet("upper")
			var/obj/effect/abstract/chrome_puppet/lower = victim_rig?.puppet("lower")
			for(var/i in 1 to 4)
				var/kick = (i % 2) ? 1 : -1
				if(upper)
					if(i == 1)
						animate(upper, transform = chrome_rig_turn(90 + 6 * kick, 0, BACK_WAIST_PIVOT_Y), time = 0.12 SECONDS)
					else
						animate(transform = chrome_rig_turn(90 + 6 * kick, 0, BACK_WAIST_PIVOT_Y), time = 0.24 SECONDS)
				if(lower)
					if(i == 1)
						animate(lower, transform = chrome_rig_turn(90 - 12 * kick, 0, BACK_WAIST_PIVOT_Y), time = 0.12 SECONDS)
					else
						animate(transform = chrome_rig_turn(90 - 12 * kick, 0, BACK_WAIST_PIVOT_Y), time = 0.24 SECONDS)
			if(upper)
				animate(transform = chrome_rig_turn(90, 0, BACK_WAIST_PIVOT_Y), time = 0.1 SECONDS)
			if(lower)
				animate(transform = chrome_rig_turn(90, 0, BACK_WAIST_PIVOT_Y), time = 0.1 SECONDS)
		if("slam")
			// Down to one knee, and the body comes down across it
			arms_to(120, 0.15 SECONDS, 2)
			bearer_rig?.crouch(0.8, 3, 0.15 SECONDS, SINE_EASING | EASE_IN)
			for(var/half in list("upper", "lower"))
				var/obj/effect/abstract/chrome_puppet/part = victim_rig?.puppet(half)
				if(part)
					animate(part, pixel_z = 2, time = 0.16 SECONDS, easing = SINE_EASING | EASE_IN, flags = ANIMATION_PARALLEL)
		if("roll")
			arms_to(0, 0.5 SECONDS)
			bearer_rig?.crouch(1, 0, 0.4 SECONDS, SINE_EASING | EASE_OUT)
			// Off the knee and down where it happened, on the bearer's tile (a body on the floor shares it).
			// The halves stay drawn where they are as the body moves under them.
			var/turf/knee = get_turf(user)
			var/turf/from = get_turf(victim)
			if(knee && from && knee != from && victim.body_position == LYING_DOWN && victim.Move(knee, get_dir(from, knee)))
				for(var/key_name in victim_rig?.puppets)
					var/obj/effect/abstract/chrome_puppet/part = victim_rig.puppets[key_name]
					part.forceMove(knee)
					part.pixel_x -= (knee.x - from.x) * ICON_SIZE_X
					part.pixel_y -= (knee.y - from.y) * ICON_SIZE_Y
			// Still bent if the back broke. A broken back hangs folded over the knee for a moment first. The
			// halves turn about the belt, seven pixels under the middle, so they sit a pixel up to lie where a
			// lying body lies.
			var/bend = broke ? 33 : 0
			var/hold = broke ? GORILLA_BACK_FOLD_HOLD : 0
			var/obj/effect/abstract/chrome_puppet/upper = victim_rig?.puppet("upper")
			var/obj/effect/abstract/chrome_puppet/lower = victim_rig?.puppet("lower")
			if(upper)
				animate(upper, transform = chrome_rig_turn(90 + (broke ? 38 : 0), 0, BACK_WAIST_PIVOT_Y), time = hold)
				animate(pixel_x = 0, pixel_y = 1, pixel_z = 0, transform = chrome_rig_turn(90 + bend, 0, BACK_WAIST_PIVOT_Y), time = 0.45 SECONDS, easing = SINE_EASING | EASE_IN | EASE_OUT)
			if(lower)
				animate(lower, transform = chrome_rig_turn(90 - (broke ? 38 : 0), 0, BACK_WAIST_PIVOT_Y), time = hold)
				animate(pixel_x = 0, pixel_y = 1, pixel_z = 0, transform = chrome_rig_turn(90 - bend, 0, BACK_WAIST_PIVOT_Y), time = 0.45 SECONDS, easing = SINE_EASING | EASE_IN | EASE_OUT)
			if(broke && !QDELETED(victim))
				// A pool from the mouth where he lands
				addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(gorilla_mouth_pool), victim), hold + 0.45 SECONDS)
			for(var/half in list("upper", "lower"))
				var/obj/effect/abstract/chrome_puppet/part = victim_rig?.puppet(half)
				if(part)
					part.layer = LYING_MOB_LAYER

/datum/hv_finisher/chrome/gorilla/backbreaker/beat(key)
	if(key != "slam" || QDELETED(victim))
		return
	hit_stop(victim_rig?.puppet("upper") || victim, TRUE)
	gorilla_backbreaker_sound(victim)
	playsound(victim, 'sound/effects/meteorimpact.ogg', 50, TRUE)
	var/turf/knee = get_turf(user)
	if(knee)
		new /obj/effect/temp_visual/cyberware_impact_cracks(knee, "damaged1", 255)
		cyberware_grey_dust(knee)
	var/outcome = gorilla_backbreak(victim, user, fist())
	broke = outcome == "broken"
	if(broke && !QDELETED(victim))
		// A trickle from the mouth, under where his head hangs over the knee
		victim.add_splatter_floor(get_turf(user), TRUE)
	if(broke)
		// The body folds over the knee
		var/obj/effect/abstract/chrome_puppet/upper = victim_rig?.puppet("upper")
		var/obj/effect/abstract/chrome_puppet/lower = victim_rig?.puppet("lower")
		if(upper)
			animate(upper, transform = chrome_rig_turn(90 + 38, 0, BACK_WAIST_PIVOT_Y), time = 0.06 SECONDS)
		if(lower)
			animate(lower, transform = chrome_rig_turn(90 - 38, 0, BACK_WAIST_PIVOT_Y), time = 0.06 SECONDS)
	else
		// Nothing gives: the body bounces off the knee
		for(var/half in list("upper", "lower"))
			var/obj/effect/abstract/chrome_puppet/part = victim_rig?.puppet(half)
			if(part)
				animate(part, pixel_z = 6, time = 0.12 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
				animate(pixel_z = 2, time = 0.12 SECONDS, easing = SINE_EASING | EASE_IN)

/// A pool of [victim]'s blood where a broken back lands.
/proc/gorilla_mouth_pool(mob/living/carbon/victim)
	if(QDELETED(victim) || !isturf(victim.loc) || victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	new /obj/effect/decal/cleanable/blood(victim.loc, victim.get_static_viruses(), victim.get_blood_dna_list())

/datum/hv_finisher/chrome/gorilla/backbreaker/cleanup_rigs()
	// A broken back stays drawn bent for a while after
	if(broke && victim_rig && !QDELETED(victim) && victim.get_bodypart(BODY_ZONE_CHEST))
		victim.AddComponent(/datum/component/gorilla_fold, victim_rig)
		victim_rig = null
	return ..()

#undef BACK_WAIST_PIVOT_Y

/**
 * Brings [victim] down across a knee: heavy brute to the chest, then a broken back, or cracked ribs under
 * chest armour, or nothing on the Atlas frame. Returns "broken", "ribs", "frame" or "bruised".
 */
/proc/gorilla_backbreak(mob/living/carbon/victim, mob/living/user, obj/item/fist)
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	if(isnull(chest))
		return null
	var/direction = get_dir(user, victim)
	victim.hv_hold_attack_message("[user] drops to one knee and brings [victim] down across it!", "[user] drops to one knee and brings you down across it!", "You drop to one knee and bring [victim] down across it!", user, vision_range = DEFAULT_MESSAGE_RANGE)
	// No attack direction: a body bent over a knee throws no blood across the room (#509's heavy-hit spray)
	victim.apply_damage(45, BRUTE, chest, victim.run_armor_check(chest, MELEE), wound_bonus = CANT_WOUND)
	. = "bruised"
	if(HAS_TRAIT(victim, TRAIT_CYBERWARE_UNBREAKABLE_BONES))
		victim.hv_add_hit_line("[victim]'s frame holds!", HV_LINE_BOLD, "Your frame holds!")
		. = "frame"
	else if(hv_crit_cover_rating(victim, chest, MELEE) >= GORILLA_BACK_ARMOUR)
		if(hv_crit_apply_wound(chest, /datum/wound/blunt/bone/severe, direction, fist))
			victim.hv_add_hit_line("[victim]'s ribs crack!", HV_LINE_BOLD, "Your ribs crack!")
			. = "ribs"
	else if(hv_crit_apply_wound(chest, /datum/wound/blunt/bone/critical/gorilla_spine, direction, fist))
		victim.hv_add_hit_line("[victim]'s back breaks!", HV_LINE_HUGE, "Your back breaks!", DEFAULT_MESSAGE_RANGE)
		. = "broken"
	if(!QDELETED(victim))
		victim.hv_flush_hit()
	log_combat(user, victim, "backbroke", "gorilla arms", "([.])")

/**
 * # Broken back
 *
 * tg's compound fracture on the chest, with the spine gone: while it lasts the body can crawl but not
 * stand. Treated like any compound fracture (surgery, or bone gel and tape).
 */
/datum/wound/blunt/bone/critical/gorilla_spine
	name = "Broken Back"
	undiagnosed_name = "Broken Back"
	desc = "Patient's spine has been snapped across, leaving the legs useless."
	treat_text = "Repair surgically. Bone gel and surgical tape will hold it in an emergency."
	treat_text_short = "Repair surgically, or apply bone gel and surgical tape."
	simple_desc = "Patient's back is broken. They cannot stand."
	simple_treat_text = "<b>Surgery</b>, or <b>bone gel</b> and <b>surgical tape</b>."
	homemade_treat_text = "Don't move them."
	examine_desc = "is bent at an angle no back should bend"
	occur_text = "folds the wrong way with a crack"

/datum/wound/blunt/bone/critical/gorilla_spine/wound_injury(datum/wound/old_wound = null, attack_direction = null)
	. = ..()
	if(victim)
		ADD_TRAIT(victim, TRAIT_FLOORED, REF(src))

/datum/wound/blunt/bone/critical/gorilla_spine/remove_wound(ignore_limb, replaced = FALSE)
	if(victim)
		REMOVE_TRAIT(victim, TRAIT_FLOORED, REF(src))
	return ..()

/datum/wound/blunt/bone/critical/gorilla_spine/set_victim(new_victim)
	if(victim)
		REMOVE_TRAIT(victim, TRAIT_FLOORED, REF(src))
	return ..()

/datum/wound_pregen_data/bone/gorilla_spine
	abstract = FALSE
	wound_path_to_generate = /datum/wound/blunt/bone/critical/gorilla_spine
	viable_zones = list(BODY_ZONE_CHEST)
	can_be_randomly_generated = FALSE
	threshold_minimum = 115

/**
 * The fold a broken back leaves: the victim's puppets stay bent for a while after the backbreaker, until
 * the body is moved, buckled or the back is set.
 */
/datum/component/gorilla_fold
	/// The victim's rig, handed over by the finisher
	var/datum/chrome_rig/rig
	var/fold_timer

/datum/component/gorilla_fold/Initialize(datum/chrome_rig/rig)
	if(!iscarbon(parent) || !istype(rig))
		return COMPONENT_INCOMPATIBLE
	src.rig = rig
	fold_timer = QDEL_IN_STOPPABLE(src, GORILLA_FOLD_TIME)

/datum/component/gorilla_fold/RegisterWithParent()
	RegisterSignals(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BUCKLED, COMSIG_CARBON_LOSE_WOUND, COMSIG_LIVING_REVIVE, COMSIG_LIVING_SET_BODY_POSITION), PROC_REF(unfold))

/datum/component/gorilla_fold/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BUCKLED, COMSIG_CARBON_LOSE_WOUND, COMSIG_LIVING_REVIVE, COMSIG_LIVING_SET_BODY_POSITION))

/datum/component/gorilla_fold/Destroy()
	if(fold_timer)
		deltimer(fold_timer)
		fold_timer = null
	QDEL_NULL(rig)
	return ..()

/datum/component/gorilla_fold/proc/unfold(datum/source)
	SIGNAL_HANDLER
	qdel(src)
