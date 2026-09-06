/**
 * # The Silent Dojo: space ninja vestige
 *
 * A Spider Clan training hall drifting cold, mats still swept. The master's
 * suit still kneels at the head of the room; the master, as far as anyone can
 * tell, is not in it. Trials are lessons, the thrown star (precision), the
 * unseen hand (silence), stillness (reading a threat). Ninja kit is pure gear (zero
 * antag coupling), so the boons are the clan's own kit and drills: the blade
 * (its dash action rides the item and grants on equip, verified upstream), a
 * finite case of true stars, and smoke/footwork techniques built as
 * standalone spells, every upstream ninja ABILITY lives on the MOD suit's
 * modules and checks mod.wearer (modules_ninja.dm), so none of those port;
 * the techniques here are local reimplementations.
 */

// Stars the clan hands over before it makes you wait. Keep the boon desc's
// "three" in sync, initial() values must be compile-time constant, so no
// interpolation there.
#define VESTIGE_CLAN_STAR_CHARGES 3
// How long the clan takes to hand over another three
#define VESTIGE_CLAN_STAR_RECHARGE (60 SECONDS)
// The beat between drawing one star and the next
#define VESTIGE_CLAN_STAR_DRAW (1 SECONDS)
// ===== PATRON =====

/mob/living/basic/vestige_patron/hollow_master
	name = "the Hollow Master"
	desc = "A ninja shozoku kneeling in perfect seiza. The posture is flawless. The suit is, by every instrument you have, empty."
	gender = NEUTER
	outfit_path = /datum/outfit/ninja
	appearance_tint = "#3c3c50"
	trial_types = list(
		/datum/vestige_trial/thrown_star,
		/datum/vestige_trial/unseen_hand,
		/datum/vestige_trial/stillness,
	)
	boon_types = list(
		/datum/vestige_boon/item/master_blade,
		/datum/vestige_boon/spell/clan_stars,
		/datum/vestige_boon/spell/veiling_smoke,
		/datum/vestige_boon/spell/veiling_smoke/vanishing,
		/datum/vestige_boon/spell/soundless_step,
		/datum/vestige_boon/spell/soundless_step/weightless,
	)
	idle_lines = list(
		"You're looking for the master. The master is looking back. Don't ask from where.",
		"Every student asks about the blade first. The blade is the last lesson. The first one is the walk back to pick up what you threw.",
		"This hall has heard ten thousand footsteps. Yours are the loudest so far. We'll work on that.",
		"The suit isn't empty. It's exactly as full as it needs to be.",
		"Stillness means knowing which blade is a lie, and which one is coming for your knees.",
		"My best students are the ones you don't remember meeting.",
	)
	accept_line = "Begin. The lesson doesn't care how good you think you are."
	busy_line = "You've got someone else's lesson half-finished. Go and finish that one first."
	fulfilled_line = "You've finished that one. Repeating it past mastery is just vanity."
	renounce_line = "The door is where you left it. So is mediocrity."
	claim_line = "Your lesson is paid for. Take it before you ask for the next."
	exhausted_line = "I've nothing left to teach you but patience, and you'd only throw it at someone."
	remember_line = "You died. Sloppy. Your training kept, at least - death doesn't clean that out."

// ===== PORTABLE FIELD LESSONS =====

/**
 * Generic basic AI supplies neither facing-based perception nor attack feints.
 * These scoped projections implement visible exercises, with real Move() and
 * can_see() checks. Their whole five-by-five footprint is checked at deployment.
 */
/datum/vestige_trial/field_encounter
	var/obj/item/vestige_field_manual/manual
	var/datum/weakref/field_center
	var/list/field_nodes = list()
	var/obj/structure/vestige_field_node/actor
	var/patrol_corner = 1
	var/next_step = 0
	var/suspicion = 0
	var/actor_steps = 0

/datum/vestige_trial/field_encounter/on_accepted(mob/living/user)
	manual = hand_over(user, new /obj/item/vestige_field_manual(get_turf(user)))
	manual.trial_ref = WEAKREF(src)

/datum/vestige_trial/field_encounter/Destroy()
	clear_field()
	QDEL_NULL(manual)
	return ..()

/datum/vestige_trial/field_encounter/proc/clear_field()
	for(var/obj/structure/vestige_field_node/node as anything in field_nodes)
		qdel(node)
	field_nodes.Cut()
	actor = null
	field_center = null
	suspicion = 0

