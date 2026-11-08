// Gut spill (hyperviolence, braingut part): tg already spills a victim's chest organs onto the floor
// when the chest is split open (/obj/item/bodypart/chest/dismember, only ever on someone in hard crit
// or dead, or cursed). The intestines come out in that same spill, every time, and nothing else
// triggers them. On a living victim they stay joined to the body by a tether (gut_tether.dm) through
// a critical slash wound, so gauze, sutures and cautery all work on the bleeding, but the cut will not
// close while the guts are out. Pushing the guts back in turns it into an ordinary severe cut. On a
// corpse there is nothing to drag: the guts just lie with the other organs.
// The design idea is Septic Shock's gut spill and Vanderlin's disembowel (AGPL code, nothing copied).

/// Slows a victim holding their guts in.
/datum/movespeed_modifier/hv_gut_spill
	multiplicative_slowdown = 0.7

/datum/wound_pregen_data/flesh_slash/disembowel
	abstract = FALSE
	wound_path_to_generate = /datum/wound/slash/flesh/critical/disembowel
	// only ever applied on purpose, by the chest spill hook below, never by the wound roll
	can_be_randomly_generated = FALSE
	viable_zones = list(BODY_ZONE_CHEST)
	threshold_minimum = WOUND_DISMEMBER_OUTRIGHT_THRESH

/// A spill replaces the cut it comes from, so an existing cut in the same series must not stop it.
/datum/wound_pregen_data/flesh_slash/disembowel/can_be_applied_to(obj/item/bodypart/limb, list/suggested_wounding_types = required_wounding_types, datum/wound/old_wound, random_roll = FALSE, duplicates_allowed = src.duplicates_allowed, care_about_existing_wounds = TRUE)
	return ..(limb, suggested_wounding_types, old_wound, random_roll, duplicates_allowed, FALSE)

/datum/wound/slash/flesh/critical/disembowel
	name = "Disembowelment"
	desc = "Abdominal wall torn open. Intestines are outside the body."
	treat_text = "Return the intestines. Dress the wound."
	treat_text_short = "Return the intestines."
	simple_treat_text = "Return the intestines. Dress the wound."
	homemade_treat_text = "Return the intestines. Dress the wound."
	examine_desc = "is torn open, guts hanging out"
	occur_text = "is torn open, guts spilling out"
	initial_flow = 4
	// the cut cannot close while the guts are out, so this is also the floor the bleeding stops at
	minimum_flow = 2.5
	clot_rate = 0
	treatable_by = list(/obj/item/stack/medical/suture, /obj/item/hv_intestines)
	scar_keyword = "slashcritical"

	/// The spilled guts, while they exist.
	var/obj/item/hv_intestines/guts
	/// Whether the guts are still outside the body. Cleared when they are pushed back in or destroyed.
	var/guts_out = FALSE
	/// The strand between the victim and the guts.
	var/datum/hv_gut_tether/tether

/// Spills quietly: tg's chest spill line and the guts line already say it, so the generic "chest is torn open" line would only repeat them.
/datum/wound/slash/flesh/critical/disembowel/apply_wound(obj/item/bodypart/L, silent = FALSE, datum/wound/old_wound = null, smited = FALSE, attack_direction = null, wound_source = "Unknown", replacing = FALSE)
	return ..(L, TRUE, old_wound, smited, attack_direction, wound_source, replacing)

/datum/wound/slash/flesh/critical/disembowel/wound_injury(datum/wound/slash/flesh/old_wound = null, attack_direction = null)
	. = ..()
	spill_out(attack_direction)

/datum/wound/slash/flesh/critical/disembowel/Destroy()
	release_guts()
	return ..()

/datum/wound/slash/flesh/critical/disembowel/remove_wound(ignore_limb, replaced = FALSE)
	release_guts()
	return ..()

/datum/wound/slash/flesh/critical/disembowel/get_self_check_description(self_aware)
	if(guts_out)
		return span_bolddanger("Your insides are hanging out of it!")
	return ..()

