/**
 * # The Shambles: slaughter demon vestige
 *
 * A provisions barge: the old word for a slaughterhouse was a "shambles",
 * and this ship earned the name twice. Her drive died between ports with the
 * holds packed and the freezers failing, and the crew, starving in a larder,
 * summoned something to "help with the butchering". It helped. Quickly,
 * professionally, with evident pride in the work. Then it stayed for the
 * meal, and the meal became a banquet, and the banquet ran so long that the
 * spilled blood dried on the deck, and a thing that travels through blood
 * cannot leave through dried blood. The patron is the Stain: a slaughter
 * demon set halfway out of the great rust-brown mark like a fly in amber,
 * convivial, dreadful, and genuinely delighted to have an apprentice at last.
 * It laughs. That is the horror; it is not laughing AT anyone.
 *
 * The trials are a butcher's apprenticeship, and every one demands active
 * play at every moment: the Red Road (positioning, fell wild things with the
 * loaned knife while YOUR boots stand in wet blood), the Trapdoor Feast
 * (stalking and timing, a lesser, lurk-capped blood crawl, credit only for a
 * strike within three seconds of rising onto a beast mid-stride), and Set the
 * Table (logistics under pressure: every kill onto the loaned gambrel's
 * hooks before it cools, while the hunt continues). The boons, the crawl,
 * the claws, the mirth, the scent. Live in the sibling boons file
 * (theme_demon_boons.dm); this file only points the patron at them.
 *
 * Design note: the demon's bloodcrawl-consume stays CUT per the ability
 * catalog. Nothing in this file (and nothing in the boon pool) eats victims;
 * the pact pays for hunting beasts, never people.
 */

// Trial tuning (file-local, #undef at bottom). Trial descs quote these
// numbers literally, keep them in sync.
/// Wild things the Red Road demands felled with wet blood underfoot
#define VESTIGE_ROAD_KILLS_NEEDED 3
/// Pounces the Trapdoor Feast demands landed out of the blood
#define VESTIGE_TRAPDOOR_AMBUSHES_NEEDED 3
/// Most pounces any single beast can credit, after that it has learned the floor
#define VESTIGE_TRAPDOOR_STRIKES_PER_PREY 2
/// How long after rising a strike still counts as a pounce
#define VESTIGE_TRAPDOOR_STRIKE_WINDOW (3 SECONDS)
/// How long the blood tolerates a lurker before spitting them back out
#define VESTIGE_TRAPDOOR_LURK_MAX (10 SECONDS)
/// The trapdoor crawl's cooldown: paid on the dive and again on the rise
#define VESTIGE_TRAPDOOR_COOLDOWN (6 SECONDS)
/// Brute the dive costs when there is no pool in reach and the door must come out of your palm
#define VESTIGE_TRAPDOOR_TOLL 5
/// How far around the surfacing lurker we memorize positions, to judge "mid-stride" honestly
#define VESTIGE_TRAPDOOR_SNAPSHOT_RANGE 9
/// Fresh carcasses Set the Table demands hung on the gambrel
#define VESTIGE_TABLE_SETTINGS 3
/// How long after death a carcass still counts as fresh enough to seat
#define VESTIGE_TABLE_FRESHNESS (45 SECONDS)
/// How long hooking a carcass up takes
#define VESTIGE_TABLE_HANG_TIME (1.5 SECONDS)
/// Beat between the final credit and completion. Keeps complete() (which qdels
/// the trial AND its kit) out of the kit's own call stack (see conclude())
#define VESTIGE_SHAMBLES_CONCLUDE_DELAY (0.5 SECONDS)

/**
 * TRUE when a mob is honest work for the Stain's lessons: wild fauna
 * (basic-mob or simple-animal stock), not a person, not a morsel, not a
 * pacifist, not the butcher's own pack, and not something under godmode
 * (patrons, trader mobs). All three trials gate their credit through this.
 * The pact pays for hunting beasts, never people. Deliberately NOT the
 * dragon's vestige_is_wild_quarry: themes keep their own gates so one theme's
 * balance pass can't silently retune another's.
 *
 * No stat check on purpose, the knife judges the living, the gambrel judges
 * the dead, and each caller applies its own.
 */
/proc/vestige_is_shambles_quarry(mob/living/beast, mob/living/butcher)
	if(!isliving(beast) || beast == butcher || ishuman(beast))
		return FALSE
	if(!isanimal_or_basicmob(beast) || beast.mind || beast.client)
		return FALSE
	if(beast.mob_size < MOB_SIZE_SMALL) // no mice, no morsels. The Stain wants carcasses worth hanging
		return FALSE
	if(HAS_TRAIT(beast, TRAIT_PACIFISM) || HAS_TRAIT(beast, TRAIT_GODMODE))
		return FALSE
	if(butcher && beast.faction_check_atom(butcher)) // your own pack is not stock
		return FALSE
	return TRUE

// ===== PATRON =====

/mob/living/basic/vestige_patron/stain
	name = "the Stain"
	desc = "A slaughter demon, or most of one. It's stuck waist-deep in a rust-brown spill that dried hard as lacquer, and it's smiling the way a shopkeeper smiles at the first customer of the day."
	// The slaughter demon's own sprite (verified in demon.dm / demon_subtypes.dm), worn like old work clothes
	icon = 'icons/mob/simple/demon.dmi'
	icon_state = "slaughter_demon"
	gender = NEUTER
	mob_biotypes = MOB_SPECIAL
	speak_emote = list("chuckles", "rumbles", "gurgles")
	appearance_tint = "#9c4a2f" // dried rust, clean through
	alpha = 205
	trial_types = list(
		/datum/vestige_trial/red_road,
		/datum/vestige_trial/trapdoor_feast,
		/datum/vestige_trial/set_the_table,
	)
	// Contract list: these boons are defined in the sibling boons file
	boon_types = list(
		/datum/vestige_boon/spell/blood_crawl,
		/datum/vestige_boon/spell/blood_crawl/red_undertow,
		/datum/vestige_boon/spell/rending_claws,
		/datum/vestige_boon/spell/rending_claws/butchers_rhythm,
		/datum/vestige_boon/spell/slaughters_mirth,
		/datum/vestige_boon/spell/scent_of_blood,
	)
	idle_lines = list(
		"They asked for help with the butchering! Ha! I have never once declined an invitation, and that one was practically engraved.",
		"The crew? Dressed, hung, and portioned, every one, and not a cut wasted. Say what you like about how the evening ended. The WORK was clean.",
		"I stayed for the meal. The meal became a banquet, the banquet became (ha!) a permanent arrangement. And the floor dried while I was still complimenting the cook.",
		"A thing that travels by blood cannot leave by dried blood, apprentice. Write that down. On something. IN something.",
		"You hold that knife like it owes you money. It owes you nothing. You owe IT a steady hand. We will fix this together, you and I.",
		"The old shops called this a shambles: the wet floor, the gutter, the hooks, the honest work. The whole ship is a shambles now. I find that very tidy.",
		"Do you know the difference between slaughter and butchery? Patience. One of us in this room had none, and look where it. HA! Look where it got me.",
	)
	accept_line = "Excellent! Apron on, chin up. The floor teaches, the knife grades, and I laugh either way."
	busy_line = "You're still carrying another kitchen's order, apprentice. Finish that plate or scrape it."
	fulfilled_line = "That cut is made and hung. Even I never butchered the same beast twice. Ha! Well. Not on purpose."
	renounce_line = "Hanging up the apron? Fine, fine. The floor was too wet for you. It gets everyone eventually, usually by the ankles."
	claim_line = "Wages before work, that's shop law, older than me. Take what you're owed. I insist. I INSIST."
	exhausted_line = "The larder's bare and the hooks are empty. You've carried off my whole trade, one parcel at a time. I'd applaud, but the stain has my hands."
	remember_line = "Back from the walk-in, are we? The cold suits you. Your tools are fine, I oiled them myself. A good shop never loses an apprentice's kit. Only, occasionally, the apprentice."

// ===== THE RED ROAD =====

/**
 * The positioning trial: a butcher works on a wet floor. The loaned knife
 * paints, every honest cut into wild quarry guarantees a wet pool under the
 * beast, its own blood where the engine gives it any and the knife's tithe
 * where it doesn't, but the credit is in the FEET: only a killing blow
 * landed by this knife while the butcher's own boots stand in wet, undried
 * blood counts. Pools stay where the fight spilled them and the fight keeps
 * moving, so every kill is a small dance of wound, herd, step, finish.
 * Attribution is synchronous and honest: the knife checks whether its own
 * swing was the one that ended the beast, so turrets, friends and somebody
 * else's crossfire pay nothing.
 */
/datum/vestige_trial/red_road
	name = "The Red Road"
	// Keep the count in sync with VESTIGE_ROAD_KILLS_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "First lesson is the floor. Take the knife. I dressed the edge myself, it spills generously. Cut your beast open so the floor gets wet, then stand in the wet and land the killing blow from there. Wet blood under your boots, or it doesn't count. Three wild things brought down that way, and no beast counts twice however many times somebody props it back up. Ha!"
	/// The loaned knife, while it survives. Reclaimed the moment the pact ends.
	var/obj/item/vestige_flensing_knife/knife
	/// Beasts already walked down the road (weakref -> TRUE). A revived and re-felled beast is still one meal
	var/list/felled = list()
	/// Guards the deferred completion beat (see conclude)
	var/concluding = FALSE

/datum/vestige_trial/red_road/on_accepted(mob/living/user)
	var/obj/item/vestige_flensing_knife/loaned = new(get_turf(user))
	loaned.bound_mind = owner
	knife = hand_over(user, loaned)
	to_chat(user, span_notice("The knife settles into your hand like it has been waiting there. The edge is unreasonably sharp."))

/datum/vestige_trial/red_road/Destroy()
	QDEL_NULL(knife)
	return ..()

