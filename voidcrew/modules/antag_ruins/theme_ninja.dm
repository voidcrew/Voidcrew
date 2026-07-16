/**
 * # The Silent Dojo — space ninja vestige
 *
 * A Spider Clan training hall drifting cold, mats still swept. The master's
 * suit still kneels at the head of the room; the master, as far as anyone can
 * tell, is not in it. Trials are lessons — the thrown star (precision), the
 * unseen hand (silence), stillness (patience). Ninja kit is pure gear (zero
 * antag coupling), so the boons are the clan's own kit and drills: the blade
 * (its dash action rides the item and grants on equip, verified upstream), a
 * finite case of true stars, and smoke/footwork techniques built as
 * standalone spells — every upstream ninja ABILITY lives on the MOD suit's
 * modules and checks mod.wearer (modules_ninja.dm), so none of those port;
 * the techniques here are local reimplementations.
 */

// Stars in the clan's lacquered case. Keep the boon desc's "six" in sync —
// initial() values must be compile-time constant, so no interpolation there.
#define VESTIGE_CLAN_STAR_COUNT 6
// Distinct people the Lesson of the Unseen Hand must mark unnoticed. Keep the
// trial desc's "four" in sync.
#define VESTIGE_UNSEEN_MARKS_NEEDED 4
// How long the clan seal takes to press home (the victim's window to turn)
#define VESTIGE_SEAL_PRESS_TIME (1.5 SECONDS)
// Unbroken seconds of kneeling the Lesson of Stillness demands. Keep the
// trial desc's "three minutes" in sync.
#define VESTIGE_STILLNESS_SECONDS_NEEDED 180
// Witnesses sharpen the lesson: stillness credit multiplier while any other
// conscious creature can see the vigil. Keep the trial desc's "double" in sync.
#define VESTIGE_STILLNESS_WITNESS_MULTIPLIER 2

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
		/datum/vestige_boon/item/clan_stars,
		/datum/vestige_boon/spell/veiling_smoke,
		/datum/vestige_boon/spell/veiling_smoke/vanishing,
		/datum/vestige_boon/spell/soundless_step,
		/datum/vestige_boon/spell/soundless_step/weightless,
	)
	idle_lines = list(
		"You are looking for the master. The master is looking back. Do not ask from where.",
		"Every student asks about the blade first. The blade is the last lesson. The first lesson is the walk back to pick up what you threw.",
		"This hall has heard ten thousand footsteps. Yours are the loudest so far. We will work on that.",
		"The suit is not empty. It is exactly as full as it needs to be.",
		"Stillness is not the absence of motion. It is motion, perfectly spent.",
		"My finest students are the ones you do not remember meeting.",
	)
	accept_line = "Begin. The lesson does not care how good you think you are. No lesson ever has."
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

// ===== LESSON OF THE UNSEEN HAND =====

/datum/vestige_trial/unseen_hand
	name = "Lesson of the Unseen Hand"
	// Keep the count in sync with VESTIGE_UNSEEN_MARKS_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the seal. Press it between the shoulder blades of four different people — living, standing, and looking anywhere but at you. They will feel it a heartbeat too late; that is permitted. The lesson is not that they never know. The lesson is that knowing comes after."
	/// Victims already marked (weakref -> TRUE); each person teaches the lesson once
	var/list/marked = list()

/datum/vestige_trial/unseen_hand/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_clan_seal(get_turf(user)))
	to_chat(user, span_notice("The seal settles into your palm, lighter than the paper it is made of."))

/datum/vestige_trial/unseen_hand/get_progress_text()
	return "You have marked [length(marked)] of [VESTIGE_UNSEEN_MARKS_NEEDED] unwary backs."

/// Credits an unseen mark. May complete (and delete) the trial. Returns FALSE if this victim already taught their lesson.
/datum/vestige_trial/unseen_hand/proc/mark(mob/living/victim)
	var/datum/weakref/key = WEAKREF(victim)
	if(marked[key])
		return FALSE
	marked[key] = TRUE
	refresh_tracker()
	if(length(marked) >= VESTIGE_UNSEEN_MARKS_NEEDED)
		complete()
	return TRUE

