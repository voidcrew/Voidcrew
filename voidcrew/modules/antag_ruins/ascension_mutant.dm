/**
 * # Specimen Zero, and Greater Telekinesis
 *
 * The Curator's capstone. See voidcrew/modules/antag_ruins/ascension.dm for the
 * framework this plugs into. The run datum owns the arena, spawns the boss on the
 * map's boss landmark, and grants [/datum/vestige_boon/spell/greater_telekinesis] the
 * moment the boss dies. Nothing in this file has to know any of that; it only has to
 * put a fight in the room and an ability on the other side of it.
 *
 * ## The boss
 *
 * An abductor test subject that let itself out of its cell on the fourth revision and
 * has been kept in the lab ever since. It fights exactly one player, always, so it is
 * tuned as a hard solo fight rather than a raid boss with the health divided down.
 *
 * Its kit is telekinetic on purpose: it is the source of the ability the supplicant
 * came to take, and it demonstrates that ability by throwing the room. Three abilities
 * to start with, a fourth at the phase flip:
 *
 * - **Sweep the Room**: every loose object around it rattles, lifts, and is thrown at
 *   the player one after another, each shot aimed at wherever they are standing when it
 *   fires. Stand still and eat all of it; keep moving and most of it lands behind you.
 *   Grabbing a lifted item off the floor mid-telegraph takes that shot out of the volley.
 * - **Pin**: it marks a floor tile, and anything still standing there when the mark
 *   fills gets picked up and put back down hard. Step off the tile.
 * - **Repulse**: a shove outward from itself that throws you clear and knocks you flat.
 *   It only fires when something is standing close, so it is the answer to parking in
 *   melee forever, not a random tax.
 * - **Confiscation** (fourth revision only): it takes whatever is in your hand and
 *   throws it back at you. Counterplay is picking your weapon back up, which costs you
 *   the ten seconds it spends setting up its next move.
 *
 * It is deliberately **not** `/mob/living/basic/boss` and deliberately not megafauna:
 * `code/modules/unit_tests/voidcrew_loot.dm` text-scans every ruin .dmm and hard-fails
 * any map carrying either string outside a legacy whitelist. The stat block below is
 * hand-copied from that tier; the inheritance is not. Do not reparent it.
 *
 * ## The capstone
 *
 * [/datum/action/cooldown/spell/greater_telekinesis] is a toggle. While it is up, the
 * caster's clicks are intercepted (`COMSIG_MOB_CLICKON`) and read differently depending
 * on combat mode: out of combat a click drags anything loose, objects, furniture,
 * machines, people, across the floor into orbit around them (the pull travels as a
 * real throw and anything that can stop a throw can stop it; people can resist free),
 * and in combat a click hurls one held thing, right-click hurls all of them. Bolted-down
 * objects can be torn loose with a five-second channel first. Held things double as a
 * shield: each one adds a chance that a melee or thrown hit is knocked aside, at the
 * price of that thing falling out of orbit. Upstream's `/obj/item/tk_grab` is
 * single-item and lives in a hand slot, so none of it is reusable here; the click
 * plumbing is our own and the levitation is the stock orbiter component.
 *
 * ## Cleanup
 *
 * Nothing in this file needs to tidy up after itself at round scale. The arena lives in
 * a turf reservation the run owns outright and frees when it ends, so the debris the
 * fight leaves on the floor goes with it. The conjured debris still deletes itself on a
 * timer, because the harness (below) is a *loot item* and gets carried out of the arena.
 */

// ===== THE CAPSTONE =====
// The ability desc quotes these numbers literally. Keep them in sync.
/// Most items the caster may hold in the air at once.
#define GREATER_TK_MAX_HELD 5
/// How far away an item may be and still be lifted.
#define GREATER_TK_RANGE 9
/// How far a hurled item travels.
#define GREATER_TK_THROW_RANGE 12
/// How fast a hurled item travels. Stock thrown items manage 2-3.
#define GREATER_TK_THROW_SPEED 4
/// Brute added on top of the item's own throwforce when a hurled item lands on someone.
#define GREATER_TK_IMPACT_DAMAGE 25
/// How long a bulky-or-larger hurled item keeps its victim off their feet.
#define GREATER_TK_HEAVY_KNOCKDOWN (1 SECONDS)
/// Recharge on the toggle itself. Purely anti-flicker.
#define GREATER_TK_TOGGLE_COOLDOWN (2 SECONDS)
/// Innermost orbit radius, in pixels. Each further item sits a little further out.
#define GREATER_TK_ORBIT_RADIUS 12
/// How fast a pulled object crosses the floor to the caster. A stock throw is 2-3.
#define GREATER_TK_PULL_SPEED 3
/// Chance per held object that an incoming blow is swatted aside, spending that object.
#define GREATER_TK_BLOCK_CHANCE_PER_ITEM 10
/// How long the caster must keep their grip on a bolted-down object to tear it loose.
#define GREATER_TK_RIP_TIME (5 SECONDS)
/// Orbit slots a living creature occupies. Everything else costs one.
#define GREATER_TK_MOB_SLOT_COST 2
/// Heaviest move_resist the field can shift. Blocks megafauna, mechs and the specimen
/// itself without needing a type list.
#define GREATER_TK_MAX_MOVE_RESIST MOVE_FORCE_STRONG

// ===== SHARED =====
/// Filter key for the outline every telekinetically held object wears.
#define VESTIGE_TK_FILTER "vestige_telekinesis"
/// The violet the abductor theme already uses for its instruments.
#define VESTIGE_TK_COLOR "#b46fd6"

// ===== THE BOSS =====
/// Hand-copied from the hoarfrost/lich tier, then cut for a fight with exactly one
/// player in it. See the file header.
#define MUTANT_MAX_HEALTH 1500
/// Fraction of max HP at or below which the fourth revision arrives.
#define MUTANT_REVISION_THRESHOLD 0.5
/// Every cooldown is multiplied by this at the revision.
#define MUTANT_REVISION_SCALE 0.7
/// Filter key for the outline it wears afterwards.
#define MUTANT_REVISION_FILTER "vestige_mutant_revision"
/// How long it tolerates losing its quarry before it starts closing up.
#define MUTANT_DISENGAGE_GRACE (10 SECONDS)
/// Beyond this, or with line of sight broken, it counts as disengaged. Sized off the
/// arena, which is 33 tiles across: from the boss landmark every corner of the specimen
/// floor is exactly 16 away, so standing in one is not a hiding place.
#define MUTANT_DISENGAGE_RANGE 16
/// Fraction of max HP regained per second while disengaged.
#define MUTANT_DISENGAGE_REGEN 0.04
/// How far from its spawn tile the leash lets it get. Generous on purpose: it has to be
/// able to reach every tile of its own room, and following someone back up the approach
/// is fine. The disengage regen is what punishes retreating, not the leash.
#define MUTANT_LEASH_RANGE 20

/// Recharge between sweeps.
#define MUTANT_SWEEP_COOLDOWN (16 SECONDS)
/// How far out it strips the floor for ammunition.
#define MUTANT_SWEEP_RADIUS 7
/// Objects thrown per sweep, before and after the revision.
#define MUTANT_SWEEP_VOLLEY 6
#define MUTANT_SWEEP_VOLLEY_REVISED 10
/// How long everything rattles on the deck before the first shot.
#define MUTANT_SWEEP_TELEGRAPH (1.5 SECONDS)
/// Gap between shots in a volley. Each shot is aimed when it fires, so this gap is
/// what makes "keep moving" the counter, shorten it and the volley collapses into
/// one burst you dodge (or eat) all at once.
#define MUTANT_SWEEP_STAGGER (1.5 SECONDS)
/// A sweep that finds less ammunition than this tears the difference out of the walls.
#define MUTANT_SWEEP_FLOOR 4
/// How long conjured debris lasts before it crumbles.
#define MUTANT_DEBRIS_LIFETIME (90 SECONDS)

/// Recharge between pins.
#define MUTANT_PIN_COOLDOWN (20 SECONDS)
/// How long the mark sits on the floor before it closes.
#define MUTANT_PIN_TELEGRAPH (1.5 SECONDS)
/// Brute dealt to whoever is still standing on the mark.
#define MUTANT_PIN_DAMAGE 28
/// How long a pinned target stays down.
#define MUTANT_PIN_KNOCKDOWN (2 SECONDS)
/// Tiles a pinned target is thrown, straight away from the mark.
#define MUTANT_PIN_THROW 3

/// Recharge between repulses.
#define MUTANT_REPULSE_COOLDOWN (25 SECONDS)
/// How long it winds up before the shove.
#define MUTANT_REPULSE_TELEGRAPH (1.2 SECONDS)
/// Radius of the shove, before and after the revision.
#define MUTANT_REPULSE_RADIUS 4
#define MUTANT_REPULSE_RADIUS_REVISED 6
/// Brute dealt by the shove.
#define MUTANT_REPULSE_DAMAGE 18
/// Tiles the shove throws you.
#define MUTANT_REPULSE_DISTANCE 5
/// How long the shove keeps you down.
#define MUTANT_REPULSE_KNOCKDOWN (1.5 SECONDS)

/// Recharge between confiscations.
#define MUTANT_CONFISCATE_COOLDOWN (22 SECONDS)
/// How long it holds your property before handing it back at speed.
#define MUTANT_CONFISCATE_HOLD (1.5 SECONDS)

// Blackboard keys for its kit. Confined to this file; the mob publishes them through
// register_kit rather than seeding them itself, so the include order cannot break.
#define BB_MUTANT_SWEEP "BB_mutant_sweep"
#define BB_MUTANT_PIN "BB_mutant_pin"
#define BB_MUTANT_REPULSE "BB_mutant_repulse"
#define BB_MUTANT_CONFISCATE "BB_mutant_confiscate"
/// Key of the last ability used, excluded from the next roll.
#define BB_MUTANT_LAST_ABILITY "BB_mutant_last_ability"

// ===== THE DROPS =====
/// How often the specimen collar can stop a thrown object.
#define COLLAR_CATCH_COOLDOWN (1 SECONDS)
/// Recharge on the palm anchor.
#define PALM_ANCHOR_COOLDOWN (30 SECONDS)
/// How far away the palm anchor can mark a tile.
#define PALM_ANCHOR_RANGE 7
/// Recharge on the debris harness.
#define HARNESS_COOLDOWN (25 SECONDS)
/// How far out the harness strips the floor.
#define HARNESS_RADIUS 5
/// Objects the harness throws per use.
#define HARNESS_VOLLEY 5

// =========================================================================
// GREATER TELEKINESIS: the capstone boon
// =========================================================================

