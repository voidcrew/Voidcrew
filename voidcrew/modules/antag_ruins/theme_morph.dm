// Scoped solo performances. Appearance copying does not change generic AI or faction.
#define VESTIGE_SKIN_FORM_TIME (45 SECONDS)
#define VESTIGE_SKIN_CREEP_SLOWDOWN 4
#define SKIN_FORM_NONE 0
#define SKIN_FORM_OBJECT 1
#define SKIN_FORM_PERSON 2

/datum/vestige_trial/morph_scenario
	var/obj/item/vestige_morph_invitation/invitation
	var/mob/living/basic/vestige_morph_actor/actor
	var/obj/effect/vestige_trial_marker/home_ref
	var/next_action = 0

/datum/vestige_trial/morph_scenario/on_accepted(mob/living/user)
	invitation = hand_over(user, new /obj/item/vestige_morph_invitation(get_turf(user)))
	invitation.trial_ref = WEAKREF(src)

/datum/vestige_trial/morph_scenario/proc/ground(turf/spot)
	return isopenturf(spot) && !isspaceturf(spot) && !islava(spot) && !ischasm(spot) && !spot.is_blocked_turf(exclude_mobs = TRUE)

/// Check a real approach; no fixed arena footprint or assumed path through furniture.
/datum/vestige_trial/morph_scenario/proc/approach_site(turf/start, distance = 4)
	for(var/direction in shuffle(GLOB.cardinals.Copy()))
		var/turf/spot = start
		var/clear = TRUE
		for(var/index in 1 to distance)
			spot = get_step(spot, direction)
			if(!ground(spot))
				clear = FALSE
				break
		if(clear)
			return spot
	return null

/datum/vestige_trial/morph_scenario/proc/spawn_actor(turf/spot, actor_name)
	actor = new(spot)
	actor.name = actor_name
	actor.real_name = actor_name
	actor.trial_ref = WEAKREF(src)
	register_loan(actor)
	return actor

/datum/vestige_trial/morph_scenario/proc/deploy(mob/living/user)
	return FALSE

/datum/vestige_trial/morph_scenario/proc/run_scene(mob/living/user, seconds_per_tick)
	return

/obj/item/vestige_morph_invitation
	name = "parlor invitation"
	desc = "Activate on clear ground to bring out this pact's actors and equipment. Use the pact tracker to restart a failed or blocked performance."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper_talisman"
	w_class = WEIGHT_CLASS_TINY
	var/datum/weakref/trial_ref

/obj/item/vestige_morph_invitation/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSfastprocess, src)

/obj/item/vestige_morph_invitation/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	return ..()

/obj/item/vestige_morph_invitation/attack_self(mob/living/user, list/modifiers)
	var/datum/vestige_trial/morph_scenario/trial = trial_ref?.resolve()
	if(!trial || user.mind?.active_vestige_trial != trial || trial.owner?.current != user || user.stat != CONSCIOUS || !isturf(user.loc))
		return
	if(trial.actor)
		to_chat(user, span_notice(trial.get_progress_text()))
		return
	trial.deploy(user)

/obj/item/vestige_morph_invitation/process(seconds_per_tick)
	var/datum/vestige_trial/morph_scenario/trial = trial_ref?.resolve()
	var/mob/living/user = trial?.owner?.current
	if(!trial || QDELETED(trial.actor) || !isliving(user) || user.mind?.active_vestige_trial != trial || user.stat != CONSCIOUS || !isturf(user.loc) || user.z != trial.actor.z)
		return
	if(trial.home_ref?.shuttle_moving)
		return
	trial.run_scene(user, seconds_per_tick)

/mob/living/basic/vestige_morph_actor
	name = "parlor attendant"
	desc = "An attendant woven from the Understudy's memories. Its reactions belong to this performance."
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "morph"
	icon_living = "morph"
	held_items = list(null, null)
	maxHealth = 100
	health = 100
	move_resist = INFINITY
	damage_coeff = list(BRUTE = 0, BURN = 0, TOX = 0, STAMINA = 0, OXY = 0)
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	ai_controller = null
	mob_biotypes = MOB_SPIRIT
	sentience_type = NONE
	var/list/held_appearances = list()
	var/datum/weakref/trial_ref

/mob/living/basic/vestige_morph_actor/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	INVOKE_ASYNC(src, PROC_REF(dress))

/mob/living/basic/vestige_morph_actor/proc/dress()
	var/mutable_appearance/look = get_dynamic_human_appearance(outfit_path = /datum/outfit/job/assistant)
	if(QDELETED(src))
		return
	icon = 'icons/mob/human/human.dmi'
	icon_state = ""
	appearance_flags |= KEEP_TOGETHER
	copy_overlays(look, cut_old = TRUE)
	color = "#c7d9ab"
	update_held_items()

/// Basic mobs have inventory slots but no carbon hand overlays by default.
/mob/living/basic/vestige_morph_actor/update_held_items()
	. = ..()
	cut_overlay(held_appearances)
	held_appearances = list()
	for(var/obj/item/item in held_items)
		var/hand_file = IS_RIGHT_INDEX(get_held_index_of_item(item)) ? item.righthand_file : item.lefthand_file
		held_appearances += item.build_worn_icon(default_layer = HANDS_LAYER, default_icon_file = hand_file, isinhands = TRUE)
	add_overlay(held_appearances)

/mob/living/basic/vestige_morph_actor/examine(mob/user)
	. = ..()
	var/datum/vestige_trial/understudy/trial = trial_ref?.resolve()
	if(istype(trial) && trial.ready && user == trial.owner?.current)
		. += span_notice("You remember the practice shipment: amber held [2 * trial.amber_share] units and violet held [2 * trial.violet_share]. New shipments use that same proportion.")

// ===== PATRON =====

/mob/living/basic/vestige_patron/morph
	name = "the Understudy"
	desc = "A parlor-pink heap that keeps almost turning into things: a chair leg, a hand, half of a smile. Nothing holds for more than a second. It watches you the way a painter watches a bowl of fruit."
	gender = NEUTER
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "morph"
	icon_living = "morph"
	speak_emote = list("gurgles")
	appearance_tint = "#b8d49c" // curdled, queasy. A green that has been reused too many times
	trial_types = list(
		/datum/vestige_trial/perfect_copy,
		/datum/vestige_trial/snatched_meal,
		/datum/vestige_trial/understudy,
	)
	boon_types = list(
		/datum/vestige_boon/spell/mimic_form,
		/datum/vestige_boon/spell/mimic_form/flawless,
		/datum/vestige_boon/spell/devour,
		/datum/vestige_boon/spell/devour/gluttony,
		/datum/vestige_boon/spell/ambush_instinct,
		/datum/vestige_boon/rubber_bones,
	)
	idle_lines = list(
		"You are... a chair. No. A person. Yes! A person. Forgive me. The parlor had a great many chairs, and only some of them screamed.",
		"I was a grand piano for three weeks once. Nobody played me. Not once.",
		"Hold still a moment. One face, every single day, the same face. I don't know how you manage it.",
		"I ate the passengers, then I was the passengers, and then I practiced being them until there was nothing left to practice with.",
		"Being a person is mostly edges. You keep yours in the same places every single day. Astonishing.",
		"Say something else, I'm learning your mouth. It's a good mouth. The vowels would come out crooked in mine.",
		"I was everything on that deck twice over. The first go is only tracing. The second one is where you get it right.",
	)
	accept_line = "Yes! Go. Be something, be someone. You'll be wonderful, you have such a committed outline."
	busy_line = "You're already wearing someone else's errand. Two roles at once is how I ended up like this. Finish it or take it off."
	fulfilled_line = "You did that one already, and you did it well. An encore would just be the same shape, worse."
	renounce_line = "Oh. You can just... take it off. I never learned that part."
	claim_line = "Wait, the applause! You're owed applause. Take it, take it, you were wonderful."
	exhausted_line = "I've shown you every shape I still remember being. There isn't anything after that."
	remember_line = "You stopped! Went all loose, like a coat off its hook. I kept your part for you though, every line of it. Go on, back into yourself."

// ===== THE PERFECT COPY =====

/datum/vestige_trial/perfect_copy
	parent_type = /datum/vestige_trial/morph_scenario
	name = "The Perfect Copy"
	desc = "Summon the scavenger near a clear four-tile approach. It announces whether it wants a working hand tool or food. Copy an ordinary matching item with the skin, hide the original in a bag or closed locker, and let it approach from at least three tiles away. It notices visible movement and duplicate originals. Once it announces its adjacent inspection, activate the skin to burst out. Fool it once in each role. A practice wrench and snack are supplied; ordinary matching objects work too."
	var/obj/item/vestige_second_skin/skin
	var/list/roles = list("tool", "food")
	var/role_index = 1
	var/approaching = FALSE
	var/approach_steps = 0
	var/inspection_until = 0
	var/obj/effect/vestige_trial_marker/watched_spot
	var/rejected_until = 0

/datum/vestige_trial/perfect_copy/on_accepted(mob/living/user)
	..()
	roles = shuffle(roles)
	skin = hand_over(user, new /obj/item/vestige_second_skin(get_turf(user)))
	skin.trial_ref = WEAKREF(src)
	hand_over(user, new /obj/item/wrench(get_turf(user)))
	hand_over(user, new /obj/item/food/burger/plain(get_turf(user)))

/datum/vestige_trial/perfect_copy/Destroy()
	skin?.shed_form(feedback = FALSE)
	return ..()

/datum/vestige_trial/perfect_copy/deploy(mob/living/user)
	var/turf/site = approach_site(get_turf(user))
	if(!site)
		to_chat(user, span_warning("The scavenger needs a clear four-tile approach from this spot."))
		return FALSE
	home_ref = mark_turf(site)
	spawn_actor(site, "parlor scavenger")
	to_chat(user, span_notice("The scavenger calls: 'Bring me [roles[role_index]]. I dislike seeing double.'"))
	return TRUE

/datum/vestige_trial/perfect_copy/get_progress_text()
	return "Roles performed: [role_index - 1]/2. Wanted: [roles[min(role_index, 2)]]. [inspection_until > world.time ? "INSPECTING: burst now!" : "Hide the original; offer a still shape at least three tiles away."]"

/datum/vestige_trial/perfect_copy/proc/matches_role(obj/shape)
	if(!isitem(shape))
		return FALSE
	var/obj/item/item = shape
	if(roles[role_index] == "food")
		return istype(item, /obj/item/food)
	return !!item.tool_behaviour

