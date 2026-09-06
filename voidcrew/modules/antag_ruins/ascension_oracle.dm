/**
 * # The Ancient Oracle, and the Voice of the Word
 *
 * The wizard vestige's capstone (see ascension.dm for the framework, and
 * theme_wizard.dm for the Magister who hands it out). One supplicant walks into
 * The Last Recitation on their own, kills the thing reciting down there, and
 * walks out able to talk a whole room off its feet.
 *
 * ## The boss
 *
 * The Oracle predates the Magister by a long way. It has been working through
 * the same six lines of the Athenaeum liturgy for about four centuries and it
 * still has not got them right, which is why the Magister's own primer
 * (theme_wizard.dm) reads like a bad copy of a bad copy.
 *
 * Its whole kit is words: it says a thing and the player's body does it. That is
 * deliberately the same trick as the capstone the player is fighting to take, so
 * the fight teaches the reward.
 *
 * - **The Word of Falling**: say DOWN, and 1.5 seconds later everything that
 *   can still see it goes down. *Counter: break line of sight.*
 * - **The Antiphon**: burn a line of the verse into the floor along all four
 *   axes (eight after the Stammer). *Counter: get off the axis.*
 * - **The Called Word**: call you by a name close enough to yours and your feet
 *   walk you in. *Counter: break line of sight, or fight while you are dragged.*
 * - **The Last Line** (phase two): it plants and recites the finish. If it gets
 *   there the room is on fire. *Counter: deal 200 damage to it inside the
 *   window, and it loses the line and sags.* That is the Magister's advice
 *   (`departure_line`: "Don't listen to it. Talk over it.") as a mechanic.
 *
 * Solo-tuned: 1500 HP against exactly one player, slow enough that contact can
 * always be broken, and an anti-cheese regen clause lifted from the Hoarfrost
 * Matriarch so that hiding behind a Word of Denial and plinking loses ground.
 *
 * It is deliberately **not** `/mob/living/basic/boss` and not megafauna.
 * `code/modules/unit_tests/voidcrew_loot.dm` text-scans every ruin .dmm and
 * hard-fails any map carrying either string outside a legacy whitelist. The stat
 * block below is hand-copied from that tier; the inheritance is not.
 *
 * ## The capstone
 *
 * `Voice of the Word` is Voice of God with the safety rails taken off: line of
 * sight instead of hearing, no deafness or antimagic check on the listener
 * gather, eight times the power, and a flat three minutes between shouts no
 * matter which order was given.
 *
 * It does NOT subtype `/datum/action/cooldown/spell/voice_of_god`, because that
 * type's `cast()` calls `voice_of_god()` unconditionally and DM has no way to
 * skip an immediate parent. Subtyping it would fire both dispatchers. The
 * fifteen lines of action shell are copied instead; the command roster is not.
 *
 * The three new commands are real `/datum/voice_of_god_command` subtypes, so
 * they land in `GLOB.voice_of_god_commands` and any Voice of God can reach them.
 * Their numbers are all multiplied by the power multiplier, so at base VoG power
 * they are minor and at capstone power they end fights. The frenzy is gated
 * harder than that, see [/datum/voice_of_god_command/frenzy].
 */

// ===== BOSS TUNING =====
// Ability descs quote these numbers literally: initial values have to be
// constant expressions, so a define cannot be interpolated into a string.
// Keep the two in sync by hand.

/// Fraction of max HP at or below which the Stammer fires.
#define ORACLE_STAMMER_THRESHOLD 0.5
/// Every cooldown is multiplied by this at the Stammer.
#define ORACLE_STAMMER_COOLDOWN_SCALE 0.75
/// How long it tolerates losing its quarry before it starts closing up.
#define ORACLE_DISENGAGE_GRACE (10 SECONDS)
/// Beyond this, or with line of sight broken, it counts as disengaged.
#define ORACLE_DISENGAGE_RANGE 12
/// Fraction of max HP regained per second while disengaged.
#define ORACLE_DISENGAGE_REGEN 0.035
/// Filter key for the outline it wears after the Stammer.
#define ORACLE_STAMMER_FILTER "vestige_oracle_stammer"
/// Trait source for anything the Oracle puts on itself.
#define ORACLE_TRAIT "vestige_oracle"
/// The palette. Matches the Magister's own tint in theme_wizard.dm.
#define ORACLE_VIOLET "#9a7bc8"

// Blackboard keys for its kit. Confined to this file, like hoarfrost_ai.dm's.
#define BB_ORACLE_WORD_OF_FALLING "BB_oracle_word_of_falling"
#define BB_ORACLE_ANTIPHON "BB_oracle_antiphon"
#define BB_ORACLE_CALLED_WORD "BB_oracle_called_word"
#define BB_ORACLE_LAST_LINE "BB_oracle_last_line"
/// Key of the last ability used, excluded from the next roll.
#define BB_ORACLE_LAST_ABILITY "BB_oracle_last_ability"

// ===== CAPSTONE TUNING =====

/// Power multiplier Voice of the Word speaks at. Base Voice of God is 1.
#define WORD_POWER_MULTIPLIER 8
/**
 * How long between shouts, whatever was shouted.
 *
 * One number for every order, rather than Voice of God's per-command cooldowns
 * scaled up: those ran from 90 seconds to six minutes here, which meant the
 * button's own tooltip could not tell you what you were about to spend, and the
 * player found out by watching the timer afterwards.
 *
 * Three minutes specifically, because `COOLDOWN_NO_DISPLAY_TIME` in
 * cooldown_action.dm blanks the countdown maptext while more than 180 seconds
 * remain. At exactly three minutes the number is on the button for all but the
 * first tick; any longer and the button would sit blank for the difference.
 */
#define WORD_COOLDOWN (3 MINUTES)
/// How far the word carries, in tiles of line of sight.
#define WORD_RANGE 9
/// Power at or above which "turn on each other" is real possession rather than
/// a fright. Base Voice of God tops out at 4 (cultist, single target).
#define WORD_FRENZY_POWER_GATE 6
/// How long a frenzy lasts.
#define WORD_FRENZY_DURATION (20 SECONDS)
/// Filter key for the violet outline a frenzied mob wears.
#define WORD_FRENZY_FILTER "voice_of_the_word_frenzy"
/// How far a frenzied mob looks for somebody to hit.
#define WORD_FRENZY_SIGHT 7

// =========================================================================
// SHARED
// =========================================================================

/**
 * Is this victim on the speaker's side, and therefore spared?
 *
 * The caster's own faction, minus "neutral", the same trick the rimebreath horn
 * plays (hoarfrost_loot.dm), because plain humans are FACTION_NEUTRAL and a
 * player firing the Oracle's slate would otherwise spare every other person
 * alive. The speaker themselves is always spared.
 */
/proc/oracle_word_spares(mob/living/victim, mob/living/caster)
	if(victim == caster)
		return TRUE
	if(!isliving(caster) || !length(caster.faction))
		return FALSE
	var/list/sides = caster.faction - FACTION_NEUTRAL
	if(!length(sides))
		return FALSE
	return faction_check(victim.faction, sides)

// =========================================================================
// THE ANCIENT ORACLE
// =========================================================================

