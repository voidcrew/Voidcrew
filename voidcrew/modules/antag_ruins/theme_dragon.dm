/**
 * # The Roost: space dragon vestige
 *
 * A bulk hauler eaten from the inside: the dragon chewed in through the bow,
 * ate cargo, crew and half the deck plating, coiled up on what was left and
 * starved anyway, hunger that size was never going to fit inside a meal. The
 * patron is the appetite it left behind, heaped over a hoard it can no longer
 * taste. The trials are a dragon's parenting, farmed out: keep a clutch alive
 * (the Broodwatch), mark quarry with flame before the kill (the Ember Feast), and
 * refuse a lunge at the last length (the Wingbeat). The boons, the breath,
 * the gust, the carrion feast. Live in theme_dragon_boons.dm; this file only
 * points the patron at them.
 *
 * Every trial here is built to be PLAYED, not waited out: the egg summons
 * things that must be fought, the jaw credits marked quarry while its flame remains,
 * and the charm only credits throws timed against something mid-lunge.
 */

// Trial tuning (file-local, #undef at bottom). Trial descs quote these
// numbers literally, keep them in sync.
/// Tides of brood carp the Broodwatch egg must survive
#define VESTIGE_BROOD_WAVES 3
/// Delay from one tide's arrival to the next tide's herald
#define VESTIGE_BROOD_WAVE_DELAY (5 SECONDS)
/// Warning time between a tide announcing itself and arriving
#define VESTIGE_BROOD_WARNING_TIME (5 SECONDS)
/// How far from the egg the brood surfaces (never closer than 3)
#define VESTIGE_BROOD_SPAWN_RANGE 7
/// Hard lifespan on every brood carp. Abandoned assaults always clean themselves up
#define VESTIGE_BROOD_LIFESPAN (4 MINUTES)
/// The planted egg's integrity: real, and worth standing in front of
#define VESTIGE_EGG_INTEGRITY 300
/// Wild things the Ember Feast demands dead while your flame is still eating them
#define VESTIGE_EMBER_KILLS_NEEDED 3
/// The ember-jaw's breath cooldown
#define VESTIGE_EMBER_COOLDOWN (8 SECONDS)
/// How many tiles the ember-jaw's cone reaches
#define VESTIGE_EMBER_RANGE 3
/// Burn damage the cone deals on contact
#define VESTIGE_EMBER_BURN 8
/// Fire stacks the cone sets, enough to catch, not enough to skip the hunt
#define VESTIGE_EMBER_FIRE_STACKS 2
/// Temperature and volume of the cone's hotspots (the welder standard)
#define VESTIGE_EMBER_TEMP 700
#define VESTIGE_EMBER_VOLUME 50
/// Lunges the Wingbeat must turn aside
#define VESTIGE_WINGBEAT_PARRIES_NEEDED 4
/// Most parries any single beast can credit. The same meal twice is beneath the wing
#define VESTIGE_WINGBEAT_PARRIES_PER_MENACE 2
/// The gust charm's cooldown: short on purpose; the trial is timing, not rationing
#define VESTIGE_WINGBEAT_COOLDOWN (6 SECONDS)
/// How close a beast must be for the gust to reach (and the parry to count)
#define VESTIGE_WINGBEAT_REACH 2
/// How many tiles the gust throws
#define VESTIGE_WINGBEAT_THROW 3

/**
 * TRUE when a mob is honest quarry for the Unfed's lessons: wild fauna
 * (basic-mob or simple-animal stock), not a person, not a pacifist, not the
 * hunter's own pack, and not something under godmode (patrons, trader mobs).
 * Both the ember-jaw and the gust charm gate their credit through this, the
 * pact pays for hunting, never for people.
 */
/proc/vestige_is_wild_quarry(mob/living/beast, mob/living/hunter)
	if(!isliving(beast) || beast == hunter || ishuman(beast))
		return FALSE
	if(!isanimal_or_basicmob(beast) || beast.mind || beast.client || beast.mob_size < MOB_SIZE_SMALL)
		return FALSE
	if(HAS_TRAIT(beast, TRAIT_PACIFISM) || HAS_TRAIT(beast, TRAIT_GODMODE))
		return FALSE
	if(hunter && beast.faction_check_atom(hunter)) // your own pack is not prey
		return FALSE
	return TRUE

/// Conservative connected approaches: never through doors, walls, lava, or chasms.
/// Comb resin may be traversed for chewers, who can destroy that specific obstruction.
/proc/vestige_hunt_approaches(atom/objective, max_range = 7, chew_resin = FALSE)
	var/turf/origin = get_turf(objective)
	var/list/perches = list()
	if(!origin)
		return perches
	var/list/frontier = list(origin)
	var/list/seen = list()
	seen[origin] = TRUE
	for(var/index in 1 to (max_range * 2 + 1) ** 2)
		if(index > length(frontier))
			break
		var/turf/current = frontier[index]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || seen[next] || get_dist(origin, next) > max_range)
				continue
			seen[next] = TRUE
			if(!isopenturf(next) || islava(next) || ischasm(next))
				continue
			var/blocked = FALSE
			for(var/atom/movable/obstacle in next)
				if(!obstacle.density || ismob(obstacle) || (chew_resin && istype(obstacle, /obj/structure/vestige_comb_resin)))
					continue
				blocked = TRUE
				break
			if(blocked)
				continue
			frontier += next
			if(get_dist(origin, next) >= 3 && !next.is_blocked_turf(exclude_mobs = TRUE))
				perches += next
	return perches

// ===== PATRON =====

/mob/living/basic/vestige_patron/dragon
	name = "the Unfed"
	desc = "A space dragon, or what's left of one: coil after translucent coil heaped over a pile of gnawed crates and stripped hull plating. It doesn't seem to be guarding any of it."
	// The dragon's own sprite (verified in space_dragon.dm), worn like a ghost
	icon = 'icons/mob/nonhuman-player/spacedragon.dmi'
	icon_state = "spacedragon"
	gender = NEUTER
	mob_biotypes = MOB_SPECIAL
	appearance_tint = "#e3d29a" // starved gold
	alpha = 210
	pixel_x = -16
	base_pixel_x = -16
	trial_types = list(
		/datum/vestige_trial/broodwatch,
		/datum/vestige_trial/ember_feast,
		/datum/vestige_trial/wingbeat,
	)
	boon_types = list(
		/datum/vestige_boon/spell/dragon_breath,
		/datum/vestige_boon/spell/dragon_breath/consuming,
		/datum/vestige_boon/spell/wing_gust,
		/datum/vestige_boon/spell/wing_gust/hurricane,
		/datum/vestige_boon/spell/carrion_feast,
		/datum/vestige_boon/spell/carrion_feast/marrow,
	)
	idle_lines = list(
		"I ate this ship in eleven days. Bulkheads, cargo, crew, the captain's chair. On the twelfth day I worked out that the hunger was never about any of it, and by then the hunger was all there was of me.",
		"You are small. That is not an insult. Small things live on small portions. I never had your talent.",
		"There were eggs once, far aft, where the engines kept the dark warm. I meant to go back before they cooled. I was still eating when they did.",
		"Everything is a meal if you're patient enough. Distance. Hulls. Time. Time took the longest to chew and didn't taste of anything.",
		"The carp still follow me. They can't tell worship from appetite. In fairness, neither could I.",
		"Don't count my hoard. It isn't wealth. It's everything I put in my mouth instead of going home.",
		"Ask what you came to ask. I have swallowed much larger things than a question.",
	)
	accept_line = "Good. Go and be hungry on my behalf. Mind the portions."
	busy_line = "You're still carrying scraps from another table. Finish them, or spit them out where you found them."
	fulfilled_line = "That meal is eaten. Even I never chewed the same bite twice."
	renounce_line = "Then starve politely, like everything else out here."
	claim_line = "You're owed a portion. Take it now. I don't keep anything warm."
	exhausted_line = "There's nothing of mine left to serve. You have eaten a dragon down to nothing but the appetite."
	remember_line = "Death swallowed you and spat you back out. It does that with the stringy ones. Your portions are still yours."

// ===== THE BROODWATCH =====

/**
 * The clutch the Unfed never went home to, handed to a supplicant: plant the
 * cold egg on ground you can hold, wake it, and stand between it and three
 * tides of brood carp. The egg is a real structure with real integrity, an
 * undefended egg dies in seconds, so the defense IS the trial. Losing the egg
 * resets everything but soft-locks nothing: the pact stays renounceable, and
 * renouncing and re-accepting the same sticky assignment hands out a fresh
 * egg (the framework's built-in kit-recovery path).
 */
/datum/vestige_trial/broodwatch
	name = "The Broodwatch"
	// Keep the count in sync with VESTIGE_BROOD_WAVES
	// (initial values must be constant, so no define interpolation here)
	desc = "There were eggs once, and I was elsewhere being enormous. Take this one. It's cold, but cold isn't dead, only patient. Plant it somewhere you can hold and wake it up. The little cousins will come to eat it: three waves of two carp, attacking you and the shell together. Keep the shell in one piece until the last of them is dealt with and you will see what I never came home to. After each wave, touch the shell to call the next. An empty hand can patch sixty shell twice during the watch. If it breaks, replace your kit from the pact tracker."
	/// The loaned egg, while it rides in a hand or pocket. Reclaimed the moment the pact ends.
	var/obj/item/vestige_dragon_egg/egg_item
	/// The planted egg, once it has been bedded down. Reclaimed the moment the pact ends.
	var/obj/structure/vestige_dragon_egg/egg_structure

/datum/vestige_trial/broodwatch/on_accepted(mob/living/user)
	var/obj/item/vestige_dragon_egg/shell = new(get_turf(user))
	shell.bound_mind = owner
	egg_item = hand_over(user, shell)
	to_chat(user, span_notice("The egg is heavier than it looks and colder than it should be. Something inside it is waiting."))

/datum/vestige_trial/broodwatch/Destroy()
	QDEL_NULL(egg_item)
	QDEL_NULL(egg_structure) // a live assault dies with the pact; the structure dissolves its own brood
	return ..()

