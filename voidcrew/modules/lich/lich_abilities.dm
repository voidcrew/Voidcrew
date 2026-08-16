/**
 * # Ilthuun's spells, AI controller and planning subtrees
 *
 * Three schools, granted one phase at a time by [/mob/living/basic/lich/proc/enter_phase]:
 *
 * - **Conjuration** (phase 1): Raise the Buried. Pulls skeletons out of the floor at
 *   the map's `/obj/effect/landmark/lich/summon_spot` markers. Revoked in phase 3.
 * - **Destruction** (phase 2): Volley of the Ossuary (a telegraphed, green
 *   `aoe/magic_missile` barrage), Bolt of Necropotence (a fast three-shot bolt), and
 *   Lift the Lid (a telegraphed ground hazard, the one piece antimagic cannot touch).
 *   Also where Wear Them comes online, the mind-control spell in lich_thrall.dm.
 * - **Illusion** (phase 3): Verdigris Reflection. Copies of himself, straight off
 *   `/datum/action/cooldown/spell/pointed/wizard_mimic` (paper_abilities.dm:41-89).
 *
 * ## Upstream coupling, verified
 *
 * Every spell here sets `spell_requirements = NONE`. Upstream's base defaults to
 * `SPELL_REQUIRES_WIZARD_GARB|SPELL_REQUIRES_NO_ANTIMAGIC` (`code/modules/spells/spell.dm:73`)
 * and Ilthuun wears no wizard garb. A robe and a skull are not the garb typepaths the
 * check looks for, so without this every spell in the fight would silently fail
 * `can_cast_spell` and he would stand there punching people for 2800 HP.
 *
 * `/datum/action/cooldown/spell/conjure` (spell_types/conjure/_conjure.dm) does the
 * turf-picking and spawning for Raise the Buried; the only thing we change is *where* it
 * centres, by rewriting `cast_on` to a summon anchor before calling parent.
 *
 * `/datum/action/cooldown/spell/aoe/magic_missile` (spell_types/aoe_spell/magic_missile.dm)
 * already iterates living mobs in view and calls `fire_projectile(victim, caster)` per
 * target, so the telegraph slots cleanly into `cast_on_thing_in_aoe` without touching
 * the aoe machinery.
 *
 * `/datum/ai_behavior/targeted_mob_ability` drives pointed spells with
 * `ability.Trigger(target = target)`, which is why the pointed spells here work from an
 * AI at all. Verified in basic_ai_behaviors/targeted_mob_ability.dm.
 *
 * ## Deviations from the contract, and why
 *
 * The contract offers `/obj/projectile/magic/necropotence` to subtype. Its `on_hit`
 * (magic.dm:335-344) performs a soul tap, which permanently reduces the victim's
 * maxHealth. A repeatable boss ability that permanently debuffs a raider is not
 * something a crew can recover from between attempts, so the green bolt below subtypes
 * `/obj/projectile/magic` directly and borrows only necropotence's `icon_state`. It is
 * necropotence-*flavoured*, per the contract's wording, not necropotence-derived.
 *
 * There is no illusion school define in `code/__DEFINES/magic.dm`; the illusion spells
 * use `SCHOOL_PSYCHIC`, which is the closest existing bucket.
 *
 * ## The antimagic boolean, and why the fight no longer lives or dies on it
 *
 * Playtest result: the fight was decided before the doors opened. Both projectiles
 * inherited `armour_penetration = 100, armor_flag = NONE` from `/obj/projectile/magic`
 * (magic.dm:6-7), and `prehit_pierce()` (magic.dm:13-20) deletes a magic projectile
 * outright against anyone passing `can_block_magic(MAGIC_RESISTANCE)`. So a crew with a
 * nullrod sat in a corner while his entire ranged kit ceased to exist, and a crew
 * without one ate five simultaneous paralyzes and died where they stood. Three answers,
 * all in this file:
 *
 * - Both projectiles now carry an armor slope (`armor_flag = ENERGY`, 35 AP), so what
 *   you wear moves the damage instead of gating it. See the projectile block.
 * - The volley knocks down instead of paralyzing, so getting hit is a position you dig
 *   out of rather than a cutscene. Also the projectile block.
 * - Lift the Lid resolves through position, never through `can_block_magic()`, so one
 *   talisman can no longer blank the whole phase. See its own header for the intent.
 *
 * Wear Them stays fully antimagic-blockable on purpose: mind control is the one thing
 * in his kit a talisman should flatly stop.
 *
 * ## Nothing here teleports
 *
 * All five lair areas are `NOTELEPORT` (track A), deliberately, so that a teleport
 * scroll cannot skip three defense layers. That applies to Ilthuun as well: the illusion
 * swap below uses `forceMove` onto an adjacent turf, not `do_teleport()`, which would
 * silently no-op inside his own sanctum. Keep any future repositioning positional.
 */

/// A lighter wash than LICH_GREEN, for tinting the things he raises.
#define VERDIGRIS_TINT "#7fd8a0"

// Phase numbers, matching /mob/living/basic/lich/var/phase.
#define LICH_PHASE_CONJURATION 1
#define LICH_PHASE_DESTRUCTION 2
#define LICH_PHASE_ILLUSION 3

