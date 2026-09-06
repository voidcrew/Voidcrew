/**
 * # The Comb: xenomorph vestige (patron + trials)
 *
 * An ore barge taken whole by a hive: corridors narrowed into resin comb-cells,
 * a host larder, an egg gallery kept warm off the engine bleed. Then the hosts
 * ran out. The eggs cooled one shelf at a time. The queen starved last, on a
 * throne her daughters built around her, having outlived her entire dynasty,
 * and the only things still moving aboard are the salvage drones that have been
 * chewing the comb for years, too stupid to know the court is ended. The patron
 * is **the Dowager**: a queen of nothing, regal, patient, speaking in dynasty
 * and inheritance, adopting supplicants as brood-by-marriage. Her grief is a
 * monarch's, composed, dynastic, enormous.
 *
 * The trials are a queen's offices, farmed out: incubate the last viable egg
 * behind walls you weave and re-weave mid-assault (the Warm Season, the
 * defense is ARCHITECTURE, not bodyblocking), finish wild things while your
 * acid is still working in them (the Boiling Kiss, slow corrosion demands
 * commitment, not a fire-and-forget), and sting wild hunters in the very act
 * of hunting (the Census, ranged interception timing, capped per subject).
 * Every trial is built to be PLAYED at every moment: the egg draws waves that
 * eat your walls faster than you can watch, the maw only credits melts you
 * close on and finish, and the stinger only credits intent caught mid-charge.
 *
 * The boons: the caustic spit, the neuro-lash, the resin weaver, and their
 * upgrades, live in the sibling boons file; this file only points the patron
 * at them.
 */

// Trial tuning (file-local, #undef at bottom). Trial descs quote these
// numbers literally, keep them in sync.

/// Minimum rebuilding window after a cleared gang
#define VESTIGE_WARM_SQUAD_DELAY (8 SECONDS)
/// Warning time between a gang announcing itself and arriving
#define VESTIGE_WARM_WARNING_TIME (4 SECONDS)
/// Work-gangs the normal season requires; no foreman
#define VESTIGE_WARM_SQUADS 4
/// How far from the egg the gangs surface (never closer than 3)
#define VESTIGE_WARM_SPAWN_RANGE 7
/// Hard lifespan on every chewer: abandoned assaults always clean themselves up
#define VESTIGE_WARM_CHEWER_LIFESPAN (4 MINUTES)
/// Ten unguarded cutter bites break the planted egg
#define VESTIGE_WARM_EGG_INTEGRITY 240
/// Thirteen cutter bites break a resin wall (melee brute is quartered)
#define VESTIGE_WARM_RESIN_INTEGRITY 80
/// How long a woven wall lasts before it dries out and crumbles on its own
#define VESTIGE_WARM_RESIN_LIFESPAN (4 MINUTES)
/// Lengths of resin the spinneret holds at once
#define VESTIGE_WARM_RESIN_CHARGES 5
/// Time to draw one fresh length of resin
#define VESTIGE_WARM_RESIN_REGEN (8 SECONDS)
/// How far from the weaver a wall can be laid
#define VESTIGE_WARM_WEAVE_RANGE 2
/// The weave channel: long enough to be a decision, short enough to do under teeth
#define VESTIGE_WARM_WEAVE_TIME (1.5 SECONDS)

/// Wild things the Boiling Kiss demands dead while the acid is still working in them
#define VESTIGE_KISS_KILLS_NEEDED 3
/// The caustic maw's spit cooldown
#define VESTIGE_KISS_COOLDOWN (6 SECONDS)
/// How many tiles the acid glob flies
#define VESTIGE_KISS_RANGE 6
/// Burn damage the glob deals on impact, before the corrosion starts
#define VESTIGE_KISS_SPLASH_DAMAGE 8
/// How long the kiss clings once landed. The window the kill must fall inside
#define VESTIGE_KISS_CLING (14 SECONDS)
/// Corrosion tick cadence
#define VESTIGE_KISS_TICK (2 SECONDS)
/// The deepest single bite the ramping corrosion reaches per tick
#define VESTIGE_KISS_BITE_CAP 6

/// Entries the Census demands: wild things stung in the very act of hunting
#define VESTIGE_CENSUS_MARKS_NEEDED 4
/// Most entries any single subject can put in the rolls
#define VESTIGE_CENSUS_PER_SUBJECT 2
/// The census stinger's cooldown
#define VESTIGE_CENSUS_COOLDOWN (4 SECONDS)
/// How many tiles the census barb flies
#define VESTIGE_CENSUS_RANGE 7
/// How long a counted subject seizes for, the interception's payoff
#define VESTIGE_CENSUS_SEIZE (1.5 SECONDS)
/// Token toxin damage on the barb; the sting is a stamp, not a weapon
#define VESTIGE_CENSUS_STING_DAMAGE 5

/**
 * TRUE when a mob is honest quarry for the Dowager's offices: wild fauna or
 * feral machines (basic-mob or simple-animal stock), not a person, not a
 * pacifist, not the hunter's own pack, and not something under godmode
 * (patrons, trader mobs). The caustic maw and the census stinger both gate
 * their credit through this. The court pays for hunting, never for people.
 * (Local counterpart of the dragon theme's helper; each theme keeps its own.)
 */
/proc/vestige_comb_quarry(mob/living/beast, mob/living/hunter)
	if(!isliving(beast) || beast == hunter || ishuman(beast))
		return FALSE
	if(!isanimal_or_basicmob(beast) || beast.mind || beast.client || beast.mob_size < MOB_SIZE_SMALL)
		return FALSE
	if(HAS_TRAIT(beast, TRAIT_PACIFISM) || HAS_TRAIT(beast, TRAIT_GODMODE))
		return FALSE
	if(hunter && beast.faction_check_atom(hunter)) // your own pack is not prey
		return FALSE
	return TRUE

// ===== PATRON =====

/mob/living/basic/vestige_patron/dowager
	name = "the Dowager"
	desc = "A huge alien queen of dried, translucent chitin, sitting upright on a resin throne with her crest up and her claws folded. The throne faces the egg gallery. The gallery has been dark a long time."
	// The queen's own sprite (verified in carbon/alien/adult/queen.dm), worn like parchment
	icon = 'icons/mob/nonhuman-player/alienqueen.dmi'
	icon_state = "alienq"
	gender = FEMALE
	mob_biotypes = MOB_SPECIAL
	appearance_tint = "#cfc0a0" // chitin gone to old ivory
	alpha = 205
	pixel_x = -16
	base_pixel_x = -16
	trial_types = list(
		/datum/vestige_trial/warm_season,
		/datum/vestige_trial/boiling_kiss,
		/datum/vestige_trial/comb_census,
	)
	boon_types = list(
		/datum/vestige_boon/spell/caustic_spit,
		/datum/vestige_boon/spell/caustic_spit/vitriol,
		/datum/vestige_boon/spell/neuro_lash,
		/datum/vestige_boon/spell/neuro_lash/paralytic,
		/datum/vestige_boon/spell/resin_weaver,
		/datum/vestige_boon/spell/resin_weaver/architect,
	)
	idle_lines = list(
		"This was an ore barge. Twelve crew. I made it a palace and made the twelve into courtiers. They served the line faithfully, in the end.",
		"The larder emptied in the third month. After that I was rationing my own children. A queen learns bookkeeping late, and the lessons are expensive.",
		"The eggs needed warmth, the warmth needed hosts, and the hosts ran out. The succession was dead well before I admitted it.",
		"My daughters built this throne around me so I would not have to watch the gallery go cold shelf by shelf. They were good children. They thought of everything. I ate them last.",
		"You can hear the little machines chewing. They were eating this comb before I got here and they will be eating it after you leave. I would have them destroyed, but a court has to keep some subjects.",
		"You are soft, warm and entirely without lineage. Fine. Consider yourself brood by marriage, drone. The paperwork is a formality; I ate the clerk.",
		"Ask, drone. Speak up and stand straight. A queen with nothing left still holds audience.",
	)
	accept_line = "Then it is sealed. Serve the line well, drone. You are all the dynasty I have left."
	busy_line = "You arrive carrying another house's errand. A drone serves one court at a time. Finish it, or renounce it and come home to mine."
	fulfilled_line = "That office is discharged and entered in the rolls. I will not ask the same service twice."
	renounce_line = "So the marriage is dissolved. Compose yourself; dynasties have died of less. Mine did."
	claim_line = "The court owes you a dowry. Take it before you ask anything further of me."
	exhausted_line = "There is nothing left to settle on you. You have inherited the whole estate, drone. The acid, the sting, the comb. Wear it carefully. It wore me out."
	remember_line = "Death is not release from a dynasty. It is just travel. What was settled on you stays settled. Welcome home, drone."

// ===== THE WARM SEASON =====

/**
 * The gallery's last viable egg, handed to a supplicant with the Dowager's own
 * spinneret: plant the egg on ground you can hold, warm it, and keep it warm
 * for three unbroken minutes while the comb's salvage vermin come to chew it.
 * The defense is architecture. The chewers do trivial harm to people and
 * ruinous harm to structures, so the loop is weaving resin, watching it be
 * eaten, and weaving again, not standing in a doorway. Work-gangs land on a
 * clock and escalate; every chewer carries its own despawn timer so abandoned
 * assaults always clean themselves up (the Roost's precedent). Losing the egg
 * resets everything but soft-locks nothing: renounce and re-accept the same
 * sticky assignment and the court advances a fresh egg and spinneret.
 */
/datum/vestige_trial/warm_season
	name = "The Warm Season"
	desc = "Plant the egg and weave resin around it. Four salvage gangs come for the comb: one cutter, then two, two, and three. They favor structures over flesh. Clear each gang, repair and rebuild, then touch the shell to call the next. The spinneret can spend one length to mend sixty shell. No previous boon is needed. If the egg is lost, replace your kit from the pact tracker."
	/// The loaned egg, while it rides in a hand or pocket. Reclaimed the moment the pact ends.
	var/obj/item/vestige_comb_egg/egg_item
	/// The planted egg, once it has been bedded down. Reclaimed the moment the pact ends.
	var/obj/structure/vestige_comb_egg/egg_structure
	/// The loaned spinneret. Reclaimed the moment the pact ends.
	var/obj/item/vestige_comb_spinneret/spinneret
	/// Live walls woven this pact (each clears itself from this on Destroy)
	var/list/woven = list()

/datum/vestige_trial/warm_season/on_accepted(mob/living/user)
	var/obj/item/vestige_comb_egg/shell = new(get_turf(user))
	shell.bound_mind = owner
	egg_item = hand_over(user, shell)
	var/obj/item/vestige_comb_spinneret/organ = new(get_turf(user))
	organ.bound_mind = owner
	spinneret = hand_over(user, organ)
	to_chat(user, span_notice("The egg is lighter than it looks and warmer than it has any right to be. The spinneret twitches against your palm."))

/datum/vestige_trial/warm_season/Destroy()
	QDEL_NULL(egg_item)
	QDEL_NULL(egg_structure) // a live season dies with the pact; the structure dissolves its own vermin
	QDEL_NULL(spinneret)
	// Old walls dry out on their own schedule, staggered so it reads as decay, not a wipe
	for(var/obj/structure/vestige_comb_resin/wall as anything in woven)
		wall.bound_mind = null
		addtimer(CALLBACK(wall, TYPE_PROC_REF(/obj/structure/vestige_comb_resin, dry_out)), rand(0.5 SECONDS, 3 SECONDS))
	woven.Cut()
	return ..()

/datum/vestige_trial/warm_season/get_progress_text()
	if(egg_structure && !QDELETED(egg_structure))
		return "Gang [egg_structure.squads_landed] of four; [length(egg_structure.chewers)] cutters remain. Clear the gang, then touch the egg to call the next. Shell: [round(egg_structure.atom_integrity)]/[egg_structure.max_integrity]."
	if(egg_item && !QDELETED(egg_item))
		return "Plant the egg on clear ground, weave resin, and touch the egg when ready."
	return "The egg is gone. Replace your kit from the pact tracker to retry."

// --- The egg, carried ---

/obj/item/vestige_comb_egg
	name = "dormant hive egg"
	desc = "An egg the colour of old teeth, cold all the way through. It does not feel dead, exactly. Just put off."
	icon = 'icons/mob/nonhuman-player/alien.dmi'
	icon_state = "egg_growing"
	inhand_icon_state = "egg"
	lefthand_file = 'icons/mob/inhands/items/food_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/food_righthand.dmi'
	color = "#a8b58c" // gallery-cold
	w_class = WEIGHT_CLASS_BULKY
	resistance_flags = ACID_PROOF // hive stock
	/// Mind of the supplicant keeping this season, the egg only answers its own keeper
	var/datum/mind/bound_mind

/obj/item/vestige_comb_egg/Destroy()
	var/datum/vestige_trial/warm_season/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.egg_item == src)
		trial.egg_item = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/item/vestige_comb_egg/examine(mob/user)
	. = ..()
	. += span_notice("Press it to an open stretch of floor to bed it down. Once planted it has to be warmed, then kept warm while the comb's vermin come for it. Pick ground you can wall off.")