/datum/vestige_trial/red_road/get_progress_text()
	if(!knife || QDELETED(knife))
		return "The knife is lost. Restart the trial from your pact tracker for a fresh knife."
	return "You have felled [length(felled)] of [VESTIGE_ROAD_KILLS_NEEDED] wild things with wet blood underfoot."

/// Credits a kill made standing in the red. Returns FALSE if this beast already walked the road.
/datum/vestige_trial/red_road/proc/fell(mob/living/prey)
	var/datum/weakref/key = WEAKREF(prey)
	if(felled[key])
		return FALSE
	felled[key] = TRUE
	refresh_tracker()
	if(length(felled) >= VESTIGE_ROAD_KILLS_NEEDED && !concluding)
		concluding = TRUE
		// Deferred: complete() qdels the trial, and the trial's Destroy qdels the
		// knife, which is partway through its own attack() right now
		addtimer(CALLBACK(src, PROC_REF(conclude)), VESTIGE_SHAMBLES_CONCLUDE_DELAY)
	return TRUE

/// The deferred completion beat. The pact may have been renounced inside the delay; complete() handles the rest.
/datum/vestige_trial/red_road/proc/conclude()
	if(!QDELETED(src))
		complete()

/**
 * The flensing knife: a butcher's cleaver on loan from something that took
 * butchery very seriously. Ordinary cleaver stats. The trial is in where you
 * stand, not what you swing, plus two jobs of its own: it PAINTS (every cut
 * into wild quarry leaves a wet pool under the beast, so the road can always
 * be laid even through bloodless-as-the-engine-reckons-it fauna), and it
 * JUDGES (a killing blow it lands itself, with wet blood under its wielder's
 * boots, credits the wielder's live Red Road, resolved fresh at that moment,
 * never stored). In anyone else's hand it is just a very good cleaver.
 */
/obj/item/vestige_flensing_knife
	name = "flensing knife"
	desc = "A cleaver of demon-dark iron, balanced well enough that it does most of the work for you. The groove down the blade is stained a deep brown that no amount of scrubbing touches."
	icon = 'icons/obj/weapons/khopesh.dmi'
	icon_state = "render"
	// The "ordinary cleaver stats" the docstring promises, spelled out. This hangs off
	// bare /obj/item (it keeps its own sprite and wants none of /obj/item/knife's tool
	// behaviour), and /obj/item defaults to force = 0 and sharpness = NONE - so the
	// loaned knife could wound nothing and kill nothing, and the Red Road, whose only
	// credit is a killing blow from THIS knife, could never advance past zero. Numbers
	// are /obj/item/knife/butcher's, verbatim.
	inhand_icon_state = "butch"
	lefthand_file = 'icons/mob/inhands/equipment/kitchen_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/kitchen_righthand.dmi'
	worn_icon_state = "butch"
	icon_angle = -45
	obj_flags = CONDUCTS_ELECTRICITY
	force = 15
	throwforce = 10
	throw_speed = 3
	throw_range = 6
	demolition_mod = 0.75
	w_class = WEIGHT_CLASS_NORMAL
	hitsound = 'sound/items/weapons/bladeslice.ogg'
	attack_verb_continuous = list("slices", "dices", "chops", "flenses", "unseams")
	attack_verb_simple = list("slice", "dice", "chop", "flense", "unseam")
	sharpness = SHARP_EDGED
	wound_bonus = 15
	exposed_wound_bonus = 15
	armor_type = /datum/armor/item_knife
	/// Mind of the supplicant this knife was loaned to, Destroy-time bookkeeping only; credit resolves the WIELDER at swing time
	var/datum/mind/bound_mind

/obj/item/vestige_flensing_knife/Destroy()
	var/datum/vestige_trial/red_road/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.knife == src)
		trial.knife = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/item/vestige_flensing_knife/examine(mob/user)
	. = ..()
	. += span_notice("Use in hand to check your footing. Every cut into a wild thing wets the floor beneath it. Only a killing blow from this knife counts for the Red Road, and only if your own boots are standing in wet blood when it lands. [VESTIGE_ROAD_KILLS_NEEDED] wild things, no beast twice.")

/obj/item/vestige_flensing_knife/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	var/wet = FALSE
	for(var/obj/effect/decal/cleanable/blood/pool in get_turf(user))
		if(!pool.dried)
			wet = TRUE
	balloon_alert(user, wet ? "wet blood underfoot: killing blow ready" : "dry footing: step into wet blood first")
	return TRUE

/obj/item/vestige_flensing_knife/attack(mob/living/prey, mob/living/butcher, list/modifiers, list/attack_modifiers)
	var/was_alive = isliving(prey) && prey.stat != DEAD
	. = ..() // the swing itself, damage (and any death) happens in here, synchronously
	if(!was_alive || !isliving(prey) || !isliving(butcher))
		return
	var/datum/vestige_trial/red_road/trial = butcher.mind?.active_vestige_trial
	if(!istype(trial))
		return
	if(!vestige_is_shambles_quarry(prey, butcher))
		return
	// Every honest cut paints, including the last one, so the kill itself
	// keeps laying road for the next
	paint_the_road(prey)
	if(prey.stat != DEAD)
		return
	// The beast went from alive to dead inside OUR attack call: the killing
	// blow was this knife's. Now the only question is where the boots are.
	var/turf/underfoot = get_turf(butcher)
	var/obj/effect/decal/cleanable/blood/road
	for(var/obj/effect/decal/cleanable/blood/pool in underfoot)
		if(!pool.dried)
			road = pool
			break
	if(!road)
		to_chat(butcher, span_warning("[prey] falls on a dry floor. Somewhere, a tongue clicks twice. The killing blow only counts with wet blood under your boots, apprentice."))
		return
	// fell() may schedule completion (which later deletes the trial), nothing touches trial after this
	if(trial.fell(prey))
		to_chat(butcher, span_notice("[prey] drops with your boots planted in the red. From nowhere in particular: two slow, delighted claps."))
		playsound(butcher, 'sound/effects/magic/demon_attack1.ogg', 20, TRUE)
	else
		to_chat(butcher, span_warning("[prey] has already been served once. Go and find something new."))

/**
 * Guarantees a wet pool under the beast: its own blood first (species-correct,
 * honest forensics), and the knife's tithe when the engine calls the beast
 * bloodless, the trial cannot hinge on which fauna happen to have plumbing.
 * Never stacks: an existing wet pool on the turf is left to do its job.
 */
/obj/item/vestige_flensing_knife/proc/paint_the_road(mob/living/prey)
	var/turf/floor = get_turf(prey)
	if(!floor)
		return
	prey.add_splatter_floor(floor)
	for(var/obj/effect/decal/cleanable/blood/pool in floor)
		if(!pool.dried)
			return
	new /obj/effect/decal/cleanable/blood(floor)

// ===== THE TRAPDOOR FEAST =====

/**
 * The stalking trial: the pact loans a lesser, trial-only blood crawl and
 * pays only for AMBUSHES, the first strike landed within three seconds of
 * rising, on a wild beast that was moving when the strike came. "Moving" is
 * judged from positions at the dive and at surfacing. Movement during the
 * dive or before the strike counts; standing still throughout does not. One credit per rise, capped
 * per beast, so three credits means three separate dives, stalks and reads of a
 * moving target.
 *
 * The loaned crawl is the apprentice's cut of the boon, restricted three
 * ways: it lives exactly as long as the pact (qdeled in trial Destroy, which
 * also force-ejects a mid-lurk lurker via the jaunt machinery's own Remove);
 * the blood tolerates ten seconds of lurking before spitting the lurker back
 * out (and charging the cooldown for the ride); and it refuses to cast at all
 * without a live Trapdoor Feast on the caster's mind. In exchange it keeps
 * your hands (the trial is the strike, not the swim), rises instantly (an
 * ambush that gargles first is not an ambush), and, because a hunting ground
 * rarely comes pre-bloodied. A dive with no pool in reach cuts its own door
 * out of the lurker's palm for a small brute toll. No consume mechanics
 * exist on this or any variant here: that stays cut.
 */
/datum/vestige_trial/trapdoor_feast
	name = "The Trapdoor Feast"
	// Keep the counts in sync with VESTIGE_TRAPDOOR_AMBUSHES_NEEDED /
	// _STRIKES_PER_PREY / _STRIKE_WINDOW / _LURK_MAX / _TOLL
	// (initial values must be constant, so no define interpolation here)
	desc = "Second lesson is the pounce. I'll lend you the crawl, the apprentice's version of it. Sink into wet blood and the floor is yours for ten seconds before it spits you back out. No pool in reach and the door comes out of your own palm, five brute, shop price. Come up under something that is MOVING and land your first strike within three seconds of surfacing. Lure it into a chase before diving; its movement during your dive is remembered, even if it stops beside the exit. Three pounces, and no beast counts more than twice. After that it knows where the floor keeps its doors. Ha!"
	/// The loaned crawl. Mind-targeted like the boon spells; reclaimed (and any lurker ejected) the moment the pact ends.
	var/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/crawl
	/// Pounces landed so far
	var/ambushes = 0
	/// Pounces credited per beast (weakref -> count), capping repeat lessons
	var/list/strikes_per_prey = list()
	/// Guards the deferred completion beat (see conclude)
	var/concluding = FALSE

/datum/vestige_trial/trapdoor_feast/on_accepted(mob/living/user)
	crawl = new(owner) // mind-targeted, same as granted boon spells, it rides across bodies with the pact
	crawl.Grant(user)
	to_chat(user, span_notice("Something teaches your bones the trick of it, laughing gently the whole time. A red floor is a door."))

/datum/vestige_trial/trapdoor_feast/Destroy()
	// Action Destroy runs Remove, and the jaunt machinery's Remove force-exits
	// a live jaunt, a renounced lurker surfaces instead of stranding
	QDEL_NULL(crawl)
	return ..()

