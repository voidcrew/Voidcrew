/**
 * # Artifact label
 *
 * The sticker a crew prints and sticks on a large find: what they think it does, what they
 * think wakes it, and its second effect or "None". Words come from the labeler's plain-word
 * lists (artifact_effect_label_names(), artifact_trigger_label_names()). Nothing in the game
 * says whether a label is right; the sale price is the only feedback.
 */
/datum/artifact_label
	/// What it does, as an effect's label_name
	var/effect_name
	/// What wakes it, as artifact_trigger_name() gives it
	var/trigger_name
	/// The second effect's label_name, or ARTIFACT_LABEL_NONE
	var/second_name = ARTIFACT_LABEL_NONE

/datum/artifact_label/New(effect_name, trigger_name, second_name = ARTIFACT_LABEL_NONE)
	. = ..()
	src.effect_name = effect_name
	src.trigger_name = trigger_name
	src.second_name = second_name || ARTIFACT_LABEL_NONE

/// The label as it reads when examined.
/datum/artifact_label/proc/examine_text()
	return "A printed label reads: <i>Effect: [effect_name || "?"]. Trigger: [trigger_name || "?"]. Second: [second_name || ARTIFACT_LABEL_NONE].</i>"