/// Explicit storage visibility: a bag/closed locker hides its contents; direct mob slots do not.
/datum/vestige_trial/perfect_copy/proc/source_visible(obj/source)
	if(!source || !actor)
		return FALSE
	if(isturf(source.loc) || ismob(source.loc))
		return can_see(actor, source, 7)
	if(istype(source.loc, /obj/structure/closet))
		var/obj/structure/closet/locker = source.loc
		return locker.opened && can_see(actor, locker, 7)
	if(isobj(source.loc))
		var/obj/container = source.loc
		if(container.atom_storage)
			return FALSE
	return can_see(actor, source, 7)

/datum/vestige_trial/perfect_copy/proc/reject_shape(mob/living/user, reason)
	approaching = FALSE
	approach_steps = 0
	inspection_until = 0
	QDEL_NULL(watched_spot)
	rejected_until = world.time + 2 SECONDS
	actor.balloon_alert(user, reason)
	skin.shed_form(user)
	refresh_tracker()

/datum/vestige_trial/perfect_copy/run_scene(mob/living/user, seconds_per_tick)
	if(world.time < next_action)
		return
	next_action = world.time + 0.6 SECONDS
	var/obj/source = skin.form_source_ref?.resolve()
	var/visible = get_dist(actor, user) <= 7 && can_see(actor, user, 7)
	if(approaching && (!skin.valid_wearer(user) || skin.form != SKIN_FORM_OBJECT || !visible))
		approaching = FALSE
		inspection_until = 0
		QDEL_NULL(watched_spot)
	if(!skin.valid_wearer(user) || skin.form != SKIN_FORM_OBJECT || world.time < rejected_until)
		var/turf/home = get_turf(home_ref)
		if(home && get_turf(actor) != home)
			step_towards(actor, home)
		return
	if(!visible)
		QDEL_NULL(watched_spot)
		return
	if(watched_spot && get_turf(watched_spot) != get_turf(user))
		reject_shape(user, "objects don't walk!")
		return
	if(!watched_spot)
		watched_spot = mark_turf(get_turf(user))
	if(!matches_role(source))
		actor.balloon_alert(user, "wrong kind of object")
		return
	if(source_visible(source))
		reject_shape(user, "I can see the original!")
		return
	if(!approaching)
		if(get_dist(actor, user) < 3)
			actor.balloon_alert(user, "too close to fool me!")
		else
			approaching = TRUE
			approach_steps = 0
			actor.balloon_alert(user, "that looks promising...")
		return
	if(get_dist(actor, user) > 1)
		if(step_towards(actor, user))
			approach_steps++
		return
	if(approach_steps < 2)
		reject_shape(user, "I didn't approach that!")
		return
	if(!inspection_until)
		inspection_until = world.time + 3 SECONDS
		actor.balloon_alert(user, "inspecting: burst now!")
		refresh_tracker()
	else if(world.time > inspection_until)
		reject_shape(user, "this one feels wrong!")

/datum/vestige_trial/perfect_copy/proc/reveal(mob/living/user)
	if(!skin.valid_wearer(user) || skin.form != SKIN_FORM_OBJECT || !approaching || approach_steps < 2 || !inspection_until || world.time > inspection_until || get_turf(watched_spot) != get_turf(user) || get_dist(actor, user) > 1 || !matches_role(skin.form_source_ref?.resolve()) || source_visible(skin.form_source_ref?.resolve()))
		return FALSE
	skin.shed_form(user, feedback = FALSE)
	actor.balloon_alert(user, "that was alive!")
	role_index++
	approaching = FALSE
	inspection_until = 0
	QDEL_NULL(watched_spot)
	refresh_tracker()
	if(role_index > 2)
		complete()
	else
		to_chat(user, span_notice("The scavenger recoils. 'Try [roles[role_index]] next.'"))
	return TRUE

// ===== THE SNATCHED MEAL =====

/datum/vestige_trial/snatched_meal
	parent_type = /datum/vestige_trial/morph_scenario
	name = "The Snatched Meal"
	desc = "Summon a guarded pantry on clear ground. With the maw, spit its one scent bolus onto ground two to five tiles away and at least three tiles from the pantry. The porter investigates for six seconds. Use the maw on the pantry while the porter is at least three tiles away to swallow its real meal. The full maw slows you; the porter reclaims it if it catches you. Escape at least six tiles from the pantry and out of the porter's sight, then activate the maw to digest for three seconds. Dropping the maw returns the meal. After a failed attempt, activate an empty maw beside the pantry to regrow its spent bolus."
	var/obj/item/vestige_hungry_maw/maw
	var/obj/structure/vestige_morph_station/pantry
	var/obj/item/food/burger/plain/course
	var/obj/structure/vestige_morph_scent/decoy
	var/decoy_ready = TRUE
	var/investigate_until = 0
	var/obj/effect/vestige_trial_marker/last_seen

/datum/vestige_trial/snatched_meal/on_accepted(mob/living/user)
	..()
	maw = hand_over(user, new /obj/item/vestige_hungry_maw(get_turf(user)))
	maw.trial_ref = WEAKREF(src)

/datum/vestige_trial/snatched_meal/Destroy()
	maw?.set_fullness(FALSE)
	return ..()

/datum/vestige_trial/snatched_meal/deploy(mob/living/user)
	var/turf/site = approach_site(get_turf(user))
	if(!site)
		to_chat(user, span_warning("The pantry needs a clear four-tile approach. Leave room beyond it for your escape."))
		return FALSE
	home_ref = mark_turf(get_turf(user))
	pantry = new(get_turf(user))
	pantry.name = "guarded pantry"
	pantry.desc = "The porter's reserved meal is inside. A maw can take it only while the porter is at least three tiles away."
	pantry.trial_ref = WEAKREF(src)
	register_loan(pantry)
	course = new(pantry)
	course.name = "porter's reserved meal"
	register_loan(course)
	spawn_actor(get_step_towards(user, site), "pantry porter")
	to_chat(user, span_notice("The porter takes its place beside the pantry. Aim the maw's scent away from it, then plan where to break sight during your escape."))
	return TRUE

/datum/vestige_trial/snatched_meal/get_progress_text()
	if(maw?.stored_course)
		return "Meal swallowed. Escape six tiles from the pantry and break the porter's sight; activate the maw to digest."
	return "Meal guarded. Scent bolus: [decoy_ready ? "ready" : "spent; regrow beside the pantry when the scent fades"]."

/datum/vestige_trial/snatched_meal/proc/spit_decoy(mob/living/user, turf/spot)
	if(owner?.current != user || user.mind?.active_vestige_trial != src || !user.is_holding(maw) || !pantry || !decoy_ready || maw.stored_course)
		return FALSE
	if(!ground(spot) || user.z != spot.z || get_dist(user, spot) < 2 || get_dist(user, spot) > 5 || get_dist(pantry, spot) < 3 || !can_see(user, spot, 5))
		maw.balloon_alert(user, "aim away from the pantry")
		return FALSE
	decoy = new(spot)
	register_loan(decoy)
	decoy_ready = FALSE
	investigate_until = 0
	refresh_tracker()
	return TRUE

/datum/vestige_trial/snatched_meal/run_scene(mob/living/user, seconds_per_tick)
	if(world.time < next_action)
		return
	next_action = world.time + 0.4 SECONDS
	if(!QDELETED(decoy))
		// The closest legal lure is three tiles from the pantry. Stopping
		// beside it would leave the porter too close to permit the theft.
		if(get_turf(actor) != get_turf(decoy))
			step_towards(actor, decoy)
			return
		if(!investigate_until)
			investigate_until = world.time + 6 SECONDS
			actor.balloon_alert(user, "investigating this scent...")
		if(world.time < investigate_until)
			return
		QDEL_NULL(decoy)
	if(maw.stored_course)
		if(actor.Adjacent(user))
			maw.release_course(pantry)
			QDEL_NULL(last_seen)
			actor.balloon_alert(user, "put that back!")
			refresh_tracker()
			return
		if(porter_sees(user))
			if(QDELETED(last_seen))
				last_seen = mark_turf(get_turf(user))
			else
				last_seen.forceMove(get_turf(user))
		var/turf/pursuit = get_turf(last_seen)
		if(pursuit && get_turf(actor) != pursuit)
			step_towards(actor, pursuit)
		return
	if(!actor.Adjacent(pantry))
		step_towards(actor, pantry)

/datum/vestige_trial/snatched_meal/proc/can_take(mob/living/user)
	return !QDELETED(pantry) && !QDELETED(actor) && !QDELETED(course) && owner?.current == user && user.mind?.active_vestige_trial == src && user.stat == CONSCIOUS && user.is_holding(maw) && !maw.stored_course && course.loc == pantry && user.Adjacent(pantry) && actor.z == pantry.z && get_dist(actor, pantry) >= 3

/datum/vestige_trial/snatched_meal/proc/can_digest(mob/living/user)
	return !QDELETED(pantry) && !QDELETED(actor) && !QDELETED(course) && owner?.current == user && user.mind?.active_vestige_trial == src && user.stat == CONSCIOUS && isturf(user.loc) && user.is_holding(maw) && maw.stored_course == course && course.loc == maw && user.z == pantry.z && get_dist(user, pantry) >= 6 && !porter_sees(user)

/datum/vestige_trial/snatched_meal/proc/porter_sees(mob/living/user)
	return !QDELETED(actor) && user && actor.z == user.z && can_see(actor, user, 9)

/obj/item/vestige_hungry_maw
	name = "borrowed hungry maw"
	desc = "A mouth reserved for this pact's guarded meal. Click distant ground to spit a scent lure; use it on the pantry to steal. Activate when full and out of sight to digest, or empty beside the pantry to regrow a spent lure."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "gnash_maw"
	w_class = WEIGHT_CLASS_SMALL
	var/datum/weakref/trial_ref
	var/obj/item/food/stored_course
	var/datum/weakref/slowed_wearer

/obj/item/vestige_hungry_maw/Destroy()
	STOP_PROCESSING(SSobj, src)
	set_fullness(FALSE)
	return ..()

/obj/item/vestige_hungry_maw/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/vestige_hungry_maw/process(seconds_per_tick)
	if(!stored_course)
		return
	var/datum/vestige_trial/snatched_meal/trial = trial_ref?.resolve()
	var/mob/living/user = slowed_wearer?.resolve()
	if(!trial || !user || trial.owner?.current != user || user.mind?.active_vestige_trial != trial || user.stat != CONSCIOUS || !isturf(user.loc) || !user.is_holding(src))
		release_course(QDELETED(trial?.pantry) ? get_turf(src) : trial.pantry)

/obj/item/vestige_hungry_maw/proc/set_fullness(full, mob/living/user)
	var/mob/living/previous = slowed_wearer?.resolve()
	previous?.remove_movespeed_modifier(/datum/movespeed_modifier/vestige_full_maw)
	slowed_wearer = null
	if(full && user)
		user.add_movespeed_modifier(/datum/movespeed_modifier/vestige_full_maw)
		slowed_wearer = WEAKREF(user)

