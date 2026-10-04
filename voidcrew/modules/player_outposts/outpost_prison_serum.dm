/**
 * # Kessler items, and the prisoners' fear
 *
 * What the researcher hands over: a serum injector (one dose, form unknown until it takes) or a
 * specimen jar, whose contents go into food a prisoner then eats. Each carries
 * /datum/component/outpost_experiment_item: it works only in the hands of a member of the wing
 * that got it, only on that wing's prisoners, only for OUTPOST_EXPERIMENT_ITEM_LIFETIME, and is
 * destroyed off the wing's level. Tainted food looks like any other food; only a close look shows
 * it. Anyone but one of the wing's prisoners who eats it throws the specimen up, and that is logged.
 * What the prisoners do about the creatures is in outpost_prison_panic.dm.
 */

// ===== ITEMS =====

/// Something Kessler Biolabs handed a prison wing's manager
/obj/item/outpost_experiment
	name = "Kessler Biolabs item"
	desc = "Something from Kessler Biolabs."
	w_class = WEIGHT_CLASS_SMALL
	/// "serum" or "specimen"
	var/kind = "serum"

/obj/item/outpost_experiment/Initialize(mapload, datum/outpost_prison/prison, form)
	. = ..()
	AddComponent(/datum/component/outpost_experiment_item, prison, kind, form, world.time + OUTPOST_EXPERIMENT_ITEM_LIFETIME)

/obj/item/outpost_experiment/proc/item_tag()
	return GetComponent(/datum/component/outpost_experiment_item)

/obj/item/outpost_experiment/proc/issuing_prison()
	var/datum/component/outpost_experiment_item/label = item_tag()
	return label?.prison()

/// Why `user` cannot use it, or null: it has to be one of the issuing wing's members
/obj/item/outpost_experiment/proc/user_error(mob/living/user)
	var/datum/outpost_prison/prison = issuing_prison()
	if(!prison)
		return "it's inert"
	if(!prison.is_member(user))
		return "the seal won't open for you"
	return null

// ----- the serum -----

/obj/item/outpost_experiment/serum
	name = "serum injector"
	desc = "A sealed Kessler Biolabs injector holding one dose of something cloudy and yellow. The seal only opens for the prison wing's staff."
	icon = /obj/item/reagent_containers/hypospray/medipen::icon
	icon_state = "stimpen"
	inhand_icon_state = "stimpen"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	kind = "serum"

/obj/item/outpost_experiment/serum/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with))
		return NONE
	var/mob/living/basic/outpost_prisoner/subject = interacting_with
	var/error = dose_error(user, subject)
	if(error)
		balloon_alert(user, error)
		return ITEM_INTERACT_BLOCKING
	user.visible_message(span_warning("[user] starts to inject [subject] with [src]."), span_notice("You start to inject [subject] with [src]."))
	if(!do_after(user, OUTPOST_EXPERIMENT_DOSE_TIME, target = subject))
		return ITEM_INTERACT_BLOCKING
	error = dose_error(user, subject)
	if(error)
		balloon_alert(user, error)
		return ITEM_INTERACT_BLOCKING
	var/datum/component/outpost_experiment_item/label = item_tag()
	var/datum/outpost_prison/prison = label.prison()
	if(!prison.start_experiment(label.form, subject))
		balloon_alert(user, "it won't take now")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(span_warning("[user] injects [subject] with [src]."), span_notice("You inject [subject] with [src]."))
	playsound(subject, 'sound/items/hypospray.ogg', 50, TRUE)
	log_combat(user, subject, "injected", src, "(Kessler serum, [label.form])")
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/// Why the serum cannot go into `subject` now, or null
/obj/item/outpost_experiment/serum/proc/dose_error(mob/living/user, mob/living/basic/outpost_prisoner/subject)
	var/error = user_error(user)
	if(error)
		return error
	if(!istype(subject))
		return "prisoners only"
	var/datum/outpost_prison/prison = issuing_prison()
	if(subject.prison != prison)
		return "not one of this wing's prisoners"
	if(subject.stat == DEAD || subject.phase != PRISONER_PRESENT)
		return "not now"
	if(prison.experiment_active())
		return "one experiment at a time"
	if(subject.trouble == PRISONER_TROUBLE_LOOSE || !prison.in_cell_block(subject))
		return "only in the cell block"
	// Not a bounty prisoner (outpost_prison_bounty.dm)
	return bounty_experiment_refusal(subject)

// ----- the specimen -----

/obj/item/outpost_experiment/specimen
	name = "specimen jar"
	desc = "A sealed Kessler Biolabs jar. Something small and pale is curled up inside, and it moves when you are not looking. The seal only opens for the prison wing's staff."
	icon = /obj/item/reagent_containers/cup/beaker/organ_jar::icon
	icon_state = "organ_jar"
	inhand_icon_state = "beaker"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	kind = "specimen"

/obj/item/outpost_experiment/specimen/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(isliving(interacting_with))
		balloon_alert(user, "it goes in food")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/food/meal = interacting_with
	if(!istype(meal))
		return NONE
	var/error = taint_error(user, meal)
	if(error)
		balloon_alert(user, error)
		return ITEM_INTERACT_BLOCKING
	user.visible_message(span_warning("[user] starts to push something from [src] into [meal]."), span_notice("You start to push the specimen into [meal]."))
	if(!do_after(user, OUTPOST_EXPERIMENT_DOSE_TIME, target = meal))
		return ITEM_INTERACT_BLOCKING
	error = taint_error(user, meal)
	if(error)
		balloon_alert(user, error)
		return ITEM_INTERACT_BLOCKING
	var/datum/component/outpost_experiment_item/label = item_tag()
	meal.AddComponent(/datum/component/outpost_experiment_item, label.prison(), "tainted", "changeling", label.expires_at)
	user.visible_message(span_warning("[user] pushes something from [src] into [meal]."), span_notice("You push the specimen into [meal]. It burrows out of sight."))
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] put a Kessler specimen into [meal] at [AREACOORD(meal)]")
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/// Why the specimen cannot go into `meal` now, or null
/obj/item/outpost_experiment/specimen/proc/taint_error(mob/living/user, obj/item/food/meal)
	var/error = user_error(user)
	if(error)
		return error
	if(QDELETED(meal))
		return "the food is gone"
	if(meal.GetComponent(/datum/component/outpost_experiment_item))
		return "something is already in it"
	return null

