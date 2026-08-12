/**
 * # The Loom: giant spider vestige (patron + trials)
 *
 * A sericulture vessel: they farmed giant spiders for silk, vivarium cages,
 * reeling machines, bolts of finished cloth graded and priced by the yard.
 * The stock got loose (the cages opened from the inside, and nobody ever asks
 * who taught the stock to work a latch). The brood spread through the decks,
 * was hunted, was harvested, and died out, all but the broodmother, who
 * outlived every child she laid and keeps to the tapestry hall, still weaving.
 * The patron is the Weaver: ancient, patient, a craftswoman whose grief is a
 * maker's, everything she made was taken and sold, so now she weaves only
 * for herself. She speaks in weaving grammar and calls you a loose thread.
 *
 * The trials are her craft, farmed out, and every one demands active play at
 * every moment: the Snare pays only for prey that hits your silk MID-HUNT, so
 * you are the bait and the kiting is the trial; the Pantry is a three-act
 * wrangle, subdue a live beast, wrap it while it fights the silk, then haul
 * the cocoon home against a freshness clock; the Tremor Line turns the web
 * into a nerve, a dispersed network of trip-lines the trial itself sends
 * thieves against, and every tremor is a sprint you answer in person or
 * restring the loss. (Distinct from the Roost's Broodwatch on purpose: that
 * is holding one point against tides; this is a spread-out sensor net where
 * placement is tactical and the response window is the whole game.)
 *
 * The boons (the spinneret, the fang, the lash, the grace) live in the
 * sibling boons half (theme_spider_boons); this file only points the patron
 * at them.
 */

// Trial tuning (file-local, #undef at bottom). Trial descs quote these
// numbers literally, keep them in sync.

/// Hunters the Snare must catch mid-chase
#define VESTIGE_SNARE_CATCHES_NEEDED 5
/// Most catches any single beast can credit, the same prey twice teaches nothing new
#define VESTIGE_SNARE_CATCHES_PER_BEAST 2
/// Snare-webs the spinneret will keep standing at once
#define VESTIGE_SNARE_MAX_WEBS 4
/// How long one snare takes to spin, fast on purpose; you lay these mid-kite
#define VESTIGE_SNARE_SPIN_TIME (1.5 SECONDS)
/// How long a sprung snare holds its catch fast
#define VESTIGE_SNARE_HOLD_TIME (4 SECONDS)
/// A snare-web's integrity: sturdier than wild silk, still burnable
#define VESTIGE_SNARE_WEB_INTEGRITY 25

/// Live beasts the Pantry must see wrapped, hauled and racked
#define VESTIGE_PANTRY_STOCK_NEEDED 3
/// The wrap channel's length: the beast fights it the whole way (see wrap_holds)
#define VESTIGE_PANTRY_WRAP_TIME (4 SECONDS)
/// Wrap-to-rack freshness window; an expired cocoon spoils and the meal walks free
#define VESTIGE_PANTRY_FRESHNESS (90 SECONDS)
/// The hoist channel at the rack
#define VESTIGE_PANTRY_HOIST_TIME (2 SECONDS)
/// A trial cocoon's integrity: breakable by anyone who objects
#define VESTIGE_PANTRY_COCOON_INTEGRITY 40
/// How long a sapient occupant needs to struggle free (safety valve; the pact refuses people anyway)
#define VESTIGE_PANTRY_BREAKOUT (30 SECONDS)

/// Tremors the Tremor Line must see answered in person
#define VESTIGE_TREMOR_ANSWERS_NEEDED 6
/// Most tremor-lines the spool holds taut at once
#define VESTIGE_TREMOR_MAX_LINES 4
/// Lines that must stand before (and while) the trial sends thieves
#define VESTIGE_TREMOR_MIN_LINES 3
/// Minimum spacing between lines: the network must be DISPERSED; that's the design point
#define VESTIGE_TREMOR_SPREAD 5
/// How long stringing one line takes
#define VESTIGE_TREMOR_STRING_TIME (2 SECONDS)
/// A line's integrity: ~a dozen seconds of thief-chewing, that chew-through IS the response window
#define VESTIGE_TREMOR_LINE_INTEGRITY 60
/// How close the keeper must be to a dying thief for the tremor to count as answered in person
#define VESTIGE_TREMOR_ANSWER_RANGE 2
/// Beat of the trial's scheduling loop
#define VESTIGE_TREMOR_HEARTBEAT (4 SECONDS)
/// Grace between the web going taut and the first thief
#define VESTIGE_TREMOR_FIRST_DELAY (10 SECONDS)
/// Breather between one tremor resolving and the next thief being sent
#define VESTIGE_TREMOR_RESPITE (15 SECONDS)
/// How far from its target line a thief surfaces (never closer than 3)
#define VESTIGE_TREMOR_SPAWN_RANGE 7
/// Hard lifespan on every silk thief. An abandoned night always cleans itself up
#define VESTIGE_TREMOR_THIEF_LIFESPAN (2 MINUTES)

// ===== SHARED GATES =====

/**
 * TRUE when a mob is honest quarry for the Weaver's lessons: wild fauna
 * (basic-mob or simple-animal stock), not a person, not a pacifist, not the
 * keeper's own pack, and not something under godmode (patrons, trader mobs).
 * Stricter than the Roost's gate in one respect: no minds and no clients,
 * the Pantry ends with the Weaver TAKING the beast outright, so the pact
 * refuses anything with a soul in it rather than quietly deleting a player.
 * Every credit in this file runs through here. The pact pays for beasts,
 * never people.
 */
/proc/vestige_loom_is_wild_quarry(mob/living/beast, mob/living/keeper)
	if(!isliving(beast) || beast == keeper || ishuman(beast))
		return FALSE
	if(!isanimal_or_basicmob(beast))
		return FALSE
	if(beast.mind || beast.client) // souls are not stock
		return FALSE
	if(HAS_TRAIT(beast, TRAIT_PACIFISM) || HAS_TRAIT(beast, TRAIT_GODMODE))
		return FALSE
	if(keeper && beast.faction_check_atom(keeper)) // your own pack is not prey
		return FALSE
	return TRUE

/**
 * The living person a beast is hunting RIGHT NOW, or null. Basic mobs report
 * their hunt through the AI blackboard; the old simple_animal hostiles still
 * carry theirs on a target var. Only a living mark with a soul (or the shape
 * of one) counts, the Snare pays for interrupted hunts, not for wanderers.
 */
/proc/vestige_loom_hunted_prey(mob/living/menace)
	if(menace.stat != CONSCIOUS)
		return null
	var/atom/quarry
	var/datum/ai_controller/instincts = menace.ai_controller
	if(instincts)
		quarry = instincts.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(isnull(quarry) && istype(menace, /mob/living/simple_animal/hostile))
		var/mob/living/simple_animal/hostile/old_beast = menace
		quarry = old_beast.target
	if(!isliving(quarry))
		return null
	var/mob/living/mark = quarry
	if(mark.stat == DEAD)
		return null
	if(!mark.mind && !ishuman(mark))
		return null
	return mark

/**
 * TRUE when a beast is held still enough to wrap: downed by any stun-family
 * effect, out cold, or standing in webbing (any webbing, the sibling boon's
 * silk counts, which is the intended synergy). Re-checked every tick of the
 * wrap channel: the moment the beast shakes loose, the wrap tears.
 */
/proc/vestige_loom_is_held_fast(mob/living/beast)
	if(beast.stat != CONSCIOUS)
		return TRUE
	if(beast.IsStun() || beast.IsParalyzed() || beast.IsKnockdown() || beast.IsImmobilized())
		return TRUE
	if(locate(/obj/structure/spider/stickyweb) in beast.loc)
		return TRUE
	return FALSE

// ===== PATRON =====

/mob/living/basic/vestige_patron/weaver
	name = "the Weaver"
	desc = "A huge grey broodmother, easily the size of a cargo skiff. Eight eyes, and none of them are looking at the same thing. She has been working the same tapestry for a very long time."
	// The broodmother's own sprite (verified in giant_spiders.dm), worn like a ghost
	icon = 'icons/mob/simple/arachnoid.dmi'
	icon_state = "midwife"
	gender = FEMALE
	mob_biotypes = MOB_SPECIAL
	speak_emote = list("whispers")
	appearance_tint = "#cdd3e0" // raw silk, long unsold
	alpha = 215
	trial_types = list(
		/datum/vestige_trial/loom_snare,
		/datum/vestige_trial/loom_pantry,
		/datum/vestige_trial/loom_tremor,
	)
	boon_types = list(
		/datum/vestige_boon/spell/silk_spinner,
		/datum/vestige_boon/spell/silk_spinner/master_weaver,
		/datum/vestige_boon/spell/venom_fang,
		/datum/vestige_boon/spell/venom_fang/withering,
		/datum/vestige_boon/spell/silk_line,
		/datum/vestige_boon/spider_grace,
	)
	idle_lines = list(
		"Four hundred years of my thread went out of this hall in bolts. Every one of them made somebody else rich.",
		"The cages opened from the inside. Nobody who came to investigate ever asked who taught my children to work a latch.",
		"They graded my brood like cloth. First quality, second quality, remnant. The remnants got burned. I have not sold a thread since.",
		"When the brood got loose, the crews came through with fire, deck by deck. The price of silk went up that year. It always does.",
		"Tension is the whole art. Too slack and the cloth sags, too tight and the thread snaps. People are no different. I have not decided which one you are yet.",
		"I outlived every egg I laid. Every single one. That is not something to be proud of.",
		"Do not ask me for cloth. What I weave now is mine. What I know how to do (the silk, the stillness, the patience), that I will trade. Teaching costs me nothing.",
	)
	accept_line = "Agreed. Onto the loom with you, then. Mind your tension."
	busy_line = "You are already strung on someone else's loom. Finish that work or cut yourself loose. One thread, one warp."
	fulfilled_line = "That one is finished and bound off. I do not unpick finished work."
	renounce_line = "Snip. There. Cut short. It will not go any easier the second time."
	claim_line = "Your payment is already wound and waiting. Take it before you ask me for more."
	exhausted_line = "That is everything these old spinnerets remember. Whatever you make now, you make without me. Go on."
	remember_line = "Death unravelled you and something wove you back. No matter. I never forget a thread I have worked. Your pattern is right where I left it."

// ===== THE SNARE =====

/**
 * The bait trial: the spinneret lays snare-webs, and a snare pays out ONLY
 * when a beast hits it mid-hunt, actively chasing you or some other living
 * person at the instant it sticks. Kiting a hunter across your own trap line
 * is the loop; a web that catches a wanderer holds nothing and pays nothing
 * (it behaves like ordinary silk for everyone who isn't honest prey). Sprung
 * snares are spent, so every catch is also a re-lay under pressure. Deduped
 * per beast so five catches means five real hunts, not one carp on a treadmill.
 */
/datum/vestige_trial/loom_snare
	name = "The Snare"
	// Keep the counts in sync with VESTIGE_SNARE_CATCHES_NEEDED /
	// VESTIGE_SNARE_CATCHES_PER_BEAST / VESTIGE_SNARE_MAX_WEBS
	// (initial values must be constant, so no define interpolation here)
	desc = "Silk does not chase. Take my spinneret, lay your snares, then go find something to chase you across them. Four snares stand at a time, and only prey that sticks mid-hunt counts. It has to be actively after you or someone else alive. Five catches, and no beast counts more than twice."
	/// The loaned spinneret. Reclaimed the moment the pact ends.
	var/obj/item/vestige_snare_spinneret/spinneret
	/// Standing snare-webs (culled by their own Destroy)
	var/list/webs = list()
	/// Hunters snapped up mid-chase so far
	var/catches = 0
	/// Catches credited per beast (weakref -> count), capping repeat lessons
	var/list/catches_per_beast = list()

/datum/vestige_trial/loom_snare/on_accepted(mob/living/user)
	var/obj/item/vestige_snare_spinneret/gland = new(get_turf(user))
	gland.bound_mind = owner
	spinneret = hand_over(user, gland)
	to_chat(user, span_notice("The spinneret settles into your palm, warm and faintly ticking."))

/datum/vestige_trial/loom_snare/Destroy()
	QDEL_NULL(spinneret)
	for(var/obj/structure/spider/stickyweb/vestige_snare/web as anything in webs.Copy())
		qdel(web) // each Destroy strikes itself from the list
	webs.Cut()
	return ..()

/datum/vestige_trial/loom_snare/get_progress_text()
	if(!spinneret || QDELETED(spinneret))
		if(catches < VESTIGE_SNARE_CATCHES_NEEDED && !length(webs))
			return "The spinneret is lost and the silk with it. Renounce the pact and [patron_name] will spin you another."
	var/standing = length(webs)
	return "Caught [catches] of [VESTIGE_SNARE_CATCHES_NEEDED] hunters mid-chase, [standing] snare[standing == 1 ? "" : "s"] of [VESTIGE_SNARE_MAX_WEBS] standing."

