/**
 * # Ilthuun, the Verdigris Lich
 *
 * The boss of The Verdigris. He sits in the sanctum at the bottom of a four-layer
 * lair and fights in three phases, one per school of his art.
 *
 * ## Why this is not a megafauna
 *
 * He is megafauna-*tier* and deliberately not megafauna-*typed*.
 * `code/modules/unit_tests/voidcrew_loot.dm:157` text-scans every ruin .dmm under the
 * voidcrew ruin root and hard-fails any map containing the literal strings
 * `/mob/living/basic/boss` or `/mob/living/simple_animal/hostile/megafauna` outside a
 * 14-map legacy arena whitelist. `/mob/living/basic/lich` shares no prefix with either,
 * so a map may place him freely. The stat block below is hand-copied from that tier;
 * the inheritance is not. Do not "tidy" this by reparenting him onto
 * `/mob/living/basic/boss` — that silently breaks the test suite for every ruin map
 * that carries him.
 *
 * He also gets none of the megafauna infrastructure on purpose: no wall-tearing
 * (`environment_smash = ENVIRONMENT_SMASH_NONE`), no devour, no crusher trophies, no
 * achievements, and no GPS beacon — `gps_name` lives on `/mob/living/basic/boss`, which
 * we do not inherit, so there is nothing to suppress.
 *
 * ## The thing that will bite you if you change it
 *
 * The Verdigris interior **never unloads** for the rest of the round (see track A's
 * `check_and_respawn()` / `unload_level()` overrides). That means anything he leaves
 * behind is permanent. Every mob he conjures is registered in [live_summons], is hard
 * capped by [max_live_summons], and is destroyed in [dismiss_all_summons] when he dies
 * or is deleted. An uncapped or uncleaned summon loop in a map that never resets is an
 * unkillable skeleton fog for the rest of the round. Any new ability that
 * creates a mob MUST route through [can_summon_more] and [register_summon].
 *
 * All summon types must also carry `DEL_ON_DEATH`, because the registry prunes on
 * death as well as on deletion — a summon that dies and leaves a corpse behind stops
 * being tracked, and we would rather it delete itself than linger.
 *
 * ## Leashing
 *
 * He must never wander the lair or reach the docks. He is leashed with
 * `/datum/component/leash` to an invisible anchor dropped on his home turf. The anchor
 * is a movable because the leash component rejects turfs
 * (`code/datums/components/leash.dm:35-37`).
 *
 * Every one of his repositioning effects — the leash's own recall
 * (`leash.dm:168`, a plain `forceMove`) and the illusion swap in lich_abilities.dm — is
 * positional rather than `do_teleport()` based. This is mandatory, not stylistic: all
 * five lair areas are `NOTELEPORT` so a teleport scroll cannot skip three defense
 * layers, and anything routed through `do_teleport()` would silently no-op inside his
 * own sanctum.
 *
 * Files: lich_abilities.dm holds his spells, AI controller and planning subtrees;
 * lich_thrall.dm holds the mind-control status effect. The site, the ritual clock, the
 * ward gates and the shared defines (`FACTION_LICH`, `LICH_GREEN`) are track A's, in
 * lich_site.dm / lich_wards.dm / voidcrew/_DEFINES/lich.dm.
 */

/// Trait source for the traits he applies to himself during a phase transition.
#define LICH_TRAIT "verdigris_lich"
/// Filter key for the phase-transition glow.
#define LICH_PHASE_FILTER "verdigris_phase_glow"