/mob/living/basic/vestige_oracle
	name = "the Ancient Oracle"
	desc = "A tall figure in a stone hood, worn smooth where a face should be. Its mouth never stops moving, and it keeps starting the same line over."
	gender = NEUTER

	icon = 'voidcrew/modules/antag_ruins/icons/oracle.dmi'
	icon_state = "oracle"
	icon_living = "oracle"
	icon_dead = "oracle_dead"
	mouse_opacity = MOUSE_OPACITY_ICON

	// Hoarfrost/lich tier, hand-copied, then tuned down for one player. See the
	// file header for why none of it is inherited.
	maxHealth = 1500
	health = 1500
	melee_damage_lower = 18
	melee_damage_upper = 26
	armour_penetration = 25
	melee_attack_cooldown = 1.6 SECONDS
	obj_damage = 30
	// Slow on purpose. Every word it says has a clean dodge, and none of those
	// dodges work against something that can simply run a player down.
	speed = 3
	combat_mode = TRUE
	status_flags = NONE
	mob_size = MOB_SIZE_LARGE
	mob_biotypes = MOB_HUMANOID|MOB_MINERAL
	faction = list(FACTION_HOSTILE)
	// Stone and habit. Nothing in it to poison, tire or suffocate.
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0, STAMINA = 0, OXY = 0)
	move_force = MOVE_FORCE_VERY_STRONG
	move_resist = MOVE_FORCE_VERY_STRONG
	pull_force = MOVE_FORCE_VERY_STRONG

	// The arena is authored geometry and the fight is supposed to happen inside
	// it, not through it.
	environment_smash = ENVIRONMENT_SMASH_NONE
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	lighting_cutoff_red = 25
	lighting_cutoff_green = 15
	lighting_cutoff_blue = 35

	speak_emote = list("recites")
	attack_verb_continuous = "backhands"
	attack_verb_simple = "backhand"
	attack_sound = 'sound/effects/magic/demon_attack1.ogg'
	attack_vis_effect = ATTACK_EFFECT_PUNCH
	death_message = "stops talking, and goes down in a heap of grey cloth."
	death_sound = 'sound/effects/magic/demon_dies.ogg'

	ai_controller = /datum/ai_controller/basic_controller/vestige_oracle

	/// The Word of Falling: the line-of-sight knockdown.
	var/datum/action/cooldown/mob_cooldown/oracle_word/word_of_falling/word_of_falling
	/// The Antiphon: the burning axes.
	var/datum/action/cooldown/mob_cooldown/oracle_word/antiphon/antiphon
	/// The Called Word: the drag.
	var/datum/action/cooldown/mob_cooldown/oracle_word/called_word/called_word
	/// The Last Line: phase two only, granted at the Stammer.
	var/datum/action/cooldown/mob_cooldown/oracle_word/last_line/last_line

	/// TRUE once the Stammer has fired. One-way.
	var/stammering = FALSE
	/// Resurrection can restart the body, but this encounter has only one physical loot payment.
	var/loot_dropped = FALSE

	/// TRUE while it is planted for the Last Line: no movement, no melee, no
	/// casting. The whole payout for interrupting is that it stays that way.
	var/inert = FALSE

	/// Nothing else may be said while this is running. Stops two telegraphs
	/// landing on the same tile at the same time, which is not a dodge, it is a
	/// coin flip.
	COOLDOWN_DECLARE(speech_lockout_timer)

	/// Restarted every tick it can see and reach its quarry. See [proc/handle_disengagement].
	COOLDOWN_DECLARE(disengage_timer)

	/// Percent chance a landed backhand also shakes the target's hands open.
	var/letgo_chance = 20

	/// The jackpot pool. Both entries hand the player a piece of its own kit.
	var/static/list/jackpot_pool = list(
		/obj/item/oracle_slate,
		/obj/item/borrowed_name,
	)

	/// What it says to itself between attacks. All of it is the Athenaeum
	/// liturgy the Magister's primer quotes, and all of it is slightly wrong.
	var/static/list/mutterings = list(
		"ILN ASH VERBA. SOMA VESH... SOMA VESH... SOMA VESH ENNA.",
		"OXI ATH'ENNA MORI. VECTA UN'DAL. VECTA UN'DAL RETH.",
		"SIC ITUR AD ASHTA. EX LIBRIS. EX LIBRIS. EX OSSIBUS.",
		"That isn't it.",
		"From the top.",
		"Closer.",
	)

/mob/living/basic/vestige_oracle/Initialize(mapload)
	. = ..()

	AddElement(/datum/element/relay_attackers)
	AddElement(/datum/element/ai_retaliate)

	// A bluespace body bag takes MOB_SIZE_LARGE, so without this the trial's boss can be
	// zipped up and carried out of its own arena (#131).
	ban_from_containment()

	word_of_falling = new(src)
	antiphon = new(src)
	called_word = new(src)
	word_of_falling.Grant(src)
	antiphon.Grant(src)
	called_word.Grant(src)

	// The controller is built during /atom/Initialize, i.e. before any of the
	// above existed, so the kit has to be handed over now.
	var/datum/ai_controller/basic_controller/vestige_oracle/brain = ai_controller
	if(istype(brain))
		brain.register_kit(word_of_falling, antiphon, called_word)

	RegisterSignal(src, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_health_update))
	RegisterSignal(src, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(on_backhand_landed))

	COOLDOWN_START(src, disengage_timer, ORACLE_DISENGAGE_GRACE)

/mob/living/basic/vestige_oracle/Destroy()
	word_of_falling = null
	antiphon = null
	called_word = null
	last_line = null
	return ..()

// ===== PHASE TWO: THE STAMMER =====

/**
 * Watches its own health. Reading the signal rather than overriding
 * `adjust_health` catches every damage path, including the ones that never touch
 * bruteloss.
 */
/mob/living/basic/vestige_oracle/proc/on_health_update(datum/source)
	SIGNAL_HANDLER
	if(stammering || stat == DEAD)
		return
	if(health > maxHealth * ORACLE_STAMMER_THRESHOLD)
		return
	// visible_message, playsound and Grant are not safe from a SIGNAL_HANDLER.
	INVOKE_ASYNC(src, PROC_REF(begin_stammer))

/**
 * Half health. It loses the thread completely: everything comes faster, the
 * Antiphon opens up to all eight directions, the Word of Falling shakes your
 * hands open as well, and it starts trying to finish the verse.
 */
/mob/living/basic/vestige_oracle/proc/begin_stammer()
	if(stammering)
		return
	stammering = TRUE

	visible_message(span_boldwarning("[src] loses its place, drags the verse back to the start, and starts again much faster."))
	say("FROM THE TOP. FROM THE TOP. FROM THE TOP.", spans = list("colossus"), forced = "vestige oracle")
	playsound(src, 'sound/effects/magic/clockwork/invoke_general.ogg', 100, TRUE)
	var/turf/pulpit = get_turf(src)
	if(pulpit)
		new /obj/effect/temp_visual/circle_wave/oracle(pulpit)
	for(var/mob/living/witness in view(7, src))
		shake_camera(witness, 3, 2)

	add_filter(ORACLE_STAMMER_FILTER, 2, list("type" = "outline", "color" = ORACLE_VIOLET, "size" = 1))

	for(var/datum/action/cooldown/ability as anything in list(word_of_falling, antiphon, called_word))
		if(isnull(ability))
			continue
		ability.cooldown_time = round(ability.cooldown_time * ORACLE_STAMMER_COOLDOWN_SCALE, 0.1)

	// The last line only exists in the second half of the fight.
	last_line = new(src)
	last_line.Grant(src)
	var/datum/ai_controller/basic_controller/vestige_oracle/brain = ai_controller
	if(istype(brain))
		brain.set_blackboard_key(BB_ORACLE_LAST_LINE, last_line)

// ===== PLANTED =====

/**
 * Plant or unplant it for the Last Line. While planted it cannot move, swing or
 * cast, the AI rotation checks this too. Standing in front of it during the
 * recital has to be safe, or the interrupt is not a real option.
 */
/mob/living/basic/vestige_oracle/proc/set_inert(planted)
	if(inert == planted)
		return
	inert = planted
	if(planted)
		ADD_TRAIT(src, TRAIT_IMMOBILIZED, ORACLE_TRAIT)
		ai_controller?.CancelActions()
		return
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, ORACLE_TRAIT)

/mob/living/basic/vestige_oracle/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	if(inert)
		return FALSE
	return ..()

// ===== LET GO =====

/**
 * Sometimes the backhand comes with a word attached and the target's hands open.
 *
 * `/datum/element/knockback` would be the obvious tool, but its Attach() gates on
 * ishostile(), which is false for the basic-mob line, so it can never attach
 * here. `melee_attack()` still fires COMSIG_HOSTILE_POST_ATTACKINGTARGET, so we
 * hang off the same signal the element would have used, the Matriarch's maul
 * does exactly this.
 *
 * Dropped, not thrown, and no stun: everything you lose is at your feet. It is a
 * second of your time, not a death sentence.
 */
/mob/living/basic/vestige_oracle/proc/on_backhand_landed(mob/living/attacker, atom/target, success)
	SIGNAL_HANDLER
	if(!success || !isliving(target))
		return
	if(!prob(letgo_chance))
		return
	INVOKE_ASYNC(src, PROC_REF(shake_loose), target)

/mob/living/basic/vestige_oracle/proc/shake_loose(mob/living/victim)
	if(QDELETED(victim) || victim.stat == DEAD)
		return
	// held_items carries a null per empty hand, so length() is not the answer.
	var/holding_anything = FALSE
	for(var/obj/item/held_item as anything in victim.held_items)
		if(isnull(held_item))
			continue
		holding_anything = TRUE
		break
	if(!holding_anything)
		return
	say("LET GO.", spans = list("colossus"), forced = "vestige oracle")
	victim.visible_message(
		span_boldwarning("[victim]'s hands open on their own and everything in them hits the floor."),
		span_userdanger("Your fingers come open without asking you and you drop everything."),
	)
	victim.drop_all_held_items()
	playsound(victim, 'sound/effects/magic/blind.ogg', 45, TRUE)

// ===== ANTI-CHEESE =====

/mob/living/basic/vestige_oracle/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(stat == DEAD)
		return
	handle_disengagement(seconds_per_tick)
	if(!inert && SPT_PROB(3, seconds_per_tick))
		say(pick(mutterings), forced = "vestige oracle")

/**
 * Kite-and-plink killer, straight off the Hoarfrost Matriarch. If it cannot see
 * or reach its quarry for ORACLE_DISENGAGE_GRACE it starts closing up at
 * ORACLE_DISENGAGE_REGEN of its max HP per second until somebody re-engages.
 *
 * This is what stops a supplicant parking behind a Word of Denial (their own
 * wizard boon) and winning the fight one fireball at a time.
 */
/mob/living/basic/vestige_oracle/proc/handle_disengagement(seconds_per_tick)
	var/atom/quarry
	if(ai_controller)
		quarry = ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(is_engaged(quarry))
		COOLDOWN_START(src, disengage_timer, ORACLE_DISENGAGE_GRACE)
		return
	if(!COOLDOWN_FINISHED(src, disengage_timer) || health >= maxHealth)
		return
	adjust_health(-(maxHealth * ORACLE_DISENGAGE_REGEN * seconds_per_tick))
	if(SPT_PROB(20, seconds_per_tick))
		visible_message(span_boldwarning("[src] picks the verse back up where it left off, and the cracks in it close."))