/datum/vestige_trial/field_encounter/proc/deploy(mob/living/user)
	var/turf/center = get_turf(user)
	if(user != owner?.current || user.stat != CONSCIOUS || !isturf(user.loc))
		return FALSE
	if(field_center)
		clear_field()
		to_chat(user, span_notice("The field folds away. Activate the manual again to restart the exercise."))
		return FALSE
	for(var/offset_x in -2 to 2)
		for(var/offset_y in -2 to 2)
			var/turf/spot = locate(center.x + offset_x, center.y + offset_y, center.z)
			if(!isopenturf(spot) || isspaceturf(spot) || islava(spot) || ischasm(spot) || spot.is_blocked_turf(exclude_mobs = TRUE))
				to_chat(user, span_warning("The projection needs a clear five-by-five patch of ground, centered on you. Remove dense objects or choose another site."))
				return FALSE
	field_center = WEAKREF(center)
	patrol_corner = 2
	actor_steps = 0
	next_step = world.time + 3 SECONDS
	setup_field(center, user)
	refresh_tracker()
	return TRUE

/datum/vestige_trial/field_encounter/proc/add_node(turf/spot, label, node_tag = 0)
	var/obj/structure/vestige_field_node/node = new(spot)
	register_loan(node)
	node.name = label
	node.field_tag = node_tag
	node.trial_ref = WEAKREF(src)
	field_nodes += node
	return node

/datum/vestige_trial/field_encounter/proc/setup_field(turf/center, mob/living/user)
	return

/datum/vestige_trial/field_encounter/proc/field_tick(mob/living/user, seconds_per_tick)
	return

/datum/vestige_trial/field_encounter/proc/field_abandoned()
	return

/datum/vestige_trial/field_encounter/proc/field_interact(obj/structure/vestige_field_node/node, mob/living/user)
	return

/datum/vestige_trial/field_encounter/proc/corner_turf(index)
	var/turf/center = field_center?.resolve()
	if(!center)
		return null
	switch(index)
		if(1)
			return locate(center.x - 2, center.y - 2, center.z)
		if(2)
			return locate(center.x - 2, center.y + 2, center.z)
		if(3)
			return locate(center.x + 2, center.y + 2, center.z)
		if(4)
			return locate(center.x + 2, center.y - 2, center.z)

/// One tile per second, with three-second corner pauses. Blocking it earns nothing.
/datum/vestige_trial/field_encounter/proc/patrol()
	if(QDELETED(actor) || world.time < next_step)
		return
	var/turf/destination = corner_turf(patrol_corner)
	if(!destination)
		return
	if(get_turf(actor) == destination)
		patrol_corner = (patrol_corner % 4) + 1
		next_step = world.time + 3 SECONDS
		actor.setDir(get_dir(actor, corner_turf(patrol_corner)))
		actor.balloon_alert(owner?.current, "looks [dir2text(actor.dir)]")
	else
		if(step_towards(actor, destination))
			actor_steps++
		next_step = world.time + 1 SECONDS

/// Forward cone: cover and distance defeat it; darkness alone does not.
/datum/vestige_trial/field_encounter/proc/in_sight(mob/living/user)
	return !QDELETED(actor) && get_dist(actor, user) <= 4 && is_source_facing_target(actor, user) && can_see(actor, user, 4)

/obj/item/vestige_field_manual
	name = "folding lesson manual"
	desc = "Activate on a clear five-by-five patch of ground to project your lesson. Activating again folds the field away and resets its progress. Projections disappear when the pact ends."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper_talisman"
	w_class = WEIGHT_CLASS_SMALL
	var/datum/weakref/trial_ref

/obj/item/vestige_field_manual/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSfastprocess, src)

/obj/item/vestige_field_manual/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	trial_ref = null
	return ..()

/obj/item/vestige_field_manual/attack_self(mob/living/user, list/modifiers)
	var/datum/vestige_trial/field_encounter/trial = trial_ref?.resolve()
	if(trial && user.mind?.active_vestige_trial == trial)
		trial.deploy(user)