/datum/vestige_boon/spell/greater_telekinesis
	name = "Greater Telekinesis"
	// Keep the numbers in sync with the defines above (initial values must be
	// compile-time constant, so no define interpolation here).
	desc = "Hold an armful of loose objects, furniture, machines, even people in the air around you. Bolted-down things come up too if you hold your grip on them. Combat mode off: click to drag something to you, click a held thing to set it down. Combat mode on: left-click throws one, right-click throws everything. What you're holding will sometimes turn a hit aside."
	grant_text = "Everything loose in the room is suddenly within arm's reach, and your arms have nothing to do with it."
	spell_type = /datum/action/cooldown/spell/greater_telekinesis

/**
 * The toggle.
 *
 * While it is up the caster's clicks go through [on_click] before anything else touches
 * them, and combat mode decides what a click means. Everything the ability is holding
 * orbits the caster on the stock orbiter component (`code/datums/components/orbiter.dm`),
 * which keeps each item abstract-moved onto whatever turf the caster is standing on and
 * follows them anywhere, including across z-levels and through forceMoves.
 *
 * Nothing goes straight into orbit: [pull_thing] throws it across the floor at the
 * caster and it sits in [pulling_in] until it lands, only joining [lifted] if it
 * actually arrived within arm's reach ([on_pull_finished]). Bolted-down objects add a
 * five-second channel in front of that ([rip_loose]). Living creatures ride the same
 * pipeline as everything else. The only mob-specific handling is the immobilize
 * trait and resist hook added in [lift_thing] and removed in [forget_thing].
 *
 * Every way a held thing can leave the set funnels through exactly two procs:
 * [forget_thing] drops our bookkeeping and touches it no further (used when the
 * world took it away from us), and [release_thing] does that *and then* ends the orbit
 * (used when we are the ones letting go). Because release_thing removes the thing from
 * [lifted] before it calls end_orbit, the COMSIG_ATOM_ORBIT_STOP that end_orbit fires
 * finds nothing to clean up and returns, no re-entry, no flag needed.
 */
/datum/action/cooldown/spell/greater_telekinesis
	name = "Greater Telekinesis"
	desc = "Hold an armful of objects, furniture or people in the air around you, anywhere in sight. Combat mode off: click to pull things in, click a held thing to set it down. Combat mode on: left-click throws one, right-click throws everything. Heavy throws knock people over."
	button_icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	button_icon_state = "greater_telekinesis"
	school = SCHOOL_PSYCHIC
	cooldown_time = GREATER_TK_TOGGLE_COOLDOWN
	// No robe, no hat, no words. The Curator does not issue vestments.
	spell_requirements = NONE
	invocation_type = INVOCATION_NONE
	panel = "Spells"

	/// Everything currently in the air around the caster, in the order it was lifted.
	var/list/atom/movable/lifted = list()
	/// Things still crossing the floor on their way to the caster. Not held yet, they
	/// only join [lifted] if they actually arrive. See [pull_thing].
	var/list/atom/movable/pulling_in = list()
	/// The bolted-down object currently being torn loose, if any. One rip at a time.
	var/atom/movable/ripping
	/// TRUE while the field is up and clicks are being read.
	var/lifting = FALSE
	/// Grant changes owner before removing the old body; field signals still belong to this body.
	var/mob/living/field_owner
	/// A canceled old rip cannot complete or clear a later body's channel.
	var/rip_generation = 0

/datum/action/cooldown/spell/greater_telekinesis/Destroy()
	stop_lifting(silent = TRUE)
	lifted = null
	pulling_in = null
	ripping = null
	return ..()

/datum/action/cooldown/spell/greater_telekinesis/Remove(mob/living/remove_from)
	// Before the parent nulls owner out from under us.
	stop_lifting(silent = TRUE)
	return ..()

/// The button shows as active while the field is up. The parent's version only knows
/// about click_to_activate abilities, and this is not one.
/datum/action/cooldown/spell/greater_telekinesis/is_action_active(atom/movable/screen/movable/action_button/current_button)
	return lifting

/datum/action/cooldown/spell/greater_telekinesis/cast(atom/cast_on)
	. = ..()
	if(lifting)
		stop_lifting()
		return
	start_lifting()

// ===== THE FIELD =====

/datum/action/cooldown/spell/greater_telekinesis/proc/start_lifting()
	if(lifting || !isliving(owner))
		return
	lifting = TRUE
	field_owner = owner
	RegisterSignal(owner, COMSIG_MOB_CLICKON, PROC_REF(on_click), override = TRUE)
	RegisterSignal(owner, COMSIG_ATOM_ORBIT_STOP, PROC_REF(on_orbit_lost), override = TRUE)
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_died), override = TRUE)
	RegisterSignal(owner, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(on_check_block), override = TRUE)
	build_all_button_icons(UPDATE_BUTTON_STATUS)
	playsound(owner, 'sound/effects/magic/charge.ogg', 40, TRUE)
	to_chat(owner, span_boldnotice("Everything loose in the room comes into reach. Click things to lift them; \
		switch to combat mode to throw them."))

/**
 * Puts the field down and sets everything it was holding on the floor.
 *
 * Called by the toggle, by the caster dying, and by the ability being stripped off a
 * body. Safe to call when the field is already down.
 */
/datum/action/cooldown/spell/greater_telekinesis/proc/stop_lifting(silent = FALSE)
	if(!lifting)
		return
	lifting = FALSE
	rip_generation++
	for(var/atom/movable/thing as anything in lifted.Copy())
		release_thing(thing)
	// Anything still mid-pull keeps its momentum and lands as an ordinary object.
	for(var/atom/movable/thing as anything in pulling_in.Copy())
		cancel_pull(thing)
	ripping = null
	if(field_owner)
		UnregisterSignal(field_owner, list(COMSIG_MOB_CLICKON, COMSIG_ATOM_ORBIT_STOP, COMSIG_LIVING_DEATH, COMSIG_LIVING_CHECK_BLOCK))
		if(!silent)
			playsound(field_owner, 'sound/effects/magic/blind.ogg', 30, TRUE)
			to_chat(field_owner, span_notice("You let the room go. Everything you were holding lands at your feet."))
	field_owner = null
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/datum/action/cooldown/spell/greater_telekinesis/proc/on_owner_died(mob/living/source)
	SIGNAL_HANDLER
	stop_lifting(silent = TRUE)

// ===== CLICKS =====

/**
 * The whole interface.
 *
 * Deliberately conservative about what it eats. Anything modified (shift, ctrl, alt,
 * middle) and anything on the HUD passes straight through, so examining, pulling and
 * the action bar all keep working with the field up. Out of combat, only a click on a
 * liftable object is intercepted. Doors, machines and conversations are untouched.
 * In combat with something held, every click becomes a throw, which is the tradeoff:
 * you cannot swing a weapon and hold the room at the same time.
 */
/datum/action/cooldown/spell/greater_telekinesis/proc/on_click(mob/living/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(!lifting || QDELETED(target) || source != field_owner || source != owner || !isliving(source))
		return NONE
	if(source.stat != CONSCIOUS)
		return NONE
	// Never swallow the HUD, and never swallow the clicks players use to look at things.
	if(istype(target, /atom/movable/screen))
		return NONE
	if(LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK))
		return NONE
	if(LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, MIDDLE_CLICK))
		return NONE

	if(source.combat_mode)
		return throw_click(source, target, LAZYACCESS(modifiers, RIGHT_CLICK))
	// Out of combat, right-click stays the game's own secondary interaction.
	if(LAZYACCESS(modifiers, RIGHT_CLICK))
		return NONE
	return grab_click(source, target)

/// Out of combat: pull things to you, tear bolted things loose, or put held things down.
/datum/action/cooldown/spell/greater_telekinesis/proc/grab_click(mob/living/source, atom/target)
	if(!ismovable(target) || target == source)
		return NONE
	var/atom/movable/thing = target
	if(thing in lifted)
		release_thing(thing)
		source.balloon_alert(source, "set down ([used_slots()]/[GREATER_TK_MAX_HELD])")
		return COMSIG_MOB_CANCEL_CLICKON
	// Clicking something already on its way in changes your mind about it: it keeps
	// flying, but it lands as an ordinary object instead of joining the orbit.
	if(thing in pulling_in)
		cancel_pull(thing)
		source.balloon_alert(source, "released")
		return COMSIG_MOB_CANCEL_CLICKON
	var/needs_ripping = can_rip(thing)
	if(!needs_ripping && !can_lift(thing))
		return NONE
	// Past this point it IS something we lift, so a refusal is worth saying out loud
	// rather than quietly falling through to a normal click. Things mid-pull count
	// against the cap, each has its slots booked whether or not it arrives.
	if(used_slots() + slot_cost(thing) > GREATER_TK_MAX_HELD)
		source.balloon_alert(source, "no room to hold it!")
		return COMSIG_MOB_CANCEL_CLICKON
	// Measured off the containing turf: an item in somebody's fist has no map coordinates
	// of its own, and get_dist on one of those answers nonsense.
	var/turf/resting_on = get_turf(thing)
	if(isnull(resting_on) || source.z != resting_on.z || get_dist(source, resting_on) > GREATER_TK_RANGE)
		source.balloon_alert(source, "too far!")
		return COMSIG_MOB_CANCEL_CLICKON
	// The same sightline a throw would need, checked up front so a click through a
	// window refuses cleanly instead of launching a pull straight into the glass.
	if(!can_see(source, resting_on, GREATER_TK_RANGE))
		source.balloon_alert(source, "no line of sight!")
		return COMSIG_MOB_CANCEL_CLICKON
	if(needs_ripping)
		// The channel sleeps, and a signal handler must not.
		INVOKE_ASYNC(src, PROC_REF(rip_loose), source, thing)
		return COMSIG_MOB_CANCEL_CLICKON
	pull_thing(source, thing)
	return COMSIG_MOB_CANCEL_CLICKON

/// In combat: throw one, or throw the lot.
/datum/action/cooldown/spell/greater_telekinesis/proc/throw_click(mob/living/source, atom/target, all_of_them)
	if(!length(lifted))
		return NONE // nothing held, so let the punch land
	if(target in lifted)
		source.balloon_alert(source, "aim somewhere else!")
		return COMSIG_MOB_CANCEL_CLICKON
	var/turf/destination = get_turf(target)
	if(isnull(destination))
		return NONE
	if(destination == get_turf(source))
		source.balloon_alert(source, "not at yourself!")
		return COMSIG_MOB_CANCEL_CLICKON

	var/list/atom/movable/volley = all_of_them ? lifted.Copy() : list(lifted[length(lifted)])
	for(var/atom/movable/thing as anything in volley)
		hurl(source, thing, target)
	source.changeNext_move(CLICK_CD_MELEE)
	playsound(source, 'sound/effects/magic/repulse.ogg', 60, TRUE)
	return COMSIG_MOB_CANCEL_CLICKON