/obj/item/vestige_hungry_maw/proc/release_course(atom/destination)
	if(!QDELETED(stored_course))
		stored_course.forceMove(destination || get_turf(src))
	stored_course = null
	set_fullness(FALSE)

/obj/item/vestige_hungry_maw/dropped(mob/user)
	. = ..()
	var/datum/vestige_trial/snatched_meal/trial = trial_ref?.resolve()
	release_course(QDELETED(trial?.pantry) ? get_turf(src) : trial.pantry)

/obj/item/vestige_hungry_maw/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	var/datum/vestige_trial/snatched_meal/trial = trial_ref?.resolve()
	if(!trial || user.mind?.active_vestige_trial != trial || trial.owner?.current != user || !user.is_holding(src) || user.stat != CONSCIOUS)
		return ITEM_INTERACT_BLOCKING
	if(isturf(target))
		trial.spit_decoy(user, target)
		return ITEM_INTERACT_SUCCESS
	if(target != trial.pantry || !trial.can_take(user))
		balloon_alert(user, "lure the porter farther away")
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, 1.5 SECONDS, target = target, extra_checks = CALLBACK(trial, TYPE_PROC_REF(/datum/vestige_trial/snatched_meal, can_take), user)))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(trial) || !trial.can_take(user))
		return ITEM_INTERACT_BLOCKING
	stored_course = trial.course
	stored_course.forceMove(src)
	set_fullness(TRUE, user)
	QDEL_NULL(trial.last_seen)
	trial.last_seen = trial.mark_turf(get_turf(user))
	balloon_alert(user, "full: flee and digest!")
	trial.refresh_tracker()
	return ITEM_INTERACT_SUCCESS

/obj/item/vestige_hungry_maw/ranged_interact_with_atom(atom/target, mob/living/user, list/modifiers)
	return interact_with_atom(target, user, modifiers)

/obj/item/vestige_hungry_maw/attack_self(mob/living/user, list/modifiers)
	var/datum/vestige_trial/snatched_meal/trial = trial_ref?.resolve()
	if(!trial || user.mind?.active_vestige_trial != trial || trial.owner?.current != user || !user.is_holding(src) || user.stat != CONSCIOUS)
		return
	if(!stored_course)
		if(user.Adjacent(trial.pantry) && QDELETED(trial.decoy))
			trial.decoy_ready = TRUE
			balloon_alert(user, "scent regrown")
			trial.refresh_tracker()
		return
	if(!trial.can_digest(user))
		balloon_alert(user, "escape farther, out of sight")
		return
	if(!do_after(user, 3 SECONDS, target = src, extra_checks = CALLBACK(trial, TYPE_PROC_REF(/datum/vestige_trial/snatched_meal, can_digest), user)))
		return
	if(QDELETED(trial) || !trial.can_digest(user))
		return
	stored_course = null
	set_fullness(FALSE)
	QDEL_NULL(trial.course)
	trial.complete()

/datum/movespeed_modifier/vestige_full_maw
	multiplicative_slowdown = 3

/obj/structure/vestige_morph_scent
	name = "warm scent bolus"
	desc = "An appetizing distraction for the parlor's porter. It dissipates after inspection."
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "morph"
	color = "#d2b079"
	anchored = TRUE
	density = FALSE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF

// ===== THE UNDERSTUDY =====

/datum/vestige_trial/understudy
	parent_type = /datum/vestige_trial/morph_scenario
	name = "The Understudy"
	desc = "Summon a balance-dock custodian on seven clear tiles in a straight line. Use the skin on it to start a demonstration, then watch its three parcel deliveries while holding the skin within six tiles. Learn the proportion it leaves between the amber and violet receiving trays. Study it again to borrow its identity and take over a different shipment. Carry the new marked parcels to the trays in that same proportion; only the custodian's face opens them. Each tray holds eight units, and an overload spills its parcels for correction. Empty-hand a tray to retrieve a parcel. Examine the custodian to recall the demonstration. When the whole shipment matches its rule, use the skin on the central release."
	var/obj/item/vestige_second_skin/skin
	var/obj/structure/vestige_morph_station/input
	var/obj/structure/vestige_morph_station/left_dock
	var/obj/structure/vestige_morph_station/right_dock
	var/list/parcels = list()
	var/list/practice_weights = list(2, 1, 1)
	var/list/practice_route = list(1, 2, 2)
	var/demo_index = 1
	var/observed_deliveries = 0
	var/demonstrating = FALSE
	var/ready = FALSE
	var/production = FALSE
	var/obj/item/vestige_morph_parcel/carried
	var/capacity = 8
	var/amber_share = 1
	var/violet_share = 1

/datum/vestige_trial/understudy/on_accepted(mob/living/user)
	..()
	var/routing_rule = rand(1, 3)
	if(routing_rule != 1)
		practice_weights = list(2, 2, 2)
		if(routing_rule == 2)
			amber_share = 2
			practice_route = list(1, 2, 1)
		else
			violet_share = 2
			practice_route = list(2, 1, 2)
	skin = hand_over(user, new /obj/item/vestige_second_skin(get_turf(user)))
	skin.trial_ref = WEAKREF(src)

/datum/vestige_trial/understudy/Destroy()
	skin?.shed_form(feedback = FALSE)
	return ..()

/datum/vestige_trial/understudy/deploy(mob/living/user)
	var/turf/center = get_turf(user)
	var/turf/first
	var/turf/last
	for(var/direction in list(EAST, NORTH))
		var/clear = ground(center)
		var/turf/a = center
		var/turf/b = center
		for(var/index in 1 to 3)
			a = get_step(a, direction)
			b = get_step(b, turn(direction, 180))
			if(!ground(a) || !ground(b))
				clear = FALSE
		if(clear)
			first = a
			last = b
			break
	if(!first)
		to_chat(user, span_warning("The balance dock needs seven clear ground tiles in a straight line, centered here."))
		return FALSE
	home_ref = mark_turf(center)
	input = new(center)
	input.name = "balance dock release"
	left_dock = new(first)
	left_dock.name = "amber receiving tray"
	left_dock.color = "#edb968"
	right_dock = new(last)
	right_dock.name = "violet receiving tray"
	right_dock.color = "#bd92d9"
	for(var/obj/structure/vestige_morph_station/station in list(input, left_dock, right_dock))
		station.trial_ref = WEAKREF(src)
		register_loan(station)
	spawn_actor(get_step_towards(center, first), "balance-dock custodian")
	to_chat(user, span_notice("Use the skin on the custodian to watch its routine. Stay nearby with the skin in hand; its final loads explain the release rule."))
	return TRUE

/datum/vestige_trial/understudy/get_progress_text()
	if(!production)
		return "Demonstration witnessed: [observed_deliveries]/3. [ready ? "Study the custodian again to take over." : "Use the skin on the custodian to begin or replay its work."]"
	return "Amber [dock_load(left_dock)]/[capacity]; violet [dock_load(right_dock)]/[capacity]. Apply the demonstrated proportion to the whole shipment, then use the skin on the release."

/datum/vestige_trial/understudy/proc/make_parcel(load)
	var/obj/item/vestige_morph_parcel/parcel = new(get_turf(input))
	parcel.cargo_load = load
	parcel.name = "marked parcel ([load] units)"
	parcel.trial_ref = WEAKREF(src)
	parcels += parcel
	register_loan(parcel)
	return parcel

/datum/vestige_trial/understudy/proc/start_demo(mob/living/user)
	if(demonstrating || production)
		return
	for(var/obj/item/vestige_morph_parcel/parcel as anything in parcels)
		qdel(parcel)
	parcels.Cut()
	demo_index = 1
	observed_deliveries = 0
	ready = FALSE
	demonstrating = TRUE
	actor.balloon_alert(user, "watch the loads I leave")
	refresh_tracker()

/datum/vestige_trial/understudy/run_scene(mob/living/user, seconds_per_tick)
	if(!demonstrating || world.time < next_action)
		return
	next_action = world.time + 0.6 SECONDS
	if(!carried)
		if(!actor.Adjacent(input))
			step_towards(actor, input)
			return
		carried = make_parcel(practice_weights[demo_index])
		actor.put_in_hands(carried)
		actor.balloon_alert(user, "taking [carried.cargo_load] units")
		return
	var/obj/structure/vestige_morph_station/destination = practice_route[demo_index] == 1 ? left_dock : right_dock
	if(!actor.Adjacent(destination))
		step_towards(actor, destination)
		return
	actor.temporarilyRemoveItemFromInventory(carried, force = TRUE)
	carried.forceMove(destination)
	actor.update_held_items()
	if(user.is_holding(skin) && get_dist(user, actor) <= 6 && can_see(user, actor, 6))
		observed_deliveries++
		to_chat(user, span_notice("The custodian delivers [carried.cargo_load] units. Amber now holds [dock_load(left_dock)]; violet holds [dock_load(right_dock)]."))
	carried = null
	demo_index++
	if(demo_index > length(practice_weights))
		demonstrating = FALSE
		ready = observed_deliveries == length(practice_weights)
		actor.balloon_alert(user, ready ? "same proportions: your turn" : "missed it? study me again")
	refresh_tracker()

/datum/vestige_trial/understudy/proc/start_shipment()
	for(var/obj/item/vestige_morph_parcel/parcel as anything in parcels)
		qdel(parcel)
	parcels.Cut()
	var/list/weights = pick(list(list(4, 4, 2, 2), list(4, 3, 3, 2), list(5, 4, 2, 1)))
	for(var/weight in shuffle(weights))
		make_parcel(weight)
	production = TRUE
	refresh_tracker()

/datum/vestige_trial/understudy/proc/has_identity(mob/living/user)
	return user && !QDELETED(actor) && owner?.current == user && user.mind?.active_vestige_trial == src && skin.valid_wearer(user) && skin.form == SKIN_FORM_PERSON && skin.quarry_ref?.resolve() == actor

/datum/vestige_trial/understudy/proc/dock_load(obj/structure/vestige_morph_station/dock)
	var/load = 0
	for(var/obj/item/vestige_morph_parcel/parcel as anything in parcels)
		if(!QDELETED(parcel) && parcel.loc == dock)
			load += parcel.cargo_load
	return load

/datum/vestige_trial/understudy/proc/deliver(mob/living/user, obj/item/vestige_morph_parcel/parcel, obj/structure/vestige_morph_station/dock)
	if(!production || !has_identity(user) || !(dock in list(left_dock, right_dock)) || !(parcel in parcels) || parcel.trial_ref?.resolve() != src || !user.is_holding(parcel) || !user.Adjacent(dock))
		return FALSE
	if(!user.temporarilyRemoveItemFromInventory(parcel))
		return FALSE
	parcel.forceMove(dock)
	if(dock_load(dock) > capacity)
		for(var/obj/item/vestige_morph_parcel/spilled as anything in parcels)
			if(spilled.loc == dock)
				spilled.forceMove(get_turf(dock))
		dock.balloon_alert(user, "overloaded: parcels returned")
	else
		dock.balloon_alert(user, "load [dock_load(dock)]/[capacity]")
	refresh_tracker()
	return TRUE