/obj/item/vestige_comb_egg/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isopenturf(interacting_with))
		return NONE
	var/turf/open/ground = interacting_with
	var/datum/vestige_trial/warm_season/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || user.mind != bound_mind || trial.egg_item != src)
		balloon_alert(user, "the egg is cold clean through!")
		return ITEM_INTERACT_BLOCKING
	// Never inside the vestige: the ruin unloads the moment everyone leaves,
	// and a clutch must not be wiped mid-season by map cleanup
	if(istype(get_area(ground), /area/ruin/space/has_grav/vestige))
		balloon_alert(user, "not in the comb itself!")
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
	var/obj/structure/vestige_comb_egg/clutch = new(ground)
	clutch.bound_mind = user.mind
	trial.egg_structure = clutch
	trial.register_loan(clutch)
	user.visible_message(
		span_warning("[user] beds [src] down against the ground."),
		span_notice("You bed the egg down. It settles in like it belongs there."),
	)
	playsound(ground, 'sound/items/weapons/tap.ogg', 50, TRUE)
	trial.refresh_tracker()
	qdel(src) // Destroy clears the trial's item pointer
	return ITEM_INTERACT_SUCCESS

// --- The egg, planted ---

/**
 * The clutch: a real structure with real integrity, warmed by its keeper's
 * hand. Once warm it runs the season itself. Heralds, work-gangs on a clock,
 * escalating sizes, idle stragglers re-converged, and holds no trial
 * reference: everything resolves through bound_mind at the moment it's needed,
 * the same rule the kit items follow. The shell must still be
 * whole when all four gangs are defeated. Resin delays the cutters long enough
 * to intercept them and repair the shell.
 */
/obj/structure/vestige_comb_egg
	name = "hive egg"
	desc = "An egg the colour of old teeth, bedded down into the ground. Something inside it is folded up very carefully."
	icon = 'icons/mob/nonhuman-player/alien.dmi'
	icon_state = "egg_growing"
	color = "#a8b58c"
	anchored = TRUE
	density = TRUE
	max_integrity = VESTIGE_WARM_EGG_INTEGRITY
	resistance_flags = ACID_PROOF
	/// Mind of the supplicant keeping this season
	var/datum/mind/bound_mind
	/// Whether the season has been started. Set once, never unset
	var/assault_underway = FALSE
	/// Work-gangs landed so far (drives escalation)
	var/squads_landed = 0
	/// Whether the hatch has been scheduled (guards the deferred timer)
	var/hatching = FALSE
	/// Live chewers currently on the comb (culled by death/deletion signals)
	var/list/chewers = list()
	var/turf/squad_perch
	var/squad_pending = FALSE
	var/squad_lost = FALSE
	var/next_squad_at = 0

/obj/structure/vestige_comb_egg/Destroy()
	STOP_PROCESSING(SSobj, src)
	// Whatever ends the egg: a broken shell, a renounced pact, a hatching.
	// The remaining vermin wind down, staggered so it reads as an ebb, not a wipe
	for(var/mob/living/basic/hivebot/vestige_comb_chewer/vermin as anything in chewers)
		UnregisterSignal(vermin, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		addtimer(CALLBACK(vermin, TYPE_PROC_REF(/mob/living/basic/hivebot/vestige_comb_chewer, wind_down)), rand(0.5 SECONDS, 3 SECONDS))
	chewers.Cut()
	var/datum/vestige_trial/warm_season/trial = get_bound_trial()
	if(istype(trial) && !QDELETED(trial))
		if(trial.egg_structure == src)
			trial.egg_structure = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/// The bound soul's warm season, if it still runs, resolved fresh every time, never stored (renounce-safe)
/obj/structure/vestige_comb_egg/proc/get_bound_trial()
	var/datum/vestige_trial/warm_season/trial = bound_mind?.active_vestige_trial
	if(istype(trial))
		return trial
	return null

/obj/structure/vestige_comb_egg/examine(mob/user)
	. = ..()
	if(!assault_underway)
		. += span_notice("It is planted and cold. A tap from the hand that planted it offers to warm it. Four work-gangs must be defeated. Touch the shell between gangs when ready. They would much rather eat walls than people.")
	else if(!hatching)
		. += span_boldwarning("Gang [squads_landed] of four; [length(chewers)] cutters remain. Use the spinneret on the shell to repair it.")
	if(atom_integrity < max_integrity * 0.35)
		. += span_danger("The shell is webbed with cracks. It will not take much more.")
	else if(atom_integrity < max_integrity * 0.7)
		. += span_warning("The shell is scored and chipped.")

// The same shell-noises as the ash walker eggs. A struck egg should sound like one
/obj/structure/vestige_comb_egg/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			if(damage_amount)
				playsound(loc, 'sound/effects/blob/attackblob.ogg', 90, TRUE)
			else
				playsound(src, 'sound/items/weapons/tap.ogg', 50, TRUE)
		if(BURN)
			if(damage_amount)
				playsound(loc, 'sound/items/tools/welder.ogg', 90, TRUE)

/obj/structure/vestige_comb_egg/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	// tend() sleeps (tgui_alert); don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(tend), user)
	return TRUE

/// The keeper's hand on the shell: progress mid-season, or the warm/take-up choice before it
/obj/structure/vestige_comb_egg/proc/tend(mob/living/user)
	if(!user.mind || user.mind != bound_mind)
		balloon_alert(user, "cold, and not yours!")
		return
	var/datum/vestige_trial/warm_season/trial = get_bound_trial()
	if(!istype(trial))
		balloon_alert(user, "cold clean through!")
		return
	if(assault_underway)
		if(!length(chewers) && !squad_pending && squads_landed < VESTIGE_WARM_SQUADS)
			if(world.time < next_squad_at)
				balloon_alert(user, "[DisplayTimeText(next_squad_at - world.time)] to rebuild")
				return
			herald_squad()
			return
		to_chat(user, span_boldnotice(trial.get_progress_text()))
		return
	var/choice = tgui_alert(user, "The egg is planted and patient. Begin the warm season here, on this ground?", name, list("Warm it", "Take it up", "Leave it"))
	// Re-verify the whole world; the alert slept
	if(!choice || QDELETED(src) || assault_underway || QDELETED(user) || !user.Adjacent(src) || user.mind != bound_mind)
		return
	trial = get_bound_trial()
	if(!istype(trial))
		return
	switch(choice)
		if("Warm it")
			begin_season(user)
		if("Take it up")
			take_up(user, trial)

/// Returns the egg to hand, only offered before the season begins
/obj/structure/vestige_comb_egg/proc/take_up(mob/living/user, datum/vestige_trial/warm_season/trial)
	var/obj/item/vestige_comb_egg/shell = new(get_turf(src))
	shell.bound_mind = bound_mind
	trial.egg_item = shell
	trial.register_loan(shell)
	user.put_in_hands(shell)
	user.visible_message(
		span_warning("[user] works [src] loose from the ground and gathers it up."),
		span_notice("You take the egg back up."),
	)
	qdel(src) // Destroy clears the trial's structure pointer and refreshes the tracker

/// Begins the season: the shell warms and the first work-gang is heralded
/obj/structure/vestige_comb_egg/proc/begin_season(mob/living/user)
	assault_underway = TRUE
	START_PROCESSING(SSobj, src)
	color = "#e0c47f" // the warmth takes
	set_light(1.5, 0.8, "#ffce7a")
	visible_message(span_boldwarning("Warmth blooms through [src]. Somewhere out in the dark, tool-motors change pitch."))
	playsound(src, 'sound/mobs/non-humanoids/hiss/lowHiss2.ogg', 60, TRUE)
	to_chat(user, span_bolddanger("The vermin will have felt that through the deck. Weave your ground and hold the season."))
	var/datum/vestige_trial/warm_season/trial = get_bound_trial()
	trial?.refresh_tracker()
	addtimer(CALLBACK(src, PROC_REF(herald_squad)), 3 SECONDS)

/// Each work-gang announces itself before it lands, the weaver's cue to spend resin
/obj/structure/vestige_comb_egg/proc/herald_squad()
	if(QDELETED(src) || !assault_underway || hatching || squad_pending || length(chewers) || squads_landed >= VESTIGE_WARM_SQUADS)
		return
	var/list/perches = vestige_hunt_approaches(src, VESTIGE_WARM_SPAWN_RANGE, chew_resin = TRUE)
	if(!length(perches))
		visible_message(span_warning("The cutters have no approach. Clear a route through to open ground, then touch the shell again. Your own resin may remain in their way."))
		return
	squad_perch = pick(perches)
	squad_pending = TRUE
	visible_message(span_boldwarning("Cutter-motors shrill to the [dir2text(get_dir(src, squad_perch))] of [src]. Gang [squads_landed + 1] approaches in four seconds!"))
	playsound(src, 'sound/machines/buzz/buzz-two.ogg', 60, TRUE)
	addtimer(CALLBACK(src, PROC_REF(land_squad)), VESTIGE_WARM_WARNING_TIME)

/obj/structure/vestige_comb_egg/proc/land_squad()
	if(QDELETED(src) || !assault_underway || hatching || !squad_pending)
		return
	squad_pending = FALSE
	var/list/perches = vestige_hunt_approaches(src, VESTIGE_WARM_SPAWN_RANGE, chew_resin = TRUE)
	if(!(squad_perch in perches))
		visible_message(span_warning("The approach has closed. Clear it and touch the shell to call the gang again."))
		return
	squad_lost = FALSE
	var/list/gang_sizes = list(1, 2, 2, 3)
	var/squad_size = gang_sizes[squads_landed + 1]
	for(var/i in 1 to squad_size)
		var/mob/living/basic/hivebot/vestige_comb_chewer/vermin = new(squad_perch)
		do_sparks(3, TRUE, vermin)
		enlist(vermin, egg_bound = TRUE)
	squads_landed++
	visible_message(span_boldwarning("The salvage gang clatters from the announced approach, cutters spinning!"))
	var/datum/vestige_trial/warm_season/trial = get_bound_trial()
	trial?.refresh_tracker()

/// Books a chewer into the season: siege roster, death/deletion signals, and its own despawn clock
/obj/structure/vestige_comb_egg/proc/enlist(mob/living/basic/hivebot/vestige_comb_chewer/vermin, egg_bound = TRUE)
	chewers += vermin
	get_bound_trial()?.register_loan(vermin)
	RegisterSignal(vermin, COMSIG_LIVING_DEATH, PROC_REF(on_chewer_slain))
	RegisterSignal(vermin, COMSIG_QDELETING, PROC_REF(on_chewer_gone))
	// The lifespan rides the CHEWER, not the egg. Orphans always clean themselves up
	addtimer(CALLBACK(vermin, TYPE_PROC_REF(/mob/living/basic/hivebot/vestige_comb_chewer, wind_down)), VESTIGE_WARM_CHEWER_LIFESPAN)
	if(egg_bound)
		vermin.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, src)

/// Strikes a chewer from the roster. Safe to call twice (death then deletion).
/obj/structure/vestige_comb_egg/proc/muster_out(mob/living/vermin, slain = FALSE)
	if(!(vermin in chewers))
		return
	chewers -= vermin
	if(!slain)
		squad_lost = TRUE
	if(!length(chewers))
		if(squad_lost)
			squads_landed--
			visible_message(span_warning("The gang escaped the season. Call that gang again when the approach is clear."))
		if(squads_landed >= VESTIGE_WARM_SQUADS)
			finish_season()
		else
			next_squad_at = world.time + VESTIGE_WARM_SQUAD_DELAY
			visible_message(span_notice("The gang is cleared. Repair and rebuild; touch the egg after eight seconds to call the next."))
	UnregisterSignal(vermin, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))

/obj/structure/vestige_comb_egg/proc/on_chewer_slain(mob/living/vermin, gibbed)
	SIGNAL_HANDLER
	muster_out(vermin, slain = TRUE)
	var/datum/vestige_trial/warm_season/trial = get_bound_trial()
	trial?.refresh_tracker()

/obj/structure/vestige_comb_egg/proc/on_chewer_gone(mob/living/vermin)
	SIGNAL_HANDLER
	muster_out(vermin)
	var/datum/vestige_trial/warm_season/trial = get_bound_trial()
	trial?.refresh_tracker()

/**
 * Stragglers with nothing to chew are re-pointed at the shell. Progress remains
 * on the gang roster; merely surviving a clock cannot complete the season.
 */
/obj/structure/vestige_comb_egg/process(seconds_per_tick)
	if(!assault_underway || hatching)
		return
	for(var/mob/living/basic/hivebot/vestige_comb_chewer/vermin as anything in chewers)
		var/datum/ai_controller/directive = vermin.ai_controller
		if(!directive || directive.blackboard[BB_BASIC_MOB_CURRENT_TARGET])
			continue
		if(vermin.z != z || get_dist(vermin, src) > 9)
			continue
		directive.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, src)
	if(SPT_PROB(25, seconds_per_tick))
		var/datum/vestige_trial/warm_season/trial = get_bound_trial()
		trial?.refresh_tracker()
	if(SPT_PROB(3, seconds_per_tick))
		visible_message(span_warning("Something shifts its weight, once, inside [src]."))

