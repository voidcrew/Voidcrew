/**
 * # The Hoarfrost Matriarch
 *
 * The first entry in a new content tier: **scaled-down megafauna**. A
 * multi-ability, two-phase boss built on the drake's architecture at a size
 * that fits on a planet, delivered by the Big Game Hunt mission on Frozen
 * worlds.
 *
 * She keeps the megafauna pattern wholesale - a weighted attack rotation that
 * never repeats the last move (see hoarfrost_ai.dm), an HP-threshold phase flip
 * that upgrades the kit, chained combos, and an anti-cheese clause - and drops
 * the parts that do not scale down: no reinforced-wall smashing, no HUGE mob
 * size, no permanent terrain damage. Her chunks melt; her rime sublimates.
 *
 * She is deliberately **not** `/mob/living/basic/boss` and deliberately not
 * megafauna. `code/modules/unit_tests/voidcrew_loot.dm` bans both tiers from
 * every zone and guard table, so subtyping either would make her unplaceable -
 * and the boss tier drags in MOB_SIZE_HUGE, reinforced-wall tearing and
 * spacewalk, none of which this tier wants. She does smash ordinary walls -
 * ENVIRONMENT_SMASH_WALLS, below the RWALLS tier - so a door cannot cheese her.
 *
 * Faction is FACTION_MINING and must stay that way: Big Game Hunt spawns her
 * with a wolf/ice-whelp entourage, and a faction mismatch would have them
 * infight instead of fight you.
 *
 * The kit lives in hoarfrost_abilities.dm, the objects it puts on the floor in
 * hoarfrost_objects.dm, the rotation in hoarfrost_ai.dm and the drops in
 * hoarfrost_loot.dm.
 *
 * Sprite is original 64x64 art in voidcrew/icons/mob/icemoon/hoarfrost.dmi - she
 * does not share a sheet with the 32x32 icemoon fauna because a 64x64 state
 * cannot live in a 32x32 DMI. Being double-tile, she needs pixel_x =
 * base_pixel_x = -16 to sit centred on her turf. No `color` tint: the palette is
 * painted into the art, unlike the polarbear/warbear elites she stands beside.
 */

/// Filter key for the frost outline she wears after the Calving.
#define HOARFROST_CALVING_FILTER "hoarfrost_calving"

