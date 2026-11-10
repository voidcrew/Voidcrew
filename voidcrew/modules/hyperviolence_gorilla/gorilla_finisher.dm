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
 * A synced pair of Brawler myomers has the limb rip only, the same rip on the same terms.
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
	if(!iscarbon(victim) || !ishuman(source) || !gorilla_may_use_heavy_moves(source))
		return FALSE
	var/gorilla_pair = gorilla_synced(source)
	if(!gorilla_pair && !brawler_synced(source))
		return FALSE
	if(!TIMER_COOLDOWN_FINISHED(source, COOLDOWN_GORILLA_PISTONS) || source.chrome_finisher)
		return FALSE
	if(!chrome_finisher_valid_victim(source, victim))
		return FALSE
	zone = check_zone(zone || source.zone_selected)
	var/datum/hv_finisher/chrome/gorilla/finisher_type
	switch(zone)
		if(BODY_ZONE_HEAD)
			finisher_type = /datum/hv_finisher/chrome/gorilla/clap
		if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
			finisher_type = /datum/hv_finisher/chrome/gorilla/rip
		if(BODY_ZONE_CHEST)
			finisher_type = /datum/hv_finisher/chrome/gorilla/backbreaker
	if(!finisher_type)
		return FALSE
	// Brawler myomers have the rip and nothing else
	if(!gorilla_pair && !initial(finisher_type.brawler_ok))
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
	/// Whether a synced pair of Brawler myomers can do this one too, not only Gorilla Arms
	var/brawler_ok = FALSE
	/// Where the victim was drawn before the finisher's grab, list(x, y) of their pixel offsets: tg draws a grabbed body
	/// pulled in at once, and the puppets ease that in instead
	var/list/lying_offsets

/datum/hv_finisher/chrome/gorilla/take_grip()
	if(!gripped && isnull(lying_offsets) && !QDELETED(victim))
		lying_offsets = list(victim.pixel_x + victim.pixel_w, victim.pixel_y + victim.pixel_z)
	return ..()

/// Pixels from where the victim is drawn now back to where they lay before the grab: list(x, y).
/datum/hv_finisher/chrome/gorilla/proc/grab_pull_back()
	if(isnull(lying_offsets) || QDELETED(victim))
		return list(0, 0)
	return list(lying_offsets[1] - (victim.pixel_x + victim.pixel_w), lying_offsets[2] - (victim.pixel_y + victim.pixel_z))

/datum/hv_finisher/chrome/gorilla/can_start()
	if(!..())
		return FALSE
	if(!ishuman(user) || !pair_synced() || !TIMER_COOLDOWN_FINISHED(user, COOLDOWN_GORILLA_PISTONS))
		return FALSE
	var/mob/living/carbon/human/bearer = user
	for(var/obj/item/held in bearer.held_items)
		return FALSE
	var/list/arms = gorilla_synced_pair(bearer)
	if(length(arms) < 2)
		return FALSE
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in arms)
		if(!arm.gorilla_running())
			return FALSE
	return can_start_on(victim)

/// Whether the bearer's arms are synced for this finisher: a Gorilla pair, or a Brawler pair where it allows one.
/datum/hv_finisher/chrome/gorilla/proc/pair_synced()
	return gorilla_synced(user) || (brawler_ok && brawler_synced(user))

/// What this finisher needs of the victim besides being down.
/datum/hv_finisher/chrome/gorilla/proc/can_start_on(mob/living/carbon/target)
	return TRUE

/datum/hv_finisher/chrome/gorilla/safety_check()
	. = ..()
	if(!. && !completed && !pair_synced())
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
	/// The held body's offsets at rest in the hold, list(pixel_x, pixel_y, pixel_z): the fists move it about from there
	var/list/held_at

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

/// The middle of a human head above the neck line, half its width, and half a fist's width, in pixels (tg's human base sprite).
#define CLAP_HEAD_RISE 3.5
#define CLAP_HEAD_HALF_WIDTH 4.5
#define CLAP_FIST_HALF_WIDTH 1.5
/// A chrome fist on an arm pointing up is drawn a couple of pixels short of its hand's middle: aim it that much higher.
#define CLAP_FIST_RAISE 2

/// The puppets of the body held in the clap that move it about. The head rides on the body (see the hoist), so it is not one.
/datum/hv_finisher/chrome/gorilla/clap/proc/held_parts()
	. = list()
	for(var/key_name in victim_rig?.puppets)
		if(key_name != "head")
			. += victim_rig.puppets[key_name]

/**
 * Where the bearer's fists go on the held head: side ("l" or "r") -> list(x, y), pixels from the middle of his
 * puppets, as pose_reaching() takes them. Seen from the side both go on the temple, the near one over the head and the
 * far one behind it; from the front or back, one on each side of it. [apart] pixels back off it (negative: pressed
 * in), the head squashed to [width] and [height] about its neck, the held body moved [shift_x], [shift_y] pixels from
 * where it rests in the hold. Null without both rigs.
 */
/datum/hv_finisher/chrome/gorilla/clap/proc/fists_on_head(apart = 0, width = 1, height = 1, shift_x = 0, shift_y = 0)
	var/obj/effect/abstract/chrome_puppet/body_puppet = victim_rig?.puppet("body")
	if(!bearer_rig || !body_puppet || !isturf(body_puppet.loc) || !held_at)
		return null
	// The held body's middle as drawn, from the middle of the bearer's puppets
	var/held_x = (body_puppet.x - user.x) * ICON_SIZE_X + held_at[1] + shift_x - (user.pixel_x + user.pixel_w)
	var/held_y = (body_puppet.y - user.y) * ICON_SIZE_Y + held_at[2] + held_at[3] + shift_y - (user.pixel_y + user.pixel_z)
	// The picture faces the bearer, which puts the head's middle half a pixel off the picture's
	var/head_x = held_x + (facing == WEST ? 0.5 : -0.5) * width
	var/head_y = held_y + CHROME_RIG_NECK_PIVOT_Y + CLAP_HEAD_RISE * height
	. = list()
	if(side_view())
		var/back = facing == EAST ? -1 : 1
		for(var/side in list("l", "r"))
			.[side] = list(head_x + back * apart, head_y - 1)
		return
	var/out_by = CLAP_HEAD_HALF_WIDTH * width + CLAP_FIST_HALF_WIDTH + apart
	for(var/side in list("l", "r"))
		var/list/pivot = bearer_rig.shoulder(side)
		.[side] = list(head_x + (pivot[1] < 0 ? -out_by : out_by), head_y + CLAP_FIST_RAISE)

/// Both fists to [fists] (fists_on_head()) over [time], in short steps.
/datum/hv_finisher/chrome/gorilla/clap/proc/fists_to(list/fists, time)
	for(var/side in fists)
		bearer_rig.reach_through(side, list(fists[side]), list(time), GORILLA_CLAP_MAX_REACH)

/// The most either arm must stretch to put its fist on [fists] (fists_on_head()), as a share of its length.
/datum/hv_finisher/chrome/gorilla/clap/proc/fists_stretch(list/fists)
	. = 0
	for(var/side in fists)
		var/list/point = fists[side]
		var/list/pose = bearer_rig.pose_reaching(side, point[1], point[2])
		. = max(., pose[2])

/**
 * [shift_x], [shift_y] (pixels the fists would move the held head from where it rests in the hold), cut back as far as it
 * takes for both fists to stay on the head there ([apart], [width] and [height] as fists_on_head() takes them): never further
 * than his arms reach, or than they already stretch to hold it still. list(x, y), whole pixels.
 */
/datum/hv_finisher/chrome/gorilla/clap/proc/within_reach(shift_x, shift_y, apart = 0, width = 1, height = 1)
	var/list/still = fists_on_head(apart, width, height)
	if(!still)
		return list(0, 0)
	var/most = max(GORILLA_CLAP_MAX_REACH, fists_stretch(still))
	for(var/scale in list(1, 0.75, 0.5, 0.25))
		var/list/shift = list(round(shift_x * scale, 1), round(shift_y * scale, 1))
		if(fists_stretch(fists_on_head(apart, width, height, shift[1], shift[2])) <= most)
			return shift
	return list(0, 0)

/**
 * The held body hangs from its head: to each of [shifts] (list(x, y) pixels from where it rests in the hold) in turn,
 * step_times[i] to the i-th, swinging about its neck behind the head as it is shaken aside. Returns the swing at each step,
 * which the head takes back off its own turn so only its strain shows.
 */