/obj/item/vestige_field_manual/process(seconds_per_tick)
	var/datum/vestige_trial/field_encounter/trial = trial_ref?.resolve()
	var/mob/living/user = trial?.owner?.current
	var/turf/center = trial?.field_center?.resolve()
	if(!trial || !center)
		return
	if(!isliving(user) || user.stat != CONSCIOUS || !isturf(user.loc) || get_dist(user, center) > 7 || user.z != center.z)
		trial.field_abandoned()
		return
	trial.field_tick(user, seconds_per_tick)

/obj/structure/vestige_field_node
	name = "lesson projection"
	desc = "A temporary projection. The pact tracker explains this exercise's rules."
	icon = 'icons/obj/ore.dmi'
	icon_state = "bluespace_crystal"
	color = "#ad8de0"
	anchored = TRUE
	density = FALSE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	var/datum/weakref/trial_ref
	var/field_tag = 0
	var/lit = FALSE
	var/show_facing = FALSE
	maptext_width = 96
	maptext_x = -16
	maptext_y = 24

/obj/structure/vestige_field_node/setDir(newdir)
	. = ..()
	if(show_facing)
		maptext = MAPTEXT("<span style='color: white;'>[uppertext(dir2text(dir))]</span>")

/obj/structure/vestige_field_node/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	var/datum/vestige_trial/field_encounter/trial = trial_ref?.resolve()
	if(trial && user.mind?.active_vestige_trial == trial && user.stat == CONSCIOUS && user.Adjacent(src))
		trial.field_interact(src, user)

/obj/structure/vestige_field_node/proc/light_state(new_state)
	if(lit == new_state)
		return
	lit = new_state
	color = lit ? "#ffe6a0" : "#352849"
	set_light(lit ? 2 : 0, 1, "#ffe6a0")

// ===== TRIAL OF THE THROWN STAR =====

/datum/vestige_trial/thrown_star
	parent_type = /datum/vestige_trial/field_encounter
	name = "Trial of the Thrown Star"
	desc = "Deploy the lesson on a clear five-by-five patch of ground. Strike the patrolling shield target from at least three tiles away, behind its facing. Land one throw from each of three different sides of the field: north, south, east or west. It must travel two tiles between hits. Click the central focus empty-handed to recall a grounded star. The target pauses at corners; aim where it will be."
	var/list/firing_sides = list()
	var/obj/item/throwing_star/vestige_training/star
	var/last_strike_step = 0

/datum/vestige_trial/thrown_star/on_accepted(mob/living/user)
	..()
	star = hand_over(user, new /obj/item/throwing_star/vestige_training(get_turf(user)))

/datum/vestige_trial/thrown_star/Destroy()
	QDEL_NULL(star)
	return ..()

/datum/vestige_trial/thrown_star/setup_field(turf/center, mob/living/user)
	firing_sides.Cut()
	last_strike_step = 0
	actor = add_node(corner_turf(1), "patrolling shield target")
	actor.show_facing = TRUE
	actor.density = TRUE
	actor.icon = 'icons/mob/silicon/aibots.dmi'
	actor.icon_state = "cleanbot0"
	actor.setDir(NORTH)
	add_node(center, "star recall focus")

/datum/vestige_trial/thrown_star/field_tick(mob/living/user, seconds_per_tick)
	patrol()

/datum/vestige_trial/thrown_star/get_progress_text()
	return "Clean firing sides: [length(firing_sides)]/3. Used: [length(firing_sides) ? english_list(firing_sides) : "none"]."

/datum/vestige_trial/thrown_star/proc/strike(atom/hit, datum/thrownthing/flight)
	var/turf/center = field_center?.resolve()
	if(hit != actor || !center || flight?.get_thrower() != owner?.current || get_dist(flight.starting_turf, actor) < 3)
		return FALSE
	if(actor_steps - last_strike_step < 2)
		actor.balloon_alert(owner.current, "target must travel between hits!")
		return FALSE
	if(is_source_facing_target(actor, flight.starting_turf))
		actor.balloon_alert(owner.current, "shield blocked it!")
		return FALSE
	var/delta_x = flight.starting_turf.x - center.x
	var/delta_y = flight.starting_turf.y - center.y
	var/side = abs(delta_x) > abs(delta_y) ? (delta_x > 0 ? "east" : "west") : (delta_y > 0 ? "north" : "south")
	if(side in firing_sides)
		actor.balloon_alert(owner.current, "change firing side!")
		return FALSE
	firing_sides += side
	last_strike_step = actor_steps
	actor.balloon_alert(owner.current, "clean [side] strike")
	refresh_tracker()
	if(length(firing_sides) >= 3)
		complete()
	return TRUE