/datum/vestige_trial/trapdoor_feast/get_progress_text()
	return "You have pounced on [ambushes] of [VESTIGE_TRAPDOOR_AMBUSHES_NEEDED] moving targets."

/// Credits a pounce. May schedule completion. Returns FALSE if this beast has been surprised out.
/datum/vestige_trial/trapdoor_feast/proc/pounce(mob/living/prey)
	var/datum/weakref/key = WEAKREF(prey)
	var/prior = strikes_per_prey[key] || 0
	if(prior >= VESTIGE_TRAPDOOR_STRIKES_PER_PREY)
		return FALSE
	strikes_per_prey[key] = prior + 1
	ambushes++
	refresh_tracker()
	if(ambushes >= VESTIGE_TRAPDOOR_AMBUSHES_NEEDED && !concluding)
		concluding = TRUE
		// Deferred: complete() qdels the trial, whose Destroy qdels the crawl,
		// which is partway through its own strike signal handler right now
		addtimer(CALLBACK(src, PROC_REF(conclude)), VESTIGE_SHAMBLES_CONCLUDE_DELAY)
	return TRUE

/// The deferred completion beat. The pact may have been renounced inside the delay; complete() handles the rest.
/datum/vestige_trial/trapdoor_feast/proc/conclude()
	if(!QDELETED(src))
		complete()

/**
 * The trapdoor crawl: upstream's plain bloodcrawl (NOT the slaughter demon's.
 * The consume machinery stays cut) with the trial's restrictions bolted on.
 * All the pounce-judging state lives here on the action, kit-side and
 * ephemeral, exactly like the ember-jaw's marks: the trial datum on the mind
 * keeps only the score.
 *
 * Fork quirk note: this fork's spell Activate() ignores cast() return values,
 * so every cancel here routes through can_cast_spell (checked before
 * activation, no side effects) or before_cast (cast-time, may have side
 * effects, honored SPELL_CANCEL_CAST), never through cast() itself.
 */
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor
	name = "Trapdoor Crawl"
	// Keep the quoted numbers in sync with VESTIGE_TRAPDOOR_LURK_MAX / VESTIGE_TRAPDOOR_TOLL
	// (initial values must be constant, so no define interpolation here)
	desc = "Sink into wet blood and travel beneath the floor for up to 10 seconds before the blood spits you back out. With no pool in reach, the dive cuts its own door out of your palm for 5 brute. It only works while the Trapdoor Feast is running."
	cooldown_time = VESTIGE_TRAPDOOR_COOLDOWN
	exit_blood_time = 0 SECONDS // an ambush that bubbles and gargles first is not an ambush
	equip_blood_hands = FALSE // the knife rises with you. The trial is the strike, not the swim
	/// Timer for the blood's patience running out mid-lurk
	var/lurk_timer
	/// When we last surfaced (0 = never), the strike window's anchor
	var/emerged_at = 0
	/// Whether this rise has already paid out, one pounce per surfacing, however fast you swing
	var/credited_this_rise = FALSE
	/// Where every living thing nearby stood at the instant of surfacing (weakref -> turf), the "mid-stride" evidence
	var/list/positions_at_rise
	/// Locations seen at the dive, so a quarry that reaches the exit and stops can still be ambushed.
	var/list/positions_at_dive

/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/Destroy()
	deltimer(lurk_timer)
	var/datum/mind/mind = target
	if(istype(mind))
		var/datum/vestige_trial/trapdoor_feast/trial = mind.active_vestige_trial
		if(istype(trial) && trial.crawl == src)
			trial.crawl = null
			trial.refresh_tracker()
	return ..()

// The strike-watching signals ride Grant/Remove, so the action's own
// body-transfer machinery keeps them on whatever body the mind wears
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/Grant(mob/grant_to)
	. = ..()
	RegisterSignal(grant_to, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_armed_strike))
	RegisterSignal(grant_to, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_strike))

/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/Remove(mob/living/remove_from)
	UnregisterSignal(remove_from, list(COMSIG_MOB_ITEM_ATTACK, COMSIG_LIVING_UNARMED_ATTACK))
	return ..()

/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE
	// Belt and suspenders: the crawl is qdeled with the pact, but resolve the
	// wielder's mind at interaction time anyway, the kit-item rule
	var/datum/vestige_trial/trapdoor_feast/trial = owner.mind?.active_vestige_trial
	if(istype(trial))
		return TRUE
	if(feedback)
		to_chat(owner, span_warning("The trapdoor only opens for a standing pact, and yours has ended."))
	return FALSE

/// The parent's finder, kept honest: a real, crawlable pool within reach, or null
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/proc/find_wet_door(turf/origin)
	for(var/obj/effect/decal/cleanable/pool in range(blood_radius, origin))
		if(is_valid_blood_destination(origin, pool))
			return pool
	return null

/**
 * A lurker above the floor can ALWAYS dive: when no pool waits, before_cast
 * cuts a door out of their own palm. This override returns a truthy sentinel
 * (src) in that case so the parent's can_cast_spell agrees the dive is
 * possible, with no side effects, because this proc runs on every movement
 * update. The sentinel never reaches do_bloodcrawl: before_cast guarantees a
 * real pool exists before the parent's cast() goes looking for one.
 */
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/find_nearby_blood(turf/origin)
	. = find_wet_door(origin)
	if(.)
		return
	if(owner && !is_jaunting(owner))
		return src

/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	var/mob/living/lurker = cast_on
	if(!isliving(lurker) || is_jaunting(lurker))
		return // rising: the parent's path, and can_cast_spell already demanded blood to rise through
	if(find_wet_door(get_turf(lurker)))
		return // a door is already waiting
	if(!cut_own_door(lurker))
		return . | SPELL_CANCEL_CAST // nullspace and stranger things, no door, no dive, no cooldown

/// The toll: no pool in reach, so the lurker's own palm paints one. Returns the door, or null if there is nowhere to put it.
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/proc/cut_own_door(mob/living/lurker)
	var/turf/floor = get_turf(lurker)
	if(!floor)
		return null
	lurker.visible_message(
		span_warning("[lurker] draws a palm along an edge and shakes the price onto the floor."),
		span_notice("No pool in reach, so the door comes out of you. [VESTIGE_TRAPDOOR_TOLL] brute, shop price."),
	)
	lurker.adjustBruteLoss(VESTIGE_TRAPDOOR_TOLL)
	// The lurker's own blood where the engine gives them any...
	lurker.add_splatter_floor(floor)
	var/obj/effect/decal/cleanable/door = find_wet_door(floor)
	if(!door)
		// ...and the Stain lends the ink to the bloodless (ethereals, odd species)
		door = new /obj/effect/decal/cleanable/blood(floor)
	return door

/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/try_enter_jaunt(obj/effect/decal/cleanable/blood, mob/living/jaunter, forced = FALSE)
	. = ..()
	if(!.)
		return
	positions_at_dive = list()
	for(var/mob/living/quarry in range(VESTIGE_TRAPDOOR_SNAPSHOT_RANGE, jaunter))
		if(vestige_is_shambles_quarry(quarry, jaunter) && vestige_loom_hunted_prey(quarry))
			positions_at_dive[WEAKREF(quarry)] = get_turf(quarry)
	deltimer(lurk_timer)
	// The clock rides the timer subsystem, not the holder, a renounced pact's
	// Destroy deltimers it, and the jaunt machinery ejects the lurker itself
	lurk_timer = addtimer(CALLBACK(src, PROC_REF(spit_out), jaunter), VESTIGE_TRAPDOOR_LURK_MAX, TIMER_STOPPABLE)
	to_chat(jaunter, span_notice("The red closes over you. [VESTIGE_TRAPDOOR_LURK_MAX / 10] seconds, apprentice, then it puts you back."))

/**
 * Any exit (voluntary rise, the clock, a renounce, a stat change) lands
 * here via the jaunt machinery's eject signal. Stamp the ambush window open
 * and memorize where everything nearby is standing, so "mid-stride" can be
 * judged against evidence instead of vibes.
 */
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/on_jaunt_exited(obj/effect/dummy/phased_mob/jaunt, mob/living/unjaunter)
	. = ..()
	deltimer(lurk_timer)
	lurk_timer = null
	emerged_at = world.time
	credited_this_rise = FALSE
	positions_at_rise = list()
	for(var/mob/living/bystander in range(VESTIGE_TRAPDOOR_SNAPSHOT_RANGE, unjaunter))
		positions_at_rise[WEAKREF(bystander)] = get_turf(bystander)
	if(istype(unjaunter.mind?.active_vestige_trial, /datum/vestige_trial/trapdoor_feast))
		to_chat(unjaunter, span_boldnotice("AMBUSH ARMED: strike a moving quarry within three seconds. Your held weapon stays in hand."))
		unjaunter.balloon_alert(unjaunter, "ambush armed: three seconds!")

/// The blood's patience runs out: eject the lurker wherever they are, and charge the cooldown for the ride
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/proc/spit_out(mob/living/lurker)
	lurk_timer = null
	if(QDELETED(src) || QDELETED(lurker) || !is_jaunting(lurker))
		return
	var/obj/effect/dummy/phased_mob/burrow = lurker.loc
	// Don't strand them inside a wall they were phasing through, walk the
	// holder to the nearest open ground first
	var/turf/spot = find_spit_spot(burrow)
	if(spot && spot != get_turf(burrow))
		burrow.forceMove(spot)
	exit_jaunt(lurker) // fires the eject signal -> on_jaunt_exited handles the bookkeeping
	StartCooldown()
	lurker.visible_message(
		span_warning("The floor heaves, and spits [lurker] back out!"),
		span_warning("The blood spits you back out."),
	)