/mob/living/basic/lich
	name = "Ilthuun, the Verdigris Lich"
	desc = "A tall, dry thing in a green robe, wearing a horned skull that did not grow on its own head. \
		Green light moves behind the eye sockets."
	gender = MALE

	icon = 'voidcrew/modules/lich/icons/lich.dmi'
	icon_state = "lich"
	icon_living = "lich"
	icon_dead = "lich_dying"

	// Megafauna-tier stat block, hand-copied. See the header for why we do not inherit.
	maxHealth = 2800
	health = 2800
	melee_damage_lower = 25
	melee_damage_upper = 35
	armour_penetration = 40
	melee_attack_cooldown = 1.5 SECONDS
	obj_damage = 0
	speed = 2 // Deliberate and slow. He does not need to chase you; the wards do that.
	mob_size = MOB_SIZE_LARGE
	mob_biotypes = MOB_UNDEAD|MOB_HUMANOID
	// FACTION_LICH is track A's shared define ("verdigris"). It has to be on him and on
	// everything he raises, because the ward machines count anything alive, clientless,
	// mindless and in GLOB.lich_ward_garrison_factions as that layer's garrison — so
	// the faction is what makes the layer gates open at the right moment.
	// FACTION_SKELETON is kept as well so `/mob/living/basic/skeleton` summons never turn
	// on him, and FACTION_HOSTILE so generic hostile ruin fauna in the lair leave him be.
	// (There is no FACTION_UNDEAD in this codebase — checked code/__DEFINES/mobfactions.dm.)
	faction = list(FACTION_LICH, FACTION_SKELETON, FACTION_HOSTILE)
	// Undead: poison and suffocation mean nothing, and he does not tire.
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0, STAMINA = 0, OXY = 0)
	// He cannot be shoved out of position or stunlocked. status_flags = NONE strips
	// both CANPUSH and CANSTUN off the /mob/living/basic default.
	status_flags = NONE
	// A corpse-cold ruin should not hurt him, and he should not eat vacuum damage in a
	// depressurised sanctum. Zeroing all three means the atmos/temperature elements are
	// never attached at all (see /mob/living/basic/Initialize).
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	// No wall-tearing. The raid is supposed to be fought inside the geometry the map
	// track authored, not through it.
	environment_smash = ENVIRONMENT_SMASH_NONE

	attack_verb_continuous = "rends"
	attack_verb_simple = "rend"
	attack_sound = 'sound/effects/magic/demon_attack1.ogg'
	attack_vis_effect = ATTACK_EFFECT_CLAW
	speak_emote = list("intones")
	death_message = "sags inside its robe, and the green goes out of the room all at once."
	mouse_opacity = MOUSE_OPACITY_OPAQUE

	// A cold green cast on everything near him.
	lighting_cutoff_red = 10
	lighting_cutoff_green = 40
	lighting_cutoff_blue = 20

	ai_controller = /datum/ai_controller/basic_controller/lich

	/// Which school he is currently fighting with. 1 conjuration, 2 destruction, 3 illusion.
	/// Advanced by [on_health_update]; see [enter_phase] for what each one grants.
	var/phase = 1
	/// The last phase that exists. Past this he simply dies.
	var/max_phase = 3
	/// He enters the destruction phase at or below this fraction of maxHealth.
	var/destruction_threshold = 0.66
	/// He enters the illusion phase at or below this fraction of maxHealth.
	var/illusion_threshold = 0.33
	/// How long he is staggered and untouchable while a phase transition plays out.
	/// Short and purely for readability — unlike the Thing this is not a puzzle window,
	/// there are no machines to overload.
	var/phase_transition_time = 3 SECONDS

	/// Every mob he has conjured that is still alive, skeletons and mirror images alike.
	/// This is the authoritative list; the spells ask it for permission and report back
	/// to it. Read the file header before touching any of this.
	var/list/mob/living/live_summons = list()
	/// Hard ceiling on [live_summons]. Nothing may exceed it, ever, for any reason.
	var/max_live_summons = 8

	/// Turf he considers home. Set from an /obj/effect/landmark/lich/boss_spawn if the
	/// map placed one, otherwise wherever he was standing when he initialised.
	var/turf/home_turf
	/// The invisible movable the leash component is anchored to.
	var/obj/effect/lich_anchor/home_anchor
	/// How far from [home_turf] he may get before the leash drags him back.
	var/leash_range = 12
	/// Turfs marked by /obj/effect/landmark/lich/summon_spot, where his dead climb out.
	/// Empty is fine — [pick_summon_anchor] falls back to his own turf.
	var/list/turf/summon_anchors = list()

	/// Extra `/datum/element/death_drops` payload, empty by default. The real hoard — garb,
	/// staff, phylactery, spell codices — is track E's and is paid out by
	/// `drop_lich_hoard()` in [on_true_death], not through this list. This exists for
	/// variant subtypes and admin setups that want to bolt something else on; the element
	/// is only attached when the list is non-empty.
	var/list/death_loot = list()

	/// TRUE on the mirror-image subtype. Gates everything that only the real Ilthuun
	/// should do: phases, leashing, the summon registry and the death broadcast.
	var/is_illusion = FALSE

	/// Weakref to the last living thing that hit him, so his death report can name a
	/// killer. `/mob/living/var/lastattacker` only stores a name string, which is no use
	/// for `on_lich_slain()`'s `key_name()` call.
	var/datum/weakref/last_attacker_ref