/// Is this quarry close enough, alive enough and visible enough to count?
/mob/living/basic/vestige_oracle/proc/is_engaged(atom/quarry)
	if(QDELETED(quarry))
		return FALSE
	if(isliving(quarry))
		var/mob/living/living_quarry = quarry
		if(living_quarry.stat == DEAD)
			return FALSE
	if(get_dist(src, quarry) > ORACLE_DISENGAGE_RANGE)
		return FALSE
	return can_see(src, quarry, ORACLE_DISENGAGE_RANGE)

// ===== DEATH =====

/mob/living/basic/vestige_oracle/death(gibbed)
	remove_filter(ORACLE_STAMMER_FILTER)
	set_inert(FALSE)
	. = ..()
	if(!. || gibbed)
		return
	drop_the_verse()

/**
 * The drops, on the Matriarch's model: one guaranteed piece so the kill is
 * always worth something, and one jackpot rolled from a two-entry pool where
 * both entries hand the player a piece of the Oracle's own kit.
 *
 * The capstone is the real payout, so the pool deliberately avoids duplicating
 * it, the slate is short-cooldown shaped damage and the token is a lure, and
 * Voice of the Word is neither.
 */
/mob/living/basic/vestige_oracle/proc/drop_the_verse()
	if(loot_dropped)
		return
	var/atom/spot = drop_location()
	if(isnull(spot))
		return
	loot_dropped = TRUE
	new /obj/item/clothing/head/oracle_hood(spot)
	var/jackpot_type = pick(jackpot_pool)
	new jackpot_type(spot)
	visible_message(span_boldnotice("The hood comes apart, and everything it was carrying hits the floor."))

// =========================================================================
// AI
// =========================================================================

/**
 * The megafauna attack rotation in the modern basic-mob framework, copied from
 * hoarfrost_ai.dm: pick one ability at random, never the one used last, drop
 * anything unavailable. Everything else about it is ordinary, it walks up and
 * hits you, which is what makes the telegraphed words read as events.
 */
/datum/ai_controller/basic_controller/vestige_oracle
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_AGGRO_RANGE = 10,
		BB_ORACLE_LAST_ABILITY = null,
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = null
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/oracle_rotation,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree/oracle,
	)

/**
 * Publishes the kit onto the blackboard.
 *
 * Called from Initialize, because the controller is built inside
 * /atom/Initialize (before a single action exists) so the keys cannot be
 * seeded in the `blackboard` list above. The Last Line is deliberately absent:
 * it is registered by [/mob/living/basic/vestige_oracle/proc/begin_stammer], and
 * until then the rotation simply finds a null under its key and skips it.
 */
/// Temporary possession replaces the controller; reconnect the original actions on return.
/datum/ai_controller/basic_controller/vestige_oracle/PossessPawn(atom/new_pawn)
	. = ..()
	var/mob/living/basic/vestige_oracle/oracle = pawn
	if(!istype(oracle))
		return
	register_kit(oracle.word_of_falling, oracle.antiphon, oracle.called_word)
	set_blackboard_key(BB_ORACLE_LAST_LINE, oracle.last_line)

/datum/ai_controller/basic_controller/vestige_oracle/proc/register_kit(
	datum/action/cooldown/word_of_falling,
	datum/action/cooldown/antiphon,
	datum/action/cooldown/called_word,
)
	set_blackboard_key(BB_ORACLE_WORD_OF_FALLING, word_of_falling)
	set_blackboard_key(BB_ORACLE_ANTIPHON, antiphon)
	set_blackboard_key(BB_ORACLE_CALLED_WORD, called_word)

/datum/ai_planning_subtree/oracle_rotation
	/// It will not spend a word on somebody this far away, the Antiphon falls
	/// short and the rest are simply walked out of.
	var/engagement_range = 8

/datum/ai_planning_subtree/oracle_rotation/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/vestige_oracle/oracle = controller.pawn
	if(!istype(oracle))
		return
	if(oracle.inert)
		// Planted for the Last Line. No casting, no swinging, no shuffling.
		return SUBTREE_RETURN_FINISH_PLANNING
	if(oracle.stat != CONSCIOUS)
		return

	var/atom/quarry = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(quarry))
		return
	if(isliving(quarry))
		var/mob/living/living_quarry = quarry
		if(living_quarry.stat == DEAD)
			return
	if(get_dist(oracle, quarry) > engagement_range)
		return

	// Built fresh rather than filtered in place: removing from the list you are
	// iterating skips entries in DM, and the pool is four long anyway.
	var/static/list/kit = list(
		BB_ORACLE_WORD_OF_FALLING,
		BB_ORACLE_ANTIPHON,
		BB_ORACLE_CALLED_WORD,
		BB_ORACLE_LAST_LINE,
	)
	var/last_used = controller.blackboard[BB_ORACLE_LAST_ABILITY]
	var/list/options = list()
	for(var/ability_key as anything in kit)
		if(ability_key == last_used)
			continue
		var/datum/action/cooldown/ability = controller.blackboard[ability_key]
		if(!ability?.IsAvailable())
			continue
		options += ability_key
	if(!length(options))
		return

	var/chosen_key = pick(options)
	controller.set_blackboard_key(BB_ORACLE_LAST_ABILITY, chosen_key)
	controller.queue_behavior(/datum/ai_behavior/targeted_mob_ability, chosen_key, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/// It does not swing while it is planted.
/datum/ai_planning_subtree/basic_melee_attack_subtree/oracle

/datum/ai_planning_subtree/basic_melee_attack_subtree/oracle/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/vestige_oracle/oracle = controller.pawn
	if(istype(oracle) && oracle.inert)
		return
	return ..()

// =========================================================================
// THE KIT
// =========================================================================

/**
 * Shared base for everything the Oracle says.
 *
 * Two rules live here and nowhere else: nothing casts while it is planted for
 * the Last Line, and nothing casts on top of a word still in the air. Without
 * the second rule two telegraphs can land on the same tile in the same second,
 * which is not a dodge, it is a coin flip.
 *
 * The Antiphon subtype below is also handed to a player through the Oracle's
 * slate, so every check here degrades safely when the owner is not the Oracle.
 */
/datum/action/cooldown/mob_cooldown/oracle_word
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "spell_default"
	// Load-bearing, do not "tidy" to FALSE. /datum/action/cooldown/Trigger only
	// forwards a target into PreActivate when click_to_activate is set; with it
	// off it passes the OWNER instead, and the Called Word would call the Oracle
	// to itself. Everything else here ignores the target it is handed.
	click_to_activate = TRUE
	// The rotation picks one word at a time; it must not put the whole kit on
	// cooldown when it does.
	shared_cooldown = NONE
	/// How long this word keeps the Oracle's mouth busy afterwards.
	var/speech_lockout = 3.5 SECONDS

/datum/action/cooldown/mob_cooldown/oracle_word/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/vestige_oracle/oracle = owner
	if(!istype(oracle))
		return TRUE
	if(oracle.inert)
		return FALSE
	return COOLDOWN_FINISHED(oracle, speech_lockout_timer)

/// Called at the top of every Activate. Holds the floor for [speech_lockout].
/datum/action/cooldown/mob_cooldown/oracle_word/proc/hold_the_floor()
	var/mob/living/basic/vestige_oracle/oracle = owner
	if(istype(oracle) && speech_lockout > 0)
		COOLDOWN_START(oracle, speech_lockout_timer, speech_lockout)

/// TRUE if the Oracle is in its second phase. FALSE for anyone else holding this.
/datum/action/cooldown/mob_cooldown/oracle_word/proc/stammering()
	var/mob/living/basic/vestige_oracle/oracle = owner
	return istype(oracle) && oracle.stammering

// ===== THE WORD OF FALLING =====

/**
 * *Break line of sight.* It says DOWN, and everything still looking at it 1.5
 * seconds later goes down. The window is generous and the tell is loud, so this
 * is the ability that teaches a player to use the arena's pillars.
 */
/datum/action/cooldown/mob_cooldown/oracle_word/word_of_falling
	name = "The Word of Falling"
	// Keep these numbers in sync with the vars below.
	desc = "Say DOWN. Anything that can still see you 1.5 seconds later is knocked flat for 3 seconds and takes 15 brute. Breaking line of sight before it lands avoids it entirely."
	button_icon_state = "repulse"
	cooldown_time = 20 SECONDS
	/// How long between the word and the fall.
	var/windup = 1.5 SECONDS
	/// How far the word reaches.
	var/word_range = 7
	/// How long a target stays down.
	var/knockdown_time = 3 SECONDS
	/// How long a target stays down after the Stammer.
	var/stammer_knockdown_time = 4 SECONDS
	/// Brute dealt on landing.
	var/impact_damage = 15

/datum/action/cooldown/mob_cooldown/oracle_word/word_of_falling/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	StartCooldown()
	hold_the_floor()
	owner.visible_message(span_boldwarning("[owner] stops mid-verse, picks a different word, and holds it."))
	owner.balloon_alert_to_viewers("the word of falling!")
	owner.say("DOWN.", spans = list("colossus"), forced = "vestige oracle")
	playsound(owner, 'sound/effects/magic/clockwork/invoke_general.ogg', 75, TRUE)
	owner.Shake(pixelshiftx = 1, pixelshifty = 0, duration = windup)
	addtimer(CALLBACK(src, PROC_REF(land)), windup)
	return TRUE

/datum/action/cooldown/mob_cooldown/oracle_word/word_of_falling/proc/land()
	var/mob/living/caster = owner
	if(QDELETED(caster) || caster.stat == DEAD)
		return
	var/turf/pulpit = get_turf(caster)
	if(isnull(pulpit))
		return

	playsound(pulpit, 'sound/effects/magic/repulse.ogg', 85, TRUE)
	new /obj/effect/temp_visual/circle_wave/oracle(pulpit)

	var/floored = stammering() ? stammer_knockdown_time : knockdown_time
	for(var/mob/living/victim in view(word_range, pulpit))
		if(victim.stat == DEAD || oracle_word_spares(victim, caster))
			continue
		victim.Knockdown(floored)
		victim.apply_damage(impact_damage, BRUTE, spread_damage = TRUE)
		to_chat(victim, span_userdanger("The word goes through you and your legs stop taking instructions."))
		if(stammering())
			victim.drop_all_held_items()

// ===== THE ANTIPHON =====

/**
 * *Get off the axis.* The verse burns itself into the floor along the four
 * directions out from the caster, six tiles each, and after the Stammer along
 * all eight. Blocked by anything dense, so the arena's pillars shorten the lanes.
 * Standing behind one is as good as standing off the axis.
 */
/datum/action/cooldown/mob_cooldown/oracle_word/antiphon
	name = "The Antiphon"
	// Keep these numbers in sync with the vars below.
	desc = "Burn a line of the verse into the floor along all four directions, six tiles each. 1.4 seconds of warning, then 25 burn to anything standing on it. Eight directions after the Stammer."
	button_icon_state = "sacredflame"
	cooldown_time = 15 SECONDS
	/// How long the letters hang before they burn.
	var/telegraph_time = 1.4 SECONDS
	/// How far each lane runs.
	var/lane_length = 6
	/// Burn dealt to anything caught in a lane.
	var/strike_damage = 25
	/// Lines of the verse it writes, one picked per cast.
	var/static/list/written_lines = list(
		"ILN ASH VERBA.",
		"SOMA VESH ENNA.",
		"OXI ATH'ENNA MORI.",
		"VECTA UN'DAL RETH.",
		"EX LIBRIS.",
	)

/datum/action/cooldown/mob_cooldown/oracle_word/antiphon/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	var/list/turf/lanes = pick_lanes()
	if(!length(lanes))
		return FALSE
	StartCooldown()
	hold_the_floor()
	owner.visible_message(span_boldwarning("[owner] scratches something into the air, and it settles onto the floor in lines running away from [owner.p_them()]."))
	owner.balloon_alert_to_viewers("the antiphon!")
	owner.say(pick(written_lines), spans = list("colossus"), forced = "vestige oracle")
	playsound(owner, 'sound/effects/magic/fireball.ogg', 60, TRUE)
	var/list/markers = list()
	for(var/turf/marked as anything in lanes)
		new /obj/effect/temp_visual/oracle_glyph(marked, telegraph_time)
		var/obj/effect/vestige_trial_marker/marker = new(marked)
		markers += marker
		// A destroyed slate cancels its callback; the short fallback also cleans up that case.
		QDEL_IN(marker, telegraph_time + 1 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(strike_marked_lanes), markers), telegraph_time)
	return TRUE