/// Nearest open turf to eject onto: the holder's own, else the closest unblocked within 2. Falls back to wherever (the upstream machinery accepts worse).
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/proc/find_spit_spot(obj/effect/dummy/phased_mob/burrow)
	var/turf/here = get_turf(burrow)
	if(!here)
		return null
	if(!here.is_blocked_turf(exclude_mobs = TRUE))
		return here
	var/turf/best
	for(var/turf/candidate as anything in RANGE_TURFS(2, burrow))
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		if(!best || get_dist(candidate, here) < get_dist(best, here))
			best = candidate
	return best || here

/// An armed swing by the crawl's owner. Signal args per COMSIG_MOB_ITEM_ATTACK: (target, user, modifiers, attack_modifiers).
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/proc/on_armed_strike(mob/living/butcher, mob/living/prey, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	// The signal fires for every item touch, scanners included, only a real
	// weapon in the striking hand reads as a strike
	var/obj/item/blade = butcher.get_active_held_item()
	if(!blade || blade.force <= 0)
		return
	judge_pounce(butcher, prey)

/// An unarmed swing by the crawl's owner. Signal args per COMSIG_LIVING_UNARMED_ATTACK: (target, proximity, modifiers).
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/proc/on_unarmed_strike(mob/living/butcher, atom/prey, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!proximity || !butcher.combat_mode)
		return
	judge_pounce(butcher, prey)

/**
 * The pounce, judged: inside the window, first credit of this rise, honest
 * quarry, still alive, and MOVING, meaning it is not standing on the same
 * tile it stood on at the dive or when the lurker surfaced. A beast absent
 * from the surfacing snapshot is not enough evidence for a pounce. Credit resolves the wielder's live trial at strike
 * time; completion may delete the trial (deferred), so nothing here touches
 * it after pounce() returns.
 */
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/proc/judge_pounce(mob/living/butcher, atom/prey)
	if(!emerged_at || world.time > emerged_at + VESTIGE_TRAPDOOR_STRIKE_WINDOW || credited_this_rise)
		return
	if(!isliving(prey))
		return
	var/mob/living/quarry = prey
	if(quarry.stat == DEAD || !vestige_is_shambles_quarry(quarry, butcher))
		return
	var/datum/vestige_trial/trapdoor_feast/trial = butcher.mind?.active_vestige_trial
	if(!istype(trial))
		return
	var/turf/seen_at = LAZYACCESS(positions_at_rise, WEAKREF(quarry))
	var/turf/dive_at = LAZYACCESS(positions_at_dive, WEAKREF(quarry))
	if(!seen_at)
		return
	var/moved_during_dive = dive_at && dive_at != seen_at
	if(!moved_during_dive && seen_at == get_turf(quarry))
		to_chat(butcher, span_warning("[quarry] has not moved during your dive or since you rose. A pounce only counts on something that was moving."))
		return
	if(!trial.pounce(quarry))
		to_chat(butcher, span_warning("[quarry] has been surprised enough times. It knows where the floor keeps its doors now. Go find something else."))
		return
	credited_this_rise = TRUE
	to_chat(butcher, span_notice("Up through the red and into [quarry] mid-stride. From under the floor, briefly: laughter."))
	playsound(butcher, 'sound/effects/magic/demon_attack1.ogg', 20, TRUE)

// ===== SET THE TABLE =====

/**
 * The logistics trial: killing is only half the shop. Every wild thing
 * brought down must go onto the loaned gambrel's hooks while it still steams.
 * The freshness clock is the beast's own time of death, so the pressure
 * needs no global scanning and no kill-watching: a carcass presented to the
 * hooks either made the window or it didn't. The gambrel refuses cold meat
 * outright (refusal teaches the timer better than silent no-credit would),
 * refuses anyone but its own butcher, and dedups by carcass, so three settings
 * means three full kill-haul-hang cycles run while the hunting ground stays
 * hostile around you. Verified against the kitchenspike: fauna corpses
 * buckle fine, but its 10-second hook time and torture-rack unbuckling are
 * wrong for a timed trial, so the gambrel is its own structure with a
 * 1.5-second hang and instant unhooking (credit is banked at hang time;
 * unhooking un-credits nothing and re-hanging re-credits nothing).
 */
/datum/vestige_trial/set_the_table
	name = "Set the Table"
	// Keep the counts in sync with VESTIGE_TABLE_SETTINGS / _FRESHNESS
	// (initial values must be constant, so no define interpolation here)
	desc = "Last lesson is the table, and it's the one every butcher skips. Take the gambrel and plant it somewhere the hunting is good. Everything you bring down goes on the hooks while it's still warm: forty-five seconds from last breath to hook, no more, I don't seat cold meat. Three carcasses hung fresh while the hunt goes on around you: kill, haul, hang, repeat. A butcher who can't set a table is just a murderer with a very good knife. Ha!"
	/// The loaned gambrel, folded, while it rides in hand. Reclaimed the moment the pact ends.
	var/obj/item/vestige_gambrel/gambrel_item
	/// The gambrel, planted. Reclaimed the moment the pact ends (hung meat drops free).
	var/obj/structure/vestige_gambrel/gambrel_structure
	/// Fresh settings hung so far
	var/settings = 0
	/// Carcasses already seated (weakref -> TRUE), unhooking and re-hanging the same beast lays no second setting
	var/list/served = list()
	/// Guards the deferred completion beat (see conclude)
	var/concluding = FALSE

/datum/vestige_trial/set_the_table/on_accepted(mob/living/user)
	var/obj/item/vestige_gambrel/folded = new(get_turf(user))
	folded.bound_mind = owner
	gambrel_item = hand_over(user, folded)
	to_chat(user, span_notice("The gambrel folds itself into your arms with its hooks tucked in. It is heavier than iron and much warmer than it should be."))

/datum/vestige_trial/set_the_table/Destroy()
	QDEL_NULL(gambrel_item)
	QDEL_NULL(gambrel_structure) // its Destroy lets the hung meat down first
	return ..()

/datum/vestige_trial/set_the_table/get_progress_text()
	var/status
	if(gambrel_structure && !QDELETED(gambrel_structure))
		status = "The gambrel stands planted"
	else if(gambrel_item && !QDELETED(gambrel_item))
		status = "The gambrel is folded up in your hands. Plant it somewhere the hunting is good"
	else
		status = "The gambrel is gone. Replace the kit from your pact tracker to try again"
	return "[status]. [settings] of [VESTIGE_TABLE_SETTINGS] settings hung fresh."

/// Credits a fresh carcass onto the table. May schedule completion. Returns FALSE if this beast was already seated.
/datum/vestige_trial/set_the_table/proc/lay_setting(mob/living/meat)
	var/datum/weakref/key = WEAKREF(meat)
	if(served[key])
		return FALSE
	served[key] = TRUE
	settings++
	refresh_tracker()
	if(settings >= VESTIGE_TABLE_SETTINGS && !concluding)
		concluding = TRUE
		// Deferred: complete() qdels the trial, whose Destroy qdels the gambrel,
		// which is partway through its own buckle chain right now
		addtimer(CALLBACK(src, PROC_REF(conclude)), VESTIGE_SHAMBLES_CONCLUDE_DELAY)
	return TRUE

/// The deferred completion beat. The pact may have been renounced inside the delay; complete() handles the rest.
/datum/vestige_trial/set_the_table/proc/conclude()
	if(!QDELETED(src))
		complete()

// --- The gambrel, folded ---

/obj/item/vestige_gambrel
	name = "traveling gambrel"
	desc = "A folding rack of demon-dark iron with its hooks curled in on themselves. Butcher shops have hung meat from these for centuries. This one hums, very faintly."
	icon = 'icons/obj/service/kitchen.dmi'
	icon_state = "spikeframe"
	color = "#a86a54" // demon-dark iron gone rustward
	w_class = WEIGHT_CLASS_BULKY
	/// Mind of the supplicant setting this table, the gambrel answers only its own butcher
	var/datum/mind/bound_mind

/obj/item/vestige_gambrel/Destroy()
	var/datum/vestige_trial/set_the_table/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.gambrel_item == src)
		trial.gambrel_item = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/item/vestige_gambrel/examine(mob/user)
	. = ..()
	. += span_notice("Use it on an open stretch of floor to unfold it into a hanging rack. Plant it somewhere the hunting is good. It only takes meat within [VESTIGE_TABLE_FRESHNESS / 10] seconds of the kill.")

