/**
 * # The Gloaming — nightmare vestige
 *
 * A freighter that went dark mid-burn, in every sense. The map itself is the
 * hazard: bring a light, and know the patron wants it gone. Every trial is a
 * lesson in the dark — snuff the lights, teach the living to fear them, or
 * simply sit in the black long enough that it starts sitting back. The boons
 * are the nightmare's own: the shadow it walks, the terror it projects, the
 * lights it puts out, and the wounds the dark closes when no one is looking.
 *
 * Two upgrade chains (the shadow-walk and the terror) plus two standalones
 * (the snuff and the dark-heal), all human-castable ports — the nightmare's
 * body IS the antag, so nothing here needs a shadow species or a heart of
 * darkness to work.
 */

// Tuning constants for the Stranger's new trials (file-local, #undef at bottom)
/// Distinct living people the Stranger's regard must be fixed upon, in the dark
#define VESTIGE_WATCHED_NEEDED 4
/// How long the regard must hold on a victim before it takes
#define VESTIGE_WATCHED_DO_AFTER (3 SECONDS)
/// Cumulative seconds spent conscious in darkness the Long Night demands
#define VESTIGE_LONG_NIGHT_SECONDS 180

// Tuning constants for the Stranger's ports (file-local, #undef at bottom)
/// Brute+burn per SSobj tick the Umbral Passage's deeper dark knits (base jaunt is 1.5)
#define VESTIGE_UMBRAL_HEAL_RATE 3
/// How far Creeping Dread bleeds terror into the dark around its target
#define VESTIGE_DREAD_RADIUS 4
/// Radius of lights Snuff reaches out and puts out
#define VESTIGE_SNUFF_RADIUS 4
/// Brute+burn a single Heart of Darkness closes, castable only in the dark
#define VESTIGE_DARKHEAL_AMOUNT 25

// ===== PATRON =====

/mob/living/basic/vestige_patron/stranger
	name = "the Stranger"
	desc = "A silhouette with its proportions slightly off, pinned under a dead floodlight like a moth. It is only visible because it is darker than the dark behind it."
	gender = NEUTER
	outfit_path = /datum/outfit/job/assistant
	appearance_tint = "#151515"
	trial_types = list(
		/datum/vestige_trial/snuffed_flame,
		/datum/vestige_trial/the_watched,
		/datum/vestige_trial/long_night,
	)
	boon_types = list(
		/datum/vestige_boon/spell/shadow_walk,
		/datum/vestige_boon/spell/shadow_walk/umbral,
		/datum/vestige_boon/spell/terrorize,
		/datum/vestige_boon/spell/terrorize/creeping_dread,
		/datum/vestige_boon/spell/snuff,
		/datum/vestige_boon/spell/heart_of_darkness,
	)
	idle_lines = list(
		"You brought a light. They always bring a light. Put it out and we can talk properly.",
		"There were four hundred lights on this ship. I remember every one of them going out.",
		"The dark is not empty. The dark is full. The light is what's empty.",
		"I am not trapped under this lamp. The lamp is trapped over me.",
		"Fear is only the dark, felt from the inside. I can teach you to be the room, instead of the one standing in it.",
		"Sit a while. Do not fill the silence. The silence is where I keep everything worth having.",
	)
	accept_line = "Good. Go into the dark, and do the work the dark asks of you."
	busy_line = "One debt. Then another. Not both at once."
	fulfilled_line = "You have already learned that one. The dark does not repeat itself."
	renounce_line = "Then keep squinting."
	claim_line = "You are owed. I always pay. Take it."
	exhausted_line = "You have everything I kept. The rest went out with the lights."
	remember_line = "You went dark. Everything does. What you earned was waiting where you left it."

// ===== TRIAL OF THE SNUFFED FLAME =====