/// Resolve the marked deck after any shuttle movement, at the same instant its warning ends.
/datum/action/cooldown/mob_cooldown/oracle_word/antiphon/proc/strike_marked_lanes(list/markers)
	var/list/lanes = list()
	for(var/obj/effect/vestige_trial_marker/marker as anything in markers)
		if(QDELETED(marker))
			continue
		var/turf/marked = get_turf(marker)
		if(marked)
			lanes += marked
		qdel(marker)
	strike(lanes)

/// Walk each direction out from the caster until something dense stops the line.
/datum/action/cooldown/mob_cooldown/oracle_word/antiphon/proc/pick_lanes()
	var/turf/centre = get_turf(owner)
	if(isnull(centre))
		return list()
	var/list/directions = stammering() ? GLOB.alldirs : GLOB.cardinals
	var/list/turf/lanes = list()
	for(var/direction in directions)
		var/turf/walker = centre
		for(var/tile in 1 to lane_length)
			walker = get_step(walker, direction)
			if(isnull(walker) || walker.is_blocked_turf(exclude_mobs = TRUE))
				break
			lanes += walker
	return lanes

/datum/action/cooldown/mob_cooldown/oracle_word/antiphon/proc/strike(list/turf/lanes)
	var/mob/living/caster = owner
	if(QDELETED(caster) || caster.stat == DEAD)
		return
	playsound(caster, 'sound/effects/magic/fireball.ogg', 80, TRUE)
	for(var/turf/burning as anything in lanes)
		if(QDELETED(burning))
			continue
		new /obj/effect/temp_visual/oracle_glyph/spent(burning)
		for(var/mob/living/victim in burning)
			if(victim.stat == DEAD || oracle_word_spares(victim, caster))
				continue
			victim.apply_damage(strike_damage, BURN, spread_damage = TRUE)
			to_chat(victim, span_userdanger("The letters under your feet finish themselves and take the skin with them."))

// ===== THE CALLED WORD =====

/**
 * *Break line of sight, or fight while you are dragged.* It calls the target by
 * a name that is almost theirs, and their feet answer. Six seconds of one forced
 * step a second, no damage and no loss of control over anything else, the
 * danger is entirely in where it puts you, which is usually inside melee range
 * or onto an Antiphon lane.
 */
/datum/action/cooldown/mob_cooldown/oracle_word/called_word
	name = "The Called Word"
	// Keep these numbers in sync with /datum/status_effect/oracle_called.
	desc = "Call a target by a name close enough to theirs. For 6 seconds they take one forced step toward you every second. Losing sight of you ends it early."
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "dominate"
	cooldown_time = 26 SECONDS
	/// How far it can call.
	var/call_range = 8
	/// Names it tries. None of them are anybody's.
	var/static/list/wrong_names = list(
		"MERRICK",
		"VESSA",
		"TOLLAND",
		"CORVIN",
		"MARGET",
		"HANNET",
		"SUL",
	)

/datum/action/cooldown/mob_cooldown/oracle_word/called_word/Activate(atom/target)
	if(!isliving(owner) || !isliving(target))
		return FALSE
	var/mob/living/victim = target
	if(victim.stat == DEAD || get_dist(owner, victim) > call_range)
		return FALSE
	StartCooldown()
	hold_the_floor()
	owner.say("[pick(wrong_names)]. COME HERE.", spans = list("colossus"), forced = "vestige oracle")
	playsound(owner, 'sound/effects/magic/curse.ogg', 70, TRUE)
	victim.apply_status_effect(/datum/status_effect/oracle_called, owner)
	return TRUE

// ===== THE LAST LINE =====

/**
 * *Talk over it.* Phase two only. It plants and recites the finish, one word a
 * second. If it gets to the end the room burns. If it takes 200 damage inside
 * the window it loses the line, hurts itself and stays planted for five more
 * seconds, which is the largest free damage window in the fight.
 *
 * It is completely inert for the whole recital, so committing to the interrupt
 * is safe. That is the point: the Magister's parting advice is "don't listen to
 * it, talk over it", and this is the sentence that means.
 */
/datum/action/cooldown/mob_cooldown/oracle_word/last_line
	name = "The Last Line"
	// Keep these numbers in sync with the vars below.
	desc = "Plant and recite the last line, one word a second. If it finishes, everything in sight takes 60 burn, catches fire and is knocked flat for 5 seconds. Take 200 damage during the recital and lose the line instead, and stay planted 5 seconds longer."
	button_icon_state = "scream_for_me"
	cooldown_time = 55 SECONDS
	// It holds the floor by being planted, not by the shared lockout.
	speech_lockout = 0
	/// The line, one word per second.
	var/list/verse = list("SIC", "ITUR", "AD", "ASHTA", "EX", "LIBRIS", "EX", "OSSIBUS")
	/// Time between words.
	var/syllable_time = 1 SECONDS
	/// Damage that has to land inside the window to break the recital.
	var/interrupt_damage = 200
	/// How long it stays planted after losing the line.
	var/stumble_stagger = 5 SECONDS
	/// What losing the line costs it.
	var/stumble_recoil = 100
	/// Burn dealt if the line finishes.
	var/line_damage = 60
	/// How long the line knocks its targets down for.
	var/line_knockdown = 5 SECONDS
	/// Fire stacks the line leaves on its targets.
	var/line_fire_stacks = 6
	/// How far the finished line reaches.
	var/line_range = 9
	/// Health the Oracle had when the recital started.
	var/health_at_start = 0
	/// TRUE while the recital is running.
	var/reciting = FALSE