/obj/item/vestige_gambrel/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isopenturf(interacting_with))
		return NONE
	var/turf/open/ground = interacting_with
	var/datum/vestige_trial/set_the_table/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the hooks hang slack!")
		return ITEM_INTERACT_BLOCKING
	// Never inside the vestige: the ruin unloads the moment everyone leaves,
	// and a planted table must not be wiped mid-hunt by map cleanup
	if(istype(get_area(ground), /area/ruin/space/has_grav/vestige))
		balloon_alert(user, "not in the shambles itself!")
		return ITEM_INTERACT_BLOCKING
	if(ground.is_blocked_turf(exclude_mobs = TRUE))
		balloon_alert(user, "no room to stand it up!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "unfolding the rack...")
	if(!do_after(user, 1 SECONDS, target = ground))
		return ITEM_INTERACT_BLOCKING
	if(!user.is_holding(src))
		return ITEM_INTERACT_BLOCKING
	// Re-resolve everything; the pact may have been renounced mid-plant
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return ITEM_INTERACT_BLOCKING
	if(ground.is_blocked_turf(exclude_mobs = TRUE))
		balloon_alert(user, "no room to stand it up!")
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/vestige_gambrel/rack = new(ground)
	rack.bound_mind = user.mind
	trial.gambrel_structure = rack
	trial.register_loan(rack)
	user.visible_message(
		span_warning("[user] stands [src] up, and its hooks unfold with a sound like knuckles cracking."),
		span_notice("You stand the gambrel up. The hooks spread themselves out, unhurried."),
	)
	playsound(ground, 'sound/items/weapons/tap.ogg', 50, TRUE)
	trial.refresh_tracker()
	qdel(src) // Destroy clears the trial's item pointer
	return ITEM_INTERACT_SUCCESS

// --- The gambrel, planted ---

/**
 * The planted rack: a buckle structure that accepts exactly one kind of guest,
 * a fresh, wild carcass, presented by its own butcher. It holds no trial
 * reference: everything resolves through bound_mind at the moment it's
 * needed, the same rule every kit item follows. Freshness is judged twice
 * (before and after the hang do_after. The clock does not stop for
 * ceremony), and credit is banked at hang time, so unhooking to lighten the
 * table costs nothing and recycles nothing.
 */
/obj/structure/vestige_gambrel
	name = "traveling gambrel"
	desc = "A hanging rack of demon-dark iron, hooks spread and waiting. The metal is warm to the touch, which it has no reason to be."
	icon = 'icons/obj/service/kitchen.dmi'
	icon_state = "spike"
	color = "#a86a54"
	density = TRUE
	anchored = TRUE
	max_integrity = 200
	can_buckle = TRUE
	buckle_lying = FALSE
	max_buckled_mobs = VESTIGE_TABLE_SETTINGS // the finished table displays whole
	/// Mind of the supplicant setting this table
	var/datum/mind/bound_mind

/obj/structure/vestige_gambrel/Destroy()
	unbuckle_all_mobs(force = TRUE) // post_unbuckle_mob rights each carcass on the way down
	var/datum/vestige_trial/set_the_table/trial = get_bound_trial()
	if(istype(trial) && !QDELETED(trial))
		if(trial.gambrel_structure == src)
			trial.gambrel_structure = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/// The bound soul's table-setting, if it still runs, resolved fresh every time, never stored (renounce-safe)
/obj/structure/vestige_gambrel/proc/get_bound_trial()
	var/datum/vestige_trial/set_the_table/trial = bound_mind?.active_vestige_trial
	if(istype(trial))
		return trial
	return null

/obj/structure/vestige_gambrel/examine(mob/user)
	. = ..()
	for(var/mob/living/meat in view(7, src))
		if(meat.stat == DEAD && vestige_is_shambles_quarry(meat, user))
			var/remaining = max(0, meat.timeofdeath + VESTIGE_TABLE_FRESHNESS - world.time)
			. += span_notice("[meat]: [remaining ? "[DisplayTimeText(remaining)] to hang" : "gone cold"].")
	. += span_notice("Drag a fresh wild carcass onto it to hang it, within [VESTIGE_TABLE_FRESHNESS / 10] seconds of the kill, and only by whoever made the pact. [VESTIGE_TABLE_SETTINGS] settings finish the table.")
	var/datum/vestige_trial/set_the_table/trial = get_bound_trial()
	if(istype(trial) && user.mind == bound_mind)
		. += span_boldnotice(trial.get_progress_text())

/obj/structure/vestige_gambrel/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode || has_buckled_mobs())
		return ..() // smacking it, or letting the meat down, both the parent's business
	// tend() sleeps (tgui_alert); don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(tend), user)
	return TRUE

/// The butcher's hand on an empty rack: the fold-up/leave choice
/obj/structure/vestige_gambrel/proc/tend(mob/living/user)
	if(!user.mind || user.mind != bound_mind)
		balloon_alert(user, "not your table!")
		return
	var/datum/vestige_trial/set_the_table/trial = get_bound_trial()
	if(!istype(trial))
		balloon_alert(user, "the hooks hang slack!")
		return
	var/choice = tgui_alert(user, "The gambrel stands empty. Fold it back up and carry it to better hunting?", name, list("Fold it up", "Leave it"))
	// Re-verify the whole world; the alert slept
	if(choice != "Fold it up" || QDELETED(src) || has_buckled_mobs() || QDELETED(user) || !user.Adjacent(src) || user.mind != bound_mind)
		return
	trial = get_bound_trial()
	if(!istype(trial))
		return
	var/obj/item/vestige_gambrel/folded = new(get_turf(src))
	folded.bound_mind = bound_mind
	trial.gambrel_item = folded
	trial.register_loan(folded)
	user.put_in_hands(folded)
	user.visible_message(
		span_warning("[user] folds [src] down, hooks tucking themselves away."),
		span_notice("You fold the gambrel back up. It comes away easily."),
	)
	qdel(src) // Destroy clears the trial's structure pointer and refreshes the tracker

/**
 * The gatekeeping: only the bound butcher, only dead wild quarry, only fresh,
 * only new. Every refusal says why. The freshness clock is the trial, and a
 * clock you can't read teaches nothing. The parent runs the actual buckle;
 * post_buckle_mob banks the credit.
 */
/obj/structure/vestige_gambrel/user_buckle_mob(mob/living/meat, mob/user, check_loc = TRUE)
	if(!isliving(user) || !isliving(meat))
		return
	var/mob/living/butcher = user
	if(!butcher.mind || butcher.mind != bound_mind)
		balloon_alert(butcher, "not your table to set!")
		return
	var/datum/vestige_trial/set_the_table/trial = get_bound_trial()
	if(!istype(trial))
		balloon_alert(butcher, "the hooks hang slack!")
		return
	if(meat.stat != DEAD)
		balloon_alert(butcher, "still kicking!") // finished work only, this is a table, not a rack
		return
	if(!vestige_is_shambles_quarry(meat, butcher))
		balloon_alert(butcher, "not fit for this table!")
		return
	if(trial.served[WEAKREF(meat)])
		balloon_alert(butcher, "already served!")
		return
	if(world.time > meat.timeofdeath + VESTIGE_TABLE_FRESHNESS)
		balloon_alert(butcher, "gone cold, no cold meat!")
		return
	balloon_alert(butcher, "hooking it up...")
	if(!do_after(butcher, VESTIGE_TABLE_HANG_TIME, target = src))
		return
	// The hang took time and the clock kept running; re-verify all of it
	trial = get_bound_trial()
	if(!istype(trial) || meat.stat != DEAD || trial.served[WEAKREF(meat)])
		return
	if(world.time > meat.timeofdeath + VESTIGE_TABLE_FRESHNESS)
		balloon_alert(butcher, "went cold on the way up!")
		return
	return ..()

// The hung-meat presentation, borrowed from the kitchenspike (verified) minus
// its living-victim theatrics: no scream, no spike damage. This guest is past both
/obj/structure/vestige_gambrel/post_buckle_mob(mob/living/meat)
	playsound(loc, 'sound/effects/splat.ogg', 40, TRUE)
	meat.setDir(SOUTH)
	var/matrix/hung = matrix(meat.transform)
	hung.Turn(180)
	animate(meat, transform = hung, time = 3)
	meat.add_offsets(type, y_add = -6, animate = FALSE)
	ADD_TRAIT(meat, TRAIT_MOVE_UPSIDE_DOWN, REF(src))
	// The gates all ran in user_buckle_mob, but post_buckle_mob is reachable by
	// other roads (admin fiat, future code). Re-derive the cheap, honest checks
	var/datum/vestige_trial/set_the_table/trial = get_bound_trial()
	if(!istype(trial))
		return
	if(world.time > meat.timeofdeath + VESTIGE_TABLE_FRESHNESS)
		return
	// lay_setting() may schedule completion (which later deletes the trial and
	// this rack), nothing touches trial after this
	if(trial.lay_setting(meat))
		visible_message(span_notice("[meat] settles onto the hooks, still steaming. From somewhere close by: two slow, delighted claps."))
		playsound(src, 'sound/effects/magic/demon_attack1.ogg', 20, TRUE)

/obj/structure/vestige_gambrel/post_unbuckle_mob(mob/living/meat)
	var/matrix/righted = matrix(meat.transform)
	righted.Turn(180)
	animate(meat, transform = righted, time = 3)
	meat.remove_offsets(type, animate = FALSE)
	REMOVE_TRAIT(meat, TRAIT_MOVE_UPSIDE_DOWN, REF(src))

#undef VESTIGE_ROAD_KILLS_NEEDED
#undef VESTIGE_TRAPDOOR_AMBUSHES_NEEDED
#undef VESTIGE_TRAPDOOR_STRIKES_PER_PREY
#undef VESTIGE_TRAPDOOR_STRIKE_WINDOW
#undef VESTIGE_TRAPDOOR_LURK_MAX
#undef VESTIGE_TRAPDOOR_COOLDOWN
#undef VESTIGE_TRAPDOOR_TOLL
#undef VESTIGE_TRAPDOOR_SNAPSHOT_RANGE
#undef VESTIGE_TABLE_SETTINGS
#undef VESTIGE_TABLE_FRESHNESS
#undef VESTIGE_TABLE_HANG_TIME
#undef VESTIGE_SHAMBLES_CONCLUDE_DELAY