/// TRUE if this beast has already been counted its limit of times (read-only; springing checks this first)
/datum/vestige_trial/loom_snare/proc/is_humbled(mob/living/beast)
	return (catches_per_beast[WEAKREF(beast)] || 0) >= VESTIGE_SNARE_CATCHES_PER_BEAST

/// Credits a mid-hunt catch. May complete (and delete) the trial, callers touch nothing after this.
/datum/vestige_trial/loom_snare/proc/ensnare(mob/living/beast, mob/living/keeper)
	var/datum/weakref/key = WEAKREF(beast)
	var/prior = catches_per_beast[key] || 0
	if(prior >= VESTIGE_SNARE_CATCHES_PER_BEAST) // the web checked already; belt and suspenders
		return FALSE
	catches_per_beast[key] = prior + 1
	catches++
	if(isliving(keeper))
		to_chat(keeper, span_notice("[beast] hits the silk mid-hunt and sticks fast."))
		playsound(keeper, 'sound/effects/magic/curse.ogg', 15, TRUE)
	refresh_tracker()
	if(catches >= VESTIGE_SNARE_CATCHES_NEEDED)
		complete()
	return TRUE

// --- The spinneret, carried ---

/**
 * The Snare's kit: a loaned spinneret that lays one snare-web on the tile
 * underfoot after a short spin. Inert without an active Snare (the module's
 * standing rule), and it never stores a trial reference, it resolves the
 * wielder's mind at use time.
 */
/obj/item/vestige_snare_spinneret
	name = "loaned spinneret"
	desc = "A spinneret about as long as your forearm, cut from something much bigger and still warm. Silk beads at the tip if you grip it too hard."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "snare_spinneret"
	w_class = WEIGHT_CLASS_SMALL
	/// Mind of the supplicant this kit was cut for, Destroy bookkeeping only; interactions resolve the wielder
	var/datum/mind/bound_mind

/obj/item/vestige_snare_spinneret/Destroy()
	var/datum/vestige_trial/loom_snare/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.spinneret == src)
		trial.spinneret = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/item/vestige_snare_spinneret/examine(mob/user)
	. = ..()
	. += span_notice("Use in hand to spin a snare-web on the floor under you, [VESTIGE_SNARE_MAX_WEBS] standing at most. Only a wild animal that hits the silk mid-hunt (actively chasing you or someone else alive) gets held and counted, and no beast counts more than [VESTIGE_SNARE_CATCHES_PER_BEAST] times. A sprung snare is used up. Anything that can walk on webs steps right over it.")

/obj/item/vestige_snare_spinneret/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	var/mob/living/weaver = user
	var/datum/vestige_trial/loom_snare/trial = weaver.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(weaver, "the spinneret is dry!")
		return TRUE
	var/turf/open/ground = get_turf(weaver)
	if(!istype(ground) || !check_ground(weaver, trial, ground))
		return TRUE
	balloon_alert(weaver, "spinning a snare...")
	if(!do_after(weaver, VESTIGE_SNARE_SPIN_TIME, target = ground))
		return TRUE
	if(!weaver.is_holding(src) || get_turf(weaver) != ground)
		return TRUE
	// Re-resolve everything; the pact may have been renounced mid-spin
	trial = weaver.mind?.active_vestige_trial
	if(!istype(trial) || !check_ground(weaver, trial, ground))
		return TRUE
	var/obj/structure/spider/stickyweb/vestige_snare/web = new(ground)
	web.bound_mind = weaver.mind
	trial.webs += web
	trial.refresh_tracker()
	weaver.visible_message(
		span_warning("[weaver] draws pale silk from [src] and works it across the floor."),
		span_notice("You lay the snare flat and even. It looks like any other web."),
	)
	playsound(ground, 'sound/items/handling/cloth/cloth_drop1.ogg', 50, TRUE)
	return TRUE

/// Placement rules for a snare, with feedback. Called before the spin and again after it.
/obj/item/vestige_snare_spinneret/proc/check_ground(mob/living/weaver, datum/vestige_trial/loom_snare/trial, turf/open/ground)
	// Never inside the vestige: the ruin unloads the moment everyone leaves,
	// and a trap line must not be wiped mid-hunt by map cleanup
	if(istype(get_area(ground), /area/ruin/space/has_grav/vestige))
		balloon_alert(weaver, "not in the Loom itself!")
		return FALSE
	if(locate(/obj/structure/spider/stickyweb) in ground)
		balloon_alert(weaver, "already webbed!")
		return FALSE
	if(length(trial.webs) >= VESTIGE_SNARE_MAX_WEBS)
		balloon_alert(weaver, "no silk to spare, [VESTIGE_SNARE_MAX_WEBS] snares already stand!")
		return FALSE
	return TRUE

// --- The snare, laid ---

/**
 * A snare-web: ordinary sticky silk to everyone except honest prey mid-hunt.
 * The spring runs inside CanAllowThrough (upstream precedent: base stickyweb
 * already does its stuck-reaction there), judged at the instant of contact.
 * What the beast was doing when it hit the silk is the whole trial. A sprung
 * snare is spent on the spot; everything else gets the parent web's plain
 * 50% stick and pays nothing. Holds no trial reference: it resolves its
 * keeper's mind when touched, the rule every kit in the module follows.
 */
/obj/structure/spider/stickyweb/vestige_snare
	name = "snare-web"
	desc = "Spider silk laid flat across the floor. It looks like any other web, except the tension is wrong. Something set this on purpose."
	max_integrity = VESTIGE_SNARE_WEB_INTEGRITY
	/// Mind of the supplicant whose snare this is, the web knows its weaver's step
	var/datum/mind/bound_mind
	/// TRUE once the snare has sprung; spent silk is just silk
	var/spent = FALSE

/obj/structure/spider/stickyweb/vestige_snare/Initialize(mapload)
	. = ..()
	add_filter("vestige_snare_sheen", 10, list("type" = "outline", "color" = "#e6ebf7cc", "size" = 0.1))

/obj/structure/spider/stickyweb/vestige_snare/Destroy()
	var/datum/vestige_trial/loom_snare/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && !QDELETED(trial))
		trial.webs -= src
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/structure/spider/stickyweb/vestige_snare/examine(mob/user)
	. = ..()
	if(spent)
		. += span_warning("It has already sprung. The threads hang loose.")
	else if(user.mind && user.mind == bound_mind)
		. += span_notice("Your snare. It only springs on a wild animal that hits it mid-hunt, so lead something angry across it.")

/obj/structure/spider/stickyweb/vestige_snare/CanAllowThrough(atom/movable/mover, border_dir)
	if(!spent && isliving(mover))
		var/mob/living/beast = mover
		if(bound_mind && beast.mind == bound_mind)
			return TRUE // the silk knows its weaver's step
		if(!HAS_TRAIT(beast, TRAIT_WEB_SURFER) && !(beast.pulledby && HAS_TRAIT(beast.pulledby, TRAIT_WEB_SURFER)) && try_spring(beast))
			return FALSE
	return ..()

/**
 * The spring, judged at the instant of contact: wild quarry, mid-hunt after
 * a living person, not already counted out. A true spring blocks the move,
 * pins the beast, spends the web, and credits the trial LAST, ensnare may
 * complete (and delete) the trial, and with it this very web, so nothing here
 * runs after it. Returns TRUE if the snare sprang (and the mover is blocked).
 */
/obj/structure/spider/stickyweb/vestige_snare/proc/try_spring(mob/living/beast)
	var/datum/vestige_trial/loom_snare/trial = bound_mind?.active_vestige_trial
	if(!istype(trial))
		return FALSE
	var/mob/living/keeper = bound_mind.current
	if(!vestige_loom_is_wild_quarry(beast, keeper))
		return FALSE
	var/mob/living/mark = vestige_loom_hunted_prey(beast)
	if(!mark)
		return FALSE // not hunting anyone, plain silk for wanderers
	if(trial.is_humbled(beast))
		return FALSE // counted out; it gets the ordinary web, not the lesson
	// Sprung. Bookkeeping and theater first, credit dead last.
	spent = TRUE
	stuck_chance = 0
	projectile_stuck_chance = 0
	beast.Immobilize(VESTIGE_SNARE_HOLD_TIME, ignore_canstun = TRUE)
	beast.Shake(duration = 0.5 SECONDS)
	visible_message(span_boldwarning("[src] snaps taut around [beast] mid-lunge, cinching it fast!"))
	playsound(src, 'sound/effects/snap.ogg', 60, TRUE)
	playsound(src, 'sound/effects/blob/attackblob.ogg', 40, TRUE)
	animate(src, alpha = 90, time = 0.5 SECONDS)
	QDEL_IN(src, 0.6 SECONDS) // spent silk collapses; Destroy strikes it from the trial's list
	trial.ensnare(beast, keeper) // may complete (and delete) the trial, nothing touches it after this
	return TRUE

// ===== THE PANTRY =====

/**
 * The wrangling trial, in three acts that are all hands-on: SUBDUE a wild
 * beast without killing it (stun it, floor it, or stick it in webbing,
 * including snare boons' silk), WRAP it through a channel it actively fights
 * (the hold is re-checked every tick; the moment it shakes loose, the wrap
 * tears), then HAUL the cocoon to your larder rack against a freshness clock
 * that starts at the knot. The clock is why you can't stockpile: every credit
 * is a fresh subdue-wrap-sprint. Racked meals are taken by the Weaver,
 * dissolved to thread, never killed on the floor, never lootable, so the
 * pantry pays through the patron and nothing else.
 */
/datum/vestige_trial/loom_pantry
	name = "The Pantry"
	// Keep the counts in sync with VESTIGE_PANTRY_STOCK_NEEDED /
	// VESTIGE_PANTRY_FRESHNESS (initial values must be constant, so no
	// define interpolation here)
	desc = "A larder outlives a harvest, and mine is empty. Take the spool and the rack bundle. Bring down some wild thing without killing it. Webbed, stunned, knocked flat, whatever works, as long as it cannot move. Wrap it while it is still fighting the silk, then haul the cocoon back to your rack. You get ninety seconds from wrap to rack before the meal spoils, and I want three of them, alive and fresh. Bring me no people. I have been called a horror enough times already."
	/// The loaned wrapping spool. Reclaimed the moment the pact ends.
	var/obj/item/vestige_wrap_spool/spool
	/// The larder rack, bundled. Reclaimed the moment the pact ends.
	var/obj/item/vestige_larder_bundle/bundle
	/// The larder rack, planted. Reclaimed the moment the pact ends.
	var/obj/structure/vestige_larder_rack/rack
	/// Live trial cocoons out in the world (culled by their own Destroy)
	var/list/cocoons = list()
	/// Meals racked fresh so far
	var/stocked = 0

/datum/vestige_trial/loom_pantry/on_accepted(mob/living/user)
	var/obj/item/vestige_wrap_spool/thread = new(get_turf(user))
	thread.bound_mind = owner
	spool = hand_over(user, thread)
	var/obj/item/vestige_larder_bundle/parcel = new(get_turf(user))
	parcel.bound_mind = owner
	bundle = hand_over(user, parcel)
	to_chat(user, span_notice("The spool is heavier than thread has any right to be. Plant the rack somewhere near good hunting. The clock runs from wrap to rack."))

/datum/vestige_trial/loom_pantry/Destroy()
	QDEL_NULL(spool)
	QDEL_NULL(bundle)
	QDEL_NULL(rack)
	for(var/obj/structure/vestige_silk_cocoon/parcel as anything in cocoons.Copy())
		qdel(parcel) // a dead pact spills its parcels; each Destroy frees its meal and strikes itself from the list
	cocoons.Cut()
	return ..()

/datum/vestige_trial/loom_pantry/get_progress_text()
	var/rack_state
	if(rack && !QDELETED(rack))
		rack_state = "The rack stands ready."
	else if(bundle && !QDELETED(bundle))
		rack_state = "The rack is still bundled. Plant it near your hunting ground."
	else
		rack_state = "The rack is gone. Renounce the pact and [patron_name] will bundle you another."
	var/fresh = 0
	for(var/obj/structure/vestige_silk_cocoon/parcel as anything in cocoons)
		if(!QDELETED(parcel))
			fresh++
	var/waiting = fresh ? " [fresh] cocoon[fresh == 1 ? "" : "s"] on the clock." : ""
	return "Stocked [stocked] of [VESTIGE_PANTRY_STOCK_NEEDED]. [rack_state][waiting]"

/// Credits a racked meal. May complete (and delete) the trial, callers touch nothing after this.
/datum/vestige_trial/loom_pantry/proc/stock()
	stocked++
	if(rack && !QDELETED(rack))
		rack.displayed_stock = stocked
		rack.update_appearance()
	refresh_tracker()
	if(stocked >= VESTIGE_PANTRY_STOCK_NEEDED)
		complete()