/datum/hv_finisher/chrome/gorilla/clap/proc/move_held(list/shifts, list/step_times, easing = SINE_EASING)
	. = list()
	var/obj/effect/abstract/chrome_puppet/body_puppet = victim_rig?.puppet("body")
	for(var/i in 1 to length(shifts))
		var/list/shift = shifts[i]
		var/sway = clamp(shift[1] * GORILLA_CLAP_SWAY, -GORILLA_CLAP_MAX_SWAY, GORILLA_CLAP_MAX_SWAY)
		. += sway
		if(!body_puppet || !held_at)
			continue
		var/matrix/hung = chrome_rig_turn(sway, 0, CHROME_RIG_NECK_PIVOT_Y)
		if(i == 1)
			animate(body_puppet, transform = hung, pixel_x = held_at[1] + shift[1], pixel_y = held_at[2], pixel_z = held_at[3] + shift[2], time = step_times[i], easing = easing)
		else
			animate(transform = hung, pixel_x = held_at[1] + shift[1], pixel_y = held_at[2], pixel_z = held_at[3] + shift[2], time = step_times[i], easing = easing)

/datum/hv_finisher/chrome/gorilla/clap/pose(key)
	switch(key)
		if("hoist")
			rig_bearer()
			victim_rig = new(victim, REVERSE_DIR(facing || user.dir))
			if(victim_rig.snapshot())
				// The head on its own puppet, so it can strain and crush while the body hangs
				victim_rig.add_puppet("body", victim_rig.cut_at_neck(FALSE), TRUE)
				var/obj/effect/abstract/chrome_puppet/head = victim_rig.add_puppet("head", victim_rig.cut_at_neck(TRUE))
				// The head rides on the body, drawn wherever the body is and turned with it, so it can never come
				// off the neck: only its own squash and strain are its own
				head.pixel_x = 0
				head.pixel_y = 0
				head.pixel_w = 0
				head.pixel_z = 0
				head.moveToNullspace()
				var/obj/effect/abstract/chrome_puppet/body_puppet = victim_rig.puppet("body")
				body_puppet.vis_contents += head
				victim_rig.conceal()
				var/list/toward = to_bearer()
				// Held up in close, and kept there until the burst: seen from the side chest to chest, from the front
				// up to his face, from the back just past his head, so its head is where his fists can close on it
				var/share = side_view() ? GORILLA_CLAP_HOLD_SIDE : (facing == NORTH ? GORILLA_CLAP_HOLD_BACK : GORILLA_CLAP_HOLD_FRONT)
				var/lift = side_view() ? GORILLA_CLAP_LIFT_SIDE : (facing == NORTH ? GORILLA_CLAP_LIFT_BACK : GORILLA_CLAP_LIFT_FRONT)
				held_at = list(round(toward[1] * share), round(toward[2] * share), lift)
				// It comes up from where it lay, not from where tg's grab draws it pulled in
				var/list/pull_back = grab_pull_back()
				for(var/obj/effect/abstract/chrome_puppet/held as anything in held_parts())
					held.pixel_x += pull_back[1]
					held.pixel_y += pull_back[2]
					// The held body is in front of the bearer, unless he faces away from the viewer
					held.layer = facing == NORTH ? user.layer - 0.02 : user.layer + 0.02
					animate(held, transform = matrix(), pixel_x = held_at[1], pixel_y = held_at[2], pixel_w = 0, pixel_z = held_at[3], time = 0.4 SECONDS, easing = SINE_EASING | EASE_OUT)
				// The head's bottom row overlaps the body's top one: the head draws over it
				head.layer = body_puppet.layer + 0.001
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
			// The fists close on the head and press, then wrench it side to side and lift it as they squeeze. The body
			// hangs from the head and goes with them, swinging behind it; the head strains and gives between the fists in
			// steps, about the neck so it stays on the shoulders, and the fists follow it in.
			var/obj/effect/abstract/chrome_puppet/head = victim_rig?.puppet("head")
			var/list/jerks = list(-5, 4, -4, 5, -3, 0)
			// Shares of GORILLA_CLAP_SHAKE (aside) and GORILLA_CLAP_HEAVE (up), never lowered
			var/list/shakes = list(0, 1, -1, 1, -0.5, 0)
			var/list/heaves = list(0, 0.5, 0.5, 1, 1, 1)
			var/list/step_times = list()
			var/list/squashes = list()
			var/list/shifts = list()
			var/list/fist_points = list("l" = list(), "r" = list())
			for(var/i in 1 to length(jerks))
				var/give = 1 - 0.05 * i
				var/width = side_view() ? 1 + (1 - give) * 0.5 : give
				var/height = side_view() ? give : 1 + (1 - give) * 0.3
				step_times += i == 1 ? 0.2 SECONDS : 0.15 SECONDS
				squashes += list(list(width, height))
				var/list/shift = within_reach(shakes[i] * GORILLA_CLAP_SHAKE, heaves[i] * GORILLA_CLAP_HEAVE, 0, width, height)
				shifts += list(shift)
				var/list/fists = fists_on_head(0, width, height, shift[1], shift[2])
				for(var/side in fists)
					fist_points[side] += list(fists[side])
			// Each puppet's steps in one run, as animate() chains onto the last thing it was given
			var/list/sways = move_held(shifts, step_times)
			if(head)
				for(var/i in 1 to length(jerks))
					var/list/squash = squashes[i]
					// Its own strain and squash about the neck, on top of the body's swing
					var/matrix/pressed = chrome_rig_turn(jerks[i] - sways[i], 0, CHROME_RIG_NECK_PIVOT_Y, 0, 0, squash[1], squash[2])
					if(i == 1)
						animate(head, transform = pressed, time = step_times[i], easing = SINE_EASING)
					else
						animate(transform = pressed, time = step_times[i], easing = SINE_EASING)
			for(var/side in fist_points)
				if(length(fist_points[side]))
					bearer_rig.reach_through(side, fist_points[side], step_times, GORILLA_CLAP_MAX_REACH)
			// After the swings: the tremble runs alongside them, his fists and the body he holds shaking together
			bearer_rig?.tremble(1 SECONDS)
			victim_rig?.tremble(1 SECONDS, list("head"))
			playsound(victim, 'sound/mobs/humanoids/human/gasp/gasp_male1.ogg', 30, TRUE)
		if("toss")
			// The fists heave the head up and come off it a little, for the clap; the body goes up with it
			var/width = side_view() ? 1.15 : 0.7
			var/height = side_view() ? 0.7 : 1.09
			var/list/shift = within_reach(0, GORILLA_CLAP_HEAVE + GORILLA_CLAP_TOSS_LIFT, GORILLA_CLAP_WIND, width, height)
			fists_to(fists_on_head(GORILLA_CLAP_WIND, width, height, shift[1], shift[2]), 0.15 SECONDS)
			move_held(list(shift), list(0.15 SECONDS), SINE_EASING | EASE_OUT)
		if("clap")
			// It bursts and falls where it is held, on the bearer's tile. First, as it moves every puppet to his tile.
			bring_in()
			// ...and the fists slam back in and down, pressed into the head as it gives between them, still on the neck,
			// and drive it down with them
			var/width = side_view() ? 1.2 : 0.55
			var/height = side_view() ? 0.6 : 1.15
			var/list/shift = within_reach(0, GORILLA_CLAP_HEAVE + GORILLA_CLAP_TOSS_LIFT - GORILLA_CLAP_SLAM, -1, width, height)
			fists_to(fists_on_head(-1, width, height, shift[1], shift[2]), 0.08 SECONDS)
			move_held(list(shift), list(0.08 SECONDS), SINE_EASING | EASE_IN)
			var/obj/effect/abstract/chrome_puppet/head = victim_rig?.puppet("head")
			if(head)
				animate(head, transform = chrome_rig_turn(0, 0, CHROME_RIG_NECK_PIVOT_Y, 0, 0, width, height), time = 0.08 SECONDS, easing = SINE_EASING | EASE_IN)
			// The sparks go where the fists meet, on the head
			hit_stop(victim_rig?.puppet("body") || victim, TRUE, 9)
		if("recover")
			arms_to(0, 0.5 SECONDS)

/datum/hv_finisher/chrome/gorilla/clap/beat(key)
	if(key != "clap" || QDELETED(victim))
		return
	playsound(victim, 'sound/effects/wounds/crack2.ogg', 80, TRUE)
	// Blood and pieces go on out ahead of him
	var/outcome = gorilla_head_clap(victim, user, fist(), facing)
	drop_held_body(outcome == "burst")