/datum/vestige_trial/broodwatch/get_progress_text()
	if(egg_structure && !QDELETED(egg_structure))
		if(!egg_structure.assault_underway)
			return "The egg sits where you planted it. Wake it once you have picked your ground."
		if(!length(egg_structure.brood) && !egg_structure.wave_pending && egg_structure.stage < VESTIGE_BROOD_WAVES)
			return "Wave [egg_structure.stage] cleared. Touch the egg to call the next wave. [egg_structure.repairs_left] shell patches remain."
		if(egg_structure.stage < VESTIGE_BROOD_WAVES)
			return "Wave [egg_structure.stage] of [VESTIGE_BROOD_WAVES], [length(egg_structure.brood)] of the brood are still circling the egg."
		if(length(egg_structure.brood))
			return "Last wave, [length(egg_structure.brood)] of the brood are still circling the egg."
		return "The brood is dealt with. Something is moving inside the egg."
	if(egg_item && !QDELETED(egg_item))
		return "The egg is still cold in your hands. Plant it on open ground you can hold, then wake it."
	return "The egg is gone. Replace the kit from your pact tracker to try again."

// --- The egg, carried ---

/obj/item/vestige_dragon_egg
	name = "cold dragon egg"
	desc = "An egg the size of a curled-up child, with a shell like cold slate. Hold it to your ear and you hear absolutely nothing, which is somehow worse."
	icon = 'icons/mob/simple/lavaland/lavaland_monsters.dmi'
	icon_state = "large_egg"
	inhand_icon_state = "egg"
	lefthand_file = 'icons/mob/inhands/items/food_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/food_righthand.dmi'
	color = "#7c8fb5" // cold through and through
	w_class = WEIGHT_CLASS_BULKY
	resistance_flags = FIRE_PROOF | LAVA_PROOF // dragon stock
	/// Mind of the supplicant keeping this watch, the egg only answers its own keeper
	var/datum/mind/bound_mind

/obj/item/vestige_dragon_egg/Destroy()
	var/datum/vestige_trial/broodwatch/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.egg_item == src)
		trial.egg_item = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/item/vestige_dragon_egg/examine(mob/user)
	. = ..()
	. += span_notice("Use it on an open stretch of floor to bed it down. Once planted it has to be woken up and then defended, so pick ground you can hold.")

/obj/item/vestige_dragon_egg/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isopenturf(interacting_with))
		return NONE
	var/turf/open/ground = interacting_with
	var/datum/vestige_trial/broodwatch/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || user.mind != bound_mind || trial.egg_item != src)
		balloon_alert(user, "the egg is cold clean through!")
		return ITEM_INTERACT_BLOCKING
	// Never inside the vestige: the ruin unloads the moment everyone leaves,
	// and a clutch must not be wiped mid-watch by map cleanup
	if(istype(get_area(ground), /area/ruin/space/has_grav/vestige))
		balloon_alert(user, "not in the roost itself!")
		return ITEM_INTERACT_BLOCKING
	if(ground.is_blocked_turf(exclude_mobs = TRUE))
		balloon_alert(user, "no room to bed it down!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "bedding it down...")
	if(!do_after(user, 2 SECONDS, target = ground))
		return ITEM_INTERACT_BLOCKING
	if(!user.is_holding(src))
		return ITEM_INTERACT_BLOCKING
	// Re-resolve everything; the pact may have been renounced mid-plant
	trial = user.mind?.active_vestige_trial
	if(!istype(trial) || user.mind != bound_mind || trial.egg_item != src)
		return ITEM_INTERACT_BLOCKING
	if(ground.is_blocked_turf(exclude_mobs = TRUE))
		balloon_alert(user, "no room to bed it down!")
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/vestige_dragon_egg/nest = new(ground)
	nest.bound_mind = user.mind
	trial.egg_structure = nest
	trial.register_loan(nest)
	user.visible_message(
		span_warning("[user] beds [src] down into the ground."),
		span_notice("You bed the egg down. The cold in it starts to feel less like a dead thing and more like a waiting one."),
	)
	playsound(ground, 'sound/items/weapons/tap.ogg', 50, TRUE)
	trial.refresh_tracker()
	qdel(src) // Destroy clears the trial's item pointer
	return ITEM_INTERACT_SUCCESS

// --- The egg, planted ---

/**
 * The nest: a real structure with real integrity, woken by its keeper's hand.
 * It orchestrates the tides itself: heralds, spawns, converging stragglers,
 * and holds no trial reference: everything resolves through bound_mind at the
 * moment it's needed, the same rule the kit items follow. Every brood carp it
 * spawns carries its own despawn timer, so an abandoned or failed watch never
 * leaves a carp swarm loose in the world.
 */
/obj/structure/vestige_dragon_egg
	name = "dragon egg"
	desc = "An egg the size of a curled-up child, bedded into the ground. The shell is faintly warm on whichever side happens to be facing you."
	icon = 'icons/mob/simple/lavaland/lavaland_monsters.dmi'
	icon_state = "large_egg"
	color = "#7c8fb5"
	anchored = TRUE
	density = TRUE
	max_integrity = VESTIGE_EGG_INTEGRITY
	resistance_flags = FIRE_PROOF | LAVA_PROOF
	/// Mind of the supplicant keeping this watch
	var/datum/mind/bound_mind
	/// Tides unleashed so far (0 while dormant)
	var/stage = 0
	/// Whether the watch has been woken. Set once, never unset
	var/assault_underway = FALSE
	/// Whether the hatch has been scheduled (guards the deferred timer)
	var/hatching = FALSE
	/// Live brood carp currently besieging the egg (culled by death/deletion signals)
	var/list/brood = list()
	/// The announced approach, rechecked when the wave arrives.
	var/turf/wave_perch
	var/wave_pending = FALSE
	var/wave_lost = FALSE
	var/next_wave_at = 0
	var/repairs_left = 2
	var/repairing = FALSE

/obj/structure/vestige_dragon_egg/Destroy()
	STOP_PROCESSING(SSobj, src)
	// Whatever ends the egg: a broken shell, a renounced pact, a hatching.
	// The remaining brood dissolves, staggered so it reads as an ebb, not a wipe
	for(var/mob/living/basic/carp/vestige_brood/hunter as anything in brood)
		UnregisterSignal(hunter, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		addtimer(CALLBACK(hunter, TYPE_PROC_REF(/mob/living/basic/carp/vestige_brood, dissolve)), rand(0.5 SECONDS, 3 SECONDS))
	brood.Cut()
	var/datum/vestige_trial/broodwatch/trial = get_bound_trial()
	if(istype(trial) && !QDELETED(trial))
		if(trial.egg_structure == src)
			trial.egg_structure = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/// The bound soul's broodwatch, if it still runs, resolved fresh every time, never stored (renounce-safe)
/obj/structure/vestige_dragon_egg/proc/get_bound_trial()
	var/datum/vestige_trial/broodwatch/trial = bound_mind?.active_vestige_trial
	if(istype(trial))
		return trial
	return null

/obj/structure/vestige_dragon_egg/examine(mob/user)
	. = ..()
	if(!assault_underway)
		// Keep the count in sync with VESTIGE_BROOD_WAVES
		. += span_notice("It's planted and waiting. A tap from whoever planted it will offer to wake it up. Once it's awake the brood comes in [VESTIGE_BROOD_WAVES] waves, and the shell has to survive all of them.")
	else
		. += span_boldwarning("It is awake, and everything hungry nearby knows it.")
	if(atom_integrity < max_integrity * 0.35)
		. += span_danger("The shell is webbed with cracks. It won't take much more.")
	else if(atom_integrity < max_integrity * 0.7)
		. += span_warning("The shell is chipped and scored.")

// The same shell-noises as the ash walker eggs. A struck egg should sound like one
/obj/structure/vestige_dragon_egg/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			if(damage_amount)
				playsound(loc, 'sound/effects/blob/attackblob.ogg', 90, TRUE)
			else
				playsound(src, 'sound/items/weapons/tap.ogg', 50, TRUE)
		if(BURN)
			if(damage_amount)
				playsound(loc, 'sound/items/tools/welder.ogg', 90, TRUE)

/obj/structure/vestige_dragon_egg/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	// tend() sleeps (tgui_alert); don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(tend), user)
	return TRUE

/// The keeper's hand on the shell: progress mid-watch, or the wake/take-up choice before it
/obj/structure/vestige_dragon_egg/proc/tend(mob/living/user)
	if(!user.mind || user.mind != bound_mind)
		balloon_alert(user, "cold, and not yours!")
		return
	var/datum/vestige_trial/broodwatch/trial = get_bound_trial()
	if(!istype(trial))
		balloon_alert(user, "cold clean through!")
		return
	if(assault_underway)
		if(!length(brood) && !wave_pending && stage < VESTIGE_BROOD_WAVES)
			if(world.time < next_wave_at)
				balloon_alert(user, "[DisplayTimeText(next_wave_at - world.time)] to prepare")
				return
			if(atom_integrity >= max_integrity || !repairs_left)
				herald_wave()
				return
			var/choice = tgui_alert(user, "Patch the shell before the next wave?", name, list("Patch shell", "Call wave", "Leave it"))
			if(QDELETED(src) || !user.Adjacent(src) || user.mind != bound_mind || !get_bound_trial())
				return
			if(choice == "Call wave")
				herald_wave()
				return
			if(choice != "Patch shell")
				return
		if(atom_integrity < max_integrity && repairs_left && !repairing)
			repairing = TRUE
			balloon_alert(user, "patching shell...")
			var/patched = do_after(user, 3 SECONDS, target = src)
			repairing = FALSE
			if(patched && !QDELETED(src) && user.mind == bound_mind && get_bound_trial())
				repairs_left--
				repair_damage(60)
				balloon_alert(user, "shell patched; [repairs_left] patches left")
			return
		to_chat(user, span_boldnotice(trial.get_progress_text()))
		return
	var/choice = tgui_alert(user, "The egg is planted and waiting. Wake the brood here, on this ground?", name, list("Wake it", "Take it up", "Leave it"))
	// Re-verify the whole world; the alert slept
	if(!choice || QDELETED(src) || assault_underway || QDELETED(user) || !user.Adjacent(src) || user.mind != bound_mind)
		return
	trial = get_bound_trial()
	if(!istype(trial))
		return
	switch(choice)
		if("Wake it")
			begin_assault(user)
		if("Take it up")
			take_up(user, trial)

/// Returns the egg to hand, only offered before the watch is woken
/obj/structure/vestige_dragon_egg/proc/take_up(mob/living/user, datum/vestige_trial/broodwatch/trial)
	var/obj/item/vestige_dragon_egg/shell = new(get_turf(src))
	shell.bound_mind = bound_mind
	trial.egg_item = shell
	trial.register_loan(shell)
	user.put_in_hands(shell)
	user.visible_message(
		span_warning("[user] works [src] loose from the ground and gathers it up."),
		span_notice("You take the egg back up. It doesn't object."),
	)
	qdel(src) // Destroy clears the trial's structure pointer and refreshes the tracker

/// Wakes the watch: the egg warms, the ground is chosen, and the first tide is heralded
/obj/structure/vestige_dragon_egg/proc/begin_assault(mob/living/user)
	assault_underway = TRUE
	START_PROCESSING(SSobj, src)
	color = "#d8905a" // the cold gives way
	set_light(1.5, 0.8, "#ff9a4d")
	visible_message(span_boldwarning("Warmth spreads through [src]. Somewhere out in the dark, something starts paying attention."))
	playsound(src, 'sound/mobs/non-humanoids/space_dragon/space_dragon_roar.ogg', 40, TRUE)
	to_chat(user, span_bolddanger("The little cousins will have smelled that. Hold the ground."))
	var/datum/vestige_trial/broodwatch/trial = get_bound_trial()
	trial?.refresh_tracker()
	addtimer(CALLBACK(src, PROC_REF(herald_wave)), VESTIGE_BROOD_WARNING_TIME)

/// Each tide announces itself before it lands, the defender's cue to set their feet
/obj/structure/vestige_dragon_egg/proc/herald_wave()
	if(QDELETED(src) || !assault_underway || wave_pending || length(brood) || stage >= VESTIGE_BROOD_WAVES)
		return
	var/list/perches = vestige_hunt_approaches(src, VESTIGE_BROOD_SPAWN_RANGE)
	if(!length(perches))
		visible_message(span_warning("The brood cannot reach this shell. Clear a route at least three tiles long, then touch the egg again."))
		return
	wave_perch = pick(perches)
	wave_pending = TRUE
	visible_message(span_boldwarning("The space [dir2text(get_dir(src, wave_perch))] of [src] churns. Wave [stage + 1] approaches in five seconds!"))
	playsound(src, 'sound/effects/magic/wand_teleport.ogg', 40, TRUE)
	addtimer(CALLBACK(src, PROC_REF(unleash_wave)), VESTIGE_BROOD_WARNING_TIME)

/// One announced approach per wave. Closing it postpones the wave instead of spawning on the egg.
/obj/structure/vestige_dragon_egg/proc/unleash_wave()
	if(QDELETED(src) || !assault_underway || !wave_pending)
		return
	wave_pending = FALSE
	var/list/perches = vestige_hunt_approaches(src, VESTIGE_BROOD_SPAWN_RANGE)
	if(!(wave_perch in perches))
		visible_message(span_warning("The approach has closed. Clear it and touch the shell to call the brood again."))
		return
	wave_lost = FALSE
	stage++
	for(var/i in 1 to 2)
		var/mob/living/basic/carp/vestige_brood/hunter = new(wave_perch)
		enlist(hunter, egg_bound = (i % 2 == 0))
	visible_message(span_boldwarning("The brood pours from the announced approach and turns toward [src]!"))
	playsound(src, 'sound/effects/magic/wand_teleport.ogg', 70, TRUE)
	var/datum/vestige_trial/broodwatch/trial = get_bound_trial()
	trial?.refresh_tracker()

/// Books a brood carp into the watch: siege roster, death/deletion signals, and its own despawn clock
/obj/structure/vestige_dragon_egg/proc/enlist(mob/living/basic/carp/vestige_brood/hunter, egg_bound = FALSE)
	brood += hunter
	get_bound_trial()?.register_loan(hunter)
	RegisterSignal(hunter, COMSIG_LIVING_DEATH, PROC_REF(on_brood_slain))
	RegisterSignal(hunter, COMSIG_QDELETING, PROC_REF(on_brood_gone))
	// The lifespan rides the CARP, not the egg. Orphans always clean themselves up
	addtimer(CALLBACK(hunter, TYPE_PROC_REF(/mob/living/basic/carp/vestige_brood, dissolve)), VESTIGE_BROOD_LIFESPAN)
	if(egg_bound)
		hunter.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, src)

/// Strikes a carp from the roster. Safe to call twice (death then deletion).
/obj/structure/vestige_dragon_egg/proc/muster_out(mob/living/hunter, slain = FALSE)
	if(!(hunter in brood))
		return
	brood -= hunter
	if(!slain)
		wave_lost = TRUE
	if(!length(brood) && wave_lost)
		stage--
		visible_message(span_warning("The brood escaped the watch. Clear the approach and call this wave again."))
	if(!length(brood) && stage < VESTIGE_BROOD_WAVES)
		next_wave_at = world.time + VESTIGE_BROOD_WAVE_DELAY
		visible_message(span_notice("The wave is spent. Touch the egg after five seconds to call the next; patch the shell first if needed."))
	UnregisterSignal(hunter, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))