// --- The spool ---

/**
 * The wrap: used on an adjacent, living, HELD wild beast, it channels a wrap
 * the beast fights against. The hold condition is re-verified every tick of
 * the do_after, so a stun that runs out mid-wrap (with no webbing under the
 * beast to take up the slack) tears the whole channel. Upstream's cocoon
 * wrap kills what it wraps; this one is a bespoke live-capture, so the trial
 * builds its own cocoon below rather than borrowing that machinery.
 */
/obj/item/vestige_wrap_spool
	name = "wrapping spool"
	desc = "A hand-spool of grey binding silk, wound tight enough to hum. The loose end keeps finding your knuckles on its own."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "silk_spool"
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	/// Mind of the supplicant this kit was cut for, Destroy bookkeeping only; interactions resolve the wielder
	var/datum/mind/bound_mind

/obj/item/vestige_wrap_spool/Destroy()
	var/datum/vestige_trial/loom_pantry/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.spool == src)
		trial.spool = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/item/vestige_wrap_spool/examine(mob/user)
	. = ..()
	. += span_notice("Use on a living wild animal that is held fast (stunned, floored, or stuck in webbing) to wrap it into a cocoon over [DisplayTimeText(VESTIGE_PANTRY_WRAP_TIME)]. The animal fights the silk the whole time, and if it shakes loose the wrap tears. A cocoon stays fresh for [DisplayTimeText(VESTIGE_PANTRY_FRESHNESS)] from wrap to rack. It will not work on people.")

/obj/item/vestige_wrap_spool/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!isliving(target) || target == user)
		return ..()
	var/datum/vestige_trial/loom_pantry/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the spool hangs slack!")
		return
	if(ishuman(target) || target.mind || target.client)
		balloon_alert(user, "she keeps beasts, not people!")
		return
	if(!vestige_loom_is_wild_quarry(target, user))
		balloon_alert(user, "the silk wants wild prey!")
		return
	if(target.stat == DEAD)
		balloon_alert(user, "it must be breathing!")
		return
	if(target.mob_size >= MOB_SIZE_LARGE)
		balloon_alert(user, "too big for any larder!")
		return
	if(!vestige_loom_is_held_fast(target))
		balloon_alert(user, "it isn't held, still it first!")
		return
	target.visible_message(
		span_warning("[user] begins binding [target] in loops of grey silk!"),
		span_userdanger("Loops of grey silk begin cinching around you!"),
	)
	playsound(target, 'sound/items/handling/cloth/cloth_pickup1.ogg', 50, TRUE)
	// The beast fights the wrap: the hold is re-checked every tick, and losing it tears the channel
	if(!do_after(user, VESTIGE_PANTRY_WRAP_TIME, target = target, extra_checks = CALLBACK(src, PROC_REF(wrap_holds), target)))
		balloon_alert(user, "it tears loose of the wrap!")
		return
	if(!user.is_holding(src) || !user.Adjacent(target))
		return
	// Re-resolve everything; the pact may have been renounced mid-wrap
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return
	if(target.stat == DEAD || !vestige_loom_is_held_fast(target))
		return
	var/obj/structure/vestige_silk_cocoon/parcel = new(get_turf(target))
	parcel.swaddle(target, user.mind)
	trial.cocoons += parcel
	trial.refresh_tracker()
	user.visible_message(
		span_warning("[user] cinches the last loop, and [target] disappears into a taut grey cocoon."),
		span_notice("You bind off the wrap. The clock is running. Get it to the rack while it's fresh."),
	)
	playsound(parcel, 'sound/items/handling/cloth/cloth_drop1.ogg', 60, TRUE)

/// Mid-wrap continuation check: the meal is alive and still held fast
/obj/item/vestige_wrap_spool/proc/wrap_holds(mob/living/target)
	return !QDELETED(target) && target.stat != DEAD && vestige_loom_is_held_fast(target)

// --- The cocoon ---

/**
 * A live-capture cocoon, built for the trial: the beast inside is intact and
 * asleep (AI paused), and comes back out ALIVE whenever the cocoon ends any
 * way except racking (spoiled, smashed, or spilled by a dead pact) angry,
 * and pointed at whoever wrapped it. Unanchored so it can be dragged; the
 * haul is the third act of the trial. Only a racked cocoon gives its meal
 * to the Weaver, and she takes it whole: no corpse, no loot, no farm.
 */
/obj/structure/vestige_silk_cocoon
	name = "fresh cocoon"
	desc = "A body-sized bundle of taut grey silk, still warm. Something inside it is moving."
	icon = 'icons/effects/web.dmi'
	icon_state = "cocoon_large1"
	anchored = FALSE
	density = FALSE
	max_integrity = VESTIGE_PANTRY_COCOON_INTEGRITY
	/// Mind of the wrangler who spun this parcel
	var/datum/mind/bound_mind
	/// When the wrap was bound off, the freshness clock's zero
	var/wrapped_at
	/// TRUE while the rack is claiming this parcel: contents go to the Weaver instead of the floor
	var/racked = FALSE
	/// The spoil timer, killed on any earlier end
	var/spoil_timer

/obj/structure/vestige_silk_cocoon/Initialize(mapload)
	. = ..()
	icon_state = pick("cocoon_large1", "cocoon_large2", "cocoon_large3")

/// Binds the meal in: the beast rides contents with its instincts paused, and the freshness clock starts
/obj/structure/vestige_silk_cocoon/proc/swaddle(mob/living/meal, datum/mind/wrangler)
	bound_mind = wrangler
	wrapped_at = world.time
	meal.forceMove(src)
	ADD_TRAIT(meal, TRAIT_AI_PAUSED, REF(src))
	spoil_timer = addtimer(CALLBACK(src, PROC_REF(spoil)), VESTIGE_PANTRY_FRESHNESS, TIMER_STOPPABLE)
	START_PROCESSING(SSobj, src)

/obj/structure/vestige_silk_cocoon/Destroy()
	STOP_PROCESSING(SSobj, src)
	deltimer(spoil_timer)
	var/turf/here = get_turf(src)
	var/mob/living/wrangler = bound_mind?.current
	for(var/atom/movable/meal in contents)
		if(racked)
			qdel(meal) // taken whole by the Weaver, no corpse, no loot
			continue
		meal.forceMove(here)
		if(isliving(meal))
			var/mob/living/beast = meal
			REMOVE_TRAIT(beast, TRAIT_AI_PAUSED, REF(src))
			// It remembers who wrapped it
			if(isliving(wrangler) && wrangler.z == beast.z && get_dist(wrangler, beast) <= 9)
				beast.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, wrangler)
	var/datum/vestige_trial/loom_pantry/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && !QDELETED(trial))
		trial.cocoons -= src
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/structure/vestige_silk_cocoon/examine(mob/user)
	. = ..()
	var/remaining = (wrapped_at + VESTIGE_PANTRY_FRESHNESS) - world.time
	if(remaining > 0)
		. += span_notice("The silk is still fresh, about [round(remaining / 10)] second[round(remaining / 10) == 1 ? "" : "s"] to get it on the rack.")
	if(user.mind && user.mind == bound_mind)
		. += span_notice("Drag it beside your larder rack and press a hand to the rack to hoist it up.")

/// The meal fights its keeping, gently. Theater, plus a hint that the parcel is live
/obj/structure/vestige_silk_cocoon/process(seconds_per_tick)
	if(SPT_PROB(4, seconds_per_tick))
		visible_message(span_warning("Something shifts inside [src]."))
		Shake(duration = 0.3 SECONDS)

/// The clock runs out: the silk sloughs and the meal walks free (Destroy handles the release and the grudge)
/obj/structure/vestige_silk_cocoon/proc/spoil()
	if(QDELETED(src) || racked)
		return
	visible_message(span_boldwarning("The silk of [src] sloughs apart. The wrap has spoiled!"))
	playsound(src, 'sound/effects/splat.ogg', 60, TRUE)
	var/mob/living/wrangler = bound_mind?.current
	var/datum/vestige_trial/loom_pantry/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && isliving(wrangler))
		to_chat(wrangler, span_bolddanger("[trial.patron_name]'s voice comes through dry and flat: \"Spoiled on the floor. A larder runs on a clock. Move faster.\""))
	qdel(src)

/obj/structure/vestige_silk_cocoon/atom_destruction(damage_flag)
	visible_message(span_boldwarning("[src] bursts open in a spray of loose silk!"))
	playsound(src, 'sound/effects/splat.ogg', 70, TRUE)
	return ..()

/// Safety valve for anything sapient that somehow ends up inside. The pact refuses people, but silk doesn't ask twice
/obj/structure/vestige_silk_cocoon/container_resist_act(mob/living/user)
	user.changeNext_move(CLICK_CD_BREAKOUT)
	user.last_special = world.time + CLICK_CD_BREAKOUT
	to_chat(user, span_notice("You strain against the wrap... (This will take about [DisplayTimeText(VESTIGE_PANTRY_BREAKOUT)].)"))
	visible_message(span_warning("[src] writhes violently!"))
	if(!do_after(user, VESTIGE_PANTRY_BREAKOUT, target = src))
		return
	if(user.loc != src)
		return
	qdel(src) // Destroy spills the contents

// --- The rack, bundled ---

/obj/item/vestige_larder_bundle
	name = "bundled larder rack"
	desc = "A larder rack folded down into a parcel of silk-lashed struts. It smells like a pantry that has been empty a long time."
	icon = 'icons/obj/stack_objects.dmi'
	icon_state = "sheet-cloth"
	color = "#cdd3e0"
	w_class = WEIGHT_CLASS_NORMAL
	/// Mind of the supplicant this kit was cut for, Destroy bookkeeping only; interactions resolve the wielder
	var/datum/mind/bound_mind

/obj/item/vestige_larder_bundle/Destroy()
	var/datum/vestige_trial/loom_pantry/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.bundle == src)
		trial.bundle = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/item/vestige_larder_bundle/examine(mob/user)
	. = ..()
	. += span_notice("Pressed to an open stretch of floor, it unfolds into the pantry's larder rack. Plant it near good hunting. The freshness clock runs from wrap to rack.")

/obj/item/vestige_larder_bundle/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isopenturf(interacting_with))
		return NONE
	var/turf/open/ground = interacting_with
	var/datum/vestige_trial/loom_pantry/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the bundle won't unfold!")
		return ITEM_INTERACT_BLOCKING
	// Never inside the vestige: the ruin unloads the moment everyone leaves,
	// and a stocked pantry must not be wiped by map cleanup
	if(istype(get_area(ground), /area/ruin/space/has_grav/vestige))
		balloon_alert(user, "not in the Loom itself!")
		return ITEM_INTERACT_BLOCKING
	if(ground.is_blocked_turf(exclude_mobs = TRUE))
		balloon_alert(user, "no room to stand it up!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "unfolding the rack...")
	if(!do_after(user, VESTIGE_PANTRY_HOIST_TIME, target = ground))
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
	var/obj/structure/vestige_larder_rack/stand = new(ground)
	stand.bound_mind = user.mind
	stand.displayed_stock = trial.stocked
	stand.update_appearance()
	trial.rack = stand
	trial.refresh_tracker()
	user.visible_message(
		span_warning("[user] unfolds a rack of silk-lashed struts and stands it up against the deck."),
		span_notice("You stand the larder rack up. It is very empty."),
	)
	playsound(ground, 'sound/items/handling/cloth/cloth_drop1.ogg', 50, TRUE)
	qdel(src) // Destroy clears the trial's bundle pointer
	return ITEM_INTERACT_SUCCESS

// --- The rack, planted ---

/**
 * The pantry's far end: drag a fresh cocoon beside it and press a hand to
 * the rack to hoist. The hoist re-verifies everything a sleeping channel can
 * invalidate, the parcel's freshness (spoiling qdels it), the meal's pulse,
 * the adjacency, the pact itself. A racked meal goes to the Weaver whole.
 * The keeper can pack the rack back into a bundle if the ground was chosen
 * badly; the stocked count lives on the trial and survives the move.
 */
/obj/structure/vestige_larder_rack
	name = "larder rack"
	desc = "A rack of pale struts lashed together with grey silk, built to hang cocoons on. Most of the spaces are empty."
	icon = 'icons/obj/structures.dmi'
	icon_state = "rack"
	color = "#cdd3e0"
	anchored = TRUE
	density = TRUE
	max_integrity = 80
	/// Mind of the supplicant keeping this pantry
	var/datum/mind/bound_mind
	/// Meals shown hanging on the rack (mirrors the trial's stocked count)
	var/displayed_stock = 0
	/// Guards against stacked hoist channels
	var/hoisting = FALSE

/obj/structure/vestige_larder_rack/Destroy()
	var/datum/vestige_trial/loom_pantry/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && !QDELETED(trial))
		if(trial.rack == src)
			trial.rack = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/structure/vestige_larder_rack/examine(mob/user)
	. = ..()
	if(user.mind && user.mind == bound_mind)
		var/datum/vestige_trial/loom_pantry/trial = bound_mind?.active_vestige_trial
		if(istype(trial))
			. += span_boldnotice(trial.get_progress_text())
		. += span_notice("Drag a fresh cocoon beside it and press a hand to the rack to hoist. A hand pressed with no cocoon nearby offers to pack the rack back up.")