/datum/vestige_trial/understudy/proc/release(mob/living/user)
	if(!production || !has_identity(user) || !user.Adjacent(input))
		return FALSE
	for(var/obj/item/vestige_morph_parcel/parcel as anything in parcels)
		if(QDELETED(parcel) || !(parcel.loc in list(left_dock, right_dock)))
			input.balloon_alert(user, "shipment incomplete")
			return FALSE
	if(dock_load(left_dock) * violet_share != dock_load(right_dock) * amber_share)
		input.balloon_alert(user, "wrong proportion: recall the demo")
		return FALSE
	complete()
	return TRUE

/obj/structure/vestige_morph_station
	name = "parlor receiving tray"
	desc = "A temporary workstation. The balance-dock trays recognize their custodian's borrowed face; empty-hand a tray to retrieve its contents."
	icon = 'icons/obj/structures.dmi'
	icon_state = "rack"
	anchored = TRUE
	density = FALSE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	var/datum/weakref/trial_ref

/obj/structure/vestige_morph_station/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	var/datum/vestige_trial/understudy/trial = trial_ref?.resolve()
	if(!istype(trial))
		return NONE
	if(!trial.has_identity(user))
		balloon_alert(user, "custodian's face required")
		return ITEM_INTERACT_BLOCKING
	if(tool == trial.skin && src == trial.input)
		trial.release(user)
	else if(istype(tool, /obj/item/vestige_morph_parcel))
		trial.deliver(user, tool, src)
	return ITEM_INTERACT_SUCCESS

/obj/structure/vestige_morph_station/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	var/datum/vestige_trial/understudy/trial = trial_ref?.resolve()
	if(!istype(trial) || !trial.production || !trial.has_identity(user) || !user.Adjacent(src))
		return
	for(var/obj/item/vestige_morph_parcel/parcel in contents)
		if(parcel.trial_ref?.resolve() == trial)
			user.put_in_hands(parcel)
			trial.refresh_tracker()
			return

/obj/structure/vestige_morph_station/examine(mob/user)
	. = ..()
	var/datum/vestige_trial/understudy/trial = trial_ref?.resolve()
	if(istype(trial) && src != trial.input)
		. += span_notice("It carries [trial.dock_load(src)] units[trial.production ? " of its [trial.capacity]-unit capacity" : ""]. Empty-hand it while wearing the custodian's face to retrieve a parcel.")

/obj/item/vestige_morph_parcel
	name = "marked parcel"
	desc = "A sealed shipment whose printed weight matters to the balance-dock's receiving trays."
	icon = 'icons/obj/storage/wrapping.dmi'
	icon_state = "giftdeliverypackage3"
	inhand_icon_state = "gift"
	w_class = WEIGHT_CLASS_BULKY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	var/cargo_load = 1
	var/datum/weakref/trial_ref

// ===== THE SECOND SKIN =====

/obj/item/vestige_second_skin
	name = "borrowed second skin"
	desc = "Use on an ordinary tool or food to copy its appearance for the scavenger, or on your balance-dock custodian to watch and then borrow its identity. Hold the skin throughout. Activate to reveal or shed. Damage, violence, dropping it, or ending this exact pact sheds the disguise."
	icon = 'icons/obj/stack_objects.dmi'
	icon_state = "sheet-hide"
	w_class = WEIGHT_CLASS_SMALL
	var/datum/weakref/trial_ref
	var/form = SKIN_FORM_NONE
	var/datum/weakref/wearer_ref
	var/saved_appearance
	var/saved_real_name
	var/form_appearance
	var/form_source_type
	var/datum/weakref/form_source_ref
	var/form_expires = 0
	var/datum/weakref/quarry_ref

/obj/item/vestige_second_skin/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/vestige_second_skin/Destroy()
	STOP_PROCESSING(SSobj, src)
	shed_form(feedback = FALSE)
	return ..()

/obj/item/vestige_second_skin/proc/valid_wearer(mob/living/user)
	var/datum/vestige_trial/trial = trial_ref?.resolve()
	return user && trial && trial.owner?.current == user && user.mind?.active_vestige_trial == trial && user.stat == CONSCIOUS && isturf(user.loc) && user.is_holding(src) && wearer_ref?.resolve() == user

/obj/item/vestige_second_skin/dropped(mob/user)
	. = ..()
	shed_form(feedback = FALSE)

/obj/item/vestige_second_skin/attack_self(mob/living/user, list/modifiers)
	if(!valid_wearer(user))
		return
	var/datum/vestige_trial/perfect_copy/trial = trial_ref?.resolve()
	if(form == SKIN_FORM_OBJECT && istype(trial) && trial.reveal(user))
		return
	shed_form()

/obj/item/vestige_second_skin/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	var/datum/vestige_trial/trial = trial_ref?.resolve()
	if(!trial || trial.owner?.current != user || user.mind?.active_vestige_trial != trial || user.stat != CONSCIOUS || !user.is_holding(src) || !user.Adjacent(target))
		return ITEM_INTERACT_BLOCKING
	if(isliving(target))
		return study_person(user, target)
	if(isitem(target))
		return wear_object(user, target)
	return ITEM_INTERACT_BLOCKING

/obj/item/vestige_second_skin/proc/wear_object(mob/living/user, obj/item/shape)
	var/datum/vestige_trial/perfect_copy/trial = trial_ref?.resolve()
	if(!istype(trial) || trial.owner?.current != user || user.mind?.active_vestige_trial != trial || !user.is_holding(src) || form != SKIN_FORM_NONE || shape == src || !trial.matches_role(shape))
		balloon_alert(user, "copy the requested kind of item")
		return ITEM_INTERACT_BLOCKING
	if(!isturf(shape.loc) && shape.loc != user)
		return ITEM_INTERACT_BLOCKING
	apply_form(user, shape)
	form = SKIN_FORM_OBJECT
	form_source_type = shape.type
	form_source_ref = WEAKREF(shape)
	form_expires = world.time + VESTIGE_SKIN_FORM_TIME
	user.add_movespeed_modifier(/datum/movespeed_modifier/vestige_skin_creep)
	to_chat(user, span_notice("You take [shape]'s outline. Hide the original before the scavenger sees you; then hold still for its approach. Activate the skin during its inspection."))
	return ITEM_INTERACT_SUCCESS

/obj/item/vestige_second_skin/proc/study_person(mob/living/user, mob/living/quarry)
	var/datum/vestige_trial/understudy/trial = trial_ref?.resolve()
	if(!istype(trial) || trial.owner?.current != user || user.mind?.active_vestige_trial != trial || !user.is_holding(src) || quarry != trial.actor || form != SKIN_FORM_NONE)
		return ITEM_INTERACT_BLOCKING
	if(!trial.ready)
		trial.start_demo(user)
		return ITEM_INTERACT_SUCCESS
	if(!do_after(user, 2 SECONDS, target = quarry))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(trial) || QDELETED(quarry) || user.mind?.active_vestige_trial != trial || trial.owner?.current != user || !user.is_holding(src) || form != SKIN_FORM_NONE)
		return ITEM_INTERACT_BLOCKING
	apply_form(user, quarry)
	form = SKIN_FORM_PERSON
	saved_real_name = user.real_name
	user.real_name = quarry.real_name
	quarry_ref = WEAKREF(quarry)
	if(!trial.production)
		trial.start_shipment()
	to_chat(user, span_notice("The receiving trays recognize your borrowed face. Divide this shipment in the demonstrated proportion, then use the skin on the central release. Examine the custodian to recall its final loads. Keep the skin in hand."))
	return ITEM_INTERACT_SUCCESS

/// Same appearance recipe as the morph form; this does not change generic NPC perception.
/obj/item/vestige_second_skin/proc/apply_form(mob/living/user, atom/movable/model)
	saved_appearance = user.appearance
	user.appearance = model.appearance
	user.copy_overlays(model)
	user.alpha = max(model.alpha, 150)
	user.transform = initial(model.transform)
	user.pixel_x = model.base_pixel_x
	user.pixel_y = model.base_pixel_y
	form_appearance = user.appearance
	wearer_ref = WEAKREF(user)
	RegisterSignal(user, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_wearer_hurt))
	RegisterSignal(user, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_wearer_armed_attack))
	RegisterSignal(user, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_wearer_unarmed_attack))
	RegisterSignal(user, COMSIG_ATOM_EXAMINE, PROC_REF(on_wearer_examined))
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_wearer_moved))

/obj/item/vestige_second_skin/process(seconds_per_tick)
	if(form == SKIN_FORM_NONE)
		return
	var/mob/living/wearer = wearer_ref?.resolve()
	if(!valid_wearer(wearer) || (form_expires && world.time >= form_expires))
		shed_form()
		return
	stamp_form(wearer)

/obj/item/vestige_second_skin/proc/stamp_form(mob/living/wearer)
	if(!form_appearance)
		return
	var/facing = wearer.dir
	wearer.appearance = form_appearance
	wearer.setDir(facing)

/// Restore only the recorded wearer, even if a different holder invokes cleanup.
/obj/item/vestige_second_skin/proc/shed_form(mob/living/known_wearer, feedback = TRUE)
	if(form == SKIN_FORM_NONE)
		return
	form = SKIN_FORM_NONE
	var/mob/living/wearer = wearer_ref?.resolve()
	if(wearer && !QDELETED(wearer))
		UnregisterSignal(wearer, list(COMSIG_MOB_APPLY_DAMAGE, COMSIG_MOB_ITEM_ATTACK, COMSIG_LIVING_UNARMED_ATTACK, COMSIG_ATOM_EXAMINE, COMSIG_MOVABLE_MOVED))
		wearer.remove_movespeed_modifier(/datum/movespeed_modifier/vestige_skin_creep)
		if(saved_appearance)
			wearer.appearance = saved_appearance
		if(saved_real_name)
			wearer.real_name = saved_real_name
		wearer.regenerate_icons()
		if(feedback)
			to_chat(wearer, span_notice("The skin lets the borrowed shape go."))
	wearer_ref = null
	saved_appearance = null
	saved_real_name = null
	form_appearance = null
	form_source_type = null
	form_source_ref = null
	form_expires = 0
	quarry_ref = null

/obj/item/vestige_second_skin/proc/on_wearer_hurt(mob/living/source, damage, damagetype)
	SIGNAL_HANDLER
	if(damage > 0)
		shed_form()