/datum/vestige_trial/snuffed_flame
	name = "Trial of the Snuffed Flame"
	// Keep the count in sync with VESTIGE_FLAME_LIGHTS_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the censer. Feed it twenty-five burning lights — fixtures, lanterns, flares, it is not picky. Lights snatched out of someone's living grip taste twice as sweet. When it is sated, you will not need eyes the way you do now."
	/// Devour points so far (a light in someone else's grip counts double)
	var/lights_eaten = 0

/datum/vestige_trial/snuffed_flame/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_censer(get_turf(user)))

/datum/vestige_trial/snuffed_flame/get_progress_text()
	return "The censer has eaten [lights_eaten] of [VESTIGE_FLAME_LIGHTS_NEEDED] lights."

/// May complete (and delete) the trial
/datum/vestige_trial/snuffed_flame/proc/feed(points)
	lights_eaten += points
	refresh_tracker()
	if(lights_eaten >= VESTIGE_FLAME_LIGHTS_NEEDED)
		complete()

/obj/item/vestige_censer
	name = "darklight censer"
	desc = "A lantern that burns backwards. Whatever light it touches goes somewhere else, and does not come back."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "syndilantern"
	w_class = WEIGHT_CLASS_SMALL
	force = 5

/obj/item/vestige_censer/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!devour_lights(interacting_with, user))
		return NONE
	user.do_attack_animation(interacting_with)
	user.changeNext_move(CLICK_CD_MELEE)
	return ITEM_INTERACT_SUCCESS

// Combat-mode swings still feed the censer (plus the bonk)
/obj/item/vestige_censer/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	devour_lights(target, user)

/**
 * Eats every light attached to the target, permanently. Mirrors
 * /datum/element/light_eater's devour rules, but counts morsels for the
 * wielder's trial — the shared element signals on the element instance, which
 * is useless for per-item credit, hence the local copy.
 *
 * Returns the devour points scored (held lights are worth double).
 */
/obj/item/vestige_censer/proc/devour_lights(atom/food, mob/living/user)
	var/list/buffet = list()
	SEND_SIGNAL(food, COMSIG_LIGHT_EATER_QUEUE, buffet, src)
	for(var/datum/light_source/morsel_source as anything in food.light_sources)
		buffet[morsel_source.source_atom] = TRUE
	if(!length(buffet))
		return 0

	var/points = 0
	for(var/atom/morsel as anything in buffet)
		if(morsel == src)
			continue
		if(istype(morsel, /turf/open/space) || istype(morsel, /turf/open/lava))
			continue
		if(istransparentturf(morsel))
			continue
		if(morsel.light_power <= 0 || morsel.light_range <= 0 || !morsel.light_on)
			continue
		if(SEND_SIGNAL(morsel, COMSIG_LIGHT_EATER_ACT, src) & COMPONENT_BLOCK_LIGHT_EATER)
			continue
		morsel.AddElement(/datum/element/light_eaten)
		points += (ismob(morsel.loc) && morsel.loc != user) ? 2 : 1

	if(!points)
		return 0
	food.visible_message(
		span_danger("The dark inside [src] lashes out at [food], and the light goes with it!"),
		span_userdanger("Something hungry snuffs your light out from inside [src]!"),
	)
	playsound(src, 'sound/effects/magic/blind.ogg', 40, TRUE)
	var/datum/vestige_trial/snuffed_flame/trial = user?.mind?.active_vestige_trial
	if(istype(trial))
		trial.feed(points)
	return points

// ===== TRIAL OF THE WATCHED =====

/datum/vestige_trial/the_watched
	name = "Trial of the Watched"
	// Keep the count in sync with VESTIGE_WATCHED_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the eye. It is mine — I have others. Find the living in the dark and hold it on them, close, until they feel what it is to be seen by something that should not have eyes. Four of them, each their own person. Give them a taste of the fear I keep, and you will learn to pour it yourself."
	/// Victims already regarded (weakref -> TRUE), so no one is counted twice
	var/list/watched = list()

/datum/vestige_trial/the_watched/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_regard(get_turf(user)))

/datum/vestige_trial/the_watched/get_progress_text()
	return "The regard has been fixed upon [length(watched)] of [VESTIGE_WATCHED_NEEDED] of the living."