// Blackboard keys for his abilities. Deliberately confined to this file, the mob's
// granting and revoking both live here (see below) so lich_mob.dm never needs them and
// the two files carry no #define ordering dependency on each other.
#define BB_LICH_RAISE_DEAD "BB_lich_raise_dead"
#define BB_LICH_BONE_VOLLEY "BB_lich_bone_volley"
#define BB_LICH_NECROTIC_BOLT "BB_lich_necrotic_bolt"
#define BB_LICH_GRAVE_DIRT "BB_lich_grave_dirt"
#define BB_LICH_MIRROR_IMAGES "BB_lich_mirror_images"
#define BB_LICH_CORRUPTION "BB_lich_corruption"

// ===== PHASE WIRING =====

/**
 * Grants the abilities of a phase, and takes away anything that phase retires.
 *
 * Additive by design: phase 2 keeps his summoning, so the destruction phase is fought
 * against skeletons *and* missiles. Phase 3 is the exception, it revokes conjuration,
 * because a boss who can both flood the room and duplicate himself at 33% health is
 * both unreadable and a summon-cap fight rather than a boss fight.
 */
/mob/living/basic/lich/proc/grant_school_abilities(new_phase)
	if(is_illusion)
		return

	switch(new_phase)
		if(LICH_PHASE_CONJURATION)
			grant_actions_by_list(list(
				/datum/action/cooldown/spell/conjure/lich_raise_dead = BB_LICH_RAISE_DEAD,
			))

		if(LICH_PHASE_DESTRUCTION)
			grant_actions_by_list(list(
				/datum/action/cooldown/spell/aoe/magic_missile/lich_bone_volley = BB_LICH_BONE_VOLLEY,
				/datum/action/cooldown/spell/pointed/projectile/lich_necrotic_bolt = BB_LICH_NECROTIC_BOLT,
				/datum/action/cooldown/spell/pointed/lich_grave_dirt = BB_LICH_GRAVE_DIRT,
				/datum/action/cooldown/spell/pointed/lich_corruption = BB_LICH_CORRUPTION,
			))

		if(LICH_PHASE_ILLUSION)
			grant_actions_by_list(list(
				/datum/action/cooldown/spell/pointed/lich_mirror_images = BB_LICH_MIRROR_IMAGES,
			))
			// He has run out of buried dead. From here he only has himself to spend.
			revoke_ability(BB_LICH_RAISE_DEAD)
			// And he stops pacing himself. This 15 -> 10 second drop was originally
			// tuned against a volley that paralyzed, which no longer exists: the
			// missiles knock down now (see the projectile block). Kept anyway, and it
			// matters more than it did -- with no paralyze chain, sustained volley
			// pressure at this cadence is what stops phase 3 from being solved by
			// pure kiting.
			var/datum/action/cooldown/volley = ai_controller?.blackboard[BB_LICH_BONE_VOLLEY]
			if(!QDELETED(volley))
				volley.cooldown_time = 10 SECONDS

/// Destroys an ability he owns and clears it out of the blackboard, so the planning
/// subtree that watches that key stops firing.
/mob/living/basic/lich/proc/revoke_ability(blackboard_key)
	var/datum/action/ability = ai_controller?.blackboard[blackboard_key]
	ai_controller?.clear_blackboard_key(blackboard_key)
	if(!QDELETED(ability))
		qdel(ability)

/// The green tell for each phase. Loud on purpose: the fight is only fair if you can
/// tell which school is about to be used on you.
/mob/living/basic/lich/proc/announce_phase(new_phase)
	switch(new_phase)
		if(LICH_PHASE_DESTRUCTION)
			visible_message(span_boldwarning("Ilthuun straightens up, and the green in the room turns hard and bright. \
				\"ENOUGH DIGGING. I WILL DO THIS MYSELF.\""))
			balloon_alert_to_viewers("destruction!")
		if(LICH_PHASE_ILLUSION)
			visible_message(span_boldwarning("Ilthuun laughs, and for a moment there is more than one of him laughing. \
				\"YOU HAVE BEEN VERY BUSY. WHICH OF ME WERE YOU HITTING?\""))
			balloon_alert_to_viewers("illusion!")

// ===== AI =====

/**
 * Ilthuun's controller.
 *
 * Laid out like `/datum/ai_controller/basic_controller/paper_wizard` (paper_wizard.dm:51-71):
 * find a target, then walk the ability subtrees, then fall through to melee. Every
 * ability subtree sets `finish_planning = FALSE` so a queued spell does not stop him
 * swinging in the same tick. Cooldowns, not planning order, are what pace the fight.
 *
 * `idle_behavior` is deliberately null. He does not wander; he stands in the sanctum
 * until someone walks in. The leash on the mob is the hard guarantee, but not moving in
 * the first place means the leash never has to drag him anywhere.
 */