/**
 * Brings the held body onto the bearer's tile, drawn where it is held, so it bursts there and falls at his feet
 * (a body on the floor shares his tile).
 */
/datum/hv_finisher/chrome/gorilla/clap/proc/bring_in()
	var/turf/here = get_turf(user)
	var/turf/from = get_turf(victim)
	if(!isturf(here) || !isturf(from) || here == from)
		return
	// Off the grab first: tg turns a pulled body to face whoever pulls it, and on one tile there is no way to face
	release_grip()
	if(!victim.Move(here, get_dir(from, here)))
		victim.forceMove(here)
	if(get_turf(victim) != here)
		return
	for(var/obj/effect/abstract/chrome_puppet/part as anything in held_parts())
		part.forceMove(here)
		part.pixel_x -= (here.x - from.x) * ICON_SIZE_X
		part.pixel_y -= (here.y - from.y) * ICON_SIZE_Y
	if(held_at)
		held_at[1] -= (here.x - from.x) * ICON_SIZE_X
		held_at[2] -= (here.y - from.y) * ICON_SIZE_Y

/// The held body falls from where it is held, headless after a burst, to lie as the real one does; that one shows when it lands.
/datum/hv_finisher/chrome/gorilla/clap/proc/drop_held_body(burst)
	var/obj/effect/abstract/chrome_puppet/body_puppet = victim_rig?.puppet("body")
	if(!body_puppet || QDELETED(victim) || get_turf(body_puppet) != get_turf(victim))
		land()
		return
	if(burst)
		var/obj/effect/abstract/chrome_puppet/head = victim_rig.puppet("head")
		if(head)
			body_puppet.vis_contents -= head
			victim_rig.drop_puppet("head")
	// The real body's turn and offsets are already its own, though it may still be drawn on its way to them
	animate(body_puppet, transform = victim.transform, pixel_x = victim.pixel_x, pixel_y = victim.pixel_y, pixel_w = victim.pixel_w, pixel_z = victim.pixel_z, time = GORILLA_CLAP_DROP_TIME, easing = SINE_EASING | EASE_IN)
	addtimer(CALLBACK(src, PROC_REF(land)), GORILLA_CLAP_DROP_TIME, TIMER_DELETE_ME)

/// The held body is down: the real one shows in its place.
/datum/hv_finisher/chrome/gorilla/clap/proc/land()
	QDEL_NULL(victim_rig)
	if(!QDELETED(victim) && victim.stat == DEAD)
		victim.hv_death_throes()