/mob/living/basic/lich/Initialize(mapload)
	. = ..()

	// Everything below belongs to the real Ilthuun only. The illusion subtype must not
	// inherit any of it — in particular it registers its own COMSIG_ATOM_WAS_ATTACKED
	// handler, and RegisterSignal stack_traces when the same signal is claimed twice on
	// the same datum.
	if(is_illusion)
		return

	grant_school_abilities(phase) // defined in lich_abilities.dm

	if(length(death_loot))
		AddElement(/datum/element/death_drops, death_loot)

	// Aggro immediately if something shoots him from outside his sight range, same as
	// the Thing does (thing.dm:57-58) — otherwise a sniper can whittle a boss that
	// never plans a response.
	AddElement(/datum/element/relay_attackers)
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(immediate_aggro))
	RegisterSignal(src, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_health_update))

	// Landmarks are INITIALIZE_IMMEDIATE (code/game/objects/effects/landmarks.dm), so on
	// a mapload they are all in GLOB.landmarks_list by the time LateInitialize runs.
	// Admin-spawned copies have no mapload pass, so anchor them right away instead.
	if(mapload)
		return INITIALIZE_HINT_LATELOAD
	setup_lair_anchors()

/mob/living/basic/lich/LateInitialize()
	setup_lair_anchors()

/mob/living/basic/lich/Destroy()
	dismiss_all_summons(silent = TRUE)
	live_summons = null
	summon_anchors = null
	home_turf = null
	last_attacker_ref = null
	QDEL_NULL(home_anchor)
	return ..()

/**
 * Sets his home turf, collects his summon spots, and leashes him to home.
 *
 * Home is simply wherever he initialised. It deliberately does NOT re-read the
 * `/obj/effect/landmark/lich/boss_spawn` landmark: track A's `link_interior()` already
 * resolves that landmark when it decides where he goes — preferring a map-placed lich,
 * falling back to the landmark, then to any clear sanctum tile — and then `qdel`s the
 * landmark (lich_site.dm:389-391). Reading it here would be redundant at best, and at
 * worst would disagree with the site about where he lives, on whichever side of that
 * qdel our LateInitialize happened to land.
 *
 * Summon spots are ours alone; the site does not touch them.
 */