/// All four gangs defeated: the shell has earned its heir
/obj/structure/vestige_comb_egg/proc/finish_season()
	if(hatching || squad_lost || squads_landed < VESTIGE_WARM_SQUADS || length(chewers))
		return
	hatching = TRUE
	assault_underway = FALSE // no gang lands after the season, no clock keeps running
	for(var/mob/living/basic/hivebot/vestige_comb_chewer/vermin as anything in chewers)
		UnregisterSignal(vermin, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		addtimer(CALLBACK(vermin, TYPE_PROC_REF(/mob/living/basic/hivebot/vestige_comb_chewer, wind_down)), rand(0.5 SECONDS, 3 SECONDS))
	chewers.Cut()
	visible_message(span_boldwarning("The salvage machines stall mid-bite, listen to something on a dead frequency, and start falling apart. Inside [src], something is working its way out."))
	// A beat of theater between the season's end and the crack, and it keeps the
	// hatch out of the middle of the process loop
	addtimer(CALLBACK(src, PROC_REF(hatch)), 2 SECONDS)

/// The thing the gallery never got to finish. Completes (and deletes) the trial.
/obj/structure/vestige_comb_egg/proc/hatch()
	if(QDELETED(src))
		return
	var/datum/vestige_trial/warm_season/trial = get_bound_trial()
	var/mob/living/keeper = bound_mind?.current
	var/turf/clutch = get_turf(src)
	visible_message(span_boldwarning("[src] splits along a seam, and something small and pale unfolds out of it!"))
	playsound(src, 'sound/effects/splat.ogg', 60, TRUE)
	playsound(src, 'sound/mobs/non-humanoids/hiss/hiss1.ogg', 40, TRUE)
	new /obj/item/clothing/mask/facehugger/vestige_comb_heir(clutch)
	if(isliving(keeper))
		to_chat(keeper, span_boldnotice("Somewhere across the dark, something very large lets out one long breath."))
	qdel(src) // clears the trial's structure pointer on the way out
	if(istype(trial))
		trial.complete() // deletes the trial, nothing touches it after this

/// The shell breaks: the season fails, the vermin ebb, and the pact resets to nothing, renounceable, never soft-locked
/obj/structure/vestige_comb_egg/atom_destruction(damage_flag)
	assault_underway = FALSE // no gang lands on a broken shell, no clock finishes
	visible_message(span_boldwarning("[src] caves in with a wet crack, and the warmth goes out of it all at once."))
	playsound(src, 'sound/effects/splat.ogg', 80, TRUE)
	var/mob/living/keeper = bound_mind?.current
	var/datum/vestige_trial/warm_season/trial = get_bound_trial()
	if(istype(trial) && isliving(keeper))
		to_chat(keeper, span_bolddanger("[trial.patron_name]'s voice arrives level and unhurried: \"So the count is one fewer. Replace your kit through the pact tracker and I will advance you another.\""))
	return ..()

// --- The heir ---

/**
 * What was in the egg: a hugger born sterile into a dynasty of one, harmless
 * by biology rather than by training. It leaps at nothing, implants nothing,
 * and can be worn as a mask by anyone with more sentiment than sense. The
 * succession, such as it is.
 */
/obj/item/clothing/mask/facehugger/vestige_comb_heir
	name = "heir of the comb"
	desc = "A parchment-coloured facehugger, sterile from the shell out. It grips your fingers with tremendous ceremony and no ambition whatsoever."
	sterile = TRUE
	color = "#e3d5ac" // the Dowager's ivory

// --- The spinneret ---

/**
 * The Dowager's own spinneret, loaned: weaves a wall of fresh comb resin onto
 * open ground within two tiles, from a small reserve that redraws itself over
 * time. Weaving only answers its keeper's live Warm Season and only while the
 * planted egg stands, the pact's fortification tool never outlives the thing
 * it was lent to shelter. Everything it weaves dries out on its own timer, so
 * the world never keeps the architecture either.
 */
/obj/item/vestige_comb_spinneret
	name = "dowager's spinneret"
	desc = "A resin-spinning organ, dry but not dead, its ducts still primed with something amber."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "spinner-x"
	inhand_icon_state = "coil_white"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	color = "#d9c184"
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	/// Mind of the supplicant this was lent to, resolved for pointer cleanup only
	var/datum/mind/bound_mind
	/// Lengths of resin currently drawn and ready
	var/charges = VESTIGE_WARM_RESIN_CHARGES
	/// world.time at which the next length finishes drawing
	var/next_draw_at = 0

/obj/item/vestige_comb_spinneret/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/vestige_comb_spinneret/Destroy()
	STOP_PROCESSING(SSobj, src)
	var/datum/vestige_trial/warm_season/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.spinneret == src)
		trial.spinneret = null
	bound_mind = null
	return ..()

/// The reserve redraws one length at a time, on its own clock
/obj/item/vestige_comb_spinneret/process(seconds_per_tick)
	if(charges >= VESTIGE_WARM_RESIN_CHARGES)
		return
	if(world.time < next_draw_at)
		return
	charges++
	next_draw_at = world.time + VESTIGE_WARM_RESIN_REGEN

/obj/item/vestige_comb_spinneret/examine(mob/user)
	. = ..()
	. += span_notice("Pressed toward open ground within [VESTIGE_WARM_WEAVE_RANGE] tiles, it weaves a wall of fresh comb resin. It holds [VESTIGE_WARM_RESIN_CHARGES] lengths at a time and redraws one every [VESTIGE_WARM_RESIN_REGEN / (1 SECONDS)] seconds; each wall dries out and crumbles on its own after a few minutes. It only weaves while the planted egg is still standing. Use it on the shell to spend one length and three seconds repairing sixty integrity.")
	. += span_notice("[charges] of [VESTIGE_WARM_RESIN_CHARGES] lengths are drawn and ready.")

/obj/item/vestige_comb_spinneret/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	balloon_alert(user, "[charges] of [VESTIGE_WARM_RESIN_CHARGES] lengths ready")
	return TRUE

/obj/item/vestige_comb_spinneret/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(istype(interacting_with, /obj/structure/vestige_comb_egg))
		return mend_egg(interacting_with, user)
	if(!isopenturf(interacting_with))
		return NONE
	return weave(interacting_with, user)

/obj/item/vestige_comb_spinneret/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isopenturf(interacting_with))
		return NONE
	return weave(interacting_with, user)

/// Repair trades a weaving charge and a vulnerable channel for shell integrity.
/obj/item/vestige_comb_spinneret/proc/mend_egg(obj/structure/vestige_comb_egg/egg, mob/living/user)
	var/datum/vestige_trial/warm_season/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.spinneret != src || trial.egg_structure != egg || !user.Adjacent(egg))
		return ITEM_INTERACT_BLOCKING
	if(charges < 1 || egg.atom_integrity >= egg.max_integrity)
		balloon_alert(user, "needs damaged shell and one length of resin!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "mending shell...")
	if(!do_after(user, 3 SECONDS, target = egg))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(egg) || !user.is_holding(src) || trial != user.mind?.active_vestige_trial || charges < 1)
		return ITEM_INTERACT_BLOCKING
	charges--
	next_draw_at = max(next_draw_at, world.time + VESTIGE_WARM_RESIN_REGEN)
	egg.repair_damage(60)
	balloon_alert(user, "shell mended")
	trial.refresh_tracker()
	return ITEM_INTERACT_SUCCESS

/// The weave: gate, channel, re-gate, wall. The mid-assault loop lives here.
/obj/item/vestige_comb_spinneret/proc/weave(turf/open/ground, mob/living/user)
	var/datum/vestige_trial/warm_season/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || user.mind != bound_mind || trial.spinneret != src)
		balloon_alert(user, "the spinneret hangs slack!")
		return ITEM_INTERACT_BLOCKING
	if(!trial.egg_structure || QDELETED(trial.egg_structure))
		balloon_alert(user, "nothing planted to shelter!")
		return ITEM_INTERACT_BLOCKING
	if(ground.z != user.z || get_dist(user, ground) > VESTIGE_WARM_WEAVE_RANGE)
		balloon_alert(user, "too far to weave!")
		return ITEM_INTERACT_BLOCKING
	if(ground.is_blocked_turf()) // mobs block too: no entombing the vermin, or yourself
		balloon_alert(user, "no room to weave!")
		return ITEM_INTERACT_BLOCKING
	if(charges < 1)
		balloon_alert(user, "the ducts are still drawing!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "weaving...")
	if(!do_after(user, VESTIGE_WARM_WEAVE_TIME, target = ground))
		return ITEM_INTERACT_BLOCKING
	if(!user.is_holding(src))
		return ITEM_INTERACT_BLOCKING
	// Re-resolve the world; the channel slept through renounces, chewers and worse
	trial = user.mind?.active_vestige_trial
	if(!istype(trial) || user.mind != bound_mind || trial.spinneret != src || !trial.egg_structure || QDELETED(trial.egg_structure))
		return ITEM_INTERACT_BLOCKING
	if(ground.is_blocked_turf() || charges < 1)
		balloon_alert(user, "the weave is spoiled!")
		return ITEM_INTERACT_BLOCKING
	charges--
	if(next_draw_at < world.time) // the reserve was full; start the redraw clock now
		next_draw_at = world.time + VESTIGE_WARM_RESIN_REGEN
	var/obj/structure/vestige_comb_resin/wall = new(ground)
	wall.bound_mind = user.mind
	trial.woven += wall
	trial.register_loan(wall)
	user.visible_message(
		span_warning("[user] draws a rope of amber resin from [src] and it stands up into a wall!"),
		span_notice("You weave a length of the comb back into the world. It sets fast."),
	)
	playsound(ground, 'sound/effects/blob/attackblob.ogg', 60, TRUE)
	return ITEM_INTERACT_SUCCESS

// --- The woven wall ---

/**
 * A wall of fresh comb resin: real resin stock (melee brute quartered, burn
 * doubled, smooths with alien walls) at a fraction of the integrity, drying
 * out on its own timer so neither an abandoned season nor a finished one
 * leaves fortifications lying around. Holds no trial reference, it clears
 * itself from its weaver's ledger through bound_mind on the way out.
 */
/obj/structure/vestige_comb_resin
	parent_type = /obj/structure/alien/resin/wall // real resin stock: armor profile, smoothing, shell-noises
	name = "fresh comb resin"
	desc = "Resin drawn warm from a loaned organ and set into a wall. It is already drying at the edges. Maybe four minutes of wall in it."
	max_integrity = VESTIGE_WARM_RESIN_INTEGRITY
	color = "#d9c184" // amber over the old purple; the comb as the Dowager remembers it
	/// Mind of the weaver, for striking this wall from the trial's ledger on Destroy
	var/datum/mind/bound_mind

/obj/structure/vestige_comb_resin/Initialize(mapload)
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(dry_out)), VESTIGE_WARM_RESIN_LIFESPAN)

/obj/structure/vestige_comb_resin/Destroy()
	var/datum/vestige_trial/warm_season/trial = bound_mind?.active_vestige_trial
	if(istype(trial))
		trial.woven -= src
	bound_mind = null
	return ..()

/// The wall's clock runs out (or its pact does): it crumbles. Safe on the deleted.
/obj/structure/vestige_comb_resin/proc/dry_out()
	if(QDELETED(src))
		return
	visible_message(span_warning("[src] dries through, sags, and sifts apart into pale dust."))
	qdel(src)

// --- The vermin ---

/**
 * The comb-chewers: the barge's salvage drones, gone feral over years of
 * eating the hive that ate their crew. Ordinary hivebot chassis with the
 * priorities inverted, trivial harm to people, ruinous harm to structures,
 * so the season is lost or won in resin, not in doorway bodyblocking. They
 * never flee, they wind down rather than linger, and they leave nothing but
 * scrap: a failed season pays nothing, and a finished one pays only through
 * the patron.
 */
/mob/living/basic/hivebot/vestige_comb_chewer
	name = "comb-chewer"
	desc = "A salvage drone gone feral, its cutters furred with resin dust and its chassis scabbed with the stuff. It isn't angry with you. It just has a quota."
	color = "#d8bf9a" // resin-scabbed amber tint over the borrowed hivebot sprite
	health = 35
	maxHealth = 35
	melee_damage_lower = 6
	melee_damage_upper = 6
	obj_damage = 25 // 6.25 per melee bite against resin, 25 against the bare egg
	death_message = "grinds to a halt and comes apart!"
	ai_controller = /datum/ai_controller/basic_controller/vestige_comb_chewer

/// A chewer's clock runs out (or its egg does): it winds down to scrap. Safe on the dead and deleted.
/mob/living/basic/hivebot/vestige_comb_chewer/proc/wind_down()
	if(QDELETED(src) || stat == DEAD)
		return
	visible_message(span_warning("[src] shudders, forgets what it was chewing, and comes apart into scrap."))
	do_sparks(3, TRUE, src)
	qdel(src)

/// The late-season gang-leader: heavier, meaner, and much worse news for a wall
/mob/living/basic/hivebot/vestige_comb_chewer/foreman
	name = "salvage foreman"
	desc = "A heavy salvage frame with parts from a dozen smaller machines riveted onto it. Whatever ran the barge's tear-down is still in there somewhere."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "foreman"
	icon_living = "foreman"
	icon_dead = "foreman_dead"
	basic_mob_flags = NONE // leaves a wreck behind instead of blowing apart like a hivebot
	color = null // custom sprite already carries the rust-and-resin palette
	health = 90
	maxHealth = 90
	melee_damage_lower = 12
	melee_damage_upper = 12
	obj_damage = 120