/// The cut cannot close while the guts are out.
/datum/wound/slash/flesh/critical/disembowel/adjust_blood_flow(adjust_by, minimum = 0)
	if(guts_out)
		minimum = max(minimum, minimum_flow)
	return ..(adjust_by, minimum)

/// Open guts never clot, so a cut with them out is never reported as healing.
/datum/wound/slash/flesh/critical/disembowel/get_bleed_rate_of_change()
	return ..() || BLOOD_FLOW_STEADY

/// Drops the guts on the floor and ties them to the victim. The other organs are already out: the chest spill
/// that brought this wound took them.
/datum/wound/slash/flesh/critical/disembowel/proc/spill_out(attack_direction)
	var/obj/item/bodypart/chest/chest = limb
	guts = chest.hv_drop_intestines(attack_direction)
	if(!guts)
		return
	guts_out = TRUE
	RegisterSignal(guts, COMSIG_QDELETING, PROC_REF(on_guts_deleted))
	victim.add_movespeed_modifier(/datum/movespeed_modifier/hv_gut_spill)
	INVOKE_ASYNC(victim, TYPE_PROC_REF(/mob, emote), "scream")
	tether = new(victim, guts)
	RegisterSignal(tether, COMSIG_QDELETING, PROC_REF(on_tether_deleted))

/datum/wound/slash/flesh/critical/disembowel/proc/on_tether_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	tether = null

/// The guts were destroyed, so there is nothing left to push back in.
/datum/wound/slash/flesh/critical/disembowel/proc/on_guts_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	guts = null
	end_spill()

/// Lets go of the guts: no tether, no slowdown. Leaves the guts item where it lies.
/datum/wound/slash/flesh/critical/disembowel/proc/release_guts()
	if(guts)
		UnregisterSignal(guts, COMSIG_QDELETING)
		guts = null
	end_spill()

/// Nothing is outside the body any more.
/datum/wound/slash/flesh/critical/disembowel/proc/end_spill()
	guts_out = FALSE
	if(tether)
		UnregisterSignal(tether, COMSIG_QDELETING)
		QDEL_NULL(tether)
	victim?.remove_movespeed_modifier(/datum/movespeed_modifier/hv_gut_spill)

/datum/wound/slash/flesh/critical/disembowel/treat(obj/item/I, mob/user)
	if(istype(I, /obj/item/hv_intestines))
		return push_guts_back(I, user)
	return ..()