/datum/ai_controller/basic_controller/lich
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = null
	planning_subtrees = list(
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/targeted_mob_ability/lich_corruption,
		/datum/ai_planning_subtree/targeted_mob_ability/lich_mirror_images,
		/datum/ai_planning_subtree/targeted_mob_ability/lich_grave_dirt,
		/datum/ai_planning_subtree/targeted_mob_ability/lich_necrotic_bolt,
		/datum/ai_planning_subtree/use_mob_ability/lich_bone_volley,
		/datum/ai_planning_subtree/use_mob_ability/lich_raise_dead,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

/datum/ai_planning_subtree/use_mob_ability/lich_raise_dead
	ability_key = BB_LICH_RAISE_DEAD
	finish_planning = FALSE

/datum/ai_planning_subtree/use_mob_ability/lich_bone_volley
	ability_key = BB_LICH_BONE_VOLLEY
	finish_planning = FALSE

/datum/ai_planning_subtree/targeted_mob_ability/lich_necrotic_bolt
	ability_key = BB_LICH_NECROTIC_BOLT
	finish_planning = FALSE

/datum/ai_planning_subtree/targeted_mob_ability/lich_grave_dirt
	ability_key = BB_LICH_GRAVE_DIRT
	finish_planning = FALSE

/datum/ai_planning_subtree/targeted_mob_ability/lich_mirror_images
	ability_key = BB_LICH_MIRROR_IMAGES
	finish_planning = FALSE

/datum/ai_planning_subtree/targeted_mob_ability/lich_corruption
	ability_key = BB_LICH_CORRUPTION
	finish_planning = FALSE

/// Don't bother trying to possess something that cannot be possessed, otherwise the
/// ability burns its planning slot every tick on antimagic-carrying raiders.
/datum/ai_planning_subtree/targeted_mob_ability/lich_corruption/additional_ability_checks(datum/ai_controller/controller, datum/action/cooldown/using_action)
	var/mob/living/target = controller.blackboard[target_key]
	return can_be_lich_thralled(target) // defined in lich_thrall.dm

// ===== CONJURATION =====

/**
 * ## Raise the Buried
 *
 * Skeletons climb out of the floor at the sanctum's summon spots.
 *
 * The cap and the tracking are not implemented here on purpose. The mob owns the
 * registry (`live_summons` / `max_live_summons` on `/mob/living/basic/lich`) because the
 * illusion spell also feeds it, and because the interior never unloads, one authority
 * for "what has he left lying around" is the whole point. This spell only asks
 * permission and reports back.
 */
/datum/action/cooldown/spell/conjure/lich_raise_dead
	name = "Raise the Buried"
	desc = "Pulls the lair's dead back onto their feet."
	button_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "art_summon"
	sound = 'sound/effects/magic/castsummon.ogg'

	school = SCHOOL_NECROMANCY
	cooldown_time = 12 SECONDS
	invocation = "UP. ALL OF YOU. UP. YOU HAVE RESTED LONGER THAN YOU LIVED."
	invocation_type = INVOCATION_SHOUT
	spell_requirements = NONE

	summon_type = list(
		/mob/living/basic/skeleton,
		/mob/living/basic/skeleton/settler,
		/mob/living/basic/skeleton/templar,
	)
	summon_radius = 2
	summon_amount = 2
	summon_respects_density = TRUE
	// Permanent. The cap plus the mob's death cleanup is what keeps this safe, not a
	// timer, see the header of lich_mob.dm.
	summon_lifespan = 0

/datum/action/cooldown/spell/conjure/lich_raise_dead/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/lich/ilthuun = owner
	if(!istype(ilthuun))
		return FALSE
	// Any room at all is enough, cast() clamps the batch to what is left under the
	// cap, so a lone free slot still buys a skeleton instead of a silent turn.
	return ilthuun.can_summon_more(1)

/**
 * Recentres the summon on one of the map's summon spots before handing off to the base
 * conjure spell, which then spreads the batch over `range(summon_radius, cast_on)`.
 *
 * `pick_summon_anchor()` returns his own turf when the map placed no landmarks, so a
 * hand-edited lair still works, the dead just climb out around his feet instead.
 */
/datum/action/cooldown/spell/conjure/lich_raise_dead/cast(atom/cast_on)
	var/mob/living/basic/lich/ilthuun = owner
	var/turf/anchor = ilthuun?.pick_summon_anchor()
	if(istype(ilthuun))
		// Clamp the batch to the room left under the cap, so a partial batch keeps the
		// cap exact. can_cast_spell guarantees at least one slot is free.
		summon_amount = clamp(ilthuun.max_live_summons - length(ilthuun.live_summons), 1, initial(summon_amount))
	// Passed explicitly rather than relying on DM aliasing the named parameter into args.
	return ..(anchor || cast_on)

/datum/action/cooldown/spell/conjure/lich_raise_dead/post_summon(atom/summoned_object, atom/cast_on)
	. = ..()
	var/mob/living/risen = summoned_object
	if(!isliving(risen))
		return

	var/mob/living/basic/lich/ilthuun = owner
	if(!istype(ilthuun))
		// Unreachable in the fight: can_cast_spell already rejects a non-lich owner,
		// but if it ever happens, an untracked summon in an interior that never unloads
		// is exactly the failure mode this module exists to prevent. Refuse to leave it.
		qdel(risen)
		return

	ilthuun.register_summon(risen)
	// FACTION_LICH is what makes the ward machines read this thing as its layer's
	// garrison rather than as somebody's pet, so the gates open when the hall is
	// actually clear. FACTION_SKELETON is kept so the /mob/living/basic/skeleton types
	// still recognise each other.
	risen.faction = list(FACTION_LICH, FACTION_SKELETON)
	risen.add_atom_colour(VERDIGRIS_TINT, FIXED_COLOUR_PRIORITY)
	var/turf/risen_turf = get_turf(risen)
	if(risen_turf)
		new /obj/effect/temp_visual/small_smoke/halfsecond(risen_turf)
		playsound(risen_turf, 'sound/effects/magic/RATTLEMEBONES.ogg', 45, vary = TRUE)

// ===== DESTRUCTION =====

/**
 * ## Volley of the Ossuary
 *
 * A green magic missile barrage. Telegraphed twice: he announces the wind-up, and every
 * mob about to be hit gets a ripple on their own tile [telegraph_time] before the
 * missile actually launches. That window is the whole counterplay. Break line of sight
 * or get behind something.
 */
/datum/action/cooldown/spell/aoe/magic_missile/lich_bone_volley
	name = "Volley of the Ossuary"
	desc = "Marks everyone in sight, then throws a piece of the ossuary at each of them."
	sound = 'sound/effects/magic/magic_missile.ogg'

	school = SCHOOL_NECROMANCY
	cooldown_time = 15 SECONDS
	invocation = "COUNT YOURSELVES. I ALREADY HAVE."
	invocation_type = INVOCATION_SHOUT
	spell_requirements = NONE

	aoe_radius = 7
	max_targets = 5
	shuffle_targets_list = TRUE
	projectile_type = /obj/projectile/magic/aoe/magic_missile/verdigris

	/// How long between a target being marked and the missile leaving his hand.
	var/telegraph_time = 1.5 SECONDS

/datum/action/cooldown/spell/aoe/magic_missile/lich_bone_volley/cast(atom/cast_on)
	if(owner)
		owner.visible_message(span_boldwarning("Ilthuun spreads both hands, and the room fills with the smell of wet bone."))
		owner.balloon_alert_to_viewers("marking targets!")
	return ..()

/datum/action/cooldown/spell/aoe/magic_missile/lich_bone_volley/cast_on_thing_in_aoe(mob/living/victim, atom/caster)
	var/turf/mark_turf = get_turf(victim)
	if(mark_turf)
		new /obj/effect/temp_visual/circle_wave/verdigris(mark_turf)
	addtimer(CALLBACK(src, PROC_REF(delayed_fire), victim, caster), telegraph_time)

/// Fires after the telegraph window. Re-checks both ends, because 1.5 seconds is plenty
/// of time for a target to die or for Ilthuun to.
/datum/action/cooldown/spell/aoe/magic_missile/lich_bone_volley/proc/delayed_fire(atom/victim, mob/caster)
	if(QDELETED(victim) || QDELETED(caster))
		return
	fire_projectile(victim, caster)

/**
 * ## Bolt of Necropotence
 *
 * His quick attack. Three bolts per cast, short cooldown, used at range while the
 * skeletons close.
 */
/datum/action/cooldown/spell/pointed/projectile/lich_necrotic_bolt
	name = "Bolt of Necropotence"
	desc = "A fast green bolt, three per cast. It rots whatever it hits."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "spell_default"
	sound = 'sound/effects/magic/curse.ogg'

	school = SCHOOL_NECROMANCY
	cooldown_time = 6 SECONDS
	invocation = "LEND IT TO ME."
	invocation_type = INVOCATION_WHISPER
	spell_requirements = NONE

	cast_range = 9
	projectile_type = /obj/projectile/magic/verdigris_necropotence
	projectile_amount = 3

/**
 * ## Lift the Lid
 *
 * Phase 2's ground hazard. He picks someone, the 3x3 of deck around them darkens into
 * turned earth for [telegraph_time], and then the patch burns for [burn_duration]:
 * anything living standing on it takes [burn_per_tick] burn per [burn_interval] until
 * it steps off or gets on top of something. His own faction walks on it freely.
 *
 * ### Why this exists, and why it is not a projectile
 *
 * Everything else phase 2 throws resolves through one boolean. The missiles and the
 * bolt are magic projectiles, deleted on contact by `prehit_pierce()` against a
 * `can_block_magic(MAGIC_RESISTANCE)` carrier, and Wear Them checks the same flag by
 * design. Playtested result: one nullrod turned the whole phase off. This ability is
 * the piece of his kit that boolean cannot answer, deliberately: it is not a
 * projectile, and nothing in it ever consults the target's antimagic. The counterplay
 * is movement -- the telegraph gives you the window, the elevation rule gives you an
 * answer that works mid-melee, and it burns ground, not people, so it never needs to
 * care what you are carrying.
 *
 * ### Salvage note
 *
 * The damage shape, the elevation rule and the green-washed `weather_effects.dmi`
 * ground overlay are carried over from the deleted galaxy-rite version of the same
 * idea (Ritual: The Floor Is Grave-Dirt, formerly under events/), itself a port of
 * `/datum/weather/floor_is_lava`. Reimplemented here self-contained because the event
 * framework is gone. Two deliberate drops from the rite's rule set:
 * TRAIT_LAVA_IMMUNE / TRAIT_WEATHER_IMMUNE are not honoured (this is his working, not
 * weather, and a gear trait quietly restoring a full exemption is exactly the
 * bimodality this ability exists to remove), and the burn lands raw rather than
 * through armor, because a patch you can simply step off does not need a second
 * mitigation axis.
 *
 * ### Lifecycle safety
 *
 * The lair interior never unloads, so a leaked effect loop would be permanent. Four
 * guards, in depth: every timer callback opens with a QDELETED(src) bail (timers fire
 * on qdel'd datums -- the callback holds a hard ref); the burn loop is time-bounded
 * by [burn_duration] no matter what; the ground visuals are temp_visuals that delete
 * themselves on their own timers even if this datum leaks; and Destroy() deltimers
 * the pending step and snuffs the visuals, so deleting him (or this action) ends an
 * in-flight patch instantly. If he merely dies without being deleted, an
 * already-burning patch runs out its last few seconds on its own -- acceptable, and
 * bounded.
 */
/datum/action/cooldown/spell/pointed/lich_grave_dirt
	name = "Lift the Lid"
	desc = "Turns the ground under someone into burning grave-dirt. Step off it, or get on top of something."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "spell_default"
	sound = 'sound/effects/magic/curse.ogg'

	school = SCHOOL_NECROMANCY
	cooldown_time = 12 SECONDS // Pre-playtest guess: slower than the bolt, faster than the volley.
	invocation = "GET YOUR FEET OFF MY GROUND."
	invocation_type = INVOCATION_SHOUT
	spell_requirements = NONE

	cast_range = 9 // The bolt's reach, so his two pointed attacks threaten the same ring.

	// Every figure below is a pre-playtest guess. The intended feel: standing in the
	// patch for its whole life (7 ticks x 5 burn = 35) costs about a bolt and a half,
	// walking out on the telegraph costs nothing.
	/// How long the patch glows dim before it starts burning. The whole counterplay window.
	var/telegraph_time = 2 SECONDS
	/// How long the ground burns once lit.
	var/burn_duration = 7 SECONDS
	/// How often the burn is applied while it lasts.
	var/burn_interval = 1 SECONDS
	/// Burn applied per tick to anyone standing on an affected tile.
	var/burn_per_tick = 5
	/// The live patch's ground visuals, so his deletion can snuff them early.
	var/list/obj/effect/temp_visual/lich_grave_dirt/active_dirt = list()
	/// Stoppable id of the pending ignition, null outside the telegraph window.
	var/ignite_timer
	/// Stoppable id of the next burn application, null outside the burn window.
	var/burn_timer

/datum/action/cooldown/spell/pointed/lich_grave_dirt/Destroy()
	deltimer(ignite_timer)
	deltimer(burn_timer)
	ignite_timer = null
	burn_timer = null
	QDEL_LIST(active_dirt)
	return ..()

/datum/action/cooldown/spell/pointed/lich_grave_dirt/is_valid_target(atom/cast_on)
	. = ..()
	if(!.)
		return FALSE
	if(!isliving(cast_on))
		return FALSE
	var/mob/living/victim = cast_on
	return victim.stat != DEAD

/datum/action/cooldown/spell/pointed/lich_grave_dirt/cast(mob/living/cast_on)
	. = ..()
	var/turf/center = get_turf(cast_on)
	if(isnull(center))
		return

	if(owner)
		owner.visible_message(span_boldwarning("Ilthuun drives a hand downward, and the ground around [cast_on] darkens into turned earth."))
		owner.balloon_alert_to_viewers("the ground turns!")

	// The cooldown (12s) is longer than telegraph + burn (9s), so exactly one patch
	// can be in flight and the single-slot timer ids above are safe. If a retune ever
	// breaks that inequality, the ids must become lists first.
	QDEL_LIST(active_dirt) // No-op under that invariant; a hard reset if it breaks.

	// His established "something is about to happen on this tile" tell, same as the
	// volley's per-target mark, so the language of the fight stays consistent.
	new /obj/effect/temp_visual/circle_wave/verdigris(center)
	var/list/turf/patch = list()
	for(var/turf/tile as anything in RANGE_TURFS(1, center))
		if(isnull(tile) || isspaceturf(tile))
			continue
		patch += tile
		active_dirt += new /obj/effect/temp_visual/lich_grave_dirt(tile, telegraph_time + burn_duration)
		for(var/mob/living/warned in tile)
			if(can_burn(warned))
				to_chat(warned, span_warning("The ground under you softens into warm, turned earth. Move."))
	if(!length(patch))
		return
	ignite_timer = addtimer(CALLBACK(src, PROC_REF(ignite_patch), patch, center), telegraph_time, TIMER_STOPPABLE)

/// Fires when the telegraph runs out. QDELETED-guarded for the same reason as the
/// volley's delayed_fire: two seconds is plenty of time for him to stop existing.
/datum/action/cooldown/spell/pointed/lich_grave_dirt/proc/ignite_patch(list/turf/patch, turf/center)
	if(QDELETED(src))
		return
	ignite_timer = null
	playsound(center, 'sound/effects/magic/fireball.ogg', 60, TRUE)
	for(var/obj/effect/temp_visual/lich_grave_dirt/dirt as anything in active_dirt)
		if(QDELETED(dirt))
			continue
		// The dim telegraph wash hardens into the full burn overlay.
		animate(dirt, alpha = 230, time = 0.3 SECONDS)
	burn_tick(patch, world.time + burn_duration)

/**
 * One application of the burn, self-rescheduling until end_time.
 *
 * Holding the turf list across the burn is safe: BYOND turf refs are positional, so a
 * tile that gets ChangeTurf'd mid-burn resolves to whatever replaced it, which is the
 * behaviour we want -- the dirt is on the ground, not on a particular floor type.
 */
/datum/action/cooldown/spell/pointed/lich_grave_dirt/proc/burn_tick(list/turf/patch, end_time)
	if(QDELETED(src))
		return
	burn_timer = null
	for(var/turf/tile as anything in patch)
		if(turf_is_safe(tile))
			continue
		for(var/mob/living/victim in tile)
			if(!can_burn(victim))
				continue
			victim.adjustFireLoss(burn_per_tick)
			to_chat(victim, span_danger("The grave-dirt sears you from below!"))
	// The first application lands at ignition, so reschedule only while the NEXT one
	// would still fall inside the window: 7 ticks total, not 8.
	if(world.time + burn_interval < end_time)
		burn_timer = addtimer(CALLBACK(src, PROC_REF(burn_tick), patch, end_time), burn_interval, TIMER_STOPPABLE)

/// TRUE if this tile of the patch cannot burn anyone right now. The ground half of
/// /datum/weather/floor_is_lava/can_weather_act_mob(): walls are not floors, and a
/// dense structure (a table, a rack) is something to stand on. The elevation rule is
/// the mid-melee counterplay, keep it generous.
/datum/action/cooldown/spell/pointed/lich_grave_dirt/proc/turf_is_safe(turf/tile)
	if(QDELETED(tile) || tile.density)
		return TRUE
	for(var/obj/structure/perch in tile)
		if(perch.density)
			return TRUE
	return FALSE

/// TRUE if the burn applies to this mob. The containment exemptions (in a locker, in
/// a mech, in a body bag) are structural rather than checked: the burn loop only ever
/// sees a turf's direct contents.
/datum/action/cooldown/spell/pointed/lich_grave_dirt/proc/can_burn(mob/living/victim)
	if(QDELETED(victim) || victim.stat == DEAD)
		return FALSE // Cooking a corpse does nothing but husk somebody's revival.
	if(FACTION_LICH in victim.faction)
		return FALSE // His skeletons walk on it freely. So do active thralls: lich_thrall.dm rewrites their faction while he wears them.
	if(issilicon(victim))
		return FALSE
	if(istype(victim.buckled, /obj/structure/bed))
		return FALSE // Buckled onto furniture counts as being on top of something.
	if(victim.movement_type & MOVETYPES_NOT_TOUCHING_GROUND)
		return FALSE // Flying and floating are not standing.
	return TRUE

/**
 * The ground of one patch tile: the weather "lava" overlay washed LICH_GREEN, drawn at
 * the exact layer/plane pair /datum/weather/floor_is_lava uses so it covers floors and
 * not walls, and people visibly stand ON it. Spawns dim as the telegraph;
 * ignite_patch() animates it to full strength when the burn starts. Self-deleting on
 * the temp_visual timer, so even a leaked cast cleans its own visuals up.
 */
/obj/effect/temp_visual/lich_grave_dirt
	name = "grave-dirt"
	icon = 'icons/effects/weather_effects.dmi'
	icon_state = "lava"
	color = LICH_GREEN
	alpha = 90 // The telegraph wash. Full strength arrives when it ignites.
	layer = ABOVE_OPEN_TURF_LAYER
	plane = FLOOR_PLANE
	randomdir = FALSE // A tiling ground texture; rotating tiles breaks the seams.
	duration = 9 SECONDS // Fallback only; Initialize receives the real telegraph + burn figure.

/obj/effect/temp_visual/lich_grave_dirt/Initialize(mapload, lifetime)
	if(lifetime)
		duration = lifetime
	return ..()

// ===== ILLUSION =====

/**
 * ## Verdigris Reflection
 *
 * Spawns copies of himself around his target and steps into the crowd, so the party has
 * to work out which one is real. `/mob/living/basic/lich/mirror_image` is 1 HP, pops when
 * a living mob examines it, and burns whoever swings at it.
 *
 * ### Deliberate deviation from wizard_mimic
 *
 * `/datum/action/cooldown/spell/pointed/wizard_mimic` deletes all of its clones the
 * moment the caster's health changes (paper_abilities.dm:58, 82-85). Hit the real one
 * and the ruse collapses. That works for a wandering paper wizard, but this ability
 * comes online below 33% health in the middle of a raid, where incoming damage is
 * continuous: the copies would be deleted within a tick of being created, every time.
 * They expire on [image_lifespan] instead. Examining and hitting are still the outs.
 *
 * The images route through the mob's summon registry like everything else he makes, so
 * they are capped with his skeletons and cleaned up when he dies.
 */
/datum/action/cooldown/spell/pointed/lich_mirror_images
	name = "Verdigris Reflection"
	desc = "There is only one of him. Probably."
	button_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "mimic_summon"
	sound = 'sound/effects/magic/smoke.ogg'

	school = SCHOOL_PSYCHIC // No illusion school exists in code/__DEFINES/magic.dm.
	cooldown_time = 20 SECONDS
	invocation = "WHICH OF ME WERE YOU HITTING?"
	invocation_type = INVOCATION_SHOUT
	spell_requirements = NONE

	cast_range = 7

	/// How many copies he tries to place per cast. Bounded again by his summon cap.
	var/image_count = 3
	/// How long a copy lasts if nobody sees through it.
	var/image_lifespan = 20 SECONDS
	/// Copies from this spell specifically, so they can be cleaned up if it is destroyed.
	var/list/copies = list()

/datum/action/cooldown/spell/pointed/lich_mirror_images/Destroy()
	QDEL_LIST(copies)
	return ..()

/datum/action/cooldown/spell/pointed/lich_mirror_images/is_valid_target(atom/cast_on)
	return isliving(cast_on)

/datum/action/cooldown/spell/pointed/lich_mirror_images/cast(mob/living/cast_on)
	. = ..()
	var/mob/living/basic/lich/ilthuun = owner
	if(!istype(ilthuun))
		return

	var/list/directions = GLOB.alldirs.Copy()
	var/placed = 0
	for(var/i in 1 to image_count)
		if(!length(directions) || !ilthuun.can_summon_more())
			break
		var/turf/spot = get_step(cast_on, pick_n_take(directions))
		if(isnull(spot) || spot.is_blocked_turf(exclude_mobs = TRUE))
			continue
		var/mob/living/basic/lich/mirror_image/copy = new(spot)
		ilthuun.register_summon(copy)
		copies += copy
		RegisterSignals(copy, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH), PROC_REF(lost_copy))
		QDEL_IN(copy, image_lifespan)
		placed++

	if(!placed)
		return

	// He hides among them. Same trick as paper_abilities.dm:74, but bounded to his leash,
	// which the paper wizard has no equivalent of.
	//
	// This swap is a forceMove onto a tile up to cast_range + 1 away from him, and a
	// forceMove is invisible to /datum/component/leash: it only re-checks distance when its
	// ANCHOR moves (leash.dm:63), never when the leashed mob does. Land him outside the
	// radius and its pre-move handler then blocks every step whose destination is still
	// outside (leash.dm:97-103). From out there that is the first step back, so he stands
	// frozen in a corridor for the rest of a round whose interior never unloads. Vetting the
	// landing turf first is the fix; recall_home() on the mob is the net under it.
	for(var/direction in shuffle(directions))
		var/turf/hiding_spot = get_step(cast_on, direction)
		if(isnull(hiding_spot) || hiding_spot.is_blocked_turf(exclude_mobs = TRUE))
			continue
		if(ilthuun.is_outside_lair(hiding_spot))
			continue
		new /obj/effect/temp_visual/small_smoke/halfsecond(get_turf(ilthuun))
		ilthuun.forceMove(hiding_spot)
		break

