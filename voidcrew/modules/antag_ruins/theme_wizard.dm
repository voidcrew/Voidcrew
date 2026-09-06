/**
 * # The Athenaeum: wizard vestige
 *
 * A library barge that burned from the inside out when its master mispronounced
 * something. The patron is what the mispronunciation left behind. The trials
 * are practical lessons in containing a miscast, directing a spoken word,
 * and restoring an inscription without speaking. The boons are wizard spells, taught as words
 * of the art: granted as-is where upstream asks for no garb (fireball, knock,
 * forcewall), and locally subtyped where it does (blink) or where crew tempo
 * wants a retune.
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/magister
	name = "the Magister's Echo"
	desc = "A wizard-shaped afterimage, like the shadow a flash burns onto a wall. It is still mid-gesture. It has been mid-gesture for a very long time."
	gender = NEUTER
	outfit_path = /datum/outfit/wizard
	appearance_tint = "#6a5480"
	trial_types = list(
		/datum/vestige_trial/singed_hand,
		/datum/vestige_trial/steady_tongue,
		/datum/vestige_trial/swallowed_word,
	)
	boon_types = list(
		/datum/vestige_boon/spell/fireball,
		/datum/vestige_boon/spell/fireball/refined,
		/datum/vestige_boon/spell/knock,
		/datum/vestige_boon/spell/knock/greater,
		/datum/vestige_boon/spell/word_of_passage,
		/datum/vestige_boon/spell/word_of_denial,
	)
	idle_lines = list(
		"I mispronounced one syllable. ONE. The rest of me is still apologizing for it somewhere.",
		"Four thousand books, and every one of them said the same thing: the price is flesh. I thought I was the exception. So does everyone.",
		"You want the words? The words are easy. Surviving your own mouth is the discipline.",
		"Don't lean on the shelves. The ash still thinks it's a library, and it's sentimental about it.",
		"The library kept silence for thirty years after the fire. Finest lecture ever delivered here. I took notes.",
	)
	accept_line = "Then burn. Properly, this time. Not like I did."
	busy_line = "You're already spoken for. I can smell the other pact on you."
	fulfilled_line = "You've learned that one. There's no learning it twice."
	renounce_line = "Unsinged. Unlettered. Unremarkable."
	claim_line = "Your tuition is paid. Collect your diploma before you sign up for another course."
	exhausted_line = "I've taught you every word I still remember how to say."
	remember_line = "Death mispronounced you. It happens. Your education was fireproof, at least."

// ===== PRACTICAL LESSONS =====

/datum/vestige_trial/wizard_lesson
	var/obj/structure/vestige_lesson_well/focus
	var/list/manifestations = list()
	var/resolved = 0

/datum/vestige_trial/wizard_lesson/Destroy()
	clear_lesson()
	return ..()

/datum/vestige_trial/wizard_lesson/proc/clear_lesson()
	QDEL_NULL(focus)
	QDEL_LIST(manifestations)
	manifestations = list()
	resolved = 0

/// Flood-fill walking surfaces so a wall cannot strand the supplied manifestations.
/datum/vestige_trial/wizard_lesson/proc/set_up(mob/living/user)
	if(focus)
		clear_lesson()
		to_chat(user, span_notice("You pack up the unfinished exercise. Use the kit again to retry."))
		return FALSE
	var/turf/origin = get_turf(user)
	if(!isopenturf(origin) || isspaceturf(origin))
		return FALSE
	var/list/reachable = list(origin)
	var/list/perimeter = list()
	for(var/index = 1; index <= length(reachable); index++)
		var/turf/current = reachable[index]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || next in reachable || get_dist(next, origin) > 3)
				continue
			if(!isopenturf(next) || isspaceturf(next) || next.is_blocked_turf(exclude_mobs = FALSE))
				continue
			reachable += next
			if(get_dist(next, origin) == 3)
				perimeter += next
	if(length(perimeter) < 3 || length(reachable) < 18)
		to_chat(user, span_warning("The lesson needs eighteen connected clear floor tiles, reaching three paces away. Try a larger room."))
		return FALSE
	focus = new(origin)
	for(var/index in 1 to 3)
		var/obj/structure/vestige_miscast/miscast = new(pick_n_take(perimeter))
		miscast.student = owner
		manifestations += miscast
		START_PROCESSING(SSobj, miscast)
	return TRUE

/datum/vestige_trial/singed_hand
	parent_type = /datum/vestige_trial/wizard_lesson
	name = "Trial of the Singed Hand"
	desc = "Unfold the geode in a clear room. Three miscasts mark your footing, then flare there: move out of the red tile. While a miscast is blue and spent, catch it with the geode from two or three paces away. The geode holds two. Empty it at the central cooling well when every remaining miscast is at least three paces from the well. Cool all three. Use the geode in hand to pack up and retry."
	var/stored_heat = 0

/datum/vestige_trial/singed_hand/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_geode(get_turf(user)))

/datum/vestige_trial/singed_hand/clear_lesson()
	stored_heat = 0
	return ..()

/datum/vestige_trial/singed_hand/get_progress_text()
	return focus ? "[resolved] of three miscasts cooled; [stored_heat] of two heat held. Dodge red tiles; catch blue miscasts from two or three paces." : "Use the geode in hand in a clear room."

/datum/vestige_trial/singed_hand/proc/catch_miscast(mob/living/user, obj/structure/vestige_miscast/miscast)
	if(!(miscast in manifestations) || stored_heat >= 2)
		return FALSE
	var/distance = get_dist(user, miscast)
	if(distance < 2 || distance > 3 || world.time >= miscast.spent_until || !(miscast in view(3, user)))
		return FALSE
	manifestations -= miscast
	qdel(miscast)
	stored_heat++
	refresh_tracker()
	return TRUE

/datum/vestige_trial/singed_hand/proc/cool(mob/living/user)
	if(!stored_heat || !focus || !user.Adjacent(focus))
		return FALSE
	for(var/obj/structure/vestige_miscast/miscast as anything in manifestations)
		if(get_dist(miscast, focus) < 3)
			to_chat(user, span_warning("A miscast is too close to the well. Lure it away before cooling!"))
			return FALSE
	resolved += stored_heat
	stored_heat = 0
	refresh_tracker()
	if(resolved == 3)
		complete()
	return TRUE

/obj/item/vestige_geode
	name = "mana geode"
	desc = "Use in hand to unfold or pack up a lesson. Catch blue miscasts from two or three paces away; touch the central well to cool what you caught."
	icon = 'icons/obj/ore.dmi'
	icon_state = "diamond"
	color = "#ff9a4d"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_geode/attack_self(mob/living/user, modifiers)
	var/datum/vestige_trial/singed_hand/trial = user.mind?.active_vestige_trial
	if(istype(trial))
		trial.set_up(user)
		trial.refresh_tracker()
	return TRUE

/obj/item/vestige_geode/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	return handle_lesson(interacting_with, user)

/obj/item/vestige_geode/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	return handle_lesson(interacting_with, user)

/obj/item/vestige_geode/proc/handle_lesson(atom/target, mob/living/user)
	var/datum/vestige_trial/singed_hand/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || !user.is_holding(src))
		return NONE
	if(target == trial.focus)
		if(!trial.cool(user))
			balloon_alert(user, "well not ready!")
		return ITEM_INTERACT_BLOCKING
	if(istype(target, /obj/structure/vestige_miscast))
		if(!trial.catch_miscast(user, target))
			balloon_alert(user, "needs room, capacity and a blue miscast!")
		return ITEM_INTERACT_BLOCKING
	return NONE

/datum/vestige_trial/steady_tongue
	parent_type = /datum/vestige_trial/wizard_lesson
	name = "Trial of the Steady Tongue"
	desc = "Unfold the primer in a clear room. Click a miscast with the primer to speak a repelling word: it moves one tile directly away from you, then hangs still for four seconds. Line yourself up on a cardinal axis and drive all three into the central brazier. Words need two seconds between casts. Keep moving out of the red flare marks. Use the primer in hand to pack up and retry."

/datum/vestige_trial/steady_tongue/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_primer(get_turf(user)))

/datum/vestige_trial/steady_tongue/get_progress_text()
	return focus ? "[resolved] of three miscasts driven into the brazier. Align on a row or column and repel them toward it." : "Use the primer in hand in a clear room."

/obj/item/vestige_primer
	name = "singed primer"
	desc = "Use in hand to unfold or pack up a lesson. Click a miscast within three tiles to push it one tile directly away from you. Align on a cardinal axis with the central brazier."
	icon = 'icons/obj/service/library.dmi'
	icon_state = "book"
	color = "#b0663a"
	w_class = WEIGHT_CLASS_SMALL
	var/next_word = 0

/obj/item/vestige_primer/attack_self(mob/living/user, modifiers)
	var/datum/vestige_trial/steady_tongue/trial = user.mind?.active_vestige_trial
	if(istype(trial))
		trial.set_up(user)
		trial.refresh_tracker()
	return TRUE

/obj/item/vestige_primer/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	return repel(interacting_with, user)

/obj/item/vestige_primer/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	return repel(interacting_with, user)

/obj/item/vestige_primer/proc/repel(atom/target, mob/living/user)
	var/datum/vestige_trial/steady_tongue/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || !user.is_holding(src) || !(target in trial.manifestations))
		return NONE
	if(!user.can_speak() || world.time < next_word || !(target in view(3, user)))
		balloon_alert(user, "the word isn't ready!")
		return ITEM_INTERACT_BLOCKING
	if(user.x != target.x && user.y != target.y)
		balloon_alert(user, "align on a row or column!")
		return ITEM_INTERACT_BLOCKING
	if(get_turf(user) == get_turf(target))
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/vestige_miscast/miscast = target
	var/turf/destination = get_step(miscast, get_dir(user, miscast))
	if(!isopenturf(destination) || isspaceturf(destination) || destination.is_blocked_turf(exclude_mobs = TRUE))
		balloon_alert(user, "no room behind it!")
		return ITEM_INTERACT_BLOCKING
	next_word = world.time + 2 SECONDS
	user.say("RETRO!", forced = "vestige practical lesson")
	miscast.forceMove(destination)
	miscast.spent_until = world.time + 4 SECONDS
	miscast.update_appearance()
	if(destination == get_turf(trial.focus))
		trial.manifestations -= miscast
		qdel(miscast)
		trial.resolved++
		trial.refresh_tracker()
		if(trial.resolved == 3)
			trial.complete()
	return ITEM_INTERACT_SUCCESS

/obj/structure/vestige_lesson_well
	name = "miscast cooling well"
	desc = "A shallow bowl of blue fire. The geode unloads heat here; the primer drives miscasts into it."
	icon = 'icons/obj/antags/cult/structures.dmi'
	icon_state = "forge"
	color = "#74bfff"
	density = FALSE
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE

/obj/structure/vestige_miscast
	name = "loose miscast"
	desc = "It marks your footing in red before flaring there. Spent blue miscasts can be caught with a geode."
	icon = 'icons/obj/service/library.dmi'
	icon_state = "book"
	color = "#ff6544"
	density = FALSE
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE
	var/datum/mind/student
	var/spent_until = 0
	var/strike_at = 0
	var/turf/marked
	var/obj/effect/temp_visual/vestige_miscast_warning/warning

/obj/structure/vestige_miscast/Destroy()
	STOP_PROCESSING(SSobj, src)
	QDEL_NULL(warning)
	student = null
	return ..()

/obj/structure/vestige_miscast/update_appearance(updates=ALL)
	color = world.time < spent_until ? "#74bfff" : "#ff6544"
	return ..()

/obj/structure/vestige_miscast/process(seconds_per_tick)
	var/datum/vestige_trial/wizard_lesson/trial = student?.active_vestige_trial
	var/mob/living/user = student?.current
	if(!istype(trial) || !(src in trial.manifestations))
		qdel(src)
		return
	if(!isliving(user) || user.stat != CONSCIOUS || user.z != z || get_dist(user, trial.focus) > 7)
		return
	if(strike_at)
		if(world.time < strike_at)
			return
		if(get_turf(user) == marked)
			user.adjustStaminaLoss(18)
			to_chat(user, span_warning("The miscast flares under your feet, knocking the breath out of you!"))
		QDEL_NULL(warning)
		strike_at = 0
		marked = null
		spent_until = world.time + 4 SECONDS
		update_appearance()
		return
	if(world.time < spent_until)
		return
	update_appearance()
	if(get_dist(src, user) <= 3)
		marked = get_turf(user)
		warning = new(marked)
		strike_at = world.time + 2 SECONDS
		return
	var/turf/destination = get_step_towards(src, user)
	if(isopenturf(destination) && !isspaceturf(destination) && !destination.is_blocked_turf(exclude_mobs = TRUE))
		forceMove(destination)

/obj/effect/temp_visual/vestige_miscast_warning
	icon = 'icons/effects/effects.dmi'
	icon_state = "shield2"
	color = "#ff3333"
	duration = 3 SECONDS

// ===== TRIAL OF THE SWALLOWED WORD =====

/datum/vestige_trial/swallowed_word
	name = "Trial of the Swallowed Word"
	desc = "Unstopper the phial over clear three-by-three floor. Eight numbered syllables and a gap appear. Touch a syllable beside the gap to slide it into the empty space. Restore reading order: 1 2 3 across the north row, 4 5 6 in the middle, 7 8 and the gap along the south row. Speaking reshuffles the inscription into another solvable order. Use the phial in hand to pack up and retry."
	var/list/syllables = list()
	var/moves = 0
	var/mob/living/listener

/datum/vestige_trial/swallowed_word/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_syllable(get_turf(user)))
	RegisterSignal(owner, COMSIG_MIND_TRANSFERRED, PROC_REF(on_body_changed))
	bind_listener(user)

/datum/vestige_trial/swallowed_word/Destroy()
	UnregisterSignal(owner, COMSIG_MIND_TRANSFERRED)
	bind_listener(null)
	QDEL_LIST(syllables)
	return ..()

/datum/vestige_trial/swallowed_word/proc/bind_listener(mob/living/user)
	if(listener)
		UnregisterSignal(listener, COMSIG_MOB_SAY)
	listener = user
	if(listener)
		RegisterSignal(listener, COMSIG_MOB_SAY, PROC_REF(on_spoken))

/datum/vestige_trial/swallowed_word/proc/on_body_changed(datum/mind/source)
	SIGNAL_HANDLER
	bind_listener(owner?.current)

/datum/vestige_trial/swallowed_word/get_progress_text()
	return length(syllables) ? "Slide syllables into the gap: north row 1 2 3, middle 4 5 6, south 7 8 gap. [moves] moves made. Speaking reshuffles." : "Use the phial in hand on clear three-by-three floor."

/datum/vestige_trial/swallowed_word/proc/unfold(mob/living/user)
	if(length(syllables))
		QDEL_LIST(syllables)
		syllables = list()
		moves = 0
		return
	var/turf/center = get_turf(user)
	var/list/places = list()
	for(var/dy = 1; dy >= -1; dy--)
		for(var/dx in -1 to 1)
			var/turf/place = locate(center.x + dx, center.y + dy, center.z)
			if(!isopenturf(place) || isspaceturf(place) || place.is_blocked_turf(exclude_mobs = TRUE))
				to_chat(user, span_warning("The inscription needs a clear three-by-three patch of floor."))
				return
			places += place
	for(var/turf/place as anything in places)
		var/obj/structure/vestige_silent_glyph/glyph = new(place)
		glyph.home = place
		glyph.number = length(syllables) + 1
		glyph.name = glyph.number == 9 ? "gap in the inscription" : "syllable [glyph.number]"
		glyph.maptext = glyph.number == 9 ? "" : "<span style='font-size:16px;color:white;text-align:center'>[glyph.number]</span>"
		glyph.color = glyph.number == 9 ? "#333344" : "#ffd27f"
		syllables += glyph
	scramble()

/// Legal moves from the solved state guarantee that every inscription is solvable.
/datum/vestige_trial/swallowed_word/proc/scramble()
	for(var/obj/structure/vestige_silent_glyph/glyph as anything in syllables)
		glyph.forceMove(glyph.home)
	var/obj/structure/vestige_silent_glyph/gap = syllables[9]
	var/obj/structure/vestige_silent_glyph/previous
	var/distance = 0
	for(var/index = 1; index <= 80 || distance < 10; index++)
		var/list/options = list()
		for(var/obj/structure/vestige_silent_glyph/glyph as anything in syllables)
			if(glyph != gap && glyph != previous && abs(glyph.x - gap.x) + abs(glyph.y - gap.y) == 1)
				options += glyph
		var/obj/structure/vestige_silent_glyph/chosen = pick(options)
		slide(chosen)
		previous = chosen
		distance = 0
		for(var/obj/structure/vestige_silent_glyph/glyph as anything in syllables)
			distance += abs(glyph.x - glyph.home.x) + abs(glyph.y - glyph.home.y)
	moves = 0
	refresh_tracker()

/datum/vestige_trial/swallowed_word/proc/on_spoken(mob/living/source, list/say_args)
	SIGNAL_HANDLER
	if(source != owner?.current || !length(syllables))
		return
	scramble()
	to_chat(source, span_warning("Your spoken word tangles the inscription. A new pattern lights up."))

/datum/vestige_trial/swallowed_word/proc/slide(obj/structure/vestige_silent_glyph/glyph)
	var/obj/structure/vestige_silent_glyph/gap = syllables[9]
	if(glyph == gap || abs(glyph.x - gap.x) + abs(glyph.y - gap.y) != 1)
		return FALSE
	var/turf/previous = get_turf(glyph)
	glyph.forceMove(get_turf(gap))
	gap.forceMove(previous)
	return TRUE

/datum/vestige_trial/swallowed_word/proc/touch_glyph(obj/structure/vestige_silent_glyph/glyph)
	if(!(glyph in syllables))
		return FALSE
	if(!slide(glyph))
		return FALSE
	moves++
	refresh_tracker()
	for(var/obj/structure/vestige_silent_glyph/other as anything in syllables)
		if(get_turf(other) != other.home)
			return TRUE
	complete()
	return TRUE

/obj/item/vestige_syllable
	name = "sealed syllable"
	desc = "Use in hand to lay out or pack up the inscription. Slide numbered syllables into the gap to restore reading order. North: 1 2 3. Middle: 4 5 6. South: 7 8 gap. Speaking reshuffles."
	icon = 'icons/obj/mining_zones/artefacts.dmi'
	icon_state = "vial"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_syllable/attack_self(mob/living/user, modifiers)
	var/datum/vestige_trial/swallowed_word/trial = user.mind?.active_vestige_trial
	if(istype(trial))
		trial.unfold(user)
		trial.refresh_tracker()
	return TRUE

/obj/item/vestige_syllable/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/swallowed_word/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || !user.is_holding(src) || !user.Adjacent(interacting_with))
		return NONE
	if(trial.touch_glyph(interacting_with))
		return ITEM_INTERACT_SUCCESS
	return NONE

/obj/structure/vestige_silent_glyph
	name = "unspoken syllable"
	desc = "Touch with the phial while beside the gap to slide into it. Restore 1 2 3 across the north row, 4 5 6 in the middle, 7 8 gap to the south."
	icon = 'icons/obj/antags/cult/rune.dmi'
	icon_state = "1"
	color = "#ffd27f"
	density = FALSE
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE
	var/number
	var/turf/home

// ===== BOONS =====

// Upstream coupling, verified against code/modules/spells/spell.dm: the base
// spell cast chain has no antag checks and no resource costs, garb is only
// demanded when SPELL_REQUIRES_WIZARD_GARB is set. Fireball, knock and
// forcewall all override spell_requirements down to
// SPELL_REQUIRES_NO_ANTIMAGIC, so they grant to a plain human exactly as
// upstream ships them. Blink never overrides the base default
// (GARB|NO_ANTIMAGIC), so its local subtype below relaxes the garb half.
/datum/vestige_boon/spell/fireball
	name = "Fireball"
	desc = "Point at something and throw a ball of fire at it. Don't stand next to whatever you're pointing at."
	grant_text = "A word settles in behind your teeth, hot as a swallowed coal."
	spell_type = /datum/action/cooldown/spell/pointed/projectile/fireball/vestige

/datum/vestige_boon/spell/fireball/refined
	name = "Refined Fireball"
	desc = "The same fireball on a shorter cooldown, cast with a whisper instead of a shout, and with a tighter blast that wrecks less of what's around the target."
	grant_text = "The coal behind your teeth settles and stops crackling."
	upgrades_from = /datum/vestige_boon/spell/fireball
	spell_type = /datum/action/cooldown/spell/pointed/projectile/fireball/vestige/refined

/datum/vestige_boon/spell/knock
	name = "Knock"
	desc = "Speak the word and every door, locker and lock nearby pops open."
	grant_text = "A word settles in behind your teeth. Every door in earshot feels briefly nervous."
	spell_type = /datum/action/cooldown/spell/aoe/knock

/datum/vestige_boon/spell/knock/greater
	name = "Greater Knock"
	desc = "The same word with more range and a shorter cooldown, and it unbolts bolted airlocks on the way through. Welded or unpowered doors still hold."
	grant_text = "The word behind your teeth grows a second syllable."
	upgrades_from = /datum/vestige_boon/spell/knock
	spell_type = /datum/action/cooldown/spell/aoe/knock/vestige_greater

/datum/vestige_boon/spell/word_of_passage
	name = "Word of Passage"
	desc = "Teleport a short distance. You don't get to pick where - the spell does, and it isn't careful about it."
	grant_text = "A word settles in behind your teeth, and immediately starts fidgeting."
	spell_type = /datum/action/cooldown/spell/teleport/radius_turf/blink/vestige_passage

/datum/vestige_boon/spell/word_of_denial
	name = "Word of Denial"
	desc = "Raise a short barrier that nobody but you can walk through. It holds for a while."
	grant_text = "A word settles in behind your teeth, flat and immovable."
	spell_type = /datum/action/cooldown/spell/forcewall/vestige_denial

// ===== LOCAL SPELLS =====

/**
 * The word of destruction, slowed to something a crew can live around.
 * Upstream fireball's whole chain is clean, pointed/_pointed.dm and
 * projectile/magic.dm carry no antag or garb coupling, and antimagic_flags
 * propagate onto the bolt, so the only thing this subtype changes is the
 * tempo. Upstream speaks it every SIX seconds, which is a wizard mid-ascension
 * with a spellbook to answer for; a permanent ranged explosive on a six second
 * loop in crew hands is not a boon, it is artillery. Forty-five seconds puts it
 * with the other heavy boons (rusted grasp, ashen passage) and makes each cast
 * a decision. Subtyped rather than retuned in place so the wizard's own
 * fireball keeps upstream's numbers, and rank scaling is switched off since a
 * boon has no spellbook to level.
 */