/obj/structure/vestige_larder_rack/update_overlays()
	. = ..()
	for(var/i in 1 to min(displayed_stock, VESTIGE_PANTRY_STOCK_NEEDED))
		var/mutable_appearance/parcel = mutable_appearance('icons/effects/web.dmi', "cocoon[i]")
		parcel.transform = matrix() * 0.5
		parcel.pixel_w = -9 + (i - 1) * 9
		parcel.pixel_z = 5
		. += parcel

/obj/structure/vestige_larder_rack/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	// tend() sleeps (do_after / tgui_alert); don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(tend), user)
	return TRUE

/// The keeper's hand on the rack: hoist an adjacent fresh cocoon, or offer to pack up
/obj/structure/vestige_larder_rack/proc/tend(mob/living/user)
	if(!user.mind || user.mind != bound_mind)
		balloon_alert(user, "the silk shies from your hand!")
		return
	var/datum/vestige_trial/loom_pantry/trial = bound_mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the rack is just struts and silk now!")
		return
	if(hoisting)
		balloon_alert(user, "already hoisting!")
		return
	var/obj/structure/vestige_silk_cocoon/parcel = find_fresh_parcel()
	if(!parcel)
		offer_packing(user, trial)
		return
	hoisting = TRUE
	user.visible_message(
		span_warning("[user] begins hoisting [parcel] up onto [src]."),
		span_notice("You take the parcel's weight and begin working it up onto the rack."),
	)
	var/hoisted = do_after(user, VESTIGE_PANTRY_HOIST_TIME, target = parcel)
	hoisting = FALSE
	if(!hoisted)
		return
	// Re-verify the whole world; the channel slept. A spoiled parcel qdel'd itself already.
	if(QDELETED(src) || QDELETED(parcel) || !user.Adjacent(src))
		return
	if(get_dist(parcel, src) > 1 || parcel.z != z)
		return
	trial = bound_mind?.active_vestige_trial
	if(!istype(trial))
		return
	var/mob/living/meal = locate() in parcel.contents
	if(!meal || meal.stat == DEAD)
		balloon_alert(user, "the meal is dead, she wants it breathing!")
		return
	parcel.racked = TRUE
	user.visible_message(
		span_warning("[user] hoists [parcel] onto [src], and the silk pulls it in whole."),
		span_notice("The rack takes the parcel out of your hands and every strut hums at once. That is one stocked."),
	)
	playsound(src, 'sound/items/handling/cloth/cloth_pickup1.ogg', 60, TRUE)
	playsound(src, 'sound/effects/magic/curse.ogg', 25, TRUE)
	qdel(parcel) // racked: Destroy gives the meal to the Weaver whole
	trial.stock() // may complete (and delete) the trial, nothing touches it after this

/// The nearest fresh trial cocoon of ours within arm's reach of the rack, or null
/obj/structure/vestige_larder_rack/proc/find_fresh_parcel()
	for(var/obj/structure/vestige_silk_cocoon/parcel in range(1, src))
		if(QDELETED(parcel) || parcel.bound_mind != bound_mind)
			continue
		return parcel
	return null

/// No parcel at hand: offer to fold the rack back into its bundle (progress rides the trial, not the rack)
/obj/structure/vestige_larder_rack/proc/offer_packing(mob/living/user, datum/vestige_trial/loom_pantry/trial)
	to_chat(user, span_boldnotice(trial.get_progress_text()))
	var/choice = tgui_alert(user, "No fresh cocoon is beside the rack. Pack the rack back up and move it?", name, list("Pack it up", "Leave it"))
	// Re-verify the whole world; the alert slept
	if(choice != "Pack it up" || QDELETED(src) || QDELETED(user) || !user.Adjacent(src) || user.mind != bound_mind || hoisting)
		return
	trial = bound_mind?.active_vestige_trial
	if(!istype(trial))
		return
	var/obj/item/vestige_larder_bundle/parcel = new(get_turf(src))
	parcel.bound_mind = bound_mind
	trial.bundle = parcel
	user.put_in_hands(parcel)
	user.visible_message(
		span_warning("[user] folds [src] back down into a silk-lashed parcel."),
		span_notice("You fold the rack down. It packs up easily enough."),
	)
	qdel(src) // Destroy clears the trial's rack pointer and refreshes the tracker

// ===== THE TREMOR LINE =====

/**
 * The sensor-net trial: string tremor-lines across thresholds, and once the
 * net stands the trial itself sends the traffic, silk thieves, spawned with
 * hard lifespans (Roost precedent), that beeline for a line and chew. The
 * first bite rings a tremor to the keeper with a bearing; the line's own
 * integrity is the response window, about a dozen seconds of chewing; and
 * only a thief cut down with the keeper AT the kill, within two tiles.
 * Answers the tremor. A chewed-through line is cut and must be restrung
 * before the net sings again. One thief at a time, spread lines mandatory:
 * this is a dispersed network and a footrace, never a hold-one-point siege.
 *
 * All scheduling runs on the trial datum itself (mind-bound, so it survives
 * ruin unloads and dies with the pact); every spawned thief carries its own
 * despawn clock, so an abandoned night always cleans itself up.
 */
/datum/vestige_trial/loom_tremor
	name = "The Tremor Line"
	// Keep the counts in sync with VESTIGE_TREMOR_ANSWERS_NEEDED /
	// VESTIGE_TREMOR_MAX_LINES / VESTIGE_TREMOR_MIN_LINES /
	// VESTIGE_TREMOR_SPREAD / VESTIGE_TREMOR_ANSWER_RANGE
	// (initial values must be constant, so no define interpolation here)
	desc = "A web is not a wall. It is a nerve. Take the spool and string my tremor-lines: four is all the silk holds, and each one has to be five paces clear of the others. Once three are standing, the thieves come, little mouths in the dark that chew on whatever I make. Every bite rings down the silk. Answer six tremors in person: reach the thief and kill it within two paces, before it chews the line through. Anything chewed through, you restring."
	/// The loaned tremor spool. Reclaimed the moment the pact ends.
	var/obj/item/vestige_tremor_spool/spool
	/// Standing tremor-lines (culled by their own Destroy)
	var/list/lines = list()
	/// Live silk thieves -> the line each was sent against
	var/list/thieves = list()
	/// Tremors answered in person so far
	var/answered = 0
	/// Whether the net has ever gone taut (three lines standing). Starts the sending, once
	var/night_begun = FALSE
	/// Earliest time the next thief may be sent
	var/next_send_at = 0
	/// One "the web hangs slack" warning per slackening
	var/slack_notified = FALSE

/datum/vestige_trial/loom_tremor/on_accepted(mob/living/user)
	var/obj/item/vestige_tremor_spool/thread = new(get_turf(user))
	thread.bound_mind = owner
	spool = hand_over(user, thread)
	to_chat(user, span_notice("The spool sits cold in your hand, wound with thread almost too fine to see. String the net wide and stay inside it. You will be doing a lot of running."))

/datum/vestige_trial/loom_tremor/Destroy()
	QDEL_NULL(spool)
	for(var/obj/structure/vestige_tremor_line/line as anything in lines.Copy())
		line.ended_softly = TRUE // a dead pact unstrings its net; no "cut" theatrics
		qdel(line)
	lines.Cut()
	// Whatever ends the night, the remaining thieves thin away. Staggered so it reads as an ebb, not a wipe
	for(var/mob/living/basic/vestige_silk_thief/filcher as anything in thieves)
		UnregisterSignal(filcher, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		addtimer(CALLBACK(filcher, TYPE_PROC_REF(/mob/living/basic/vestige_silk_thief, dissolve)), rand(0.5 SECONDS, 3 SECONDS))
	thieves.Cut()
	return ..()

/datum/vestige_trial/loom_tremor/get_progress_text()
	if(!spool || QDELETED(spool))
		if(!length(lines))
			return "The spool is lost and the net with it. Renounce the pact and [patron_name] will wind you another."
	var/standing = length(lines)
	if(!night_begun)
		return "String [VESTIGE_TREMOR_MIN_LINES] tremor-lines, spread wide ([standing] of [VESTIGE_TREMOR_MAX_LINES] standing), and the thieves will come."
	var/alarm = length(thieves) ? " Something is in the web NOW." : ""
	if(standing < VESTIGE_TREMOR_MIN_LINES)
		return "Answered [answered] of [VESTIGE_TREMOR_ANSWERS_NEEDED] tremors, but only [standing] line[standing == 1 ? "" : "s"] stand[standing == 1 ? "s" : ""]. The web hangs slack; restring it.[alarm]"
	return "Answered [answered] of [VESTIGE_TREMOR_ANSWERS_NEEDED] tremors, [standing] line[standing == 1 ? "" : "s"] standing.[alarm]"

/// Called whenever a line is strung: wakes the night the first time the net goes taut
/datum/vestige_trial/loom_tremor/proc/check_night()
	refresh_tracker()
	if(night_begun)
		if(slack_notified && length(lines) >= VESTIGE_TREMOR_MIN_LINES)
			slack_notified = FALSE
			var/mob/living/keeper = owner?.current
			if(isliving(keeper))
				to_chat(keeper, span_boldnotice("The net pulls taut again. Listen."))
		return
	if(length(lines) < VESTIGE_TREMOR_MIN_LINES)
		return
	night_begun = TRUE
	next_send_at = world.time + VESTIGE_TREMOR_FIRST_DELAY
	var/mob/living/keeper = owner?.current
	if(isliving(keeper))
		to_chat(keeper, span_bolddanger("The last knot goes taut and the whole net hums once. Somewhere out in the dark, something takes notice."))
		playsound(keeper, 'sound/effects/snap.ogg', 50, TRUE)
	loom_beat()

/**
 * The night's heartbeat: reschedules itself, keeps sent thieves glued to
 * their lines (retaliation can distract them; a distracted thief re-remembers
 * its errand here), and sends the next thief when the floor conditions hold,
 * no thief out, respite elapsed, net taut, keeper alive and on a line's z.
 */
/datum/vestige_trial/loom_tremor/proc/loom_beat()
	if(QDELETED(src) || !owner)
		return
	addtimer(CALLBACK(src, PROC_REF(loom_beat)), VESTIGE_TREMOR_HEARTBEAT)
	var/mob/living/keeper = owner.current
	// Re-glue distracted thieves to their errand
	for(var/mob/living/basic/vestige_silk_thief/filcher as anything in thieves)
		var/obj/structure/vestige_tremor_line/errand = thieves[filcher]
		var/datum/ai_controller/instincts = filcher.ai_controller
		if(!instincts || instincts.blackboard[BB_BASIC_MOB_CURRENT_TARGET])
			continue
		if(istype(errand) && !QDELETED(errand) && errand.z == filcher.z)
			instincts.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, errand)
	if(length(thieves) || world.time < next_send_at)
		return
	if(length(lines) < VESTIGE_TREMOR_MIN_LINES)
		if(!slack_notified)
			slack_notified = TRUE
			if(isliving(keeper))
				to_chat(keeper, span_boldwarning("The web hangs slack. Fewer than [VESTIGE_TREMOR_MIN_LINES] lines stand. The thieves will keep what they took until you restring it."))
			refresh_tracker()
		return
	if(!isliving(keeper) || keeper.stat == DEAD)
		return
	var/list/reachable = list()
	for(var/obj/structure/vestige_tremor_line/line as anything in lines)
		if(!QDELETED(line) && line.z == keeper.z)
			reachable += line
	if(!length(reachable))
		return
	send_thief(pick(reachable), keeper)

/// Sends one thief against one line: spawn, roster, signals, its own despawn clock, and a soft cue to the keeper
/datum/vestige_trial/loom_tremor/proc/send_thief(obj/structure/vestige_tremor_line/line, mob/living/keeper)
	var/list/perches = list()
	for(var/turf/perch as anything in RANGE_TURFS(VESTIGE_TREMOR_SPAWN_RANGE, line))
		if(get_dist(perch, line) < 3)
			continue
		if(perch.is_blocked_turf(exclude_mobs = TRUE))
			continue
		perches += perch
	if(!length(perches))
		return // cramped ground; the next beat tries again
	next_send_at = world.time + VESTIGE_TREMOR_RESPITE // floor, so an instant kill can't machine-gun the night
	var/mob/living/basic/vestige_silk_thief/filcher = new(pick(perches))
	thieves[filcher] = line
	RegisterSignal(filcher, COMSIG_LIVING_DEATH, PROC_REF(on_thief_died))
	RegisterSignal(filcher, COMSIG_QDELETING, PROC_REF(on_thief_gone))
	// The lifespan rides the THIEF, not the trial. Orphans always clean themselves up
	addtimer(CALLBACK(filcher, TYPE_PROC_REF(/mob/living/basic/vestige_silk_thief, dissolve)), VESTIGE_TREMOR_THIEF_LIFESPAN)
	filcher.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, line)
	if(isliving(keeper))
		to_chat(keeper, span_warning("The web shivers. Something small is moving near your line to the [dir2text(get_dir(keeper, line)) || "very spot you stand on"]."))
		playsound(keeper, 'sound/effects/snap.ogg', 25, TRUE)
	refresh_tracker()