/mob/living/basic/lich/proc/setup_lair_anchors()
	home_turf = get_turf(src)

	// The lair loads into a turf reservation, and reservations share a z-level with
	// every other reservation in the round. z alone is not an isolation guarantee, so
	// the landmark sweep is distance-gated to the leash radius as well.
	if(isnull(home_turf))
		return

	for(var/obj/effect/landmark/lich/summon_spot/summon_mark in GLOB.landmarks_list)
		var/turf/mark_turf = get_turf(summon_mark)
		if(isnull(mark_turf) || mark_turf.z != home_turf.z || get_dist(mark_turf, home_turf) > leash_range)
			continue
		summon_anchors += mark_turf

	// The leash component refuses a turf owner (leash.dm:35-37), so drop an invisible
	// movable to hang the leash off. Its recall is a plain forceMove (leash.dm:168), which
	// is what makes it safe inside the lair's NOTELEPORT areas.
	// AddComponent is a variadic macro, so this has to stay on one line.
	home_anchor = new /obj/effect/lich_anchor(home_turf)
	AddComponent(/datum/component/leash, home_anchor, leash_range, /obj/effect/temp_visual/small_smoke/halfsecond, /obj/effect/temp_visual/small_smoke/halfsecond)

/**
 * Returns a turf for his conjured dead to appear on.
 *
 * Prefers a mapped `/obj/effect/landmark/lich/summon_spot`, but a map with none simply
 * gets his own turf back, which the conjure spell then spreads around with its
 * summon_radius. The fight cannot be bricked by a missing landmark.
 */
/mob/living/basic/lich/proc/pick_summon_anchor()
	RETURN_TYPE(/turf)
	// Prune any anchor that got destroyed or replaced since the map loaded.
	for(var/turf/anchor as anything in summon_anchors)
		if(QDELETED(anchor))
			summon_anchors -= anchor
	if(length(summon_anchors))
		return pick(summon_anchors)
	return get_turf(src)

// ===== SUMMON REGISTRY =====
// The single most important part of this mob. See the file header.

/// TRUE if he has room for [count] more live summons.
/mob/living/basic/lich/proc/can_summon_more(count = 1)
	return (length(live_summons) + count) <= max_live_summons

/**
 * Takes ownership of a freshly conjured mob.
 *
 * Registered on both COMSIG_QDELETING and COMSIG_LIVING_DEATH, the same pair
 * paper_wizard's summon spell uses (paper_abilities.dm:32), so the count follows the
 * mob whichever way it stops existing.
 */
/mob/living/basic/lich/proc/register_summon(mob/living/summon)
	if(QDELETED(summon) || (summon in live_summons))
		return
	live_summons += summon
	RegisterSignals(summon, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH), PROC_REF(on_summon_lost))

/mob/living/basic/lich/proc/on_summon_lost(mob/living/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH))
	live_summons -= source

/**
 * Destroys every mob he currently owns.
 *
 * Called on death and on deletion. This is what stops a party wipe from leaving a
 * permanent skeleton fog in an interior that never unloads.
 */
/mob/living/basic/lich/proc/dismiss_all_summons(silent = FALSE)
	if(!length(live_summons))
		return
	if(!silent)
		visible_message(span_boldwarning("Whatever was holding Ilthuun's dead upright lets go of them all at once."))
	for(var/mob/living/summon as anything in live_summons.Copy())
		if(QDELETED(summon))
			live_summons -= summon
			continue
		var/turf/collapse_turf = get_turf(summon)
		if(collapse_turf)
			new /obj/effect/temp_visual/small_smoke/halfsecond(collapse_turf)
			playsound(collapse_turf, 'sound/effects/magic/RATTLEMEBONES.ogg', 40, vary = TRUE)
		qdel(summon) // on_summon_lost prunes the list for us via COMSIG_QDELETING
	live_summons.Cut()

// ===== PHASES =====

/**
 * Watches his health and steps him up a phase when he crosses a threshold.
 *
 * Nothing clamps damage at a phase boundary (unlike the Thing, thing.dm:78-86), so a
 * single big hit can skip a phase entirely. [advance_to_phase] therefore walks the
 * phases one at a time instead of jumping, so the player never misses the tell for a
 * school that is about to be used on them.
 */
