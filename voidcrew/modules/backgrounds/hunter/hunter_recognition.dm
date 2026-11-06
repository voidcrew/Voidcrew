/// Backgrounds: owned by P3. See data/backgrounds/spec.md.

/// Whether this person's face is hidden
/proc/background_face_hidden(mob/living/carbon/human/person)
	return FALSE

/// Whether this person shows neither a face nor an ID name
/proc/background_no_papers(mob/living/carbon/human/person)
	return FALSE

/// The active mind of this background key this person is recognised as, or null
/proc/background_recognised_mind(mob/living/carbon/human/person, key)
	return null

/// "Last seen at <site>", or null
/datum/background_state/proc/last_seen_text()
	return null

/// The ZONE_* band this state's target was last seen in, or null
/datum/background_state/proc/last_seen_zone()
	return null