#undef CLAP_HEAD_RISE
#undef CLAP_HEAD_HALF_WIDTH
#undef CLAP_FIST_HALF_WIDTH
#undef CLAP_FIST_RAISE

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
	// Not dismember(): it throws the head a tile or two, and a head is heavy enough to knock whoever it hits
	// a tile back. Thrown into the bearer it shoved him off the body and ended the finisher at the burst.
	head = gorilla_tear_limb(victim, head, burst_dir, FALSE)
	if(isnull(head))
		return FALSE
	// A burst head comes apart where it was
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
	brawler_ok = TRUE
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
	/// The bearer's arm whose fist takes the wrist first ("l" or "r"); the other fist joins it
	var/grip_side
	/// Pixels the bearer's puppets lean onto the body now: further in as he takes the arm, back to lean_out as he hauls
	var/list/lean = list(0, 0)
	/// The lean he hauls back to and holds through the blow
	var/list/lean_out = list(0, 0)
	/// Pixels the body's puppets are drawn from the real body: where it lay before the grab, until he drags it in by the arm
	var/list/body_shift = list(0, 0)
	/// Degrees (clockwise) the body is turned up about its feet toward his fists by the haul
	var/raised = 0
	/// The hauled arm's length when the fists take it, as a share of its own
	var/grip_stretch = 1
	/// Where the fists hold the wrist: pixels from the middle of the bearer's tile
	var/list/grip
	/// The torn arm's hand and shoulder in its own picture, list(hand_x, hand_y, shoulder_x, shoulder_y): the bearer
	/// holds it by the hand and swings the shoulder end
	var/list/club_ends

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
	// Still held through the blow, so the body doesn't slide back off the grab under it. The hit is timed with the
	// swing (swing_club()), not this stage's beat, which only fires on the finisher's next tick.
	pins = TRUE

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
			lean_out = list(-round(toward[1] / ICON_SIZE_X * GORILLA_RIP_LEAN), -round(toward[2] / ICON_SIZE_Y * GORILLA_RIP_LEAN))
			lean = lean_out.Copy()
			victim_rig = new(victim, victim.dir)
			if(bearer_rig && victim_rig.snapshot())
				// The arm turns with the lying body, about its own shoulder
				victim_rig.base_transform = matrix(victim.transform)
				victim_rig.add_puppet("body", victim_rig.cut_without_arms(side), TRUE)
				var/obj/effect/abstract/chrome_puppet/hauled = victim_rig.add_puppet("arm_[side]", victim_rig.arm_picture(side), TRUE)
				// The far arm seen from the side comes out from behind the body. Any other arm is hauled up in front of the
				// bearer, over his body and under his near fist, unless he faces away and it is beyond him.
				if(victim_rig.behind_body(side))
					hauled.layer = victim.layer - 0.01
				else
					hauled.layer = facing == NORTH ? victim.layer + 0.01 : user.layer + 0.005
				// The body stays where it lay (tg's grab draws it pulled in at once): he steps in to it as far, and drags it
				// in by the arm as he hauls
				body_shift = grab_pull_back()
				lean = list(lean_out[1] + body_shift[1], lean_out[2] + body_shift[2])
				for(var/key_name in victim_rig.puppets)
					var/obj/effect/abstract/chrome_puppet/part = victim_rig.puppets[key_name]
					part.pixel_x += body_shift[1]
					part.pixel_y += body_shift[2]
				victim_rig.conceal()
				take_wrist(0.3 SECONDS)
			else
				QDEL_NULL(victim_rig)
				arms_to(side_view() ? 45 : 30, 0.3 SECONDS, 3)
			// A boot on the body: the bearer leans over them, arms and all (after the swings, which would cut
			// the lean short on the arms)
			for(var/key_name in bearer_rig?.puppets)
				var/obj/effect/abstract/chrome_puppet/part = bearer_rig.puppets[key_name]
				animate(part, pixel_x = part.pixel_x + lean[1], pixel_y = part.pixel_y + lean[2], time = 0.3 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
		if("strain")
			if(victim_rig && grip)
				haul(1.3 SECONDS)
			else
				arms_to(side_view() ? 25 : 15, 1.3 SECONDS, 1)
				bearer_rig?.tremble(1.3 SECONDS)
		if("tear")
			// The arm gives: he yanks it back and comes upright
			bearer_rig?.bend_and_swing(0, side_view() ? -20 : 0, 0.1 SECONDS)
		if("club")
			if(held_limb)
				// Up over his head, then down on theirs, the hit landing as it comes down
				swing_club(GORILLA_CLUB_RAISE, GORILLA_CLUB_STRIKE)
				// A shade before the arm is all the way down: the server's timer runs a tick or two behind the client's swing
				addtimer(CALLBACK(src, PROC_REF(club_hit)), GORILLA_CLUB_RAISE + GORILLA_CLUB_STRIKE - GORILLA_CLUB_HIT_LEAD, TIMER_DELETE_ME)
			else
				arms_to(0, 0.4 SECONDS)
		if("recover")
			bearer_rig?.drop_puppet("club")
			// The arm goes down with the body as he lets it go
			drop_held_limb()
			arms_to(0, 0.5 SECONDS)
			// Straightens up off the body, so the real one shows where he stands (after the swing, as the lean was)
			for(var/key_name in bearer_rig?.puppets)
				var/obj/effect/abstract/chrome_puppet/part = bearer_rig.puppets[key_name]
				animate(part, pixel_x = user.pixel_x, pixel_y = user.pixel_y, time = 0.4 SECONDS, easing = SINE_EASING, flags = ANIMATION_PARALLEL)

/// The middle of the bearer's puppets as drawn: pixels from the middle of his tile.
/datum/hv_finisher/chrome/gorilla/rip/proc/bearer_origin()
	return list(user.pixel_x + user.pixel_w + lean[1], user.pixel_y + user.pixel_z + lean[2])

/// The middle of the body's puppets as drawn (body_shift from the real body): pixels from the middle of the bearer's tile.
/datum/hv_finisher/chrome/gorilla/rip/proc/body_origin()
	return list((victim.x - user.x) * ICON_SIZE_X + victim.pixel_x + victim.pixel_w + body_shift[1], (victim.y - user.y) * ICON_SIZE_Y + victim.pixel_y + victim.pixel_z + body_shift[2])

/**
 * The hauled arm's shoulder as drawn, the body turned as the victim rig's base_transform turns it (pixels from the middle
 * of the bearer's tile), and the angle the arm comes up at: toward the bearer's shoulders (bent by [bearer_base]), and
 * seen from the side turned [tilt] degrees up off the floor. list(x, y, angle).
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/haul_line(tilt, matrix/bearer_base)
	var/list/shoulder_at = body_shoulder_at()
	var/list/left = bearer_shoulder_at("l", bearer_base)
	var/list/right = bearer_shoulder_at("r", bearer_base)
	var/angle = arctan((left[1] + right[1]) / 2 - shoulder_at[1], (left[2] + right[2]) / 2 - shoulder_at[2])
	if(side_view())
		// Up toward the top of the screen, never past it
		var/to_up = 90 - angle
		while(to_up > 180)
			to_up -= 360
		while(to_up < -180)
			to_up += 360
		angle += clamp(to_up, -tilt, tilt)
	return list(shoulder_at[1], shoulder_at[2], angle)

/// Where the bearer's shoulder on [arm_side] is drawn with his body bent by [bearer_base]: pixels from the middle of his tile.
/datum/hv_finisher/chrome/gorilla/rip/proc/bearer_shoulder_at(arm_side, matrix/bearer_base)
	var/list/origin = bearer_origin()
	var/list/at = bearer_rig.shoulder_point(arm_side, bearer_base)
	return list(origin[1] + at[1], origin[2] + at[2])

/// Where the hauled arm's shoulder is drawn, the body turned as the victim rig's base_transform turns it: pixels from the middle of the bearer's tile.
/datum/hv_finisher/chrome/gorilla/rip/proc/body_shoulder_at()
	var/list/body_at = body_origin()
	var/list/at = victim_rig.shoulder_point(side)
	return list(body_at[1] + at[1], body_at[2] + at[2])

/// Where the wrist is when the arm is [stretch] times its length: pixels from the middle of the bearer's tile.
/datum/hv_finisher/chrome/gorilla/rip/proc/wrist_at(stretch, tilt, matrix/bearer_base)
	var/list/line = haul_line(tilt, bearer_base)
	var/length = stretch * victim_rig.arm_reach(side)
	return list(line[1] + length * cos(line[3]), line[2] + length * sin(line[3]))

/**
 * The poses that put both of the bearer's fists (his body bent by [bearer_base]) and the hauled hand (the body
 * turned as the victim rig's base_transform turns it) on [wrist], each turned the short way from [from] (key -> turn).
 * Keys "bearer_l", "bearer_r" and "body"; every pose carries its body's turn.
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/poses_on(list/wrist, list/from, matrix/bearer_base)
	. = list()
	var/list/origin = bearer_origin()
	for(var/arm_side in list("l", "r"))
		var/list/pose = bearer_rig.pose_reaching(arm_side, wrist[1] - origin[1], wrist[2] - origin[2], from["bearer_[arm_side]"], bearer_base)
		.["bearer_[arm_side]"] = list(pose[1], pose[2], bearer_base)
	var/list/body_at = body_origin()
	var/list/body_pose = victim_rig.pose_reaching(side, wrist[1] - body_at[1], wrist[2] - body_at[2], from["body"])
	.["body"] = list(body_pose[1], body_pose[2], victim_rig.base_transform)

/// Sends the bearer's arms and body and the hauled arm through [all_poses] (a list of poses_on() lists), [step_time] a step.
/datum/hv_finisher/chrome/gorilla/rip/proc/pose_through(list/all_poses, step_time)
	var/list/bends = list()
	for(var/key_name in list("bearer_l", "bearer_r", "body"))
		var/list/steps = list()
		for(var/list/poses as anything in all_poses)
			var/list/pose = poses[key_name]
			steps += list(pose)
			if(key_name == "bearer_l")
				bends += list(pose[3])
		if(key_name == "body")
			victim_rig.pose_arm_through(side, steps, step_time)
		else
			bearer_rig.pose_arm_through(key_name == "bearer_l" ? "l" : "r", steps, step_time)
	// His body bends with his arms, step for step, so they stay on his shoulders
	bearer_rig.body_through(bends, step_time)

/// The turns each arm is in now, keyed as poses_on() keys them.
/datum/hv_finisher/chrome/gorilla/rip/proc/turns_now()
	. = list()
	for(var/arm_side in list("l", "r"))
		var/list/pose = bearer_rig.arm_poses[arm_side] || list(0, 1)
		.["bearer_[arm_side]"] = pose[1]
	var/list/pose = victim_rig.arm_poses[side] || list(0, 1)
	.["body"] = pose[1]

/**
 * The plant, over [time]: the bearer's piston arms push out, both fists close on the wrist and the arm comes
 * up off the floor into them.
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/take_wrist(time)
	var/bend = 0
	var/matrix/bent = null
	var/list/line = haul_line(GORILLA_RIP_TILT, bent)
	// The fist on the near side (seen from the side) or nearer the arm takes it; the other one joins it
	var/best_distance
	for(var/arm_side in list("l", "r"))
		var/list/at = bearer_shoulder_at(arm_side, bent)
		var/distance = sqrt((at[1] - line[1]) ** 2 + (at[2] - line[2]) ** 2)
		if(isnull(best_distance) || distance < best_distance)
			best_distance = distance
			grip_side = arm_side
	if(side_view())
		grip_side = bearer_rig.near_side()
	// The arm comes up as far as it takes to meet that fist pushed out to its reach
	var/list/from = bearer_shoulder_at(grip_side, bent)
	var/along = gorilla_ray_meets(line[1], line[2], line[3], from[1], from[2], GORILLA_RIP_REACH * bearer_rig.arm_reach(grip_side))
	grip_stretch = clamp(isnull(along) ? GORILLA_RIP_MAX_STRETCH : along / victim_rig.arm_reach(side), 1, GORILLA_RIP_MAX_STRETCH)
	grip = wrist_at(grip_stretch, GORILLA_RIP_TILT, bent)
	// Every arm swings the same number of short steps, so they arrive together
	var/list/now = turns_now()
	var/list/there = poses_on(grip, now, bent)
	var/list/start = list(
		"bearer_l" = bearer_rig.arm_poses["l"] || list(0, 1),
		"bearer_r" = bearer_rig.arm_poses["r"] || list(0, 1),
		"body" = victim_rig.arm_poses[side] || list(0, 1),
	)
	var/steps = bearer_rig.swing_steps(0, bend)
	for(var/key_name in there)
		var/list/pose = there[key_name]
		steps = max(steps, bearer_rig.swing_steps(now[key_name], pose[1]))
	var/list/all_poses = list()
	for(var/i in 1 to steps)
		var/progress = (1 - cos(180 * i / steps)) / 2
		var/matrix/bent_now = bearer_rig.bend_matrix(bend * progress)
		var/list/poses = list()
		for(var/key_name in there)
			var/list/pose = there[key_name]
			var/list/was = start[key_name]
			poses[key_name] = list(was[1] + (pose[1] - was[1]) * progress, was[2] + (pose[2] - was[2]) * progress, key_name == "body" ? null : bent_now)
		all_poses += list(poses)
	pose_through(all_poses, time / steps)

/**
 * The strain, over [time]: the bearer leans back from his feet (seen from the side) with his arms out and steps back to
 * lean_out, hauling the arm up and out of its socket. The body is dragged in by it to where tg's grab draws it, and turns
 * up about its feet toward his fists, the feet staying on the floor; both fists on the wrist the whole way.
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/haul(time)
	var/lean_back = side_view() ? -GORILLA_RIP_LEAN_BACK : 0
	var/list/start_fist = bearer_shoulder_at(grip_side)
	var/grip_reach = sqrt((grip[1] - start_fist[1]) ** 2 + (grip[2] - start_fist[2]) ** 2)
	var/body_length = victim_rig.arm_reach(side)
	var/matrix/flat = matrix(victim.transform)
	raised = raise_toward(flat, grip)
	var/list/lean_from = lean.Copy()
	var/list/shift_from = body_shift.Copy()
	var/step_time = time / GORILLA_RIP_HAUL_STEPS
	var/list/all_poses = list()
	var/list/body_turns = list()
	var/list/leans = list()
	var/list/shifts = list()
	var/list/from = turns_now()
	for(var/i in 1 to GORILLA_RIP_HAUL_STEPS)
		// Sine in and out, the same for every part
		var/progress = (1 - cos(180 * i / GORILLA_RIP_HAUL_STEPS)) / 2
		lean = list(round(lean_from[1] + (lean_out[1] - lean_from[1]) * progress, 1), round(lean_from[2] + (lean_out[2] - lean_from[2]) * progress, 1))
		body_shift = list(round(shift_from[1] * (1 - progress), 1), round(shift_from[2] * (1 - progress), 1))
		victim_rig.base_transform = chrome_rig_turn_about_feet(flat, raised * progress)
		leans += list(lean)
		shifts += list(body_shift)
		body_turns += list(victim_rig.base_transform)
		var/matrix/bent = bearer_rig.bend_matrix(lean_back * progress)
		var/list/fist_from = bearer_shoulder_at(grip_side, bent)
		var/list/arm_from = body_shoulder_at()
		var/apart = sqrt((arm_from[1] - fist_from[1]) ** 2 + (arm_from[2] - fist_from[2]) ** 2)
		var/fist_reach = grip_reach
		// The arm gives as far as it must to stay in his fists
		var/arm_reach = clamp(max((grip_stretch + GORILLA_RIP_HAUL * progress) * body_length, apart - fist_reach + 1), body_length, GORILLA_RIP_MAX_HAUL * body_length)
		fist_reach = max(fist_reach, apart - arm_reach + 1)
		grip = gorilla_circles_meet(fist_from[1], fist_from[2], fist_reach, arm_from[1], arm_from[2], arm_reach, grip[1], grip[2])
		var/list/poses = poses_on(grip, from, bent)
		for(var/key_name in poses)
			var/list/pose = poses[key_name]
			from[key_name] = pose[1]
		all_poses += list(poses)
	pose_through(all_poses, step_time)
	victim_rig.body_through(body_turns, step_time)
	// He stays leaning back until the arm comes away
	bearer_rig.bend_angle = lean_back
	bearer_rig.base_transform = bearer_rig.bend_matrix(lean_back)
	// After the swings and turns, which would cut these short: he steps back and the body comes with him
	gorilla_offsets_through(bearer_rig.puppets, leans, user.pixel_x, user.pixel_y, step_time)
	gorilla_offsets_through(victim_rig.puppets, shifts, victim.pixel_x, victim.pixel_y, step_time)
	// Both bodies shake together, so the fists stay on the wrist
	bearer_rig.tremble(time)
	victim_rig.tremble(time)

/**
 * Degrees (clockwise) to turn the body lying as [flat] turns it about its feet as the arm is hauled toward [point] (pixels
 * from the middle of the bearer's tile). Seen from the side the upper body comes up off the floor, GORILLA_RIP_RAISE; from
 * the front or back it turns toward the fists, at most that.
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/raise_toward(matrix/flat, list/point)
	var/list/feet = chrome_rig_apply(flat, 0, CHROME_RIG_FEET_Y)
	var/list/shoulder_at = victim_rig.shoulder_point(side, flat)
	if(side_view())
		// Clockwise lifts a shoulder that lies to the left of the feet
		return shoulder_at[1] < feet[1] ? GORILLA_RIP_RAISE : -GORILLA_RIP_RAISE
	var/list/body_at = body_origin()
	var/turned = arctan(point[1] - body_at[1] - feet[1], point[2] - body_at[2] - feet[2]) - arctan(shoulder_at[1] - feet[1], shoulder_at[2] - feet[2])
	while(turned > 180)
		turned -= 360
	while(turned <= -180)
		turned += 360
	// Angles run anticlockwise, turns clockwise
	return -clamp(turned, -GORILLA_RIP_RAISE, GORILLA_RIP_RAISE)

/**
 * The arm gives: the body drops back flat from its turn about the feet, faster and faster, the arm falling back to its
 * side with it if it held. The real body shows once it is down.
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/fall_back()
	var/obj/effect/abstract/chrome_puppet/body_puppet = victim_rig?.puppet("body")
	if(!body_puppet || !raised || QDELETED(victim))
		QDEL_NULL(victim_rig)
		return
	var/matrix/flat = matrix(victim.transform)
	var/list/arm_from = victim_rig.puppet("arm_[side]") ? (victim_rig.arm_poses[side] || list(0, 1)) : null
	var/steps = 3
	if(arm_from)
		steps = max(steps, victim_rig.swing_steps(arm_from[1], 0))
	var/list/body_turns = list()
	var/list/arm_steps = list()
	for(var/i in 1 to steps)
		// Gravity: slow off the top, fast onto the floor
		var/progress = 1 - cos(90 * i / steps)
		var/matrix/turned = chrome_rig_turn_about_feet(flat, raised * (1 - progress))
		body_turns += list(turned)
		if(arm_from)
			arm_steps += list(list(arm_from[1] * (1 - progress), arm_from[2] + (1 - arm_from[2]) * progress, turned))
	victim_rig.body_through(body_turns, GORILLA_RIP_FALL_TIME / steps)
	if(arm_from)
		victim_rig.pose_arm_through(side, arm_steps, GORILLA_RIP_FALL_TIME / steps)
	raised = 0
	victim_rig.base_transform = flat
	addtimer(CALLBACK(src, PROC_REF(fallen)), GORILLA_RIP_FALL_TIME, TIMER_DELETE_ME)

/// The body is down after the arm gave: the real one shows in its place.
/datum/hv_finisher/chrome/gorilla/rip/proc/fallen()
	QDEL_NULL(victim_rig)

/**
 * The stand-ins take on how both bodies look now. With the arm [torn] off, the victim's whole picture is the body,
 * stump and all; else the arm is still its own piece.
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/redraw_bodies(torn)
	bearer_rig?.redraw_arms()
	if(QDELETED(victim) || !victim_rig?.snapshot())
		return
	victim_rig.repaint("body", torn ? victim_rig.flat : victim_rig.cut_without_arms(side))
	if(!torn)
		victim_rig.repaint("arm_[side]", victim_rig.arm_picture(side))

/// Blood bursts every way from the socket the arm just left, where the shoulder is drawn at that moment.
/datum/hv_finisher/chrome/gorilla/rip/proc/shoulder_burst()
	var/turf/spot = get_turf(victim)
	if(!isturf(spot))
		return
	var/list/joint
	if(victim_rig?.puppet("body"))
		// The stand-in's shoulder, hauled up off the floor: from the middle of the bearer's tile, so back onto the victim's
		var/list/at = body_shoulder_at()
		var/list/toward = to_bearer()
		joint = list(at[1] + toward[1], at[2] + toward[2])
	else
		joint = gorilla_shoulder_at(victim, side)
	gorilla_blood_burst(spot, round(joint[1]), round(joint[2]), victim, GORILLA_RIP_BURST_DROPS)

/**
 * Where the pool under the torn shoulder goes: pixels from the middle of the victim's tile. Half-way between where the
 * shoulder lies as the arm comes off, pulled in by the grab, and where it lies once he lets go, so the stump is over it
 * both times.
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/pool_spot()
	if(QDELETED(victim))
		return null
	var/list/joint = gorilla_shoulder_at(victim, side, victim_rig?.facing)
	// Off a body still on its feet it lands at them
	if(victim.body_position != LYING_DOWN)
		joint[2] = CHROME_RIG_FEET_Y + victim.pixel_y + victim.pixel_z
	var/list/back = grab_pull_back()
	return list(clamp(round(joint[1] + back[1] / 2), -GORILLA_RIP_POOL_REACH, GORILLA_RIP_POOL_REACH), clamp(round(joint[2] + back[2] / 2), -GORILLA_RIP_POOL_REACH, GORILLA_RIP_POOL_REACH))

/**
 * Where the shoulder on [side] ("l" or "r") of [body] is drawn, lying or standing as it is now: pixels from the middle of
 * its tile. [facing] is the way its picture faces, else its own.
 */
/proc/gorilla_shoulder_at(mob/living/body, side, facing)
	var/list/pivots = GLOB.chrome_rig_shoulders["[facing || body.dir]"] || GLOB.chrome_rig_shoulders["[SOUTH]"]
	var/list/at = chrome_rig_apply(body.transform, side == "l" ? pivots[1] : pivots[3], side == "l" ? pivots[2] : pivots[4])
	return list(at[1] + body.pixel_x + body.pixel_w, at[2] + body.pixel_y + body.pixel_z)

/**
 * Blood bursts from a wound at [from_x], [from_y] (pixels from the middle of [origin]) every way at once: [count] drops
 * of [bleeder]'s blood thrown in a broken ring, no two in a row alike, each landing as a drip one of [reach] pixels out,
 * give or take. Drops only: no line along the floor, as #509's sprays lay, and no heavy splats.
 */
/proc/gorilla_blood_burst(turf/origin, from_x, from_y, mob/living/bleeder, count = 10, list/reach = list(6, 9, 12, 15, 19))
	if(!isturf(origin) || QDELETED(bleeder) || bleeder.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	var/blood_color = bleeder.get_bloodtype()?.get_damage_color(bleeder) || BLOOD_COLOR_RED
	var/list/blood_dna = bleeder.get_blood_dna_list()
	var/list/viruses = bleeder.get_static_viruses()
	var/start = rand(0, 359)
	for(var/i in 1 to count)
		var/angle = start + i * (360 / count) + rand(-14, 14)
		var/distance = pick(reach) + rand(-2, 2)
		var/land_x = from_x + round(sin(angle) * distance)
		var/land_y = from_y + round(cos(angle) * distance)
		// list(start x, start y, land x, land y, arc height, flight time, wait): the monowire's drop, which lands as a drip
		new /obj/effect/temp_visual/wire_blood_drop(origin, list(from_x, from_y, land_x, land_y, 3 + rand(0, 5), round(1.5 + distance / 14, 0.5), 0), blood_color, blood_dna, viruses)

/**
 * Moves [pool] (blood just laid on the floor) so its middle is [x], [y] pixels from the middle of its tile, and keeps it
 * there as it grows into a pool.
 */
/proc/gorilla_place_blood(obj/effect/decal/cleanable/blood/pool, x, y)
	pool.pixel_x += x - pool.base_pixel_x
	pool.pixel_y += y - pool.base_pixel_y
	pool.base_pixel_x = x
	pool.base_pixel_y = y

/**
 * [body] shudders up to [shift_x], [shift_y] pixels for [time] and ends where it began. Drawn only (pixel_w and pixel_z,
 * each step relative), so whatever offsets tg has on the body stay as they are.
 */
/proc/gorilla_shudder(atom/movable/body, shift_x = 2, shift_y = 1, time = 0.2 SECONDS)
	var/steps = max(2, round(time / (0.04 SECONDS)))
	var/moved_w = 0
	var/moved_z = 0
	for(var/i in 1 to steps)
		// The last step takes it back
		var/to_w = i == steps ? 0 : rand(-shift_x, shift_x)
		var/to_z = i == steps ? 0 : rand(-shift_y, shift_y)
		if(i == 1)
			animate(body, pixel_w = to_w - moved_w, pixel_z = to_z - moved_z, time = time / steps, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
		else
			animate(pixel_w = to_w - moved_w, pixel_z = to_z - moved_z, time = time / steps, flags = ANIMATION_RELATIVE)
		moved_w = to_w
		moved_z = to_z

/// Sends every puppet in [parts] (key -> puppet) through [points] (list(x, y) pixels on from [base_x], [base_y]), [step_time] a step, alongside its turns.
/proc/gorilla_offsets_through(list/parts, list/points, base_x, base_y, step_time)
	for(var/key_name in parts)
		var/obj/effect/abstract/chrome_puppet/part = parts[key_name]
		for(var/i in 1 to length(points))
			var/list/point = points[i]
			if(i == 1)
				animate(part, pixel_x = base_x + point[1], pixel_y = base_y + point[2], time = step_time, flags = ANIMATION_PARALLEL)
			else
				animate(pixel_x = base_x + point[1], pixel_y = base_y + point[2], time = step_time)

/**
 * The point [first_radius] from [first_x], [first_y] and [second_radius] from [second_x], [second_y] nearest
 * [near_x], [near_y]. If the two never meet, the point [first_radius] along the line between them.
 */
/proc/gorilla_circles_meet(first_x, first_y, first_radius, second_x, second_y, second_radius, near_x, near_y)
	var/apart_x = second_x - first_x
	var/apart_y = second_y - first_y
	var/apart = sqrt(apart_x * apart_x + apart_y * apart_y)
	if(!apart)
		return list(first_x, first_y)
	apart_x /= apart
	apart_y /= apart
	if(first_radius + second_radius <= apart || abs(first_radius - second_radius) >= apart)
		return list(first_x + apart_x * first_radius, first_y + apart_y * first_radius)
	var/along = (apart * apart + first_radius * first_radius - second_radius * second_radius) / (2 * apart)
	var/aside = sqrt(max(0, first_radius * first_radius - along * along))
	var/list/one = list(first_x + apart_x * along - apart_y * aside, first_y + apart_y * along + apart_x * aside)
	var/list/two = list(first_x + apart_x * along + apart_y * aside, first_y + apart_y * along - apart_x * aside)
	if((one[1] - near_x) ** 2 + (one[2] - near_y) ** 2 <= (two[1] - near_x) ** 2 + (two[2] - near_y) ** 2)
		return one
	return two

/// How far along the line from [from_x], [from_y] heading [angle] degrees it first meets the circle of [radius] round [round_x], [round_y], or null.
/proc/gorilla_ray_meets(from_x, from_y, angle, round_x, round_y, radius)
	var/off_x = from_x - round_x
	var/off_y = from_y - round_y
	var/half_b = off_x * cos(angle) + off_y * sin(angle)
	var/c = off_x * off_x + off_y * off_y - radius * radius
	var/disc = half_b * half_b - c
	if(disc < 0)
		return null
	var/root = sqrt(disc)
	if(-half_b - root >= 0)
		return -half_b - root
	if(-half_b + root >= 0)
		return -half_b + root
	return null

/datum/hv_finisher/chrome/gorilla/rip/beat(key)
	if(QDELETED(victim))
		return
	switch(key)
		if("tear")
			hit_stop(victim_rig?.puppet("arm_[side]") || victim)
			var/outcome = gorilla_limb_rip(victim, target_zone, user, fist(), pool_spot())
			// Both bodies are hidden behind their stand-ins, and so is what this just did to them (the stump, the blood
			// that ran back over him): the stand-ins take it on now, or it would only show when they come down
			redraw_bodies(outcome == "torn")
			if(outcome == "torn")
				held_limb = gorilla_last_torn_limb(victim, target_zone)
				if(held_limb?.can_bleed())
					shoulder_burst()
				// The arm goes with the bearer's fists; the body drops back to the floor
				var/obj/effect/abstract/chrome_puppet/arm = victim_rig?.puppet("arm_[side]")
				if(arm && bearer_rig)
					var/list/arm_shoulder = victim_rig.shoulder(side)
					var/list/arm_hand = victim_rig.hand_offset(side)
					club_ends = list(arm_shoulder[1] + arm_hand[1], arm_shoulder[2] + arm_hand[2], arm_shoulder[1], arm_shoulder[2])
					victim_rig.puppets -= "arm_[side]"
					bearer_rig.puppets["club"] = arm
					// Drawn where it was, from the bearer's tile
					var/list/toward = to_bearer()
					arm.pixel_x -= toward[1]
					arm.pixel_y -= toward[2]
					arm.forceMove(get_turf(user))
					arm.layer = user.layer + 0.03
					if(grip)
						// ...and yanked back with the fist that held it
						var/list/fist_at = bearer_rig.hand_point(grip_side)
						var/list/origin = bearer_origin()
						animate(arm, pixel_x = arm.pixel_x + round(origin[1] + fist_at[1] - grip[1]), pixel_y = arm.pixel_y + round(origin[2] + fist_at[2] - grip[2]), time = 0.1 SECONDS, easing = SINE_EASING)
					else
						arm.pixel_x = 0
						arm.pixel_y = 0
						arm.pixel_z = 6
						arm.transform = matrix().Turn(100)
				for(var/key_name in bearer_rig?.puppets)
					var/obj/effect/abstract/chrome_puppet/part = bearer_rig.puppets[key_name]
					animate(part, pixel_w = -2, time = 0.1 SECONDS, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
					animate(pixel_w = 2, time = 0.3 SECONDS, flags = ANIMATION_RELATIVE)
			// It drops back to the floor as the arm gives
			fall_back()

/// The middle of the victim's head as drawn, lying or not: pixels from the middle of the bearer's tile.
/datum/hv_finisher/chrome/gorilla/rip/proc/victim_head_at()
	var/list/head = chrome_rig_apply(victim.transform, 0, CHROME_RIG_NECK_PIVOT_Y + 3.5)
	return list((victim.x - user.x) * ICON_SIZE_X + victim.pixel_x + victim.pixel_w + head[1], (victim.y - user.y) * ICON_SIZE_Y + victim.pixel_y + victim.pixel_z + head[2])

/// The torn arm's length in its own picture, hand to shoulder.
/datum/hv_finisher/chrome/gorilla/rip/proc/club_length()
	return sqrt((club_ends[3] - club_ends[1]) ** 2 + (club_ends[4] - club_ends[2]) ** 2)

/**
 * The torn arm held by its hand at [fist_x], [fist_y] (pixels from the middle of the bearer's puppets), its shoulder
 * end pointing [angle] degrees round from the right (anticlockwise), [stretch] times its length.
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/club_matrix(fist_x, fist_y, angle, stretch = 1)
	var/along = arctan(club_ends[3] - club_ends[1], club_ends[4] - club_ends[2])
	return chrome_rig_turn(along - angle, club_ends[1], club_ends[2], fist_x - club_ends[1], fist_y - club_ends[2], 1, stretch)

/// The degrees from [from_angle] to [to_angle], turning the way [arm_turned] went (anticlockwise positive) when they are far apart.
/proc/gorilla_turn_with(from_angle, to_angle, arm_turned)
	var/turned = to_angle - from_angle
	while(turned > 180)
		turned -= 360
	while(turned <= -180)
		turned += 360
	if(abs(arm_turned) > 90 && turned * arm_turned < 0)
		turned += arm_turned > 0 ? 360 : -360
	return turned

/**
 * The blow with the torn arm: both fists swing it up over his head in [raise], then bring it down on the victim's
 * head in [strike], so it lands as the arms come down. The arm in his fists goes through the same short steps as
 * his arms, held by its hand in the fist that tore it off.
 */
/datum/hv_finisher/chrome/gorilla/rip/proc/swing_club(raise, strike)
	if(!bearer_rig)
		return
	var/obj/effect/abstract/chrome_puppet/club = club_ends ? bearer_rig.puppet("club") : null
	var/holding = grip_side || bearer_rig.near_side()
	var/list/origin = bearer_origin()
	// The blow comes down from his shoulders onto the head; the fists go out as far along it as the arm in them doesn't
	var/list/head = victim_head_at()
	var/list/left = bearer_rig.shoulder("l")
	var/list/right = bearer_rig.shoulder("r")
	var/from_x = (left[1] + right[1]) / 2
	var/from_y = (left[2] + right[2]) / 2
	var/to_x = head[1] - origin[1] - from_x
	var/to_y = head[2] - origin[2] - from_y
	var/apart = sqrt(to_x * to_x + to_y * to_y)
	var/blow_angle = arctan(to_x, to_y)
	var/held_length = club ? club_length() : 0
	var/fist_along = clamp(apart - held_length, 0, GORILLA_CLUB_REACH * bearer_rig.arm_reach(holding))
	var/blow_stretch = held_length ? clamp((apart - fist_along) / held_length, 1, GORILLA_CLUB_MAX_STRETCH) : 1
	var/fist_x = from_x + fist_along * cos(blow_angle)
	var/fist_y = from_y + fist_along * sin(blow_angle)
	// Overhead: seen from the side up and back, the arm hanging back over his head; from the front straight up; from
	// behind with his fists down behind his head, the arm down his back
	var/club_up
	var/list/poses_now = list()
	var/list/poses_up = list()
	var/list/poses_down = list()
	for(var/arm_side in list("l", "r"))
		poses_now[arm_side] = bearer_rig.arm_poses[arm_side] || list(0, 1)
		var/list/up
		if(side_view())
			up = list(200 * bearer_rig.raise_sign(arm_side), 1.2)
			club_up = facing == EAST ? 145 : 35
		else if(facing == NORTH)
			up = list(170 * bearer_rig.raise_sign(arm_side), 0.6)
			club_up = -90
		else
			up = list(170 * bearer_rig.raise_sign(arm_side), 1.1)
			club_up = 90
		poses_up[arm_side] = up
		var/list/down = bearer_rig.pose_reaching(arm_side, fist_x, fist_y, up[1])
		down[2] = min(down[2], GORILLA_CLUB_REACH)
		poses_down[arm_side] = down
	// Every arm goes through the same steps: sine up, then faster and faster down
	var/up_steps = 1
	var/down_steps = 1
	for(var/arm_side in list("l", "r"))
		var/list/now = poses_now[arm_side]
		var/list/up = poses_up[arm_side]
		var/list/down = poses_down[arm_side]
		up_steps = max(up_steps, bearer_rig.swing_steps(now[1], up[1]))
		down_steps = max(down_steps, bearer_rig.swing_steps(up[1], down[1]))
	var/list/progress = list()
	var/list/step_times = list()
	for(var/i in 1 to up_steps)
		progress += (1 - cos(180 * i / up_steps)) / 2
		step_times += raise / up_steps
	for(var/i in 1 to down_steps)
		progress += 1 - cos(90 * i / down_steps)
		step_times += strike / down_steps
	var/list/arm_steps = list("l" = list(), "r" = list())
	for(var/i in 1 to length(progress))
		var/rising = i <= up_steps
		for(var/arm_side in list("l", "r"))
			var/list/was = rising ? poses_now[arm_side] : poses_up[arm_side]
			var/list/will = rising ? poses_up[arm_side] : poses_down[arm_side]
			arm_steps[arm_side] += list(list(was[1] + (will[1] - was[1]) * progress[i], was[2] + (will[2] - was[2]) * progress[i]))
	for(var/arm_side in arm_steps)
		bearer_rig.pose_arm_through(arm_side, arm_steps[arm_side], step_times)
	if(!club)
		return
	// The torn arm turns the way the arm holding it does, from where it hangs in the fist now
	var/matrix/drawn = club.transform
	var/list/hand_now = chrome_rig_apply(drawn, club_ends[1], club_ends[2])
	var/list/stump_now = chrome_rig_apply(drawn, club_ends[3], club_ends[4])
	var/club_now = arctan(stump_now[1] - hand_now[1], stump_now[2] - hand_now[2])
	var/stretch_now = held_length ? sqrt((stump_now[1] - hand_now[1]) ** 2 + (stump_now[2] - hand_now[2]) ** 2) / held_length : 1
	var/list/hold_now = poses_now[holding]
	var/list/hold_up = poses_up[holding]
	var/list/hold_down = poses_down[holding]
	// Arm turns are clockwise, the arm's angles anticlockwise
	var/turn_up = gorilla_turn_with(club_now, club_up, hold_now[1] - hold_up[1])
	var/turn_down = gorilla_turn_with(club_now + turn_up, blow_angle, hold_up[1] - hold_down[1])
	var/obj/effect/abstract/chrome_puppet/holding_arm = bearer_rig.puppet("arm_[holding]")
	var/list/held_steps = arm_steps[holding]
	for(var/i in 1 to length(held_steps))
		var/rising = i <= up_steps
		var/list/fist = bearer_rig.hand_at(holding, held_steps[i])
		var/angle = rising ? club_now + turn_up * progress[i] : club_now + turn_up + turn_down * progress[i]
		var/stretch = rising ? stretch_now + (1 - stretch_now) * progress[i] : 1 + (blow_stretch - 1) * progress[i]
		var/matrix/held = club_matrix(fist[1], fist[2], angle, stretch)
		if(i == 1)
			animate(club, transform = held, pixel_x = holding_arm?.pixel_x || 0, pixel_y = holding_arm?.pixel_y || 0, pixel_w = 0, pixel_z = holding_arm?.pixel_z || 0, time = step_times[i])
		else
			animate(transform = held, time = step_times[i])

/// The torn arm lands on the victim's head.
/datum/hv_finisher/chrome/gorilla/rip/proc/club_hit()
	if(!running || QDELETED(victim) || !held_limb)
		return
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	victim.hv_hold_attack_message("[user] beats [victim] with [victim.p_their()] own arm!", "[user] beats you with your own arm!", "You beat [victim] with [victim.p_their()] own arm!", user, vision_range = DEFAULT_MESSAGE_RANGE)
	// None of #509's heavy-hit spray for this blow: its fan lands a tile out past the body, nowhere near the head
	gorilla_hold_spray(victim)
	victim.apply_damage(15, BRUTE, head || BODY_ZONE_CHEST, victim.run_armor_check(head, MELEE), wound_bonus = CANT_WOUND, attack_direction = get_dir(user, victim), attacking_item = fist())
	victim.hv_flush_hit()
	playsound(victim, 'sound/effects/wounds/splatter.ogg', 60, TRUE)
	var/obj/effect/abstract/cyberware_anim/impact = gorilla_play_impact(user, victim, "impact_gorilla")
	if(impact)
		// On the head, where the arm lands. It rides on the body, so its offset turns with a lying one: up is the head.
		impact.pixel_y += round(CHROME_RIG_NECK_PIVOT_Y + 3.5)
	// Not tg's Shake(): its first step takes pixel_y from pixel_x, which throws a body pulled in by a grab a third of a
	// tile aside for a frame
	gorilla_shudder(victim, 2, 1, 0.2 SECONDS)
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
		// What still runs out of it as it lands: a drip, into the pool from the tear where there is one. Not a fresh
		// splash on the body's tile a second after the wound
		if(limb.can_bleed())
			if(!QDELETED(victim) && get_turf(victim) == spot)
				victim.add_splatter_floor(spot, TRUE)
			else
				new /obj/effect/decal/cleanable/blood/drip(spot, null, limb.blood_dna_info)

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
 * "dislocated" or "held". [blood_at] (list(x, y) pixels from the middle of the victim's tile) is where
 * the blood the torn shoulder puts on the floor goes; the middle of the tile without it.
 */
/proc/gorilla_limb_rip(mob/living/carbon/victim, zone, mob/living/user, obj/item/fist, list/blood_at)
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
	var/obj/item/bodypart/torn = gorilla_tear_limb(victim, limb, toward_bearer, TRUE, blood_at)
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
 * floor splatter, the wet stump and the spray along the last blow), but never flings it: with [keep_out]
 * it is kept out of the world for the finisher to hold, else it is left on the victim's tile. Fresh blood
 * it puts on the floor goes [blood_at] (list(x, y) pixels from the middle of the tile), under the wound, if
 * given; blood already on the tile stays where it is. Returns the limb or null.
 */
/proc/gorilla_tear_limb(mob/living/carbon/victim, obj/item/bodypart/limb, direction, keep_out = TRUE, list/blood_at)
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
	var/turf/spot = get_turf(victim)
	var/list/old_blood = list()
	if(blood_at && isturf(spot))
		for(var/obj/effect/decal/cleanable/blood/there in spot)
			old_blood += there
	if(bleeds)
		victim.bleed(rand(20, 40))
	limb.drop_limb(FALSE, TRUE)
	victim.update_equipment_speed_mods()
	if(bleeds && isturf(spot))
		victim.add_splatter_floor(spot)
		if(blood_at)
			// tg lays it on the middle of the tile, which a body held in a grab is drawn well off
			for(var/obj/effect/decal/cleanable/blood/pool in spot)
				if(pool.type == /obj/effect/decal/cleanable/blood && !(pool in old_blood) && !QDELETED(pool))
					gorilla_place_blood(pool, blood_at[1], blood_at[2])
	if(QDELETED(limb))
		return null
	if(keep_out)
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
			// It lands in front of him, toward the viewer, where he doesn't hide it (owner): the real body too, for when the halves come down
			if(get_turf(victim) == knee)
				victim.AddComponent(/datum/component/gorilla_laid_in_front)
			// The halves lie head east (turned 90). tg turns a lying body to the way it last crawled, so the move
			// above can leave it head west: lay it as the halves are, or it flips over when they come down.
			if(victim.body_position == LYING_DOWN)
				victim.set_lying_angle(LYING_ANGLE_EAST)
			// Still bent if the back broke. A broken back hangs folded over the knee for a moment first. The
			// halves turn about the belt, seven pixels under the middle, so they sit a pixel up to lie where a
			// lying body lies.
			var/bend = broke ? 33 : 0
			var/hold = broke ? GORILLA_BACK_FOLD_HOLD : 0
			var/obj/effect/abstract/chrome_puppet/upper = victim_rig?.puppet("upper")
			var/obj/effect/abstract/chrome_puppet/lower = victim_rig?.puppet("lower")
			if(upper)
				animate(upper, transform = chrome_rig_turn(90 + (broke ? 38 : 0), 0, BACK_WAIST_PIVOT_Y), time = hold)
				animate(pixel_x = 0, pixel_y = 1 - GORILLA_BACK_IN_FRONT, pixel_z = 0, transform = chrome_rig_turn(90 + bend, 0, BACK_WAIST_PIVOT_Y), time = 0.45 SECONDS, easing = SINE_EASING | EASE_IN | EASE_OUT)
			if(lower)
				animate(lower, transform = chrome_rig_turn(90 - (broke ? 38 : 0), 0, BACK_WAIST_PIVOT_Y), time = hold)
				animate(pixel_x = 0, pixel_y = 1 - GORILLA_BACK_IN_FRONT, pixel_z = 0, transform = chrome_rig_turn(90 - bend, 0, BACK_WAIST_PIVOT_Y), time = 0.45 SECONDS, easing = SINE_EASING | EASE_IN | EASE_OUT)
			// No blood of the move's own where he lands (owner): a broken back doesn't bleed, and a pool on the middle
			// of the tile never lined up with a body laid in front of it. What the body really bleeds is tg's.
			// The halves stay drawn over him (user.layer + 0.05, from the hoist) while they lie there

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
	// What the blow did to the body (the snapped bone, tg's wounds) is drawn on the hidden one: the halves take it on
	// now, or it would only show when they come down
	if(!QDELETED(victim) && victim_rig?.snapshot())
		for(var/half in list("upper", "lower"))
			victim_rig.repaint(half, victim_rig.cut("rig_[half]"))
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

/datum/hv_finisher/chrome/gorilla/backbreaker/cleanup_rigs()
	// A broken back stays drawn bent for a while after
	if(broke && victim_rig && !QDELETED(victim) && victim.get_bodypart(BODY_ZONE_CHEST))
		victim.AddComponent(/datum/component/gorilla_fold, victim_rig)
		victim_rig = null
	return ..()

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
 * the body is moved, buckled or the back is set. Left alone, it eases out flat when its time is up, to lie as
 * the real body does, which then shows in its place.
 */
/datum/component/gorilla_fold
	/// The victim's rig, handed over by the finisher
	var/datum/chrome_rig/rig
	var/fold_timer

/datum/component/gorilla_fold/Initialize(datum/chrome_rig/rig)
	if(!iscarbon(parent) || !istype(rig))
		return COMPONENT_INCOMPATIBLE
	src.rig = rig
	fold_timer = addtimer(CALLBACK(src, PROC_REF(settle)), GORILLA_FOLD_TIME, TIMER_STOPPABLE)

/// The fold's time is up: the halves ease out flat, where the real body lies, and it shows once they are.
/datum/component/gorilla_fold/proc/settle()
	for(var/half in list("upper", "lower"))
		var/obj/effect/abstract/chrome_puppet/part = rig?.puppet(half)
		if(part)
			animate(part, transform = chrome_rig_turn(90, 0, BACK_WAIST_PIVOT_Y), time = GORILLA_FOLD_SETTLE, easing = SINE_EASING)
	fold_timer = QDEL_IN_STOPPABLE(src, GORILLA_FOLD_SETTLE)

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

/**
 * A body the backbreaker dropped on the bearer's own tile, drawn [GORILLA_BACK_IN_FRONT] pixels toward the viewer so
 * the one standing over it doesn't hide it. Comes off when it is moved, strapped in or gets up.
 *
 * It lies where its halves were laid. They turn about the belt, which is under the middle of the picture, so they lie
 * that many pixels along toward the head from where tg draws a lying body (turned about its middle): the real body is
 * drawn as far along, or it would jump back when the halves come down.
 */
/datum/component/gorilla_laid_in_front

/datum/component/gorilla_laid_in_front/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/body = parent
	body.add_offsets(GORILLA_LAID_IN_FRONT_OFFSET, x_add = -BACK_WAIST_PIVOT_Y, y_add = -GORILLA_BACK_IN_FRONT, animate = FALSE)

/datum/component/gorilla_laid_in_front/RegisterWithParent()
	RegisterSignals(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BUCKLED, COMSIG_LIVING_SET_BODY_POSITION), PROC_REF(moved_off))

/datum/component/gorilla_laid_in_front/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BUCKLED, COMSIG_LIVING_SET_BODY_POSITION))
	var/mob/living/body = parent
	body.remove_offsets(GORILLA_LAID_IN_FRONT_OFFSET)

/datum/component/gorilla_laid_in_front/proc/moved_off(datum/source)
	SIGNAL_HANDLER
	qdel(src)

#undef BACK_WAIST_PIVOT_Y