/mob/living/basic/lich/proc/on_health_update(datum/source)
	SIGNAL_HANDLER
	if(stat == DEAD || is_illusion || phase >= max_phase)
		return

	var/target_phase = 1
	if(health <= maxHealth * illusion_threshold)
		target_phase = 3
	else if(health <= maxHealth * destruction_threshold)
		target_phase = 2

	if(target_phase <= phase)
		return
	// visible_message/emote/playsound are not safe from a SIGNAL_HANDLER, so hand off.
	INVOKE_ASYNC(src, PROC_REF(advance_to_phase), target_phase)

/mob/living/basic/lich/proc/advance_to_phase(target_phase)
	while(phase < target_phase && phase < max_phase)
		enter_phase(phase + 1)

/**
 * Plays the transition for, and grants the abilities of, a new phase.
 *
 * The stagger is short and purely for readability: everyone in the room gets a beat to
 * read the balloon alert and the announcement before the new school starts landing on
 * them. It is not a puzzle window — there is nothing to overload, he just gets up again.
 */
/mob/living/basic/lich/proc/enter_phase(new_phase)
	phase = new_phase

	add_traits(list(TRAIT_GODMODE, TRAIT_IMMOBILIZED), LICH_TRAIT)
	// Stop him planning while he is staggered, or he casts through his own tell.
	// VOIDCREW EDIT: upstream deleted /datum/ai_controller/PauseAi() in the behaviour-tree
	// rewrite, but paused_until is still honoured by get_able_to_run(). This is that proc's
	// old body inlined (set the deadline, refresh now, refresh again when it lapses).
	if(ai_controller)
		ai_controller.paused_until = world.time + phase_transition_time
		ai_controller.update_able_to_run()
		addtimer(CALLBACK(ai_controller, TYPE_PROC_REF(/datum/ai_controller, update_able_to_run)), phase_transition_time)
	addtimer(CALLBACK(src, PROC_REF(end_phase_transition)), phase_transition_time, TIMER_UNIQUE|TIMER_OVERRIDE)

	// Pulsing green outline for the duration, the same trick the Thing uses for its
	// phase tell (thing.dm:102-105).
	add_filter(LICH_PHASE_FILTER, 2, list("type" = "outline", "color" = LICH_GREEN, "alpha" = 0, "size" = 2))
	var/phase_filter = get_filter(LICH_PHASE_FILTER)
	if(phase_filter)
		animate(phase_filter, alpha = 220, time = 0.4 SECONDS, loop = -1)
		animate(alpha = 0, time = 0.4 SECONDS)

	var/turf/our_turf = get_turf(src)
	if(our_turf)
		new /obj/effect/temp_visual/circle_wave/verdigris(our_turf)
		// VOIDCREW EDIT: RATTLEMEBONES2.ogg was deleted upstream for copyright (tg #96880).
		playsound(our_turf, 'sound/effects/magic/RATTLEMEBONES.ogg', 80, vary = TRUE, extrarange = SHORT_RANGE_SOUND_EXTRARANGE)
	for(var/mob/nearby in range(7, src))
		shake_camera(nearby, duration = 1 SECONDS, strength = 1)

	announce_phase(new_phase) // defined in lich_abilities.dm, holds the flavour text
	grant_school_abilities(new_phase) // ditto

/mob/living/basic/lich/proc/end_phase_transition()
	remove_traits(list(TRAIT_GODMODE, TRAIT_IMMOBILIZED), LICH_TRAIT)
	var/phase_filter = get_filter(LICH_PHASE_FILTER)
	if(phase_filter)
		animate(phase_filter)
		remove_filter(LICH_PHASE_FILTER)

// ===== COMBAT ODDS AND ENDS =====

/// Aggro whoever shoots him, even from outside his planning range. Lifted from
/// /mob/living/basic/boss/thing/immediate_aggro (thing.dm:170-174).
/mob/living/basic/lich/proc/immediate_aggro(datum/source, mob/attacker, flags)
	SIGNAL_HANDLER
	if(!isliving(attacker))
		return
	// Remembered for the death report regardless of whether we can act on it.
	last_attacker_ref = WEAKREF(attacker)
	if(isnull(ai_controller) || stat)
		return
	if(ai_controller.blackboard_key_exists(BB_CURRENT_TARGET))
		return
	ai_controller.set_blackboard_key(BB_CURRENT_TARGET, attacker)