/datum/action/cooldown/mob_cooldown/oracle_word/last_line/Activate(atom/target)
	var/mob/living/basic/vestige_oracle/oracle = owner
	if(!istype(oracle) || reciting)
		return FALSE
	StartCooldown()
	reciting = TRUE
	health_at_start = oracle.health
	oracle.set_inert(TRUE)
	oracle.visible_message(span_boldwarning("[oracle] plants both feet, puts its head back and starts the last line."))
	oracle.balloon_alert_to_viewers("the last line!")
	playsound(oracle, 'sound/effects/magic/clockwork/invoke_general.ogg', 95, TRUE)
	oracle.Shake(pixelshiftx = 1, pixelshifty = 1, duration = (length(verse) + 1) * syllable_time)
	addtimer(CALLBACK(src, PROC_REF(recite), 1), syllable_time)
	return TRUE

/// One word, then a look at how much has landed on it since the recital started.
/datum/action/cooldown/mob_cooldown/oracle_word/last_line/proc/recite(index)
	var/mob/living/basic/vestige_oracle/oracle = owner
	if(!istype(oracle) || oracle.stat == DEAD)
		reciting = FALSE
		release()
		return
	if((health_at_start - oracle.health) >= interrupt_damage)
		stumble()
		return
	if(index > length(verse))
		deliver()
		return
	oracle.say(verse[index], spans = list("colossus"), forced = "vestige oracle")
	playsound(oracle, 'sound/effects/magic/RATTLEMEBONES.ogg', 55, TRUE)
	addtimer(CALLBACK(src, PROC_REF(recite), index + 1), syllable_time)

/// Talked over. It bites its own tongue and stays down for a while.
/datum/action/cooldown/mob_cooldown/oracle_word/last_line/proc/stumble()
	reciting = FALSE
	var/mob/living/basic/vestige_oracle/oracle = owner
	if(!istype(oracle) || oracle.stat == DEAD)
		release()
		return
	oracle.visible_message(span_boldnotice("[oracle] loses the line halfway through, coughs, and sags where it stands."))
	oracle.balloon_alert_to_viewers("lost the line!")
	oracle.say("...no.", forced = "vestige oracle")
	playsound(oracle, 'sound/effects/magic/blind.ogg', 70, TRUE)
	oracle.apply_damage(stumble_recoil, BRUTE, spread_damage = TRUE)
	addtimer(CALLBACK(src, PROC_REF(release)), stumble_stagger)

/// Nobody stopped it.
/datum/action/cooldown/mob_cooldown/oracle_word/last_line/proc/deliver()
	reciting = FALSE
	var/mob/living/basic/vestige_oracle/oracle = owner
	if(!istype(oracle) || oracle.stat == DEAD)
		release()
		return
	var/turf/pulpit = get_turf(oracle)
	oracle.visible_message(span_boldwarning("[oracle] finishes the line, and the whole room goes up."))
	if(pulpit)
		playsound(pulpit, 'sound/effects/magic/demon_dies.ogg', 100, TRUE)
		new /obj/effect/temp_visual/circle_wave/oracle(pulpit)
		for(var/mob/living/victim in view(line_range, pulpit))
			if(victim.stat == DEAD || oracle_word_spares(victim, oracle))
				continue
			victim.apply_damage(line_damage, BURN, spread_damage = TRUE)
			victim.adjust_fire_stacks(line_fire_stacks)
			victim.ignite_mob()
			victim.Knockdown(line_knockdown)
			to_chat(victim, span_userdanger("The last line lands on you, and everything you are wearing catches."))
			shake_camera(victim, 3, 3)
	release()

/// Hand it its legs back.
/datum/action/cooldown/mob_cooldown/oracle_word/last_line/proc/release()
	var/mob/living/basic/vestige_oracle/oracle = owner
	if(istype(oracle))
		oracle.set_inert(FALSE)

// =========================================================================
// THE CALLED WORD: STATUS EFFECT
// =========================================================================

/**
 * One forced step a second toward whatever called you.
 *
 * Deliberately generic in what does the calling: the Oracle uses it, and so does
 * the borrowed name once it is stuck in the floor. Nothing else about the victim
 * is taken away, they can still shoot, cast and swing, they just cannot stand
 * still. Losing sight of the caller ends it, which is the counterplay.
 */
/datum/status_effect/oracle_called
	id = "oracle_called"
	duration = 6 SECONDS
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/oracle_called
	show_duration = TRUE
	/// Whatever is doing the calling.
	var/datum/weakref/caller_ref
	/// Past this, or with sight broken, the call stops carrying.
	var/call_range = 9

/datum/status_effect/oracle_called/on_creation(mob/living/new_owner, atom/new_caller, set_duration)
	if(new_caller)
		caller_ref = WEAKREF(new_caller)
	if(isnum(set_duration))
		duration = set_duration
	return ..()

/datum/status_effect/oracle_called/on_apply()
	if(isnull(caller_ref?.resolve()))
		return FALSE
	owner.visible_message(
		span_boldwarning("[owner] turns and starts walking, and does not look happy about it."),
		span_userdanger("Something calls a name that is nearly yours, and your feet answer it."),
	)
	owner.balloon_alert_to_viewers("called!")
	return TRUE

/datum/status_effect/oracle_called/refresh(mob/living/new_owner, atom/new_caller, set_duration)
	. = ..()
	if(new_caller)
		caller_ref = WEAKREF(new_caller)
	if(isnum(set_duration))
		duration = world.time + set_duration

/datum/status_effect/oracle_called/on_remove()
	if(!QDELETED(owner))
		to_chat(owner, span_notice("Your feet are yours again."))
	return ..()

/datum/status_effect/oracle_called/tick(seconds_between_ticks)
	var/atom/summoner = caller_ref?.resolve()
	if(QDELETED(summoner))
		qdel(src)
		return
	if(isliving(summoner))
		var/mob/living/living_summoner = summoner
		if(living_summoner.stat == DEAD)
			qdel(src)
			return
	if(get_dist(owner, summoner) > call_range || !can_see(owner, summoner, call_range))
		qdel(src)
		return
	if(owner.stat != CONSCIOUS || owner.buckled || HAS_TRAIT(owner, TRAIT_IMMOBILIZED))
		return
	step_towards(owner, summoner)

/datum/status_effect/oracle_called/get_examine_text()
	return span_warning("[owner.p_They()] [owner.p_are()] walking somewhere [owner.p_they()] clearly [owner.p_do()]n't want to go.")

/atom/movable/screen/alert/status_effect/oracle_called
	name = "Called"
	desc = "Something is calling you by a name that is almost yours, and your legs keep answering. \
		You can still fight. You just cannot stand still. Get out of its sight and it stops."
	icon_state = ALERT_MIND_CONTROL

// =========================================================================
// VISUALS
// =========================================================================

/// The letters the Antiphon is about to burn in.
/obj/effect/temp_visual/oracle_glyph
	icon = 'icons/mob/telegraphing/telegraph_holographic.dmi'
	icon_state = "target_box"
	color = ORACLE_VIOLET
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	randomdir = FALSE
	duration = 1.4 SECONDS

/obj/effect/temp_visual/oracle_glyph/Initialize(mapload, new_duration)
	if(new_duration)
		duration = new_duration
	return ..()

/// And what is left of them for a moment afterwards.
/obj/effect/temp_visual/oracle_glyph/spent
	color = COLOR_RED
	duration = 0.7 SECONDS

/// The ring under anything loud the Oracle does.
/obj/effect/temp_visual/circle_wave/oracle
	color = ORACLE_VIOLET
	duration = 0.9 SECONDS
	amount_to_scale = 8

// =========================================================================
// DROPS
// =========================================================================

/**
 * Guaranteed. The thing that made it deaf to its own recital, which is why four
 * centuries of getting the words wrong never bothered it.
 *
 * Mechanically a tinfoil hat carved out of rock: it blocks mind-affecting magic
 * outright and takes a reasonable beating. Notably it does not stop Voice of the
 * Word, which does not check for antimagic at all.
 */
/obj/item/clothing/head/oracle_hood
	name = "worn stone hood"
	desc = "A hood cut from one piece of grey rock, rubbed thin at the front where a mouth would be. Much lighter than it looks."
	icon = 'icons/obj/clothing/head/helmet.dmi'
	worn_icon = 'icons/mob/clothing/head/helmet.dmi'
	icon_state = "culthood"
	inhand_icon_state = "culthood"
	color = "#9c9aa4"
	armor_type = /datum/armor/head_oracle_hood
	flags_inv = HIDEFACE|HIDEHAIR|HIDEEARS
	flags_cover = HEADCOVERSEYES
	cold_protection = HEAD
	min_cold_protection_temperature = HELMET_MIN_TEMP_PROTECT
	heat_protection = HEAD
	max_heat_protection_temperature = HELMET_MAX_TEMP_PROTECT
	resistance_flags = FIRE_PROOF | ACID_PROOF

/obj/item/clothing/head/oracle_hood/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/anti_magic, MAGIC_RESISTANCE_MIND, INFINITY, ITEM_SLOT_HEAD)

/obj/item/clothing/head/oracle_hood/examine(mob/user)
	. = ..()
	. += span_notice("Worn, nothing that works on the mind can get at yours. It does nothing about anything else.")

/datum/armor/head_oracle_hood
	melee = 40
	bullet = 20
	laser = 20
	energy = 30
	bomb = 30
	fire = 60
	acid = 60
	wound = 10