/// Someone pushes the guts back in. Whichever guts they hold go in, and the wound becomes the plain severe cut it was.
/datum/wound/slash/flesh/critical/disembowel/proc/push_guts_back(obj/item/hv_intestines/returned, mob/user)
	if(!guts_out)
		return FALSE
	var/mob/living/carbon/patient = victim
	var/self_treat = (user == patient)
	user.visible_message(
		span_notice("[user] starts pushing [self_treat ? user.p_their() : "[patient]'s"] guts back in."),
		span_notice("You start pushing [self_treat ? "your" : "[patient]'s"] guts back in..."),
	)
	if(!do_after(user, (self_treat ? 6 SECONDS : 4 SECONDS), target = patient, extra_checks = CALLBACK(src, PROC_REF(can_push_back), returned)))
		return TRUE
	user.visible_message(
		span_notice("[user] pushes [self_treat ? user.p_their() : "[patient]'s"] guts back in."),
		span_notice("You push [self_treat ? "your" : "[patient]'s"] guts back in."),
	)
	finish_push_back(returned)
	return TRUE

/datum/wound/slash/flesh/critical/disembowel/proc/can_push_back(obj/item/hv_intestines/returned)
	return guts_out && still_exists() && !QDELETED(returned)

/// The guts go back in for good: the held guts are used up and the wound drops to the cut it came from.
/datum/wound/slash/flesh/critical/disembowel/proc/finish_push_back(obj/item/hv_intestines/returned)
	end_spill()
	qdel(returned)
	if(!QDELETED(src) && limb && demotes_to)
		replace_wound(new demotes_to)

/// Whether this chest could spill intestines at all: a human body that can be wounded.
/obj/item/bodypart/chest/proc/hv_chest_can_spill()
	if(!owner || !ishuman(owner))
		return FALSE
	if(HAS_TRAIT(owner, TRAIT_NODISMEMBER) || HAS_TRAIT(owner, TRAIT_NEVER_WOUNDED) || HAS_TRAIT(owner, TRAIT_GODMODE))
		return FALSE
	var/datum/wound_pregen_data/pregen = GLOB.all_wound_pregen_data[/datum/wound/slash/flesh/critical/disembowel]
	return pregen.can_be_applied_to(src)

/// Puts a coil of intestines on the floor where the organs fell, ahead of the victim when the blow's direction
/// is known, with a smear of gibs and a line in the hit message. Returns the guts, or null if there was nowhere to put them.
/obj/item/bodypart/chest/proc/hv_drop_intestines(attack_direction)
	var/mob/living/carbon/victim = owner
	var/turf/victim_turf = get_turf(victim)
	if(!victim_turf)
		return null
	var/atom/drop_spot = victim.drop_location() || victim_turf
	if(isturf(victim.loc) && attack_direction)
		var/turf/ahead = get_step(victim, attack_direction)
		if(ahead && !ahead.is_blocked_turf(exclude_mobs = TRUE))
			drop_spot = ahead
	var/obj/item/hv_intestines/guts = new(drop_spot)
	guts.add_mob_blood(victim)
	if(victim.can_bleed() && isturf(drop_spot))
		new /obj/effect/decal/cleanable/blood/gibs(drop_spot, null, victim.get_blood_dna_list())
	// Reads after tg's "chest is split open, causing their internal organs to spill out!"
	victim.hv_add_hit_line("[victim]'s guts unspool across the floor!", HV_LINE_BOLD, "Your guts unspool across the floor!", DEFAULT_MESSAGE_RANGE)
	return guts

/// Puts a disembowelment on this chest, replacing the cut it comes from, and drops the guts it holds on a tether.
/// Returns the wound, or null if it could not be applied.
/obj/item/bodypart/chest/proc/hv_spill_guts(attack_direction, damage_source)
	if(!hv_chest_can_spill())
		return null
	var/datum/wound/slash/flesh/critical/disembowel/spill = new
	var/datum/wound/slash/flesh/existing = get_wound_type(/datum/wound/slash/flesh)
	if(existing)
		existing.replace_wound(spill, attack_direction = attack_direction)
	else
		spill.apply_wound(src, attack_direction = attack_direction, wound_source = damage_source)
	if(QDELETED(spill) || spill.limb != src)
		return null
	return spill

/// The intestines that come out in the same moment as the other chest organs. A living victim (in hard crit,
/// or cursed) is disemboweled, so the guts stay tied to them; a corpse has nothing to drag, so its guts only drop.
/// Does nothing if the guts are already out.
/obj/item/bodypart/chest/proc/hv_spill_intestines(attack_direction)
	if(!hv_chest_can_spill())
		return
	var/datum/wound/slash/flesh/critical/disembowel/already = get_wound_type(/datum/wound/slash/flesh/critical/disembowel)
	if(already?.guts_out)
		return
	if(owner.stat == DEAD)
		hv_drop_intestines(attack_direction)
		return
	hv_spill_guts(attack_direction, "chest spill")

/// tg splits the chest open by spilling its organs onto the floor; the intestines are part of that spill.
/// The way the last blow travelled, if one just landed, is where the guts are thrown.
/obj/item/bodypart/chest/dismember(dam_type = BRUTE, silent = TRUE, wounding_type)
	var/mob/living/carbon/chest_owner = owner
	. = ..()
	// tg gives back the organs it spilled, or FALSE when it did nothing
	if(!islist(.) || !length(.) || !chest_owner || chest_owner != owner)
		return
	hv_spill_intestines(chest_owner.hv_blood_recent_hit_dir())