/obj/item/throwing_star/vestige_training
	name = "training star"
	desc = "A harmless, non-embedding star. It judges only the loaned shield target. Click the central focus empty-handed to recall it after a throw."
	force = 0
	throwforce = 0
	armour_penetration = 0
	sharpness = NONE
	embed_type = null

/obj/item/throwing_star/vestige_training/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	. = ..()
	var/mob/living/thrower = throwingdatum?.get_thrower()
	var/datum/vestige_trial/thrown_star/trial = thrower?.mind?.active_vestige_trial
	if(istype(trial) && trial.star == src)
		trial.strike(hit_atom, throwingdatum)

/datum/vestige_trial/thrown_star/field_interact(obj/structure/vestige_field_node/node, mob/living/user)
	if(node == actor || QDELETED(star) || star.throwing || !isturf(star.loc) || get_dist(star, node) > 7 || star.z != node.z)
		return
	user.put_in_hands(star)

// ===== LESSON OF THE UNSEEN HAND =====

/datum/vestige_trial/unseen_hand
	parent_type = /datum/vestige_trial/field_encounter
	name = "Lesson of the Unseen Hand"
	desc = "Deploy a five-by-five patrol field. Empty-handed, silence both corner bells while the sentry is at least three tiles away. Press the seal against its back during a corner pause, then withdraw to the central extraction focus. Its forward sight reaches four tiles; a red warning gives you one second to break sight before the whole attempt resets."
	var/list/silenced = list()
	var/marked = FALSE
	var/obj/item/vestige_clan_seal/seal

/datum/vestige_trial/unseen_hand/on_accepted(mob/living/user)
	..()
	seal = hand_over(user, new /obj/item/vestige_clan_seal(get_turf(user)))

/datum/vestige_trial/unseen_hand/Destroy()
	QDEL_NULL(seal)
	return ..()

/datum/vestige_trial/unseen_hand/setup_field(turf/center, mob/living/user)
	silenced.Cut()
	marked = FALSE
	actor = add_node(corner_turf(1), "dojo patrol sentry")
	actor.show_facing = TRUE
	actor.icon = 'icons/mob/silicon/aibots.dmi'
	actor.icon_state = "cleanbot0"
	actor.setDir(NORTH)
	add_node(corner_turf(2), "northwest alarm bell", 1)
	add_node(corner_turf(4), "southeast alarm bell", 2)
	add_node(center, "extraction focus", 3)

/datum/vestige_trial/unseen_hand/get_progress_text()
	return "Bells silenced: [length(silenced)]/2. Seal: [marked ? "stolen; reach the center unseen" : "still on sentry"]."

/datum/vestige_trial/unseen_hand/field_tick(mob/living/user, seconds_per_tick)
	patrol()
	if(!in_sight(user))
		suspicion = 0
		actor.color = "#ad8de0"
		return
	if(!suspicion)
		actor.balloon_alert(user, "seen! break sight!")
		actor.color = "#ff3333"
	suspicion += seconds_per_tick
	if(suspicion < 1)
		return
	silenced.Cut()
	marked = FALSE
	suspicion = 0
	to_chat(user, span_warning("The sentry sounds the alarm. Both bells rearm and the seal returns to its back."))
	refresh_tracker()

/datum/vestige_trial/unseen_hand/field_interact(obj/structure/vestige_field_node/node, mob/living/user)
	if(in_sight(user))
		node.balloon_alert(user, "break sight first!")
		return
	if(node.field_tag == 3)
		if(marked && get_dist(actor, user) >= 2)
			complete()
		return
	if(node.field_tag && !(node.field_tag in silenced) && get_dist(actor, user) >= 3)
		silenced += node.field_tag
		node.balloon_alert(user, "bell silenced")
		refresh_tracker()