/obj/structure/vestige_dragon_egg/proc/on_brood_slain(mob/living/hunter, gibbed)
	SIGNAL_HANDLER
	muster_out(hunter, slain = TRUE)
	var/datum/vestige_trial/broodwatch/trial = get_bound_trial()
	trial?.refresh_tracker()
	check_hatch()

/obj/structure/vestige_dragon_egg/proc/on_brood_gone(mob/living/hunter)
	SIGNAL_HANDLER
	muster_out(hunter)
	var/datum/vestige_trial/broodwatch/trial = get_bound_trial()
	trial?.refresh_tracker()
	check_hatch()

/// Keeps the siege honest: stragglers with nothing to hunt converge on the shell
/obj/structure/vestige_dragon_egg/process(seconds_per_tick)
	if(!assault_underway)
		return
	for(var/mob/living/basic/carp/vestige_brood/hunter as anything in brood)
		var/datum/ai_controller/instincts = hunter.ai_controller
		if(!instincts || instincts.blackboard[BB_BASIC_MOB_CURRENT_TARGET])
			continue
		if(hunter.z != z || get_dist(hunter, src) > 9)
			continue
		instincts.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, src)
	if(SPT_PROB(3, seconds_per_tick))
		visible_message(span_warning("Something taps, once, from inside [src]."))

/// All tides landed, all brood dealt with: the shell has earned its heir
/obj/structure/vestige_dragon_egg/proc/check_hatch()
	if(hatching || wave_lost || !assault_underway || stage < VESTIGE_BROOD_WAVES || length(brood))
		return
	hatching = TRUE
	visible_message(span_boldwarning("The tapping inside [src] becomes a knocking."))
	// A beat of theater between the last kill and the crack, and it keeps the
	// hatch out of the middle of a death signal chain
	addtimer(CALLBACK(src, PROC_REF(hatch)), 1.5 SECONDS)

/// The thing the Unfed never came home to. Completes (and deletes) the trial.
/obj/structure/vestige_dragon_egg/proc/hatch()
	if(QDELETED(src))
		return
	var/datum/vestige_trial/broodwatch/trial = get_bound_trial()
	var/mob/living/keeper = bound_mind?.current
	var/turf/nest = get_turf(src)
	visible_message(span_boldwarning("[src] splits along a seam of light, and something small and gold swims out!"))
	playsound(src, 'sound/effects/splat.ogg', 60, TRUE)
	playsound(src, 'sound/mobs/non-humanoids/space_dragon/space_dragon_roar.ogg', 30, TRUE)
	// Hatched into the keeper's care: the carp constructor takes a tamer
	new /mob/living/basic/carp/pet/vestige_hatchling(nest, isliving(keeper) ? keeper : null)
	if(isliving(keeper))
		to_chat(keeper, span_boldnotice("Somewhere far off, something enormous shifts its coils, very slowly and very carefully."))
	qdel(src) // clears the trial's structure pointer on the way out
	if(istype(trial))
		trial.complete() // deletes the trial, nothing touches it after this

/// The shell breaks: the watch fails, the brood ebbs, and the pact resets to nothing, renounceable, never soft-locked
/obj/structure/vestige_dragon_egg/atom_destruction(damage_flag)
	assault_underway = FALSE // no tide lands on a broken shell, no hatch check passes
	visible_message(span_boldwarning("[src] caves in with a wet crack, and the warmth goes out of it all at once."))
	playsound(src, 'sound/effects/splat.ogg', 80, TRUE)
	var/mob/living/keeper = bound_mind?.current
	var/datum/vestige_trial/broodwatch/trial = get_bound_trial()
	if(istype(trial) && isliving(keeper))
		to_chat(keeper, span_bolddanger("[trial.patron_name]'s voice arrives flat and unsurprised: \"That happens. It happened to mine. Replace your kit through the pact tracker and try again.\""))
	return ..()

// --- The brood ---

/**
 * The little cousins: spectral carp sent to eat the heir. Ordinary carp
 * chassis (teeth, rifts, door-chewing) with the self-preservation burned out,
 * they never flee, they dissolve rather than despawn-linger, and they leave no
 * corpse, no meat and no trophy: a failed watch pays nothing, and a finished
 * one pays only through the patron.
 */
/mob/living/basic/carp/vestige_brood
	name = "brood carp"
	desc = "A space carp made out of pale light and teeth. It moves like a fish and looks extremely hungry."
	greyscale_config = NONE
	icon_state = "base"
	icon_living = "base"
	alpha = 200
	basic_mob_flags = DEL_ON_DEATH
	death_message = "comes apart into a slick of pale light, and is gone."
	melee_damage_lower = 15
	melee_damage_upper = 15
	obj_damage = 25 // an unattended egg still dies fast; a defended one survives a lapse
	cowardly = TRUE // skips the flee-while-injured element; hunger has no self-preservation
	butcher_results = null
	cell_line = NONE
	gold_core_spawnable = NO_SPAWN
	ai_controller = /datum/ai_controller/basic_controller/carp/vestige_brood

