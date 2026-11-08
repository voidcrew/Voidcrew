/**
 * # Large alien artifact
 *
 * A dense machine dug out of a planet's old dig sites. It carries a main effect and sometimes
 * a minor second one, each with its own trigger.
 */
/obj/machinery/artifact
	name = "alien artifact"
	desc = "A large object of no make you recognise."
	density = TRUE
	anchored = FALSE
	use_power = NO_POWER_USE
	max_integrity = 1000
	resistance_flags = LAVA_PROOF | FIRE_PROOF | ACID_PROOF

	/// ZONE_* it was dug in, or null if it never came out of the ground. Price and research read this.
	var/origin_band
	/// Catalogue number, such as "Kappa-4412"
	var/serial
	/// The label a crew stuck on it, if any
	var/datum/artifact_label/label
	/// Harvests a harvester may still drain from it
	var/harvests_left = ARTIFACT_MAX_HARVESTS
	/// Its first full analysis has paid research points. Stays with the artifact whichever crew holds it.
	var/research_paid = FALSE
	/// Came out of the rock unstabilised. Sells for less.
	var/damaged = FALSE
	/// The effect it is named and priced for
	var/datum/artifact_effect/main_effect
	/// A minor second effect, or null
	var/datum/artifact_effect/second_effect

/// Whether it came out of a dig site. Buyers refuse anything else.
/obj/machinery/artifact/proc/is_dug()
	return !isnull(origin_band)

/// How many harvests have been drained from it.
/obj/machinery/artifact/proc/harvests_taken()
	return clamp(ARTIFACT_MAX_HARVESTS - harvests_left, 0, ARTIFACT_MAX_HARVESTS)

/// 0 to 1: how right its label is. 0 with no label.
/obj/machinery/artifact/proc/label_accuracy()
	if(!label || !main_effect)
		return 0
	. = 0
	if(label.effect_name == main_effect.label_name)
		. += ARTIFACT_LABEL_SHARE_EFFECT
	if(label.trigger_name == artifact_trigger_name(main_effect.trigger))
		. += ARTIFACT_LABEL_SHARE_TRIGGER
	var/second_truth = second_effect ? second_effect.label_name : ARTIFACT_LABEL_NONE
	if(label.second_name == second_truth)
		. += ARTIFACT_LABEL_SHARE_SECOND

/// Sticks a new label on, replacing any old one.
/obj/machinery/artifact/proc/apply_label(datum/artifact_label/new_label, mob/user)
	if(label && label != new_label)
		QDEL_NULL(label)
	label = new_label
	SEND_SIGNAL(src, COMSIG_ARTIFACT_LABEL_CHANGED, new_label, user)
	update_appearance()

/// Scrapes the label off.
/obj/machinery/artifact/proc/remove_label(mob/user)
	if(!label)
		return FALSE
	QDEL_NULL(label)
	SEND_SIGNAL(src, COMSIG_ARTIFACT_LABEL_CHANGED, null, user)
	update_appearance()
	return TRUE

/// Marks it as dug in `band`. Only the first stamp counts.
/obj/machinery/artifact/proc/stamp_origin(band)
	if(!isnull(origin_band))
		return FALSE
	origin_band = XENOARCH_BAND_INDEX(band)
	SEND_SIGNAL(src, COMSIG_ARTIFACT_STAMPED, origin_band)
	return TRUE