/obj/item/vestige_clan_seal
	name = "clan paper seal"
	desc = "Press against the loaned patrol sentry's back after silencing its bells; then withdraw to the center."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper_talisman"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_clan_seal/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/unseen_hand/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.seal != src || interacting_with != trial.actor)
		return NONE
	if(length(trial.silenced) < 2 || trial.in_sight(user) || !user.Adjacent(interacting_with))
		balloon_alert(user, "silence bells; approach behind!")
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, 1.5 SECONDS, target = interacting_with))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(trial) || user.mind?.active_vestige_trial != trial || !user.is_holding(src) || trial.in_sight(user) || length(trial.silenced) < 2)
		return ITEM_INTERACT_BLOCKING
	trial.marked = TRUE
	trial.refresh_tracker()
	balloon_alert(user, "seal taken; withdraw!")
	return ITEM_INTERACT_SUCCESS

// ===== LESSON OF STILLNESS =====

/datum/vestige_trial/stillness
	parent_type = /datum/vestige_trial/field_encounter
	name = "Lesson of Stillness"
	desc = "Deploy the instructor on a clear five-by-five patch of ground. Use Rest at least two tiles from it, then activate the incense to bait a feint: hold that tile and posture for its three-second tell. The following red sweep covers your row or column: toggle Rest again to rise and move off that line, then touch the instructor with the incense during its six-second recovery. Three counters finish the lesson; mistakes cost focus and a little stamina."
	var/counters = 0
	var/phase = 0
	var/deadline = 0
	var/datum/weakref/bait_turf
	var/sweep_horizontal = FALSE
	var/obj/item/vestige_incense/incense

/datum/vestige_trial/stillness/on_accepted(mob/living/user)
	..()
	incense = hand_over(user, new /obj/item/vestige_incense(get_turf(user)))

/datum/vestige_trial/stillness/Destroy()
	QDEL_NULL(incense)
	return ..()

/datum/vestige_trial/stillness/setup_field(turf/center, mob/living/user)
	phase = 0
	counters = 0
	actor = add_node(center, "hollow instructor")
	actor.show_facing = TRUE
	actor.icon = 'icons/mob/silicon/aibots.dmi'
	actor.icon_state = "cleanbot0"

/datum/vestige_trial/stillness/get_progress_text()
	return "Counters: [counters]/3. [phase == 0 ? "Kneel two tiles away; activate incense to bait." : phase == 1 ? "FEINT: hold your tile and kneel." : phase == 2 ? "SWEEP: move off the red line!" : "RECOVERY: reach the instructor and counter with incense."]"

/datum/vestige_trial/stillness/proc/bait(mob/living/user)
	if(!field_center || phase || get_dist(user, actor) < 2 || get_dist(user, actor) > 3 || !user.resting)
		return FALSE
	bait_turf = WEAKREF(get_turf(user))
	phase = 1
	deadline = world.time + 3 SECONDS
	actor.setDir(get_dir(actor, user))
	to_chat(user, span_boldnotice("FEINT: the instructor's blade is loose. Hold your kneeling position."))
	refresh_tracker()
	return TRUE

/datum/vestige_trial/stillness/proc/failed_exchange(mob/living/user)
	phase = 0
	user.adjustStaminaLoss(15)
	clear_sweep()
	to_chat(user, span_warning("The instructor taps your guard. Recover your stance and bait another exchange."))
	refresh_tracker()

/datum/vestige_trial/stillness/proc/clear_sweep()
	for(var/obj/structure/vestige_field_node/node as anything in field_nodes.Copy())
		if(node == actor)
			continue
		field_nodes -= node
		qdel(node)

/datum/vestige_trial/stillness/proc/on_sweep(turf/spot)
	var/turf/bait = bait_turf?.resolve()
	return bait && spot && spot.z == bait.z && (sweep_horizontal ? spot.y == bait.y : spot.x == bait.x)

/datum/vestige_trial/stillness/field_tick(mob/living/user, seconds_per_tick)
	if(!phase)
		return
	var/turf/bait = bait_turf?.resolve()
	if(phase == 1 && (get_turf(user) != bait || !user.resting || !user.is_holding(incense)))
		failed_exchange(user)
		return
	if(world.time < deadline)
		return
	switch(phase)
		if(1)
			phase = 2
			sweep_horizontal = prob(50)
			deadline = world.time + 3 SECONDS
			var/turf/center = field_center?.resolve()
			for(var/turf/spot in range(2, center))
				if(on_sweep(spot))
					var/obj/structure/vestige_field_node/warning = add_node(spot, "committed sweep: leave this line")
					warning.color = "#ff3333"
			to_chat(user, span_userdanger("COMMITTED SWEEP: rise and leave the red [sweep_horizontal ? "row" : "column"]!"))
		if(2)
			if(on_sweep(get_turf(user)) || user.resting)
				failed_exchange(user)
				return
			clear_sweep()
			phase = 3
			deadline = world.time + 6 SECONDS
			to_chat(user, span_boldnotice("The blade passes. The instructor's guard is open: counter with the incense!"))
		if(3)
			failed_exchange(user)
	refresh_tracker()