/**
 * Jackpot. The Antiphon, scaled to something a person can hold: same four lanes,
 * shorter, weaker, and a much longer wait between recitals.
 *
 * Reuses the Oracle's own ability rather than reimplementing it, so retuning the
 * boss's lanes retunes this with them. It is never "stammering" in a player's
 * hands, so it stays at four directions.
 */
/obj/item/oracle_slate
	name = "Oracle's slate"
	desc = "A slab of grey rock with three lines of the Athenaeum liturgy cut into it. Two of them have been scratched out and cut again, deeper."
	icon = 'voidcrew/modules/antag_ruins/icons/oracle.dmi'
	icon_state = "slate"
	inhand_icon_state = "blankplaque"
	w_class = WEIGHT_CLASS_NORMAL
	force = 12
	throwforce = 12
	attack_verb_continuous = list("clubs", "bludgeons", "brains")
	attack_verb_simple = list("club", "bludgeon", "brain")
	resistance_flags = FIRE_PROOF | ACID_PROOF
	actions_types = list(/datum/action/cooldown/mob_cooldown/oracle_word/antiphon/slate)
	action_slots = ITEM_SLOT_HANDS

/obj/item/oracle_slate/examine(mob/user)
	. = ..()
	. += span_notice("Hold it and use the ability. The lines run out from wherever you are standing, so mind who is standing beside you.")

/datum/action/cooldown/mob_cooldown/oracle_word/antiphon/slate
	name = "The Antiphon"
	// Keep these numbers in sync with the vars below.
	desc = "Burn a line of the verse into the floor along all four directions, four tiles each. 1.4 seconds of warning, then 20 burn to anything standing on it. You are the only thing it spares."
	// Self-centred, so the button fires it rather than arming a click.
	click_to_activate = FALSE
	cooldown_time = 25 SECONDS
	lane_length = 4
	strike_damage = 20

/**
 * Jackpot. A name the Oracle never managed to get right, and now nobody owns it.
 *
 * Put it in the floor and it recites, and anything nearby that is not thinking
 * very hard walks over to listen. Deliberately no effect on anything with a
 * client: this is a tool for pulling a pack of hostiles off you, not a way to
 * march another player into a wall.
 */
/obj/item/borrowed_name
	name = "borrowed name"
	desc = "A palm-sized stone token with a name cut into it, then crossed out, then cut again underneath. Neither version is spelled the same way twice."
	icon = 'voidcrew/modules/antag_ruins/icons/oracle.dmi'
	icon_state = "name_token"
	inhand_icon_state = "blankplaque"
	w_class = WEIGHT_CLASS_SMALL
	throwforce = 5
	light_range = 1.5
	light_power = 0.6
	light_color = ORACLE_VIOLET
	resistance_flags = FIRE_PROOF | ACID_PROOF
	/// Time between plantings.
	var/plant_cooldown_time = 45 SECONDS
	COOLDOWN_DECLARE(plant_cooldown)

/obj/item/borrowed_name/examine(mob/user)
	. = ..()
	. += span_notice("Use it in your hand to stand it up in the floor. It recites for 30 seconds and pulls anything mindless within 6 tiles toward it. It does nothing to people.")
	if(!COOLDOWN_FINISHED(src, plant_cooldown))
		. += span_warning("It is still saying the last one. About [round(COOLDOWN_TIMELEFT(src, plant_cooldown) / 10)] seconds.")

/obj/item/borrowed_name/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!COOLDOWN_FINISHED(src, plant_cooldown))
		balloon_alert(user, "still saying the last one!")
		return TRUE
	var/turf/spot = get_turf(user)
	if(isnull(spot) || spot.is_blocked_turf(exclude_mobs = TRUE))
		balloon_alert(user, "no room!")
		return TRUE
	COOLDOWN_START(src, plant_cooldown, plant_cooldown_time)
	user.visible_message(
		span_warning("[user] stands [src] up in the floor, and it starts talking."),
		span_notice("You stand [src] up in the floor. It picks a name and starts working on it."),
	)
	playsound(spot, 'sound/effects/magic/curse.ogg', 50, TRUE)
	new /obj/structure/borrowed_name(spot)
	return TRUE

/obj/structure/borrowed_name
	name = "borrowed name"
	desc = "A stone token standing upright in the floor, saying a name over and over and getting it wrong every time."
	icon = 'voidcrew/modules/antag_ruins/icons/oracle.dmi'
	icon_state = "name_token"
	anchored = TRUE
	density = FALSE
	max_integrity = 60
	light_range = 2
	light_power = 0.8
	light_color = ORACLE_VIOLET
	/// How far the name carries.
	var/pull_range = 6
	/// How long it keeps talking.
	var/lifespan = 30 SECONDS
	/// How long each pull it applies lasts.
	var/pull_duration = 4 SECONDS

/obj/structure/borrowed_name/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)
	QDEL_IN(src, lifespan)

/obj/structure/borrowed_name/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/borrowed_name/process(seconds_per_tick)
	for(var/mob/living/listener in view(pull_range, src))
		// People get to keep their own legs. See the item's header.
		if(listener.client || listener.mind)
			continue
		if(listener.stat != CONSCIOUS)
			continue
		listener.apply_status_effect(/datum/status_effect/oracle_called, src, pull_duration)

// =========================================================================
// THE CAPSTONE: VOICE OF THE WORD
// =========================================================================

/datum/vestige_boon/spell/voice_of_the_word
	name = "Voice of the Word"
	// Keep these numbers in sync with the defines at the top of this file.
	desc = "Shout an order and everything alive that can see you obeys it. Deafness, ear protection and magic resistance make no difference. Casting offers the full list of orders, from KNOCK EVERYONE DOWN to TURN ON EACH OTHER; right-click to read it without shouting."
	grant_text = "Your throat feels wrong. There is a much bigger voice in it than there was this morning."
	spell_type = /datum/action/cooldown/spell/voice_of_the_word

/**
 * Voice of God with the safety rails off.
 *
 * Not a subtype of `/datum/action/cooldown/spell/voice_of_god`: that type's
 * `cast()` calls `voice_of_god()` unconditionally, and DM cannot skip an
 * immediate parent, so subtyping it would run both dispatchers on every cast.
 * The action shell below is copied from it; the dispatch is
 * [/proc/voice_of_the_word] instead.
 */
/datum/action/cooldown/spell/voice_of_the_word
	name = "Voice of the Word"
	// Keep these numbers in sync with the defines at the top of this file.
	desc = "Shout an order at the room. Everything alive nearby that can see you obeys, and nothing blocks it. Right-click to read the list of orders."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "voice_of_god"
	sound = 'sound/effects/magic/clockwork/invoke_general.ogg'

	cooldown_time = WORD_COOLDOWN
	invocation = "" // The dispatcher does the talking
	invocation_type = INVOCATION_SHOUT
	spell_requirements = NONE
	antimagic_flags = NONE

	/// The order to deliver on cast.
	var/command
	/// Only one prompt may reserve an order at a time.
	var/choosing_word = FALSE
	/// Multiplier on the command's power.
	var/power_mod = WORD_POWER_MULTIPLIER
	/// How far it carries, in tiles of line of sight.
	var/word_range = WORD_RANGE
	/// Spans applied to the order.
	var/list/spans = list("colossus", "yell")
	/// Menu label -> the words actually shouted. Built once from phrasebook, shared by every copy of the spell.
	var/static/list/word_menu
	/**
	 * The Word's phrasebook: what it can be told to do, in the words that do it.
	 *
	 * The dispatcher matches free text against a roster of regexes nobody can
	 * see, which made the capstone a guessing game, the whole point of this
	 * table is that the player never has to guess. Each row is the command it
	 * triggers, the words to shout, and what those words do at this spell's
	 * power.
	 *
	 * The typepath is not decoration: build_word_menu() checks each phrase
	 * against its own command's trigger, so if an upstream regex is ever
	 * reworded the row drops out with a stack trace instead of quietly shouting
	 * something inert. A command added upstream and not listed here is still
	 * reachable, the menu's last entry is a free-text box, which is exactly
	 * what this spell used to be.
	 *
	 * Effects are described at WORD_POWER_MULTIPLIER, which is what this spell
	 * speaks at, not at Voice of God's base strength.
	 */
	var/static/list/phrasebook = list(
		// --- Ending a fight ---
		list(/datum/voice_of_god_command/slumber, "SLEEP", "Everything in the room falls asleep for about half a minute."),
		list(/datum/voice_of_god_command/frenzy, "TURN ON EACH OTHER", "Everyone in the room is possessed for twenty seconds and attacks whoever is nearest. A tinfoil hat stops this one."),
		list(/datum/voice_of_god_command/knockdown, "DROP", "Everyone hits the deck for about half a minute."),
		list(/datum/voice_of_god_command/immobilize, "HALT", "Everyone is rooted where they stand for about half a minute."),
		list(/datum/voice_of_god_command/silence, "SILENCE", "Nobody in the room can speak for over two minutes."),
		// --- Hurting people ---
		list(/datum/voice_of_god_command/brute, "DIE", "A hundred and twenty brute to the chest of everything in the room. This is the one that kills."),
		list(/datum/voice_of_god_command/immolate, "INCINERATE", "Everyone catches fire properly and cooks. A firesuit still works."),
		list(/datum/voice_of_god_command/burn, "BURN", "Everyone catches fire. The gentler of the two fires."),
		list(/datum/voice_of_god_command/hot, "HEAT", "Everyone's body temperature is driven up hard."),
		list(/datum/voice_of_god_command/cold, "FREEZE", "Everyone's body temperature is driven down hard."),
		list(/datum/voice_of_god_command/bleed, "BLEED", "Opens a bleeding wound somewhere on every human in the room."),
		list(/datum/voice_of_god_command/vomit, "VOMIT", "Everyone throws up where they stand."),
		// --- Moving people ---
		list(/datum/voice_of_god_command/repulse, "BEGONE", "Everyone is hurled away from you and lands hard."),
		list(/datum/voice_of_god_command/attract, "COME HERE", "Everyone is dragged through the air to your feet."),
		list(/datum/voice_of_god_command/move, "MOVE", "Everyone takes a step. Name a direction in the shout and they all step that way."),
		list(/datum/voice_of_god_command/getup, "GET UP", "Everyone stands, and every stun on them is wiped. Use it on your own people."),
		list(/datum/voice_of_god_command/sit, "SIT", "Everyone buckles into whatever chair they are standing on."),
		list(/datum/voice_of_god_command/stand, "STAND", "Everyone unbuckles from whatever is holding them."),
		list(/datum/voice_of_god_command/run, "RUN", "Everyone switches to running."),
		list(/datum/voice_of_god_command/walk, "SLOW DOWN", "Everyone switches to walking."),
		list(/datum/voice_of_god_command/throw_catch, "CATCH", "Everyone's throw mode comes on."),
		// --- Helping people ---
		list(/datum/voice_of_god_command/heal, "HEAL", "Eighty brute and eighty burn closed on everyone in the room. It does not tell friend from enemy."),
		list(/datum/voice_of_god_command/wake_up, "WAKE UP", "Wakes everyone up, sedated or not."),
		// --- Getting answers ---
		list(/datum/voice_of_god_command/who_are_you, "WHO ARE YOU", "Everyone says their real name out loud. Masks and hoods do not help them."),
		list(/datum/voice_of_god_command/say_my_name, "SAY MY NAME", "Everyone says your name."),
		list(/datum/voice_of_god_command/state_laws, "STATE YOUR LAWS", "Every silicon in the room recites its lawset."),
		list(/datum/voice_of_god_command/speak, "SPEAK", "Everyone blurts out something stupid."),
		// --- Wasting the shout ---
		list(/datum/voice_of_god_command/hallucinate, "SEE THE TRUTH", "Everyone sees monsters instead of people for two minutes."),
		list(/datum/voice_of_god_command/jump, "JUMP", "Everyone jumps, or asks how high."),
		list(/datum/voice_of_god_command/knock_knock, "KNOCK KNOCK", "Everyone answers \"who's there?\""),
		list(/datum/voice_of_god_command/multispin, "RIGHT ROUND", "Everyone spins on the spot."),
		list(/datum/voice_of_god_command/honk, "HONK", "Honk."),
	)