// ===== THE ITEM TAG =====

/**
 * Ties a serum, specimen jar or tainted food to the prison that got it, with its form and the
 * world.time it expires. The prison tracks it from here (track_experiment_item()), spoils it and
 * destroys it off the level (items_tick()). On food it is the specimen itself: a close look shows
 * it, and anyone who is not the wing's prisoner eating it throws it up.
 */
/datum/component/outpost_experiment_item
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/datum/weakref/prison_ref
	/// "serum", "specimen" or "tainted"
	var/kind
	/// What it starts: "hulk", "fly", "nightmare" or "changeling"
	var/form
	/// world.time it spoils
	var/expires_at = 0

/datum/component/outpost_experiment_item/Initialize(datum/outpost_prison/prison, kind, form, expires_at)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE
	prison_ref = prison ? WEAKREF(prison) : null
	src.kind = kind
	src.form = form
	src.expires_at = expires_at
	prison?.track_experiment_item(parent)

/datum/component/outpost_experiment_item/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	if(kind == "tainted")
		RegisterSignal(parent, COMSIG_ATOM_EXAMINE_MORE, PROC_REF(on_examine_more))
		RegisterSignal(parent, COMSIG_FOOD_EATEN, PROC_REF(on_bitten))

/datum/component/outpost_experiment_item/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_EXAMINE, COMSIG_ATOM_EXAMINE_MORE, COMSIG_FOOD_EATEN))

/datum/component/outpost_experiment_item/proc/prison()
	return prison_ref?.resolve()

/datum/component/outpost_experiment_item/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	if(kind == "tainted")
		return
	var/minutes = max(0, round((expires_at - world.time) / (1 MINUTES), 1))
	examine_list += span_notice(minutes >= 1 ? "The label says it is good for about [minutes] more minute\s." : "The label says it is about to spoil.")

/datum/component/outpost_experiment_item/proc/on_examine_more(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	examine_list += span_warning("Something moves under the surface.")

/// Someone took a bite: only the wing's prisoners can host it, so whoever this is throws it up
/datum/component/outpost_experiment_item/proc/on_bitten(datum/source, mob/living/eater, mob/living/feeder, bitecount, bitesize)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(reject), eater)
	return DESTROY_FOOD

/**
 * `eater` ate the tainted food. One of the issuing wing's prisoners becomes the specimen's host;
 * anyone else throws it up. Returns TRUE if it took.
 */
/datum/component/outpost_experiment_item/proc/eaten_by(mob/living/eater)
	var/datum/outpost_prison/prison = prison()
	var/mob/living/basic/outpost_prisoner/host = eater
	if(istype(host) && prison && host.prison == prison && prison.start_experiment("changeling", host))
		log_game("PLAYER OUTPOST PRISON: [host.real_name] ate food with a Kessler specimen in it at '[prison.outpost?.name]'")
		qdel(src)
		return TRUE
	reject(eater)
	return FALSE

/// The specimen will not take in `eater`: it comes back up, dead
/datum/component/outpost_experiment_item/proc/reject(mob/living/eater)
	if(QDELETED(eater))
		qdel(src)
		return
	eater.visible_message(span_warning("[eater] retches up something small and wriggling. It stops moving."), span_userdanger("Something in your food squirms in your throat, and you bring it straight back up!"))
	if(iscarbon(eater))
		var/mob/living/carbon/sick = eater
		sick.vomit(VOMIT_CATEGORY_DEFAULT, /obj/effect/decal/cleanable/vomit, 10)
	else if(isturf(eater.loc))
		new /obj/effect/decal/cleanable/vomit(eater.loc)
	log_game("PLAYER OUTPOST PRISON: [key_name(eater)] ate food with a Kessler specimen in it and threw it up [AREACOORD(eater)]")
	if(eater.client)
		message_admins("[ADMIN_LOOKUPFLW(eater)] ate food with a prison experiment specimen in it and threw it up.")
	qdel(src)

/// Out of time: the serum curdles, the specimen dies
/datum/component/outpost_experiment_item/proc/expire()
	var/atom/thing = parent
	switch(kind)
		if("serum")
			thing.visible_message(span_notice("The dose in [thing] curdles, and its seal locks for good."))
			qdel(thing)
		if("specimen")
			thing.visible_message(span_notice("The thing in [thing] stops moving."))
			qdel(thing)
		else
			// Tainted food stays food; what was in it is dead.
			qdel(src)

/// Off the level: gone
/datum/component/outpost_experiment_item/proc/destroy_item()
	qdel(parent)

/// A prisoner eats: food with the specimen in it takes them as its host
/mob/living/basic/outpost_prisoner/eat_food(obj/item/food/meal)
	var/datum/component/outpost_experiment_item/specimen = meal?.GetComponent(/datum/component/outpost_experiment_item)
	. = ..()
	if(specimen && !QDELETED(specimen))
		specimen.eaten_by(src)