/mob/living/basic/carp/vestige_brood/Initialize(mapload, mob/tamer)
	. = ..()
	// No taming the siege with a pocketful of meat
	qdel(GetComponent(/datum/component/tameable))

/mob/living/basic/carp/vestige_brood/apply_colour()
	add_atom_colour("#dcc98e", FIXED_COLOUR_PRIORITY) // the Unfed's starved gold

/// A brood carp's clock runs out (or its egg does): it thins away to nothing. Safe on the dead and deleted.
/mob/living/basic/carp/vestige_brood/proc/dissolve()
	if(QDELETED(src) || stat == DEAD)
		return
	visible_message(span_warning("[src] thins into pale light, and is gone."))
	qdel(src)

/**
 * Brood AI: the carp toolkit minus the cowardice and the snacking. Same
 * movement, same rift teleports, same obstacle-chewing, but no fleeing, no
 * food-hunting, no migration, and a targeting strategy that recognizes the
 * egg (the generic strategy only attacks mobs, mechs and turrets).
 */
/datum/ai_controller/basic_controller/carp/vestige_brood
	blackboard = list(
		BB_BASIC_MOB_STOP_FLEEING = TRUE,
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/vestige_brood,
		BB_PET_TARGETING_STRATEGY = /datum/targeting_strategy/basic/not_friends,
		BB_TARGET_PRIORITY_TRAIT = TRAIT_SCARY_FISHERMAN,
		BB_CARPS_FEAR_FISHERMAN = FALSE,
	)
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/find_target_prioritize_traits,
		/datum/ai_planning_subtree/attack_obstacle_in_path/carp,
		/datum/ai_planning_subtree/shortcut_to_target_through_carp_rift,
		/datum/ai_planning_subtree/make_carp_rift/aggressive_teleport,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

/**
 * Standard basic targeting, plus the egg. The egg is assigned as a blackboard
 * target by the nest itself (find_potential_targets only scans mobs and
 * GLOB.hostile_machines), so this strategy's job is to keep that assignment
 * VALID: both the target-finder's keep-current-target check and the melee
 * behavior's re-validation run through can_attack.
 */
/datum/targeting_strategy/basic/vestige_brood

/datum/targeting_strategy/basic/vestige_brood/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	if(istype(the_target, /obj/structure/vestige_dragon_egg))
		if(QDELETED(the_target) || living_mob.z != the_target.z)
			return FALSE
		if(vision_range && get_dist(living_mob, the_target) > vision_range)
			return FALSE
		return TRUE
	return ..()

// --- The hatchling ---

/**
 * What was in the egg: a carp, gold as a coal, hatched warm into the
 * defender's care. Pet chassis, retaliates if hurt, follows commands, never
 * hunts, and tamed to the keeper by the constructor's tamer argument.
 */
/mob/living/basic/carp/pet/vestige_hatchling
	name = "dragonet"
	desc = "A carp the colour of banked embers, fresh from a shell it had no business fitting inside. It is extremely certain it is a dragon. Nothing so far has dared correct it."
	gender = NEUTER
	greyscale_config = NONE
	color = "#e8975a" // banked-ember tint over the borrowed carp sprite
	icon_state = "base"
	icon_living = "base"
	icon_dead = "base_dead"
	health = 50
	maxHealth = 50
	melee_damage_lower = 5
	melee_damage_upper = 5
	faction = list(FACTION_NEUTRAL)
	gold_core_spawnable = NO_SPAWN

/mob/living/basic/carp/pet/vestige_hatchling/Initialize(mapload)
	. = ..()
	update_transform(0.7) // still growing into the name

/mob/living/basic/carp/pet/vestige_hatchling/apply_colour()
	add_atom_colour("#e8b84a", FIXED_COLOUR_PRIORITY) // hatched warm

// ===== THE EMBER FEAST =====

/**
 * The hunting trial: only deaths YOUR flame is still eating count, tracked by
 * honest attribution, the jaw marks what it ignites, an extinguished mark is
 * released, and only a mark that dies burning credits the feast. Somebody
 * else's fire, somebody else's kill and your own crowbar all pay nothing.
 */
/datum/vestige_trial/ember_feast
	name = "The Ember Feast"
	// Keep the count in sync with VESTIGE_EMBER_KILLS_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the jaw. It remembers a little of my fire, enough to start a meal, not enough to skip the hunt. Three flammable wild beasts at least the size of a carp, dead while my flame is still on them. Adult wild spiders can burn; space carp cannot. Wound tough quarry first, then ignite it and finish quickly with your own weapons or a helper. If the flame goes out, breathe again. People, pets, tiny vermin, and beasts that cannot hold a flame do not count."
	/// Prey already savored (weakref -> TRUE). A revived and re-cooked beast is still one meal
	var/list/devoured = list()

/datum/vestige_trial/ember_feast/on_accepted(mob/living/user)
	var/obj/item/vestige_ember_jaw/jaw = hand_over(user, new /obj/item/vestige_ember_jaw(get_turf(user)))
	jaw.bound_mind = owner
	to_chat(user, span_notice("The jaw settles into your grip, warm side down."))

/datum/vestige_trial/ember_feast/get_progress_text()
	return "The flame has finished [length(devoured)] of [VESTIGE_EMBER_KILLS_NEEDED] wild things."

/// Credits a burning death. May complete (and delete) the trial. Returns FALSE if this beast was already savored.
/datum/vestige_trial/ember_feast/proc/savor(mob/living/prey)
	var/datum/weakref/key = WEAKREF(prey)
	if(devoured[key])
		return FALSE
	devoured[key] = TRUE
	refresh_tracker()
	if(length(devoured) >= VESTIGE_EMBER_KILLS_NEEDED)
		complete()
	return TRUE

/**
 * The ember-jaw: a bone fetish that exhales a three-tile cone of dragonfire
 * on a short cooldown, a weak taste of the breath boon. Inert without an
 * active Ember Feast (same rule as the Gloaming's censer), so the pact's
 * flamethrower never outlives the pact. Attribution rides mark_prey below.
 */
/obj/item/vestige_ember_jaw
	name = "ember-jaw"
	desc = "The fused jawbone of something that starved with its mouth full. The teeth are soot-black, and something still glows deep in the marrow."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "ember_jaw"
	w_class = WEIGHT_CLASS_SMALL
	light_range = 1.2
	light_power = 0.5
	light_color = "#ff9a4d"
	/// Mobs our flame is currently eating (victim -> hunter's mind), released on extinguish or death
	var/list/marked_prey = list()
	var/datum/mind/bound_mind
	COOLDOWN_DECLARE(breath_cooldown)

/obj/item/vestige_ember_jaw/Destroy()
	for(var/mob/living/prey as anything in marked_prey)
		UnregisterSignal(prey, list(COMSIG_LIVING_DEATH, COMSIG_LIVING_EXTINGUISHED, COMSIG_QDELETING))
	marked_prey.Cut()
	return ..()

/obj/item/vestige_ember_jaw/examine(mob/user)
	. = ..()
	if(isliving(user))
		for(var/mob/living/prey in view(7, user))
			if(vestige_is_wild_quarry(prey, user))
				. += span_notice("[prey]: [can_hold_flame(prey) ? "can hold a flame" : "cannot burn; no feast credit"].")
	. += span_notice("Squeeze it in your hand to breathe a short cone of dragonfire in the direction you're facing. Only flammable wild things that die while that flame is still on them count. Adult wild spiders can burn; space carp cannot. The flame is brief: weaken tough prey before igniting it, then finish quickly. Helpers may finish a marked beast. Extinguishing it removes the mark. Tiny vermin and player-controlled creatures do not count.")

/// Match the ordinary fire-status eligibility without changing a beast's innate immunity.
/obj/item/vestige_ember_jaw/proc/can_hold_flame(mob/living/prey)
	if(prey.on_fire)
		return TRUE
	if(HAS_TRAIT(prey, TRAIT_NOFIRE) || isanimal(prey))
		return FALSE
	if(isbasicmob(prey))
		var/mob/living/basic/beast = prey
		return !!(beast.basic_mob_flags & FLAMMABLE_MOB)
	return TRUE

/obj/item/vestige_ember_jaw/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	var/mob/living/hunter = user
	var/datum/vestige_trial/ember_feast/trial = hunter.mind?.active_vestige_trial
	if(!istype(trial) || hunter.mind != bound_mind)
		balloon_alert(hunter, "the jaw stays cold!")
		return TRUE
	if(!COOLDOWN_FINISHED(src, breath_cooldown))
		balloon_alert(hunter, "the ember is banked!")
		return TRUE
	COOLDOWN_START(src, breath_cooldown, VESTIGE_EMBER_COOLDOWN)
	exhale(hunter)
	return TRUE

/// The breath itself: hotspots down the cone, everything living in it seared and set alight
/obj/item/vestige_ember_jaw/proc/exhale(mob/living/hunter)
	hunter.visible_message(
		span_danger("[hunter] squeezes [src], and it exhales a gout of gold-white fire!"),
		span_notice("You squeeze the jaw. Something that starved a long time ago breathes out through your hand."),
	)
	playsound(hunter, 'sound/effects/magic/fireball.ogg', 75, TRUE)
	var/list/roasted = list(hunter) // never our own barbecue
	for(var/turf/scorch as anything in build_cone(hunter))
		new /obj/effect/hotspot(scorch, VESTIGE_EMBER_VOLUME, VESTIGE_EMBER_TEMP)
		scorch.hotspot_expose(VESTIGE_EMBER_TEMP, VESTIGE_EMBER_VOLUME, 1)
		for(var/mob/living/prey in scorch)
			if(prey in roasted)
				continue
			roasted += prey
			sear(prey, hunter)