/mob/living/basic/hoarfrost_matriarch
	name = "hoarfrost matriarch"
	desc = "A huge white predator, built like a bear and about twice the size of one. Frost pours off her in a haze, and the ground she walks on stays white."
	icon = 'voidcrew/icons/mob/icemoon/hoarfrost.dmi'
	icon_state = "hoarfrost_matriarch"
	icon_living = "hoarfrost_matriarch"
	icon_dead = "hoarfrost_matriarch_dead"
	pixel_x = -16
	base_pixel_x = -16
	mouse_opacity = MOUSE_OPACITY_ICON

	maxHealth = 800
	health = 800
	melee_damage_lower = 25
	melee_damage_upper = 30
	armour_penetration = 20
	obj_damage = 60
	// Mild fire weakness: rewards bringing it, never gates the fight on it.
	damage_coeff = list(BRUTE = 1, BURN = 1.2, TOX = 1, STAMINA = 0, OXY = 1)

	// Slow enough that a player can always break contact and reset - every
	// attack is meant to have a clean, learnable dodge, and none of that works
	// if she can simply run you down.
	speed = 3
	combat_mode = TRUE
	status_flags = NONE
	mob_size = MOB_SIZE_LARGE
	mob_biotypes = MOB_ORGANIC|MOB_BEAST|MOB_MINING
	faction = list(FACTION_MINING)
	environment_smash = ENVIRONMENT_SMASH_WALLS
	move_force = MOVE_FORCE_VERY_STRONG
	move_resist = MOVE_FORCE_VERY_STRONG
	pull_force = MOVE_FORCE_VERY_STRONG

	unsuitable_atmos_damage = 0
	minimum_survivable_temperature = 0
	maximum_survivable_temperature = INFINITY
	lighting_cutoff_red = 20
	lighting_cutoff_green = 25
	lighting_cutoff_blue = 35

	speak_emote = list("bellows")
	attack_verb_continuous = "mauls"
	attack_verb_simple = "maul"
	attack_sound = 'sound/items/weapons/punch1.ogg'
	attack_vis_effect = ATTACK_EFFECT_CLAW
	death_message = "settles into the ice with a sound like a calving glacier."
	death_sound = 'sound/effects/magic/demon_dies.ogg'

	butcher_results = list(
		/obj/item/food/meat/slab/bear = 3,
		/obj/item/stack/sheet/bone = 6,
		/obj/item/stack/sheet/sinew = 4,
	)

	ai_controller = /datum/ai_controller/basic_controller/hoarfrost_matriarch

	/// Rimebreath - the cone.
	var/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/rimebreath
	/// Killing Cold - the inverted field. Her signature.
	var/datum/action/cooldown/mob_cooldown/hoarfrost_killing_cold/killing_cold
	/// Avalanche - the gapped ring of ice.
	var/datum/action/cooldown/mob_cooldown/hoarfrost_avalanche/avalanche

	/// TRUE once the Calving has fired. One-way.
	var/calved = FALSE
	/// Fraction of max HP at or below which the Calving triggers.
	var/calving_threshold = 0.5
	/// Every cooldown is multiplied by this at the Calving.
	var/calving_cooldown_scale = 0.75

	/// TRUE while she is planted for Killing Cold: no movement, no melee, no
	/// casting. This is what makes standing next to her genuinely safe.
	var/inert = FALSE

	/// Killing Cold is blocked until this expires. Started by every Rimebreath.
	COOLDOWN_DECLARE(rimebreath_lockout)

	/// Restarted every tick she can see and reach her quarry; once it expires
	/// she starts healing. See [proc/handle_disengagement].
	COOLDOWN_DECLARE(disengage_timer)
	/// How long she tolerates losing her quarry before she starts closing up.
	var/disengage_grace = 10 SECONDS
	/// Beyond this, or with line of sight broken, she counts as disengaged.
	var/disengage_range = 14
	/// Fraction of max HP regained per second while disengaged.
	var/disengage_regen = 0.04

	/// Percent chance a landed swipe becomes a full maul instead.
	var/maul_chance = 20
	/// Tiles a mauled target is thrown, straight away from her.
	var/maul_throw_distance = 3
	/// How long a mauled target stays down.
	var/maul_knockdown = 1.5 SECONDS

	/// Sheets of hide dropped on death. The kill is always worth something.
	var/hide_dropped = 6
	/// The jackpot pool. Both entries hand the player a piece of her kit.
	var/static/list/jackpot_pool = list(
		/obj/item/matriarchs_heart,
		/obj/item/rimebreath_horn,
	)

/mob/living/basic/hoarfrost_matriarch/Initialize(mapload)
	. = ..()
	add_traits(list(
		TRAIT_LAVA_IMMUNE,
		TRAIT_ASHSTORM_IMMUNE,
		TRAIT_SNOWSTORM_IMMUNE,
		// Her own field and her own rime do not touch her - the cold is hers.
		TRAIT_RESISTCOLD,
	), INNATE_TRAIT)

	AddElement(/datum/element/wall_smasher, ENVIRONMENT_SMASH_WALLS)
	AddElement(/datum/element/footstep, FOOTSTEP_MOB_HEAVY)
	AddElement(/datum/element/relay_attackers)
	AddElement(/datum/element/ai_retaliate)
	AddElement(/datum/element/mob_killed_tally, "mobs_killed_mining")
	AddElement(\
		/datum/element/change_force_on_death,\
		move_force = MOVE_FORCE_DEFAULT,\
		move_resist = MOVE_RESIST_DEFAULT,\
		pull_force = PULL_FORCE_DEFAULT,\
	)
	// Crusher convention for the tier: bring the crusher, earn the fang.
	AddElement(\
		/datum/element/crusher_loot,\
		trophy_type = /obj/item/crusher_trophy/rime_fang,\
		drop_mod = 100,\
		drop_immediately = TRUE,\
	)

	rimebreath = new(src)
	killing_cold = new(src)
	avalanche = new(src)
	rimebreath.Grant(src)
	killing_cold.Grant(src)
	avalanche.Grant(src)

	// The controller is built during /atom/Initialize, i.e. before any of the
	// above existed, so the kit has to be handed over now.
	var/datum/ai_controller/basic_controller/hoarfrost_matriarch/brain = ai_controller
	if(istype(brain))
		brain.register_kit(rimebreath, killing_cold, avalanche)

	RegisterSignal(src, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(on_swipe_landed))

	COOLDOWN_START(src, disengage_timer, disengage_grace)

