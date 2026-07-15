/**
 * # The Silent Dojo — space ninja vestige
 *
 * A Spider Clan training hall drifting cold, mats still swept. The master's
 * suit still kneels at the head of the room; the master, as far as anyone can
 * tell, is not in it. Ninja kit is pure gear (zero antag coupling), so the
 * boon is the clan's blade itself — the energy katana's dash action lives on
 * the item and grants on equip, verified upstream.
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/hollow_master
	name = "the Hollow Master"
	desc = "A ninja shozoku kneeling in perfect seiza. The posture is flawless. The suit is, by every instrument you have, empty."
	gender = NEUTER
	outfit_path = /datum/outfit/ninja
	appearance_tint = "#3c3c50"
	trial_types = list(
		/datum/vestige_trial/thrown_star,
	)
	boon_types = list(
		/datum/vestige_boon/item/master_blade,
	)
	idle_lines = list(
		"You are looking for the master. The master is looking back. Do not ask from where.",
		"Every student asks about the blade first. The blade is the last lesson. The first lesson is the walk back to pick up what you threw.",
		"This hall has heard ten thousand footsteps. Yours are the loudest so far. We will work on that.",
		"The suit is not empty. It is exactly as full as it needs to be.",
	)
	accept_line = "Begin. The star does not care how good you think you are. That is why we start with the star."
	busy_line = "You carry another's lesson unfinished. A split student learns two nothings."
	fulfilled_line = "That kata is complete. Repetition past mastery is vanity."
	renounce_line = "The door is where you left it. So is mediocrity."
	claim_line = "Your lesson is paid for. Take it before you ask for the next."
	exhausted_line = "I have nothing left to teach you but patience, and you would only throw it at someone."
	remember_line = "You died. Sloppy. Your training, fortunately, is kept in a place death does not clean out."

// ===== TRIAL OF THE THROWN STAR =====

/datum/vestige_trial/thrown_star
	name = "Trial of the Thrown Star"
	// Keep the counts in sync with VESTIGE_STAR_HITS_NEEDED / VESTIGE_STAR_HITS_PER_VICTIM
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the training star. Land ten thrown strikes on living targets — and no more than three on the same one; the master is bored by bullies. It will not wound and it will not stick. Bring it back each time. The lesson is in the fetching."
	/// Credited hits so far
	var/hits_landed = 0
	/// Hits credited per victim (weakref -> count), capping farm-a-friend
	var/list/hits_per_victim = list()

/datum/vestige_trial/thrown_star/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/throwing_star/vestige_training(get_turf(user)))

/datum/vestige_trial/thrown_star/get_progress_text()
	return "You have landed [hits_landed] of [VESTIGE_STAR_HITS_NEEDED] strikes."

/// Credits a thrown hit. May complete (and delete) the trial. Returns FALSE if this victim is spent.
/datum/vestige_trial/thrown_star/proc/strike(mob/living/victim)
	var/datum/weakref/key = WEAKREF(victim)
	var/prior = hits_per_victim[key] || 0
	if(prior >= VESTIGE_STAR_HITS_PER_VICTIM)
		return FALSE
	hits_per_victim[key] = prior + 1
	hits_landed++
	refresh_tracker()
	if(hits_landed >= VESTIGE_STAR_HITS_NEEDED)
		complete()
	return TRUE

/obj/item/throwing_star/vestige_training
	name = "training star"
	desc = "A blunted throwing star, worn smooth by ten thousand failures. It stings pride far more than flesh, and refuses on principle to stick into anything."
	force = 0
	throwforce = 5
	armour_penetration = 0
	sharpness = NONE
	embed_type = null

/obj/item/throwing_star/vestige_training/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	. = ..()
	if(!isliving(hit_atom))
		return
	var/mob/living/victim = hit_atom
	var/mob/living/thrower = throwingdatum?.thrower
	if(!istype(thrower) || thrower == victim || victim.stat == DEAD)
		return
	var/datum/vestige_trial/thrown_star/trial = thrower.mind?.active_vestige_trial
	if(!istype(trial))
		return
	if(trial.strike(victim))
		to_chat(thrower, span_notice("A clean strike. Somewhere, something nods."))
	else
		to_chat(thrower, span_warning("That target has nothing left to teach you. Find another."))

// ===== BOONS =====

// The katana is fully standalone: its dash action rides the item and grants
// on equip, no suit or antag datum required.
/datum/vestige_boon/item/master_blade
	name = "The Master's Blade"
	desc = "The clan's energy katana. It cuts what it is told to, parries what it is not, and — thrown or right-clicked across a gap — takes you with it, three steps at a time."
	grant_text = "A hilt finds your hand as if it had been waiting there all along."
	item_type = /obj/item/energy_katana