/// May complete (and delete) the trial. Returns FALSE if this victim was already regarded.
/datum/vestige_trial/the_watched/proc/regard(mob/living/victim)
	var/datum/weakref/key = WEAKREF(victim)
	if(watched[key])
		return FALSE
	watched[key] = TRUE
	refresh_tracker()
	if(length(watched) >= VESTIGE_WATCHED_NEEDED)
		complete()
	return TRUE

/obj/item/vestige_regard
	name = "the Stranger's regard"
	desc = "A single eye, kept moist and open, that does not belong to you and does not much care for you. Held up in the dark, it looks at whatever you look at, and whatever you look at feels it."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "eyes"
	w_class = WEIGHT_CLASS_TINY
	color = "#8a8a8a"

/obj/item/vestige_regard/examine(mob/user)
	. = ..()
	. += span_notice("Held on someone living, in the dark, it teaches them the fear the Stranger keeps. The same soul never learns it twice.")

/obj/item/vestige_regard/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with))
		return NONE
	var/mob/living/victim = interacting_with
	var/datum/vestige_trial/the_watched/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "just a dead man's eye")
		return ITEM_INTERACT_BLOCKING
	if(victim == user)
		balloon_alert(user, "it will not look at you")
		return ITEM_INTERACT_BLOCKING
	if(victim.stat == DEAD)
		balloon_alert(user, "past all fear")
		return ITEM_INTERACT_BLOCKING
	var/turf/victim_turf = get_turf(victim)
	if(!victim_turf || victim_turf.get_lumcount() > LIGHTING_TILE_IS_DARK)
		balloon_alert(user, "too much light on them")
		return ITEM_INTERACT_BLOCKING
	if(trial.watched[WEAKREF(victim)])
		balloon_alert(user, "already made to see")
		return ITEM_INTERACT_BLOCKING
	victim.visible_message(
		span_warning("[user] holds something small and wet up toward [victim], and it turns to look at [victim.p_them()]."),
		span_userdanger("Something in [user]'s hand fixes on you, and the dark leans in with it."),
	)
	if(!do_after(user, VESTIGE_WATCHED_DO_AFTER, target = victim))
		balloon_alert(user, "the regard slipped")
		return ITEM_INTERACT_BLOCKING
	// Re-resolve; the pact may have been renounced mid-regard
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return ITEM_INTERACT_BLOCKING
	if(victim.stat == DEAD || trial.watched[WEAKREF(victim)])
		return ITEM_INTERACT_BLOCKING
	victim.apply_status_effect(/datum/status_effect/terrified)
	playsound(victim, 'sound/effects/magic/blind.ogg', 30, TRUE)
	trial.regard(victim) // may complete (and delete) the trial — nothing touches it after this
	return ITEM_INTERACT_SUCCESS

// ===== TRIAL OF THE LONG NIGHT =====

/datum/vestige_trial/long_night
	name = "Trial of the Long Night"
	// Keep the duration in sync with VESTIGE_LONG_NIGHT_SECONDS
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the glass. Then do the hardest thing anyone ever asked of you: nothing. Carry it into the dark and stay there, awake, until three whole minutes of blackness have soaked into you. Step into the light and the clock only pauses — it does not forgive, but it does not punish. Sit with me long enough and you will stop needing the light to close a wound."
	/// Cumulative deciseconds spent conscious in darkness
	var/dark_time = 0
	/// The loaned kit item, reclaimed (deleted) the moment the pact ends
	var/obj/item/vestige_gloom_glass/glass

/datum/vestige_trial/long_night/on_accepted(mob/living/user)
	glass = hand_over(user, new /obj/item/vestige_gloom_glass(get_turf(user)))
	glass.commune_with(user.mind)
	to_chat(user, span_notice("The glass is cold, and heavier than it should be, and in no hurry at all."))

/datum/vestige_trial/long_night/Destroy()
	QDEL_NULL(glass)
	return ..()