/datum/action/cooldown/spell/pointed/lich_mirror_images/proc/lost_copy(mob/living/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH))
	copies -= source

// ===== CORRUPTION =====

/**
 * ## Wear Them
 *
 * The mind-control spell. All of the mechanics, the guardrails and the attribution live
 * on `/datum/status_effect/lich_thrall` in lich_thrall.dm; this is just the delivery.
 *
 * `antimagic_flags` includes `MAGIC_RESISTANCE_MIND` because this is a mind-affecting
 * spell, the same call `/datum/action/cooldown/spell/pointed/dominate` makes
 * (spell_types/pointed/dominate.dm:17). Anyone carrying mind-affecting antimagic shrugs
 * it off and is told so.
 *
 * [thrall_type] and [on_thrall_applied] exist because this delivery chain is shared with
 * the verdigris bridle (lich_loot.dm), the player-wielded version of the same possession:
 * the bridle swaps in the shorter-duration status effect and spends one of its charges on
 * a landed possession, and inherits the targeting, the range check, the antimagic
 * propagation and the eligibility gate from here without copying any of it.
 */
/datum/action/cooldown/spell/pointed/lich_corruption
	name = "Wear Them"
	desc = "Takes hold of one living mind and drives it at its own friends."
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "dominate"
	sound = 'sound/effects/magic/curse.ogg'

	school = SCHOOL_PSYCHIC
	cooldown_time = 35 SECONDS
	invocation = "HOLD STILL. I ONLY NEED THE HANDS."
	invocation_type = INVOCATION_SHOUT
	spell_requirements = NONE
	antimagic_flags = MAGIC_RESISTANCE|MAGIC_RESISTANCE_MIND

	cast_range = 7

	/// The possession this delivers. Subtyped, not retuned in place, see lich_loot.dm.
	var/thrall_type = /datum/status_effect/lich_thrall