/obj/item/vestige_incense
	name = "temple incense"
	desc = "Use Rest two tiles from your instructor, then activate this to bait an exchange. Toggle Rest again to rise and evade its committed sweep, then touch it with this to counter."
	icon = 'icons/obj/cigarettes.dmi'
	icon_state = "cigon"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_incense/attack_self(mob/living/user, list/modifiers)
	var/datum/vestige_trial/stillness/trial = user.mind?.active_vestige_trial
	if(istype(trial) && trial.incense == src)
		trial.bait(user)

/obj/item/vestige_incense/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/stillness/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.incense != src || interacting_with != trial.actor)
		return NONE
	if(trial.phase != 3 || world.time > trial.deadline || user.resting || !user.Adjacent(interacting_with))
		return ITEM_INTERACT_BLOCKING
	trial.phase = 0
	trial.counters++
	trial.refresh_tracker()
	balloon_alert(user, "counter landed")
	if(trial.counters >= 3)
		trial.complete()
	return ITEM_INTERACT_SUCCESS

// ===== BOONS =====

// The katana is fully standalone: its dash action rides the item and grants
// on equip, no suit or antag datum required.
/datum/vestige_boon/item/master_blade
	name = "The Master's Blade"
	desc = "The clan's energy katana. It cuts hard, parries well, and right-clicking a spot dashes you to it. A few dashes stored at a time, and they recharge."
	grant_text = "A hilt finds your hand like it had been waiting there."
	item_type = /obj/item/energy_katana

// The stars themselves are pure gear: /obj/item/throwing_star/stamina/ninja is
// just a name and throwforce bump over the shock star (ninja_stars.dm), and
// its embedding datum (pain_stam_pct 0.8) trades most of the hurt for stamina
// pain, folds legs long before it stops hearts. What the boon grants is the
// clan's willingness to keep handing them over: three, then a minute's wait.
/datum/vestige_boon/spell/clan_stars
	name = "The Clan's Stars"
	// Keep the count in sync with VESTIGE_CLAN_STAR_CHARGES (initial values
	// must be constant, so no define interpolation here)
	desc = "Call a real Spider Clan throwing star into your hand out of nothing. They embed where they hit, and the sting drops people from exhaustion long before it kills them. A few come one after another, then the clan makes you wait for more."
	grant_text = "Your empty hand closes on a weight that wasn't there a moment ago."
	spell_type = /datum/action/cooldown/spell/vestige_clan_stars

/**
 * Three stars on tap, then a minute of nothing. The charges are metered by
 * hand: the spell waves off the automatic cooldown and starts either the short
 * beat between draws or the full minute, so the button's timer always counts
 * down the thing the caster is actually waiting for. A spent handful restocks
 * on the way through the next cast rather than on a timer of its own, a cast
 * can only land once the minute is up, so the two amount to the same thing.
 */
/datum/action/cooldown/spell/vestige_clan_stars
	name = "The Clan's Stars"
	desc = "Put a throwing star in your free hand. A few come one after another, then the clan takes a while to hand over more."
	// The star's own sprite, so the button and the thing in your hand match
	button_icon = 'icons/obj/weapons/thrown.dmi'
	button_icon_state = "throwingstar"
	background_icon_state = "bg_spell"
	overlay_icon_state = "bg_spell_border"
	cooldown_time = VESTIGE_CLAN_STAR_RECHARGE
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// Stars left in this handful
	var/stars_left = VESTIGE_CLAN_STAR_CHARGES

/datum/action/cooldown/spell/vestige_clan_stars/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	if(!iscarbon(cast_on))
		return . | SPELL_CANCEL_CAST
	var/mob/living/carbon/carbon_cast_on = cast_on
	if(!length(carbon_cast_on.get_empty_held_indexes()))
		carbon_cast_on.balloon_alert(carbon_cast_on, "no free hand!")
		return . | SPELL_CANCEL_CAST
	// Both timers are started by hand in cast()
	return . | SPELL_NO_IMMEDIATE_COOLDOWN