/**
 * Chewer AI: the hivebot toolkit re-ordered around demolition. Same dumb
 * bump-movement, which is the point: a blocked chewer chews (the stock
 * attack_obstacle_in_path subtree smashes dense objects in its way), so every
 * wall the weaver lays is time bought, not a maze solved. The targeting
 * strategy below keeps the egg valid as a held target (the generic finder
 * only scans mobs and hostile machines; the egg assigns itself).
 */
/datum/ai_controller/basic_controller/vestige_comb_chewer
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/vestige_comb_chewer,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

/**
 * Standard basic targeting, plus the egg. The egg is assigned as a blackboard
 * target by the clutch itself (find_potential_targets only scans mobs and
 * GLOB.hostile_machines), so this strategy's job is to keep that assignment
 * VALID: both the target-finder's keep-current-target check and the melee
 * behavior's re-validation run through can_attack. (The Roost's brood carp
 * proved this pattern.)
 */
/datum/targeting_strategy/basic/vestige_comb_chewer

/datum/targeting_strategy/basic/vestige_comb_chewer/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	if(istype(the_target, /obj/structure/vestige_comb_egg))
		if(QDELETED(the_target) || living_mob.z != the_target.z)
			return FALSE
		if(vision_range && get_dist(living_mob, the_target) > vision_range)
			return FALSE
		return TRUE
	return ..()

// ===== THE BOILING KISS =====

/**
 * The corrosion trial: only deaths YOUR acid is still working on count. The
 * loaned maw spits a single aimed glob; the glob starts a slow, RAMPING
 * corrosion (a status effect defined below) that clings for a fixed window,
 * and the trial credits a wild thing only if it dies inside that window. Where
 * the Roost's ember-jaw is a cone you sweep and a fire that either takes or
 * doesn't, the kiss is a commitment: spit, then close on the melting target
 * and finish it with weapons or helpers before the acid dries. Attribution is honest the same
 * way the ember-jaw's is. The maw marks what it lands on, an expired
 * corrosion releases the mark, and only a mark that dies still melting pays.
 */
/datum/vestige_trial/boiling_kiss
	name = "The Boiling Kiss"
	// Keep the numbers in sync with VESTIGE_KISS_KILLS_NEEDED / VESTIGE_KISS_CLING
	// (initial values must be constant, so no define interpolation here)
	desc = "My daughters carried acid the way courtiers carry seals. Take this maw. The acid clings for fourteen seconds and eats deeper the whole time, and I want three wild beasts at least carp-sized finished while it is still working in them. Spit, then close. You or your helpers must finish them before the acid dries. Another spit refreshes the fourteen-second window. Anything that dies unmarked is scavenge, and I do not count scavenge."
	/// Prey already entered in the ledger (weakref -> TRUE). A revived and re-melted beast is still one appointment
	var/list/dissolved = list()
	/// The loaned maw. Reclaimed the moment the pact ends.
	var/obj/item/vestige_kiss_maw/maw

/datum/vestige_trial/boiling_kiss/on_accepted(mob/living/user)
	var/obj/item/vestige_kiss_maw/kit = new(get_turf(user))
	kit.bound_mind = owner
	maw = hand_over(user, kit)
	to_chat(user, span_notice("The maw settles into your grip, jaws slightly parted. Something in the back of it is still swallowing."))

/datum/vestige_trial/boiling_kiss/Destroy()
	QDEL_NULL(maw)
	return ..()

/datum/vestige_trial/boiling_kiss/get_progress_text()
	return "The kiss has finished [length(dissolved)] of [VESTIGE_KISS_KILLS_NEEDED] wild things."

/// Credits a melting death. May complete (and delete) the trial. Returns FALSE if this beast was already dissolved.
/datum/vestige_trial/boiling_kiss/proc/consume(mob/living/prey)
	var/datum/weakref/key = WEAKREF(prey)
	if(dissolved[key])
		return FALSE
	dissolved[key] = TRUE
	refresh_tracker()
	if(length(dissolved) >= VESTIGE_KISS_KILLS_NEEDED)
		complete()
	return TRUE

// --- The maw ---

/**
 * The caustic maw: a royal daughter's fused mandibles that spit one aimed glob
 * of acid on a short cooldown, a weak taste of the caustic spit boon. Inert
 * without an active Boiling Kiss (the standing kit rule), and QDEL'd with the
 * pact. Attribution rides mark_prey below: marks mean OUR acid is in them
 * right now, and the corrosion status effect reports its own end.
 */
/obj/item/vestige_kiss_maw
	name = "caustic maw"
	desc = "The fused mandibles of a royal daughter, cured hard, with ducts that still weep something faintly smoking."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "acid"
	color = "#b9c96a"
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	light_range = 1.2
	light_power = 0.4
	light_color = "#a4d434"
	/// Mind of the supplicant this was lent to, resolved for pointer cleanup only
	var/datum/mind/bound_mind
	/// Mobs our acid is currently working in (victim -> hunter's mind), released when the corrosion ends
	var/list/marked_prey = list()
	COOLDOWN_DECLARE(spit_cooldown)

/obj/item/vestige_kiss_maw/Destroy()
	for(var/mob/living/prey as anything in marked_prey)
		UnregisterSignal(prey, list(COMSIG_LIVING_DEATH, COMSIG_LIVING_STATUS_REMOVED, COMSIG_QDELETING))
	marked_prey.Cut()
	var/datum/vestige_trial/boiling_kiss/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.maw == src)
		trial.maw = null
	bound_mind = null
	return ..()

/obj/item/vestige_kiss_maw/examine(mob/user)
	. = ..()
	for(var/mob/living/prey as anything in marked_prey)
		var/datum/status_effect/vestige_kiss_corrosion/coating = prey.has_status_effect(/datum/status_effect/vestige_kiss_corrosion)
		if(coating)
			. += span_notice("[prey]: marked for [DisplayTimeText(max(0, coating.duration - world.time))]; next acid bite [coating.bite].")
	. += span_notice("Aim it at a living thing within [VESTIGE_KISS_RANGE] tiles to spit a glob of clinging acid. Only wild animals that die while the acid is still working in them count. Helpers may finish your marked quarry. Reapply acid before it dries; examine the maw for active marks and their remaining time.")

/obj/item/vestige_kiss_maw/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with) || interacting_with == user)
		return NONE
	return spit_at(interacting_with, user, modifiers)

/obj/item/vestige_kiss_maw/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with) || interacting_with == user)
		return NONE
	return spit_at(interacting_with, user, modifiers)

/// The spit itself: one aimed glob, pact-gated, on the maw's own clock
/obj/item/vestige_kiss_maw/proc/spit_at(mob/living/target, mob/living/hunter, list/modifiers)
	var/datum/vestige_trial/boiling_kiss/trial = hunter.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(hunter, "the maw is dry!")
		return ITEM_INTERACT_BLOCKING
	if(!COOLDOWN_FINISHED(src, spit_cooldown))
		balloon_alert(hunter, "the glands are still swelling!")
		return ITEM_INTERACT_BLOCKING
	if(trial.maw != src || hunter.mind != bound_mind || !vestige_comb_quarry(target, hunter) || target.stat == DEAD || target.z != hunter.z || get_dist(target, hunter) > VESTIGE_KISS_RANGE)
		balloon_alert(hunter, "needs living wild quarry within six tiles!")
		return ITEM_INTERACT_BLOCKING
	COOLDOWN_START(src, spit_cooldown, VESTIGE_KISS_COOLDOWN)
	hunter.visible_message(
		span_danger("[hunter] squeezes [src], and it spits a hissing glob of acid at [target]!"),
		span_notice("You squeeze the maw and it spits for you."),
	)
	playsound(hunter, 'sound/mobs/non-humanoids/bileworm/bileworm_spit.ogg', 70, TRUE)
	var/obj/projectile/vestige_kiss_glob/gob = new(get_turf(hunter))
	gob.aim_projectile(target, hunter, modifiers)
	gob.firer = hunter
	gob.fired_from = src
	gob.fire()
	return ITEM_INTERACT_SUCCESS

/**
 * Attribution, done properly: a mark means OUR acid is in them right now. The
 * corrosion ending (expiry, a fullheal, anything) releases the mark, so a
 * later death pays nothing. Death while marked (and still corroding, belt and
 * suspenders) credits the hunter's live trial, resolved fresh at that moment.
 */
/obj/item/vestige_kiss_maw/proc/mark_prey(mob/living/prey, datum/mind/hunter_mind)
	if(marked_prey[prey]) // re-spat mid-melt: freshest hunter takes the appointment
		marked_prey[prey] = hunter_mind
		return
	marked_prey[prey] = hunter_mind
	RegisterSignal(prey, COMSIG_LIVING_DEATH, PROC_REF(on_prey_died))
	RegisterSignal(prey, COMSIG_LIVING_STATUS_REMOVED, PROC_REF(on_prey_status_lost))
	RegisterSignal(prey, COMSIG_QDELETING, PROC_REF(on_prey_gone))

/obj/item/vestige_kiss_maw/proc/unmark_prey(mob/living/prey)
	if(!marked_prey[prey])
		return
	marked_prey -= prey
	UnregisterSignal(prey, list(COMSIG_LIVING_DEATH, COMSIG_LIVING_STATUS_REMOVED, COMSIG_QDELETING))

/obj/item/vestige_kiss_maw/proc/on_prey_died(mob/living/prey, gibbed)
	SIGNAL_HANDLER
	var/datum/mind/hunter_mind = marked_prey[prey]
	unmark_prey(prey)
	if(!prey.has_status_effect(/datum/status_effect/vestige_kiss_corrosion)) // the kiss dried first; the removal signal usually catches this, but be sure
		return
	var/datum/vestige_trial/boiling_kiss/trial = hunter_mind?.active_vestige_trial
	if(!istype(trial))
		return
	var/mob/living/hunter = hunter_mind.current
	if(!vestige_comb_quarry(prey, hunter))
		return
	if(trial.consume(prey) && isliving(hunter)) // consume may complete (and delete) the trial, nothing touches it after this
		to_chat(hunter, span_notice("[prey] dies with the acid still working. That one counts."))
		playsound(hunter, 'sound/mobs/non-humanoids/hiss/lowHiss3.ogg', 25, TRUE)

/// The corrosion ended before the death did, the appointment lapses
/obj/item/vestige_kiss_maw/proc/on_prey_status_lost(mob/living/prey, datum/status_effect/lost)
	SIGNAL_HANDLER
	if(!istype(lost, /datum/status_effect/vestige_kiss_corrosion))
		return
	unmark_prey(prey)

/obj/item/vestige_kiss_maw/proc/on_prey_gone(mob/living/prey)
	SIGNAL_HANDLER
	unmark_prey(prey)

// --- The glob ---

/obj/projectile/vestige_kiss_glob
	name = "glob of royal acid"
	icon_state = "neurotoxin"
	color = "#a4d434"
	damage = VESTIGE_KISS_SPLASH_DAMAGE
	damage_type = BURN
	armor_flag = BIO
	range = VESTIGE_KISS_RANGE
	impact_effect_type = /obj/effect/temp_visual/impact_effect/neurotoxin
	hitsound = 'sound/effects/wounds/sizzle1.ogg'

/obj/projectile/vestige_kiss_glob/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(. != BULLET_ACT_HIT)
		return
	var/obj/item/vestige_kiss_maw/maw = fired_from
	var/mob/living/hunter = firer
	var/datum/vestige_trial/boiling_kiss/trial = hunter?.mind?.active_vestige_trial
	// atom/bullet_act calls on_hit before living applies projectile damage.
	// Keep the mark here so a lethal first glob retains its existing credit.
	if(isliving(target) && blocked < 100 && istype(maw) && !QDELETED(maw) && istype(trial) && trial.maw == maw && maw.bound_mind == hunter.mind)
		var/mob/living/prey = target
		if(!HAS_TRAIT(prey, TRAIT_GODMODE) && prey.stat != DEAD)
			prey.apply_status_effect(/datum/status_effect/vestige_kiss_corrosion)
			if(vestige_comb_quarry(prey, hunter))
				maw.mark_prey(prey, hunter.mind)
				maw.balloon_alert(hunter, "[prey]: fourteen-second acid mark")
	return .

// --- The corrosion ---

/**
 * The kiss itself: a clinging corrosion that eats DEEPER the longer it works,
 * each tick bites one point harder than the last, up to a cap, but expires on
 * a fixed clock. Re-spitting refreshes the clock without resetting the depth
 * (same instance, STATUS_EFFECT_REFRESH), so a committed hunter can keep a big
 * beast melting through a long fight. On its own it rarely kills anything
 * bigger than vermin; that is the design. The acid opens the appointment, the
 * hunter keeps it.
 */
/datum/status_effect/vestige_kiss_corrosion
	id = "vestige_kiss_corrosion"
	duration = VESTIGE_KISS_CLING
	tick_interval = VESTIGE_KISS_TICK
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/vestige_kiss_corrosion
	/// How much burn the next tick eats. The kiss eats deeper the longer it clings
	var/bite = 1

/datum/status_effect/vestige_kiss_corrosion/on_apply()
	owner.add_atom_colour("#9fbf4e", TEMPORARY_COLOUR_PRIORITY)
	return TRUE