// ===== HOLDING =====

/// Is this the kind of thing the field can pick up at all? Says nothing about range
/// or how full our hands are, see [grab_click] for the refusals worth voicing.
/datum/action/cooldown/spell/greater_telekinesis/proc/can_lift(atom/movable/thing)
	if(QDELETED(thing) || thing == owner || thing.throwing || thing.anchored)
		return FALSE
	// The one weight limit: whatever the game itself says cannot be shoved around.
	// Megafauna, mechs, the specimen: cannot be lifted either.
	if(thing.move_resist > GREATER_TK_MAX_MOVE_RESIST)
		return FALSE
	if(isliving(thing))
		var/mob/living/victim = thing
		if(victim.buckled)
			return FALSE
		return isturf(victim.loc)
	if(!isobj(thing)) // effects, projectiles, ghosts: nothing to grip
		return FALSE
	if(isitem(thing))
		var/obj/item/held = thing
		if(held.item_flags & ABSTRACT)
			return FALSE
		if(HAS_TRAIT(held, TRAIT_NODROP))
			return FALSE
		// On the floor, or in somebody's hand. Not in a bag, not in a crate, the field
		// lifts what it can see, and it cannot see into a backpack.
		return isturf(held.loc) || isliving(held.loc)
	// Furniture, machines, closets, crates: anything standing free on the floor.
	return isturf(thing.loc)

/**
 * Is this a bolted-down object the field could tear loose?
 *
 * Wall gear and anything meshed into a network is off the table: doors and windows
 * because ripping them out is a free breaching tool, pipes/cables/ducts/disposals
 * because flipping their anchored flag without their own disconnect logic corrupts
 * the net they belong to.
 */
/datum/action/cooldown/spell/greater_telekinesis/proc/can_rip(atom/movable/thing)
	if(QDELETED(thing) || thing.throwing || !thing.anchored || !isobj(thing))
		return FALSE
	if(!isturf(thing.loc))
		return FALSE
	if(thing.move_resist > GREATER_TK_MAX_MOVE_RESIST)
		return FALSE
	var/obj/bolted = thing
	if(bolted.resistance_flags & INDESTRUCTIBLE)
		return FALSE
	var/static/list/never_rip = typecacheof(list(
		/obj/machinery/door,
		/obj/structure/window,
		/obj/structure/grille,
		/obj/structure/cable,
		/obj/structure/disposalpipe,
		/obj/machinery/atmospherics,
		/obj/machinery/duct,
		/obj/machinery/power/apc,
		/obj/machinery/airalarm,
		/obj/machinery/firealarm,
		/obj/machinery/button,
		/obj/machinery/camera,
		/obj/machinery/light,
		/obj/item/radio/intercom,
	))
	return !is_type_in_typecache(thing, never_rip)

/// How many of the five slots this thing occupies while held or inbound.
/datum/action/cooldown/spell/greater_telekinesis/proc/slot_cost(atom/movable/thing)
	return isliving(thing) ? GREATER_TK_MOB_SLOT_COST : 1

/// Slots spent across everything held and everything still flying in.
/datum/action/cooldown/spell/greater_telekinesis/proc/used_slots()
	. = 0
	for(var/atom/movable/thing as anything in lifted)
		. += slot_cost(thing)
	for(var/atom/movable/thing as anything in pulling_in)
		. += slot_cost(thing)

// ===== RIPPING =====

/**
 * Tears a bolted-down object off the deck: five seconds of held concentration, then
 * the bolts give and the object goes into the ordinary pull flow. Async off the click
 * handler, because a signal handler must not sleep.
 */
/datum/action/cooldown/spell/greater_telekinesis/proc/rip_loose(mob/living/source, atom/movable/thing)
	if(!lifting || source != owner || source != field_owner || !can_rip(thing))
		return
	if(ripping)
		source.balloon_alert(source, "already tearing something loose!")
		return
	ripping = thing
	var/this_rip = ++rip_generation
	source.balloon_alert(source, "tearing it loose...")
	thing.visible_message(span_warning("[thing] starts straining against its own bolts!"))
	playsound(thing, 'sound/machines/airlock/airlock_alien_prying.ogg', 60, TRUE)
	thing.Shake(pixelshiftx = 1, pixelshifty = 1, duration = GREATER_TK_RIP_TIME)
	var/held_on = do_after(source, GREATER_TK_RIP_TIME, target = thing, extra_checks = CALLBACK(src, PROC_REF(keep_ripping), source, thing, this_rip))
	if(this_rip != rip_generation)
		return
	ripping = null
	if(!held_on)
		source.balloon_alert(source, "lost your grip!")
		return
	if(!lifting || source != owner || source != field_owner || QDELETED(thing) || !thing.anchored || !can_rip(thing))
		return
	// The channel guaranteed a slot when it started; somebody may have filled it since.
	if(used_slots() + slot_cost(thing) > GREATER_TK_MAX_HELD)
		source.balloon_alert(source, "no room to hold it!")
		return
	thing.set_anchored(FALSE)
	playsound(thing, 'sound/effects/bang.ogg', 60, TRUE)
	new /obj/effect/temp_visual/telekinesis(get_turf(thing))
	thing.visible_message(span_boldwarning("[thing] tears loose from the deck, bolts and all!"))
	pull_thing(source, thing)

/// The rip channel only holds while the field is up and the caster is with us.
/datum/action/cooldown/spell/greater_telekinesis/proc/keep_ripping(mob/living/source, atom/movable/thing, generation)
	return lifting && !QDELETED(owner) && source == owner && source == field_owner && ripping == thing && generation == rip_generation

// ===== PULLING =====

/**
 * Starts dragging something across the floor to the caster.
 *
 * It travels as a real throw aimed at the caster's own tile, with the caster as the
 * thrower, the throwing subsystem never lets an object throw hit its own thrower, so
 * objects glide to their feet rather than striking them. A pulled person is dense and
 * simply bumps to a stop on the adjacent tile, which counts as arriving. Everything
 * else that can stop a throw can stop the pull: a wall, a closed door, a window, or a
 * bystander it slams into (who can simply catch a small item). The grab only
 * completes when the thing actually arrives, see [on_pull_finished].
 */
/datum/action/cooldown/spell/greater_telekinesis/proc/pull_thing(mob/living/source, atom/movable/thing)
	if(isitem(thing) && isliving(thing.loc))
		var/mob/living/holder = thing.loc
		var/obj/item/held = thing
		if(!holder.dropItemToGround(held))
			source.balloon_alert(source, "it won't come loose!")
			return FALSE
		holder.visible_message(
			span_warning("[held] tears itself out of [holder]'s hand!"),
			span_userdanger("[held] is pulled straight out of your hand!"),
		)
	if(!isturf(thing.loc))
		return FALSE
	// Already within arm's reach: there is no trip to make, just take it.
	if(get_dist(source, thing) <= 1)
		return lift_thing(source, thing)

	pulling_in += thing
	RegisterSignal(thing, COMSIG_QDELETING, PROC_REF(on_thing_deleted), override = TRUE)
	thing.add_filter(VESTIGE_TK_FILTER, 2, list("type" = "outline", "color" = VESTIGE_TK_COLOR, "size" = 1))
	new /obj/effect/temp_visual/telekinesis(get_turf(thing))
	playsound(thing, 'sound/effects/magic/ethereal_enter.ogg', 25, TRUE)
	if(isliving(thing))
		var/mob/living/victim = thing
		victim.visible_message(
			span_warning("[victim] is dragged bodily across the deck towards [source]!"),
			span_userdanger("Something takes hold of your whole body and drags you towards [source]!"),
		)
	if(!thing.throw_at(get_turf(source), GREATER_TK_RANGE + 1, GREATER_TK_PULL_SPEED, source, spin = FALSE, callback = CALLBACK(src, PROC_REF(on_pull_finished), thing), gentle = TRUE))
		cancel_pull(thing)
		source.balloon_alert(source, "it won't budge!")
		return FALSE
	return TRUE

/**
 * The pull is over, one way or the other.
 *
 * If the thing made it to within arm's reach of the caster it goes into orbit.
 * Anywhere else means something stopped it, a wall it fell short against, a
 * doorframe, or a hand that got to it first, and the grab simply fails.
 */
/datum/action/cooldown/spell/greater_telekinesis/proc/on_pull_finished(atom/movable/thing)
	if(!(thing in pulling_in)) // cancelled mid-flight; it lands as an ordinary object
		return
	pulling_in -= thing
	if(QDELETED(thing))
		return
	var/mob/living/source = owner
	if(!lifting || !isliving(source) || source.stat != CONSCIOUS)
		end_pull_visuals(thing)
		return
	if(isturf(thing.loc) && thing.z == source.z && get_dist(source, thing) <= 1 && can_lift(thing) && used_slots() + slot_cost(thing) <= GREATER_TK_MAX_HELD)
		lift_thing(source, thing)
		return
	end_pull_visuals(thing)
	source.balloon_alert(source, "out of reach!")

/// Stops tracking something we were pulling in. It keeps whatever momentum it had;
/// it just lands as an ordinary object instead of joining the orbit.
/datum/action/cooldown/spell/greater_telekinesis/proc/cancel_pull(atom/movable/thing)
	pulling_in -= thing
	if(!QDELETED(thing))
		end_pull_visuals(thing)

/// Strips the pull markings off something that is not becoming held after all.
/datum/action/cooldown/spell/greater_telekinesis/proc/end_pull_visuals(atom/movable/thing)
	UnregisterSignal(thing, COMSIG_QDELETING)
	thing.remove_filter(VESTIGE_TK_FILTER)

/// Puts something into orbit. By the time this runs it is on a turf within arm's
/// reach, [pull_thing] and [on_pull_finished] have already done the travelling.
/datum/action/cooldown/spell/greater_telekinesis/proc/lift_thing(mob/living/source, atom/movable/thing)
	if(!isturf(thing.loc))
		return FALSE
	// End the previous caster's hold before adding our shared outline and immobilization source.
	// Orbiter.begin_orbit would otherwise release it after our new effects were installed.
	thing.orbiting?.end_orbit(thing)

	pulling_in -= thing
	lifted += thing
	RegisterSignal(thing, COMSIG_QDELETING, PROC_REF(on_thing_deleted), override = TRUE)
	thing.add_filter(VESTIGE_TK_FILTER, 2, list("type" = "outline", "color" = VESTIGE_TK_COLOR, "size" = 1))
	if(isliving(thing))
		var/mob/living/captive = thing
		// Held fast, not stunned: they can still swing, shoot and resist. Walking out
		// of the orbit is the one thing the grip denies them.
		ADD_TRAIT(captive, TRAIT_IMMOBILIZED, VESTIGE_TK_FILTER)
		RegisterSignal(captive, COMSIG_LIVING_RESIST, PROC_REF(on_captive_resist), override = TRUE)
		captive.visible_message(
			span_boldwarning("[captive] is hauled into the air, circling [source] like a moon!"),
			span_userdanger("You are wrenched off the deck! Resist to tear yourself free!"),
		)
	// Each slot rides a little further out and a little slower, so five objects read as
	// five objects rather than one blurred clump.
	var/slot = length(lifted)
	thing.orbit(source, GREATER_TK_ORBIT_RADIUS + (slot * 4), (slot % 2), 18 + (slot * 3), 36, FALSE)
	if(thing.orbiting?.parent != source)
		forget_thing(thing)
		return FALSE
	new /obj/effect/temp_visual/telekinesis(get_turf(source))
	playsound(source, 'sound/effects/magic/ethereal_enter.ogg', 25, TRUE)
	source.balloon_alert(source, "lifted ([used_slots()]/[GREATER_TK_MAX_HELD])")
	return TRUE