/datum/action/cooldown/spell/vestige_clan_stars/cast(mob/living/carbon/cast_on)
	. = ..()
	if(stars_left <= 0)
		stars_left = VESTIGE_CLAN_STAR_CHARGES
	var/obj/item/star = new /obj/item/throwing_star/stamina/ninja(cast_on)
	if(!cast_on.put_in_hands(star))
		if(!QDELETED(star))
			qdel(star)
		cast_on.balloon_alert(cast_on, "no free hand!")
		StartCooldown(VESTIGE_CLAN_STAR_DRAW)
		return
	stars_left--
	playsound(cast_on, 'sound/items/weapons/batonextend.ogg', 30, TRUE, -3)
	cast_on.visible_message(
		span_warning("A throwing star folds itself out of the air into [cast_on]'s hand!"),
		span_notice("A star settles into your hand. [stars_left ? "[stars_left] more before the wait." : "That was the last of the three."]"),
	)
	StartCooldown(stars_left > 0 ? VESTIGE_CLAN_STAR_DRAW : VESTIGE_CLAN_STAR_RECHARGE)

/datum/vestige_boon/spell/veiling_smoke
	name = "The Veiling Smoke"
	desc = "Drop a smoke charge at your feet and fill the room with dense smoke. It doesn't poison anyone or do any damage, it just blocks line of sight."
	grant_text = "Someone shows you the trick once. Your hands pick it up immediately."
	spell_type = /datum/action/cooldown/spell/vestige_veiling_smoke

/datum/vestige_boon/spell/veiling_smoke/vanishing
	name = "The Vanishing Smoke"
	desc = "The same cloud on a shorter cooldown, except it stays where you were standing and puts you a few tiles away from it."
	grant_text = "The smoke no longer expects you to stand still inside it."
	upgrades_from = /datum/vestige_boon/spell/veiling_smoke
	spell_type = /datum/action/cooldown/spell/teleport/radius_turf/vestige_vanishing_smoke

/datum/vestige_boon/spell/soundless_step
	name = "The Soundless Step"
	desc = "A walking stance that silences your footsteps. Take it up and set it down whenever you like."
	grant_text = "Your next footstep doesn't make a sound."
	spell_type = /datum/action/cooldown/spell/vestige_soundless_step

/datum/vestige_boon/spell/soundless_step/weightless
	name = "The Weightless Step"
	desc = "The same stance, plus footing: you won't slip on water or ice anymore. Space lube will still put you on your back."
	grant_text = "Your feet stop arguing with the floor."
	upgrades_from = /datum/vestige_boon/spell/soundless_step
	spell_type = /datum/action/cooldown/spell/vestige_soundless_step/weightless

/**
 * The clan's smoke bomb, built local. The upstream ninja-kit smoke spell
 * (/datum/action/cooldown/spell/smoke, sold to traitors as a granter book) is
 * already standalone, but it is the choking kind, /bad smoke drops held
 * items and stacks oxyloss on a 12-second cooldown. The crew-earnable art is
 * the polite version: plain opaque smoke (vision denial only, ~10 second
 * lifetime, no mob effects, verified in effects_smoke.dm) on a longer leash.
 * The smoke itself is spawned by the spell base's after_cast, driven by
 * smoke_type/smoke_amt (smoke_amt is a RANGE; 3 covers a decent room).
 */
/datum/action/cooldown/spell/vestige_veiling_smoke
	name = "Veiling Smoke"
	desc = "Drop a smoke charge at your feet. The smoke is thick but harmless."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "smoke"
	background_icon_state = "bg_agent"
	overlay_icon_state = "bg_agent_border"
	sound = 'sound/effects/smoke.ogg'
	school = SCHOOL_CONJURATION
	cooldown_time = 30 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	smoke_type = /datum/effect_system/fluid_spread/smoke
	smoke_amt = 3