/mob/living/basic/hoarfrost_matriarch/Destroy()
	rimebreath = null
	killing_cold = null
	avalanche = null
	return ..()

// =========================================================================
// PHASE TWO - THE CALVING
// =========================================================================

/mob/living/basic/hoarfrost_matriarch/adjust_health(amount, updating_health = TRUE, forced = FALSE)
	. = ..()
	if(calved || stat == DEAD)
		return
	// Read bruteloss rather than health: health is only recomputed when
	// updating_health is set, and this can be called without it.
	if(bruteloss < maxHealth * (1 - calving_threshold))
		return
	begin_calving()

/**
 * Half health. She sheds a layer and stops pacing herself: cooldowns drop by a
 * quarter, Rimebreath starts doubling up, and Avalanche chains straight into
 * Killing Cold. One-time, with a real beat to it.
 */
/mob/living/basic/hoarfrost_matriarch/proc/begin_calving()
	if(calved)
		return
	calved = TRUE

	visible_message(span_boldwarning("[src] throws [p_their()] head back and BELLOWS! Sheets of ice slough off [p_them()], and the cold gets worse."))
	playsound(src, 'sound/mobs/non-humanoids/space_dragon/space_dragon_roar.ogg', 110, TRUE)
	new /obj/effect/temp_visual/circle_wave/hoarfrost(get_turf(src))
	for(var/mob/living/witness in view(7, src))
		shake_camera(witness, 4, 2)

	add_filter(HOARFROST_CALVING_FILTER, 2, list("type" = "outline", "color" = COLOR_BLUE_LIGHT, "size" = 1))

	for(var/datum/action/cooldown/ability as anything in list(rimebreath, killing_cold, avalanche))
		if(isnull(ability))
			continue
		ability.cooldown_time = round(ability.cooldown_time * calving_cooldown_scale, 0.1)

/**
 * Called by Avalanche the moment its ring lands.
 *
 * After the Calving the ring is immediately followed by Killing Cold, so the
 * safe zone you now have to reach is partly walled off - break through the ice
 * or path around it, on a timer. Two simple abilities compounding into a hard
 * question, the same way the drake's swoop chains into cone and meteors.
 */
/mob/living/basic/hoarfrost_matriarch/proc/on_avalanche_landed()
	if(!calved || inert || stat != CONSCIOUS)
		return
	if(!killing_cold?.IsAvailable())
		return
	killing_cold.Trigger()

// =========================================================================
// PLANTED
// =========================================================================

/**
 * Plant or unplant her for a Killing Cold cast. While planted she cannot move,
 * cannot swing and cannot cast - the AI rotation checks this too. The whole
 * demand of the ability is getting into melee range and holding there, which
 * only works if melee range is actually safe.
 */
/mob/living/basic/hoarfrost_matriarch/proc/set_inert(planted)
	if(inert == planted)
		return
	inert = planted
	if(planted)
		ADD_TRAIT(src, TRAIT_IMMOBILIZED, MEGAFAUNA_TRAIT)
		ai_controller?.CancelActions()
		return
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, MEGAFAUNA_TRAIT)

/mob/living/basic/hoarfrost_matriarch/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	if(inert)
		return FALSE
	return ..()

// =========================================================================
// THE MAUL
// =========================================================================

/**
 * Occasionally a swipe lands as a full shoulder-check instead: knocked flat and
 * thrown clear of her.
 *
 * `/datum/element/knockback` does most of this already but its Attach() gates on
 * ishostile(), which is false for the basic-mob line, so it can never attach here.
 * `melee_attack()` still fires COMSIG_HOSTILE_POST_ATTACKINGTARGET (basic.dm:236),
 * so we hang off the same signal the element would have used.
 *
 * The throw is what makes this more than flavour: it moves you AWAY from her, and
 * her safe ground is the two tiles nearest her. Eating a maul while Killing Cold is
 * winding up is the worst thing that can happen to you in the fight, which is the
 * intent - but she cannot melee at all while planted, so it can never fire *during*
 * the field itself. The danger is the timing, not an unavoidable coin flip.
 */