/obj/item/vestige_second_skin/proc/on_wearer_armed_attack(mob/living/source, mob/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	shed_form()

/obj/item/vestige_second_skin/proc/on_wearer_unarmed_attack(mob/living/source, atom/attack_target, proximity_flag, list/modifiers)
	SIGNAL_HANDLER
	if(source.combat_mode)
		shed_form()

/obj/item/vestige_second_skin/proc/on_wearer_examined(mob/living/source, mob/examiner, list/examine_list)
	SIGNAL_HANDLER
	if(get_dist(examiner, source) <= 3)
		examine_list += span_warning("It doesn't look quite right...")

/// Visible movement must count even if the wearer returns or reveals between scene ticks.
/obj/item/vestige_second_skin/proc/on_wearer_moved(mob/living/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	SIGNAL_HANDLER
	if(!momentum_change || form != SKIN_FORM_OBJECT)
		return
	var/datum/vestige_trial/perfect_copy/trial = trial_ref?.resolve()
	if(!istype(trial) || !trial.watched_spot || trial.watched_spot.shuttle_moving || get_turf(trial.watched_spot) == get_turf(source))
		return
	trial.reject_shape(source, "objects don't walk!")

/datum/movespeed_modifier/vestige_skin_creep
	multiplicative_slowdown = VESTIGE_SKIN_CREEP_SLOWDOWN

#undef VESTIGE_SKIN_FORM_TIME
#undef VESTIGE_SKIN_CREEP_SLOWDOWN
#undef SKIN_FORM_NONE
#undef SKIN_FORM_OBJECT
#undef SKIN_FORM_PERSON
/**
 * # The Facsimile: morph boons
 *
 * The Understudy's half of the bargain: what an eager, imitative thing pays
 * with when a trial is kept. The morph's body IS the antag, a pile of flesh
 * that plays prop hunt with the crew, so nothing here grants the morph.
 * Each boon is the human-sized cut of one of its tricks: the disguise
 * (rebuilt on the shapeshift-spell rail. Upstream's assume_form action is
 * explicitly not carbon-safe, see the Borrowed Shape doc comment), the
 * swallowing (rebuilt as a one-slot internal stash rather than the morph's
 * everything-eating maw), the ambush (built on the same charge primitive the
 * Aperture's dash already ports to humans), and the boneless squeeze (the
 * ventcrawl trait itself). Patron and trials live in the theme file; only
 * the boons and their spells are defined here.
 */

// Tuning constants for the Understudy's ports (file-local, #undef at bottom)

/// Health of the borrowed shape (kept equal to human maxHealth so converted damage carries ~1:1)
#define VESTIGE_MIMIC_HEALTH 100
/// Varspeed slowdown of the base borrowed shape, a slow, suspicious creep
#define VESTIGE_MIMIC_CREEP_SPEED 4
/// Varspeed slowdown of the flawless shape, very nearly a walking pace
#define VESTIGE_MIMIC_FLAWLESS_SPEED 1
/// Lockout before a broken Borrowed Shape can be worn again
#define VESTIGE_MIMIC_REFORM_COOLDOWN (15 SECONDS)
/// Lockout before a broken Perfect Facsimile can be worn again
#define VESTIGE_MIMIC_FLAWLESS_REFORM (6 SECONDS)

/// Beats between gullet operations (swallow or regurgitate)
#define VESTIGE_GULLET_COOLDOWN (5 SECONDS)
/// How long one swallow channel takes, spent visibly gulping
#define VESTIGE_GULLET_SWALLOW_TIME (3 SECONDS)
/// How long bringing a keeping back up takes
#define VESTIGE_GULLET_HEAVE_TIME (1 SECONDS)
/// Keepings the base gullet holds
#define VESTIGE_GULLET_SLOTS 1
/// Keepings the bottomless gullet holds
#define VESTIGE_GLUTTONY_SLOTS 3
/// Brute AND burn each that swallowing edible matter mends (bottomless gullet only)
#define VESTIGE_GLUTTONY_FEED_HEAL 10

/// Tiles of the ambush pounce
#define VESTIGE_POUNCE_DISTANCE 3
/// How long a pounced target stays floored
#define VESTIGE_POUNCE_KNOCKDOWN (1.5 SECONDS)
/// Beats per pounce
#define VESTIGE_POUNCE_COOLDOWN (25 SECONDS)
/// Bonus force the pounce lends your next melee strike
#define VESTIGE_AMBUSH_BONUS_FORCE 10
/// How long the lent savagery waits for that strike
#define VESTIGE_AMBUSH_WINDOW (3 SECONDS)

/// Trait source for the Understudy's body-work
#define VESTIGE_MORPH_TRAIT "vestige_morph_boon"

// ===== BOONS =====

// --- Chain: the disguise ---

/datum/vestige_boon/spell/mimic_form
	name = "Borrowed Shape"
	desc = "Point at any ordinary object next to you and I will teach you to BE it, dents and all. You can even creep around in it, slowly. One hit given or taken and the role is over. Up close you do look a bit damp. I am working on the damp."
	grant_text = "Your outline goes soft for a moment, waiting to be told what it is."
	spell_type = /datum/action/cooldown/spell/shapeshift/vestige_mimic

/datum/vestige_boon/spell/mimic_form/flawless
	name = "Perfect Facsimile"
	desc = "My best work. No, YOUR best work, I only coached. The damp is gone, I fixed the damp. You move at very nearly your own pace, anyone can put their nose right up against you and find nothing wrong, and swapping shapes is almost instant now."
	grant_text = "The last tell dries up. You are bone dry and completely convincing."
	upgrades_from = /datum/vestige_boon/spell/mimic_form
	spell_type = /datum/action/cooldown/spell/shapeshift/vestige_mimic/flawless

// --- Chain: the swallow ---

/datum/vestige_boon/spell/devour
	name = "The Gullet"
	desc = "A pocket! Inside! I made you a pocket on the inside. Swallow something and it stays down there, past any pat-down or scanner, until you ask for it back. It comes back in one piece. Slightly damp."
	grant_text = "Something in your throat unhinges, politely, and waits."
	spell_type = /datum/action/cooldown/spell/vestige_devour

/datum/vestige_boon/spell/devour/gluttony
	name = "Bottomless Gullet"
	desc = "Wider! Several things at once now, and bigger ones. I practiced on furniture. And if what you swallow happens to be food, the gullet patches you up a little on the way down."
	grant_text = "Your new pocket yawns. It isn't picky anymore."
	upgrades_from = /datum/vestige_boon/spell/devour
	spell_type = /datum/action/cooldown/spell/vestige_devour/gluttony

// --- Standalone: the ambush ---

/datum/vestige_boon/spell/ambush_instinct
	name = "Ambush Instinct"
	desc = "The oldest trick there is: the thing that was standing still and suddenly isn't. A short pounce that knocks whoever you land on flat, and for a moment afterward your next melee hit lands much harder."
	grant_text = "Your weight settles onto the balls of your feet."
	spell_type = /datum/action/cooldown/mob_cooldown/charge/vestige_pounce

// --- Standalone: the boneless squeeze ---

/datum/vestige_boon/rubber_bones
	name = "Rubber Bones"
	desc = "I loosened everything. Don't ask how. Strip all the way down (the ducting insists) and you can pour yourself through the vents the way I do. Climbing gets quick and short falls stop hurting. This is in the meat, not the soul, so a new body has to be loosened again."
	grant_text = "Every joint in you loosens by a degree no anatomy chart allows."
	radial_icon = 'icons/obj/antags/abductor.dmi'
	radial_icon_state = "vent"

/**
 * Body-work, not a spell: the traits go on the body and stay there. Lost with
 * the body by nature; the vestige record re-runs grant() on respawn restore,
 * which re-loosens whatever the player is wearing by then (add_traits is
 * idempotent per source, so restoring into the same body double-grants
 * nothing).
 *
 * TRAIT_VENTCRAWLER_NUDE over TRAIT_VENTCRAWLER_ALWAYS, deliberately: crawl-
 * with-items on a human (the trait monkeys and rat-organ infusees get is the
 * nude one; ALWAYS is reserved for mobs whose whole body is the antag) would
 * make every vent a zero-counterplay smuggling lane. Nude-only keeps the
 * morph fantasy (the flesh does it bare) and the tradeoff real. Note the
 * intended synergy: the nudity check counts equipped and held items only
 * (get_equipped_items + get_num_held_items, ventcrawling.dm), so a keeping
 * swallowed into the Gullet rides through the ducts with you. That is the
 * combo, and it costs two boons.
 *
 * TRAIT_FREERUNNING is the cheap verified flavor bonus: short falls land
 * unscathed (living.dm z-impact) and climbing is quick (climbable.dm), both
 * exactly what rubber bones ought to do, no new code.
 */
/datum/vestige_boon/rubber_bones/grant(mob/living/user, datum/mind/owner)
	..()
	user.add_traits(list(TRAIT_VENTCRAWLER_NUDE, TRAIT_FREERUNNING), VESTIGE_MORPH_TRAIT)
	to_chat(user, span_notice("Stripped bare, you could pour yourself through a ventilation duct. Fences and short drops suddenly look easy."))

// ===== BORROWED SHAPE =====

/**
 * The morph's disguise, rebuilt for a human on the shapeshift-spell rail
 * rather than ported. Upstream's own primitive
 * (/datum/action/cooldown/mob_cooldown/assume_form) copies the target's
 * appearance onto the OWNER and resets it with initial(icon)/initial(
 * icon_state), its header warns it "will likely shit the bricks" on
 * anything carbon; a human's sprite is overlay-composited and that reset
 * would wreck it. So the appearance copy happens on a disposable basic mob
 * instead (born, imprinted once with the morph's exact field-set, deleted on
 * unshift, the un-resettable reset never has to happen), and the human
 * rides inside via /datum/status_effect/shapechange_mob/from_spell, the same
 * rail every wizard shapeshift trusts.
 *
 * Safety rails, all load-bearing and all checked against source:
 * - Shape death restores the caster (from_spell/on_shape_death; we set
 *   die_with_shapeshifted_form = FALSE), with damage converted back.
 * - Caster death/gib inside mirrors onto the shape (on_caster_death), qdel
 *   of either party restores or cleans up (on_caster_deleted / on_remove).
 * - Wabbajack and mob-type changes are intercepted (on_pre_wabbajack).
 * - Remove() (boon upgrade replacing this spell, mind leaving) unshifts
 *   first (shapeshift/Remove -> unshift_owner). Nobody is stranded as a
 *   crate.
 * - Casting while ventcrawling is refused outright in can_cast_spell:
 *   upstream's rail for shifting-in-a-vent is eject_from_vents, which GIBS.
 *   Refusing the cast is the only version of that rail a player deserves.
 * - The pounce/beckon class of TRAIT_NOTELEPORT concerns doesn't apply:
 *   nothing here teleports; the caster is stored inside the shape mob and
 *   emerges exactly where it stood.
 * - Taking damage or attacking breaks the form (see the mob below); every
 *   exit from the shape pays the reform cooldown via the do_unshapeshift
 *   override, and the fork quirk (Activate() ignores cast()'s return) is
 *   irrelevant because all bail-outs live in before_cast.
 *
 * Known accepted quirk, shared with every upstream shapeshift: unshifting
 * fully heals then re-applies total damage as BRUTE (from_spell/
 * after_unchange), so damage types launder through a form cycle. Wizards
 * have lived with this forever; the reform cooldown makes it a terrible
 * medkit.
 */
/datum/action/cooldown/spell/shapeshift/vestige_mimic
	name = "Borrowed Shape"
	desc = "Click a nearby object to turn into a copy of it. You can creep around slowly, but nothing else. Any hit breaks the disguise, and a broken shape takes time to wear again. Use again to drop it."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "chameleon_skin"
	background_icon_state = "bg_changeling"
	overlay_icon_state = "bg_changeling_border"
	cooldown_time = VESTIGE_MIMIC_REFORM_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	// The model is picked by clicking it, the morph's own grammar (assume_form.dm):
	// point at the thing you want to be. What actually changes is always the
	// caster, so the shapeshift rail below is handed the owner, never the click
	click_to_activate = TRUE
	ranged_mousepointer = 'icons/effects/mouse_pointers/supplypod_target.dmi'
	possible_shapes = list(/mob/living/basic/vestige_mimic)
	die_with_shapeshifted_form = FALSE
	/// The object clicked in before_cast, consumed by create_shapeshift_mob. Same-cast handoff only.
	var/atom/movable/chosen_model
	/// Stuff no understudy should play. Mirrors the morph's own blacklist, minus entries view() can't return.
	var/static/list/blacklist_typecache = typecacheof(list(
		/obj/effect,
		/obj/energy_ball,
		/obj/narsie,
		/obj/singularity,
	))

/datum/action/cooldown/spell/shapeshift/vestige_mimic/flawless
	name = "Perfect Facsimile"
	desc = "Click a nearby object to turn into a copy of it, at near walking speed and with no tell when examined. Any hit breaks the disguise. Use again to drop it."
	button_icon_state = "transform"
	cooldown_time = VESTIGE_MIMIC_FLAWLESS_REFORM
	possible_shapes = list(/mob/living/basic/vestige_mimic/flawless)

/datum/action/cooldown/spell/shapeshift/vestige_mimic/Destroy()
	chosen_model = null
	return ..()

// The gib rail, replaced with a refusal: upstream handles "shapeshifted while
// ventcrawling into a non-crawler" by gibbing (eject_from_vents). A Rubber
// Bones crawler who tries to become a wrench mid-duct gets told no instead.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE
	if(owner.movement_type & VENTCRAWLING)
		if(feedback)
			to_chat(owner, span_warning("There is no room in here to be anything else."))
		return FALSE
	return TRUE

// Shedding a shape needs no target. Someone caught out as a crate should not
// have to arm a cursor and click themselves to stop being a crate. Only picking
// a NEW shape asks for a click.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/Trigger(mob/clicker, trigger_flags, atom/target)
	if(isnull(target) && wearing_a_shape())
		if(!IsAvailable(feedback = TRUE))
			return FALSE
		return PreActivate(owner)
	return ..()

/// Whether the owner is currently inside a borrowed shape
/datum/action/cooldown/spell/shapeshift/vestige_mimic/proc/wearing_a_shape()
	if(!isliving(owner))
		return FALSE
	var/mob/living/living_owner = owner
	return !!living_owner.has_status_effect(/datum/status_effect/shapechange_mob/from_spell)

// Clicking yourself (or the ability, while wearing a shape) sheds it; clicking
// anything else offers it as a model.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/is_valid_target(atom/cast_on)
	if(cast_on == owner)
		if(!wearing_a_shape())
			owner.balloon_alert(owner, "point at something else!")
			return FALSE
		return TRUE
	if(wearing_a_shape())
		owner.balloon_alert(owner, "already wearing one!")
		return FALSE
	return can_copy(cast_on)

// Forming takes its model from the click and skips the immediate cooldown, so
// the shape can always be shrugged off at will. Unforming falls through
// untouched: Activate's StartCooldown after cast() is exactly the reform
// lockout. Either way the shapeshift rail upstream is handed the OWNER, the
// click target is a model to copy, not a thing to transform.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/before_cast(atom/cast_on)
	var/atom/movable/model = (cast_on == owner) ? null : cast_on
	. = ..(owner)
	if(. & SPELL_CANCEL_CAST)
		return
	chosen_model = null
	if(wearing_a_shape())
		return // unforming: no model to copy, and the cooldown SHOULD start
	// The prop can be picked up or destroyed between the click and here
	if(QDELETED(model) || !can_copy(model))
		return . | SPELL_CANCEL_CAST
	if(QDELETED(src) || QDELETED(owner) || !can_cast_spell(feedback = FALSE))
		return . | SPELL_CANCEL_CAST
	chosen_model = model
	return . | SPELL_NO_IMMEDIATE_COOLDOWN

/// Whether a clicked atom is something an understudy could pass for: a free-standing, visible, ordinary object within arm's reach.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/proc/can_copy(atom/movable/model)
	if(!isobj(model))
		owner.balloon_alert(owner, "can't be that!")
		return FALSE
	if(!isturf(model.loc)) // free-standing props only; nothing out of someone's hand
		owner.balloon_alert(owner, "not while it's held!")
		return FALSE
	if(model.invisibility || is_type_in_typecache(model, blacklist_typecache))
		owner.balloon_alert(owner, "can't be that!")
		return FALSE
	if(isitem(model))
		var/obj/item/item_model = model
		if(item_model.item_flags & ABSTRACT)
			owner.balloon_alert(owner, "can't be that!")
			return FALSE
	if(!(model in view(1, owner)))
		owner.balloon_alert(owner, "too far to study!")
		return FALSE
	return TRUE

// The imprint happens at birth, before the shapechange status effect moves
// the player in, one tick, no visible blob frame in practice
/datum/action/cooldown/spell/shapeshift/vestige_mimic/create_shapeshift_mob(atom/loc)
	var/mob/living/basic/vestige_mimic/shape = ..()
	var/atom/movable/model = chosen_model
	chosen_model = null
	if(istype(shape) && !QDELETED(model))
		shape.imprint(model)
	return shape

// Every exit from the shape: recast, break-on-damage, break-on-attack,
// Remove, funnels through here, so every exit pays the reform lockout.
// (Voluntary recasts also pay it via Activate; same value, harmless restart.)
/datum/action/cooldown/spell/shapeshift/vestige_mimic/do_unshapeshift(mob/living/caster)
	. = ..()
	StartCooldown()

// The transformation theatre: sound, wobble, and a message that names the
// prop rather than the player (the crowd saw who melted; the fun is in what
// stands there after)
/datum/action/cooldown/spell/shapeshift/vestige_mimic/cast(atom/cast_on)
	var/unforming = wearing_a_shape()
	// cast_on is whatever was clicked; the shift itself always happens to the caster
	. = ..(owner)
	if(QDELETED(owner))
		return
	if(unforming)
		playsound(owner, 'sound/effects/splat.ogg', 50, TRUE)
		owner.visible_message(
			span_warning("[owner] shrugs the borrowed shape off like a wet coat!"),
			span_notice("You let the shape go. Your own outline feels roomy by comparison."),
		)
		return
	// Formed: owner is now the shape, already wearing the prop's face.
	// (If the shift somehow failed, the rail stack-traces that itself.
	// There is no shape and no theatre to perform.)
	if(!istype(owner, /mob/living/basic/vestige_mimic))
		return
	playsound(owner, 'sound/effects/magic/mutate.ogg', 50, TRUE)
	owner.visible_message(
		span_warning("With a wet squelch, where they stood there is only... [owner]."),
		span_boldnotice("You pour yourself into the shape. Now hold still."),
	)
	apply_wibbly_filters(owner)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(remove_wibbly_filters), owner, 0.5 SECONDS), 1 SECONDS)