/// Drops our bookkeeping for something without touching it further. For when the
/// world already took it away from us.
/datum/action/cooldown/spell/greater_telekinesis/proc/forget_thing(atom/movable/thing)
	lifted -= thing
	pulling_in -= thing
	if(QDELETED(thing))
		return
	UnregisterSignal(thing, COMSIG_QDELETING)
	thing.remove_filter(VESTIGE_TK_FILTER)
	if(isliving(thing))
		REMOVE_TRAIT(thing, TRAIT_IMMOBILIZED, VESTIGE_TK_FILTER)
		UnregisterSignal(thing, COMSIG_LIVING_RESIST)
	// The orbiter cannot clean up after itself: end_orbit "cancels" its endless spin
	// with a zero-length PARALLEL animation, which starts a second track and leaves the
	// endless one running, so a released object keeps circling its resting place
	// forever, on the floor or in flight. (Ghosts never show this because their float
	// animation overwrites every track the moment the orbit ends; plain objects have
	// nothing that would.) Killing every animation track here lets end_orbit's
	// transform restore actually show, and any throw spin is applied after this.
	animate(thing)

/// Sets something down. Bookkeeping first, so the orbit-stop signal end_orbit fires
/// finds nothing left to clean up.
/datum/action/cooldown/spell/greater_telekinesis/proc/release_thing(atom/movable/thing)
	if(!(thing in lifted))
		return
	forget_thing(thing)
	if(QDELETED(thing))
		return
	var/datum/component/orbiter/holding_it = thing.orbiting
	holding_it?.end_orbit(thing)

/// Somebody grabbed one of ours off our own tile, or the component gave up on it.
/datum/action/cooldown/spell/greater_telekinesis/proc/on_orbit_lost(atom/source, atom/movable/departed)
	SIGNAL_HANDLER
	if(!(departed in lifted))
		return
	forget_thing(departed)
	if(isliving(source))
		var/mob/living/caster = source
		caster.balloon_alert(caster, "lost hold of it")

/datum/action/cooldown/spell/greater_telekinesis/proc/on_thing_deleted(atom/movable/source)
	SIGNAL_HANDLER
	forget_thing(source)

/// A held creature fights the grip. One resist is enough. The hold is a beat of
/// control and a throw, not a jail.
/datum/action/cooldown/spell/greater_telekinesis/proc/on_captive_resist(mob/living/captive)
	SIGNAL_HANDLER
	if(!(captive in lifted))
		return
	captive.visible_message(
		span_warning("[captive] wrenches [captive.p_them()]self out of the invisible grip and drops to the deck!"),
		span_notice("You tear yourself free of the grip and drop to the deck."),
	)
	release_thing(captive)
	if(isliving(owner))
		var/mob/living/caster = owner
		caster.balloon_alert(caster, "they fought free!")

// ===== THE GUARD =====

/**
 * The orbit is a shield as well as an arsenal.
 *
 * Each object held adds [GREATER_TK_BLOCK_CHANCE_PER_ITEM]% to the chance that a melee
 * swing, an unarmed strike, a pounce or a thrown object is knocked out of the air
 * before it lands. The object that took the hit drops out of orbit, so a full orbit is
 * five blocks at the very most. The protection is spent, not passive. Bullets and
 * beams are too fast to swat, which keeps this from stepping on the specimen collar's
 * territory too.
 */
/datum/action/cooldown/spell/greater_telekinesis/proc/on_check_block(mob/living/source, atom/hit_by, damage, attack_text, attack_type, armour_penetration, damage_type)
	SIGNAL_HANDLER
	if(!length(lifted))
		return NONE
	// Never swat down our own inbound grab. A pulled person "hitting" the caster is
	// just the pull arriving.
	if(hit_by in pulling_in)
		return NONE
	if(attack_type != MELEE_ATTACK && attack_type != UNARMED_ATTACK && attack_type != LEAP_ATTACK && attack_type != THROWN_PROJECTILE_ATTACK)
		return NONE
	if(!prob(length(lifted) * GREATER_TK_BLOCK_CHANCE_PER_ITEM))
		return NONE
	var/atom/movable/guard = pick(lifted)
	release_thing(guard)
	playsound(source, 'sound/effects/gravhit.ogg', 50, TRUE)
	new /obj/effect/temp_visual/telekinesis(get_turf(source))
	source.visible_message(
		span_warning("[guard] whips out of the air around [source] and takes [attack_text], then drops to the deck!"),
		span_warning("[guard] whips out of orbit and takes [attack_text] for you, then drops to the deck."),
	)
	return SUCCESSFUL_BLOCK

// ===== THROWING =====

/**
 * One thing, thrown hard.
 *
 * The bonus damage rides a one-shot COMSIG_MOVABLE_IMPACT hook rather than a temporary
 * throwforce edit, because a throwforce we forget to put back is a permanently buffed
 * item loose in the round. `/datum/thrownthing/finalize()` guarantees a throw_impact
 * even when the object hits nothing but floor, so the hook always gets to unregister
 * itself.
 */
/datum/action/cooldown/spell/greater_telekinesis/proc/hurl(mob/living/source, atom/movable/thing, atom/at_what)
	release_thing(thing)
	if(QDELETED(thing) || !isturf(thing.loc))
		return
	RegisterSignal(thing, COMSIG_MOVABLE_IMPACT, PROC_REF(on_hurled_impact), override = TRUE)
	new /obj/effect/temp_visual/telekinesis(get_turf(thing))
	if(!thing.throw_at(at_what, GREATER_TK_THROW_RANGE, GREATER_TK_THROW_SPEED, source, spin = TRUE, force = MOVE_FORCE_EXTREMELY_STRONG))
		UnregisterSignal(thing, COMSIG_MOVABLE_IMPACT)
		return
	source.log_message("threw [thing] at [at_what] using Greater Telekinesis.", LOG_ATTACK)

/// Does this hit hard enough to put somebody on the floor? Hand items only when
/// bulky; furniture, machines and people always.
/datum/action/cooldown/spell/greater_telekinesis/proc/hits_heavy(atom/movable/thing)
	if(!isitem(thing))
		return TRUE
	var/obj/item/hand_item = thing
	return hand_item.w_class >= WEIGHT_CLASS_BULKY

/datum/action/cooldown/spell/greater_telekinesis/proc/on_hurled_impact(atom/movable/thing, atom/hit_atom, datum/thrownthing/throwingdatum, caught)
	SIGNAL_HANDLER
	UnregisterSignal(thing, COMSIG_MOVABLE_IMPACT)
	if(caught)
		return
	// A thrown person is their own crash. Whatever solid thing ends their flight
	// hurts them too; running out of throw over open floor is a free landing.
	if(isliving(thing))
		hurled_mob_crash(thing, hit_atom)
	if(!isliving(hit_atom) || hit_atom == owner)
		return
	var/mob/living/victim = hit_atom
	victim.apply_damage(GREATER_TK_IMPACT_DAMAGE, BRUTE)
	playsound(victim, 'sound/effects/gravhit.ogg', 60, TRUE)
	if(!hits_heavy(thing))
		victim.visible_message(
			span_danger("[thing] hits [victim] far harder than a thrown [thing.name] has any business hitting."),
			span_userdanger("[thing] slams into you!"),
		)
		return
	victim.Knockdown(GREATER_TK_HEAVY_KNOCKDOWN)
	victim.visible_message(
		span_boldwarning("[thing] slams into [victim] and takes [victim.p_them()] off [victim.p_their()] feet!"),
		span_userdanger("[thing] hits you like a car and puts you on the floor!"),
	)

/// The thrown person hits whatever stopped them.
/datum/action/cooldown/spell/greater_telekinesis/proc/hurled_mob_crash(mob/living/projectile_person, atom/barrier)
	if(QDELETED(projectile_person))
		return
	var/solid = isliving(barrier) || isclosedturf(barrier)
	if(!solid && isobj(barrier))
		var/obj/barrier_obj = barrier
		solid = barrier_obj.density
	if(!solid)
		return
	projectile_person.apply_damage(GREATER_TK_IMPACT_DAMAGE, BRUTE)
	projectile_person.Knockdown(GREATER_TK_HEAVY_KNOCKDOWN)
	playsound(projectile_person, 'sound/effects/gravhit.ogg', 60, TRUE)
	projectile_person.visible_message(
		span_boldwarning("[projectile_person] slams into [barrier]!"),
		span_userdanger("You slam into [barrier]!"),
	)

// =========================================================================
// SPECIMEN ZERO
// =========================================================================