/// `..()` first for the pointed spell's own "not on yourself" rejection. It never fires for
/// Ilthuun: `can_be_lich_thralled` already refuses anything in FACTION_LICH, himself
/// included, but the bridle's wielder is not in his faction, and a player must not be able
/// to click the bridle onto their own head.
/datum/action/cooldown/spell/pointed/lich_corruption/is_valid_target(atom/cast_on)
	. = ..()
	if(!.)
		return FALSE
	return can_be_lich_thralled(cast_on) // defined in lich_thrall.dm

/datum/action/cooldown/spell/pointed/lich_corruption/cast(mob/living/cast_on)
	. = ..()
	if(!isliving(cast_on))
		return

	if(cast_on.can_block_magic(antimagic_flags))
		cast_on.visible_message(
			span_warning("Something green gropes at [cast_on] and finds nothing to hold."),
			span_notice("Something cold reaches into your head, fumbles, and lets go."),
		)
		return

	var/turf/victim_turf = get_turf(cast_on)
	if(victim_turf)
		new /obj/effect/temp_visual/circle_wave/verdigris(victim_turf)
	// apply_status_effect returns the instance, or null if on_apply refused it (the third
	// and last eligibility check), so this is the honest "did the possession land" answer.
	var/datum/status_effect/lich_thrall/possession = cast_on.apply_status_effect(thrall_type, owner)
	if(possession)
		on_thrall_applied(cast_on, possession)