/datum/action/cooldown/spell/pointed/projectile/fireball/vestige
	name = "Crude Fireball"
	cooldown_time = 45 SECONDS
	cooldown_reduction_per_rank = 0 SECONDS

/**
 * The refined word: the same bolt, thirty seconds instead of forty-five, a
 * whispered invocation in place of the shout, and a tighter blast. Contact
 * damage is untouched, the upgrade buys tempo and control, not more damage.
 */
/datum/action/cooldown/spell/pointed/projectile/fireball/vestige/refined
	name = "Refined Fireball"
	desc = "Throw a fireball. A shorter wait between casts, whispered instead of shouted, and a tighter blast."
	cooldown_time = 30 SECONDS
	invocation = "oni soma."
	invocation_type = INVOCATION_WHISPER
	projectile_type = /obj/projectile/magic/fireball/vestige_refined

/// The refined fireball's bolt: same flame and contact damage, smaller
/// structural splash. Mastery reads as control, and ships only have one hull.
/obj/projectile/magic/fireball/vestige_refined
	exp_light = 1 // upstream 2
	exp_flash = 2 // upstream 3

/**
 * The greater word of opening. Upstream knock's cast chain is clean (garb-free,
 * turf-signal based), so this subtype extends it: wider reach, shorter
 * cooldown, and airlock bolts are thrown before the door is asked to open.
 * Base knock's COMSIG_ATOM_MAGICALLY_UNLOCKED handler calls open(), which
 * refuses while locked (verified in door.dm / airlock.dm). Welded, sealed and
 * unpowered doors still hold, so a determined defender keeps counterplay.
 */