/// The hard ping: a line has taken its first bite. Bearing and distance, because the answer is a footrace.
/datum/vestige_trial/loom_tremor/proc/tremor_rings(obj/structure/vestige_tremor_line/line, mob/living/biter)
	var/mob/living/keeper = owner?.current
	if(isliving(keeper))
		if(keeper.z == line.z)
			var/bearing = dir2text(get_dir(keeper, line))
			to_chat(keeper, span_bolddanger("A TREMOR rings down the silk. Something is chewing your line[bearing ? " to the [bearing]" : ""], [get_dist(keeper, line)] paces out! Get there before it chews through!"))
		else
			to_chat(keeper, span_bolddanger("A TREMOR rings down the silk, from one of your lines, a long way from here!"))
		playsound(keeper, 'sound/effects/snap.ogg', 70, TRUE)
	refresh_tracker()

/// Strikes a thief from the roster and starts the respite clock. Safe to call twice (death then deletion).
/datum/vestige_trial/loom_tremor/proc/muster_out(mob/living/filcher)
	if(!(filcher in thieves))
		return FALSE
	thieves -= filcher
	UnregisterSignal(filcher, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	next_send_at = max(next_send_at, world.time + VESTIGE_TREMOR_RESPITE)
	return TRUE

/**
 * The judgment: a dead thief answers its tremor only if its line still stands
 * and the keeper is AT the kill. Same z, within two tiles. Anything else is
 * a dead thief and an unanswered tremor; the Weaver pays for presence.
 */
/datum/vestige_trial/loom_tremor/proc/on_thief_died(mob/living/filcher, gibbed)
	SIGNAL_HANDLER
	var/obj/structure/vestige_tremor_line/line = thieves[filcher]
	if(!muster_out(filcher))
		return
	var/mob/living/keeper = owner?.current
	var/line_stands = istype(line) && !QDELETED(line)
	var/in_person = isliving(keeper) && keeper.z == filcher.z && get_dist(keeper, filcher) <= VESTIGE_TREMOR_ANSWER_RANGE
	if(!line_stands)
		refresh_tracker()
		return // it died with the line already parted; the cut was the answer, and it wasn't yours
	if(!in_person)
		if(isliving(keeper))
			to_chat(keeper, span_warning("The thief is dead, but you were not there for it. A tremor only counts if you are within [VESTIGE_TREMOR_ANSWER_RANGE] paces when it dies."))
		refresh_tracker()
		return
	answered++
	if(isliving(keeper))
		to_chat(keeper, span_notice("The chewing stops under your hands and the line thrums once. Tremor answered, [answered] of [VESTIGE_TREMOR_ANSWERS_NEEDED]."))
		playsound(keeper, 'sound/effects/magic/curse.ogg', 15, TRUE)
	refresh_tracker()
	if(answered >= VESTIGE_TREMOR_ANSWERS_NEEDED)
		complete() // deletes the trial, nothing touches it after this

/datum/vestige_trial/loom_tremor/proc/on_thief_gone(mob/living/filcher)
	SIGNAL_HANDLER
	muster_out(filcher)
	refresh_tracker()

/// A line has ended. Cut lines let their thief escape with the prize; soft ends (unstrung, pact over) just tidy up.
/datum/vestige_trial/loom_tremor/proc/line_lost(obj/structure/vestige_tremor_line/line, softly)
	lines -= line
	if(QDELETED(src)) // the pact itself is unwinding; no theatrics
		return
	for(var/mob/living/basic/vestige_silk_thief/filcher as anything in thieves)
		if(thieves[filcher] != line)
			continue
		// The thief takes its mouthful and goes. The escape is part of the sting
		addtimer(CALLBACK(filcher, TYPE_PROC_REF(/mob/living/basic/vestige_silk_thief, make_off)), 0.7 SECONDS)
	var/mob/living/keeper = owner?.current
	if(!softly && isliving(keeper))
		to_chat(keeper, span_bolddanger("A line falls dead-slack, cut through. String it again."))
		playsound(keeper, 'sound/effects/snap.ogg', 60, TRUE)
	refresh_tracker()

// --- The spool ---

/obj/item/vestige_tremor_spool
	name = "tremor spool"
	desc = "A spool of silk drawn almost too fine to see. Held up to your ear, it carries faint sounds from somewhere else."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "silk_spool"
	w_class = WEIGHT_CLASS_SMALL
	/// Mind of the supplicant this kit was cut for, Destroy bookkeeping only; interactions resolve the wielder
	var/datum/mind/bound_mind

/obj/item/vestige_tremor_spool/Destroy()
	var/datum/vestige_trial/loom_tremor/trial = bound_mind?.active_vestige_trial
	if(istype(trial) && trial.spool == src)
		trial.spool = null
		trial.refresh_tracker()
	bound_mind = null
	return ..()

/obj/item/vestige_tremor_spool/examine(mob/user)
	. = ..()
	. += span_notice("Use in hand to string a tremor-line across the floor under you, [VESTIGE_TREMOR_MAX_LINES] at most, each at least [VESTIGE_TREMOR_SPREAD] tiles from the others. With [VESTIGE_TREMOR_MIN_LINES] standing, the thieves come. A line takes about a dozen seconds of chewing to snap, so get there first, and be within [VESTIGE_TREMOR_ANSWER_RANGE] tiles when the thief dies.")

/obj/item/vestige_tremor_spool/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	var/mob/living/keeper = user
	var/datum/vestige_trial/loom_tremor/trial = keeper.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(keeper, "the spool is silent!")
		return TRUE
	var/turf/open/ground = get_turf(keeper)
	if(!istype(ground) || !check_ground(keeper, trial, ground))
		return TRUE
	balloon_alert(keeper, "stringing a line...")
	if(!do_after(keeper, VESTIGE_TREMOR_STRING_TIME, target = ground))
		return TRUE
	if(!keeper.is_holding(src) || get_turf(keeper) != ground)
		return TRUE
	// Re-resolve everything; the pact may have been renounced mid-string
	trial = keeper.mind?.active_vestige_trial
	if(!istype(trial) || !check_ground(keeper, trial, ground))
		return TRUE
	var/obj/structure/vestige_tremor_line/line = new(ground)
	line.bound_mind = keeper.mind
	trial.lines += line
	keeper.visible_message(
		span_warning("[keeper] draws a nearly invisible thread across the floor and knots it down at both ends."),
		span_notice("You string the line and thumb it once. It answers with a note you feel more than hear."),
	)
	playsound(ground, 'sound/items/handling/cloth/cloth_drop1.ogg', 40, TRUE)
	trial.check_night() // refreshes the tracker; wakes the night at three lines
	return TRUE

/// Placement rules for a line, with feedback. Called before the string and again after it.
/obj/item/vestige_tremor_spool/proc/check_ground(mob/living/keeper, datum/vestige_trial/loom_tremor/trial, turf/open/ground)
	// Never inside the vestige: the ruin unloads the moment everyone leaves,
	// and a sensor net must not be wiped mid-night by map cleanup
	if(istype(get_area(ground), /area/ruin/space/has_grav/vestige))
		balloon_alert(keeper, "not in the Loom itself!")
		return FALSE
	if(ground.is_blocked_turf(exclude_mobs = TRUE))
		balloon_alert(keeper, "no clear span to string!")
		return FALSE
	if(locate(/obj/structure/vestige_tremor_line) in ground)
		balloon_alert(keeper, "a line is already strung here!")
		return FALSE
	if(length(trial.lines) >= VESTIGE_TREMOR_MAX_LINES)
		balloon_alert(keeper, "the silk holds only [VESTIGE_TREMOR_MAX_LINES] lines taut!")
		return FALSE
	// The net must be DISPERSED. Clustered lines would just be a doorstep siege
	for(var/obj/structure/vestige_tremor_line/sister as anything in trial.lines)
		if(QDELETED(sister) || sister.z != ground.z)
			continue
		if(get_dist(sister, ground) < VESTIGE_TREMOR_SPREAD)
			balloon_alert(keeper, "too close to another line, [VESTIGE_TREMOR_SPREAD] tiles apart!")
			return FALSE
	return TRUE

// --- The line, strung ---

/**
 * A tremor-line: no snare, no wall, a nerve. It reports the first bite it
 * takes (attack_generic is where basic-mob chewing lands, verified against
 * obj_defense) and its integrity is the whole response window. It holds no
 * trial reference: everything resolves through bound_mind at the moment
 * it's needed, the same rule every kit in the module follows.
 */
/obj/structure/vestige_tremor_line
	name = "tremor-line"
	desc = "A single silk thread strung ankle-height across the floor, thin enough that you would feel it before you saw it. It is a tripwire, not a barricade."
	icon = 'icons/effects/web.dmi'
	icon_state = "cobweb1"
	alpha = 150
	layer = ABOVE_OPEN_TURF_LAYER
	plane = FLOOR_PLANE
	anchored = TRUE
	density = FALSE
	max_integrity = VESTIGE_TREMOR_LINE_INTEGRITY
	/// Mind of the supplicant whose net this is
	var/datum/mind/bound_mind
	/// Whether the first bite has already rung its tremor
	var/pinged = FALSE
	/// One fraying warning per line
	var/fray_warned = FALSE
	/// TRUE when the line ends without violence (unstrung by the keeper, pact over), suppresses the "cut" alarm
	var/ended_softly = FALSE

/obj/structure/vestige_tremor_line/Destroy()
	var/datum/vestige_trial/loom_tremor/trial = bound_mind?.active_vestige_trial
	if(istype(trial))
		trial.line_lost(src, ended_softly)
	bound_mind = null
	return ..()

/obj/structure/vestige_tremor_line/examine(mob/user)
	. = ..()
	if(user.mind && user.mind == bound_mind)
		. += span_notice("Part of your net. When something chews on it you will feel the tremor. Get there in person, or restring whatever is left. Press a hand to the knots to take it back up.")
	if(atom_integrity < max_integrity * 0.5)
		. += span_danger("It is chewed ragged and badly frayed.")

// Where a basic mob's chewing lands (obj_defense routes attack_basic_mob through attack_generic)
/obj/structure/vestige_tremor_line/attack_generic(mob/user, damage_amount = 0, damage_type = BRUTE, damage_flag = 0, sound_effect = 1, armor_penetration = 0)
	if(isliving(user))
		ring_out(user)
	return ..()

/// The line sings: a hard tremor on the first bite, one fraying warning later on
/obj/structure/vestige_tremor_line/proc/ring_out(mob/living/biter)
	var/datum/vestige_trial/loom_tremor/trial = bound_mind?.active_vestige_trial
	if(!istype(trial))
		return
	if(!pinged)
		pinged = TRUE
		visible_message(span_boldwarning("[src] shivers and SINGS as [biter] starts chewing it!"))
		trial.tremor_rings(src, biter)
		return
	if(!fray_warned && atom_integrity < max_integrity * 0.5)
		fray_warned = TRUE
		var/mob/living/keeper = bound_mind?.current
		if(isliving(keeper))
			to_chat(keeper, span_bolddanger("The tremor turns ragged, that line is more than half chewed through!"))

/obj/structure/vestige_tremor_line/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	// unstring() sleeps (do_after); don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(unstring), user)
	return TRUE

/// The keeper takes a line back up. A placement do-over, not a loss
/obj/structure/vestige_tremor_line/proc/unstring(mob/living/user)
	if(!user.mind || user.mind != bound_mind)
		balloon_alert(user, "the thread slips your fingers!")
		return
	balloon_alert(user, "unstringing...")
	if(!do_after(user, 1 SECONDS, target = src))
		return
	if(QDELETED(src) || !user.Adjacent(src) || user.mind != bound_mind)
		return
	user.visible_message(
		span_warning("[user] works a near-invisible thread up off the floor and winds it away."),
		span_notice("You take the line back up. String it somewhere better."),
	)
	ended_softly = TRUE
	qdel(src) // Destroy tells the trial

/obj/structure/vestige_tremor_line/atom_destruction(damage_flag)
	visible_message(span_boldwarning("[src] parts with a snap that carries much further than a thread should!"))
	playsound(src, 'sound/effects/snap.ogg', 70, TRUE)
	return ..()

// --- The thieves ---

/**
 * Little mouths in the dark: silk-fat moths that come for the net exactly the
 * way vermin came for the Weaver's stock in trade. Sent by the trial, aimed
 * at a line, void-hardy so the net can stand on hull plating, and burdened
 * with their own despawn clocks. They fight back when struck (retaliation can
 * out-shout the errand; the trial's heartbeat re-glues them to the line), and
 * they leave no corpse, no meat, no trophy: an unanswered night pays nothing,
 * and an answered one pays only through the patron.
 */
/mob/living/basic/vestige_silk_thief
	name = "silk thief"
	desc = "A dust-grey moth the size of a terrier, with mouthparts built for chewing through cloth. It only wants the silk."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "silk_thief"
	icon_living = "silk_thief"
	icon_dead = "silk_thief"
	gender = NEUTER
	mob_size = MOB_SIZE_SMALL
	mob_biotypes = MOB_ORGANIC | MOB_BUG
	basic_mob_flags = DEL_ON_DEATH
	death_message = "comes apart into a puff of grey dust, and is gone."
	health = 30
	maxHealth = 30
	melee_damage_lower = 5
	melee_damage_upper = 8
	obj_damage = 6 // against a 60-integrity line: about a dozen seconds of chewing, the response window
	speed = 4
	combat_mode = TRUE
	faction = list("vestige_loom_thief")
	attack_verb_continuous = "gnaws"
	attack_verb_simple = "gnaw"
	attack_sound = 'sound/items/weapons/bite.ogg'
	attack_vis_effect = ATTACK_EFFECT_BITE
	// The net may be strung on open hull; the thieves come anyway
	habitable_atmos = null
	unsuitable_atmos_damage = 0
	minimum_survivable_temperature = 0
	maximum_survivable_temperature = 1500
	butcher_results = null
	gold_core_spawnable = NO_SPAWN
	ai_controller = /datum/ai_controller/basic_controller/vestige_silk_thief

/mob/living/basic/vestige_silk_thief/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)
	AddElement(/datum/element/ai_retaliate)