/// Hook for a caster that pays something per landed possession. Ilthuun pays nothing; the
/// bridle spends a charge. Deliberately not called on a whiffed or refused cast.
/datum/action/cooldown/spell/pointed/lich_corruption/proc/on_thrall_applied(mob/living/victim, datum/status_effect/lich_thrall/possession)
	return

// ===== PROJECTILES =====

/**
 * The volley's missile. Green, and it hits noticeably harder than the wizard version,
 * but upstream's paralyze (6 seconds) is gone entirely, traded for a knockdown of the
 * same length we used to paralyze for. A paralyze is a cutscene: the volley marks up
 * to five people at once, and five simultaneous paralyzes chaining into his melee and
 * bolts was the "stunlocked, instant death" half of the playtest report. A knockdown
 * floors you but leaves your input alive -- you can crawl off the kill tile, keep
 * shooting from the ground, and a friend can drag you -- so eating the volley is a
 * position you dig out of rather than a death sentence, while whiffing your dodge
 * still costs real tempo.
 *
 * The armor slope (here and on the bolt below) overrides /obj/projectile/magic's
 * armour_penetration = 100 / armor_flag = NONE, which made every suit of armor in the
 * game cosmetic against him. Both bolts deal BURN, so ENERGY is the honest armor slot
 * (there is no magic armor flag in this codebase, see code/__DEFINES/combat.dm). The
 * 35 AP figure is a pre-playtest guess: hardsuit-tier armor should blunt him
 * noticeably, not blank him.
 */