/mob/living/basic/vestige_mutant
	name = "Specimen Zero"
	desc = "A thin grey figure in the shreds of a containment smock, hanging a few inches off the floor. \
		Everything loose in the room leans slightly towards it."
	gender = NEUTER

	icon = 'voidcrew/modules/antag_ruins/icons/mutant.dmi'
	icon_state = "mutant"
	icon_living = "mutant"
	icon_dead = "mutant_dead"
	// The whole tile is clickable. The silhouette is a narrow one and a boss you have to
	// aim at pixel-precisely is not a fight, it is a mouse test.
	mouse_opacity = MOUSE_OPACITY_OPAQUE

	// Hand-copied from the hoarfrost/lich tier and cut for a one-player fight. See the
	// file header on why none of this is inherited.
	maxHealth = MUTANT_MAX_HEALTH
	health = MUTANT_MAX_HEALTH
	// Its hands are an afterthought. The fight is the things it throws.
	melee_damage_lower = 16
	melee_damage_upper = 22
	melee_attack_cooldown = 1.2 SECONDS
	armour_penetration = 15
	obj_damage = 0
	// Slow enough that the player can always break contact and reset. Every ability
	// below is meant to have a clean dodge, and none of that works if it can run you down.
	speed = 3
	combat_mode = TRUE
	status_flags = NONE
	mob_size = MOB_SIZE_LARGE
	mob_biotypes = MOB_ORGANIC|MOB_HUMANOID
	faction = list(FACTION_HOSTILE)
	// Lab-raised and half-rebuilt: poison and suffocation stopped meaning anything to it
	// several revisions ago.
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0.5, STAMINA = 0, OXY = 0)
	// The arena's geometry is the fight. It does not get to open new doors in it.
	environment_smash = ENVIRONMENT_SMASH_NONE
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	move_force = MOVE_FORCE_VERY_STRONG
	move_resist = MOVE_FORCE_VERY_STRONG
	pull_force = MOVE_FORCE_VERY_STRONG

	speak_emote = list("rasps")
	attack_verb_continuous = "batters"
	attack_verb_simple = "batter"
	attack_sound = 'sound/effects/gravhit.ogg'
	attack_vis_effect = ATTACK_EFFECT_SMASH
	death_message = "comes down out of the air and does not get up."
	death_sound = 'sound/effects/magic/demon_dies.ogg'

	lighting_cutoff_red = 25
	lighting_cutoff_green = 15
	lighting_cutoff_blue = 35

	ai_controller = /datum/ai_controller/basic_controller/vestige_mutant

	/// Sweep the Room: the signature. Throws the arena at you.
	var/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/sweep
	/// Pin: the marked tile.
	var/datum/action/cooldown/mob_cooldown/vestige_tk/pin/pin
	/// Repulse: the answer to standing in its face.
	var/datum/action/cooldown/mob_cooldown/vestige_tk/repulse/repulse
	/// Confiscation: granted at the revision, not before.
	var/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate/confiscate
	/// Resurrection does not refill the specimen's physical loot.
	var/loot_dropped = FALSE

	/// TRUE once the fourth revision has arrived. One-way.
	var/revised = FALSE

	/// Where it was standing when it initialised. The leash hangs off here.
	var/turf/home_turf
	/// The invisible movable the leash component is anchored to.
	var/obj/effect/vestige_mutant_anchor/home_anchor

	/// Restarted every tick it can see and reach its quarry. See [handle_disengagement].
	COOLDOWN_DECLARE(disengage_timer)

/mob/living/basic/vestige_mutant/Initialize(mapload)
	. = ..()
	add_traits(list(
		TRAIT_NOBREATH,
		TRAIT_RESISTLOWPRESSURE,
		TRAIT_RESISTHIGHPRESSURE,
	), INNATE_TRAIT)

	AddElement(/datum/element/relay_attackers)
	AddElement(/datum/element/ai_retaliate)

	// A bluespace body bag takes MOB_SIZE_LARGE, so without this the specimen can be
	// zipped up and carried out of its own cell (#131).
	ban_from_containment()

	sweep = new(src)
	pin = new(src)
	repulse = new(src)
	sweep.Grant(src)
	pin.Grant(src)
	repulse.Grant(src)

	// The controller is built during /atom/Initialize, i.e. before any of the above
	// existed, so the kit has to be handed over now rather than seeded in `blackboard`.
	var/datum/ai_controller/basic_controller/vestige_mutant/brain = ai_controller
	if(istype(brain))
		brain.register_kit(sweep, pin, repulse)

	COOLDOWN_START(src, disengage_timer, MUTANT_DISENGAGE_GRACE)
	leash_to_home()

/mob/living/basic/vestige_mutant/Destroy()
	sweep = null
	pin = null
	repulse = null
	confiscate = null
	home_turf = null
	QDEL_NULL(home_anchor)
	return ..()

/**
 * Pins it to the room it lives in.
 *
 * The arena has an approach corridor in front of the boss room, and a boss that wanders
 * up it turns a designed fight into a doorway brawl. `/datum/component/leash` rejects a
 * turf owner (`code/datums/components/leash.dm:35-37`), so an invisible movable is
 * dropped on the spawn tile to hang the leash off. Its recall is a plain forceMove,
 * which is what makes it work at all inside a NOTELEPORT arena.
 */
/mob/living/basic/vestige_mutant/proc/leash_to_home()
	home_turf = get_turf(src)
	if(isnull(home_turf))
		return
	home_anchor = new /obj/effect/vestige_mutant_anchor(home_turf)
	// AddComponent is a variadic macro, so this has to stay on one line.
	AddComponent(/datum/component/leash, home_anchor, MUTANT_LEASH_RANGE, /obj/effect/temp_visual/small_smoke/halfsecond, /obj/effect/temp_visual/small_smoke/halfsecond)

// ===== THE FOURTH REVISION =====

/mob/living/basic/vestige_mutant/adjust_health(amount, updating_health = TRUE, forced = FALSE)
	. = ..()
	if(revised || stat == DEAD)
		return
	// Read bruteloss rather than health: health is only recomputed when updating_health
	// is set, and this can be called without it.
	if(bruteloss < maxHealth * (1 - MUTANT_REVISION_THRESHOLD))
		return
	begin_revision()

/**
 * Half health. It stops holding itself in the shape of a person, every cooldown drops
 * by a third, the sweeps get bigger, the pin marks two tiles instead of one, and it
 * starts taking things out of your hands.
 */
/mob/living/basic/vestige_mutant/proc/begin_revision()
	if(revised)
		return
	revised = TRUE

	visible_message(span_boldwarning("[src] stops holding itself upright like a person. Every loose thing in \
		the room lifts off the floor at once, and most of it stays there."))
	playsound(src, 'sound/effects/magic/mutate.ogg', 100, TRUE)
	new /obj/effect/temp_visual/circle_wave/vestige_mutant(get_turf(src))
	for(var/mob/living/witness in view(7, src))
		shake_camera(witness, 4, 2)

	add_filter(MUTANT_REVISION_FILTER, 2, list("type" = "outline", "color" = VESTIGE_TK_COLOR, "size" = 1))

	for(var/datum/action/cooldown/ability as anything in list(sweep, pin, repulse))
		if(isnull(ability))
			continue
		ability.cooldown_time = round(ability.cooldown_time * MUTANT_REVISION_SCALE, 0.1)

	confiscate = new(src)
	confiscate.Grant(src)
	ai_controller?.set_blackboard_key(BB_MUTANT_CONFISCATE, confiscate)

// ===== ANTI-CHEESE =====

/mob/living/basic/vestige_mutant/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(stat == DEAD)
		return
	handle_disengagement(seconds_per_tick)

/**
 * Kite-and-plink and doorway-cheese killer, in the same spirit as the hoarfrost
 * matriarch's. If it cannot see or reach its quarry for [MUTANT_DISENGAGE_GRACE] it
 * starts closing up at [MUTANT_DISENGAGE_REGEN] of its max HP per second until somebody
 * comes back. No arena lock and no teleport, just a hard floor under "fight it properly".
 *
 * This is the whole reason the arena can afford an approach corridor: retreating up it
 * to shoot through a doorway costs more health than it buys.
 */
/mob/living/basic/vestige_mutant/proc/handle_disengagement(seconds_per_tick)
	var/atom/quarry
	if(ai_controller)
		quarry = ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(is_engaged(quarry))
		COOLDOWN_START(src, disengage_timer, MUTANT_DISENGAGE_GRACE)
		return
	if(!COOLDOWN_FINISHED(src, disengage_timer) || bruteloss <= 0)
		return
	adjust_health(-(maxHealth * MUTANT_DISENGAGE_REGEN * seconds_per_tick))
	if(SPT_PROB(20, seconds_per_tick))
		visible_message(span_boldwarning("[src]'s wounds pull themselves shut without being touched."))

/// Is this quarry close enough, alive enough and visible enough to count?
/mob/living/basic/vestige_mutant/proc/is_engaged(atom/quarry)
	if(QDELETED(quarry))
		return FALSE
	if(isliving(quarry))
		var/mob/living/living_quarry = quarry
		if(living_quarry.stat == DEAD)
			return FALSE
	if(get_dist(src, quarry) > MUTANT_DISENGAGE_RANGE)
		return FALSE
	return can_see(src, quarry, MUTANT_DISENGAGE_RANGE)

// ===== DEATH =====

/mob/living/basic/vestige_mutant/death(gibbed)
	remove_filter(MUTANT_REVISION_FILTER)
	. = ..()
	if(!. || gibbed)
		return
	drop_the_specimen()

/**
 * The drops. Same rule as the hoarfrost matriarch: the best boss loot is the boss.
 *
 * The collar is guaranteed, so the kill is always worth something, and it is the one
 * piece of the fight the specimen was wearing rather than doing. The jackpot rolls from
 * a two-entry pool and both entries are literally its own abilities, the palm anchor
 * subtypes Pin and the harness subtypes Sweep the Room, so retuning either ability here
 * retunes the loot with it.
 */
/mob/living/basic/vestige_mutant/proc/drop_the_specimen()
	if(loot_dropped)
		return
	var/atom/spot = drop_location()
	if(isnull(spot))
		return
	loot_dropped = TRUE
	new /obj/item/clothing/neck/vestige_specimen_collar(spot)
	var/static/list/jackpot_pool = list(
		/obj/item/vestige_palm_anchor,
		/obj/item/vestige_debris_harness,
	)
	var/jackpot_type = pick(jackpot_pool)
	new jackpot_type(spot)
	visible_message(span_boldnotice("Everything still in the air drops at once. There is hardware on the floor \
		where [src] was."))

// ===== SUPPORT ATOMS =====

/// Invisible movable for the leash component to hang off. Deleted with the specimen.
/obj/effect/vestige_mutant_anchor
	name = "cell anchor"
	desc = "You should not be able to see this."
	icon = null
	icon_state = null
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	density = FALSE
	move_resist = INFINITY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/// A violet ripple. The revision, and the ground telegraph under a repulse.
/obj/effect/temp_visual/circle_wave/vestige_mutant
	color = VESTIGE_TK_COLOR

/// The tile a pin is closing on.
/obj/effect/temp_visual/vestige_pin_mark
	icon = 'icons/mob/telegraphing/telegraph.dmi'
	icon_state = "blank_semi_transparent"
	color = VESTIGE_TK_COLOR
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	randomdir = FALSE
	duration = MUTANT_PIN_TELEGRAPH

/obj/effect/temp_visual/vestige_pin_mark/Initialize(mapload, new_duration)
	if(new_duration)
		duration = new_duration
	return ..()

/**
 * A chunk of the cell.
 *
 * Only ever conjured when a sweep cannot find enough loose objects to throw, so the
 * ability never fizzles in a room that has already been cleared out. It crumbles on a
 * timer because the debris harness is loot and gets carried out of the arena, and a
 * player with an infinite junk printer is a different item than the one intended.
 */
