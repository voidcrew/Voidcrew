/// Backgrounds: owned by P4. See data/backgrounds/spec.md.

// Halcyon (green) and Quartermain (yellow) check faces and papers at every counter, the
// imprinter, the MOD bench, the chrome cradle, Pike and the network pad (all through
// is_user_barred()) and at the hangar lift, and turn pirate hulls away at the berths.
// The Undertow serves anyone. The turrets never read any of this (is_violence_barred()).

/// Whether this outpost checks faces and papers
/obj/structure/overmap/trader_outpost/proc/background_checks_papers()
	return istype(src, /obj/structure/overmap/trader_outpost/general) || istype(src, /obj/structure/overmap/trader_outpost/outfitter)

/// Whether this outpost refuses this user service at its counters, lift and network pad
/obj/structure/overmap/trader_outpost/proc/background_service_refused(mob/user)
	if(!ishuman(user) || !background_checks_papers())
		return FALSE
	var/mob/living/carbon/human/person = user
	// MP-1: a hidden face with no readable card is refused, whoever it is
	if(background_no_papers(person))
		return TRUE
	// MP-2: the mind when the face shows, the card's name when it is hidden
	return !isnull(background_recognised_mind(person, BACKGROUND_PIRATE))

/// What the trader says when refusing this user, or null
/obj/structure/overmap/trader_outpost/proc/background_refusal_line(mob/user)
	if(!ishuman(user) || !background_checks_papers())
		return null
	var/mob/living/carbon/human/person = user
	if(background_no_papers(person))
		return "No face, no papers."
	if(!isnull(background_recognised_mind(person, BACKGROUND_PIRATE)))
		return "Not your kind. Move along."
	return null

/// Why this outpost refuses this ship a berth, or null
/obj/structure/overmap/trader_outpost/proc/background_docking_refusal(obj/structure/overmap/ship/acting)
	if(!acting || !background_checks_papers())
		return null
	if(background_pirate_flag_check(acting) || background_rider_flagged(acting))
		return "[name] traffic control: your transponder is flagged. Docking denied."
	return null