/obj/projectile/magic/aoe/magic_missile/verdigris
	name = "ossuary shard"
	color = LICH_GREEN
	damage = 18
	damage_type = BURN
	armor_flag = ENERGY
	armour_penetration = 35 // Pre-playtest guess, see above.
	paralyze = 0 // Overrides the parent's 6 seconds. Never bring it back, see above.
	knockdown = 3 SECONDS

/**
 * His fast bolt.
 *
 * Subtypes `/obj/projectile/magic` rather than `/obj/projectile/magic/necropotence`, and
 * borrows only the sprite. See the deviation note in this file's header: necropotence's
 * `on_hit` soul-taps the victim's maxHealth away permanently, which is not an acceptable
 * cost to attach to a boss ability the crew will eat a dozen of per attempt.
 *
 * Same armor slope as the missile, same rationale, see the comment above it: 3x22
 * unmitigable burn per cast was the other half of the no-antimagic death spiral.
 */
/obj/projectile/magic/verdigris_necropotence
	name = "bolt of necropotence"
	icon_state = "necropotence"
	color = LICH_GREEN
	damage = 22
	damage_type = BURN
	armor_flag = ENERGY
	armour_penetration = 35 // Pre-playtest guess, matching the missile.
	speed = 1.4

/obj/projectile/magic/verdigris_necropotence/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(!isliving(target))
		return
	var/mob/living/victim = target
	// Negative energy: it feeds his own kind and rots everyone else.
	if(victim.mob_biotypes & MOB_UNDEAD)
		// forced, because damage_coeff is armour and this is a heal: without it an
		// armoured undead (templar, damage_coeff = list(BRUTE = 0.5, ...)) would be
		// worse at accepting the mend than a plain skeleton. Same reason as
		// mend_the_dead() in lich_spells.dm.
		victim.heal_overall_damage(brute = 10, burn = 10, forced = TRUE)
		return
	victim.adjustToxLoss(8, forced = TRUE)
	to_chat(victim, span_danger("Something starts rotting where the bolt went in."))

#undef VERDIGRIS_TINT
#undef LICH_PHASE_CONJURATION
#undef LICH_PHASE_DESTRUCTION
#undef LICH_PHASE_ILLUSION
#undef BB_LICH_RAISE_DEAD
#undef BB_LICH_BONE_VOLLEY
#undef BB_LICH_NECROTIC_BOLT
#undef BB_LICH_GRAVE_DIRT
#undef BB_LICH_MIRROR_IMAGES
#undef BB_LICH_CORRUPTION