/datum/vestige_trial/long_night/get_progress_text()
	return "The dark has soaked in for [DisplayTimeText(dark_time)] of [DisplayTimeText(VESTIGE_LONG_NIGHT_SECONDS SECONDS)]."

/// Accrues communion time. May complete (and delete) the trial.
/datum/vestige_trial/long_night/proc/commune(deciseconds)
	dark_time += deciseconds
	refresh_tracker()
	if(dark_time < VESTIGE_LONG_NIGHT_SECONDS SECONDS)
		return
	if(glass)
		glass.visible_message(span_boldnotice("[glass] goes perfectly, finally dark, and stops being cold. The long night is kept."))
		playsound(glass, 'sound/effects/magic/curse.ogg', 40, TRUE)
	complete()

/obj/item/vestige_gloom_glass
	name = "gloom-glass"
	desc = "A shard of black glass that is always a little colder than the room. Held in the dark, it drinks the black in and grows heavier. In the light it only waits, patiently, to be taken back where it belongs."
	icon = 'icons/obj/debris.dmi'
	icon_state = "large"
	color = "#101015"
	w_class = WEIGHT_CLASS_SMALL
	/// Mind of the one keeping the long night (resolved fresh each tick so it rides body swaps)
	var/datum/mind/keeper

/obj/item/vestige_gloom_glass/Destroy()
	STOP_PROCESSING(SSobj, src)
	keeper = null
	return ..()

/obj/item/vestige_gloom_glass/examine(mob/user)
	. = ..()
	. += span_notice("Carried in your own hands, awake and in near-total darkness, it soaks up the long night. Light pauses it; it never spills what it has already drunk.")

/// Binds the glass to the trial-keeper's mind and starts the communion clock
/obj/item/vestige_gloom_glass/proc/commune_with(datum/mind/mind)
	keeper = mind
	START_PROCESSING(SSobj, src)

/obj/item/vestige_gloom_glass/process(seconds_per_tick)
	var/datum/vestige_trial/long_night/trial = keeper?.active_vestige_trial
	if(!istype(trial)) // pact ended out from under us; the trial reclaims the glass on its way out
		STOP_PROCESSING(SSobj, src)
		return
	var/mob/living/body = keeper.current
	if(!isliving(body) || body.stat != CONSCIOUS)
		return
	if(loc != body) // it only drinks for the hand that carries it
		return
	var/turf/here = get_turf(body)
	if(!here || here.get_lumcount() > LIGHTING_TILE_IS_DARK)
		return
	if(SPT_PROB(3, seconds_per_tick))
		to_chat(body, span_notice("The gloom-glass grows a little heavier in your hand. The dark is settling into it."))
	trial.commune(seconds_per_tick * (1 SECONDS)) // may complete (and delete) the trial and us with it

// ===== BOONS =====

// --- Chain: the shadow walk ---

// The nightmare's jaunt, granted as-is: upstream ships it with
// spell_requirements = NONE, and light already polices it.
/datum/vestige_boon/spell/shadow_walk
	name = "Shadow Walk"
	desc = "Sink into darkness and move unseen through it. The dark stops being a place and starts being a door."
	grant_text = "The dark stops being a place and starts being a door."
	spell_type = /datum/action/cooldown/spell/jaunt/shadow_walk

/datum/vestige_boon/spell/shadow_walk/umbral
	name = "Umbral Passage"
	desc = "The shadow walk, gone deeper. The dark knits your wounds twice as fast while you swim in it, tolerates the dimmer half-lit places it once spat you out of, and leaves a moment of the nightmare's own reflexes on you when you surface — long enough to sway aside a bullet."
	grant_text = "You go deeper into the dark than the walk ever let you before, and it does not push back."
	upgrades_from = /datum/vestige_boon/spell/shadow_walk
	spell_type = /datum/action/cooldown/spell/jaunt/shadow_walk/vestige_umbral