/**
 * The cone's turfs: a spine of up to three tiles the way the wielder faces,
 * flaring one tile to each side past the first. A dense wall stops the spine
 * (the fire_breath standard); blocked flanks are skipped individually.
 */
/obj/item/vestige_ember_jaw/proc/build_cone(mob/living/hunter)
	var/list/cone = list()
	var/breath_dir = hunter.dir
	var/turf/spine = get_turf(hunter)
	for(var/row in 1 to VESTIGE_EMBER_RANGE)
		spine = get_step(spine, breath_dir)
		if(!spine || spine.is_blocked_turf(exclude_mobs = TRUE))
			break
		cone += spine
		if(row < 2)
			continue
		for(var/flank_dir in list(turn(breath_dir, 90), turn(breath_dir, -90)))
			var/turf/flank = get_step(spine, flank_dir)
			if(flank && !flank.is_blocked_turf(exclude_mobs = TRUE))
				cone += flank
	return cone

/// One mouthful of the fire: burn, ignite, and (for honest quarry) a mark for the feast's ledger
/obj/item/vestige_ember_jaw/proc/sear(mob/living/prey, mob/living/hunter)
	if(prey.stat == DEAD)
		return
	prey.adjust_fire_stacks(VESTIGE_EMBER_FIRE_STACKS)
	prey.ignite_mob()
	var/datum/vestige_trial/ember_feast/trial = hunter.mind?.active_vestige_trial
	if(prey.on_fire && vestige_is_wild_quarry(prey, hunter) && istype(trial))
		mark_prey(prey, hunter.mind)
		balloon_alert(hunter, "[prey]: flame marked; helpers count")
	else if(vestige_is_wild_quarry(prey, hunter))
		if(!can_hold_flame(prey))
			balloon_alert(hunter, "[prey] cannot burn; no feast credit!")
		else
			balloon_alert(hunter, "[prey] is not burning; dry it or breathe again!")
	prey.adjustFireLoss(VESTIGE_EMBER_BURN)
	to_chat(prey, span_userdanger("You are engulfed by [hunter]'s gout of dragonfire!"))

/**
 * Attribution, done properly: a mark means OUR flame is on them right now.
 * Extinguished (by water, foam, a helpful friend) releases the mark, so a
 * later death pays nothing. Death while marked (and still burning, belt and
 * suspenders) credits the hunter's live trial, resolved fresh at that moment.
 */
/obj/item/vestige_ember_jaw/proc/mark_prey(mob/living/prey, datum/mind/hunter_mind)
	if(marked_prey[prey]) // re-ignited by a new breath: freshest hunter takes the bite
		marked_prey[prey] = hunter_mind
		return
	marked_prey[prey] = hunter_mind
	RegisterSignal(prey, COMSIG_LIVING_DEATH, PROC_REF(on_prey_died))
	RegisterSignal(prey, COMSIG_LIVING_EXTINGUISHED, PROC_REF(on_prey_doused))
	RegisterSignal(prey, COMSIG_QDELETING, PROC_REF(on_prey_gone))

/obj/item/vestige_ember_jaw/proc/unmark_prey(mob/living/prey)
	if(!marked_prey[prey])
		return
	marked_prey -= prey
	UnregisterSignal(prey, list(COMSIG_LIVING_DEATH, COMSIG_LIVING_EXTINGUISHED, COMSIG_QDELETING))

/obj/item/vestige_ember_jaw/proc/on_prey_died(mob/living/prey, gibbed)
	SIGNAL_HANDLER
	var/datum/mind/hunter_mind = marked_prey[prey]
	unmark_prey(prey)
	if(!prey.on_fire) // the fire died first; the extinguish signal usually catches this, but be sure
		return
	var/datum/vestige_trial/ember_feast/trial = hunter_mind?.active_vestige_trial
	if(!istype(trial))
		return
	var/mob/living/hunter = hunter_mind.current
	if(!vestige_is_wild_quarry(prey, hunter))
		return
	if(trial.savor(prey) && isliving(hunter)) // savor may complete (and delete) the trial, nothing touches it after this
		to_chat(hunter, span_notice("[prey] dies with your flame still on it. Somewhere, an old hunger counts the portion."))
		playsound(hunter, 'sound/effects/magic/demon_attack1.ogg', 20, TRUE)

/obj/item/vestige_ember_jaw/proc/on_prey_doused(mob/living/prey)
	SIGNAL_HANDLER
	unmark_prey(prey) // the flame lost the meal; no credit for whatever kills them later

/obj/item/vestige_ember_jaw/proc/on_prey_gone(mob/living/prey)
	SIGNAL_HANDLER
	unmark_prey(prey)

// ===== THE WINGBEAT =====

/**
 * The timing trial: stand your ground in a fauna pack and refuse the lunges.
 * The gust charm repulses everything close, but only a beast that is BOTH
 * within two tiles AND currently hunting a living person counts, a
 * close interception. Deduped per beast; four credits require at least two
 * quarry, rather than repeatedly juggling one carp.
 */
/datum/vestige_trial/wingbeat
	name = "The Wingbeat"
	// Keep the counts in sync with VESTIGE_WINGBEAT_PARRIES_NEEDED /
	// VESTIGE_WINGBEAT_PARRIES_PER_MENACE (initial values must be constant,
	// so no define interpolation here)
	desc = "Teeth are the second lesson. The wing is the first. Take the charm and go stand somewhere with teeth in it. When a wild thing throws itself at somebody, beat it back. It only counts if the beast was actually mid-hunt and close enough to reach, a gust at empty air teaches nothing. Four hunts turned aside, and no single beast counts more than twice."
	/// Total lunges turned aside so far
	var/parries = 0
	/// Parries credited per beast (weakref -> count), capping repeat lessons
	var/list/parries_per_menace = list()

/datum/vestige_trial/wingbeat/on_accepted(mob/living/user)
	var/obj/item/vestige_gust_charm/charm = hand_over(user, new /obj/item/vestige_gust_charm(get_turf(user)))
	charm.bound_mind = owner
	to_chat(user, span_notice("The charm settles against your palm, and the air around your knuckles goes tight."))

/datum/vestige_trial/wingbeat/get_progress_text()
	return "You have turned aside [parries] of [VESTIGE_WINGBEAT_PARRIES_NEEDED] lunges."

/// Credits a parried lunge. May complete (and delete) the trial. Returns FALSE if this beast is humbled out.
/datum/vestige_trial/wingbeat/proc/parry(mob/living/menace)
	var/datum/weakref/key = WEAKREF(menace)
	var/prior = parries_per_menace[key] || 0
	if(prior >= VESTIGE_WINGBEAT_PARRIES_PER_MENACE)
		return FALSE
	parries_per_menace[key] = prior + 1
	parries++
	refresh_tracker()
	if(parries >= VESTIGE_WINGBEAT_PARRIES_NEEDED)
		complete()
	return TRUE

/**
 * The gust charm: a point-blank repulse on a short cooldown, a weak taste of
 * the wing gust boon. Everything living nearby is thrown back (the module's
 * safe_throw_at pattern; walls stop bodies honestly), but only honest,
 * mid-hunt beasts are gripped hard, floored and credited, bystanders are
 * tossed gently and owe the trial nothing. Inert without an active Wingbeat,
 * same rule as the ember-jaw.
 */
/obj/item/vestige_gust_charm
	name = "gust charm"
	desc = "A strip of wing leather dried around a hollow fang, strung on braided sinew. Hold it tight and the air around your hand goes very still."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "gust_charm"
	w_class = WEIGHT_CLASS_SMALL
	var/datum/mind/bound_mind
	COOLDOWN_DECLARE(gust_cooldown)

/obj/item/vestige_gust_charm/examine(mob/user)
	. = ..()
	if(isliving(user))
		for(var/mob/living/menace in view(7, user))
			if(vestige_is_wild_quarry(menace, user))
				. += span_notice("[menace]: [is_lunging_menace(menace, user) ? "actively hunting" : "not hunting a living person"], [get_dist(user, menace)] tiles away. The gust reaches two tiles.")
	. += span_notice("Squeeze it in your hand to beat one wing's worth of storm outward, hurling back everything within [VESTIGE_WINGBEAT_REACH] tiles. It only counts as a parry if the beast was wild, that close, and actively hunting a living person, and the same beast only counts [VESTIGE_WINGBEAT_PARRIES_PER_MENACE] times.")

/obj/item/vestige_gust_charm/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	var/mob/living/keeper = user
	var/datum/vestige_trial/wingbeat/trial = keeper.mind?.active_vestige_trial
	if(!istype(trial) || keeper.mind != bound_mind)
		balloon_alert(keeper, "the charm hangs slack!")
		return TRUE
	if(!COOLDOWN_FINISHED(src, gust_cooldown))
		balloon_alert(keeper, "the wing is still folding!")
		return TRUE
	var/ready = FALSE
	for(var/mob/living/menace in view(VESTIGE_WINGBEAT_REACH, keeper))
		if(is_lunging_menace(menace, keeper) && trial.parries_per_menace[WEAKREF(menace)] < VESTIGE_WINGBEAT_PARRIES_PER_MENACE)
			ready = TRUE
			break
	if(!ready)
		balloon_alert(keeper, "no uncapped hunter within two tiles!")
		return TRUE
	COOLDOWN_START(src, gust_cooldown, VESTIGE_WINGBEAT_COOLDOWN)
	beat_wings(keeper)
	return TRUE