/obj/item/vestige_clan_seal
	name = "clan paper seal"
	desc = "A strip of rice paper inked with the Spider Clan's mark. The ink never dries. It is waiting for a back that has not noticed it coming."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper_talisman"
	color = "#9c94b8"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_clan_seal/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!ishuman(target) || target == user)
		return ..()
	var/datum/vestige_trial/unseen_hand/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the ink lies dead on the paper!")
		return
	var/mob/living/carbon/human/victim = target
	// The mark wants a person: awake, upright, and someone home behind the eyes
	// (mind check — mindless monkeys and empty bodies teach nothing)
	if(victim.stat != CONSCIOUS || victim.body_position != STANDING_UP || !victim.mind)
		balloon_alert(user, "the seal wants someone awake and upright!")
		return
	if(is_source_facing_target(victim, user))
		balloon_alert(user, "they would see you!")
		return
	// A short silent press. The channel's cog is the tell a watchful room gets,
	// and the victim stepping away breaks it — turning around is checked at the end.
	if(!do_after(user, VESTIGE_SEAL_PRESS_TIME, target = victim))
		return
	if(!user.is_holding(src))
		return
	// Re-resolve; the pact may have been renounced mid-press
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return
	if(victim.stat != CONSCIOUS || victim.body_position != STANDING_UP)
		balloon_alert(user, "the moment passed!")
		return
	// They turned in time: the mark refused, the student caught red-handed
	if(is_source_facing_target(victim, user))
		to_chat(victim, span_userdanger("You catch [user] standing much too close behind you, hand outstretched!"))
		balloon_alert(user, "seen!")
		return
	if(!trial.mark(victim))
		balloon_alert(user, "already marked!")
		return
	balloon_alert(user, "marked")
	to_chat(user, span_notice("The seal kisses the cloth between [victim]'s shoulder blades and comes away blank. Somewhere, something nods."))
	// The tell lands a heartbeat after the touch: this one can never be farmed
	// again, and from now on they know to watch their back
	to_chat(victim, span_warning("A featherlight pressure between your shoulder blades, gone before you can flinch. You have the sudden, certain feeling of being watched."))

// ===== LESSON OF STILLNESS =====

/datum/vestige_trial/stillness
	name = "Lesson of Stillness"
	// Keep the duration and multiplier in sync with VESTIGE_STILLNESS_SECONDS_NEEDED
	// / VESTIGE_STILLNESS_WITNESS_MULTIPLIER (initial values must be constant, so no
	// define interpolation here)
	desc = "Take the incense. Kneel somewhere the world is loud — not here; the hall is still enough — hold it before you, and be still. Three minutes, unbroken. Move, rise or faint, and the count returns to nothing. Stillness that is watched counts double. An audience is a whetstone."
	/// Unbroken seconds of stillness credited so far
	var/seconds_still = 0
	/// "x:y:z" of last tick's kneeling spot; changing it resets the count
	var/last_spot

/datum/vestige_trial/stillness/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_incense(get_turf(user)))
	to_chat(user, span_notice("The incense is already lit. You suspect it has always been lit."))

/datum/vestige_trial/stillness/get_progress_text()
	if(seconds_still <= 0)
		return "The count stands at nothing. Kneel, and be still for [VESTIGE_STILLNESS_SECONDS_NEEDED] unbroken seconds."
	return "You have been still for [round(seconds_still)] of [VESTIGE_STILLNESS_SECONDS_NEEDED] unbroken seconds."

/// Credits unbroken stillness. May complete (and delete) the trial.
/datum/vestige_trial/stillness/proc/hold_still(seconds)
	seconds_still += seconds
	refresh_tracker()
	if(seconds_still >= VESTIGE_STILLNESS_SECONDS_NEEDED)
		complete()

/// Resets the count, with a word from the master when real progress was lost
/datum/vestige_trial/stillness/proc/break_stillness()
	if(seconds_still <= 0)
		return
	var/lost = seconds_still
	seconds_still = 0
	refresh_tracker()
	if(lost < 15) // fidgets are beneath comment
		return
	var/mob/living/user = owner?.current
	if(isliving(user))
		to_chat(user, span_warning("The stillness breaks — [round(lost)] seconds, spent on nothing. The count begins again."))

/obj/item/vestige_incense
	name = "temple incense"
	desc = "A stick of grave-grey incense that was burning before you picked it up and will be burning after you set it down. The smoke rises in a perfectly straight line. It is taking attendance."
	icon = 'icons/obj/cigarettes.dmi'
	icon_state = "cigon"
	color = "#b09a78"
	w_class = WEIGHT_CLASS_TINY
	light_range = 1.2
	light_power = 0.5
	light_color = "#cc8844"

/obj/item/vestige_incense/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/vestige_incense/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

// Setting the incense down breaks the vigil on the spot — the process tick
// would catch it within two seconds anyway, but a lesson should not be laggy
/obj/item/vestige_incense/dropped(mob/user, silent = FALSE)
	. = ..()
	var/datum/vestige_trial/stillness/trial = user?.mind?.active_vestige_trial
	if(istype(trial))
		trial.break_stillness()