/**
 * The shadow walk mastered: a subtype of the nightmare's own jaunt (still
 * spell_requirements = NONE, still light-policed) that tolerates dimmer tiles,
 * heals faster inside the dark, and leaves a two-second echo of the nightmare's
 * bullet-dodge reflexes on whoever surfaces from it.
 */
/datum/action/cooldown/spell/jaunt/shadow_walk/vestige_umbral
	name = "Umbral Passage"
	desc = "Sink into darkness and move unseen through it, faster to heal and slower to be forced out. Surfacing leaves you briefly, dangerously quick."
	light_threshold = 0.35
	jaunt_type = /obj/effect/dummy/phased_mob/shadow/vestige_umbral

/// A deeper shadow: heals faster than the base jaunt and, on ejecting the
/// jaunter, leaves them with a brief flicker of the nightmare's reflexes.
/obj/effect/dummy/phased_mob/shadow/vestige_umbral
	healing_rate = VESTIGE_UMBRAL_HEAL_RATE

/obj/effect/dummy/phased_mob/shadow/vestige_umbral/eject_jaunter(forced_out = FALSE)
	var/mob/living/emerging = jaunter
	. = ..()
	if(isliving(emerging) && !QDELETED(emerging))
		emerging.apply_status_effect(/datum/status_effect/shadow/nightmare)

// --- Chain: the terror ---

// The nightmare's Terrorize, granted as-is: upstream ships it with
// spell_requirements = NONE and it only applies the (self-contained) terror
// status effect, so it works on a plain human caster untouched.
/datum/vestige_boon/spell/terrorize
	name = "Terrorize"
	desc = "Stare a soul down in the dark and pour dread into them until they shake, stutter, and fold. It only works where you are the darkest thing in the room, so put the lights out first."
	grant_text = "You catch your own reflection in a dead screen, and it holds your gaze a half-second too long."
	spell_type = /datum/action/cooldown/spell/pointed/terrorize

/datum/vestige_boon/spell/terrorize/creeping_dread
	name = "Creeping Dread"
	desc = "The terror, taught to spread. Fix it on one soul in the dark and it seeps into every other living thing standing in the black around them. Fear was always contagious. You just make the incubation instant."
	grant_text = "The dread you carry stops being something you aim, and starts being something you leak."
	upgrades_from = /datum/vestige_boon/spell/terrorize
	spell_type = /datum/action/cooldown/spell/pointed/terrorize/vestige_dread

/**
 * Terrorize that spreads. The parent cast lays terror on the aimed target
 * (and keeps the must-be-in-the-dark targeting); this seeps the same dread
 * into every other human standing in darkness nearby — the caster excepted.
 */
/datum/action/cooldown/spell/pointed/terrorize/vestige_dread
	name = "Creeping Dread"
	desc = "Project terror into a victim in the dark — and into everyone else standing in the black around them."
	cooldown_time = 30 SECONDS

/datum/action/cooldown/spell/pointed/terrorize/vestige_dread/cast(mob/living/carbon/human/cast_on)
	. = ..()
	// range(), not view(): the whole point is bystanders standing in the dark, and
	// view() drops fully-darkened tiles (the same reason base Terrorize counts light with range())
	for(var/mob/living/carbon/human/bystander in range(VESTIGE_DREAD_RADIUS, cast_on))
		if(bystander == cast_on || bystander == owner)
			continue
		var/turf/bystander_turf = get_turf(bystander)
		if(!bystander_turf || bystander_turf.get_lumcount() > LIGHTING_TILE_IS_DARK)
			continue
		bystander.apply_status_effect(/datum/status_effect/terrified)

// --- Standalone: the snuff ---

/datum/vestige_boon/spell/snuff
	name = "Snuff"
	desc = "Reach out and put out every light around you at once. Not overloaded, not shorted — put out, the way I put out four hundred of them. The dark rushes in to fill the space they leave, and it does not give it back."
	grant_text = "The nearest light dims for a moment, as if it has just remembered it is mortal."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_snuff