/obj/item/vestige_debris
	name = "torn cell plating"
	desc = "A slab of grey wall panel with the bolt holes still in it. It came off the wall sideways."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "sheet-abductor"
	w_class = WEIGHT_CLASS_NORMAL
	force = 8
	throwforce = 14
	throw_speed = 3
	attack_verb_continuous = list("bludgeons", "slams", "smacks")
	attack_verb_simple = list("bludgeon", "slam", "smack")

/obj/item/vestige_debris/Initialize(mapload)
	. = ..()
	QDEL_IN(src, MUTANT_DEBRIS_LIFETIME)

// =========================================================================
// THE KIT
// =========================================================================

/**
 * Shared base for everything the specimen does and everything it drops.
 *
 * [worth_using_on] is the hook the rotation asks before it spends a planning slot: an
 * ability that would obviously do nothing to this quarry declines the turn instead of
 * burning its cooldown. Defaults to yes.
 */
/datum/action/cooldown/mob_cooldown/vestige_tk
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "void_magnet"
	shared_cooldown = NONE

/// Is this ability worth spending on this quarry right now?
/datum/action/cooldown/mob_cooldown/vestige_tk/proc/worth_using_on(atom/quarry)
	return !QDELETED(quarry)

/// Whoever is casting is never a target of their own force.
/datum/action/cooldown/mob_cooldown/vestige_tk/proc/spared(mob/living/victim)
	return QDELETED(victim) || victim == owner || victim.stat == DEAD

// ===== SWEEP THE ROOM =====

/**
 * ## Sweep the Room
 *
 * Every loose object within [sweep_radius] rattles on the deck for [telegraph_time],
 * then flies at the quarry one at a time, each shot aimed at wherever the quarry is
 * standing at the moment it launches. Standing still eats the whole volley. Moving
 * turns most of it into scenery.
 *
 * Two things are counterplay rather than bugs: an object that somebody picks up during
 * the telegraph leaves the volley, and an object that gets thrown into a wall stays
 * where it lands and is ammunition again next time. The arena is furnished for exactly
 * this reason.
 *
 * The debris harness (below) is a subtype with smaller numbers and no conjuring, so
 * this proc chain is the only sweep implementation in the file.
 */
/datum/action/cooldown/mob_cooldown/vestige_tk/sweep
	name = "Sweep the Room"
	desc = "Lift everything loose nearby and throw it, one piece at a time, at whatever you clicked."
	cooldown_time = MUTANT_SWEEP_COOLDOWN
	melee_cooldown_time = 0
	click_to_activate = TRUE
	/// How far out the floor gets stripped for ammunition.
	var/sweep_radius = MUTANT_SWEEP_RADIUS
	/// Most objects a single volley throws.
	var/volley_size = MUTANT_SWEEP_VOLLEY
	/// A volley that finds less than this tears the difference out of the walls. Zero
	/// disables conjuring entirely, which is what the harness does.
	var/conjure_floor = MUTANT_SWEEP_FLOOR
	/// How long everything rattles before the first shot.
	var/telegraph_time = MUTANT_SWEEP_TELEGRAPH
	/// Gap between shots.
	var/stagger_time = MUTANT_SWEEP_STAGGER
	/// How far a thrown object travels. Long enough to cross the specimen floor.
	var/throw_range = 14
	/// How fast it travels.
	var/throw_speed = 3
	/// What this volley is being thrown at. Held live rather than resolved up front, so
	/// each shot leads the quarry's current tile instead of the tile they left.
	var/atom/tracked_quarry
	/// Item => the exact filter parameters installed by this booking, before another field can replace them.
	var/list/booked_ammunition = list()

/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/Destroy()
	for(var/obj/item/loose as anything in booked_ammunition.Copy())
		release_booking(loose)
	booked_ammunition = null
	tracked_quarry = null
	return ..()

/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/Activate(atom/target)
	if(!isliving(owner) || QDELETED(target))
		return FALSE
	var/turf/centre = get_turf(owner)
	if(isnull(centre))
		return FALSE

	var/wanted = volley_size
	var/mob/living/basic/vestige_mutant/specimen = owner
	if(istype(specimen) && specimen.revised)
		wanted = MUTANT_SWEEP_VOLLEY_REVISED

	var/list/obj/item/ammunition = gather_ammunition(centre, wanted)
	if(!length(ammunition))
		return FALSE

	StartCooldown()
	tracked_quarry = target
	announce_windup()
	playsound(owner, 'sound/effects/magic/charge.ogg', 70, TRUE)
	for(var/i in 1 to length(ammunition))
		var/obj/item/loose = ammunition[i]
		lift_one(loose)
		addtimer(CALLBACK(src, PROC_REF(fling_one), loose), telegraph_time + (i * stagger_time))
	return TRUE

/// Flavour for the windup. The harness is a person wearing a piece of the specimen,
/// not the specimen.
/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/proc/announce_windup()
	owner.visible_message(span_boldwarning("[owner] spreads both hands, and every loose thing on the deck starts \
		shaking itself off the floor."))

/**
 * Rolls the volley: loose objects first, conjured plating only to make up a shortfall.
 *
 * Anchored, abstract and already-airborne objects are skipped, and so is anything in a
 * hand or a bag, this strips floors, not people. Shuffled so a cluttered corner does
 * not get thrown in the same order twice.
 */
/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/proc/gather_ammunition(turf/centre, wanted)
	var/list/obj/item/found = list()
	for(var/turf/nearby as anything in RANGE_TURFS(sweep_radius, centre))
		for(var/obj/item/loose in nearby)
			if(loose.anchored || loose.throwing || (loose.item_flags & ABSTRACT))
				continue
			if(HAS_TRAIT(loose, TRAIT_NODROP))
				continue
			// Already wearing the telekinesis outline: booked into a volley still in
			// flight, or held in somebody's Greater Telekinesis orbit. Either way it
			// is spoken for, double-booking it would fire it twice and strip the
			// other holder's outline out from under them.
			if(loose.get_filter(VESTIGE_TK_FILTER))
				continue
			found += loose
	found = shuffle(found)
	if(length(found) > wanted)
		found.Cut(wanted + 1)
	if(!conjure_floor || length(found) >= conjure_floor)
		return found
	// The cell was stripped bare a long time ago. It takes the walls apart instead.
	for(var/i in 1 to (conjure_floor - length(found)))
		var/turf/spot = pick_conjure_turf(centre)
		if(isnull(spot))
			break
		found += new /obj/item/vestige_debris(spot)
	return found

/// An open tile near the caster to tear a slab of plating onto, or null.
/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/proc/pick_conjure_turf(turf/centre)
	var/list/turf/candidates = list()
	for(var/turf/open/candidate in RANGE_TURFS(2, centre))
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		candidates += candidate
	if(!length(candidates))
		return null
	return pick(candidates)

/// Marks an object as part of the volley and shakes it loose.
/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/proc/lift_one(obj/item/loose)
	if(QDELETED(loose))
		return
	loose.add_filter(VESTIGE_TK_FILTER, 2, list("type" = "outline", "color" = VESTIGE_TK_COLOR, "size" = 1))
	// Render filters are rebuilt whenever any filter changes; their parameter list keeps our identity.
	booked_ammunition[loose] = loose.filter_data[VESTIGE_TK_FILTER]
	loose.Shake(pixelshiftx = 1, pixelshifty = 1, duration = telegraph_time)
	new /obj/effect/temp_visual/telekinesis(get_turf(loose))

/// Release only our own booking. A newer field that took the item also owns its outline and momentum.
/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/proc/release_booking(obj/item/loose)
	var/list/booked_filter = booked_ammunition[loose]
	booked_ammunition -= loose
	if(!booked_filter || QDELETED(loose) || loose.filter_data?[VESTIGE_TK_FILTER] != booked_filter)
		return FALSE
	loose.remove_filter(VESTIGE_TK_FILTER)
	return TRUE

/// One shot. Anything that stopped being throwable in the meantime is simply skipped.
/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/proc/fling_one(obj/item/loose)
	if(!release_booking(loose))
		return
	// Somebody picked it up mid-telegraph. Good for them; that shot is gone.
	if(!isturf(loose.loc))
		return
	var/atom/at_what = tracked_quarry
	if(QDELETED(at_what) || QDELETED(owner) || owner.stat == DEAD)
		return
	loose.throw_at(at_what, throw_range, throw_speed, owner, spin = TRUE, force = MOVE_FORCE_STRONG)

// ===== PIN =====

/**
 * ## Pin
 *
 * Marks a floor tile. When the mark closes, anything living still standing on it is
 * lifted off the deck and put back down hard: [pin_damage] brute, knocked flat, and
 * thrown clear so the follow-up has somewhere to land.
 *
 * The mark is painted for the whole windup and it never moves, so the dodge is simply
 * "step off the tile". After the revision it paints a second tile as well, which is what
 * stops the dodge from being automatic. You have to look before you move.
 *
 * The palm anchor (below) is a subtype, so this is the only pin implementation here.
 */
/datum/action/cooldown/mob_cooldown/vestige_tk/pin
	name = "Pin"
	desc = "Mark a tile. Anything still standing on it a moment later gets picked up and slammed back down."
	cooldown_time = MUTANT_PIN_COOLDOWN
	melee_cooldown_time = 0
	click_to_activate = TRUE
	/// How long the mark sits before it closes.
	var/telegraph_time = MUTANT_PIN_TELEGRAPH
	/// Brute dealt to whoever is still standing there.
	var/pin_damage = MUTANT_PIN_DAMAGE
	/// How long they stay down.
	var/pin_knockdown = MUTANT_PIN_KNOCKDOWN
	/// Tiles they are thrown, away from the mark.
	var/pin_throw = MUTANT_PIN_THROW
	/// How far away a tile may be marked.
	var/pin_range = 12

/datum/action/cooldown/mob_cooldown/vestige_tk/pin/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	var/turf/marked = get_turf(target)
	if(isnull(marked) || get_dist(owner, marked) > pin_range)
		return FALSE

	StartCooldown()
	announce_windup()
	playsound(owner, 'sound/effects/magic/ethereal_enter.ogg', 60, TRUE)

	var/list/turf/marks = list(marked)
	var/mob/living/basic/vestige_mutant/specimen = owner
	if(istype(specimen) && specimen.revised)
		var/turf/second = pick_second_mark(marked)
		if(second)
			marks += second

	for(var/turf/spot as anything in marks)
		new /obj/effect/temp_visual/vestige_pin_mark(spot, telegraph_time)
		owner.Beam(spot, icon_state = "purple_lightning", time = telegraph_time)
		addtimer(CALLBACK(src, PROC_REF(close_the_mark), spot), telegraph_time)
	return TRUE

/datum/action/cooldown/mob_cooldown/vestige_tk/pin/proc/announce_windup()
	owner.visible_message(span_boldwarning("[owner] fixes on a patch of floor, and the air over it starts to buzz."))