/// The free-text way out, kept because the phrasebook can never be the whole roster
#define WORD_MENU_FREEHAND "Say your own words..."

/**
 * Builds the cast menu from [phrasebook], dropping any row whose phrase no
 * longer trips its own command. Runs once for the first caster and is shared
 * from then on.
 */
/datum/action/cooldown/spell/voice_of_the_word/proc/build_word_menu()
	var/list/menu = list()
	for(var/list/row as anything in phrasebook)
		var/datum/voice_of_god_command/command_type = row[1]
		var/phrase = row[2]
		var/note = row[3]
		var/trigger = initial(command_type.trigger)
		if(!trigger)
			stack_trace("Voice of the Word phrasebook lists [command_type], which has no trigger.")
			continue
		var/regex/matcher = regex(trigger, "i")
		if(!matcher.Find(LOWER_TEXT(phrase)))
			stack_trace("Voice of the Word phrase '[phrase]' no longer matches [command_type]'s trigger.")
			continue
		menu["[phrase]: [note]"] = phrase
	// Maps to itself so both input paths below resolve it to the same string
	menu[WORD_MENU_FREEHAND] = WORD_MENU_FREEHAND
	return menu

/// Prints the phrasebook. Free, and it never costs the shout.
/datum/action/cooldown/spell/voice_of_the_word/proc/read_the_words(mob/reader)
	var/list/lines = list(span_boldnotice("The Word knows these orders. Shout any of them, or anything that means the same thing."))
	for(var/list/row as anything in phrasebook)
		lines += span_notice("<b>[row[2]]</b>, [row[3]]")
	lines += span_notice("Anything else you shout still reaches the older roster of orders; these are only the ones worth knowing by name.")
	to_chat(reader, boxed_message(jointext(lines, "<br>")))

// Right-click reads the phrasebook instead of casting. Deliberately ahead of
// every other check: reading the list is not using the ability, so a spent
// cooldown must not stop you doing it.
/datum/action/cooldown/spell/voice_of_the_word/Trigger(mob/clicker, trigger_flags, atom/target)
	if((trigger_flags & TRIGGER_SECONDARY_ACTION) && owner)
		read_the_words(owner)
		return FALSE
	return ..()

/datum/action/cooldown/spell/voice_of_the_word/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	var/mob/living/user = owner
	if(choosing_word || !menu_check(user))
		return . | SPELL_CANCEL_CAST
	choosing_word = TRUE
	var/selected_command = choose_command(user)
	choosing_word = FALSE
	if(!selected_command || !menu_check(user) || get_caster_from_target(user) != cast_on)
		return . | SPELL_CANCEL_CAST
	command = selected_command

/// Recheck the owning body and the full action gate after either sleeping input.
/datum/action/cooldown/spell/voice_of_the_word/proc/menu_check(mob/living/user)
	return !QDELETED(src) && !QDELETED(user) && owner == user && (src in user.actions) && IsAvailable(feedback = FALSE)

/// Input alone never starts or refunds a cooldown; the successful cast owns it.
/datum/action/cooldown/spell/voice_of_the_word/proc/choose_command(mob/living/user)
	if(!word_menu)
		word_menu = build_word_menu()
	var/choice = tgui_input_list(user, "What does the room do?", "Voice of the Word", word_menu)
	if(!choice || !menu_check(user))
		return null

	// tgui_input_list hands back the mapped words; the classic-input fallback
	// (for players with tgui inputs off) hands back the label it displayed.
	// Looking the answer up as a key resolves both to the same thing.
	var/selected_command = word_menu[choice] || choice
	if(selected_command == WORD_MENU_FREEHAND)
		return tgui_input_text(user, "Say it to the room.", "Voice of the Word", max_length = MAX_MESSAGE_LEN)
	return selected_command

/datum/action/cooldown/spell/voice_of_the_word/cast(atom/cast_on)
	. = ..()
	if(!isliving(cast_on))
		return
	voice_of_the_word(uppertext(command), cast_on, spans, base_multiplier = power_mod, range = word_range)

/// The dispatcher shouts for us.
/datum/action/cooldown/spell/voice_of_the_word/invocation(mob/living/invoker)
	return

/**
 * Voice of God's dispatcher, rewritten for the capstone.
 *
 * Differences from `/proc/voice_of_god`, all of them deliberate:
 *
 * - Listeners are gathered from **line of sight**, not `get_hearers_in_view`.
 *   Deafness, earmuffs and a closed helmet are all irrelevant.
 * - No `can_block_magic` check. Holy and mind antimagic do not stop an order.
 * - No name or job focusing, and no `voice_of_god_power` role multiplier. This
 *   is a room weapon; everybody in the room gets the same thing, at the same
 *   strength, and the number in the tooltip is the number that lands.
 * - The matched command's own `cooldown` is ignored rather than returned for the
 *   caller to scale. The capstone charges [WORD_COOLDOWN] for every order, so
 *   that the cost is a thing the action button can state up front.
 *
 * Everything else is upstream's: the same `/datum/voice_of_god_command` roster,
 * matched the same way.
 */
/proc/voice_of_the_word(message, mob/living/user, list/span_list, base_multiplier = 1, range = WORD_RANGE)
	if(QDELETED(user))
		return
	var/log_message = uppertext(message)
	if(!user.say(message, spans = span_list, sanitize = FALSE, ignore_spam = TRUE))
		return
	message = LOWER_TEXT(message)

	var/turf/podium = get_turf(user)
	if(isnull(podium))
		return

	var/list/mob/living/listeners = list()
	for(var/mob/living/candidate in view(range, podium))
		if(candidate == user || candidate.stat == DEAD)
			continue
		listeners += candidate
	if(!length(listeners))
		return

	for(var/datum/voice_of_god_command/command as anything in GLOB.voice_of_god_commands)
		if(!findtext(message, command.trigger))
			continue
		command.execute(listeners, user, base_multiplier, message)
		break

	message_admins("[ADMIN_LOOKUPFLW(user)] said '[log_message]' with the Voice of the Word, affecting [english_list(listeners)], at power [base_multiplier].")
	user.log_message("said '[log_message]' with the Voice of the Word, affecting [english_list(listeners)], at power [base_multiplier].", LOG_GAME, color = "red")
	SSblackbox.record_feedback("tally", "voice_of_the_word", 1, log_message)