/**
 * The Stranger's signature: silently break every working light tube in a
 * radius. No shock, no fanfare — the light is simply gone, permanently, until
 * someone fits a fresh tube. Sets the darkness the other Gloaming boons feed on.
 */
/datum/action/cooldown/spell/aoe/vestige_snuff
	name = "Snuff"
	desc = "Put out every working light around you. They stay dark until someone fits a new tube."
	button_icon = 'icons/mob/actions/actions_revenant.dmi'
	button_icon_state = "overload_lights"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	sound = 'sound/effects/magic/blind.ogg'
	cooldown_time = 40 SECONDS
	spell_requirements = NONE
	aoe_radius = VESTIGE_SNUFF_RADIUS

/datum/action/cooldown/spell/aoe/vestige_snuff/get_things_to_cast_on(atom/center)
	return RANGE_TURFS(aoe_radius, center)

/datum/action/cooldown/spell/aoe/vestige_snuff/after_cast(atom/cast_on)
	. = ..()
	if(owner)
		owner.visible_message(
			span_boldwarning("The lights around [owner] go out all at once, without a sound."),
			span_notice("You put them out. All of them. The dark thanks you by getting closer."),
		)

/datum/action/cooldown/spell/aoe/vestige_snuff/cast_on_thing_in_aoe(turf/victim, mob/living/caster)
	for(var/obj/machinery/light/light in victim)
		if(light.status != LIGHT_OK || !light.on)
			continue
		light.break_light_tube(skip_sound_and_sparks = TRUE)

// --- Standalone: the dark-heal ---

/datum/vestige_boon/spell/heart_of_darkness
	name = "Heart of Darkness"
	desc = "The dark is full, remember — full of everything the light emptied out of you. Stand where no light can see the work, and pull some of it back into your wounds. It closes flesh the way it closed over this whole ship: completely, and without asking."
	grant_text = "Something cold takes up residence behind your sternum, and offers, once in a while, to help."
	spell_type = /datum/action/cooldown/spell/vestige_darkheal

/**
 * A human-castable echo of the nightmare's heart: a burst of the dark
 * regeneration a shadow gets for free, but only where it's dark enough to hide
 * the working. Self-only, dark-gated, cooldown-paced.
 */
/datum/action/cooldown/spell/vestige_darkheal
	name = "Heart of Darkness"
	desc = "Draw the surrounding dark into your wounds — but only where no light can see it work."
	button_icon = 'icons/mob/actions/actions_revenant.dmi'
	button_icon_state = "blight"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	sound = 'sound/effects/magic/curse.ogg'
	cooldown_time = 30 SECONDS
	spell_requirements = NONE
	/// Brute and burn a single cast closes
	var/heal_amount = VESTIGE_DARKHEAL_AMOUNT

/datum/action/cooldown/spell/vestige_darkheal/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE
	var/turf/cast_turf = get_turf(owner)
	if(!cast_turf || cast_turf.get_lumcount() > LIGHTING_TILE_IS_DARK)
		if(feedback)
			to_chat(owner, span_warning("There is too much light here. The dark will not work where it can be watched."))
		return FALSE
	return TRUE

/datum/action/cooldown/spell/vestige_darkheal/cast(mob/living/cast_on)
	. = ..()
	cast_on.heal_overall_damage(brute = heal_amount, burn = heal_amount, required_bodytype = BODYTYPE_ORGANIC)
	cast_on.visible_message(
		span_warning("[cast_on]'s wounds darken, then close over with something that is not quite skin."),
		span_boldnotice("The dark pours into you and knits what was torn. It asks for nothing. That is the frightening part."),
	)

#undef VESTIGE_WATCHED_NEEDED
#undef VESTIGE_WATCHED_DO_AFTER
#undef VESTIGE_LONG_NIGHT_SECONDS
#undef VESTIGE_UMBRAL_HEAL_RATE
#undef VESTIGE_DREAD_RADIUS
#undef VESTIGE_SNUFF_RADIUS
#undef VESTIGE_DARKHEAL_AMOUNT