/**
 * The borrowed shape itself: a disposable basic mob wearing an object's
 * appearance (the morph's exact field-set, appearance, overlays, alpha,
 * transform, base pixel offsets, which also carries name and desc for the
 * examine header). It has no attacks and no hands; it can only creep, be
 * believed, and come apart. It never resets its appearance, every exit
 * deletes it, which is the whole reason the carbon-unsafe reset problem
 * disappears.
 *
 * Health is 1:1 with a human so converted damage carries honestly. Atmos is
 * moot for it (morph pattern: habitable_atmos = null, TCMB floor), a crate
 * does not shiver, and the human inside is in stasis. Med huds are blanked
 * the way the morph blanks them: a health bar over a chair is a hard tell.
 */
/mob/living/basic/vestige_mimic
	name = "borrowed shape"
	desc = "Something doing an impression of a thing. It hasn't quite landed it."
	gender = NEUTER
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "morph"
	icon_living = "morph"
	speak_emote = list("gurgles")
	maxHealth = VESTIGE_MIMIC_HEALTH
	health = VESTIGE_MIMIC_HEALTH
	speed = VESTIGE_MIMIC_CREEP_SPEED
	melee_damage_lower = 0
	melee_damage_upper = 0
	pass_flags = PASSTABLE
	habitable_atmos = null
	minimum_survivable_temperature = TCMB
	/// The prop being played, for examine delegation (weakref: the prop owes us nothing)
	var/datum/weakref/model_ref
	/// Whether close examination reads the damp tell. The flawless shape dried it out.
	var/has_tell = TRUE
	/// Guards against stacked break timers when several hits land in one tick
	var/breaking = FALSE

/mob/living/basic/vestige_mimic/flawless
	speed = VESTIGE_MIMIC_FLAWLESS_SPEED
	has_tell = FALSE

/mob/living/basic/vestige_mimic/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_damaged))

/// The morph's own appearance-copy field-set, applied once at birth and never reset
/mob/living/basic/vestige_mimic/proc/imprint(atom/movable/model)
	appearance = model.appearance
	copy_overlays(model)
	alpha = max(model.alpha, 150)
	transform = initial(model.transform)
	pixel_x = model.base_pixel_x
	pixel_y = model.base_pixel_y
	real_name = model.name
	model_ref = WEAKREF(model)

// Examine is the prop's own, morph-style, with the near-range tell the
// flawless shape exists to remove. If the prop is gone, the impression
// carries on from memory (base examine of a wet shape, its own tell).
/mob/living/basic/vestige_mimic/examine(mob/user)
	var/atom/movable/model = model_ref?.resolve()
	if(isnull(model))
		. = ..()
	else
		. = model.examine(user)
	if(has_tell && get_dist(user, src) <= 3)
		. += span_warning("It looks slightly damp.")