/datum/status_effect/vestige_kiss_corrosion/tick(seconds_between_ticks)
	if(owner.stat == DEAD)
		return
	owner.adjustFireLoss(bite)
	bite = min(bite + 1, VESTIGE_KISS_BITE_CAP)
	if(prob(40))
		playsound(owner, 'sound/effects/wounds/sizzle1.ogg', 12, TRUE)

/datum/status_effect/vestige_kiss_corrosion/on_remove()
	owner.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, "#9fbf4e")

/atom/movable/screen/alert/status_effect/vestige_kiss_corrosion
	name = "Boiling Kiss"
	desc = "Acid is clinging to you, eating deeper the longer it sits. It burns itself out after a few seconds."

// ===== THE CENSUS =====

/**
 * The timing trial, at range: sting wild things in the very act of hunting.
 * The loaned stinger fires a barb at any distance in view, but only a subject
 * that is CURRENTLY mid-hunt (AI locked onto a living person) enters the
 * rolls, and a counted subject seizes briefly (the interception's payoff: you
 * can genuinely break a charge aimed at a friend). An idle beast stung is
 * scenery: no entry, no seize, so the barb never becomes a stun weapon (the
 * Menagerie's probe precedent). Where the Roost's Wingbeat is a two-tile
 * melee-range parry, the Census is read-and-intercept at seven tiles, the
 * pressure is watching OTHER hunts, not surviving your own. Recorded per
 * behavior: each quarry supplies one distant pursuit and one close commitment.
 */
/datum/vestige_trial/comb_census
	name = "The Census"
	// Keep the numbers in sync with VESTIGE_CENSUS_MARKS_NEEDED / VESTIGE_CENSUS_PER_SUBJECT
	// (initial values must be constant, so no define interpolation here)
	desc = "A queen should know what hunts along her borders. Take the stinger and count them for me: sting wild things in the act of hunting, mid-charge, already committed to something alive. Four entries: record a distant pursuit (at least four tiles from its prey) and a close commitment (within two tiles) from each of two beasts. No beast can contribute the same behavior twice. An idle animal does not count. Counted beasts briefly seize up unless they are immune to stuns, which you may find useful."
	/// Entries in the rolls so far
	var/entries = 0
	/// Subjects with both pursuit and commitment recorded; incomplete profiles never block new ones.
	var/complete_profiles = 0
	/// Recorded behaviors per subject (weakref -> list of behavior names)
	var/list/entries_per_subject = list()
	/// The loaned stinger. Reclaimed the moment the pact ends.
	var/obj/item/vestige_census_stinger/stinger

/datum/vestige_trial/comb_census/on_accepted(mob/living/user)
	var/obj/item/vestige_census_stinger/kit = new(get_turf(user))
	kit.bound_mind = owner
	stinger = hand_over(user, kit)
	to_chat(user, span_notice("The stinger lies along your forearm like it was measured for it."))

/datum/vestige_trial/comb_census/Destroy()
	QDEL_NULL(stinger)
	return ..()

/datum/vestige_trial/comb_census/get_progress_text()
	return "[complete_profiles]/2 complete profiles: each beast needs both a distant pursuit and a close commitment. [entries] observations total; you may abandon an incomplete profile and observe another beast."

/// Enters a mid-hunt subject in the rolls. May complete (and delete) the trial. Returns FALSE if this subject is counted out.
/datum/vestige_trial/comb_census/proc/tally(mob/living/subject, behavior)
	if(!(behavior in list("pursuit", "commitment")))
		return FALSE
	var/datum/weakref/key = WEAKREF(subject)
	var/list/prior = entries_per_subject[key]
	if(!prior)
		prior = list()
		entries_per_subject[key] = prior
	if(!behavior || (behavior in prior))
		return FALSE
	prior += behavior
	entries++
	if(length(prior) == 2)
		complete_profiles++
	refresh_tracker()
	if(complete_profiles >= 2)
		complete()
	return TRUE

// --- The stinger ---

/**
 * The census stinger: a royal tail-barb cured to amber, firing a neuro-barb on
 * a short cooldown. The barb always flies and always pricks (token toxin);
 * the SEIZE and the entry only land together, on honest quarry caught
 * mid-hunt, judged at the moment of impact, because the whole trial is what
 * they were doing when the barb met them. Inert without an active Census,
 * QDEL'd with the pact.
 */
/obj/item/vestige_census_stinger
	name = "census stinger"
	desc = "An amber tail-barb with a needle that still weeps one slow bead at a time. It handles more like a rubber stamp than a weapon."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "neurotox"
	inhand_icon_state = "stinger"
	lefthand_file = 'icons/mob/inhands/weapons/melee_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/melee_righthand.dmi'
	color = "#d8c06a"
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	/// Mind of the supplicant this was lent to, resolved for pointer cleanup only
	var/datum/mind/bound_mind
	COOLDOWN_DECLARE(sting_cooldown)

/obj/item/vestige_census_stinger/Destroy()
	var/datum/vestige_trial/comb_census/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.stinger == src)
		trial.stinger = null
	bound_mind = null
	return ..()

/obj/item/vestige_census_stinger/examine(mob/user)
	. = ..()
	. += span_notice("Aim it at a living thing within [VESTIGE_CENSUS_RANGE] tiles to fire a neuro-barb. Only a wild animal caught in the act of hunting a living person goes in the rolls. Counted subjects seize up unless they are immune to stuns. Each beast can supply one pursuit (at least four tiles from its prey) and one commitment (within two tiles). The barb checks again at impact.")

/obj/item/vestige_census_stinger/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with) || interacting_with == user)
		return NONE
	return sting_at(interacting_with, user, modifiers)

/obj/item/vestige_census_stinger/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with) || interacting_with == user)
		return NONE
	return sting_at(interacting_with, user, modifiers)