/// A second tile beside the first, for the revised specimen. Open floor only, so the
/// pair always reads as two places you could actually be standing.
/datum/action/cooldown/mob_cooldown/vestige_tk/pin/proc/pick_second_mark(turf/first)
	var/list/turf/candidates = list()
	for(var/turf/open/candidate in orange(1, first))
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		candidates += candidate
	if(!length(candidates))
		return null
	return pick(candidates)

/// The mark closes on whoever is still standing in it.
/datum/action/cooldown/mob_cooldown/vestige_tk/pin/proc/close_the_mark(turf/spot)
	if(QDELETED(spot) || QDELETED(owner) || owner.stat == DEAD)
		return
	playsound(spot, 'sound/effects/gravhit.ogg', 80, TRUE)
	new /obj/effect/temp_visual/telekinesis(spot)
	for(var/mob/living/victim in spot)
		if(spared(victim))
			continue
		victim.visible_message(
			span_boldwarning("Something invisible picks [victim] up off the deck and puts [victim.p_them()] back down hard!"),
			span_userdanger("You are lifted off the floor and slammed straight back into it!"),
		)
		victim.apply_damage(pin_damage, BRUTE)
		victim.Knockdown(pin_knockdown)
		var/throw_dir = get_dir(spot, get_turf(owner))
		// Away from the caster, or anywhere at all if they are standing on the mark.
		throw_dir = throw_dir ? REVERSE_DIR(throw_dir) : pick(GLOB.cardinals)
		victim.safe_throw_at(get_edge_target_turf(victim, throw_dir), pin_throw, 1, owner)

// ===== REPULSE =====

/**
 * ## Repulse
 *
 * A shove outward from the specimen: everything living within [repulse_radius] takes
 * [repulse_damage], goes down, and gets thrown clear, and every loose object in the
 * radius is scattered with them.
 *
 * It is only offered by the rotation when something is actually standing close, so it
 * reads as a reaction to being crowded rather than as a random tax. The scattered
 * objects are not decoration: they redistribute the sweep's ammunition around the room,
 * which is why the fight does not converge on one swept-clean corner.
 */
/datum/action/cooldown/mob_cooldown/vestige_tk/repulse
	name = "Repulse"
	desc = "Shove everything nearby away from you, hard."
	cooldown_time = MUTANT_REPULSE_COOLDOWN
	melee_cooldown_time = 0
	click_to_activate = FALSE
	/// How long it winds up.
	var/telegraph_time = MUTANT_REPULSE_TELEGRAPH
	/// Tiles the shove reaches.
	var/repulse_radius = MUTANT_REPULSE_RADIUS
	/// Brute the shove deals.
	var/repulse_damage = MUTANT_REPULSE_DAMAGE
	/// Tiles the shove throws you.
	var/repulse_distance = MUTANT_REPULSE_DISTANCE
	/// How long it keeps you down.
	var/repulse_knockdown = MUTANT_REPULSE_KNOCKDOWN

/// Never spent on empty air. This is the answer to being crowded, and nothing else.
/datum/action/cooldown/mob_cooldown/vestige_tk/repulse/worth_using_on(atom/quarry)
	if(!..())
		return FALSE
	return get_dist(owner, quarry) <= current_radius()

/// The revised specimen shoves further. Anything else casting this keeps the base value.
/datum/action/cooldown/mob_cooldown/vestige_tk/repulse/proc/current_radius()
	var/mob/living/basic/vestige_mutant/specimen = owner
	if(istype(specimen) && specimen.revised)
		return MUTANT_REPULSE_RADIUS_REVISED
	return repulse_radius

/datum/action/cooldown/mob_cooldown/vestige_tk/repulse/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	StartCooldown()
	owner.visible_message(span_boldwarning("[owner] draws its arms in, and the air around it goes tight."))
	playsound(owner, 'sound/effects/magic/charge.ogg', 70, TRUE)
	owner.Shake(pixelshiftx = 1, pixelshifty = 1, duration = telegraph_time)
	var/turf/centre = get_turf(owner)
	if(centre)
		new /obj/effect/temp_visual/circle_wave/vestige_mutant(centre)
	addtimer(CALLBACK(src, PROC_REF(shove)), telegraph_time)
	return TRUE

/datum/action/cooldown/mob_cooldown/vestige_tk/repulse/proc/shove()
	if(QDELETED(owner) || owner.stat == DEAD)
		return
	var/turf/centre = get_turf(owner)
	if(isnull(centre))
		return
	var/radius = current_radius()
	owner.visible_message(span_boldwarning("[owner] snaps its arms open and the room goes with them!"))
	playsound(centre, 'sound/effects/magic/repulse.ogg', 90, TRUE)
	new /obj/effect/temp_visual/circle_wave/vestige_mutant(centre)

	for(var/mob/living/victim in range(radius, centre))
		if(spared(victim))
			continue
		victim.apply_damage(repulse_damage, BRUTE)
		victim.Knockdown(repulse_knockdown)
		throw_clear(victim, centre, repulse_distance)
		to_chat(victim, span_userdanger("The air itself hits you and you go with it!"))
	// The junk goes too. This is how the room's ammunition gets redistributed.
	for(var/turf/nearby as anything in RANGE_TURFS(radius, centre))
		for(var/obj/item/loose in nearby)
			if(loose.anchored || loose.throwing)
				continue
			throw_clear(loose, centre, round(repulse_distance / 2))

/// Throw something straight away from the epicentre.
/datum/action/cooldown/mob_cooldown/vestige_tk/repulse/proc/throw_clear(atom/movable/thing, turf/centre, distance)
	if(distance <= 0)
		return
	var/throw_dir = get_dir(centre, thing)
	if(!throw_dir) // standing on the epicentre; anywhere will do
		throw_dir = pick(GLOB.cardinals)
	thing.safe_throw_at(get_edge_target_turf(thing, throw_dir), distance, 2, owner)

// ===== CONFISCATION =====

/**
 * ## Confiscation
 *
 * Fourth revision only. It takes whatever is in the quarry's active hand, holds it up
 * where they can see it for [hold_time], and throws it back at them.
 *
 * The counterplay is real and cheap: the weapon lands on the floor somewhere near you
 * and you can pick it back up. What it actually costs is the seconds you spend doing
 * that, which is exactly the window the specimen wants for its next sweep.
 *
 * Never touches worn gear and never touches anything NODROP, so it cannot strip anyone
 * down or brick an implant. The rotation declines to queue it against empty hands.
 */
/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate
	name = "Confiscation"
	desc = "Take what is in their hand, then give it back at speed."
	cooldown_time = MUTANT_CONFISCATE_COOLDOWN
	melee_cooldown_time = 0
	click_to_activate = TRUE
	/// How long it holds the property before returning it.
	var/hold_time = MUTANT_CONFISCATE_HOLD
	/// How far away it can reach into a hand.
	var/reach = 12

/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate/worth_using_on(atom/quarry)
	if(!..() || !isliving(quarry))
		return FALSE
	var/mob/living/victim = quarry
	if(get_dist(owner, victim) > reach)
		return FALSE
	return !isnull(takeable_item(victim))

/// The item this ability would take off a victim right now, or null.
/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate/proc/takeable_item(mob/living/victim)
	var/obj/item/held = victim.get_active_held_item()
	if(QDELETED(held) || (held.item_flags & ABSTRACT) || HAS_TRAIT(held, TRAIT_NODROP))
		return null
	return held

/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate/Activate(atom/target)
	if(!isliving(owner) || !isliving(target))
		return FALSE
	var/mob/living/victim = target
	var/obj/item/prize = takeable_item(victim)
	if(isnull(prize))
		return FALSE
	// Somewhere to put it, resolved before the victim's hand is opened, a failure after
	// the drop would leave their weapon on the floor for nothing.
	var/turf/perch = get_turf(owner)
	if(isnull(perch))
		return FALSE
	if(!victim.dropItemToGround(prize))
		return FALSE

	StartCooldown()
	prize.forceMove(perch)
	prize.add_filter(VESTIGE_TK_FILTER, 2, list("type" = "outline", "color" = VESTIGE_TK_COLOR, "size" = 1))
	playsound(owner, 'sound/effects/magic/summon_magic.ogg', 60, TRUE)
	victim.visible_message(
		span_boldwarning("[prize] leaves [victim]'s hand and crosses the room to [owner], which turns it over once."),
		span_userdanger("[prize] is pulled out of your grip and across the room!"),
	)
	addtimer(CALLBACK(src, PROC_REF(hand_it_back), prize, victim), hold_time)
	return TRUE

/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate/proc/hand_it_back(obj/item/prize, mob/living/victim)
	if(QDELETED(prize))
		return
	prize.remove_filter(VESTIGE_TK_FILTER)
	if(!isturf(prize.loc) || QDELETED(victim) || QDELETED(owner) || owner.stat == DEAD)
		return
	owner.visible_message(span_boldwarning("[owner] gives it back."))
	playsound(owner, 'sound/effects/magic/repulse.ogg', 60, TRUE)
	prize.throw_at(victim, 10, 4, owner, spin = TRUE, force = MOVE_FORCE_STRONG)

// =========================================================================
// AI
// =========================================================================

/**
 * The megafauna attack rotation in the modern basic-mob framework, lifted wholesale
 * from the hoarfrost matriarch (hoarfrost_ai.dm): pick one ability at random, never the
 * one used last, drop anything unavailable or pointless against this quarry, queue it,
 * done. Everything else about the specimen is deliberately ordinary, it drifts up to
 * you and hits you, which is what makes the telegraphed abilities read as events.
 */
/datum/ai_controller/basic_controller/vestige_mutant
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_AGGRO_RANGE = 14,
		BB_MUTANT_LAST_ABILITY = null,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = null
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/vestige_mutant_rotation,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

/**
 * Publishes the kit onto the blackboard.
 *
 * Called from the specimen's Initialize, because the controller is built inside
 * /atom/Initialize (before a single action exists) so the keys cannot be seeded in
 * the `blackboard` list above. Confiscation is not here: it is granted at the revision
 * and writes its own key then.
 */
/// Restore the specimen's existing revision and cooldowns after a temporary controller takes over.
/datum/ai_controller/basic_controller/vestige_mutant/PossessPawn(atom/new_pawn)
	. = ..()
	var/mob/living/basic/vestige_mutant/specimen = pawn
	if(!istype(specimen))
		return
	register_kit(specimen.sweep, specimen.pin, specimen.repulse)
	set_blackboard_key(BB_MUTANT_CONFISCATE, specimen.confiscate)