/**
 * # The Shambles: slaughter demon vestige: BOONS
 *
 * The Stain's syllabus, taught in the order any honest butcher learns the
 * trade: the crawl (how to reach the work), the claws (how to do the work),
 * the laugh (how to clear the room for it), and the nose (how to find it).
 * Every line item is either the demon's own tool re-audited for a human hand,
 * or a faithful local rebuild where the original was welded to the demon.
 *
 * Porting audit (all against live code):
 * - Blood Crawl: upstream /datum/action/cooldown/spell/jaunt/bloodcrawl ships
 *   spell_requirements = NONE (bloodcrawl.dm line 15) and is ALREADY granted
 *   to plain humans today by the demon heart organ (demon_items.dm,
 *   on_mob_insert), the exact non-consume base type, as-is. The
 *   victim-consume subtype (/slaughter_demon) stays CUT: consume, the jaunt
 *   damage timer and the antag consume_count all live on the subtype, none of
 *   it on the base. Human edges checked: entry calls drop_all_held_items()
 *   (items DROP at the pool, nothing is deleted; DROPDEL abstracts like our
 *   claws clean themselves up), the loaned "blood crawl" hands are
 *   ABSTRACT|DROPDEL and are force-removed + qdel'd on every exit path
 *   (on_jaunt_exited), exit_blood_effect is a 6-second cosmetic tint, and an
 *   unconscious jaunter is safely ejected by the phased mob's stat-change
 *   handler. Nothing strips or eats worn gear.
 * - Red Undertow: local subtype adding ONE thing: a rise-strike on deliberate
 *   exits. The 2-second bubbling exit channel stays as the telegraph.
 * - Rending Claws: local item + conjure spell on the changeling armblade boon
 *   pattern (theme_changeling.dm). The bleed-scaling rend and the wound-bonus
 *   hitstreak of the upgrade are the live slaughter demon's own mechanics
 *   (demon_subtypes.dm: wound_bonus_per_hit = 5, cap 12, reset on crawl),
 *   resized for a person and moved onto the item.
 * - Slaughter's Mirth: local AoE spell. Fear rides the upstream fearful
 *   component exactly the way the nightmare's terrified status does
 *   (terrified.dm: AddComponentFrom/RemoveComponentSource); stagger is the
 *   upstream staggered status via adjust_staggered_up_to. No hard stun.
 * - Scent of Blood: local toggle. The compass is a subtype of the upstream
 *   agent_pinpointer status effect (screen-alert arrow, renders through
 *   walls by construction, no image/sight-flag tricks); the blood-wet
 *   footwork is the demon's own /datum/movespeed_modifier/slaughter idea
 *   (-1 for 6s post-crawl) cut down to a modest standing bonus.
 *
 * Fork quirk honored: Activate() ignores cast() return values, so every
 * cancel path here lives in before_cast (the claws' free-hand check); nothing
 * relies on reset_spell_cooldown() from inside cast().
 */

// --- The crawl (VESTIGE_CRAWL_) ---
/// How long Red Undertow's rise-strike floors bystanders
#define VESTIGE_CRAWL_RISE_KNOCKDOWN (1.5 SECONDS)
/// How far around the pool the rise-strike reaches, in tiles
#define VESTIGE_CRAWL_RISE_RANGE 1

// --- The claws (VESTIGE_CLAWS_) ---
/// Cooldown on forming/folding the claws
#define VESTIGE_CLAWS_COOLDOWN (8 SECONDS)
/// Base force of the rending claws
#define VESTIGE_CLAWS_FORCE 21
/// Armour penetration of the rending claws
#define VESTIGE_CLAWS_AP 10
/// Bonus force against prey that is already bleeding (or, for the bloodless, badly wounded)
#define VESTIGE_CLAWS_REND_BONUS 8
/// Base force of the butcher's-rhythm claws
#define VESTIGE_CLAWS_BUTCHER_FORCE 23
/// Armour penetration of the butcher's-rhythm claws
#define VESTIGE_CLAWS_BUTCHER_AP 15
/// Wound bonus gained per consecutive hit on the same living prey (the demon's own wound_bonus_per_hit)
#define VESTIGE_CLAWS_RHYTHM_STEP 5
/// Cap on the rhythm's accumulated wound bonus
#define VESTIGE_CLAWS_RHYTHM_CAP 15
/// Fraction of max health below which a bloodless (non-carbon) creature counts as opened
#define VESTIGE_CLAWS_WOUNDED_FRACTION 0.5

// --- The laugh (VESTIGE_MIRTH_) ---
/// Cooldown of the laugh
#define VESTIGE_MIRTH_COOLDOWN (40 SECONDS)
/// How far the laugh carries, in tiles (line of sight, walls smother it)
#define VESTIGE_MIRTH_RADIUS 5
/// Terror buildup poured into each human who hears it (FEAR threshold is 150; TERROR is 300)
#define VESTIGE_MIRTH_TERROR 200
/// Stagger applied per laugh
#define VESTIGE_MIRTH_STAGGER (4 SECONDS)
/// Stagger ceiling so chained laughs can't perma-stagger
#define VESTIGE_MIRTH_STAGGER_MAX (8 SECONDS)
/// How long the dread status (and its fear source) lasts
#define VESTIGE_MIRTH_DREAD_DURATION (15 SECONDS)
/// How long simple creatures cower on the deck
#define VESTIGE_MIRTH_FAUNA_COWER (3 SECONDS)

// --- The nose (VESTIGE_SCENT_) ---
/// How far the nose smells, in tiles, through anything
#define VESTIGE_SCENT_RANGE 10
/// Time between sniffs while the nose is open
#define VESTIGE_SCENT_PULSE (2 SECONDS)
/// Fraction of max health below which a bloodless creature still smells wounded
#define VESTIGE_SCENT_WOUNDED_FRACTION 0.5
/// Movespeed bonus (negative slowdown) while standing on blood-wet flooring
#define VESTIGE_SCENT_BLOOD_SPEED -0.3

// ===== BOONS =====

// --- Chain: the crawl ---

// Upstream base bloodcrawl, granted as-is: spell_requirements = NONE, and the
// demon heart already hands this exact type to plain humans (demon_items.dm).
// The consume-victims subtype is never granted by anything in this file.
/datum/vestige_boon/spell/blood_crawl
	name = "Blood Crawl"
	desc = "The trade's front door. Step into any decent pool of blood and stop existing until you step back out. Going under is instant; coming up takes a boil that everyone nearby can watch. You drop whatever you're holding at the edge of the pool."
	grant_text = "The Stain claps you on the back, fondly. \"First lesson, apprentice: never track blood THROUGH a room when you can travel AS it.\""
	spell_type = /datum/action/cooldown/spell/jaunt/bloodcrawl

/datum/vestige_boon/spell/blood_crawl/red_undertow
	name = "Red Undertow"
	desc = "The crawl, finished properly. Surface with your whole weight behind it and anyone standing beside the pool is knocked flat. It still boils first, so a patient audience keeps its footing."
	grant_text = "\"Second lesson: the pool is not the trick. The ARRIVAL is the trick.\" The Stain mimes surfacing, with tremendous theatre."
	upgrades_from = /datum/vestige_boon/spell/blood_crawl
	spell_type = /datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_undertow

// --- Chain: the claws ---

/datum/vestige_boon/spell/rending_claws
	name = "Rending Claws"
	desc = "Grow the trade's own knives out of your hand, and fold them away whenever you need the hand back. They bite deeper into anything already bleeding, and they butcher carcasses too, obviously."
	grant_text = "Your knuckles ache, then split, then settle. \"Mind the edge, apprentice. It minds you.\""
	spell_type = /datum/action/cooldown/spell/vestige_rending_claws

/datum/vestige_boon/spell/rending_claws/butchers_rhythm
	name = "Butcher's Rhythm"
	desc = "The claws with the tempo taught in. They hit harder, and every consecutive strike on the same living target wounds deeper than the last. Switch targets and the rhythm resets."
	grant_text = "\"One-two-THREE, one-two-THREE. It is a waltz, apprentice. The partner just objects more.\""
	upgrades_from = /datum/vestige_boon/spell/rending_claws
	spell_type = /datum/action/cooldown/spell/vestige_rending_claws/butchers

// --- Standalone: the laugh ---

/datum/vestige_boon/spell/slaughters_mirth
	name = "Slaughter's Mirth"
	desc = "Laugh the way the trade laughs. Everyone in sight nearby is staggered, people get hit with raw dread (shaking, stuttering, a racing heart, but never a stun) and simple creatures cower on the deck. There is no subtle way to do it."
	grant_text = "Something in your chest learns a new way to breathe, though breathing isn't quite what it's doing."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_mirth

// --- Standalone: the nose ---

/datum/vestige_boon/spell/scent_of_blood
	name = "Scent of Blood"
	desc = "Open the trade's nose. A compass on your HUD swings toward the nearest bleeding or badly wounded creature, walls or no walls, and you move a little quicker on blood-wet flooring. Use it again to close it."
	grant_text = "\"Last lesson, apprentice, and the most important: the wounded are never lost. Only mislaid.\""
	spell_type = /datum/action/cooldown/spell/vestige_blood_scent

// ===== RED UNDERTOW =====

/**
 * The crawl with a finish on it. Everything about entering, travelling and
 * the loaned blood-hands is inherited untouched; the single addition is a
 * knockdown burst when a DELIBERATE exit completes. try_exit_jaunt is only
 * reached through the cast chain, so an unconscious body flopping out of the
 * pool (phased_mob's stat-change eject) never knocks anyone down, only a
 * butcher arriving on purpose does.
 */
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_undertow
	name = "Red Undertow"
	desc = "Dive into a pool of blood and surface from another one. Anyone standing beside you when you come up is knocked over."

/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_undertow/try_exit_jaunt(obj/effect/decal/cleanable/blood, mob/living/jaunter, forced = FALSE)
	. = ..()
	if(!.)
		return
	rise_strike(jaunter)

/// The undertow itself: everyone beside the pool is floored by the arrival
/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_undertow/proc/rise_strike(mob/living/jaunter)
	var/turf/rise_turf = get_turf(jaunter)
	if(!rise_turf)
		return
	playsound(rise_turf, 'sound/effects/magic/demon_attack1.ogg', 60, TRUE)
	for(var/mob/living/bystander in range(VESTIGE_CRAWL_RISE_RANGE, rise_turf))
		if(bystander == jaunter || bystander.stat == DEAD)
			continue
		if(!isturf(bystander.loc)) // a locker is a fine place to weather an arrival
			continue
		if(bystander.buckled) // strapped in is strapped in
			continue
		bystander.Knockdown(VESTIGE_CRAWL_RISE_KNOCKDOWN)
		to_chat(bystander, span_userdanger("The pool erupts and [jaunter] surfaces through you, slapping you off your feet!"))
	jaunter.visible_message(
		span_boldwarning("[jaunter] surfaces in a wave of gore that slaps the floor flat around [jaunter.p_them()]!"),
		span_notice("You arrive the way the Stain taught you: all at once, and rudely."),
	)