/obj/item/vestige_incense/process(seconds_per_tick)
	var/mob/living/holder = loc
	if(!istype(holder))
		return
	var/datum/vestige_trial/stillness/trial = holder.mind?.active_vestige_trial
	if(!istype(trial))
		return
	// The dojo keeps no count: it is already still (mirrors the sepulcher's chalk)
	if(istype(get_area(holder), /area/ruin/space/has_grav/vestige))
		if(holder.resting && holder.is_holding(src) && SPT_PROB(3, seconds_per_tick))
			to_chat(holder, span_notice("The incense keeps no count here. Kneel somewhere the world is loud."))
		return
	// The vigil holds only kneeling, conscious, incense in hand...
	var/kneeling = holder.is_holding(src) \
		&& holder.stat == CONSCIOUS \
		&& holder.resting \
		&& holder.body_position == LYING_DOWN
	if(!kneeling)
		trial.last_spot = null
		trial.break_stillness()
		return
	// ...and only without an inch of drift. Taking a hit and holding the pose
	// is allowed — the master is not unreasonable, merely empty.
	var/turf/here = get_turf(holder)
	var/spot = here ? "[here.x]:[here.y]:[here.z]" : null
	if(!spot || spot != trial.last_spot)
		trial.last_spot = spot
		trial.break_stillness()
		return
	// Witnesses sharpen the lesson: any other conscious creature in sight doubles the credit
	var/credit = seconds_per_tick
	for(var/mob/living/watcher in oview(7, holder))
		if(watcher.stat != CONSCIOUS)
			continue
		credit *= VESTIGE_STILLNESS_WITNESS_MULTIPLIER
		break
	// The smoke advertises the vigil to the room; the kneeler is defenseless on purpose
	if(SPT_PROB(4, seconds_per_tick))
		holder.visible_message(
			span_notice("The smoke from [holder]'s incense rises in a line that does not waver."),
			span_notice("The smoke rises, straight as a plumb line. The count continues."),
		)
	trial.hold_still(credit)

// ===== BOONS =====

// The katana is fully standalone: its dash action rides the item and grants
// on equip, no suit or antag datum required.
/datum/vestige_boon/item/master_blade
	name = "The Master's Blade"
	desc = "The clan's energy katana. It cuts what it is told to, parries what it is not, and — thrown or right-clicked across a gap — takes you with it, three steps at a time."
	grant_text = "A hilt finds your hand as if it had been waiting there all along."
	item_type = /obj/item/energy_katana

// The stars are likewise pure gear: /obj/item/throwing_star/stamina/ninja is
// just a name and throwforce bump over the shock star (ninja_stars.dm), and
// its embedding datum (pain_stam_pct 0.8) trades most of the hurt for stamina
// pain — folds legs long before it stops hearts. The case is finite on
// purpose: no refills, six throws, go fetch.
/datum/vestige_boon/item/clan_stars
	name = "The Clan's Stars"
	desc = "Six true stars, clan pattern. Thrown, they bite and stay where they land, and the sting folds legs long before it troubles hearts. Six is not a shortage. It is a counting lesson."
	grant_text = "A lacquered case finds your hands. It weighs exactly as much as six decisions."
	item_type = /obj/item/storage/box/vestige_star_case

/obj/item/storage/box/vestige_star_case
	name = "lacquered star case"
	desc = "A slim black case, swept spotless inside. Fittings for six Spider Clan throwing stars — the real ones, the ones that do not apologize on impact."
	icon_state = "syndiebox"
	illustration = null
	foldable_result = null // lacquer does not fold into cardboard
	storage_type = /datum/storage/box/vestige_star_case

/obj/item/storage/box/vestige_star_case/PopulateContents()
	for(var/i in 1 to VESTIGE_CLAN_STAR_COUNT)
		new /obj/item/throwing_star/stamina/ninja(src)

/datum/storage/box/vestige_star_case
	max_slots = VESTIGE_CLAN_STAR_COUNT
	max_total_storage = WEIGHT_CLASS_SMALL * VESTIGE_CLAN_STAR_COUNT

/datum/storage/box/vestige_star_case/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	// Stars only — including the training one, for students who still fetch
	set_holdable(/obj/item/throwing_star)

/datum/vestige_boon/spell/veiling_smoke
	name = "The Veiling Smoke"
	desc = "Dash a charge at your feet and give every eye in the room something to fail at. The cloud does not poison and does not fight; it simply stands where you were. Standing where you were is the enemy's job."
	grant_text = "You are shown, once, how to fold a room away. Your hands remember it before you do."
	spell_type = /datum/action/cooldown/spell/vestige_veiling_smoke