/mob/living/basic/hoarfrost_matriarch/proc/on_swipe_landed(mob/living/attacker, atom/target, success)
	SIGNAL_HANDLER
	if(!success || !isliving(target))
		return
	if(!prob(maul_chance))
		return
	INVOKE_ASYNC(src, PROC_REF(maul), target)

/// Knock a target flat and throw them clear.
/mob/living/basic/hoarfrost_matriarch/proc/maul(mob/living/victim)
	if(QDELETED(victim) || victim.stat == DEAD)
		return
	victim.visible_message(
		span_boldwarning("[src] catches [victim] with a shoulder and sends [victim.p_them()] sprawling!"),
		span_userdanger("[src] hits you like a falling wall and knocks you off your feet!"),
	)
	playsound(src, 'sound/effects/gravhit.ogg', 75, TRUE)
	victim.Knockdown(maul_knockdown)
	var/throw_dir = get_dir(src, victim)
	if(!throw_dir) // standing on the same tile somehow - shove them anywhere
		throw_dir = pick(GLOB.cardinals)
	var/atom/landing = get_edge_target_turf(victim, throw_dir)
	victim.safe_throw_at(landing, maul_throw_distance, 1, src)

// =========================================================================
// ANTI-CHEESE
// =========================================================================

/mob/living/basic/hoarfrost_matriarch/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(stat == DEAD)
		return
	handle_disengagement(seconds_per_tick)

/**
 * Kite-and-plink and door-cheese killer, in the same spirit as the drake's
 * arena-escape enrage. If she cannot see or reach her quarry for
 * [disengage_grace], she starts closing up at [disengage_regen] of her max HP
 * per second until someone re-engages. No hard arena lock, no teleport - just
 * a hard floor under "fight her properly".
 */
/mob/living/basic/hoarfrost_matriarch/proc/handle_disengagement(seconds_per_tick)
	var/atom/quarry
	if(ai_controller)
		quarry = ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(is_engaged(quarry))
		COOLDOWN_START(src, disengage_timer, disengage_grace)
		return
	if(!COOLDOWN_FINISHED(src, disengage_timer) || bruteloss <= 0)
		return
	adjust_health(-(maxHealth * disengage_regen * seconds_per_tick))
	if(SPT_PROB(20, seconds_per_tick))
		visible_message(span_boldwarning("[src]'s wounds crust over with fresh ice."))

/// Is this quarry close enough, alive enough and visible enough to count?
/mob/living/basic/hoarfrost_matriarch/proc/is_engaged(atom/quarry)
	if(QDELETED(quarry))
		return FALSE
	if(isliving(quarry))
		var/mob/living/living_quarry = quarry
		if(living_quarry.stat == DEAD)
			return FALSE
	if(get_dist(src, quarry) > disengage_range)
		return FALSE
	return can_see(src, quarry, disengage_range)

// =========================================================================
// DEATH
// =========================================================================

/mob/living/basic/hoarfrost_matriarch/death(gibbed)
	remove_filter(HOARFROST_CALVING_FILTER)
	. = ..()
	if(gibbed)
		return
	drop_the_glacier()

/**
 * The drops.
 *
 * The hide is guaranteed, so the kill is always worth something even on a bad
 * roll, and it crafts into the rimeward cloak the same way ashdrake hide crafts
 * into the ash cloak. The jackpot rolls from a two-entry pool and both entries
 * hand the player a piece of her own kit - the best boss loot is the boss.
 *
 * The rime fang is handled separately by the crusher_loot element in
 * Initialize, per the existing elite trophy convention.
 */
/mob/living/basic/hoarfrost_matriarch/proc/drop_the_glacier()
	var/atom/spot = drop_location()
	if(isnull(spot))
		return
	new /obj/item/stack/sheet/animalhide/hoarfrost(spot, hide_dropped)
	var/jackpot_type = pick(jackpot_pool)
	new jackpot_type(spot)
	visible_message(span_boldnotice("Something inside [src] cracks loose as [p_they()] settle[p_s()] into the ice."))

#undef HOARFROST_CALVING_FILTER