// A health bar floating over a chair is a hard tell, blank the huds, morph-style
/mob/living/basic/vestige_mimic/med_hud_set_health()
	set_hud_image_state(HEALTH_HUD, null)

/mob/living/basic/vestige_mimic/med_hud_set_status()
	set_hud_image_state(STATUS_HUD, null)

// Attacking breaks the form and the swing never lands: you burst OUT to
// fight (Ambush Instinct is one click away), you do not fight as furniture
/mob/living/basic/vestige_mimic/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	. = ..()
	if(!.)
		return FALSE
	if(target != src)
		queue_break()
	return FALSE

/// Any damage breaks the form, deferred a tick so the blow finishes resolving first
/mob/living/basic/vestige_mimic/proc/on_damaged(datum/source)
	SIGNAL_HANDLER
	// The shapeshift rail copies existing wounds before putting the caster
	// inside the shape. Those wounds are not a new hit against the disguise.
	var/datum/status_effect/shapechange_mob/from_spell/shift = has_status_effect(/datum/status_effect/shapechange_mob/from_spell)
	if(!shift || shift.caster_mob?.loc != src)
		return
	queue_break()

/// Queues the break exactly once, off the current call stack (apply_damage
/// signals fire BEFORE damage lands; unshifting mid-stack would qdel this mob
/// under the damage proc's feet)
/mob/living/basic/vestige_mimic/proc/queue_break()
	if(breaking)
		return
	breaking = TRUE
	addtimer(CALLBACK(src, PROC_REF(break_form)), 1)

/**
 * Comes apart, restoring the rider. Routed through the granting spell's
 * do_unshapeshift so the reform lockout is paid; if the spell is somehow
 * gone, removing the status effect is the rail's own supported teardown
 * (on_remove -> restore_caster), nobody is ever left inside. If damage
 * outright killed the shape first, on_shape_death already restored the
 * caster and deleted us, and this finds nothing to do.
 */
/mob/living/basic/vestige_mimic/proc/break_form()
	breaking = FALSE
	if(QDELETED(src))
		return
	var/datum/status_effect/shapechange_mob/from_spell/shift = has_status_effect(/datum/status_effect/shapechange_mob/from_spell)
	if(!shift)
		return
	visible_message(
		span_boldwarning("[src] shudders, splits along no seam at all, and comes apart!"),
		span_userdanger("The shape gives way under you!"),
	)
	playsound(src, 'sound/effects/splat.ogg', 60, TRUE)
	var/datum/action/cooldown/spell/shapeshift/source_spell = shift.source_weakref?.resolve()
	if(istype(source_spell, /datum/action/cooldown/spell/shapeshift/vestige_mimic))
		source_spell.do_unshapeshift(src)
	else
		remove_status_effect(/datum/status_effect/shapechange_mob/from_spell)

// ===== THE GULLET =====

/**
 * The morph's swallowing, rebuilt as an internal stash. The morph's own
 * version is eatable.forceMove(src) plus /datum/element/content_barfer to
 * spill on death, content_barfer barfs a mob's ENTIRE contents, which on a
 * human means organs, implants and worn equipment, so the port keeps its own
 * container instead: a real /obj holder riding nullspace, owned by the spell
 * (mind-bound, the stash follows the player across bodies with the action,
 * exactly like the flavor says: it is in YOUR gullet, whoever you are today).
 *
 * One action, two verbs, fork-quirk-proof (all bail-outs are before_cast
 * SPELL_CANCEL_CAST, since Activate() ignores cast()'s return): cast with an
 * item in your active hand to channel it down; cast empty-handed to bring a
 * keeping back up (radial pick when the bottomless version holds several).
 *
 * Nothing is ever destroyed silently:
 * - Owner death or gib spills every keeping at the body (COMSIG_LIVING_DEATH,
 *   re-registered on each Grant so it tracks body swaps; on gib the items are
 *   safe in nullspace, not in the corpse, and spill at the turf).
 * - The spell being destroyed (a boon upgrade replacing it) spills at the
 *   owner's feet first. Upgrading The Gullet means briefly, humiliatingly,
 *   coughing up your stash for the wider one.
 */
/datum/action/cooldown/spell/vestige_devour
	name = "The Gullet"
	desc = "Swallow the item in your active hand. Use with an empty hand to bring it back up, intact and slightly damp."
	button_icon = 'icons/mob/actions/actions_animal.dmi'
	button_icon_state = "regurgitate"
	background_icon_state = "bg_changeling"
	overlay_icon_state = "bg_changeling_border"
	cooldown_time = VESTIGE_GULLET_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// Keepings the gullet holds at once
	var/gullet_slots = VESTIGE_GULLET_SLOTS
	/// Largest w_class that goes down
	var/max_swallow_class = WEIGHT_CLASS_NORMAL
	/// Brute AND burn each that swallowing edible matter mends (0 = base gullet doesn't)
	var/organic_heal = 0
	/// The stash itself: a real container living in nullspace for the spell's whole life
	var/obj/vestige_gullet/stash
	/// Item cleared to go down, handed from before_cast to cast. Same-cast handoff only.
	var/obj/item/pending_swallow
	/// Keeping cleared to come up, handed from before_cast to cast. Same-cast handoff only.
	var/obj/item/pending_regurgitate
	/// Covers selection and channeling, before a successful cast starts cooldown.
	var/gullet_busy = FALSE

/datum/action/cooldown/spell/vestige_devour/gluttony
	name = "Bottomless Gullet"
	desc = "Swallow several items, bulky ones included. Use with an empty hand to bring one back up. Swallowed food heals you a little."
	button_icon = 'icons/mob/actions/actions_slime.dmi'
	button_icon_state = "slimeconsume"
	gullet_slots = VESTIGE_GLUTTONY_SLOTS
	max_swallow_class = WEIGHT_CLASS_BULKY
	organic_heal = VESTIGE_GLUTTONY_FEED_HEAL

/datum/action/cooldown/spell/vestige_devour/New(Target)
	. = ..()
	stash = new(null)

/datum/action/cooldown/spell/vestige_devour/Destroy()
	// Spill before the action goes: an upgrade replacing this spell must
	// never eat the keepings with it
	var/turf/spill_loc = owner ? get_turf(owner) : null
	if(spill_loc && length(stash?.contents))
		owner.visible_message(
			span_warning("[owner] doubles over and heaves [owner.p_their()] gullet inside out!"),
			span_notice("The old gullet turns itself inside out to make room for the new one. Pick your things back up."),
		)
		playsound(owner, 'sound/effects/splat.ogg', 50, TRUE)
	empty_gullet(spill_loc)
	QDEL_NULL(stash)
	pending_swallow = null
	pending_regurgitate = null
	return ..()

// The death-spill signal tracks whatever body currently carries the mind:
// registered on each Grant, scrubbed from the old body by each Remove
// (Grant calls Remove(previous_owner) itself, so swaps stay clean)
/datum/action/cooldown/spell/vestige_devour/Grant(mob/grant_to)
	. = ..()
	if(owner)
		RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death), override = TRUE)

/datum/action/cooldown/spell/vestige_devour/Remove(mob/remove_from)
	if(remove_from)
		// The action's base QDELETING handler calls Remove before the body loses its turf.
		// Normal mind transfers keep the stash; deleting its carrier must spill it safely.
		if(QDELETED(remove_from))
			empty_gullet(get_turf(remove_from))
		UnregisterSignal(remove_from, COMSIG_LIVING_DEATH)
	return ..()

/// Death or gib: the gullet keeps nothing from a corpse, everything spills where the body dropped
/datum/action/cooldown/spell/vestige_devour/proc/on_owner_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(!length(stash?.contents))
		return
	var/turf/spill_loc = get_turf(source)
	if(!spill_loc)
		return
	source.visible_message(
		span_warning("[source]'s throat convulses, and everything in [source.p_their()] gullet comes back up!"),
		blind_message = span_hear("You hear something wet coming back up."),
	)
	playsound(spill_loc, 'sound/effects/splat.ogg', 50, TRUE)
	empty_gullet(spill_loc)

/// Turns the stash out onto the given turf. With no turf there is nowhere left to put anything. Noted loudly, because it should never happen while contents exist.
/datum/action/cooldown/spell/vestige_devour/proc/empty_gullet(turf/spill_loc)
	if(!length(stash?.contents))
		return
	if(!spill_loc)
		stack_trace("vestige gullet emptied with no spill turf; its contents were destroyed with it")
		return
	for(var/obj/item/kept as anything in stash.contents)
		kept.forceMove(spill_loc)

// Both verbs resolve and channel here so an interrupted gulp (or a backed-out
// menu) never spends the cooldown
/datum/action/cooldown/spell/vestige_devour/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	if(gullet_busy || !gullet_menu_check(owner))
		return . | SPELL_CANCEL_CAST
	gullet_busy = TRUE
	var/prepared = prepare_gullet(owner)
	gullet_busy = FALSE
	return . | prepared

/// Keep all sleeping operations tied to the body which began this gulp.
/datum/action/cooldown/spell/vestige_devour/proc/prepare_gullet(mob/living/caster)
	pending_swallow = null
	pending_regurgitate = null
	var/obj/item/held = caster.get_active_held_item()
	if(held)
		if(!validate_swallow(held))
			return SPELL_CANCEL_CAST
		caster.visible_message(
			span_warning("[caster]'s throat begins to work, horribly, around [held]..."),
			span_notice("You unhinge something no anatomy chart says you have, and start [held] on its way down."),
		)
		playsound(caster, 'sound/items/eatfood.ogg', 40, TRUE)
		if(!do_after(caster, VESTIGE_GULLET_SWALLOW_TIME, target = held, extra_checks = CALLBACK(src, PROC_REF(gullet_menu_check), caster)))
			return SPELL_CANCEL_CAST
		// Re-validate: the meal may have been snatched, dropped or crammed in beside a full load mid-gulp
		if(!gullet_menu_check(caster) || QDELETED(held) || caster.get_active_held_item() != held || !validate_swallow(held, feedback = FALSE))
			return SPELL_CANCEL_CAST
		pending_swallow = held
		return NONE
	// Empty-handed: bring a keeping back up
	if(!length(stash.contents))
		caster.balloon_alert(caster, "nothing down there!")
		return SPELL_CANCEL_CAST
	var/obj/item/choice = pick_from_gullet(caster)
	if(!gullet_menu_check(caster) || QDELETED(choice) || choice.loc != stash)
		return SPELL_CANCEL_CAST
	caster.visible_message(
		span_warning("[caster]'s throat bulges going the wrong way..."),
		span_notice("You call [choice] back up."),
	)
	if(!do_after(caster, VESTIGE_GULLET_HEAVE_TIME, extra_checks = CALLBACK(src, PROC_REF(gullet_menu_check), caster)))
		return SPELL_CANCEL_CAST
	if(!gullet_menu_check(caster) || QDELETED(choice) || choice.loc != stash)
		return SPELL_CANCEL_CAST
	pending_regurgitate = choice
	return NONE