/// One beat of a wing that is not there: repulse everything close, credit the honest parries
/obj/item/vestige_gust_charm/proc/beat_wings(mob/living/keeper)
	keeper.visible_message(
		span_danger("The air around [keeper] slams outward with one enormous, invisible wingbeat!"),
		span_notice("You squeeze the charm, and something vast beats one wing on your behalf."),
	)
	playsound(keeper, 'sound/effects/gravhit.ogg', 70, TRUE)
	new /obj/effect/temp_visual/circle_wave/vestige_wingbeat(get_turf(keeper))
	var/list/parried = list()
	for(var/mob/living/blown in view(VESTIGE_WINGBEAT_REACH, keeper))
		if(blown == keeper || blown.stat == DEAD || HAS_TRAIT(blown, TRAIT_GODMODE))
			continue
		// Judge the lunge BEFORE the throw. The whole point is what they were doing when the wing met them
		var/creditable = is_lunging_menace(blown, keeper)
		var/fling_dir = get_dir(keeper, blown) || pick(GLOB.cardinals)
		var/thrown = blown.safe_throw_at(get_edge_target_turf(keeper, fling_dir), VESTIGE_WINGBEAT_THROW, 2, keeper, gentle = !creditable)
		if(!creditable || !thrown) // a beast the wind couldn't move was not parried
			continue
		blown.Knockdown(1 SECONDS)
		parried += blown
	// Credits run after the throws so a mid-loop completion can't strand anyone mid-air
	for(var/mob/living/menace as anything in parried)
		var/datum/vestige_trial/wingbeat/trial = keeper.mind?.active_vestige_trial
		if(!istype(trial)) // completed (or renounced) partway through the pile. The rest were just thrown
			break
		if(trial.parry(menace)) // may complete (and delete) the trial, resolved fresh each loop
			to_chat(keeper, span_notice("[menace] is beaten out of the air mid-lunge."))
		else
			to_chat(keeper, span_warning("[menace] has been thrown around enough. Find something else."))

/**
 * TRUE when a beast's throw should count as a parry: wild quarry (shared gate
 * above), conscious, and currently hunting a living person, you, or anyone
 * with a soul. Basic mobs report their hunt through the AI blackboard; the
 * old simple_animal hostiles still carry theirs on a target var.
 */
/obj/item/vestige_gust_charm/proc/is_lunging_menace(mob/living/menace, mob/living/keeper)
	if(!vestige_is_wild_quarry(menace, keeper))
		return FALSE
	if(menace.stat != CONSCIOUS)
		return FALSE
	var/atom/quarry
	var/datum/ai_controller/instincts = menace.ai_controller
	if(instincts)
		quarry = instincts.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(isnull(quarry) && istype(menace, /mob/living/simple_animal/hostile))
		var/mob/living/simple_animal/hostile/old_beast = menace
		quarry = old_beast.target
	if(!isliving(quarry))
		return FALSE
	var/mob/living/mark = quarry
	if(mark.stat == DEAD)
		return FALSE
	// The parry defends people: the keeper, or any living soul the beast was hunting
	return mark == keeper || mark.mind || ishuman(mark)

/// The wingbeat's shockwave: pale storm-grey, one wing wide
/obj/effect/temp_visual/circle_wave/vestige_wingbeat
	color = "#cfd8e4"
	duration = 0.4 SECONDS
	amount_to_scale = 2

#undef VESTIGE_BROOD_WAVES
#undef VESTIGE_BROOD_WAVE_DELAY
#undef VESTIGE_BROOD_WARNING_TIME
#undef VESTIGE_BROOD_SPAWN_RANGE
#undef VESTIGE_BROOD_LIFESPAN
#undef VESTIGE_EGG_INTEGRITY
#undef VESTIGE_EMBER_KILLS_NEEDED
#undef VESTIGE_EMBER_COOLDOWN
#undef VESTIGE_EMBER_RANGE
#undef VESTIGE_EMBER_BURN
#undef VESTIGE_EMBER_FIRE_STACKS
#undef VESTIGE_EMBER_TEMP
#undef VESTIGE_EMBER_VOLUME
#undef VESTIGE_WINGBEAT_PARRIES_NEEDED
#undef VESTIGE_WINGBEAT_PARRIES_PER_MENACE
#undef VESTIGE_WINGBEAT_COOLDOWN
#undef VESTIGE_WINGBEAT_REACH
#undef VESTIGE_WINGBEAT_THROW

/**
 * # The Roost: space dragon boons
 *
 * The Unfed's half of the bargain: what an ancient, starving leviathan pays
 * with when a trial is kept. The space dragon's body IS the antag, four
 * hundred health of serpent that eats crews whole, so nothing here grants
 * the dragon. Each boon is instead the human-sized cut of one of its three
 * verbs: the fire it cooks with (a straight subtype of upstream's fire_breath
 * machinery, retuned to corridor scale), the wingbeat it clears room with
 * (rebuilt on the aoe spell base. The upstream buffet is welded to dragon
 * icon states and an endlag self-stun no human wants), and the carrion it
 * heals by eating (rebuilt as a channelled feed that marks the meal rather
 * than destroying it). Patron and trials live in the theme file; only the
 * boons and their spells are defined here.
 */

// Tuning constants for the Unfed's ports (file-local, #undef at bottom)

/// Tiles of corridor Dragonfire reaches (upstream carp breath reaches 20. This is a ship)
#define VESTIGE_BREATH_RANGE 4
/// Burn damage a direct lick of Dragonfire deals (upstream carp breath deals 30)
#define VESTIGE_BREATH_DAMAGE 15
/// Fire stacks Dragonfire slathers on before igniting
#define VESTIGE_BREATH_STACKS 2
/// Breaths per Dragonfire cooldown
#define VESTIGE_BREATH_COOLDOWN (40 SECONDS)
/// How hot the breath burns (carp 700, drake 500, hot enough to hurt, not to remodel the ship)
#define VESTIGE_BREATH_TEMP 600
/// Tiles of corridor Consuming Flame reaches
#define VESTIGE_CONSUMING_RANGE 6
/// Burn damage a direct lick of Consuming Flame deals
#define VESTIGE_CONSUMING_DAMAGE 18
/// Fire stacks Consuming Flame slathers on, victims stay lit
#define VESTIGE_CONSUMING_STACKS 4
/// Breaths per Consuming Flame cooldown
#define VESTIGE_CONSUMING_COOLDOWN (25 SECONDS)
/// How long the inner fire keeps its own flame off the breather
#define VESTIGE_INNER_FIRE_DURATION (5 SECONDS)

/// Radius of bodies a Wing Gust hurls back
#define VESTIGE_GUST_RADIUS 2
/// Tiles a gusted body flies (safe_throw_at. It stops at whatever it meets)
#define VESTIGE_GUST_THROW 3
/// How long a gusted body stays floored
#define VESTIGE_GUST_KNOCKDOWN (2 SECONDS)
/// Beats per Wing Gust cooldown
#define VESTIGE_GUST_COOLDOWN (30 SECONDS)
/// Radius of the Hurricane Beat
#define VESTIGE_HURRICANE_RADIUS 3
/// Tiles the hurricane hurls a body
#define VESTIGE_HURRICANE_THROW 4
/// How long a hurricane-struck body stays floored
#define VESTIGE_HURRICANE_KNOCKDOWN (3.5 SECONDS)
/// Beats per Hurricane Beat cooldown
#define VESTIGE_HURRICANE_COOLDOWN (20 SECONDS)

/// How long a Carrion Feast channel takes, spent elbow-deep
#define VESTIGE_FEAST_CHANNEL (4 SECONDS)
/// Brute AND burn each that one Carrion Feast closes (~40 total)
#define VESTIGE_FEAST_HEAL 20
/// Brute the meal itself is mauled for, mostly-consumed, not destroyed
#define VESTIGE_FEAST_MAULING 60
/// Feedings per Carrion Feast cooldown
#define VESTIGE_FEAST_COOLDOWN (35 SECONDS)
/// Brute AND burn each that one Marrow Feast closes (~60 total)
#define VESTIGE_MARROW_HEAL 30
/// Blood units a Marrow Feast restores (never past a healthy volume)
#define VESTIGE_MARROW_BLOOD 100
/// Stamina damage a Marrow Feast clears
#define VESTIGE_MARROW_STAMINA 60
/// Feedings per Marrow Feast cooldown
#define VESTIGE_MARROW_COOLDOWN (20 SECONDS)
/// Incoming brute/burn multiplier while fed (0.8 = 20% resist), human physiology only
#define VESTIGE_FED_RESIST_MULT 0.8
/// How long the fed-dragon hide lasts after a Marrow Feast
#define VESTIGE_FED_DURATION (30 SECONDS)

/// Marks a corpse that has already fed a feaster. One body feeds one dragon, ever
#define TRAIT_VESTIGE_DEVOURED "vestige_devoured"

// ===== BOONS =====

// --- Chain: the breath ---

/datum/vestige_boon/spell/dragon_breath
	name = "Dragonfire"
	desc = "A mouthful of my fire, lent to your little lungs. A corridor's length of flame, and it sticks to whatever it touches."
	grant_text = "Your next breath goes out warmer than it came in, and the one after that is warmer still."
	spell_type = /datum/action/cooldown/mob_cooldown/fire_breath/vestige

/datum/vestige_boon/spell/dragon_breath/consuming
	name = "Consuming Flame"
	desc = "The same fire, fed properly. It reaches further, it burns harder, and for a few seconds after you breathe it refuses to burn you at all."
	grant_text = "Fire suddenly looks like somewhere you could comfortably stand."
	upgrades_from = /datum/vestige_boon/spell/dragon_breath
	spell_type = /datum/action/cooldown/mob_cooldown/fire_breath/vestige/consuming

// --- Chain: the wingbeat ---

/datum/vestige_boon/spell/wing_gust
	name = "Wing Gust"
	desc = "One beat of wings you don't have. Everyone standing near you gets hurled off their feet, stopping at whatever they hit."
	grant_text = "Your shoulders ache, once, where the wings should be."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_wing_gust

/datum/vestige_boon/spell/wing_gust/hurricane
	name = "Hurricane Beat"
	desc = "The wingbeat grown into weather. It reaches further, keeps them down longer, sweeps the loose clutter off the deck, and blows out any fire burning on you."
	grant_text = "The ache in your shoulders deepens into something that feels almost like muscle."
	upgrades_from = /datum/vestige_boon/spell/wing_gust
	spell_type = /datum/action/cooldown/spell/aoe/vestige_wing_gust/hurricane

// --- Chain: the feed ---

/datum/vestige_boon/spell/carrion_feast
	name = "Carrion Feast"
	desc = "Kneel over a corpse and take back the strength it isn't using anymore."
	grant_text = "Your stomach turns over once, and then, horribly, settles."
	spell_type = /datum/action/cooldown/spell/pointed/vestige_carrion_feast