/// The eyes keep burning until he stops. Harmless if track F has not shipped the
/// `lich_eyes` state yet — BYOND renders a missing icon_state as nothing.
/mob/living/basic/lich/update_overlays()
	. = ..()
	if(stat == DEAD)
		return
	. += mutable_appearance(icon, "lich_eyes")
	. += emissive_appearance(icon, "lich_eyes", src)

/mob/living/basic/lich/death(gibbed)
	dismiss_all_summons()
	on_true_death()
	return ..()

/**
 * Fired once, when the real Ilthuun dies. Overridden to nothing on the illusion.
 *
 * Three cross-track calls, all idempotent, all made explicitly rather than left to a
 * backstop:
 *
 * - `drop_lich_hoard(src)` is track E's payout API (lich_loot.dm) — the robe, crown,
 *   staff, phylactery and the three spell codices. Nothing else calls it, so without this
 *   line killing the boss drops nothing at all. Guarded by `GLOB.lich_hoard_dropped`.
 *   Called synchronously: it does not sleep, and the loot landing is not something to
 *   leave to a timer.
 * - `disperse_verdigris(killer)` is the other half of that payout — one of his three
 *   spells to every living player in the galaxy, not just the boarding party. Guarded by
 *   `GLOB.lich_dispersal_done`. This is the ONLY place in the module that gives the crew
 *   power, and it fires on his death by design; see the roster note in
 *   events/lich_events.dm.
 * - `crumble_lich_leavings()` takes back everything his rituals left in the galaxy — the
 *   ossuary's bone kit, and anything a future rite drops — so no rite doubles as a supply
 *   drop. Idempotent by construction: the registry is emptied as it is swept.
 * - `on_lich_slain()` is track A's site hook — stops the ritual clock, broadcasts the
 *   victory line, retires the helm waypoints. Guarded on the site's `spent` flag, and the
 *   site also registers COMSIG_LIVING_DEATH on the bound lich as its own backstop
 *   (lich_site.dm:334-338), so calling it here cannot double-fire. Invoked async because
 *   the announcement path sleeps and `death()` is reached from inside damage application.
 */
/mob/living/basic/lich/proc/on_true_death()
	var/turf/our_turf = get_turf(src)
	if(our_turf)
		new /obj/effect/temp_visual/circle_wave/verdigris(our_turf)
		playsound(our_turf, 'sound/effects/magic/demon_dies.ogg', 90, vary = TRUE)
	visible_message(span_boldannounce("Ilthuun folds up like a dropped coat. The green light goes out of the walls."))

	var/mob/living/killer = last_attacker_ref?.resolve()
	log_game("LICH: Ilthuun died at [AREACOORD(src)], last attacker [killer ? key_name(killer) : "unknown"].")

	drop_lich_hoard(src)
	disperse_verdigris(killer)
	crumble_lich_leavings()

	var/obj/structure/overmap/space_ruin/lich_lair/site = GLOB.lich_lair
	if(!QDELETED(site))
		INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap/space_ruin/lich_lair, on_lich_slain), src, killer)

// ===== MIRROR IMAGES =====

/**
 * A phase-three illusion of Ilthuun.
 *
 * Straight out of `/mob/living/basic/paper_wizard/copy` (paper_wizard.dm:103-139):
 * 1 HP, indistinguishable by name, pops the instant a living mob examines it, and
 * punishes whoever swings at it. Observers can see through it and are told so.
 *
 * It is a subtype of the lich so it inherits the sprite and the description for free;
 * everything that only the real one should do is gated behind [is_illusion].
 */