/// The barb itself: one aimed shot, pact-gated, on the stinger's own clock
/obj/item/vestige_census_stinger/proc/sting_at(mob/living/target, mob/living/hunter, list/modifiers)
	var/datum/vestige_trial/comb_census/trial = hunter.mind?.active_vestige_trial
	if(!istype(trial) || trial.stinger != src || bound_mind != hunter.mind)
		balloon_alert(hunter, "the stinger hangs limp!")
		return ITEM_INTERACT_BLOCKING
	if(target.z != hunter.z || get_dist(target, hunter) > VESTIGE_CENSUS_RANGE)
		balloon_alert(hunter, "the barb only reaches seven tiles!")
		return ITEM_INTERACT_BLOCKING
	if(!COOLDOWN_FINISHED(src, sting_cooldown))
		balloon_alert(hunter, "the barb is still weeping!")
		return ITEM_INTERACT_BLOCKING
	var/behavior = observed_behavior(target)
	var/list/prior = trial.entries_per_subject[WEAKREF(target)]
	if(!vestige_comb_quarry(target, hunter) || !is_declared_hunter(target, hunter) || !behavior || (behavior in prior))
		balloon_alert(hunter, "need a new pursuit (4+ tiles) or commitment (1-2 tiles)!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(hunter, "[behavior] ready")
	COOLDOWN_START(src, sting_cooldown, VESTIGE_CENSUS_COOLDOWN)
	hunter.visible_message(
		span_danger("[hunter] flicks [src], and a barb whips out toward [target]!"),
		span_notice("You flick the stinger and the barb whips out."),
	)
	playsound(hunter, 'sound/items/weapons/pierce.ogg', 60, TRUE)
	var/obj/projectile/vestige_census_barb/barb = new(get_turf(hunter))
	barb.aim_projectile(target, hunter, modifiers)
	barb.firer = hunter
	barb.fired_from = src
	barb.fire()
	return ITEM_INTERACT_SUCCESS

/**
 * The appraisal, judged at impact: quarry, conscious, and mid-hunt against a
 * living person. Entered subjects are seized; capped or idle subjects get the
 * prick and nothing else. The barb pays only when the ledger does.
 */
/obj/item/vestige_census_stinger/proc/appraise(mob/living/subject, mob/living/hunter)
	var/datum/vestige_trial/comb_census/trial = hunter.mind?.active_vestige_trial
	if(!istype(trial) || trial.stinger != src || bound_mind != hunter.mind) // the pact ended while the barb was in the air
		return
	if(!vestige_comb_quarry(subject, hunter))
		return
	if(!is_declared_hunter(subject, hunter))
		to_chat(hunter, span_warning("[subject] was idle when the barb landed. Only hunts already underway count."))
		return
	var/behavior = observed_behavior(subject)
	if(!behavior)
		balloon_alert(hunter, "between pursuit and commitment ranges")
		return
	if(!trial.tally(subject, behavior)) // may complete (and delete) the trial, nothing touches it after this
		to_chat(hunter, span_warning("[subject] has already shown that behavior. Observe its other range, or another beast."))
		return
	// Basic fauna commonly have CANSTUN without CANKNOCKDOWN, which Paralyze also requires.
	if(subject.Stun(VESTIGE_CENSUS_SEIZE))
		subject.visible_message(
			span_danger("[subject] seizes mid-lunge, every limb stamped still at once!"),
			span_userdanger("Something cold hits you, and your whole body locks up!"),
		)
	else
		balloon_alert(hunter, "counted; resists the stun!")
	to_chat(hunter, span_notice("[subject] is entered in the rolls: [behavior]."))

/**
 * TRUE when a subject's sting should count: conscious and currently hunting a
 * living person, the hunter, or anyone with a soul. Basic mobs report their
 * hunt through the AI blackboard; the old simple_animal hostiles still carry
 * theirs on a target var. (Quarry-ness is checked separately, above.)
 */
/obj/item/vestige_census_stinger/proc/observed_behavior(mob/living/subject)
	var/mob/living/prey = vestige_loom_hunted_prey(subject)
	if(!prey)
		return null
	var/distance = get_dist(subject, prey)
	if(subject.z != prey.z)
		return null
	if(distance >= 4)
		return "pursuit"
	if(distance <= 2)
		return "commitment"
	return null

/obj/item/vestige_census_stinger/proc/is_declared_hunter(mob/living/subject, mob/living/hunter)
	if(subject.stat != CONSCIOUS)
		return FALSE
	var/atom/mark
	var/datum/ai_controller/instincts = subject.ai_controller
	if(instincts)
		mark = instincts.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(isnull(mark) && istype(subject, /mob/living/simple_animal/hostile))
		var/mob/living/simple_animal/hostile/old_beast = subject
		mark = old_beast.target
	if(!isliving(mark))
		return FALSE
	var/mob/living/quarry = mark
	if(quarry.stat == DEAD)
		return FALSE
	// The census counts hunts against people: the hunter, or any living soul
	return quarry == hunter || quarry.mind || ishuman(quarry)

// --- The barb ---

/obj/projectile/vestige_census_barb
	name = "census barb"
	icon_state = "toxin"
	color = "#e8cf7a"
	damage = VESTIGE_CENSUS_STING_DAMAGE
	damage_type = TOX
	armor_flag = BIO
	range = VESTIGE_CENSUS_RANGE
	impact_effect_type = /obj/effect/temp_visual/impact_effect/neurotoxin
	hitsound = 'sound/items/weapons/pierce.ogg'

/obj/projectile/vestige_census_barb/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(!isliving(target) || blocked >= 100)
		return
	var/obj/item/vestige_census_stinger/stinger = fired_from
	var/mob/living/hunter = firer
	if(!istype(stinger) || QDELETED(stinger) || !isliving(hunter))
		return
	stinger.appraise(target, hunter)

#undef VESTIGE_WARM_SQUAD_DELAY
#undef VESTIGE_WARM_WARNING_TIME
#undef VESTIGE_WARM_SQUADS
#undef VESTIGE_WARM_SPAWN_RANGE
#undef VESTIGE_WARM_CHEWER_LIFESPAN
#undef VESTIGE_WARM_EGG_INTEGRITY
#undef VESTIGE_WARM_RESIN_INTEGRITY
#undef VESTIGE_WARM_RESIN_LIFESPAN
#undef VESTIGE_WARM_RESIN_CHARGES
#undef VESTIGE_WARM_RESIN_REGEN
#undef VESTIGE_WARM_WEAVE_RANGE
#undef VESTIGE_WARM_WEAVE_TIME
#undef VESTIGE_KISS_KILLS_NEEDED
#undef VESTIGE_KISS_COOLDOWN
#undef VESTIGE_KISS_RANGE
#undef VESTIGE_KISS_SPLASH_DAMAGE
#undef VESTIGE_KISS_CLING
#undef VESTIGE_KISS_TICK
#undef VESTIGE_KISS_BITE_CAP
#undef VESTIGE_CENSUS_MARKS_NEEDED
#undef VESTIGE_CENSUS_PER_SUBJECT
#undef VESTIGE_CENSUS_COOLDOWN
#undef VESTIGE_CENSUS_RANGE
#undef VESTIGE_CENSUS_SEIZE
#undef VESTIGE_CENSUS_STING_DAMAGE


/**
 * # The Comb: xenomorph vestige boons
 *
 * The Dowager's half of the bargain: the arts of a dead house, granted to
 * adoptive brood. The xenomorph's power upstream is a whole parallel biology,
 * plasma vessels, alien organs, carbon-only action datums, so nothing here is
 * a direct port. The upstream alien action base (/datum/action/cooldown/alien,
 * alien_powers.dm) hard-fails IsAvailable for anyone without a plasma vessel
 * organ (getPlasma() returns -1 for a plain human), so every art below is a
 * standalone reimplementation on the generic spell rails, plasma economy
 * traded for cooldowns, the same treatment the fleet gave the Mansus grasp
 * and the morph's maw.
 *
 * Three chains, six boons:
 * - the acid (Caustic Spit -> Vitriol): anti-property corrosion at range
 * - the sting (Neurotoxic Lash -> Paralytic Lash): stamina pressure, opener not stunlock
 * - the architecture (Resin Weaving -> Brood Architecture): real upstream resin
 *   structures, channelled and capped
 *
 * Patron and trials live in the theme file; only the boons and their spells
 * are defined here. Boon typepaths are the contract the patron's boon_types
 * list references.
 */

// Tuning constants (file-local, #undef at bottom). Boon descs quote these
// numbers literally, keep them in sync.

// --- The acid ---
/// Spits per Caustic Spit cooldown window
#define VESTIGE_SPIT_COOLDOWN (12 SECONDS)
/// Burn a glob deals to living things. Deliberately mediocre; the acid is for property
#define VESTIGE_SPIT_MOB_BURN 10
/// Acid power handed to the acid component on struck objects (upstream xeno corrosion is 200)
#define VESTIGE_SPIT_ACID_POWER 80
/// Acid volume ditto (upstream 1000): ~43 raw damage/sec decaying over ~12s; vs an airlock's
/// 70 acid armor that's ~130-150 per glob, so 3-4 globs per standard airlock (450 integrity)
#define VESTIGE_SPIT_ACID_VOLUME 250
/// Spits per Vitriol cooldown window
#define VESTIGE_SPIT_VITRIOL_COOLDOWN (10 SECONDS)
/// Burn Vitriol deals to living things
#define VESTIGE_SPIT_VITRIOL_MOB_BURN 15
/// Vitriol's deeper corrosion: ~77 raw/sec over ~15s; roughly two globs per airlock
#define VESTIGE_SPIT_VITRIOL_ACID_POWER 160
#define VESTIGE_SPIT_VITRIOL_ACID_VOLUME 400
/// Flat damage the vitriol glob deals a struck object on impact, before the corrosion
#define VESTIGE_SPIT_VITRIOL_IMPACT 60
/// Armor the impact bites through: 50 gets through window acid armor (100), which
/// plain acid_act never touches: this is the "melts what the base cannot" mechanism
#define VESTIGE_SPIT_VITRIOL_IMPACT_AP 50
/// How long a vitriol splash keeps sizzling where it landed
#define VESTIGE_SPIT_RESIDUE_LIFETIME (8 SECONDS)
/// Burn per second for standing in the splash
#define VESTIGE_SPIT_RESIDUE_BURN 5
/// How long vitriol keeps eating at someone it splashed, if they don't wash it off
#define VESTIGE_SPIT_COATING_DURATION (10 SECONDS)
/// Burn per second while the coating is still on them
#define VESTIGE_SPIT_COATING_BURN 2

// --- The sting ---
/// Stings per Neurotoxic Lash cooldown window
#define VESTIGE_LASH_COOLDOWN (12 SECONDS)
/// Stamina damage a dart deals (upstream alien neurotoxin is 65 at AP 50)
#define VESTIGE_LASH_STAMINA 40
/// Armor the dart drills through (BIO armor class, same as upstream)
#define VESTIGE_LASH_AP 30
/// Slurred tongue on hit
#define VESTIGE_LASH_SLUR (6 SECONDS)
/// Staggered (movespeed slow) on hit, and the ceiling repeated darts can stack it to
#define VESTIGE_LASH_STAGGER (4 SECONDS)
#define VESTIGE_LASH_STAGGER_MAX (8 SECONDS)
/// Watering eyes on hit
#define VESTIGE_LASH_EYEBLUR (2 SECONDS)
/// Paralytic Lash cooldown: longer, because it carries two darts
#define VESTIGE_LASH_PARALYTIC_COOLDOWN (16 SECONDS)
/// Darts per Paralytic Lash cast (fired click by click; banking one part-refunds the cooldown)
#define VESTIGE_LASH_PARALYTIC_VOLLEY 2
/// Stamina damage a target must already carry for a paralytic dart to floor them.
/// on_hit runs BEFORE the dart's own damage lands (atom_act.dm: bullet_act calls
/// proj.on_hit first, living applies damage after), so this is tuned to what dart
/// two actually sees after dart one: 40 base, less after armor
#define VESTIGE_LASH_FLOOR_THRESHOLD 35
/// The knockdown itself: a fold, not a leash
#define VESTIGE_LASH_FLOOR_KNOCKDOWN (1.5 SECONDS)

// --- The architecture ---
/// Seconds of throat-work to raise one structure
#define VESTIGE_RESIN_CHANNEL (3 SECONDS)
/// Works per Resin Weaving cooldown window
#define VESTIGE_RESIN_COOLDOWN (20 SECONDS)
/// Standing works the base craft sustains, raising one past this crumbles the eldest
#define VESTIGE_RESIN_CAP 6
/// The architect's quicker throat
#define VESTIGE_RESIN_ARCHITECT_CHANNEL (1.5 SECONDS)
#define VESTIGE_RESIN_ARCHITECT_COOLDOWN (10 SECONDS)
#define VESTIGE_RESIN_ARCHITECT_CAP 10
/// Brute AND burn each the brood cradle knits per second of willing rest
#define VESTIGE_RESIN_CRADLE_HEAL 2
/// Stamina the cradle clears per second
#define VESTIGE_RESIN_CRADLE_STAMINA 5

// ===== BOONS =====

// --- Chain: the acid ---

/datum/vestige_boon/spell/caustic_spit
	name = "Caustic Spit"
	desc = "Spit acid across the room. The glob clings to whatever object it hits and eats away at it. A few will open a standard airlock, though glass shrugs it off entirely. Against people it is only a light scald: this is a tool for property, not flesh. Needs a bare mouth, and it will not touch floors or hull."
	grant_text = "A new gland settles in behind your back teeth."
	spell_type = /datum/action/cooldown/spell/pointed/projectile/vestige_spit/caustic

/datum/vestige_boon/spell/caustic_spit/vitriol
	name = "Vitriol"
	desc = "The acid, matured. It bites through the glass and riot-grade property the young acid could not touch, the corrosion runs deeper, and the splash leaves a sizzling pool that burns anyone standing in it, you included. Anyone it catches directly wears the acid until they wash it off."
	grant_text = "The gland deepens. Whatever it makes now bites harder."
	upgrades_from = /datum/vestige_boon/spell/caustic_spit
	spell_type = /datum/action/cooldown/spell/pointed/projectile/vestige_spit/caustic/vitriol

// --- Chain: the sting ---

/datum/vestige_boon/spell/neuro_lash
	name = "Neurotoxic Lash"
	desc = "Spit a neurotoxin dart across the room, mouth uncovered. It heavily saps stamina and leaves them staggered, slurring and blurry-eyed. It opens a fight. It does not finish one."
	grant_text = "Something coils up at the hinge of your jaw."
	spell_type = /datum/action/cooldown/spell/pointed/projectile/vestige_spit/neuro

/datum/vestige_boon/spell/neuro_lash/paralytic
	name = "Paralytic Lash"
	desc = "Two darts per cooldown now, fired one click at a time. Any dart that lands on someone already winded knocks them down, so landing both always drops them. It is a knockdown, not a stunlock. They get straight back up."
	grant_text = "The sting learns a second shot."
	upgrades_from = /datum/vestige_boon/spell/neuro_lash
	spell_type = /datum/action/cooldown/spell/pointed/projectile/vestige_spit/neuro/paralytic

// --- Chain: the architecture ---

/datum/vestige_boon/spell/resin_weaver
	name = "Resin Weaving"
	desc = "Pick bare floor next to you and work your throat to raise a resin wall (blunt hits glance off it, fire eats it twice as fast) or a membrane you can see through. Only so many stand at once; raise another and the oldest sloughs away. It needs real floor, and will not build on someone standing there."
	grant_text = "Your throat learns the old craft."
	spell_type = /datum/action/cooldown/spell/pointed/vestige_resin_weaver

/datum/vestige_boon/spell/resin_weaver/architect
	name = "Brood Architecture"
	desc = "Much faster to raise now, and more of them stand at once. You can also build a brood cradle: lie into it willingly and it swaddles your hands useless while it mends you as you rest. Resist to get out; it never argues. It only ever takes the willing."
	grant_text = "The craft matures in your throat."
	upgrades_from = /datum/vestige_boon/spell/resin_weaver
	spell_type = /datum/action/cooldown/spell/pointed/vestige_resin_weaver/architect

// ===== THE SPIT (shared mouth) =====

/**
 * Common chassis for both of the house's spat arts. Upstream both live on
 * /datum/action/cooldown/alien/acid (alien_powers.dm), which is welded to
 * carbon plasma vessels; this is the same click-to-fire experience rebuilt on
 * the pointed projectile spell rail (wholly mob-type-agnostic, verified: the
 * whole cast chain runs off owner and the clicked atom). One upstream honesty
 * is kept deliberately: a covered mouth cannot spit (the alien neurotoxin
 * gland refuses through a mask, and so do we), routed through before_cast
 * because this fork's Activate() ignores cast() return values.
 */
/datum/action/cooldown/spell/pointed/projectile/vestige_spit
	button_icon = 'icons/mob/actions/actions_xeno.dmi'
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	sound = 'sound/mobs/non-humanoids/hiss/hiss6.ogg'
	spell_requirements = NONE
	cast_range = 7
	/// The line shouted over the deck when a glob goes out
	var/spit_message = "spits!"
	/// The same line, addressed to the spitter
	var/spit_message_self = "You spit."

/datum/action/cooldown/spell/pointed/projectile/vestige_spit/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	if(iscarbon(owner))
		var/mob/living/carbon/spitter = owner
		if(spitter.is_mouth_covered(ITEM_SLOT_MASK))
			owner.balloon_alert(owner, "your mouth is covered!")
			return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/pointed/projectile/vestige_spit/after_cast(atom/cast_on)
	. = ..()
	owner.visible_message(
		span_danger("[owner] [spit_message]"),
		span_noticealien(spit_message_self),
	)

// --- Caustic spit ---

/datum/action/cooldown/spell/pointed/projectile/vestige_spit/caustic
	name = "Caustic Spit"
	desc = "Spit a glob of corrosive acid across the room. Eats through objects and lightly scalds people. Needs a bare mouth."
	button_icon_state = "alien_acid"
	cooldown_time = VESTIGE_SPIT_COOLDOWN
	active_msg = "You work your tongue against a gland that was not there yesterday..."
	deactive_msg = "You swallow the acid back down. It goes reluctantly."
	projectile_type = /obj/projectile/vestige_caustic_spit
	spit_message = "spits a hissing glob of acid!"
	spit_message_self = "You spit a hissing glob of acid."

/**
 * The acid, in flight. Mediocre against flesh by design (the upstream
 * corrosion refuses mobs outright because it would one-shot them; we allow a
 * scald and nothing more), and it NEVER touches turfs: the upstream turf
 * branch (AddComponent acid on a turf) melts walls and floors stage by stage.
 * Aboard a player ship that is a hole in the hull with extra steps, so both
 * tiers refuse turfs entirely and say so here. Object corrosion only.
 *
 * Mob equipment is also left alone on purpose, acid_act on a carbon melts
 * worn gear, which in PvP boarding is uncounterable inventory deletion.
 */
/obj/projectile/vestige_caustic_spit
	name = "caustic spit"
	icon_state = "neurotoxin"
	color = "#c4d24a" // bile-gold: the house's acid, not the sting
	damage = VESTIGE_SPIT_MOB_BURN
	damage_type = BURN
	armor_flag = BIO
	impact_effect_type = /obj/effect/temp_visual/impact_effect/neurotoxin
	/// Acid power handed to the corrosion component on struck objects
	var/acid_power = VESTIGE_SPIT_ACID_POWER
	/// Acid volume ditto: how long the meal lasts
	var/acid_volume = VESTIGE_SPIT_ACID_VOLUME

/obj/projectile/vestige_caustic_spit/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(!isobj(target)) // living things got the scald from the parent; turfs get NOTHING (hull safety, see header)
		return
	var/obj/property = target
	// acid_act refuses UNACIDABLE things itself and returns FALSE
	if(property.acid_act(acid_power, acid_volume))
		property.visible_message(span_danger("[property] sizzles and smokes under the clinging acid!"))

// --- Vitriol ---

/datum/action/cooldown/spell/pointed/projectile/vestige_spit/caustic/vitriol
	name = "Vitriol"
	desc = "Spit a glob of matured acid across the room. Wrecks objects through their armor, leaves a sizzling pool, and keeps burning anyone it catches until they wash it off. Needs a bare mouth."
	cooldown_time = VESTIGE_SPIT_VITRIOL_COOLDOWN
	projectile_type = /obj/projectile/vestige_caustic_spit/vitriol
	spit_message = "spits a seething rope of vitriol!"
	spit_message_self = "You spit a seething rope of vitriol."

/**
 * The impact damage is the qualitative step up: plain acid_act rides the acid
 * component, whose damage respects acid armor with no penetration, windows
 * (acid 100, window.dm) are flatly immune to the base glob. The vitriol
 * impact goes through take_damage with 50 AP, so glass and riot-grade
 * property finally answer for themselves. The residue pool is our own effect
 * (below), not the acid component, the component on a TURF melts the turf,
 * and no tier of this art is allowed to do that.
 */
/obj/projectile/vestige_caustic_spit/vitriol
	name = "vitriolic spit"
	color = "#96d41e"
	damage = VESTIGE_SPIT_VITRIOL_MOB_BURN
	acid_power = VESTIGE_SPIT_VITRIOL_ACID_POWER
	acid_volume = VESTIGE_SPIT_VITRIOL_ACID_VOLUME
	/// Flat impact damage to struck objects, dealt before the corrosion sets in
	var/impact_damage = VESTIGE_SPIT_VITRIOL_IMPACT
	/// Armor the impact bites through
	var/impact_penetration = VESTIGE_SPIT_VITRIOL_IMPACT_AP

/obj/projectile/vestige_caustic_spit/vitriol/on_hit(atom/target, blocked = 0, pierce_hit)
	// The pool goes down wherever the glob dies. If it died against a wall,
	// puddle at the projectile's own last open tile instead of inside the wall.
	var/turf/splash = get_turf(target)
	if(isclosedturf(splash))
		splash = get_turf(src)
	. = ..() // parent handles the scald and the object corrosion
	if(splash)
		new /obj/effect/vestige_vitriol_residue(splash)
	// Anyone it caught wears it until they wash it off
	if(isliving(target))
		if(blocked >= 100)
			return
		var/mob/living/splashed = target
		splashed.apply_status_effect(/datum/status_effect/vestige_vitriol_coating)
		return
	if(!isobj(target))
		return
	var/obj/property = target
	if(!property.uses_integrity || (property.resistance_flags & (INDESTRUCTIBLE|UNACIDABLE)))
		return
	property.take_damage(impact_damage, BURN, ACID, TRUE, null, impact_penetration)

/**
 * The splash: a few seconds of sizzling zone denial where a vitriol glob
 * landed. Deliberately narrow, it burns LIVING things standing in it (anyone,
 * the spitter included: acid has no loyalty) and nothing else. It never
 * attaches acid to its turf (hull safety) and leaves loose items to the
 * direct-hit corrosion, so the grief surface is exactly one tile of "do not
 * stand here" on an 8-second timer. Stacked pools from multiple spitters
 * stack their burn; one spitter's cooldown outlasts the pool's lifetime.
 */
/obj/effect/vestige_vitriol_residue
	name = "sizzling vitriol"
	desc = "A slick of spat acid hissing away on the floor. It will burn itself out in a few seconds."
	icon = 'icons/effects/acid.dmi'
	icon_state = "default"
	color = "#96d41e"
	alpha = 180
	anchored = TRUE
	layer = ABOVE_OPEN_TURF_LAYER
	plane = FLOOR_PLANE
	/// Throttles the "your boots are sizzling" spam
	COOLDOWN_DECLARE(sizzle_warning)

/obj/effect/vestige_vitriol_residue/Initialize(mapload)
	. = ..()
	QDEL_IN(src, VESTIGE_SPIT_RESIDUE_LIFETIME)
	START_PROCESSING(SSobj, src)
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/effect/vestige_vitriol_residue/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/effect/vestige_vitriol_residue/process(seconds_per_tick)
	for(var/mob/living/bather in loc)
		scald(bather, VESTIGE_SPIT_RESIDUE_BURN * seconds_per_tick)

/obj/effect/vestige_vitriol_residue/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(!isliving(arrived))
		return
	scald(arrived, VESTIGE_SPIT_RESIDUE_BURN)

/// One helping of the pool. Damage-only, no gear melting, no stun riders.
/obj/effect/vestige_vitriol_residue/proc/scald(mob/living/bather, burn)
	if(bather.stat == DEAD || HAS_TRAIT(bather, TRAIT_GODMODE))
		return
	bather.adjustFireLoss(burn)
	if(COOLDOWN_FINISHED(src, sizzle_warning))
		COOLDOWN_START(src, sizzle_warning, 2 SECONDS)
		to_chat(bather, span_danger("The vitriol sizzles against you!"))
		playsound(src, 'sound/items/tools/welder.ogg', 30, TRUE)

/// A mop, a shower or a bucket ends the pool early. Same rule the acid component uses
/obj/effect/vestige_vitriol_residue/wash(clean_types)
	. = ..()
	if(.)
		return
	if(!(clean_types & CLEAN_TYPE_ACID))
		return NONE
	qdel(src)
	return COMPONENT_CLEANED|COMPONENT_CLEANED_GAIN_XP

/**
 * What a vitriol glob leaves on a person: a coat of acid that keeps eating for
 * ten seconds unless they get it off them. Washing is the counterplay, and it
 * is a real one, showers, sinks, water splashes, extinguishers and a janitor's
 * spray all route through /atom/proc/wash, and CLEAN_WASH carries
 * CLEAN_TYPE_ACID, which is the same rule the engine's own acid component
 * follows. It also SHOWS: a green outline sizzling around the victim, so a
 * splashed crewman is visibly a splashed crewman and not just someone who
 * quietly took fifteen burn from off-screen.
 */
/datum/status_effect/vestige_vitriol_coating
	id = "vestige_vitriol_coating"
	duration = VESTIGE_SPIT_COATING_DURATION
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/vestige_vitriol_coating
	show_duration = TRUE

/datum/status_effect/vestige_vitriol_coating/on_apply()
	RegisterSignal(owner, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_washed))
	owner.add_filter("vestige_vitriol", 2, list("type" = "outline", "size" = 1, "color" = "#96d41e"))
	owner.visible_message(
		span_danger("[owner] is coated in hissing acid!"),
		span_userdanger("Acid clings to you and starts eating inward! Wash it off - a shower, a sink, anything wet."),
	)
	playsound(owner, 'sound/items/tools/welder.ogg', 40, TRUE)
	return TRUE