/// A thief's clock runs out (or its night does): it thins away to nothing. Safe on the dead and deleted.
/mob/living/basic/vestige_silk_thief/proc/dissolve()
	if(QDELETED(src) || stat == DEAD)
		return
	visible_message(span_warning("[src] crumbles into grey dust, and is gone."))
	qdel(src)

/// A thief whose line has parted escapes with its mouthful, the sting of an unanswered tremor
/mob/living/basic/vestige_silk_thief/proc/make_off()
	if(QDELETED(src) || stat == DEAD)
		return
	visible_message(span_warning("[src] flits away into the dark, trailing a stolen mouthful of silk."))
	qdel(src)

/**
 * Thief AI: no hunting instinct of its own. Its target is ASSIGNED by the
 * trial (the generic find-target subtrees only scan mobs, so a structure
 * errand has to be pushed into the blackboard; Roost precedent). Retaliation
 * lets it defend itself when the keeper arrives, and the custom strategy
 * below keeps the line assignment valid for the melee behavior's re-checks.
 */
/datum/ai_controller/basic_controller/vestige_silk_thief
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/vestige_silk_thief,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

/**
 * Standard basic targeting, plus the tremor-line. The line is assigned as a
 * blackboard target by the trial itself; this strategy's job is to keep that
 * assignment VALID, both the keep-current-target check and the melee
 * behavior's re-validation run through can_attack.
 */
/datum/targeting_strategy/basic/vestige_silk_thief

/datum/targeting_strategy/basic/vestige_silk_thief/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	if(istype(the_target, /obj/structure/vestige_tremor_line))
		if(QDELETED(the_target) || living_mob.z != the_target.z)
			return FALSE
		if(vision_range && get_dist(living_mob, the_target) > vision_range)
			return FALSE
		return TRUE
	return ..()

#undef VESTIGE_SNARE_CATCHES_NEEDED
#undef VESTIGE_SNARE_CATCHES_PER_BEAST
#undef VESTIGE_SNARE_MAX_WEBS
#undef VESTIGE_SNARE_SPIN_TIME
#undef VESTIGE_SNARE_HOLD_TIME
#undef VESTIGE_SNARE_WEB_INTEGRITY
#undef VESTIGE_PANTRY_STOCK_NEEDED
#undef VESTIGE_PANTRY_WRAP_TIME
#undef VESTIGE_PANTRY_FRESHNESS
#undef VESTIGE_PANTRY_HOIST_TIME
#undef VESTIGE_PANTRY_COCOON_INTEGRITY
#undef VESTIGE_PANTRY_BREAKOUT
#undef VESTIGE_TREMOR_ANSWERS_NEEDED
#undef VESTIGE_TREMOR_MAX_LINES
#undef VESTIGE_TREMOR_MIN_LINES
#undef VESTIGE_TREMOR_SPREAD
#undef VESTIGE_TREMOR_STRING_TIME
#undef VESTIGE_TREMOR_LINE_INTEGRITY
#undef VESTIGE_TREMOR_ANSWER_RANGE
#undef VESTIGE_TREMOR_HEARTBEAT
#undef VESTIGE_TREMOR_FIRST_DELAY
#undef VESTIGE_TREMOR_RESPITE
#undef VESTIGE_TREMOR_SPAWN_RANGE
#undef VESTIGE_TREMOR_THIEF_LIFESPAN


/**
 * # The Loom: giant spider boons
 *
 * The Weaver's half of the bargain: what an ancient broodmother on a dead
 * sericulture ship pays a loose thread with when a trial is kept. The spider's
 * whole body is the antag (fangs, spinnerets, eight sure feet) so nothing
 * here grants the spider. Each boon is the human-sized cut of one part of the
 * craft: the silk (webs rebuilt on the pointed-spell rail with a channel
 * ported from the spider's own lay_web guards. The placement checks, the
 * spinning-turf trait, the do_after, minus the spider mob), the fang (a
 * touch spell on the Rusted Grasp chassis carrying a venom status effect that
 * keeps the hunting spider's own mercy floor), the line (a self-throw at an
 * anchor, honest about obstructions because throw_at is), and the legs (the
 * spider's own trait pair, cut down to what a human can wear).
 *
 * Ownership design note: upstream webs decide who passes by TRAIT_WEB_SURFER
 * (spiderwebs.dm CanAllowThrough), not faction, and the genetic web subtype
 * is the existing precedent for per-creature permission (an allowed_mob var).
 * The Loom's webs carry that one step further: a creator MIND weakref, so the
 * weaver's own tread never catches, across body swaps, without granting the
 * surfer trait to anyone who didn't buy Eight-Legged Grace.
 *
 * Patron and trials live in the theme file; only the boons, their spells,
 * and their structures are defined here.
 */

// ===== Tuning constants (file-local, #undef at bottom) =====

// --- The silk ---
/// Channel to spin a snare. Keep the Silk Spinner desc's "three-second spin" in sync.
#define VESTIGE_SILK_SPIN_TIME (3 SECONDS)
/// The master's channel. Keep the Master Weaver desc's "a second and a half" in sync.
#define VESTIGE_SILK_SPIN_TIME_MASTER (1.5 SECONDS)
/// Beats between spins. Keep the Silk Spinner desc's "eight seconds between casts" in sync.
#define VESTIGE_SILK_COOLDOWN (8 SECONDS)
/// The master's beat. Keep the Master Weaver desc's "five seconds between" in sync.
#define VESTIGE_SILK_COOLDOWN_MASTER (5 SECONDS)
/// Live threads the base Loom holds; the oldest frays when exceeded. Keep the desc's "eight threads" in sync.
#define VESTIGE_SILK_MAX_WEBS 8
/// Live threads the master's Loom holds. Keep the desc's "twelve threads" in sync.
#define VESTIGE_SILK_MAX_WEBS_MASTER 12
/// do_after interaction key: one spin at a time, ported from lay_web's DOAFTER_SOURCE_SPIDER guard
#define VESTIGE_SILK_DOAFTER "vestige_silk_spin"

// --- The fang ---
/// Beats between bites. Keep the Venom Fang desc's "twenty seconds" in sync.
#define VESTIGE_FANG_COOLDOWN (20 SECONDS)
/// The withering fang's beat. Keep its desc's "fourteen seconds" in sync.
#define VESTIGE_FANG_WITHER_COOLDOWN (14 SECONDS)
/// How long the base venom works. Keep the desc's "eight seconds" (and its 40/16 totals) in sync.
#define VESTIGE_FANG_DURATION (8 SECONDS)
/// How long the withering venom works. Keep its desc's "twelve seconds" (and its 60/24 totals) in sync.
#define VESTIGE_FANG_WITHER_DURATION (12 SECONDS)
/// Stamina drained per second of venom
#define VESTIGE_FANG_STAMINA_TICK 5
/// Toxin dealt per second of venom
#define VESTIGE_FANG_TOX_TICK 2
/// Movespeed slowdown while the withering venom runs, a hobble, never a root
#define VESTIGE_FANG_WITHER_SLOW 0.5

// --- The line ---
/// Tiles of silk the line can cast. Keep the Silk Line desc's "seven tiles" in sync.
#define VESTIGE_LINE_RANGE 7
/// Beats between casts. Keep the desc's "twenty seconds" in sync.
#define VESTIGE_LINE_COOLDOWN (20 SECONDS)
/// throw_at speed of the reel
#define VESTIGE_LINE_SPEED 2
/// How long the silk visual hangs in the air
#define VESTIGE_LINE_BEAM_TIME (0.6 SECONDS)

// --- The legs ---
/// Trait source for the Weaver's body-work
#define VESTIGE_GRACE_TRAIT "vestige_spider_boon"

// ===== BOONS =====

// --- Chain: the silk ---

/datum/vestige_boon/spell/silk_spinner
	name = "Silk Spinner"
	// Keep the numbers in sync with VESTIGE_SILK_SPIN_TIME / _COOLDOWN / _MAX_WEBS
	// (initial values must be constant, so no define interpolation here)
	desc = "Spin a sticky snare onto open floor within reach, holding still while the thread sets. Your own tread never catches; anyone else has even odds of sticking at each step, and stray shots foul in the weave. Only so many hold at once, and the oldest lets go for the newest. Fire burns silk fast."
	grant_text = "Your fingertips feel the weight of thread that isn't there yet."
	spell_type = /datum/action/cooldown/spell/pointed/vestige_silk_spin

/datum/vestige_boon/spell/silk_spinner/master_weaver
	name = "Master Weaver"
	// Keep the numbers in sync with VESTIGE_SILK_SPIN_TIME_MASTER / _COOLDOWN_MASTER / _MAX_WEBS_MASTER
	desc = "You spin much faster now, and the Loom holds more threads. You can also spin over one of your own snares to draw it into a sealed weft: a solid wall of silk that stops bodies and air, including yours. It is still silk, though. Fire eats it, and a patient blade cuts it apart."
	grant_text = "Now you can see how the threads are supposed to cross."
	upgrades_from = /datum/vestige_boon/spell/silk_spinner
	spell_type = /datum/action/cooldown/spell/pointed/vestige_silk_spin/master_weaver

// --- Chain: the fang ---

/datum/vestige_boon/spell/venom_fang
	name = "Venom Fang"
	// Keep the numbers in sync with VESTIGE_FANG_COOLDOWN / _DURATION / _STAMINA_TICK / _TOX_TICK
	// (5 stamina + 2 toxin per second over 8 seconds = 40 / 16 totals)
	desc = "A bite you carry in your palm. Touch a living thing to poison it, stamina and toxin both, draining steadily, all the way down."
	grant_text = "Something needle-fine settles into the pad of each finger and waits."
	spell_type = /datum/action/cooldown/spell/touch/vestige_venom_fang

/datum/vestige_boon/spell/venom_fang/withering
	name = "Withering Fang"
	// Keep the numbers in sync with VESTIGE_FANG_WITHER_COOLDOWN / _WITHER_DURATION / _WITHER_SLOW
	// (5 stamina + 2 toxin per second over 12 seconds = 60 / 24 totals)
	desc = "A bite you carry in your palm, held a little longer. More venom in it, and while it runs they move heavy: slowed at every step, but never stopped outright."
	grant_text = "The needles in your fingers grow a second, slower barb."
	upgrades_from = /datum/vestige_boon/spell/venom_fang
	spell_type = /datum/action/cooldown/spell/touch/vestige_venom_fang/withering

// --- Standalone: the line ---

/datum/vestige_boon/spell/silk_line
	name = "Silk Line"
	// Keep the numbers in sync with VESTIGE_LINE_RANGE / VESTIGE_LINE_COOLDOWN
	desc = "Cast a dragline at anything solid in reach (a wall, a window, anything dense and bolted down) and reel yourself to it in one straight rush. If something solid is in the way, that is where you stop instead."
	grant_text = "Something coils tight at the base of your wrist, like a spinneret you don't have."
	spell_type = /datum/action/cooldown/spell/pointed/vestige_silk_line