/mob/living/basic/lich/mirror_image
	health = 1
	maxHealth = 1
	melee_damage_lower = 5
	melee_damage_upper = 12
	armour_penetration = 0
	alpha = 235
	speed = 1.5
	status_flags = CANPUSH
	// Illusions never leave a corpse — see the file header on why nothing he makes is
	// allowed to persist in an interior that never unloads.
	basic_mob_flags = DEL_ON_DEATH
	ai_controller = /datum/ai_controller/basic_controller/simple/simple_hostile
	death_loot = null
	is_illusion = TRUE

/mob/living/basic/lich/mirror_image/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/relay_attackers)
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))

/// Illusions have no abilities, no phases, no leash and no death broadcast.
/mob/living/basic/lich/mirror_image/setup_lair_anchors()
	return

/mob/living/basic/lich/mirror_image/on_true_death()
	return

/mob/living/basic/lich/mirror_image/dismiss_all_summons(silent = FALSE)
	return

/// Hit a fake and the fake bites back on its way out, same as the paper wizard's copies
/// (paper_wizard.dm:125-131). Shoves and stamina hits are exempt so a disarm is not a
/// death sentence.
/mob/living/basic/lich/mirror_image/proc/on_attacked(mob/source, mob/living/attacker, attack_flags)
	SIGNAL_HANDLER
	if(attack_flags & (ATTACKER_STAMINA_ATTACK|ATTACKER_SHOVING))
		return
	attacker.adjust_fire_loss(15)
	to_chat(attacker, span_warning("The image bursts, and something cold pours down your arm!"))

/mob/living/basic/lich/mirror_image/examine(mob/user)
	. = ..()
	if(isobserver(user))
		. += span_notice("It isn't real. The actual Ilthuun is standing somewhere else.")
		return
	new /obj/effect/temp_visual/small_smoke/halfsecond(get_turf(src))
	qdel(src) // Seen through.

// ===== SUPPORT ATOMS =====

/**
 * Invisible movable that the leash component hangs off.
 *
 * `/datum/component/leash` requires a movable owner and rejects turfs outright
 * (leash.dm:35-37), so the lich drops one of these on his home turf at init and leashes
 * himself to it. It is deleted with him.
 */
/obj/effect/lich_anchor
	name = "grave-anchor"
	desc = "You should not be able to see this."
	icon = null
	icon_state = null
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	density = FALSE
	move_resist = INFINITY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/// A green ripple. Used for phase transitions, his death, and as the ground telegraph
/// under an incoming bone volley.
/obj/effect/temp_visual/circle_wave/verdigris
	color = LICH_GREEN

// ===== LANDMARKS =====

/**
 * Map-side markers for the sanctum fight.
 *
 * Both are optional and both have a consumer with a geometric fallback, so a
 * hand-edited lair that places neither still runs the fight correctly — it just runs it
 * centred on wherever Ilthuun happens to be standing.
 */
/obj/effect/landmark/lich
	name = "lich landmark"
	icon = 'icons/mob/landmarks.dmi'
	icon_state = "x"

/**
 * Marks where Ilthuun should stand.
 *
 * Consumed by track A: `link_interior()` prefers a map-placed `/mob/living/basic/lich`,
 * falls back to this landmark's turf, and failing that to any clear sanctum tile — then
 * `qdel`s the landmark (lich_site.dm:389-391). Placing both a mob and this marker is
 * safe and does not double-spawn.
 *
 * It is a pure marker: it spawns nothing itself. The site is the single authority on
 * where the boss goes, and two things racing to place a 2800 HP boss in a map that never
 * unloads is not a race worth entering.
 */
/obj/effect/landmark/lich/boss_spawn
	name = "lich boss spawn"

/// Marks a turf his conjured dead climb out of. Place several around the sanctum;
/// [/mob/living/basic/lich/proc/pick_summon_anchor] picks one at random per cast and
/// falls back to his own turf if the map placed none.
/obj/effect/landmark/lich/summon_spot
	name = "lich summon spot"

#undef LICH_TRAIT
#undef LICH_PHASE_FILTER