/datum/status_effect/vestige_vitriol_coating/on_remove()
	UnregisterSignal(owner, COMSIG_COMPONENT_CLEAN_ACT)
	owner.remove_filter("vestige_vitriol")
	return ..()

/datum/status_effect/vestige_vitriol_coating/tick(seconds_between_ticks)
	if(owner.stat == DEAD || HAS_TRAIT(owner, TRAIT_GODMODE))
		return
	owner.adjustFireLoss(VESTIGE_SPIT_COATING_BURN * seconds_between_ticks)

/// Anything that washes the victim takes the coat with it
/datum/status_effect/vestige_vitriol_coating/proc/on_washed(datum/source, clean_types)
	SIGNAL_HANDLER
	if(!(clean_types & CLEAN_TYPE_ACID))
		return NONE
	owner.visible_message(
		span_notice("The acid sluices off [owner], hissing as it goes."),
		span_notice("The acid washes off you."),
	)
	qdel(src)
	return COMPONENT_CLEANED|COMPONENT_CLEANED_GAIN_XP

/atom/movable/screen/alert/status_effect/vestige_vitriol_coating
	name = "Coated in Vitriol"
	desc = "Acid is eating into you. Wash it off. A shower, a sink, a bucket, anything wet will do it."
	icon = 'icons/mob/actions/actions_xeno.dmi'
	icon_state = "alien_acid"

// ===== THE STING =====

/**
 * The neurotoxin, rebuilt. Upstream's gland (alien/acid/neurotoxin) is the
 * same welded carbon action, and its projectile (/obj/projectile/neurotoxin,
 * spit.dm) deals 65 stamina at AP 50, near-crit from a single hit. This
 * house teaches a smaller sting: 40 at AP 30, plus the short sensory riders
 * (stagger, slur, blur) that make it a fight-OPENER. The riders live on our
 * own projectile subtype; slur/blur ride the projectile vars the engine
 * already applies on hit (living_defense.dm apply_effects), the stagger is
 * applied in on_hit because there is no projectile var for it.
 */
/datum/action/cooldown/spell/pointed/projectile/vestige_spit/neuro
	name = "Neurotoxic Lash"
	desc = "Spit a neurotoxin dart across the room. Heavily saps stamina, and leaves them staggered and slurring for a few seconds. Needs a bare mouth."
	button_icon_state = "alien_neurotoxin_0"
	cooldown_time = VESTIGE_LASH_COOLDOWN
	active_msg = "Your jaw aches as the sting seats itself..."
	deactive_msg = "You unclench. The sting settles back to waiting."
	projectile_type = /obj/projectile/vestige_neuro_lash
	spit_message = "spits a lash of neurotoxin!"
	spit_message_self = "You spit a lash of neurotoxin."

/obj/projectile/vestige_neuro_lash
	name = "neurotoxic lash"
	icon_state = "neurotoxin"
	damage = VESTIGE_LASH_STAMINA
	damage_type = STAMINA
	armor_flag = BIO
	armour_penetration = VESTIGE_LASH_AP
	slur = VESTIGE_LASH_SLUR
	eyeblur = VESTIGE_LASH_EYEBLUR
	impact_effect_type = /obj/effect/temp_visual/impact_effect/neurotoxin

/obj/projectile/vestige_neuro_lash/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(!isliving(target) || blocked >= 100)
		return
	var/mob/living/stung = target
	if(stung.mob_biotypes & MOB_ROBOTIC) // no venom argues with hydraulics
		return
	stung.adjust_staggered_up_to(VESTIGE_LASH_STAGGER, VESTIGE_LASH_STAGGER_MAX)

/**
 * The paralytic tier: two darts per cooldown (the pointed projectile base's
 * own charge machinery, clicking twice fires both, deactivating with one
 * banked part-refunds the cooldown), and a knockdown rider against targets
 * already winded. The threshold reads getStaminaLoss() in on_hit, which runs
 * BEFORE this dart's own damage is applied (bullet_act calls proj.on_hit
 * first, then the living target applies damage/effects, atom_act.dm 116,
 * living_defense.dm 94), so "already winded" honestly means damage carried
 * INTO this hit: dart one never floors a fresh target, dart two floors
 * whoever dart one softened. 1.5 seconds every 16 is a fold, not a chain.
 */
/datum/action/cooldown/spell/pointed/projectile/vestige_spit/neuro/paralytic
	name = "Paralytic Lash"
	desc = "Spit a pair of neurotoxin darts before it needs to recharge. A dart that hits someone already winded also floors them briefly. Needs a bare mouth."
	cooldown_time = VESTIGE_LASH_PARALYTIC_COOLDOWN
	projectile_amount = VESTIGE_LASH_PARALYTIC_VOLLEY
	projectile_type = /obj/projectile/vestige_neuro_lash/paralytic

/obj/projectile/vestige_neuro_lash/paralytic
	name = "paralytic lash"

/obj/projectile/vestige_neuro_lash/paralytic/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..() // parent applies the stagger (and skips robots/full blocks)
	if(!isliving(target) || blocked >= 100)
		return
	var/mob/living/stung = target
	if(stung.mob_biotypes & MOB_ROBOTIC)
		return
	if(stung.getStaminaLoss() < VESTIGE_LASH_FLOOR_THRESHOLD)
		return
	stung.Knockdown(VESTIGE_LASH_FLOOR_KNOCKDOWN)
	stung.visible_message(
		span_warning("[stung]'s legs fold under the sting!"),
		span_userdanger("The paralytic sting folds your legs out from under you!"),
	)

// ===== THE ARCHITECTURE =====

/**
 * The resin arts, rebuilt as a channelled pointed build-spell (the Reliquary's
 * Iron Refusal precedent, minus the rusted-floor prerequisite). Upstream's
 * builder (alien/make_structure/resin) is the same plasma-welded carbon
 * action; the STRUCTURES it builds are entirely self-contained (aliens.dm.
 * Real integrity, air blocking, the melee-quarter/burn-double armor quirk),
 * so those are built as-is and only the builder is replaced.
 *
 * The channel and every cancel live in before_cast (fork quirk: Activate()
 * ignores cast() return values, so a cast()-side cancel would still spend the
 * cooldown). Grief rails, each deliberate:
 * - open, non-space turfs only (upstream refuses space too); NOTHING is ever
 *   done to the turf itself. The wall is a structure standing on it
 * - dense works refuse tiles with someone else standing on them: no entombing
 *   (walling YOURSELF in is the house's oldest privilege, and is allowed)
 * - a standing-works cap, oldest-crumbles: one weaver can plug a corridor,
 *   not slowly resin an entire deck. The ledger lives on the spell; works
 *   outlive the spell (an upgrade replacing it starts a fresh ledger and
 *   abandons the old works where they stand. They are just structures).
 */
/datum/action/cooldown/spell/pointed/vestige_resin_weaver
	name = "Resin Weaving"
	desc = "Channel a few seconds over bare floor next to you to raise a resin wall or membrane. Blunt hits glance off resin, fire eats it. Only so many stand at once; the eldest crumbles for the newest."
	button_icon = 'icons/mob/actions/actions_xeno.dmi'
	button_icon_state = "alien_resin"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	sound = 'sound/effects/splat.ogg'
	cooldown_time = VESTIGE_RESIN_COOLDOWN
	spell_requirements = NONE
	cast_range = 1
	aim_assist = FALSE // this spell wants the FLOOR the crew is standing on, never the crew
	active_msg = "Your throat thickens with the old craft. Choose ground..."
	deactive_msg = "You swallow the craft back down."
	/// Seconds of conspicuous retching between choosing ground and the work standing
	var/channel_time = VESTIGE_RESIN_CHANNEL
	/// Standing works this weaver sustains before the eldest is reclaimed
	var/works_cap = VESTIGE_RESIN_CAP
	/// The shape chosen in before_cast, consumed by cast
	var/chosen_shape
	/// Guards the menu and channel until the original caster finishes.
	var/weaving = FALSE
	/// The works this weaver currently sustains, eldest first (pruned by deletion signals)
	var/list/standing_works = list()