// ===== RENDING CLAWS =====

/**
 * The conjure spell, on the armblade boon's chassis, with the no-free-hand
 * cancel moved into before_cast, because this fork's Activate() ignores
 * cast()'s return value and an in-cast reset_spell_cooldown() is dead code.
 * Casting with any vestige claw in hand folds it away; if the held claw is an
 * outdated model (base claw after the upgrade replaced the spell), the same
 * cast reshapes it into the current one, so no stranded NODROP claw can ever
 * be left behind by an upgrade taken mid-form.
 */
/datum/action/cooldown/spell/vestige_rending_claws
	name = "Form Rending Claws"
	desc = "Turn your hand into a set of claws. Use again to put them away."
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "cleave"
	background_icon_state = "bg_demon"
	overlay_icon_state = "bg_demon_border"
	school = SCHOOL_TRANSMUTATION
	cooldown_time = VESTIGE_CLAWS_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// The claw item this spell grows
	var/claw_type = /obj/item/vestige_rending_claw

/datum/action/cooldown/spell/vestige_rending_claws/butchers
	name = "Form Butcher's Claws"
	desc = "Turn your hand into a stronger set of claws. Use again to put them away."
	button_icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	button_icon_state = "butcher_claws"
	claw_type = /obj/item/vestige_rending_claw/butchers

/datum/action/cooldown/spell/vestige_rending_claws/is_valid_target(atom/cast_on)
	return iscarbon(cast_on)

// The cancel lives here: no claw to fold and no hand to grow one in means the
// cast never happens and the cooldown is never paid (fork quirk workaround)
/datum/action/cooldown/spell/vestige_rending_claws/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	var/mob/living/carbon/butcher = cast_on
	if(locate(/obj/item/vestige_rending_claw) in butcher.held_items)
		return
	if(!length(butcher.get_empty_held_indexes()))
		butcher.balloon_alert(butcher, "no free hand!")
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/vestige_rending_claws/cast(mob/living/carbon/cast_on)
	. = ..()
	var/obj/item/vestige_rending_claw/held = locate(/obj/item/vestige_rending_claw) in cast_on.held_items
	if(held)
		var/outdated = held.type != claw_type
		qdel(held)
		if(!outdated)
			cast_on.visible_message(
				span_warning("The claws slide back under [cast_on]'s skin!"),
				span_notice("You fold the claws away. The hand forgives you, eventually."),
			)
			return
		// An old model from before the upgrade: reshape it in place
	var/obj/item/new_claw = new claw_type(cast_on)
	if(!cast_on.put_in_hands(new_claw))
		if(!QDELETED(new_claw)) // DROPDEL usually beat us to it
			qdel(new_claw)
		cast_on.balloon_alert(cast_on, "no free hand!")
		return
	cast_on.visible_message(
		span_warning("[cast_on]'s hand splits open into a fan of hooked claws!"),
		span_notice("Your hand remembers its lessons and splits into the trade's knives."),
	)
	playsound(cast_on, 'sound/effects/magic/demon_attack1.ogg', 40, TRUE)

/**
 * The trade's knives. Sharp, sheddable (ABSTRACT|DROPDEL, NODROP, same
 * lifecycle as the armblade), and rewarded for craft over brawn: force 21
 * flat, +8 rend against prey that is already bleeding, or, for bloodless
 * creatures, already below half health. Butchers meat too, naturally.
 * Sprite note: reuses the changeling arm_blade sprite under a gore-dark tint;
 * no dedicated claw item sprite exists in the tree.
 */
/obj/item/vestige_rending_claw
	name = "rending claws"
	desc = "A fan of hooked claws grown straight out of the hand. They are much better at opening a wound somebody else already started than at making a new one."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "rending_claw"
	inhand_icon_state = null
	color = "#a03535"
	item_flags = ABSTRACT | DROPDEL
	w_class = WEIGHT_CLASS_HUGE
	force = VESTIGE_CLAWS_FORCE
	throwforce = 0 // grown from the hand; they do not leave it
	throw_range = 0
	throw_speed = 0
	hitsound = 'sound/items/weapons/bladeslice.ogg'
	attack_verb_continuous = list("rends", "hooks", "carves", "opens", "unseams")
	attack_verb_simple = list("rend", "hook", "carve", "open", "unseam")
	sharpness = SHARP_EDGED
	wound_bonus = -5
	exposed_wound_bonus = 5
	armour_penetration = VESTIGE_CLAWS_AP

/obj/item/vestige_rending_claw/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, ABSTRACT_ITEM_TRAIT)
	AddComponent(/datum/component/butchering, \
		speed = 8 SECONDS, \
		effectiveness = 70, \
	)

/// Whether this prey rewards the rend: bleeding carbons, or bloodless organic creatures already below half health
/obj/item/vestige_rending_claw/proc/prey_is_opened(mob/living/prey)
	if(iscarbon(prey))
		var/mob/living/carbon/carbon_prey = prey
		return carbon_prey.is_bleeding()
	if(!(prey.mob_biotypes & MOB_ORGANIC)) // nothing to smell, nothing to rend
		return FALSE
	return prey.health <= prey.maxHealth * VESTIGE_CLAWS_WOUNDED_FRACTION

/obj/item/vestige_rending_claw/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(isliving(target) && prey_is_opened(target))
		MODIFY_ATTACK_FORCE(attack_modifiers, VESTIGE_CLAWS_REND_BONUS)
	return ..()

/**
 * The rhythm section. Same rend, plus the live slaughter demon's own
 * hitstreak (demon_subtypes.dm), moved onto the item: consecutive hits on the
 * same living prey raise the claw's wound bonuses by 5 apiece, capped at +15,
 * so a held tempo starts opening slash wounds, which bleed, which primes the
 * rend bonus. Switching targets (or reforming the claws) drops the beat to
 * zero. Melee-honest: nothing here reaches past arm's length.
 */
/obj/item/vestige_rending_claw/butchers
	name = "butcher's claws"
	desc = "The rending claws, with the tempo taught in. Every stroke on the same target lands worse than the one before it."
	color = "#7a1f1f"
	force = VESTIGE_CLAWS_BUTCHER_FORCE
	wound_bonus = 0
	exposed_wound_bonus = 10
	armour_penetration = VESTIGE_CLAWS_BUTCHER_AP
	/// Accumulated wound-bonus points from keeping the beat on one prey
	var/rhythm = 0
	/// The prey the rhythm is being kept on
	var/datum/weakref/rhythm_prey

/obj/item/vestige_rending_claw/butchers/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(isliving(target) && target.stat != DEAD)
		var/mob/living/current_prey = rhythm_prey?.resolve()
		if(current_prey == target)
			if(rhythm < VESTIGE_CLAWS_RHYTHM_CAP)
				rhythm = min(rhythm + VESTIGE_CLAWS_RHYTHM_STEP, VESTIGE_CLAWS_RHYTHM_CAP)
				if(rhythm == VESTIGE_CLAWS_RHYTHM_CAP && user)
					user.balloon_alert(user, "full rhythm!")
		else
			rhythm = 0
			rhythm_prey = WEAKREF(target)
	wound_bonus = initial(wound_bonus) + rhythm
	exposed_wound_bonus = initial(exposed_wound_bonus) + rhythm
	return ..()

// ===== SLAUGHTER'S MIRTH =====

/**
 * The Laugh. An AoE dread-and-stagger built local: the demon has no laugh
 * spell to port (its terror is ambience), so this borrows the two honest
 * pieces upstream already maintains, the fearful component (terror buildup
 * with its stock jitter/stutter/heart handlers, applied and removed exactly
 * the way the nightmare's terrified status does it) and the staggered status
 * effect. view()-bounded: the laugh is a sound with a face, and walls smother
 * both. Mind antimagic answers it (MAGIC_RESISTANCE_MIND, per Terrorize).
 * Deliberately never a stun: it opens fights and covers exits, it does not
 * win them.
 */
/datum/action/cooldown/spell/aoe/vestige_mirth
	name = "Slaughter's Mirth"
	desc = "Laugh. Everyone nearby who can see you is staggered, people are badly frightened, and animals cower. Loud, and never a stun."
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "moon_smile"
	background_icon_state = "bg_demon"
	overlay_icon_state = "bg_demon_border"
	antimagic_flags = MAGIC_RESISTANCE_MIND
	cooldown_time = VESTIGE_MIRTH_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	aoe_radius = VESTIGE_MIRTH_RADIUS

// view(), not range(): the laugh needs a line to you. A closed door is a
// perfectly good answer to it
/datum/action/cooldown/spell/aoe/vestige_mirth/get_things_to_cast_on(atom/center)
	var/list/things = list()
	for(var/mob/living/nearby in view(aoe_radius, center))
		if(nearby == owner || nearby.stat == DEAD)
			continue
		if(!(nearby.mob_biotypes & MOB_ORGANIC)) // dread is for the living; borgs file it under "noise"
			continue
		things += nearby
	return things

/datum/action/cooldown/spell/aoe/vestige_mirth/after_cast(atom/cast_on)
	. = ..()
	if(!owner)
		return
	if(isliving(owner))
		owner.emote("laugh")
	playsound(get_turf(owner), 'sound/misc/insane_low_laugh.ogg', 100, TRUE, extrarange = 3)
	new /obj/effect/temp_visual/circle_wave/vestige_mirth(get_turf(owner))
	owner.visible_message(
		span_boldwarning("[owner] throws [owner.p_their()] head back and laughs, low, warm, and entirely wrong!"),
		span_notice("You laugh the way the Stain laughs: like the room is a meal that has just been seated."),
	)