// =========================================================================
// NEW COMMANDS
// =========================================================================
//
// These are ordinary /datum/voice_of_god_command subtypes, so they join
// GLOB.voice_of_god_commands and any Voice of God can reach them. Every trigger
// below was checked against upstream's roster for overlap in both directions.
// The dispatch takes the first regex that matches, so a collision would silently
// shadow somebody else's command.

/// Everyone in the room goes to sleep. 4 seconds a point of power.
/datum/voice_of_god_command/slumber
	trigger = "sleep|slumber"
	cooldown = 120 SECONDS

/datum/voice_of_god_command/slumber/execute(list/listeners, mob/living/user, power_multiplier = 1, message)
	for(var/mob/living/target as anything in listeners)
		target.Sleeping(4 SECONDS * power_multiplier)

/**
 * Everyone in the room catches fire properly.
 *
 * Upstream's `burn` command already exists and is much gentler; this is the one
 * the capstone is for. A firesuit still works, the order overrides ear
 * protection and antimagic, not thermodynamics.
 */
/datum/voice_of_god_command/immolate
	trigger = "immolate|combust|incinerate"
	cooldown = 60 SECONDS

/datum/voice_of_god_command/immolate/execute(list/listeners, mob/living/user, power_multiplier = 1, message)
	for(var/mob/living/target as anything in listeners)
		target.adjust_fire_stacks(3 * power_multiplier)
		target.ignite_mob()
		target.adjust_bodytemperature(25 * power_multiplier)

/**
 * Everyone in the room turns on everyone else.
 *
 * Power-gated, and it is the only command here that is. At Voice of God strength
 * it is a fright. A delusion that makes the room look like monsters, which is
 * what a shout that loud should be worth. At WORD_FRENZY_POWER_GATE and above it
 * is the real thing: the possession from `/datum/status_effect/lich_thrall`,
 * with attribution rewritten to name whoever shouted.
 *
 * Reusing the lich's possession rather than writing a second one is deliberate,
 * and precedented, the verdigris bridle (lich_loot.dm) is already a second
 * consumer, and lich_thrall.dm's header threads attribution specifically so a
 * player-driven caster can be named everywhere. The one thing that comes with it
 * is `can_be_lich_thralled`'s antimagic gate: a tinfoil hat stops the frenzy
 * even though it stops nothing else in this roster. That is a documented seam
 * and, on a command that takes a whole room's bodies away, a reasonable one.
 */
/datum/voice_of_god_command/frenzy
	trigger = "kill\\s*each\\s*other|turn\\s*on\\s*each\\s*other|tear\\s*each\\s*other\\s*apart|frenzy"
	cooldown = 120 SECONDS

/datum/voice_of_god_command/frenzy/execute(list/listeners, mob/living/user, power_multiplier = 1, message)
	if(power_multiplier < WORD_FRENZY_POWER_GATE)
		for(var/mob/living/target as anything in listeners)
			target.cause_hallucination( \
				get_random_valid_hallucination_subtype(/datum/hallucination/delusion/preset), \
				"voice of god frenzy", \
				duration = 10 SECONDS * power_multiplier, \
				affects_us = FALSE, \
				affects_others = TRUE, \
				skip_nearby = FALSE, \
			)
		return
	for(var/mob/living/target as anything in listeners)
		target.apply_status_effect(/datum/status_effect/lich_thrall/word_frenzy, user)

/**
 * The possession, wearing the Oracle's colours instead of Ilthuun's.
 *
 * Only four things change: the duration, who gets named, what colour the victim
 * glows, and (the important one) [retarget]. The parent skips other thralls on
 * purpose ("two possessed crewmen circling each other reads as a bug"), which is
 * exactly right for a lich picking off one raider and exactly wrong here, where
 * everybody in the room is possessed at once and turning on each other is the
 * whole command. Without the override every victim would find no legal target
 * and stand still.
 */
/datum/status_effect/lich_thrall/word_frenzy
	duration = WORD_FRENZY_DURATION
	alert_type = /atom/movable/screen/alert/status_effect/lich_thrall/word_frenzy

	/// What a frenzied mouth says. Its own static rather than an override of the
	/// parent's: DM shares one storage slot for a static var across a type and
	/// its subtypes, so overriding the value is not a thing you can do.
	var/static/list/frenzy_lines = list(
		"I HEARD IT TOO. I AM STILL DOING IT.",
		"IT WASN'T EVEN MY NAME.",
		"SOMEBODY SHUT THEM UP. SHUT THEM UP.",
		"MY HANDS ARE BUSY. SORRY.",
	)

/datum/status_effect/lich_thrall/word_frenzy/on_apply()
	. = ..()
	if(!.)
		return .
	// The parent parks every victim in FACTION_LICH so Ilthuun's dead leave his
	// puppet alone. There is no garrison here and the point is that they all go
	// for each other, so give them a faction of their own instead. The parent
	// captured original_faction before rewriting it, and still restores it.
	owner.faction = list("frenzied")
	return .

/datum/status_effect/lich_thrall/word_frenzy/attribution_name()
	var/mob/living/speaker = master_ref?.resolve()
	return speaker ? "[speaker]" : "whoever was shouting"

/datum/status_effect/lich_thrall/word_frenzy/attribution_log()
	var/mob/living/speaker = master_ref?.resolve()
	return speaker ? "[key_name(speaker)] with Voice of the Word" : "Voice of the Word with no caster"

/datum/status_effect/lich_thrall/word_frenzy/possessed_line()
	return pick(frenzy_lines)

/datum/status_effect/lich_thrall/word_frenzy/get_examine_text()
	return span_boldwarning("[owner.p_They()] [owner.p_are()] outlined in violet and looking at everyone in the room like a job.")

/**
 * Nearest living thing that is not the speaker, people first.
 *
 * Rewritten wholesale rather than extended: the parent's exclusions (undead,
 * FACTION_LICH, other thralls) are all wrong for a room-wide order, and the one
 * exclusion that matters here (the speaker) is not one of them. Somebody who
 * shouts "TURN ON EACH OTHER" is not included in "each other".
 */
/datum/status_effect/lich_thrall/word_frenzy/retarget()
	var/mob/living/speaker = master_ref?.resolve()
	var/mob/living/best_target
	var/best_score = INFINITY

	for(var/mob/living/candidate in view(WORD_FRENZY_SIGHT, owner))
		if(candidate == owner || candidate == speaker || QDELETED(candidate))
			continue
		if(candidate.stat == DEAD)
			continue
		var/score = get_dist(owner, candidate)
		if(candidate.client)
			score -= 100 // going for the nearest mouse instead of the nearest person is a joke
		if(score >= best_score)
			continue
		best_score = score
		best_target = candidate

	if(QDELETED(best_target))
		puppet_controller?.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		return
	puppet_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, best_target)

/// Violet, not verdigris. Same two layers as the parent (outline for a glance,
/// colour wash for when the outline is off the screen edge), so the removal
/// below has to match this exactly.
/datum/status_effect/lich_thrall/word_frenzy/apply_green_wash()
	owner.add_filter(WORD_FRENZY_FILTER, 3, list("type" = "outline", "color" = ORACLE_VIOLET, "alpha" = 0, "size" = 2))
	var/frenzy_filter = owner.get_filter(WORD_FRENZY_FILTER)
	if(frenzy_filter)
		animate(frenzy_filter, alpha = 220, time = 0.5 SECONDS, loop = -1)
		animate(alpha = 60, time = 0.5 SECONDS)
	owner.add_atom_colour(ORACLE_VIOLET, TEMPORARY_COLOUR_PRIORITY)

/datum/status_effect/lich_thrall/word_frenzy/remove_green_wash()
	var/frenzy_filter = owner.get_filter(WORD_FRENZY_FILTER)
	if(frenzy_filter)
		animate(frenzy_filter)
	owner.remove_filter(WORD_FRENZY_FILTER)
	owner.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, ORACLE_VIOLET)

/atom/movable/screen/alert/status_effect/lich_thrall/word_frenzy
	name = "Frenzied"
	desc = "Somebody told the room to turn on itself and your body agreed. It is walking you at the nearest \
		person and using whatever you were holding. This wears off. None of it is your fault."
	icon_state = ALERT_MIND_CONTROL

#undef ORACLE_STAMMER_THRESHOLD
#undef ORACLE_STAMMER_COOLDOWN_SCALE
#undef ORACLE_DISENGAGE_GRACE
#undef ORACLE_DISENGAGE_RANGE
#undef ORACLE_DISENGAGE_REGEN
#undef ORACLE_STAMMER_FILTER
#undef ORACLE_TRAIT
#undef ORACLE_VIOLET
#undef BB_ORACLE_WORD_OF_FALLING
#undef BB_ORACLE_ANTIPHON
#undef BB_ORACLE_CALLED_WORD
#undef BB_ORACLE_LAST_LINE
#undef BB_ORACLE_LAST_ABILITY
#undef WORD_MENU_FREEHAND
#undef WORD_POWER_MULTIPLIER
#undef WORD_COOLDOWN
#undef WORD_RANGE
#undef WORD_FRENZY_POWER_GATE
#undef WORD_FRENZY_DURATION
#undef WORD_FRENZY_FILTER
#undef WORD_FRENZY_SIGHT