/datum/vestige_boon/spell/carrion_feast/marrow
	name = "Marrow Feast"
	desc = "Feeding done properly, right down to the marrow. You get their blood and their wind along with the meal, and for a while afterward your skin shrugs off hits the way mine does."
	grant_text = "Hunger stops feeling like a warning and starts feeling like a tool."
	upgrades_from = /datum/vestige_boon/spell/carrion_feast
	spell_type = /datum/action/cooldown/spell/pointed/vestige_carrion_feast/marrow

// ===== DRAGONFIRE =====

/**
 * The dragon's breath at corridor scale. Upstream coupling checked against
 * code/datums/actions/mobs/fire_breath.dm: the whole chain (Activate ->
 * attack_sequence -> fire_line -> progressive_fire_line -> burn_turf) runs
 * off owner and the clicked target with zero mob-type checks, so a
 * mind-targeted grant to a plain human works, the same precedent as the
 * Aperture's dash (mob_cooldown/charge). Ship-safety is inherited, not
 * hoped for: the line stops at the first blocked turf (is_blocked_turf),
 * and hotspots scorch tiles (burn_tile) without ever deleting a floor.
 * shared_cooldown = NONE so breathing never locks another boon's button.
 */
/datum/action/cooldown/mob_cooldown/fire_breath/vestige
	name = "Dragonfire"
	desc = "Breathe a short line of clinging fire at a target. It stops at the first wall or door in the way."
	background_icon_state = "bg_demon"
	overlay_icon_state = "bg_demon_border"
	cooldown_time = VESTIGE_BREATH_COOLDOWN
	shared_cooldown = NONE
	fire_range = VESTIGE_BREATH_RANGE
	fire_damage = VESTIGE_BREATH_DAMAGE
	fire_temperature = VESTIGE_BREATH_TEMP
	/// Fire stacks a direct lick slathers on before striking the match
	var/ignite_stacks = VESTIGE_BREATH_STACKS

// The parent handles the burn damage and the chat; this adds the clinging.
// Dragonfire doesn't just hurt, it stays lit on you
/datum/action/cooldown/mob_cooldown/fire_breath/vestige/on_burn_mob(mob/living/barbecued, mob/living/source)
	. = ..()
	barbecued.adjust_fire_stacks(ignite_stacks)
	barbecued.ignite_mob()

/**
 * The breath mastered: longer, stickier, quicker between mouthfuls, and the
 * breather spends a few seconds as the one thing in the room the fire will
 * not touch, so the flame becomes ground to fight on rather than a fence.
 */
/datum/action/cooldown/mob_cooldown/fire_breath/vestige/consuming
	name = "Consuming Flame"
	desc = "Breathe a longer line of clinging fire. For a few seconds after, fire can't burn you."
	cooldown_time = VESTIGE_CONSUMING_COOLDOWN
	fire_range = VESTIGE_CONSUMING_RANGE
	fire_damage = VESTIGE_CONSUMING_DAMAGE
	ignite_stacks = VESTIGE_CONSUMING_STACKS

// The immunity lands before the first flame does. The whole point is
// following your own breath in
/datum/action/cooldown/mob_cooldown/fire_breath/vestige/consuming/Activate(atom/target_atom)
	if(isliving(owner))
		var/mob/living/breather = owner
		breather.apply_status_effect(/datum/status_effect/vestige_inner_fire)
	return ..()

/**
 * A few seconds of the dragon's own relationship with fire: nothing new
 * ignites you (TRAIT_NOFIRE), heat declines to cook you (TRAIT_RESISTHEAT),
 * and whatever was already burning on you is put out on the way in.
 */
/datum/status_effect/vestige_inner_fire
	id = "vestige_inner_fire"
	duration = VESTIGE_INNER_FIRE_DURATION
	status_type = STATUS_EFFECT_REPLACE
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/vestige_inner_fire
	show_duration = TRUE

/datum/status_effect/vestige_inner_fire/on_apply()
	owner.extinguish_mob()
	owner.add_traits(list(TRAIT_NOFIRE, TRAIT_RESISTHEAT), TRAIT_STATUS_EFFECT(id))
	to_chat(owner, span_boldnotice("Fire won't touch you for a few seconds. Walk where you like."))
	return TRUE

/datum/status_effect/vestige_inner_fire/on_remove()
	owner.remove_traits(list(TRAIT_NOFIRE, TRAIT_RESISTHEAT), TRAIT_STATUS_EFFECT(id))
	to_chat(owner, span_warning("Fire can burn you again. Watch your step."))

/atom/movable/screen/alert/status_effect/vestige_inner_fire
	name = "Inner Fire"
	desc = "For the moment, fire (including your own) won't burn you."
	icon_state = "fire"

// ===== WING GUST =====

/**
 * The dragon's wing buffet, rebuilt on the aoe spell base rather than ported:
 * upstream's wing_buffet (dragon_gust.dm) is welded to dragon icon states via
 * TRAIT_WING_BUFFET, carries an escalating endlag self-stun tuned for a
 * 400-health boss, and aims its knockback at the action's target rather than
 * each victim (an upstream quirk this rebuild declines to inherit). What it
 * keeps is what matters aboard a hull: safe_throw_at knockback, bodies stop
 * at the first obstacle, nothing is thrown through or into space that a plain
 * shove couldn't manage, plus a brief knockdown. No faction check: wind has
 * no friends. Corpses, the buckled and the anchored are left where they are.
 */
/datum/action/cooldown/spell/aoe/vestige_wing_gust
	name = "Wing Gust"
	desc = "Knocks everyone nearby off their feet and throws them away from you."
	button_icon = 'icons/effects/magic.dmi'
	button_icon_state = "tornado"
	background_icon_state = "bg_demon"
	overlay_icon_state = "bg_demon_border"
	sound = 'sound/effects/gravhit.ogg'
	cooldown_time = VESTIGE_GUST_COOLDOWN
	spell_requirements = NONE
	aoe_radius = VESTIGE_GUST_RADIUS
	/// Tiles a gusted body is hurled before physics has its say
	var/throw_range = VESTIGE_GUST_THROW
	/// How long a gusted body stays floored
	var/knockdown_time = VESTIGE_GUST_KNOCKDOWN
	/// The shockwave rung outward on cast
	var/wave_type = /obj/effect/temp_visual/circle_wave/vestige_gust

// view(), not range(): the gust is air, and air does not blow through walls
/datum/action/cooldown/spell/aoe/vestige_wing_gust/get_things_to_cast_on(atom/center)
	var/list/things = list()
	for(var/mob/living/nearby in view(aoe_radius, center))
		if(nearby == owner)
			continue
		if(nearby.stat == DEAD) // scattering the dead is nobody's idea of fun
			continue
		if(nearby.buckled || nearby.anchored) // strapped in is strapped in
			continue
		things += nearby
	return things

/datum/action/cooldown/spell/aoe/vestige_wing_gust/cast_on_thing_in_aoe(atom/movable/victim, atom/caster)
	var/gust_dir = get_dir(get_turf(caster), get_turf(victim)) || pick(GLOB.alldirs)
	if(isliving(victim))
		var/mob/living/blown = victim
		blown.visible_message(
			span_boldwarning("[blown] is hurled back by the wingbeat!"),
			span_userdanger("A wall of air slams you off your feet!"),
		)
		blown.safe_throw_at(get_edge_target_turf(blown, gust_dir), throw_range, 1, owner)
		blown.Knockdown(knockdown_time)
	else if(isitem(victim))
		victim.safe_throw_at(get_edge_target_turf(victim, gust_dir), throw_range, 2, owner, gentle = TRUE)

/datum/action/cooldown/spell/aoe/vestige_wing_gust/after_cast(atom/cast_on)
	. = ..()
	new wave_type(get_turf(owner))
	owner.visible_message(
		span_boldwarning("The air around [owner] slams outward, beaten by wings that are not there!"),
		span_notice("You beat wings you don't have, and everyone nearby leaves in a hurry."),
	)
	// A little hop on the downbeat, in place of the dragon's whole ascent
	var/base_y = owner.pixel_y
	animate(owner, pixel_y = base_y + 8, time = 0.2 SECONDS)
	animate(pixel_y = base_y, time = 0.2 SECONDS)

/**
 * The wingbeat as weather: wider, heavier, and housekeeping, loose small
 * items are swept off the deck (gently: swept goods bruise nobody), and any
 * fire riding the beater is blown out. Storms do not burn.
 */
/datum/action/cooldown/spell/aoe/vestige_wing_gust/hurricane
	name = "Hurricane Beat"
	desc = "Knocks everyone nearby off their feet and throws them away from you, sweeps up loose items, and puts out any fire on you."
	cooldown_time = VESTIGE_HURRICANE_COOLDOWN
	aoe_radius = VESTIGE_HURRICANE_RADIUS
	throw_range = VESTIGE_HURRICANE_THROW
	knockdown_time = VESTIGE_HURRICANE_KNOCKDOWN
	wave_type = /obj/effect/temp_visual/circle_wave/vestige_gust/hurricane

/datum/action/cooldown/spell/aoe/vestige_wing_gust/hurricane/get_things_to_cast_on(atom/center)
	. = ..()
	for(var/obj/item/loose in view(aoe_radius, center))
		if(loose.anchored || !isturf(loose.loc))
			continue
		if(loose.w_class > WEIGHT_CLASS_NORMAL) // crates and corpses stay; clutter flies
			continue
		. += loose

/datum/action/cooldown/spell/aoe/vestige_wing_gust/hurricane/after_cast(atom/cast_on)
	. = ..()
	if(!isliving(owner))
		return
	var/mob/living/beater = owner
	if(beater.on_fire)
		beater.extinguish_mob()
		to_chat(beater, span_notice("The downdraft tears the fire off you."))

/obj/effect/temp_visual/circle_wave/vestige_gust
	color = "#d8d4c8"
	amount_to_scale = 3

/obj/effect/temp_visual/circle_wave/vestige_gust/hurricane
	amount_to_scale = 5

// ===== CARRION FEAST =====