/**
 * The mastered form: the same cloud, and the caster is quietly elsewhere by
 * the time it settles. Rides the wizard blink chassis
 * (/datum/action/cooldown/spell/teleport/radius_turf, verified standalone,
 * no garb or antag checks beyond spell_requirements, which we clear).
 * do_teleport runs unforced under TELEPORT_CHANNEL_MAGIC, so TRAIT_NO_TELEPORT
 * and NOTELEPORT areas still say no. The smoke drops either way, the step
 * simply fails. Origin smoke is spawned by hand in cast(): the base class's
 * smoke_type/smoke_amt puffs in after_cast at the owner's CURRENT turf, which
 * is post-teleport, the wrong end of a vanishing act.
 */
/datum/action/cooldown/spell/teleport/radius_turf/vestige_vanishing_smoke
	name = "Vanishing Smoke"
	desc = "Drop a smoke charge at your feet and teleport a few tiles away as it goes off."
	button_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "ninja_phase"
	background_icon_state = "bg_agent"
	overlay_icon_state = "bg_agent_border"
	sound = 'sound/effects/smoke.ogg'
	cooldown_time = 20 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	inner_tele_radius = 1
	outer_tele_radius = 3 // a sidestep, not an escape, the wizard blink this rides on reaches 6
	destination_flags = TELEPORT_SPELL_SKIP_SPACE | TELEPORT_SPELL_SKIP_DENSE | TELEPORT_SPELL_SKIP_BLOCKED
	post_teleport_sound = null // arriving loudly would defeat the syllabus

/datum/action/cooldown/spell/teleport/radius_turf/vestige_vanishing_smoke/cast(mob/living/cast_on)
	var/turf/origin = get_turf(cast_on)
	. = ..()
	// The cloud stands where the student was; the student, pointedly, does not
	var/datum/effect_system/fluid_spread/smoke/cover = new()
	cover.set_up(3, holder = cast_on, location = origin) // same reach as the unmastered art's cloud
	cover.start()

/**
 * Silent footwork as a held stance. There is no upstream spell to port, the
 * ninja gets TRAIT_SILENT_FOOTSTEPS from the MOD cloaking module
 * (modules_ninja.dm), which is suit-bound, so this is a from-scratch toggle
 * on the same trait (name verified against __DEFINES/traits/declarations.dm).
 * Traits are keyed to REF(src) and stripped in Remove(), so an upgrade
 * replacing this action, or a body swap re-homing it (action Destroy and
 * mind transfer both route through Remove). Can never strand them; the
 * stance simply drops and must be retaken.
 */
/datum/action/cooldown/spell/vestige_soundless_step
	name = "Soundless Step"
	desc = "Silences your footsteps. Use again to turn it off."
	button_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "ninja_cloak"
	background_icon_state = "bg_agent"
	overlay_icon_state = "bg_agent_border"
	cooldown_time = 2 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// Traits held while the stance is up
	var/list/stance_traits = list(TRAIT_SILENT_FOOTSTEPS)
	/// Whether the stance is currently held
	var/stance_up = FALSE

// The perfected stance adds galoshes-tier footing (water and ice only,
// TRAIT_NO_SLIP_ALL stays with the heretics; space lube still wins)
/datum/action/cooldown/spell/vestige_soundless_step/weightless
	name = "Weightless Step"
	desc = "Silences your footsteps and stops you slipping on water or ice. Use again to turn it off."
	stance_traits = list(TRAIT_SILENT_FOOTSTEPS, TRAIT_NO_SLIP_WATER, TRAIT_NO_SLIP_ICE)

/datum/action/cooldown/spell/vestige_soundless_step/cast(mob/living/cast_on)
	. = ..()
	if(stance_up)
		drop_stance(cast_on)
		cast_on.balloon_alert(cast_on, "stance set down")
		return
	cast_on.add_traits(stance_traits, REF(src))
	stance_up = TRUE
	cast_on.balloon_alert(cast_on, "stance taken up")

/datum/action/cooldown/spell/vestige_soundless_step/Remove(mob/living/remove_from)
	drop_stance(remove_from)
	return ..()

/// Sets the stance down, releasing its traits. Safe to call when it isn't up.
/datum/action/cooldown/spell/vestige_soundless_step/proc/drop_stance(mob/living/user)
	if(!stance_up)
		return
	stance_up = FALSE
	if(!QDELETED(user))
		user.remove_traits(stance_traits, REF(src))

#undef VESTIGE_CLAN_STAR_CHARGES
#undef VESTIGE_CLAN_STAR_RECHARGE
#undef VESTIGE_CLAN_STAR_DRAW