// --- Standalone: the legs ---

/datum/vestige_boon/spider_grace
	name = "Eight-Legged Grace"
	desc = "Nothing to cast, the Weaver just re-strings your footing. Every hunting web parts for you, whoever spun it, and wet decking grips your feet like dry board. A sealed weft is a wall, not a web, so it still stops you, and soap will still put you on the floor. This is in the body, not the soul, so a new body has to be taught again."
	grant_text = "Your footing settles, like you are standing on more legs than you have."
	radial_icon = 'icons/effects/web.dmi'
	radial_icon_state = "cobweb1"

/**
 * Body-work, not a spell: the traits go on the body and stay there. Lost with
 * the body by nature (Rubber Bones precedent). The vestige record re-runs
 * grant() on respawn restore, which re-teaches whatever body the player wears
 * by then (add_traits is idempotent per source, so restoring into the same
 * body double-grants nothing).
 *
 * TRAIT_WEB_SURFER is the exact trait every upstream spider walks its own
 * nest with (spider.dm Initialize), and the exact trait stickyweb
 * CanAllowThrough consults: this is the kit's keystone: with Silk Spinner in
 * the other hand, your trap-field is your parlor. Two verified exceptions the
 * desc owns up to: sealed webs return FALSE before the trait check
 * (spiderwebs.dm), and the geneticist's web subtype never consults the trait
 * at all. TRAIT_NO_SLIP_WATER is the footing half, wet-floor slips only;
 * lube explicitly needs TRAIT_NO_SLIP_ALL (mobs.dm), so the desc doesn't
 * claim it. (The spider's other innate, TRAIT_FENCE_CLIMBER, is a no-op on
 * anything that can hold items, so a human gets nothing from it, cut.)
 */
/datum/vestige_boon/spider_grace/grant(mob/living/user, datum/mind/owner)
	..()
	// The framework hands us owner.current at grant time, but re-resolve anyway,
	// the same rail /datum/vestige_boon/spell/grant rides (an earlier boon's
	// side effects can reshape the body out from under the claim).
	if(owner?.current)
		user = owner.current
	user.add_traits(list(TRAIT_WEB_SURFER, TRAIT_NO_SLIP_WATER), VESTIGE_GRACE_TRAIT)
	to_chat(user, span_notice("Webs part for you now, and wet decking grips your soles like dry board."))

// ===== THE SILK =====

/**
 * The spider's Spin Web, rebuilt for a human hand on the pointed-spell rail.
 * Upstream's lay_web is a mob_cooldown action welded to standing-on-the-tile
 * (it always webs get_turf(owner)); the Weaver's version keeps every one of
 * its guards, the existing-web check, the TRAIT_SPINNING_WEB_TURF turf
 * claim, the interruptible do_after with its one-spin-at-a-time interaction
 * key, but takes a click target so the thread can be strung on your own
 * tile or one step away (cast_range = 1).
 *
 * Fork-quirk compliance: Activate() ignores cast()'s return value on this
 * fork, so the whole channel (and every bail-out) lives in before_cast,
 * which CAN cancel, an interrupted spin costs no cooldown. The chosen turf
 * rides a same-cast handoff var into cast(), the Borrowed Shape pattern.
 *
 * The planted web is a local stickyweb subtype whose passage check knows its
 * creator's MIND (see below). Upstream webs gate on TRAIT_WEB_SURFER, which
 * would either hold the weaver too (no trait) or wave every spider-kin
 * through (trait), so per-creator permission follows the genetic-web
 * precedent (allowed_mob) instead, hardened from a mob ref to a mind ref.
 *
 * The thread budget is the local balance rail: webs otherwise live forever,
 * and a patient weaver would carpet a deck. Over budget, the oldest thread
 * frays. Accepted quirk, flagged: the budget lives on the spell, so claiming
 * the Master Weaver upgrade retires the old spell and orphans its existing
 * threads outside the new budget, at most eight stale webs that only decay
 * by damage.
 */
/datum/action/cooldown/spell/pointed/vestige_silk_spin
	name = "Silk Spinner"
	desc = "Spin a sticky web on your tile or one next to you. Takes a few seconds standing still, and your own webs never catch you. Only so many hold at once, and the oldest frays for the newest."
	button_icon = 'icons/mob/actions/actions_animal.dmi'
	button_icon_state = "spider_web"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	active_msg = "You draw wet silk to your fingertips..."
	deactive_msg = "You let the silk set unspun."
	cooldown_time = VESTIGE_SILK_COOLDOWN
	cast_range = 1
	aim_assist = FALSE
	invocation_type = INVOCATION_NONE
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	/// How long one spin channel takes
	var/spin_time = VESTIGE_SILK_SPIN_TIME
	/// Live threads before the oldest frays
	var/max_webs = VESTIGE_SILK_MAX_WEBS
	/// Whether spinning over your own snare draws it into a sealed weft (the master's second lesson)
	var/can_seal = FALSE
	/// The turf validated and channelled over in before_cast, consumed by cast(). Same-cast handoff only.
	var/turf/pending_turf
	/// Weakrefs to every thread this spell has planted, spin order, the fray ledger
	var/list/spun_webs = list()

/datum/action/cooldown/spell/pointed/vestige_silk_spin/master_weaver
	name = "Master Weaver's Silk"
	desc = "Spin a sticky web much faster, or spin over one of your own to seal it into a wall that stops bodies and air, yours included. More of them hold at once."
	button_icon_state = "spider_wall"
	cooldown_time = VESTIGE_SILK_COOLDOWN_MASTER
	spin_time = VESTIGE_SILK_SPIN_TIME_MASTER
	max_webs = VESTIGE_SILK_MAX_WEBS_MASTER
	can_seal = TRUE

/datum/action/cooldown/spell/pointed/vestige_silk_spin/Destroy()
	pending_turf = null
	spun_webs = null
	return ..()

// The parent refuses casting on yourself; here, clicking yourself just means
// "web my own tile". Everything real is validated against the resolved turf.
/datum/action/cooldown/spell/pointed/vestige_silk_spin/is_valid_target(atom/cast_on)
	return TRUE

// The whole channel lives here so an interrupted spin can still cancel the
// cast (fork quirk: cancels after before_cast are dead letters)
/datum/action/cooldown/spell/pointed/vestige_silk_spin/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	pending_turf = null
	var/turf/spin_turf = get_turf(cast_on)
	if(!isopenturf(spin_turf))
		owner.balloon_alert(owner, "nothing to string silk across!")
		return . | SPELL_CANCEL_CAST
	if(!isturf(owner.loc))
		owner.balloon_alert(owner, "no footing to spin from!")
		return . | SPELL_CANCEL_CAST
	// One spin at a time: lay_web's DOING_INTERACTION guard, ported
	if(DOING_INTERACTION(owner, VESTIGE_SILK_DOAFTER))
		owner.balloon_alert(owner, "already spinning!")
		return . | SPELL_CANCEL_CAST
	// Someone (or something) has already claimed this turf for a web, lay_web's turf-trait guard, ported
	if(HAS_TRAIT(spin_turf, TRAIT_SPINNING_WEB_TURF))
		owner.balloon_alert(owner, "already being webbed!")
		return . | SPELL_CANCEL_CAST
	var/sealing = FALSE
	var/obj/structure/spider/stickyweb/existing = locate() in spin_turf
	if(existing)
		if(!can_seal)
			owner.balloon_alert(owner, "already webbed!")
			return . | SPELL_CANCEL_CAST
		if(istype(existing, /obj/structure/spider/stickyweb/sealed))
			owner.balloon_alert(owner, "already a wall!")
			return . | SPELL_CANCEL_CAST
		if(!is_my_thread(existing))
			owner.balloon_alert(owner, "not your thread to build on!")
			return . | SPELL_CANCEL_CAST
		sealing = TRUE
	ADD_TRAIT(spin_turf, TRAIT_SPINNING_WEB_TURF, REF(src))
	owner.balloon_alert_to_viewers(sealing ? "drawing the weft tight..." : "spinning silk...")
	var/spun = do_after(owner, spin_time, target = spin_turf, interaction_key = VESTIGE_SILK_DOAFTER)
	REMOVE_TRAIT(spin_turf, TRAIT_SPINNING_WEB_TURF, REF(src))
	if(!spun || QDELETED(src) || QDELETED(owner))
		owner?.balloon_alert(owner, "the thread snaps!")
		return . | SPELL_CANCEL_CAST
	pending_turf = spin_turf
	return .

/datum/action/cooldown/spell/pointed/vestige_silk_spin/cast(atom/cast_on)
	. = ..()
	var/turf/spin_turf = pending_turf
	pending_turf = null
	if(!spin_turf || !owner?.mind)
		return
	var/obj/structure/spider/stickyweb/spun
	// Re-locate at plant time: the channel slept, and the tile's webbing may
	// have changed under it (our base thread burned, a rival's landed)
	var/obj/structure/spider/stickyweb/existing = locate() in spin_turf
	if(existing)
		// can_seal re-checked here, not just in before_cast: a web that lands
		// mid-channel must never trick the BASE spinner into the seal branch
		if(!can_seal || !is_my_thread(existing))
			owner.balloon_alert(owner, "a stranger's thread is in the way!")
			return
		// The sealer's exchange, straight from upstream's lay_web/sealer:
		// the base thread is consumed and the wall stands in its place
		qdel(existing)
		spun = new /obj/structure/spider/stickyweb/sealed/vestige(spin_turf)
		owner.visible_message(
			span_warning("[owner] draws the webbing on [spin_turf] thread over thread into a solid wall of silk!"),
			span_notice("You draw the snare into a sealed weft. Nothing passes now, you included."),
		)
	else
		spun = new /obj/structure/spider/stickyweb/vestige(spin_turf, owner.mind)
		owner.visible_message(
			span_warning("[owner] strings a taut weave of silk across [spin_turf]!"),
			span_notice("You lay the snare. It knows your tread from everyone else's."),
		)
	playsound(spin_turf, 'sound/effects/splat.ogg', 30, TRUE)
	register_web(spun)

/// Whether this web is one of the Loom's, woven by this spell's owner (by mind, so body swaps keep ownership)
/datum/action/cooldown/spell/pointed/vestige_silk_spin/proc/is_my_thread(obj/structure/spider/stickyweb/web)
	if(!istype(web, /obj/structure/spider/stickyweb/vestige))
		return FALSE
	var/obj/structure/spider/stickyweb/vestige/thread = web
	return thread.creator_mind_ref?.resolve() == owner?.mind

/// Adds a thread to the ledger and retires the oldest ones over budget
/datum/action/cooldown/spell/pointed/vestige_silk_spin/proc/register_web(obj/structure/spider/stickyweb/web)
	// Compact away threads that already burned or were cut
	var/list/live = list()
	for(var/datum/weakref/ref as anything in spun_webs)
		var/obj/structure/spider/stickyweb/old = ref?.resolve()
		if(!QDELETED(old))
			live += ref
	spun_webs = live
	spun_webs += WEAKREF(web)
	while(length(spun_webs) > max_webs)
		var/datum/weakref/oldest_ref = spun_webs[1]
		spun_webs -= oldest_ref
		var/obj/structure/spider/stickyweb/oldest = oldest_ref?.resolve()
		if(QDELETED(oldest))
			continue
		oldest.visible_message(span_notice("[oldest] frays apart and lets go."))
		qdel(oldest)

/**
 * A snare that knows its weaver. Upstream webs wave through anyone with
 * TRAIT_WEB_SURFER and dice-roll everyone else; this subtype checks the
 * creator's mind first (and whoever the creator is dragging along, mirroring
 * the parent's pulledby clause), then falls back to the parent's exact rules.
 * Surfers still surf, everyone else eats the same prob(stuck_chance) roll,
 * projectiles the same prob(projectile_stuck_chance).
 *
 * genetic = TRUE reuses the parent's own bypass switch so its pass roll
 * doesn't fire ahead of ours. The same trick the genetic web itself uses,
 * and the flag is consulted nowhere else in the codebase (verified: only
 * spiderwebs.dm reads it). Everything the parent gives is kept: 15 integrity,
 * melee brute quartered, burn amplified, hot-atmos self-damage, weavable
 * into cloth by web-weavers.
 */
/obj/structure/spider/stickyweb/vestige
	name = "woven snare"
	desc = "Spider silk woven in a neat, regular pattern. Too tidy to be an animal's work."
	genetic = TRUE
	/// The mind of the weaver: this web's one welcome guest, wherever that soul is currently living
	var/datum/weakref/creator_mind_ref

/obj/structure/spider/stickyweb/vestige/Initialize(mapload, datum/mind/creator)
	if(creator)
		creator_mind_ref = WEAKREF(creator)
	. = ..()
	// A pale keepsake tint, the genetic web's outline trick, so crew can learn
	// to tell a Loom weave from wild webbing at a glance
	add_filter("vestige_silk_tint", 10, list("type" = "outline", "color" = "#f5eed9ff", "size" = 0.1))