/datum/action/cooldown/spell/aoe/vestige_mirth/cast_on_thing_in_aoe(mob/living/victim, atom/caster)
	if(victim.can_block_magic(antimagic_flags))
		victim.balloon_alert(owner, "unmoved!")
		return
	victim.adjust_staggered_up_to(VESTIGE_MIRTH_STAGGER, VESTIGE_MIRTH_STAGGER_MAX)
	if(ishuman(victim))
		to_chat(victim, span_userdanger("The laugh crawls in under your ribs and stays there!"))
		victim.apply_status_effect(/datum/status_effect/vestige_mirth_dread)
	else
		victim.Knockdown(VESTIGE_MIRTH_FAUNA_COWER)
		victim.visible_message(
			span_warning("[victim] drops flat against the deck, cowering!"),
			span_userdanger("The laugh! Down! Get DOWN!"),
		)

/obj/effect/temp_visual/circle_wave/vestige_mirth
	color = "#7a0e0e"
	amount_to_scale = 4

/**
 * The dread the laugh leaves behind: a timed pour of terror buildup through
 * the upstream fearful component, using only its stock default handlers
 * (jittering, stuttering, heart problems, panic, no darkness scaling, unlike
 * the nightmare's nyctophobic version). 200 buildup lands between the FEAR
 * (150) and TERROR (300) thresholds: immediate shaking and stuttering that
 * decays on its own. The component source is removed with the status, so
 * nothing lingers processing after the dread lets go.
 */
/datum/status_effect/vestige_mirth_dread
	id = "vestige_mirth_dread"
	duration = VESTIGE_MIRTH_DREAD_DURATION
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/vestige_mirth_dread
	remove_on_fullheal = TRUE
	show_duration = TRUE

/datum/status_effect/vestige_mirth_dread/on_apply()
	owner.AddComponentFrom(id, /datum/component/fearful, null, VESTIGE_MIRTH_TERROR)
	return TRUE

/datum/status_effect/vestige_mirth_dread/refresh(effect, ...)
	. = ..()
	// Laughed at again while still rattled: pour more terror into the same source
	owner.AddComponentFrom(id, /datum/component/fearful, null, VESTIGE_MIRTH_TERROR)

/datum/status_effect/vestige_mirth_dread/on_remove()
	owner.RemoveComponentSource(id, /datum/component/fearful)

/atom/movable/screen/alert/status_effect/vestige_mirth_dread
	name = "Rattled"
	desc = "That laugh knew something about you. Your hands are shaking and your heart won't sit down."
	icon_state = "terrified"

// ===== SCENT OF BLOOD =====

/**
 * The nose, as a held stance (the Silent Dojo's toggle pattern). While open,
 * a pinpointer-style HUD compass, the upstream agent_pinpointer status
 * effect with the objective scanner swapped for a wound scanner, swings
 * toward the nearest bleeding carbon or badly wounded organic creature within
 * VESTIGE_SCENT_RANGE, re-sniffed every VESTIGE_SCENT_PULSE. A screen alert
 * renders through walls by construction: no images, no sight flags, no lies.
 * The same status keeps the footwork: standing on anything wet enough to
 * bloodcrawl through (the decal's own can_bloodcrawl_in test) grants a modest
 * speed bonus, dropped the moment the floor dries up or the nose closes.
 */
/datum/action/cooldown/spell/vestige_blood_scent
	name = "Scent of Blood"
	desc = "Points you at the nearest bleeding or badly hurt creature and keeps you sure-footed on bloody floors. Use again to turn it off."
	button_icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	button_icon_state = "scent_of_blood"
	background_icon_state = "bg_demon"
	overlay_icon_state = "bg_demon_border"
	cooldown_time = 2 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE

/datum/action/cooldown/spell/vestige_blood_scent/is_valid_target(atom/cast_on)
	return isliving(cast_on)

/datum/action/cooldown/spell/vestige_blood_scent/cast(mob/living/cast_on)
	. = ..()
	if(cast_on.has_status_effect(/datum/status_effect/agent_pinpointer/vestige_scent))
		cast_on.remove_status_effect(/datum/status_effect/agent_pinpointer/vestige_scent)
		cast_on.balloon_alert(cast_on, "the nose closes")
		return
	cast_on.apply_status_effect(/datum/status_effect/agent_pinpointer/vestige_scent)
	cast_on.balloon_alert(cast_on, "the nose opens")
	to_chat(cast_on, span_notice("You inhale, and you can smell every open wound in the room."))

// The stance drops with the spell, an upgrade swap, a borging, a body left
// behind: the nose never outlives the lesson that opened it
/datum/action/cooldown/spell/vestige_blood_scent/Remove(mob/living/remove_from)
	remove_from.remove_status_effect(/datum/status_effect/agent_pinpointer/vestige_scent)
	return ..()

/datum/status_effect/agent_pinpointer/vestige_scent
	id = "vestige_blood_scent"
	duration = STATUS_EFFECT_PERMANENT // the spell toggles it off; nothing else should
	tick_interval = VESTIGE_SCENT_PULSE
	alert_type = /atom/movable/screen/alert/status_effect/agent_pinpointer/vestige_scent
	minimum_range = 2 // adjacent prey reads as "direct", a nose, not a rangefinder
	range_fuzz_factor = 0 // smell does not dissemble
	range_mid = 4
	range_far = 8
	/// Whether the blood-wet speed bonus is currently held
	var/on_blood = FALSE

/datum/status_effect/agent_pinpointer/vestige_scent/on_apply()
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	update_blood_speed()
	return TRUE

/datum/status_effect/agent_pinpointer/vestige_scent/on_remove()
	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)
	if(on_blood)
		on_blood = FALSE
		owner.remove_movespeed_modifier(/datum/movespeed_modifier/vestige_blood_scent)

// The compass sniffs on the pinpointer's tick; the footing re-checks too,
// since pools dry up and get mopped under motionless feet
/datum/status_effect/agent_pinpointer/vestige_scent/tick(seconds_between_ticks)
	. = ..()
	if(!QDELETED(src))
		update_blood_speed()

/// The wound scanner: nearest living, un-dead thing in range that is bleeding
/// (carbons) or organic and below half health (everything else)
/datum/status_effect/agent_pinpointer/vestige_scent/scan_for_target()
	scan_target = null
	var/turf/here = get_turf(owner)
	if(!here)
		return
	var/best_distance = INFINITY
	for(var/mob/living/prey in range(VESTIGE_SCENT_RANGE, here))
		if(prey == owner || prey.stat == DEAD)
			continue
		if(!smells_wounded(prey))
			continue
		var/distance = get_dist(here, get_turf(prey))
		if(distance < best_distance)
			best_distance = distance
			scan_target = prey

/// Whether the nose counts this creature as wounded
/datum/status_effect/agent_pinpointer/vestige_scent/proc/smells_wounded(mob/living/prey)
	if(iscarbon(prey))
		var/mob/living/carbon/carbon_prey = prey
		return carbon_prey.is_bleeding()
	if(!(prey.mob_biotypes & MOB_ORGANIC)) // machines do not bleed, whatever they leak
		return FALSE
	return prey.health <= prey.maxHealth * VESTIGE_SCENT_WOUNDED_FRACTION

/datum/status_effect/agent_pinpointer/vestige_scent/proc/on_moved(datum/source)
	SIGNAL_HANDLER
	update_blood_speed()

/// Grants or drops the blood-wet footwork based on what the owner is standing in
/datum/status_effect/agent_pinpointer/vestige_scent/proc/update_blood_speed()
	var/wet = FALSE
	var/turf/below = get_turf(owner)
	if(below)
		for(var/obj/effect/decal/cleanable/pool in below)
			if(pool.can_bloodcrawl_in())
				wet = TRUE
				break
	if(wet == on_blood)
		return
	on_blood = wet
	if(wet)
		// No balloon: the footing changes every few steps in a messy room, and
		// announcing each one buried everything else the player needed to read
		owner.add_movespeed_modifier(/datum/movespeed_modifier/vestige_blood_scent)
	else
		owner.remove_movespeed_modifier(/datum/movespeed_modifier/vestige_blood_scent)

/atom/movable/screen/alert/status_effect/agent_pinpointer/vestige_scent
	name = "Scent of Blood"
	desc = "The trade's nose is open: it points toward the nearest bleeding or badly wounded creature it can smell."
	icon_state = "pinonnull" // upstream's "pinon" default is a dead state; start honest and null

// A fraction of the demon's own post-crawl burst (its modifier is -1 for six
// seconds); this is a standing bonus, so it stays modest
/datum/movespeed_modifier/vestige_blood_scent
	multiplicative_slowdown = VESTIGE_SCENT_BLOOD_SPEED

#undef VESTIGE_CRAWL_RISE_KNOCKDOWN
#undef VESTIGE_CRAWL_RISE_RANGE
#undef VESTIGE_CLAWS_COOLDOWN
#undef VESTIGE_CLAWS_FORCE
#undef VESTIGE_CLAWS_AP
#undef VESTIGE_CLAWS_REND_BONUS
#undef VESTIGE_CLAWS_BUTCHER_FORCE
#undef VESTIGE_CLAWS_BUTCHER_AP
#undef VESTIGE_CLAWS_RHYTHM_STEP
#undef VESTIGE_CLAWS_RHYTHM_CAP
#undef VESTIGE_CLAWS_WOUNDED_FRACTION
#undef VESTIGE_MIRTH_COOLDOWN
#undef VESTIGE_MIRTH_RADIUS
#undef VESTIGE_MIRTH_TERROR
#undef VESTIGE_MIRTH_STAGGER
#undef VESTIGE_MIRTH_STAGGER_MAX
#undef VESTIGE_MIRTH_DREAD_DURATION
#undef VESTIGE_MIRTH_FAUNA_COWER
#undef VESTIGE_SCENT_RANGE
#undef VESTIGE_SCENT_PULSE
#undef VESTIGE_SCENT_WOUNDED_FRACTION
#undef VESTIGE_SCENT_BLOOD_SPEED