/datum/action/cooldown/spell/aoe/knock/vestige_greater
	name = "Greater Knock"
	desc = "Opens nearby doors and closets, and throws the bolts on bolted airlocks."
	cooldown_time = 8 SECONDS // upstream 10
	invocation = "AULIE OXIN FIERA, OMNE!"
	aoe_radius = 4 // upstream 3

/datum/action/cooldown/spell/aoe/knock/vestige_greater/cast_on_thing_in_aoe(turf/victim, atom/caster)
	for(var/obj/machinery/door/airlock/bolted in victim)
		if(bolted.locked)
			bolted.unbolt()
	return ..()

/**
 * The word of passage. Upstream blink's cast chain is clean (_teleport.dm +
 * blink.dm: pick a random nearby turf, do_teleport on the magic channel), but
 * the spell never overrides the base-spell default spell_requirements of
 * SPELL_REQUIRES_WIZARD_GARB|SPELL_REQUIRES_NO_ANTIMAGIC, so as shipped it is
 * garb-locked. This subtype drops the garb half, keeps the antimagic hook, and
 * slows the word to crew tempo, the wizard version recasts every 2 seconds.
 * The destination stays random: the word says away, not where.
 */
/datum/action/cooldown/spell/teleport/radius_turf/blink/vestige_passage
	name = "Word of Passage"
	desc = "Teleports you a short distance in a random direction."
	cooldown_time = 10 SECONDS
	invocation = "sic itur."
	invocation_type = INVOCATION_WHISPER
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC

/**
 * The word of denial. Upstream forcewall is already garb-free
 * (SPELL_REQUIRES_NO_ANTIMAGIC) and its cast is clean: three caster-keyed
 * /obj/effect/forcefield/wizard with a 30 second lifetime, which antimagic
 * bearers simply walk through. Only the cooldown is retuned, upstream's 10
 * seconds lets several wall-lines stand at once, so this word matches its
 * cooldown to the wall's lifetime. One denial at a time; no corridor lockdown.
 */
/datum/action/cooldown/spell/forcewall/vestige_denial
	name = "Word of Denial"
	desc = "Raise a barrier only you can pass through. It holds for a while."
	cooldown_time = 30 SECONDS // upstream 10; matched to the wall's 30 second lifetime