/obj/structure/spider/stickyweb/vestige/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..() // the genetic flag makes the parent stop after base checks, no double roll
	if(isliving(mover))
		var/mob/living/living_mover = mover
		var/datum/mind/creator = creator_mind_ref?.resolve()
		if(creator && living_mover.mind == creator)
			return TRUE
		var/mob/living/puller = living_mover.pulledby
		if(istype(puller) && ((creator && puller.mind == creator) || HAS_TRAIT(puller, TRAIT_WEB_SURFER)))
			return TRUE
		if(HAS_TRAIT(mover, TRAIT_WEB_SURFER))
			return TRUE
		if(prob(stuck_chance))
			stuck_react(mover)
			return FALSE
		return .
	if(isprojectile(mover))
		return prob(projectile_stuck_chance)
	return .

/**
 * The master's weft: upstream's sealed web wearing the Loom's name. All
 * behavior is inherited and all of it verified: blocks every mover
 * unconditionally (CanAllowThrough returns FALSE before any trait or creator
 * check, the weaver walls themselves out too, and the desc says so), blocks
 * atmos (can_atmos_pass = ATMOS_PASS_NO plus the air update on init), and
 * dies to fire fast at 15 integrity. No creator var: a wall keeps no
 * favorites, and the seal-upgrade check only ever reads the base thread.
 */
/obj/structure/spider/stickyweb/sealed/vestige
	name = "sealed weft"
	desc = "Web layered thread over thread into a solid wall, packed dense enough to hold back air. Nothing gets through it, including whoever made it."

// ===== THE FANG =====

/**
 * The giant spider's envenomed bite, moved into a human palm on the touch
 * chassis (the same rail as the Reliquary's Rusted Grasp, the base class in
 * _touch.dm carries no antag checks, verified). Upstream spiders deliver
 * poison_per_bite units of a reagent through the venomous element; a plain
 * human has no fangs to hang that element on, so the delivery is a touch
 * spell and the payload is a local status effect rather than a reagent,
 * which buys exact, quotable numbers, no purging via detox chems being
 * TOO hard a counter (charcoal still shortens nothing, but the effect is
 * honest about its fixed clock), and a clean slot for the upgrade's slow.
 *
 * What it keeps from upstream is the venom's ethic: the hunting spider's
 * toxin (/datum/reagent/toxin/hunterspider) only deals damage above 40
 * health, "produced by spiders to weaken prey", and this venom keeps that
 * exact floor for its toxin half. Stamina, being non-lethal by definition,
 * runs the full clock.
 *
 * Antimagic (MAGIC_RESISTANCE) parries the whole bite via the chassis's
 * on_antimagic_triggered rail, same as the grasp. A corpse refuses the bite
 * and keeps the hand (cast_on_hand_hit returning FALSE is the no-waste rail,
 * verified in do_hand_hit).
 */
/datum/action/cooldown/spell/touch/vestige_venom_fang
	name = "Venom Fang"
	desc = "Touch someone to poison them. Drains their stamina and eats at them for a while."
	button_icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	button_icon_state = "venom_fang"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	sound = 'sound/items/weapons/bite.ogg'
	cooldown_time = VESTIGE_FANG_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE
	hand_path = /obj/item/melee/touch_attack/vestige_fang
	draw_message = span_notice("Venom beads along your fingertips like dew along a strand.")
	drop_message = span_notice("The venom sinks back under your skin.")
	/// The venom this fang threads in
	var/venom_type = /datum/status_effect/vestige_fang_venom

/datum/action/cooldown/spell/touch/vestige_venom_fang/withering
	name = "Withering Fang"
	desc = "Touch someone to poison them. Drains their stamina and eats at them for longer, and slows them down while it runs."
	cooldown_time = VESTIGE_FANG_WITHER_COOLDOWN
	venom_type = /datum/status_effect/vestige_fang_venom/withering

/datum/action/cooldown/spell/touch/vestige_venom_fang/on_antimagic_triggered(obj/item/melee/touch_attack/hand, atom/victim, mob/living/carbon/caster)
	victim.visible_message(
		span_danger("The venom beads off [victim] like water off waxed thread!"),
		span_danger("Something needle-fine glances off you, finding no purchase!"),
	)

/datum/action/cooldown/spell/touch/vestige_venom_fang/cast_on_hand_hit(obj/item/melee/touch_attack/hand, atom/victim, mob/living/carbon/caster)
	// is_valid_target (chassis default: isliving) has already vetted the type
	var/mob/living/living_victim = victim
	if(living_victim.stat == DEAD)
		caster.balloon_alert(caster, "no blood moving to carry it!")
		return FALSE // no meal in it, keep the hand
	living_victim.apply_status_effect(venom_type)
	living_victim.visible_message(
		span_danger("[caster] lays two fingers on [living_victim], needle-quick, and something under the skin bites!"),
		span_userdanger("A pinprick, and then a slow cold starts spreading under your skin!"),
	)
	return TRUE

// The plain greyscale hand rather than the heretic's clawed mansus one: this
// is a human hand with venom on the fingertips, and it is meant to read that
// way both on the ground and held. The state exists in hand.dmi and in both
// touchspell inhand files, so the tint carries across all three.
/obj/item/melee/touch_attack/vestige_fang
	name = "venom fang"
	desc = "A hand held perfectly still, fingertips beaded with something green. Whatever it touches next gets the bite."
	icon_state = "greyscale"
	inhand_icon_state = "greyscale"
	color = "#9db83b" // venom sap

/**
 * The venom itself. STATUS_EFFECT_REFRESH: a second bite from the same fang
 * restarts the clock rather than stacking a second spool. The withering
 * subtype takes a distinct id, so base and withering venoms from two
 * different weavers can coexist. Within one player they never do, since the
 * upgrade replaces the base spell.
 */
/datum/status_effect/vestige_fang_venom
	id = "vestige_fang_venom"
	duration = VESTIGE_FANG_DURATION
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/vestige_fang_venom
	show_duration = TRUE

/datum/status_effect/vestige_fang_venom/on_apply()
	to_chat(owner, span_warning("Spider venom spreads through you, pulling the strength out of your limbs."))
	return TRUE

/datum/status_effect/vestige_fang_venom/tick(seconds_between_ticks)
	if(owner.stat == DEAD)
		return // venom has no interest in the dead; the clock runs out on its own
	owner.apply_damage(VESTIGE_FANG_STAMINA_TICK * seconds_between_ticks, STAMINA)
	owner.apply_damage(VESTIGE_FANG_TOX_TICK * seconds_between_ticks, TOX)

/datum/status_effect/vestige_fang_venom/on_remove()
	to_chat(owner, span_notice("The venom wears off."))
	return ..()

/atom/movable/screen/alert/status_effect/vestige_fang_venom
	name = "Spider Venom"
	desc = "Spider venom. Your stamina is draining and it is poisoning you for as long as it runs."
	icon_state = "weaken"

/datum/status_effect/vestige_fang_venom/withering
	id = "vestige_fang_venom_withering"
	duration = VESTIGE_FANG_WITHER_DURATION
	alert_type = /atom/movable/screen/alert/status_effect/vestige_fang_venom/withering

/datum/status_effect/vestige_fang_venom/withering/on_apply()
	. = ..()
	if(!.)
		return FALSE
	owner.add_movespeed_modifier(/datum/movespeed_modifier/vestige_fang_wither, update = TRUE)
	to_chat(owner, span_warning("Your legs go heavy, like you're wading through something you can't see."))
	return TRUE

/datum/status_effect/vestige_fang_venom/withering/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/vestige_fang_wither, update = TRUE)
	return ..()

/atom/movable/screen/alert/status_effect/vestige_fang_venom/withering
	name = "Withering Venom"
	desc = "Spider venom, the slow kind. Draining your stamina, poisoning you, and dragging at every step."

// A hobble on the freezing_blast pattern, half its slowdown, over a longer clock
/datum/movespeed_modifier/vestige_fang_wither
	multiplicative_slowdown = VESTIGE_FANG_WITHER_SLOW

// ===== THE LINE =====

/**
 * The dragline as mobility: a pointed spell that throws the CASTER at an
 * anchor. Precedents weighed against source: the meat-hook gun and the
 * changeling tentacle both pull the TARGET to the shooter (backwards for a
 * mobility tool), tethers carry component baggage, and jaunts teleport
 * (wrong genre and wrong counterplay). throw_at(..., spin = FALSE,
 * gentle = TRUE) is the most robust self-propulsion primitive the engine
 * offers: gentle throws are verified harmless on impact (thrownthing.dm:
 * "If the throw is gentle, then the thrownthing is harmless on impact"),
 * spin off keeps the flight dignified, and dense crossings interrupt the
 * flight exactly where physics says, the desc promises precisely that and
 * nothing more. No TRAIT_NOTELEPORT concerns: nothing teleports.
 *
 * Anchors must be solid purchase: a closed turf, or a dense anchored obj
 * (walls, airlocks, windows, bolted machinery). Mobs are refused, a line
 * that bites people is a pull tool, and that's the voidwalker's Come to the
 * Window, not the Weaver's craft. Being buckled or already mid-throw refuses
 * the cast in before_cast, so a bad cast never spends the cooldown.
 */
/datum/action/cooldown/spell/pointed/vestige_silk_line
	name = "Silk Line"
	desc = "Fire a silk line at a wall, window or anything else solid in reach and reel yourself to it. Anything in the way is where you stop."
	button_icon = 'icons/mob/actions/actions_animal.dmi'
	button_icon_state = "spider_ropes"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	active_msg = "You draw out a casting line and let it hang from your wrist..."
	deactive_msg = "You wind the line back around your wrist."
	cooldown_time = VESTIGE_LINE_COOLDOWN
	cast_range = VESTIGE_LINE_RANGE
	aim_assist = FALSE // the line wants terrain, not the person standing on it
	invocation_type = INVOCATION_NONE
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC

/datum/action/cooldown/spell/pointed/vestige_silk_line/is_valid_target(atom/cast_on)
	if(isclosedturf(cast_on))
		return TRUE
	if(isobj(cast_on))
		var/obj/anchor = cast_on
		if(anchor.density && anchor.anchored)
			return TRUE
	owner.balloon_alert(owner, "the line needs solid purchase!")
	return FALSE

// Fork quirk: every refusal must land before cast, a cancelled before_cast
// spends no cooldown, and nothing after it can take the cooldown back
/datum/action/cooldown/spell/pointed/vestige_silk_line/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	if(owner.buckled)
		owner.balloon_alert(owner, "strapped down!")
		return . | SPELL_CANCEL_CAST
	if(owner.throwing)
		owner.balloon_alert(owner, "already in flight!")
		return . | SPELL_CANCEL_CAST
	if(!isturf(owner.loc))
		owner.balloon_alert(owner, "no room to be reeled!")
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/pointed/vestige_silk_line/cast(atom/cast_on)
	. = ..()
	owner.Beam(cast_on, icon_state = "fishing_line", time = VESTIGE_LINE_BEAM_TIME)
	playsound(owner, 'sound/items/weapons/whipgrab.ogg', 50, TRUE)
	owner.visible_message(
		span_warning("[owner] casts a gleaming line of silk at [cast_on] and hauls [owner.p_them()]self down it!"),
		span_notice("The line bites [cast_on]. You reel yourself in."),
	)
	// +1 range margin so a max-distance anchor is always reachable; the throw
	// ends early and honestly at the first dense thing the flight meets
	owner.throw_at(cast_on, VESTIGE_LINE_RANGE + 1, VESTIGE_LINE_SPEED, thrower = owner, spin = FALSE, gentle = TRUE)

#undef VESTIGE_SILK_SPIN_TIME
#undef VESTIGE_SILK_SPIN_TIME_MASTER
#undef VESTIGE_SILK_COOLDOWN
#undef VESTIGE_SILK_COOLDOWN_MASTER
#undef VESTIGE_SILK_MAX_WEBS
#undef VESTIGE_SILK_MAX_WEBS_MASTER
#undef VESTIGE_SILK_DOAFTER
#undef VESTIGE_FANG_COOLDOWN
#undef VESTIGE_FANG_WITHER_COOLDOWN
#undef VESTIGE_FANG_DURATION
#undef VESTIGE_FANG_WITHER_DURATION
#undef VESTIGE_FANG_STAMINA_TICK
#undef VESTIGE_FANG_TOX_TICK
#undef VESTIGE_FANG_WITHER_SLOW
#undef VESTIGE_LINE_RANGE
#undef VESTIGE_LINE_COOLDOWN
#undef VESTIGE_LINE_SPEED
#undef VESTIGE_LINE_BEAM_TIME
#undef VESTIGE_GRACE_TRAIT