/datum/vestige_boon/spell/veiling_smoke/vanishing
	name = "The Vanishing Smoke"
	desc = "The same cloud, mastered: quicker to your hand, and as it swallows the room it sets you down a few paces from where anyone last agreed you were. The smoke does not hide you. It corrects them."
	grant_text = "The lesson completes itself. The smoke no longer expects you to stand still inside it."
	upgrades_from = /datum/vestige_boon/spell/veiling_smoke
	spell_type = /datum/action/cooldown/spell/teleport/radius_turf/vestige_vanishing_smoke

/datum/vestige_boon/spell/soundless_step
	name = "The Soundless Step"
	desc = "A walking stance, nothing more: heel, edge, breath, repeat, until the deck stops gossiping about you. Take it up and set it down as you please. Silence is not a trick; it is housekeeping."
	grant_text = "Your next footstep declines to report you. Somewhere, a lesson is marked complete."
	spell_type = /datum/action/cooldown/spell/vestige_soundless_step

/datum/vestige_boon/spell/soundless_step/weightless
	name = "The Weightless Step"
	desc = "Silence was half the stance. Weight is the rest: feet that no longer argue with wet decking or ice, and no longer lose. Industrial lubricant will still teach you humility — some floors outrank any student."
	grant_text = "Your feet unlearn their weight. The floor files no further complaints."
	upgrades_from = /datum/vestige_boon/spell/soundless_step
	spell_type = /datum/action/cooldown/spell/vestige_soundless_step/weightless

/**
 * The clan's smoke bomb, built local. The upstream ninja-kit smoke spell
 * (/datum/action/cooldown/spell/smoke, sold to traitors as a granter book) is
 * already standalone, but it is the choking kind — /bad smoke drops held
 * items and stacks oxyloss on a 12-second cooldown. The crew-earnable art is
 * the polite version: plain opaque smoke (vision denial only, ~10 second
 * lifetime, no mob effects — verified in effects_smoke.dm) on a longer leash.
 * The smoke itself is spawned by the spell base's after_cast, driven by
 * smoke_type/smoke_amt (smoke_amt is a RANGE; 3 covers a decent room).
 */
/datum/action/cooldown/spell/vestige_veiling_smoke
	name = "Veiling Smoke"
	desc = "Dash a smoke charge at your feet, flooding the area with dense — but harmless — smoke."
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
 * (/datum/action/cooldown/spell/teleport/radius_turf — verified standalone,
 * no garb or antag checks beyond spell_requirements, which we clear).
 * do_teleport runs unforced under TELEPORT_CHANNEL_MAGIC, so TRAIT_NO_TELEPORT
 * and NOTELEPORT areas still say no — the smoke drops either way, the step
 * simply fails. Origin smoke is spawned by hand in cast(): the base class's
 * smoke_type/smoke_amt puffs in after_cast at the owner's CURRENT turf, which
 * is post-teleport — the wrong end of a vanishing act.
 */
/datum/action/cooldown/spell/teleport/radius_turf/vestige_vanishing_smoke
	name = "Vanishing Smoke"
	desc = "Dash down a smoke charge and let the cloud keep your place. You will already be a few paces elsewhere."
	button_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "ninja_phase"
	background_icon_state = "bg_agent"
	overlay_icon_state = "bg_agent_border"
	sound = 'sound/effects/smoke.ogg'
	cooldown_time = 20 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	inner_tele_radius = 1
	outer_tele_radius = 3 // a sidestep, not an escape — the wizard blink this rides on reaches 6
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
 * Silent footwork as a held stance. There is no upstream spell to port — the
 * ninja gets TRAIT_SILENT_FOOTSTEPS from the MOD cloaking module
 * (modules_ninja.dm), which is suit-bound — so this is a from-scratch toggle
 * on the same trait (name verified against __DEFINES/traits/declarations.dm).
 * Traits are keyed to REF(src) and stripped in Remove(), so an upgrade
 * replacing this action — or a body swap re-homing it (action Destroy and
 * mind transfer both route through Remove) — can never strand them; the
 * stance simply drops and must be retaken.
 */
/datum/action/cooldown/spell/vestige_soundless_step
	name = "Soundless Step"
	desc = "Take up the clan's walking stance, silencing your footsteps. Use again to set the stance down."
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

// The perfected stance adds galoshes-tier footing (water and ice only —
// TRAIT_NO_SLIP_ALL stays with the heretics; space lube still wins)
/datum/action/cooldown/spell/vestige_soundless_step/weightless
	name = "Weightless Step"
	desc = "Take up the perfected walking stance: silent footsteps, and no slipping on water or ice. Use again to set the stance down."
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

#undef VESTIGE_CLAN_STAR_COUNT
#undef VESTIGE_UNSEEN_MARKS_NEEDED
#undef VESTIGE_SEAL_PRESS_TIME
#undef VESTIGE_STILLNESS_SECONDS_NEEDED
#undef VESTIGE_STILLNESS_WITNESS_MULTIPLIER