/datum/action/cooldown/spell/pointed/vestige_resin_weaver/Destroy()
	standing_works.Cut() // the works themselves stand; only the ledger dies
	return ..()

/// name -> structure typepath. The architect tier appends the cradle.
/datum/action/cooldown/spell/pointed/vestige_resin_weaver/proc/get_shapes()
	return list(
		"resin wall" = /obj/structure/alien/resin/wall,
		"resin membrane" = /obj/structure/alien/resin/membrane,
	)

/datum/action/cooldown/spell/pointed/vestige_resin_weaver/is_valid_target(atom/cast_on)
	. = ..()
	if(!.)
		return FALSE
	if(!isopenturf(cast_on))
		cast_on.balloon_alert(owner, "needs bare floor!")
		return FALSE
	var/turf/open/ground = cast_on
	if(isspaceturf(ground))
		ground.balloon_alert(owner, "nothing to bind to!")
		return FALSE
	if(ground.is_blocked_turf(exclude_mobs = TRUE))
		ground.balloon_alert(owner, "no room!")
		return FALSE
	if((locate(/obj/structure/alien/resin) in ground) || (locate(/obj/structure/bed/nest) in ground))
		ground.balloon_alert(owner, "already resin-wrought!")
		return FALSE
	return TRUE

// The whole conversation happens here: shape choice, channel, re-validation,
// so any cancellation refunds the cast before the cooldown is ever paid
/datum/action/cooldown/spell/pointed/vestige_resin_weaver/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	if(weaving || !weave_check(owner))
		return . | SPELL_CANCEL_CAST
	weaving = TRUE
	var/prepared = prepare_weave(owner, cast_on)
	weaving = FALSE
	return . | prepared

/// Both sleeping operations belong to the body that started the work.
/datum/action/cooldown/spell/pointed/vestige_resin_weaver/proc/prepare_weave(mob/living/caster, turf/open/ground)
	chosen_shape = null
	var/shape_path = pick_shape() // sleeps on the radial
	if(!shape_path || !weave_check(caster) || !can_raise(ground, shape_path))
		return SPELL_CANCEL_CAST
	caster.visible_message(
		span_warning("[caster] hunches and begins working up a thick purple resin!"),
		span_noticealien("You work your throat around the old craft."),
	)
	playsound(caster, 'sound/mobs/non-humanoids/alien/alien_york.ogg', 60, TRUE)
	if(!do_after(caster, channel_time, target = ground, extra_checks = CALLBACK(src, PROC_REF(weave_check), caster)))
		return SPELL_CANCEL_CAST
	if(!weave_check(caster) || !can_raise(ground, shape_path))
		return SPELL_CANCEL_CAST
	chosen_shape = shape_path
	return NONE

/// Radial over the house's shapes, anchored on the weaver. Returns a structure typepath or null.
/datum/action/cooldown/spell/pointed/vestige_resin_weaver/proc/pick_shape()
	var/list/shapes = get_shapes()
	var/list/options = list()
	for(var/shape_name in shapes)
		var/obj/structure/shape_type = shapes[shape_name]
		options[shape_name] = image(icon = initial(shape_type.icon), icon_state = initial(shape_type.icon_state))
	var/choice = show_radial_menu(owner, owner, options, custom_check = CALLBACK(src, PROC_REF(weave_check), owner), tooltips = TRUE)
	if(!choice)
		return null
	return shapes[choice]

/// Menu/channel validity: the spell still exists and its owner is still up to this
/datum/action/cooldown/spell/pointed/vestige_resin_weaver/proc/weave_check(mob/living/weaver)
	return !QDELETED(src) && isliving(weaver) && !QDELETED(weaver) && weaver == owner && weaver.stat == CONSCIOUS && !weaver.incapacitated

/// Shape-aware placement check, run before AND after the channel
/datum/action/cooldown/spell/pointed/vestige_resin_weaver/proc/can_raise(turf/open/ground, obj/structure/shape_path)
	if(QDELETED(ground) || !isopenturf(ground) || isspaceturf(ground))
		return FALSE
	var/turf/weaver_turf = get_turf(owner)
	if(!weaver_turf || weaver_turf.z != ground.z || get_dist(weaver_turf, ground) > cast_range) // the weaver may have wandered mid-channel
		ground.balloon_alert(owner, "too far!")
		return FALSE
	if(ground.is_blocked_turf(exclude_mobs = TRUE))
		ground.balloon_alert(owner, "no room!")
		return FALSE
	if((locate(/obj/structure/alien/resin) in ground) || (locate(/obj/structure/bed/nest) in ground))
		ground.balloon_alert(owner, "already resin-wrought!")
		return FALSE
	if(initial(shape_path.density)) // no entombing the standing, except, traditionally, yourself
		for(var/mob/living/bystander in ground)
			if(bystander != owner)
				ground.balloon_alert(owner, "someone is standing there!")
				return FALSE
	return TRUE

/datum/action/cooldown/spell/pointed/vestige_resin_weaver/cast(atom/cast_on)
	. = ..()
	if(!chosen_shape) // belt and suspenders; before_cast always sets it on the success path
		return
	var/turf/ground = get_turf(cast_on)
	var/obj/structure/work = new chosen_shape(ground)
	chosen_shape = null
	owner.visible_message(
		span_warning("[owner] vomits up a sheet of resin, and it stands: [work]!"),
		span_noticealien("The work stands."),
	)
	enroll(work)

/// Books a work into the ledger and reclaims the eldest past the cap
/datum/action/cooldown/spell/pointed/vestige_resin_weaver/proc/enroll(obj/structure/work)
	standing_works += work
	RegisterSignal(work, COMSIG_QDELETING, PROC_REF(on_work_lost))
	while(length(standing_works) > works_cap)
		var/obj/structure/eldest = standing_works[1]
		standing_works -= eldest // pruned here AND by on_work_lost (list -= tolerates both), so the loop can never spin
		if(QDELETED(eldest))
			continue
		eldest.visible_message(span_warning("[eldest] sloughs apart into inert slurry."))
		playsound(eldest, 'sound/effects/splat.ogg', 50, TRUE)
		qdel(eldest)

/datum/action/cooldown/spell/pointed/vestige_resin_weaver/proc/on_work_lost(obj/structure/work)
	SIGNAL_HANDLER
	standing_works -= work

// --- The architect ---

/datum/action/cooldown/spell/pointed/vestige_resin_weaver/architect
	name = "Brood Architecture"
	desc = "Channel briefly over bare floor next to you to raise a resin wall, a membrane, or a cradle that slowly heals whoever rests in it."
	cooldown_time = VESTIGE_RESIN_ARCHITECT_COOLDOWN
	channel_time = VESTIGE_RESIN_ARCHITECT_CHANNEL
	works_cap = VESTIGE_RESIN_ARCHITECT_CAP

/datum/action/cooldown/spell/pointed/vestige_resin_weaver/architect/get_shapes()
	. = ..()
	.["brood cradle"] = /obj/structure/bed/nest/vestige_cradle

/**
 * The nursery art. The upstream alien nest (alien_nest.dm) is welded shut for
 * a plain human in BOTH directions, user_buckle_mob demands the buckler have
 * a plasma vessel organ and the occupant lack one, and a trapped occupant
 * without a vessel faces a 100-second solo struggle, so both verbs are
 * reimplemented for what this cradle actually is: a willing berth, not a
 * restraint. Only you may lay yourself into it (drag yourself onto it), and
 * ANYONE gets out of it instantly (resist, or a click from a helper), no
 * trapping lane exists. The chassis' TRAIT_HANDS_BLOCKED (post_buckle_mob)
 * is kept deliberately: swaddled means helpless, which is the price of the
 * mending. Heals only the living; the dead get nothing but the swaddling.
 */
/obj/structure/bed/nest/vestige_cradle
	name = "brood cradle"
	desc = "A nest of pale resin woven inward in tight rings. It looks unsettlingly comfortable."

/obj/structure/bed/nest/vestige_cradle/examine(mob/user)
	. = ..()
	. += span_notice("Drag yourself onto it to be taken in, it accepts no one unwilling. While you rest, it swaddles your hands and knits [VESTIGE_RESIN_CRADLE_HEAL] brute, [VESTIGE_RESIN_CRADLE_HEAL] burn and [VESTIGE_RESIN_CRADLE_STAMINA] fatigue a second. Resist to be released at once.")

/obj/structure/bed/nest/vestige_cradle/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/bed/nest/vestige_cradle/user_buckle_mob(mob/living/occupant, mob/user, check_loc = TRUE)
	// Deliberately NOT calling the nest parent: its plasma-vessel gates would
	// refuse a plain human on both sides. Willing self-swaddling only.
	if(occupant != user)
		balloon_alert(user, "it takes only the willing!")
		return
	if(!istype(occupant) || get_dist(src, user) > 1 || occupant.loc != loc || user.incapacitated || occupant.buckled)
		return
	if(has_buckled_mobs())
		balloon_alert(user, "occupied!")
		return
	if(!buckle_mob(occupant))
		return
	occupant.visible_message(
		span_notice("[occupant] lies back into [src], and the resin folds over [occupant.p_them()]."),
		span_notice("You lie back, and the cradle takes you. Your hands are swaddled useless; the mending begins."),
	)

/obj/structure/bed/nest/vestige_cradle/user_unbuckle_mob(mob/living/occupant, mob/living/hero)
	// No struggle timer, no plasma gate: a willing berth releases at a word
	if(!length(buckled_mobs))
		return
	unbuckle_mob(occupant)
	add_fingerprint(hero)
	occupant.visible_message(
		span_notice("[src] parts and lets [occupant] up without argument."),
		span_notice("The cradle parts and lets you up without argument."),
	)

/obj/structure/bed/nest/vestige_cradle/post_buckle_mob(mob/living/occupant)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/structure/bed/nest/vestige_cradle/post_unbuckle_mob(mob/living/occupant)
	. = ..()
	STOP_PROCESSING(SSobj, src)

/obj/structure/bed/nest/vestige_cradle/process(seconds_per_tick)
	if(!has_buckled_mobs())
		return
	for(var/mob/living/resting as anything in buckled_mobs)
		if(resting.stat == DEAD)
			continue
		resting.heal_overall_damage(
			brute = VESTIGE_RESIN_CRADLE_HEAL * seconds_per_tick,
			burn = VESTIGE_RESIN_CRADLE_HEAL * seconds_per_tick,
			required_bodytype = BODYTYPE_ORGANIC,
		)
		resting.adjustStaminaLoss(-VESTIGE_RESIN_CRADLE_STAMINA * seconds_per_tick)
		if(SPT_PROB(3, seconds_per_tick))
			to_chat(resting, span_notice("The cradle shifts around you, settling closer."))

#undef VESTIGE_SPIT_COOLDOWN
#undef VESTIGE_SPIT_MOB_BURN
#undef VESTIGE_SPIT_ACID_POWER
#undef VESTIGE_SPIT_ACID_VOLUME
#undef VESTIGE_SPIT_VITRIOL_COOLDOWN
#undef VESTIGE_SPIT_VITRIOL_MOB_BURN
#undef VESTIGE_SPIT_VITRIOL_ACID_POWER
#undef VESTIGE_SPIT_VITRIOL_ACID_VOLUME
#undef VESTIGE_SPIT_VITRIOL_IMPACT
#undef VESTIGE_SPIT_VITRIOL_IMPACT_AP
#undef VESTIGE_SPIT_RESIDUE_LIFETIME
#undef VESTIGE_SPIT_RESIDUE_BURN
#undef VESTIGE_LASH_COOLDOWN
#undef VESTIGE_LASH_STAMINA
#undef VESTIGE_LASH_AP
#undef VESTIGE_LASH_SLUR
#undef VESTIGE_LASH_STAGGER
#undef VESTIGE_LASH_STAGGER_MAX
#undef VESTIGE_LASH_EYEBLUR
#undef VESTIGE_LASH_PARALYTIC_COOLDOWN
#undef VESTIGE_LASH_PARALYTIC_VOLLEY
#undef VESTIGE_LASH_FLOOR_THRESHOLD
#undef VESTIGE_LASH_FLOOR_KNOCKDOWN
#undef VESTIGE_RESIN_CHANNEL
#undef VESTIGE_RESIN_COOLDOWN
#undef VESTIGE_RESIN_CAP
#undef VESTIGE_RESIN_ARCHITECT_CHANNEL
#undef VESTIGE_RESIN_ARCHITECT_COOLDOWN
#undef VESTIGE_RESIN_ARCHITECT_CAP
#undef VESTIGE_RESIN_CRADLE_HEAL
#undef VESTIGE_RESIN_CRADLE_STAMINA