/**
 * The dragon's corpse-eating, rebuilt as a channelled feed. Upstream the
 * dragon swallows bodies whole and regurgitates them if they revive inside it
 * (space_dragon.dm, eaten_stat_changed), that is, even the dragon never
 * actually destroys a corpse. This port keeps that spirit deliberately: the
 * meal is mauled for heavy brute and marked with TRAIT_VESTIGE_DEVOURED, but
 * never gibbed or dusted. Player corpses stay retrievable for objectives and
 * revival (a defib may want a surgeon's help first, which is fair for a body
 * that has been fed on), and the mark stops one corpse from healing the same
 * dragon (or a chain of dragons) forever. Works on any organic dead
 * /mob/living, fauna included; the channel lives in before_cast so an
 * interrupted meal never spends the cooldown.
 */
/datum/action/cooldown/spell/pointed/vestige_carrion_feast
	name = "Carrion Feast"
	desc = "Eat an adjacent corpse to heal. Takes a few seconds, and each body only feeds one feast."
	button_icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	button_icon_state = "carrion_feast"
	background_icon_state = "bg_demon"
	overlay_icon_state = "bg_demon_border"
	sound = 'sound/effects/magic/demon_attack1.ogg'
	cooldown_time = VESTIGE_FEAST_COOLDOWN
	spell_requirements = NONE
	cast_range = 1
	aim_assist = FALSE // the meal is clicked, never guessed. Aim assist would happily hand you the live mob standing over it
	active_msg = "You look at the deck with an appetite..."
	deactive_msg = "You swallow the appetite back down."
	/// Brute AND burn each that one feeding closes
	var/heal_amount = VESTIGE_FEAST_HEAL
	/// Length of the channel, spent conspicuously elbow-deep
	var/channel_time = VESTIGE_FEAST_CHANNEL
	/// One feeding at a time, including across body transfers.
	var/feeding = FALSE

/datum/action/cooldown/spell/pointed/vestige_carrion_feast/is_valid_target(atom/cast_on)
	. = ..()
	if(!.)
		return FALSE
	if(!isliving(cast_on))
		cast_on.balloon_alert(owner, "nothing to eat there!")
		return FALSE
	var/mob/living/meal = cast_on
	if(meal.stat != DEAD)
		meal.balloon_alert(owner, "still moving!")
		return FALSE
	if(!(meal.mob_biotypes & MOB_ORGANIC))
		meal.balloon_alert(owner, "nothing worth eating!")
		return FALSE
	if(HAS_TRAIT(meal, TRAIT_VESTIGE_DEVOURED))
		meal.balloon_alert(owner, "picked clean!")
		return FALSE
	return TRUE

// The channel lives here: an interrupted, stolen or revived meal cancels the
// cast outright, so the cooldown is only ever paid for a finished feeding
/datum/action/cooldown/spell/pointed/vestige_carrion_feast/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	if(feeding || !feast_check(owner))
		return . | SPELL_CANCEL_CAST
	feeding = TRUE
	var/prepared = prepare_feast(owner, cast_on)
	feeding = FALSE
	return . | prepared

/datum/action/cooldown/spell/pointed/vestige_carrion_feast/proc/feast_check(mob/living/caster)
	return !QDELETED(src) && isliving(caster) && !QDELETED(caster) && caster == owner && caster.stat == CONSCIOUS && !caster.incapacitated

/datum/action/cooldown/spell/pointed/vestige_carrion_feast/proc/prepare_feast(mob/living/caster, mob/living/meal)
	caster.visible_message(
		span_boldwarning("[caster] kneels over [meal] and begins to feed!"),
		span_notice("You kneel over [meal] and start taking back what it isn't using."),
	)
	playsound(meal, 'sound/items/eatfood.ogg', 60, TRUE)
	if(!do_after(caster, channel_time, target = meal, extra_checks = CALLBACK(src, PROC_REF(feast_check), caster)))
		return SPELL_CANCEL_CAST
	// Re-resolve the whole meal and its eater after the channel.
	if(!feast_check(caster) || QDELETED(meal) || meal.stat != DEAD || !(meal.mob_biotypes & MOB_ORGANIC) || HAS_TRAIT(meal, TRAIT_VESTIGE_DEVOURED))
		return SPELL_CANCEL_CAST
	var/turf/eater_turf = get_turf(caster)
	var/turf/meal_turf = get_turf(meal)
	if(!eater_turf || !meal_turf || eater_turf.z != meal_turf.z || get_dist(eater_turf, meal_turf) > cast_range)
		meal.balloon_alert(caster, "out of reach!")
		return SPELL_CANCEL_CAST
	return NONE

/datum/action/cooldown/spell/pointed/vestige_carrion_feast/cast(mob/living/meal)
	. = ..()
	// The mark comes first: one body, one feeding, ever, no farming a freezer
	ADD_TRAIT(meal, TRAIT_VESTIGE_DEVOURED, TRAIT_GENERIC)
	meal.adjustBruteLoss(VESTIGE_FEAST_MAULING, forced = TRUE)
	new /obj/effect/decal/cleanable/blood/gibs(get_turf(meal))
	meal.visible_message(
		span_boldwarning("[owner] tears [meal] open and eats [meal.p_their()] fill!"),
		blind_message = span_hear("You hear something wet being torn apart."),
	)
	if(isliving(owner))
		feast_effects(owner)

/// The payoff, split out so the marrow feast can deepen it
/datum/action/cooldown/spell/pointed/vestige_carrion_feast/proc/feast_effects(mob/living/feaster)
	feaster.heal_overall_damage(brute = heal_amount, burn = heal_amount, required_bodytype = BODYTYPE_ORGANIC)
	to_chat(feaster, span_boldnotice("The stolen strength settles in. It wasn't doing them any good."))

/**
 * The feed taken all the way down: bigger heal, the meal's blood and wind
 * come with it, and the feaster wears a fed dragon's hide for half a minute.
 */
/datum/action/cooldown/spell/pointed/vestige_carrion_feast/marrow
	name = "Marrow Feast"
	desc = "Eat an adjacent corpse to heal more, restore blood and stamina, and toughen your hide for a while. Each body only feeds one feast."
	cooldown_time = VESTIGE_MARROW_COOLDOWN
	heal_amount = VESTIGE_MARROW_HEAL

/datum/action/cooldown/spell/pointed/vestige_carrion_feast/marrow/feast_effects(mob/living/feaster)
	. = ..()
	// Top up, never overfill, and never bother a bloodless species about it
	if(!HAS_TRAIT(feaster, TRAIT_NOBLOOD) && feaster.blood_volume < BLOOD_VOLUME_NORMAL)
		feaster.blood_volume = min(feaster.blood_volume + VESTIGE_MARROW_BLOOD, BLOOD_VOLUME_NORMAL)
	feaster.adjustStaminaLoss(-VESTIGE_MARROW_STAMINA)
	feaster.apply_status_effect(/datum/status_effect/vestige_fed_dragon)

/**
 * A fed dragon's hide, sized for a person: incoming brute and burn are dulled
 * for the duration. Human physiology only (the same guard blooddrunk uses).
 * A non-human feaster still gets the meal, just not the hide.
 */
/datum/status_effect/vestige_fed_dragon
	id = "vestige_fed_dragon"
	duration = VESTIGE_FED_DURATION
	// Another meal renews the same hide. REPLACE skips on_remove, which would
	// multiply the physiology a second time and leave resistance after expiry.
	status_type = STATUS_EFFECT_REFRESH
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/vestige_fed_dragon
	show_duration = TRUE

/datum/status_effect/vestige_fed_dragon/on_apply()
	if(ishuman(owner))
		var/mob/living/carbon/human/human_owner = owner
		human_owner.physiology.brute_mod *= VESTIGE_FED_RESIST_MULT
		human_owner.physiology.burn_mod *= VESTIGE_FED_RESIST_MULT
	to_chat(owner, span_boldnotice("The meal settles over you like scale. You feel much harder to hurt."))
	return TRUE

/datum/status_effect/vestige_fed_dragon/on_remove()
	if(ishuman(owner))
		var/mob/living/carbon/human/human_owner = owner
		human_owner.physiology.brute_mod /= VESTIGE_FED_RESIST_MULT
		human_owner.physiology.burn_mod /= VESTIGE_FED_RESIST_MULT
	to_chat(owner, span_warning("The fed feeling fades, and your skin goes back to being skin."))

/atom/movable/screen/alert/status_effect/vestige_fed_dragon
	name = "Fed"
	desc = "A recent meal sits on you like scale. Incoming blows and burns are dulled while it lasts."
	icon_state = "food_buff_3"

#undef VESTIGE_BREATH_RANGE
#undef VESTIGE_BREATH_DAMAGE
#undef VESTIGE_BREATH_STACKS
#undef VESTIGE_BREATH_COOLDOWN
#undef VESTIGE_BREATH_TEMP
#undef VESTIGE_CONSUMING_RANGE
#undef VESTIGE_CONSUMING_DAMAGE
#undef VESTIGE_CONSUMING_STACKS
#undef VESTIGE_CONSUMING_COOLDOWN
#undef VESTIGE_INNER_FIRE_DURATION
#undef VESTIGE_GUST_RADIUS
#undef VESTIGE_GUST_THROW
#undef VESTIGE_GUST_KNOCKDOWN
#undef VESTIGE_GUST_COOLDOWN
#undef VESTIGE_HURRICANE_RADIUS
#undef VESTIGE_HURRICANE_THROW
#undef VESTIGE_HURRICANE_KNOCKDOWN
#undef VESTIGE_HURRICANE_COOLDOWN
#undef VESTIGE_FEAST_CHANNEL
#undef VESTIGE_FEAST_HEAL
#undef VESTIGE_FEAST_MAULING
#undef VESTIGE_FEAST_COOLDOWN
#undef VESTIGE_MARROW_HEAL
#undef VESTIGE_MARROW_BLOOD
#undef VESTIGE_MARROW_STAMINA
#undef VESTIGE_MARROW_COOLDOWN
#undef VESTIGE_FED_RESIST_MULT
#undef VESTIGE_FED_DURATION
#undef TRAIT_VESTIGE_DEVOURED