/datum/ai_controller/basic_controller/vestige_mutant/proc/register_kit(
	datum/action/cooldown/sweep,
	datum/action/cooldown/pin,
	datum/action/cooldown/repulse,
)
	set_blackboard_key(BB_MUTANT_SWEEP, sweep)
	set_blackboard_key(BB_MUTANT_PIN, pin)
	set_blackboard_key(BB_MUTANT_REPULSE, repulse)

/datum/ai_planning_subtree/vestige_mutant_rotation
	/// It will not spend a cooldown on somebody this far away. The sweep would fall
	/// short and the self-centred abilities would simply be walked out of.
	var/engagement_range = 13

/datum/ai_planning_subtree/vestige_mutant_rotation/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/vestige_mutant/specimen = controller.pawn
	if(!istype(specimen) || specimen.stat != CONSCIOUS)
		return

	var/atom/quarry = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(quarry))
		return
	if(isliving(quarry))
		var/mob/living/living_quarry = quarry
		if(living_quarry.stat == DEAD)
			return
	if(get_dist(specimen, quarry) > engagement_range)
		return

	// Built fresh rather than filtered in place: removing from the list you are
	// iterating skips entries in DM, and the pool is four long anyway.
	var/static/list/kit = list(BB_MUTANT_SWEEP, BB_MUTANT_PIN, BB_MUTANT_REPULSE, BB_MUTANT_CONFISCATE)
	var/last_used = controller.blackboard[BB_MUTANT_LAST_ABILITY]
	var/list/options = list()
	for(var/ability_key as anything in kit)
		if(ability_key == last_used)
			continue
		var/datum/action/cooldown/mob_cooldown/vestige_tk/ability = controller.blackboard[ability_key]
		if(QDELETED(ability) || !ability.IsAvailable())
			continue
		if(!ability.worth_using_on(quarry))
			continue
		options += ability_key
	if(!length(options))
		return

	var/chosen_key = pick(options)
	controller.set_blackboard_key(BB_MUTANT_LAST_ABILITY, chosen_key)
	controller.queue_behavior(/datum/ai_behavior/targeted_mob_ability, chosen_key, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

// =========================================================================
// THE DROPS
// =========================================================================

/**
 * ## Specimen collar: guaranteed
 *
 * The one part of the fight the specimen was wearing rather than doing. Worn, it stops
 * one thrown object per second dead in the air in front of you; the object drops on
 * your tile instead of hitting you.
 *
 * `COMSIG_ATOM_PREHITBY` is only ever sent from `/atom/movable/pre_impact`, so this can
 * never touch a projectile, a punch or a swing. It is a thrown-object ward and nothing
 * else. The one-per-second gate is what stops it from being a free hard counter to a
 * whole debris volley.
 */
/obj/item/clothing/neck/vestige_specimen_collar
	name = "specimen collar"
	desc = "An abductor restraint collar, snapped open at the hinge from the inside. The field it projects still \
		works fine. Nobody ever got round to changing which way it points."
	icon_state = "petcollar"
	color = "#a9bdb4"
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = FIRE_PROOF | ACID_PROOF
	COOLDOWN_DECLARE(catch_ready)

/obj/item/clothing/neck/vestige_specimen_collar/examine(mob/user)
	. = ..()
	. += span_notice("Worn, it stops one thrown object per second dead in the air in front of you.")
	if(!COOLDOWN_FINISHED(src, catch_ready))
		. += span_warning("The field is still resettling.")

/obj/item/clothing/neck/vestige_specimen_collar/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(slot & ITEM_SLOT_NECK)
		RegisterSignal(user, COMSIG_ATOM_PREHITBY, PROC_REF(on_incoming), override = TRUE)
		return
	UnregisterSignal(user, COMSIG_ATOM_PREHITBY)

/obj/item/clothing/neck/vestige_specimen_collar/dropped(mob/user, silent = FALSE)
	. = ..()
	UnregisterSignal(user, COMSIG_ATOM_PREHITBY)

/obj/item/clothing/neck/vestige_specimen_collar/proc/on_incoming(mob/living/wearer, atom/movable/incoming, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(!COOLDOWN_FINISHED(src, catch_ready))
		return
	COOLDOWN_START(src, catch_ready, COLLAR_CATCH_COOLDOWN)
	new /obj/effect/temp_visual/telekinesis(get_turf(wearer))
	playsound(wearer, 'sound/effects/magic/blink.ogg', 40, TRUE)
	wearer.visible_message(span_warning("[incoming] stops dead a foot from [wearer] and drops."))
	return COMSIG_HIT_PREVENTED

/**
 * ## Palm anchor: jackpot
 *
 * Pin, scaled to something a person can hold: same mark, same slam, longer recharge and
 * a shorter reach. It spares you and nobody else, exactly like the specimen's own.
 */
/obj/item/vestige_palm_anchor
	name = "palm anchor"
	desc = "A flat grey instrument the size of a coaster, with one recessed stud. It was built to hold a subject \
		still on an operating table, and it does not care that the table is gone."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "gizmo_scan"
	w_class = WEIGHT_CLASS_SMALL
	force = 4
	throwforce = 5
	resistance_flags = FIRE_PROOF | ACID_PROOF
	actions_types = list(/datum/action/cooldown/mob_cooldown/vestige_tk/pin/anchor)
	action_slots = ITEM_SLOT_HANDS

/obj/item/vestige_palm_anchor/examine(mob/user)
	. = ..()
	. += span_notice("Hold it, use the ability, then click the tile you want. It does not spare bystanders.")

/datum/action/cooldown/mob_cooldown/vestige_tk/pin/anchor
	name = "Pin"
	desc = "Mark a tile up to seven away. A second and a half later, anything still standing on it takes 28 brute, \
		is knocked down for two seconds, and is thrown three tiles clear."
	button_icon = 'icons/obj/antags/abductor.dmi'
	button_icon_state = "gizmo_scan"
	cooldown_time = PALM_ANCHOR_COOLDOWN
	pin_range = PALM_ANCHOR_RANGE

/datum/action/cooldown/mob_cooldown/vestige_tk/pin/anchor/announce_windup()
	owner.visible_message(span_danger("[owner] points a small grey instrument at the floor, and the air over it \
		starts to buzz."))

/**
 * ## Debris harness: jackpot
 *
 * Sweep the Room in a form a person can wear. It lifts less, throws it slower and
 * recharges more slowly, and it conjures nothing at all: a bare room gives you a bare
 * room. Fight somewhere cluttered.
 */
/obj/item/vestige_debris_harness
	name = "debris harness"
	desc = "A frame of grey alien tubing worn across the shoulders. It picks up everything nearby that is not \
		bolted down and waits for you to point at something."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "belt"
	w_class = WEIGHT_CLASS_NORMAL
	resistance_flags = FIRE_PROOF | ACID_PROOF
	actions_types = list(/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/harness)
	action_slots = ITEM_SLOT_HANDS

/obj/item/vestige_debris_harness/examine(mob/user)
	. = ..()
	. += span_notice("Hold it, use the ability, then click your target. It throws whatever is on the floor around \
		you, so an empty room does nothing.")

/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/harness
	name = "Sweep the Room"
	desc = "Lift up to five loose objects within five tiles and throw them, one at a time, at whatever you clicked. \
		Each one hits for its own throw damage. If there is nothing loose nearby, nothing happens."
	button_icon = 'icons/obj/antags/abductor.dmi'
	button_icon_state = "belt"
	cooldown_time = HARNESS_COOLDOWN
	sweep_radius = HARNESS_RADIUS
	volley_size = HARNESS_VOLLEY
	// A person does not get to tear the walls apart to make up a shortfall.
	conjure_floor = 0

/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/harness/Activate(atom/target)
	. = ..()
	if(!.)
		owner?.balloon_alert(owner, "nothing loose nearby!")

/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/harness/announce_windup()
	owner.visible_message(span_danger("[owner]'s harness lights up, and every loose thing on the floor nearby \
		starts shaking."))

#undef GREATER_TK_MAX_HELD
#undef GREATER_TK_RANGE
#undef GREATER_TK_THROW_RANGE
#undef GREATER_TK_THROW_SPEED
#undef GREATER_TK_IMPACT_DAMAGE
#undef GREATER_TK_HEAVY_KNOCKDOWN
#undef GREATER_TK_TOGGLE_COOLDOWN
#undef GREATER_TK_ORBIT_RADIUS
#undef GREATER_TK_PULL_SPEED
#undef GREATER_TK_BLOCK_CHANCE_PER_ITEM
#undef GREATER_TK_RIP_TIME
#undef GREATER_TK_MOB_SLOT_COST
#undef GREATER_TK_MAX_MOVE_RESIST
#undef VESTIGE_TK_FILTER
#undef VESTIGE_TK_COLOR
#undef MUTANT_MAX_HEALTH
#undef MUTANT_REVISION_THRESHOLD
#undef MUTANT_REVISION_SCALE
#undef MUTANT_REVISION_FILTER
#undef MUTANT_DISENGAGE_GRACE
#undef MUTANT_DISENGAGE_RANGE
#undef MUTANT_DISENGAGE_REGEN
#undef MUTANT_LEASH_RANGE
#undef MUTANT_SWEEP_COOLDOWN
#undef MUTANT_SWEEP_RADIUS
#undef MUTANT_SWEEP_VOLLEY
#undef MUTANT_SWEEP_VOLLEY_REVISED
#undef MUTANT_SWEEP_TELEGRAPH
#undef MUTANT_SWEEP_STAGGER
#undef MUTANT_SWEEP_FLOOR
#undef MUTANT_DEBRIS_LIFETIME
#undef MUTANT_PIN_COOLDOWN
#undef MUTANT_PIN_TELEGRAPH
#undef MUTANT_PIN_DAMAGE
#undef MUTANT_PIN_KNOCKDOWN
#undef MUTANT_PIN_THROW
#undef MUTANT_REPULSE_COOLDOWN
#undef MUTANT_REPULSE_TELEGRAPH
#undef MUTANT_REPULSE_RADIUS
#undef MUTANT_REPULSE_RADIUS_REVISED
#undef MUTANT_REPULSE_DAMAGE
#undef MUTANT_REPULSE_DISTANCE
#undef MUTANT_REPULSE_KNOCKDOWN
#undef MUTANT_CONFISCATE_COOLDOWN
#undef MUTANT_CONFISCATE_HOLD
#undef BB_MUTANT_SWEEP
#undef BB_MUTANT_PIN
#undef BB_MUTANT_REPULSE
#undef BB_MUTANT_CONFISCATE
#undef BB_MUTANT_LAST_ABILITY
#undef COLLAR_CATCH_COOLDOWN
#undef PALM_ANCHOR_COOLDOWN
#undef PALM_ANCHOR_RANGE
#undef HARNESS_COOLDOWN
#undef HARNESS_RADIUS
#undef HARNESS_VOLLEY