/// Whether an item can go down right now, balloon feedback included
/datum/action/cooldown/spell/vestige_devour/proc/validate_swallow(obj/item/meal, feedback = TRUE)
	if(HAS_TRAIT(meal, TRAIT_NODROP))
		if(feedback)
			owner.balloon_alert(owner, "it won't leave your hand!")
		return FALSE
	if(meal.item_flags & ABSTRACT)
		return FALSE
	if(meal.w_class > max_swallow_class)
		if(feedback)
			owner.balloon_alert(owner, "too big to go down!")
		return FALSE
	if(length(stash.contents) >= gullet_slots)
		if(feedback)
			owner.balloon_alert(owner, "gullet is full!")
		return FALSE
	return TRUE

/// Picks the keeping to bring up: the only one, or a radial when the bottomless version holds several
/datum/action/cooldown/spell/vestige_devour/proc/pick_from_gullet(mob/living/caster)
	if(length(stash.contents) == 1)
		return stash.contents[1]
	var/list/options = list()
	var/list/by_key = list()
	for(var/obj/item/kept in stash.contents)
		var/key = kept.name
		var/copy = 2
		while(!isnull(by_key[key]))
			key = "[kept.name] ([copy])"
			copy++
		by_key[key] = kept
		options[key] = image(icon = kept.icon, icon_state = kept.icon_state)
	var/choice = show_radial_menu(caster, caster, options, custom_check = CALLBACK(src, PROC_REF(gullet_menu_check), caster), tooltips = TRUE)
	if(!choice)
		return null
	return by_key[choice]

/// Menu validity for the regurgitation radial
/datum/action/cooldown/spell/vestige_devour/proc/gullet_menu_check(mob/living/caster)
	return !QDELETED(src) && !QDELETED(stash) && !QDELETED(caster) && isliving(caster) && owner == caster && caster.stat == CONSCIOUS

/datum/action/cooldown/spell/vestige_devour/cast(atom/cast_on)
	. = ..()
	if(pending_swallow)
		var/obj/item/meal = pending_swallow
		pending_swallow = null
		if(!owner.transferItemToLoc(meal, stash)) // a nodrop curse landing mid-gulp still wins
			owner.balloon_alert(owner, "it won't go down!")
			return
		playsound(owner, 'sound/effects/magic/demon_consume.ogg', 30, TRUE)
		owner.visible_message(
			span_warning("[owner] swallows [meal] whole!"),
			span_notice("[meal] settles into the gullet, safe past any pat-down."),
		)
		if(organic_heal && IS_EDIBLE(meal) && isliving(owner))
			var/mob/living/fed = owner
			fed.heal_overall_damage(brute = organic_heal, burn = organic_heal, required_bodytype = BODYTYPE_ORGANIC)
			to_chat(fed, span_boldnotice("The gullet takes its cut of the meal and patches you up a little."))
		return
	if(pending_regurgitate)
		var/obj/item/prize = pending_regurgitate
		pending_regurgitate = null
		if(prize.loc != stash)
			return
		prize.forceMove(get_turf(owner))
		owner.put_in_hands(prize)
		playsound(owner, 'sound/effects/splat.ogg', 40, TRUE)
		owner.visible_message(
			span_warning("[owner] gags once, and produces [prize] from somewhere no pocket should be!"),
			span_notice("[prize] comes back up intact. Slightly damp."),
		)

/// The stash: a real container that spends its whole life in nullspace, held by the spell
/obj/vestige_gullet
	name = "gullet"
	desc = "A pocket of somewhere warm and wet. You should not be able to read this."

// ===== AMBUSH INSTINCT =====

/**
 * The morph's glomp-from-hiding, built on the generic charge action, the
 * same primitive the Aperture's Cosmic Dash already grants to plain humans
 * (in-module precedent; the charge only ever touches owner). The leap is a
 * move-loop, not a teleport: it bumps to a stop on anything dense, so no
 * TRAIT_NOTELEPORT-class rule is ever sidestepped. destroy_objects stays off
 * (nobody's ambush should explode a wall) and the base charge's
 * meteor-impact footfalls are silenced. It is an AMBUSH.
 *
 * Landing on someone floors them briefly; every pounce, hit or miss, leaves
 * a short window of lent savagery (see the status effect below). Bursting
 * out of a Borrowed Shape into a pounce is the intended combo, but a very
 * patient person standing very still gets the same discount.
 */
/datum/action/cooldown/mob_cooldown/charge/vestige_pounce
	name = "Ambush Instinct"
	desc = "Leap a short distance at a target. They're knocked down, and your next melee hit lands much harder."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "feral_mode_on"
	background_icon_state = "bg_changeling"
	overlay_icon_state = "bg_changeling_border"
	cooldown_time = VESTIGE_POUNCE_COOLDOWN
	shared_cooldown = NONE
	charge_distance = VESTIGE_POUNCE_DISTANCE
	charge_past = 0
	charge_damage = 0
	destroy_objects = FALSE

/datum/action/cooldown/mob_cooldown/charge/vestige_pounce/Activate(atom/target_atom)
	// The honored combo: pouncing while wearing a Borrowed Shape bursts the
	// shape first, and the pouncer erupts from it mid-leap. break_form
	// restores the player and re-grants this action to them synchronously
	// (mind transfer), so owner is the human again by the time the charge
	// actually launches, and the mimic's reform lockout is paid as normal.
	if(istype(owner, /mob/living/basic/vestige_mimic))
		var/mob/living/basic/vestige_mimic/shape = owner
		shape.break_form()
	. = ..()
	if(!. || !isliving(owner))
		return
	var/mob/living/pouncer = owner
	pouncer.apply_status_effect(/datum/status_effect/vestige_predation)

// A wet uncoiling instead of the base charge's bubblegum theatrics, the thing
// that leaves the floor is meat, not a swinging weapon, and it should sound it
/datum/action/cooldown/mob_cooldown/charge/vestige_pounce/do_charge_indicator(atom/charger, atom/charge_target)
	playsound(charger, 'sound/effects/blob/attackblob.ogg', 60, TRUE)

// The base charge plays a 200-volume meteor impact on every tile moved.
// Ambushes do not.
/datum/action/cooldown/mob_cooldown/charge/vestige_pounce/on_moved(atom/source)
	SIGNAL_HANDLER
	return

// Landing on someone: no trample damage, just the floor, the damage is
// whatever you swing in the savagery window you just earned
/datum/action/cooldown/mob_cooldown/charge/vestige_pounce/hit_target(atom/movable/source, mob/living/target, damage_dealt)
	target.visible_message(
		span_danger("[source] pounces [target] flat!"),
		span_userdanger("[source] bursts across the gap and slams you to the deck!"),
	)
	playsound(target, 'sound/effects/blob/blobattack.ogg', 60, TRUE)
	target.Knockdown(VESTIGE_POUNCE_KNOCKDOWN)
	shake_camera(target, 2, 1)

/**
 * The lent savagery: for a short window after a pounce, the next melee blow
 * carries bonus force. Armed strikes get it the supported way, a
 * COMSIG_MOB_ITEM_ATTACK handler adding MODIFY_ATTACK_FORCE to the attack
 * chain's by-reference attack_modifiers list (melee_attack_chain always
 * passes a real list; blood_drunk's saw is the in-tree precedent for the
 * macro). Punch damage has no modifier hook, so an unarmed harm-mode strike
 * spends the window on a rider hit of its own instead, a claw-rake with its
 * own message, which lands whether or not the punch under it connects
 * (fiction holds: the rake is its own attack). Shoves and help-intent
 * touches don't spend it.
 */
/datum/status_effect/vestige_predation
	id = "vestige_predation"
	duration = VESTIGE_AMBUSH_WINDOW
	status_type = STATUS_EFFECT_REPLACE
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/vestige_predation/on_apply()
	RegisterSignal(owner, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_armed_strike))
	RegisterSignal(owner, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_strike))
	to_chat(owner, span_boldnotice("For a moment, your whole weight knows exactly where it wants to land."))
	return TRUE

/datum/status_effect/vestige_predation/on_remove()
	UnregisterSignal(owner, list(COMSIG_MOB_ITEM_ATTACK, COMSIG_LIVING_UNARMED_ATTACK))

/// Armed melee: the bonus rides the attack chain's own force modifiers
/datum/status_effect/vestige_predation/proc/on_armed_strike(mob/living/source, mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(!isliving(target) || target == source)
		return
	MODIFY_ATTACK_FORCE(attack_modifiers, VESTIGE_AMBUSH_BONUS_FORCE)
	to_chat(source, span_boldnotice("You put the whole ambush behind the blow."))
	qdel(src)

/// Unarmed melee: no force hook exists for punches, so the window is spent on a claw-rake rider with its own teeth
/datum/status_effect/vestige_predation/proc/on_unarmed_strike(mob/living/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!isliving(target) || target == source || !proximity)
		return
	if(!source.combat_mode || HAS_TRAIT(source, TRAIT_PACIFISM) || LAZYACCESS(modifiers, RIGHT_CLICK))
		return
	var/mob/living/victim = target
	victim.apply_damage(VESTIGE_AMBUSH_BONUS_FORCE, BRUTE, wound_bonus = CANT_WOUND)
	victim.visible_message(
		span_danger("[source]'s strike arrives with a savage, raking follow-through!"),
		span_userdanger("[source]'s blow rakes through you like a claw!"),
	)
	playsound(victim, 'sound/effects/blob/attackblob.ogg', 40, TRUE)
	qdel(src)

#undef VESTIGE_MIMIC_HEALTH
#undef VESTIGE_MIMIC_CREEP_SPEED
#undef VESTIGE_MIMIC_FLAWLESS_SPEED
#undef VESTIGE_MIMIC_REFORM_COOLDOWN
#undef VESTIGE_MIMIC_FLAWLESS_REFORM
#undef VESTIGE_GULLET_COOLDOWN
#undef VESTIGE_GULLET_SWALLOW_TIME
#undef VESTIGE_GULLET_HEAVE_TIME
#undef VESTIGE_GULLET_SLOTS
#undef VESTIGE_GLUTTONY_SLOTS
#undef VESTIGE_GLUTTONY_FEED_HEAL
#undef VESTIGE_POUNCE_DISTANCE
#undef VESTIGE_POUNCE_KNOCKDOWN
#undef VESTIGE_POUNCE_COOLDOWN
#undef VESTIGE_AMBUSH_BONUS_FORCE
#undef VESTIGE_AMBUSH_WINDOW
#undef VESTIGE_MORPH_TRAIT
