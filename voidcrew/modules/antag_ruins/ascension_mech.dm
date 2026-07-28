/**
 * # The Warframe, and Machine Communion
 *
 * The Hollow Master's capstone. See voidcrew/modules/antag_ruins/ascension.dm for
 * the framework this plugs into; this file owns three things it names:
 *
 * - [/mob/living/basic/vestige_warframe] — the boss of the Standing Opponent arena.
 * - [/datum/vestige_boon/spell/machine_communion] — the capstone boon.
 * - [/datum/action/cooldown/spell/machine_communion] — the ability it grants.
 *
 * ## The Warframe
 *
 * The clan built one sparring partner that could not be beaten so there would always
 * be something to train against, then everybody who knew how to switch it off left.
 * It has been winning matches alone in the lower hall for a century and it keeps score.
 *
 * It is hoarfrost/lich tier and, unlike either of them, it only ever fights one person.
 * The budget below is tuned for exactly that: 1400 HP is roughly four minutes of solid
 * work for a supplicant who has finished every one of the Hollow Master's lessons and
 * is carrying the blade, the stars and the smoke.
 *
 * It is deliberately **not** `/mob/living/basic/boss` and deliberately not megafauna.
 * `code/modules/unit_tests/voidcrew_loot.dm` text-scans every ruin .dmm and hard-fails
 * any map carrying either string outside a legacy whitelist. The stat block is
 * hand-copied from that tier; the inheritance is not. Do not reparent it.
 *
 * It is a mob and not an `/obj/vehicle/sealed/mecha`. Nobody ever gets in it.
 *
 * ### How it fights
 *
 * Four abilities, each asking a different question, plus a passive that decides which
 * question gets asked:
 *
 * - **The Read** — it samples your range every couple of seconds and keeps a running
 *   score. Play at range and it favours the closer and the floor;
 *   stay in melee and it favours the guard and the sweep. It announces the switch out
 *   loud, because the whole point is that you can learn it.
 * - **Iai** — the anti-kite. Fixes a line, paints it, then cuts down it very fast.
 *   Sidestep during the telegraph and it overshoots and is wide open for a second.
 * - **The Standing Guard** — the anti-mash. It raises guard for three and a half
 *   seconds and every melee hit that lands is deflected and answered. The counterplay
 *   is to stop swinging, which is a harder ask than it sounds. It cannot move, swing or
 *   cast while guarding, so it is also a free repositioning window.
 * - **Sweep of the Lower Hall** — the anti-hug. A telegraphed arc in its facing out to
 *   three tiles that throws you clear. Walk around behind it or get out of range.
 * - **Live Floor** — second round only. It energises a scatter of the hall's own deck
 *   plates for five seconds. Pure footwork.
 *
 * At half health it bows and starts the second round: Live Floor comes online, every
 * cooldown drops by 30%, it hits harder and moves faster, and the guard starts
 * deflecting bullets as well as blades.
 *
 * ### The traps in here
 *
 * - `/mob/living/basic/emp_act` deals **maxHealth** damage to any MOB_ROBOTIC basic mob
 *   on a heavy EMP (basic_defense.dm:171-184). A single EMP grenade would delete the
 *   boss outright. [/mob/living/basic/vestige_warframe/proc/emp_reaction] is overridden
 *   to a stagger and a modest chunk instead — keep it that way if you touch the biotype.
 * - Everything that repositions it is `forceMove`, not `do_teleport`. The arena area is
 *   NOTELEPORT (ascension.dm), so anything routed through `do_teleport` silently no-ops.
 * - It is leashed to an invisible anchor on its spawn turf, because the arena has an
 *   approach corridor and a boss dragged into a doorway is not a fight.
 *
 * ## Machine Communion
 *
 * Two halves. The passive half hands the owner TRAIT_SILICON_ACCESS and TRAIT_AI_ACCESS,
 * so every machine on the ship treats them as the AI and ID locks stop applying — the
 * same pair the machine wand grants (code/game/objects/items/machine_wand.dm:30-31).
 * The active half is a click ability that opens a quickhack list on whatever you clicked,
 * scoped to what that thing actually is.
 *
 * What was cut, and why: there is no AI eye. Camera-hopping a human across the ship is a
 * large amount of fragile silicon plumbing and it would make the owner a spectator rather
 * than a person in the room, so the reach is nine tiles and you have to be there. The
 * hacks are likewise local — Kill the Power is one APC's area, not the grid; Silence is
 * one bubble, not the ship. Every one of them is repeatable, which is where the round
 * warping actually comes from.
 */

// ===== THE WARFRAME =====

/// Fraction of max health at or below which the second round starts.
#define WARFRAME_SECOND_ROUND_THRESHOLD 0.5
/// How long the round change takes. It is untouchable and immobile for all of it.
#define WARFRAME_ROUND_CHANGE_TIME (3 SECONDS)
/// Every cooldown is multiplied by this when the second round starts.
#define WARFRAME_SECOND_ROUND_COOLDOWN_SCALE 0.7
/// Trait source for everything it applies to itself.
#define WARFRAME_TRAIT "vestige_warframe"
/// Filter key for the second-round outline.
#define WARFRAME_ROUND_FILTER "warframe_round"
/// Filter key for the outline it wears while guarding.
#define WARFRAME_GUARD_FILTER "warframe_guard"

/// How far it may get from its spawn mark before the leash drags it home. Sized to
/// cover the whole arena template from the boss landmark: the leash exists to
/// guarantee it can never end up outside the map, not to stop it chasing you through
/// the approach — [/mob/living/basic/vestige_warframe/proc/handle_disengagement] is
/// what punishes running away.
#define WARFRAME_LEASH_RANGE 20
/// How long it tolerates losing its opponent before it calls the match and starts repairing.
#define WARFRAME_DISENGAGE_GRACE (8 SECONDS)
/// Beyond this, or with line of sight broken, the opponent counts as gone.
#define WARFRAME_DISENGAGE_RANGE 12
/// Fraction of max health repaired per second while disengaged.
#define WARFRAME_DISENGAGE_REPAIR 0.05

/// At or inside this range, a range sample counts as "melee".
#define WARFRAME_CLOSE_RANGE 2
/// Ceiling on either half of the running range score, so the read stays responsive.
#define WARFRAME_READ_CAP 20
/// How far the read has to be ahead before it commits to a stance.
#define WARFRAME_READ_MARGIN 5
/// Minimum gap between spoken read changes.
#define WARFRAME_READ_ANNOUNCE_COOLDOWN (25 SECONDS)
/// Weight every ability starts the roll with.
#define WARFRAME_BASE_WEIGHT 3
/// Extra weight an ability gets when the read favours it.
#define WARFRAME_READ_WEIGHT 4

// Iai — the drawn cut. Range matches the rotation's engagement range on purpose: an
// ability that can be picked at a distance it cannot reach just burns planning ticks.
#define WARFRAME_IAI_RANGE 9
#define WARFRAME_IAI_TELEGRAPH (1.3 SECONDS)
#define WARFRAME_IAI_STEP_DELAY (0.1 SECONDS)
#define WARFRAME_IAI_DAMAGE 30
#define WARFRAME_IAI_KNOCKDOWN (1 SECONDS)
/// How long it stands there with the cut finished. Your free damage window.
#define WARFRAME_IAI_RECOVERY (1.2 SECONDS)

// The Standing Guard.
#define WARFRAME_GUARD_DURATION (3.5 SECONDS)
#define WARFRAME_RIPOSTE_DAMAGE 22
/// Shortest gap between two counters, so a fast weapon cannot chain them into a kill.
#define WARFRAME_RIPOSTE_INTERVAL (0.6 SECONDS)

// Sweep of the Lower Hall.
#define WARFRAME_SWEEP_RADIUS 3
/// Degrees either side of its facing that the sweep covers.
#define WARFRAME_SWEEP_ARC 75
#define WARFRAME_SWEEP_TELEGRAPH (1.2 SECONDS)
#define WARFRAME_SWEEP_DAMAGE 26
#define WARFRAME_SWEEP_THROW 3

// Live Floor.
#define WARFRAME_PLATE_COUNT 12
#define WARFRAME_PLATE_RADIUS 5
#define WARFRAME_PLATE_TELEGRAPH (1.5 SECONDS)
#define WARFRAME_PLATE_DURATION (5 SECONDS)
#define WARFRAME_PLATE_DAMAGE 18
/// Shortest gap between two shocks from the same plate on the same person.
#define WARFRAME_PLATE_REFRACTORY (2 SECONDS)

// The hall breaker — the optional in-fight interaction.
#define WARFRAME_BREAKER_STAGGER (3 SECONDS)
#define WARFRAME_BREAKER_BROWNOUT (25 SECONDS)
#define WARFRAME_BREAKER_RESET (60 SECONDS)

// Blackboard keys for its kit. Confined to this file.
#define BB_WARFRAME_IAI "BB_warframe_iai"
#define BB_WARFRAME_GUARD "BB_warframe_guard"
#define BB_WARFRAME_SWEEP "BB_warframe_sweep"
#define BB_WARFRAME_LIVE_FLOOR "BB_warframe_live_floor"
#define BB_WARFRAME_LAST_ABILITY "BB_warframe_last_ability"

// ===== MACHINE COMMUNION =====

/// How far the capstone reaches. You have to be in the room.
#define COMMUNION_RANGE 9
/// Seconds a bolted-and-live door stays electrified.
#define COMMUNION_ELECTRIFY_SECONDS 30
/// Burn a communion-live door lands. Equal to the floor of a stock powernet shock, ELECTROCUTE_DAMAGE().
#define COMMUNION_ELECTRIFY_DAMAGE 20
/// Stun on top of the burn. Matches the paralyse a carbon takes from a stock shock, so carbons feel no change.
#define COMMUNION_ELECTRIFY_STUN (4 SECONDS)
/// How long an overloaded machine buzzes before it goes.
#define COMMUNION_OVERLOAD_DELAY (4 SECONDS)
/// Radius and lifetime of the Silence bubble.
#define COMMUNION_JAM_RANGE 9
#define COMMUNION_JAM_DURATION (45 SECONDS)
/// How long a radio switched off by Cutout or Silence stays dead before it recovers.
#define COMMUNION_RADIO_OFF_DURATION (45 SECONDS)
/// Burn per full standard cell drained by Feedback Surge, and the ceiling on it.
#define COMMUNION_SURGE_PER_CELL 12
#define COMMUNION_SURGE_MAX 60
#define COMMUNION_SURGE_MIN 5

// =========================================================================
// THE WARFRAME
// =========================================================================

/mob/living/basic/vestige_warframe
	name = "the Warframe"
	desc = "A two-and-a-half metre sparring machine in clan lacquer, holding a blunted blade in a textbook guard. \
		Someone has scratched a tally into the plate on its chest and run out of room."
	gender = NEUTER

	icon = 'voidcrew/modules/antag_ruins/icons/warframe.dmi'
	icon_state = "warframe"
	icon_living = "warframe"
	icon_dead = "warframe_dead"
	mouse_opacity = MOUSE_OPACITY_ICON

	// Hand-copied boss tier. See the file header for why it is not inherited.
	maxHealth = 1400
	health = 1400
	melee_damage_lower = 20
	melee_damage_upper = 26
	armour_penetration = 25
	melee_attack_cooldown = 1.2 SECONDS
	obj_damage = 0 // it fights in the hall, not through it
	// Deliberate. It does not need to run you down; Iai does that.
	speed = 2.5
	combat_mode = TRUE
	status_flags = NONE
	mob_size = MOB_SIZE_LARGE
	mob_biotypes = MOB_ROBOTIC|MOB_HUMANOID
	faction = list(FACTION_HOSTILE)
	environment_smash = ENVIRONMENT_SMASH_NONE
	move_force = MOVE_FORCE_VERY_STRONG
	move_resist = MOVE_FORCE_VERY_STRONG
	pull_force = MOVE_FORCE_VERY_STRONG

	// A machine: nothing to poison, nothing to tire out, nothing to suffocate.
	// Heat is the one thing it minds.
	damage_coeff = list(BRUTE = 1, BURN = 1.15, TOX = 0, STAMINA = 0, OXY = 0)
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	minimum_survivable_temperature = 0
	maximum_survivable_temperature = INFINITY

	speak_emote = list("states")
	attack_verb_continuous = "strikes"
	attack_verb_simple = "strike"
	attack_sound = 'sound/items/weapons/bladeslice.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	death_message = "grounds its blade, straightens up, and stops."
	death_sound = 'sound/effects/magic/demon_dies.ogg'

	ai_controller = /datum/ai_controller/basic_controller/vestige_warframe

	/// Iai — the drawn cut.
	var/datum/action/cooldown/mob_cooldown/warframe_iai/iai
	/// The Standing Guard — the parry window.
	var/datum/action/cooldown/mob_cooldown/warframe_guard/guard
	/// Sweep of the Lower Hall — the arc.
	var/datum/action/cooldown/mob_cooldown/warframe_sweep/sweep
	/// Live Floor — second round only.
	var/datum/action/cooldown/mob_cooldown/warframe_live_floor/live_floor

	/// Which round of the match it is on. 2 is the last one.
	var/round_number = 1
	/// TRUE while it is committed to something: no walking, no swinging, no casting.
	var/committed = FALSE

	/// Running score of how the opponent has been fighting, capped at WARFRAME_READ_CAP.
	var/close_reads = 0
	/// The other half of the same score.
	var/far_reads = 0
	/// "close", "far", or null while it has not decided.
	var/current_read
	/// Rate limit on saying the read out loud.
	COOLDOWN_DECLARE(read_announce_cooldown)
	/// Restarted every tick it can see and reach its opponent.
	COOLDOWN_DECLARE(disengage_timer)
	/// Live Floor is locked out until this expires. Started by the hall breaker.
	COOLDOWN_DECLARE(brownout)

	/// Turf it calls home. Set on init; the leash hangs off it.
	var/turf/home_turf
	/// Invisible movable the leash component is anchored to.
	var/obj/effect/warframe_mark/home_mark

/mob/living/basic/vestige_warframe/Initialize(mapload)
	. = ..()
	add_traits(list(TRAIT_NOFIRE, TRAIT_NOBREATH, TRAIT_RESISTHIGHPRESSURE, TRAIT_RESISTLOWPRESSURE), INNATE_TRAIT)

	AddElement(/datum/element/footstep, FOOTSTEP_MOB_HEAVY)
	AddElement(/datum/element/relay_attackers)
	AddElement(/datum/element/ai_retaliate)

	iai = new(src)
	guard = new(src)
	sweep = new(src)
	live_floor = new(src)
	iai.Grant(src)
	guard.Grant(src)
	sweep.Grant(src)
	live_floor.Grant(src)

	// The controller is built inside /atom/Initialize, i.e. before any of the above
	// existed, so the kit has to be handed over now. Live Floor is deliberately held
	// back — the first round does not have it.
	var/datum/ai_controller/basic_controller/vestige_warframe/brain = ai_controller
	if(istype(brain))
		brain.register_kit(iai, guard, sweep)

	RegisterSignal(src, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_health_update))
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(immediate_aggro))

	COOLDOWN_START(src, disengage_timer, WARFRAME_DISENGAGE_GRACE)
	set_up_mark()

/mob/living/basic/vestige_warframe/Destroy()
	iai = null
	guard = null
	sweep = null
	live_floor = null
	home_turf = null
	QDEL_NULL(home_mark)
	return ..()

/**
 * Drops the leash anchor on its spawn turf.
 *
 * The leash component refuses a turf owner (leash.dm:35-37), so the anchor is an
 * invisible movable. Its recall is a plain `forceMove` (leash.dm:168), which is what
 * makes it safe inside the arena's NOTELEPORT area.
 */
/mob/living/basic/vestige_warframe/proc/set_up_mark()
	home_turf = get_turf(src)
	if(isnull(home_turf))
		return
	home_mark = new /obj/effect/warframe_mark(home_turf)
	// AddComponent is a variadic macro, so this has to stay on one line.
	AddComponent(/datum/component/leash, home_mark, WARFRAME_LEASH_RANGE, /obj/effect/temp_visual/small_smoke/halfsecond, /obj/effect/temp_visual/small_smoke/halfsecond)

/// Aggro whoever shoots it, even from outside its planning range.
/mob/living/basic/vestige_warframe/proc/immediate_aggro(datum/source, mob/attacker, flags)
	SIGNAL_HANDLER
	if(!isliving(attacker) || isnull(ai_controller) || stat)
		return
	if(ai_controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, attacker)

// =========================================================================
// COMMITTING
// =========================================================================

/**
 * Lock or unlock it for the length of a move.
 *
 * While committed it cannot walk, swing or start anything else. Iai still travels,
 * because `forceMove` does not care about TRAIT_IMMOBILIZED — that is the point of
 * using it. Every ability in the kit funnels through here so the "it is doing a thing
 * right now" state has exactly one owner.
 */
/mob/living/basic/vestige_warframe/proc/set_committed(locked)
	if(committed == locked)
		return
	committed = locked
	if(locked)
		ADD_TRAIT(src, TRAIT_IMMOBILIZED, WARFRAME_TRAIT)
		ai_controller?.CancelActions()
		return
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, WARFRAME_TRAIT)

/mob/living/basic/vestige_warframe/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	if(committed)
		return FALSE
	return ..()

// =========================================================================
// THE READ
// =========================================================================

/mob/living/basic/vestige_warframe/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(stat == DEAD)
		return
	var/atom/opponent = ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	take_a_read(opponent)
	handle_disengagement(opponent, seconds_per_tick)

/**
 * One sample of how the opponent is fighting.
 *
 * Both halves are capped and the losing half decays, so a fight that changes shape
 * changes the read within about ten seconds rather than being decided by the first
 * minute. Fighting from cover counts as fighting at range: if it cannot see you, it
 * assumes you are shooting.
 */
/mob/living/basic/vestige_warframe/proc/take_a_read(atom/opponent)
	if(QDELETED(opponent) || committed)
		return
	if(get_dist(src, opponent) <= WARFRAME_CLOSE_RANGE && can_see(src, opponent, WARFRAME_CLOSE_RANGE))
		close_reads = min(close_reads + 1, WARFRAME_READ_CAP)
		far_reads = max(far_reads - 1, 0)
	else
		far_reads = min(far_reads + 1, WARFRAME_READ_CAP)
		close_reads = max(close_reads - 1, 0)

	var/new_read = current_read
	if(close_reads - far_reads >= WARFRAME_READ_MARGIN)
		new_read = "close"
	else if(far_reads - close_reads >= WARFRAME_READ_MARGIN)
		new_read = "far"
	if(new_read == current_read)
		return
	current_read = new_read
	announce_read()

/// Says the new stance out loud. The fight is only fair if the rule is legible.
/mob/living/basic/vestige_warframe/proc/announce_read()
	if(!COOLDOWN_FINISHED(src, read_announce_cooldown))
		return
	COOLDOWN_START(src, read_announce_cooldown, WARFRAME_READ_ANNOUNCE_COOLDOWN)
	if(current_read == "close")
		say("You keep closing. Adjusting.")
	else
		say("You keep giving ground. Adjusting.")

/// Does the read currently favour the reach half of the kit?
/mob/living/basic/vestige_warframe/proc/reads_far()
	return current_read == "far"

/// Does the read currently favour the close half of the kit?
/mob/living/basic/vestige_warframe/proc/reads_close()
	return current_read == "close"

// =========================================================================
// ANTI-CHEESE
// =========================================================================

/**
 * Kite-and-plink and doorway cheese, killed the same way the Matriarch kills it. Lose
 * the opponent for [WARFRAME_DISENGAGE_GRACE] and it calls the round, walks the damage
 * back off at [WARFRAME_DISENGAGE_REPAIR] of max per second and waits. Between this and
 * the leash there is no version of this fight that happens in a corridor.
 */
/mob/living/basic/vestige_warframe/proc/handle_disengagement(atom/opponent, seconds_per_tick)
	if(is_engaged(opponent))
		COOLDOWN_START(src, disengage_timer, WARFRAME_DISENGAGE_GRACE)
		return
	if(!COOLDOWN_FINISHED(src, disengage_timer) || health >= maxHealth)
		return
	adjust_health(-(maxHealth * WARFRAME_DISENGAGE_REPAIR * seconds_per_tick))
	if(SPT_PROB(15, seconds_per_tick))
		visible_message(span_boldwarning("[src]'s plating grinds back into line. It is repairing itself."))

/// Is this opponent close enough, alive enough and visible enough to count?
/mob/living/basic/vestige_warframe/proc/is_engaged(atom/opponent)
	if(QDELETED(opponent))
		return FALSE
	if(isliving(opponent))
		var/mob/living/living_opponent = opponent
		if(living_opponent.stat == DEAD)
			return FALSE
	if(get_dist(src, opponent) > WARFRAME_DISENGAGE_RANGE)
		return FALSE
	return can_see(src, opponent, WARFRAME_DISENGAGE_RANGE)

/**
 * An EMP staggers it. It does not delete it.
 *
 * `/mob/living/basic/emp_act` hands any MOB_ROBOTIC basic mob `maxHealth` damage on a
 * heavy pulse (basic_defense.dm:171-184), so without this override one ion rifle shot
 * ends the capstone fight instantly. Bringing EMP is still worth doing — it buys a real
 * opening — it just is not an "I win" button.
 */
/mob/living/basic/vestige_warframe/emp_reaction(severity)
	var/damage = (severity == EMP_HEAVY) ? (maxHealth * 0.08) : (maxHealth * 0.04)
	apply_damage(damage, BURN)
	visible_message(span_boldwarning("[src] locks up mid-stance, servos whining."))
	playsound(src, 'sound/effects/empulse.ogg', 60, TRUE)
	do_sparks(4, FALSE, src)
	set_committed(TRUE)
	ai_controller?.PauseAi(WARFRAME_BREAKER_STAGGER)
	addtimer(CALLBACK(src, PROC_REF(set_committed), FALSE), WARFRAME_BREAKER_STAGGER, TIMER_UNIQUE|TIMER_OVERRIDE)

// =========================================================================
// THE SECOND ROUND
// =========================================================================

/mob/living/basic/vestige_warframe/proc/on_health_update(datum/source)
	SIGNAL_HANDLER
	if(stat == DEAD || round_number >= 2)
		return
	if(health > maxHealth * WARFRAME_SECOND_ROUND_THRESHOLD)
		return
	// say/playsound/visible_message are not safe from a SIGNAL_HANDLER, so hand off.
	INVOKE_ASYNC(src, PROC_REF(begin_second_round))

/**
 * Half health. It steps back, bows, and stops pacing itself: Live Floor comes online,
 * every cooldown drops by 30%, the blade comes up and the guard starts catching bullets.
 * One-time, with a real beat to it.
 */
/mob/living/basic/vestige_warframe/proc/begin_second_round()
	if(round_number >= 2)
		return
	round_number = 2

	visible_message(span_boldwarning("[src] steps back out of measure and bows, exactly as deep as the rules require."))
	say("Second round.")
	playsound(src, 'sound/machines/terminal/terminal_on.ogg', 80, TRUE)
	playsound(src, 'sound/items/weapons/sear.ogg', 70, TRUE)
	for(var/mob/living/witness in view(7, src))
		shake_camera(witness, 2, 1)

	add_filter(WARFRAME_ROUND_FILTER, 2, list("type" = "outline", "color" = COLOR_VIVID_RED, "alpha" = 0, "size" = 1))
	var/round_filter = get_filter(WARFRAME_ROUND_FILTER)
	if(round_filter)
		animate(round_filter, alpha = 200, time = 0.5 SECONDS, loop = -1)
		animate(alpha = 0, time = 0.5 SECONDS)

	// Untouchable for the length of the bow, so nobody misses the tell.
	add_traits(list(TRAIT_GODMODE, TRAIT_IMMOBILIZED), WARFRAME_TRAIT)
	ai_controller?.PauseAi(WARFRAME_ROUND_CHANGE_TIME)
	addtimer(CALLBACK(src, PROC_REF(end_round_change)), WARFRAME_ROUND_CHANGE_TIME, TIMER_UNIQUE|TIMER_OVERRIDE)

	melee_damage_lower = 28
	melee_damage_upper = 36
	armour_penetration = 40
	set_varspeed(1.8)

	for(var/datum/action/cooldown/ability as anything in list(iai, guard, sweep, live_floor))
		if(isnull(ability))
			continue
		ability.cooldown_time = round(ability.cooldown_time * WARFRAME_SECOND_ROUND_COOLDOWN_SCALE, 0.1)

	// The floor is a second-round weapon, so the key only goes up now.
	var/datum/ai_controller/basic_controller/vestige_warframe/brain = ai_controller
	if(istype(brain) && !QDELETED(live_floor))
		brain.set_blackboard_key(BB_WARFRAME_LIVE_FLOOR, live_floor)

/mob/living/basic/vestige_warframe/proc/end_round_change()
	remove_traits(list(TRAIT_GODMODE, TRAIT_IMMOBILIZED), WARFRAME_TRAIT)

// =========================================================================
// THE GUARD, ON THE MOB SIDE
// =========================================================================

/// Is it holding guard right now?
/mob/living/basic/vestige_warframe/proc/is_guarding()
	return !isnull(has_status_effect(/datum/status_effect/warframe_guard))

/**
 * Second-round guard catches bullets too.
 *
 * `check_block` is never called for projectiles hitting a basic mob (that path only
 * exists on `/mob/living/carbon/human`, human_defense.dm:67), so the status effect
 * cannot see them from its side and this has to be done here.
 */
/mob/living/basic/vestige_warframe/bullet_act(obj/projectile/proj, def_zone, piercing_hit = FALSE, blocked = 0)
	if(round_number >= 2 && is_guarding())
		visible_message(span_warning("[src] turns [proj] aside without moving its feet."))
		playsound(src, 'sound/items/weapons/parry.ogg', 60, TRUE)
		return BULLET_ACT_BLOCK
	return ..()

// =========================================================================
// DEATH
// =========================================================================

/mob/living/basic/vestige_warframe/death(gibbed)
	remove_filter(WARFRAME_ROUND_FILTER)
	remove_filter(WARFRAME_GUARD_FILTER)
	set_committed(FALSE)
	. = ..()
	if(gibbed)
		return
	drop_the_match()

/**
 * The drops.
 *
 * Same shape as the Matriarch's: one guaranteed piece so the kill is always worth
 * something, then a jackpot rolled from a pool where both entries hand you a piece of
 * what just beat you. The capstone itself is paid out by the ascension run, not here.
 */
/mob/living/basic/vestige_warframe/proc/drop_the_match()
	var/atom/spot = drop_location()
	if(isnull(spot))
		return
	new /obj/item/sparring_blade(spot)
	var/static/list/jackpot_pool = list(
		/obj/item/warframe_contact_plate,
		/obj/item/warframe_actuator,
	)
	var/jackpot_type = pick(jackpot_pool)
	new jackpot_type(spot)
	visible_message(span_boldnotice("Something inside [src] unlatches and drops out onto the mat."))

// =========================================================================
// AI
// =========================================================================

/**
 * Its controller.
 *
 * `idle_behavior` is null on purpose: it stands in the middle of the hall until somebody
 * walks in. The rotation subtree is where the whole personality lives — see
 * [/datum/ai_planning_subtree/warframe_rotation].
 */
/datum/ai_controller/basic_controller/vestige_warframe
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_AGGRO_RANGE = 12,
		BB_WARFRAME_LAST_ABILITY = null,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = null
	planning_subtrees = list(
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/warframe_rotation,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree/warframe,
	)

/**
 * Publishes the first-round kit onto the blackboard.
 *
 * Called from its Initialize, because the controller is built inside /atom/Initialize —
 * i.e. before it has created a single action — so the keys cannot be seeded above.
 * Live Floor is registered later, by [/mob/living/basic/vestige_warframe/proc/begin_second_round].
 */
/datum/ai_controller/basic_controller/vestige_warframe/proc/register_kit(
	datum/action/cooldown/iai,
	datum/action/cooldown/guard,
	datum/action/cooldown/sweep,
)
	set_blackboard_key(BB_WARFRAME_IAI, iai)
	set_blackboard_key(BB_WARFRAME_GUARD, guard)
	set_blackboard_key(BB_WARFRAME_SWEEP, sweep)

/**
 * The rotation. One ability per plan at most, never the same one twice running, and
 * weighted by the read: it leans on the closer and the floor against somebody who keeps
 * backing off, and on the guard and the sweep against somebody who stands in its face.
 *
 * The weights are soft. Everything stays in the pool at [WARFRAME_BASE_WEIGHT] whatever
 * the read says, so the fight never becomes one move on a loop.
 */
/datum/ai_planning_subtree/warframe_rotation
	/// It will not spend a cooldown on somebody further away than this.
	var/engagement_range = 9

/datum/ai_planning_subtree/warframe_rotation/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/vestige_warframe/warframe = controller.pawn
	if(!istype(warframe))
		return
	if(warframe.committed)
		// Mid-move. No walking, no swinging, nothing queued on top.
		return SUBTREE_RETURN_FINISH_PLANNING
	if(warframe.stat != CONSCIOUS)
		return

	var/atom/opponent = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(opponent))
		return
	if(isliving(opponent))
		var/mob/living/living_opponent = opponent
		if(living_opponent.stat == DEAD)
			return
	if(get_dist(warframe, opponent) > engagement_range)
		return

	var/last_used = controller.blackboard[BB_WARFRAME_LAST_ABILITY]
	var/list/options = list()
	for(var/ability_key as anything in list(BB_WARFRAME_IAI, BB_WARFRAME_GUARD, BB_WARFRAME_SWEEP, BB_WARFRAME_LIVE_FLOOR))
		if(ability_key == last_used)
			continue
		var/datum/action/cooldown/ability = controller.blackboard[ability_key]
		if(!ability?.IsAvailable())
			continue
		options[ability_key] = WARFRAME_BASE_WEIGHT + read_bonus(warframe, ability_key)
	if(!length(options))
		return

	var/chosen_key = pick_weight(options)
	controller.set_blackboard_key(BB_WARFRAME_LAST_ABILITY, chosen_key)
	controller.queue_behavior(/datum/ai_behavior/targeted_mob_ability, chosen_key, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Extra weight this ability gets from the current read.
/datum/ai_planning_subtree/warframe_rotation/proc/read_bonus(mob/living/basic/vestige_warframe/warframe, ability_key)
	switch(ability_key)
		if(BB_WARFRAME_IAI, BB_WARFRAME_LIVE_FLOOR)
			return warframe.reads_far() ? WARFRAME_READ_WEIGHT : 0
		if(BB_WARFRAME_GUARD, BB_WARFRAME_SWEEP)
			return warframe.reads_close() ? WARFRAME_READ_WEIGHT : 0
	return 0

/// It does not swing while it is committed to something.
/datum/ai_planning_subtree/basic_melee_attack_subtree/warframe

/datum/ai_planning_subtree/basic_melee_attack_subtree/warframe/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/vestige_warframe/warframe = controller.pawn
	if(istype(warframe) && warframe.committed)
		return
	return ..()

// =========================================================================
// IAI — THE DRAWN CUT
// =========================================================================

/**
 * The anti-kite. It fixes a line, paints every tile of it, and a beat later travels the
 * whole thing in about a second, cutting everything standing on it.
 *
 * The line is locked in at cast, so the dodge is a single step off it during the
 * telegraph. Dodging is properly rewarded: it finishes the cut where you used to be and
 * stands there for [WARFRAME_IAI_RECOVERY] unable to do anything at all.
 */
/datum/action/cooldown/mob_cooldown/warframe_iai
	name = "Iai"
	desc = "Fix a line up to nine tiles long and cut down it. 30 brute and a knockdown to everything standing on it. Step off the line before it moves."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
	cooldown_time = 15 SECONDS
	melee_cooldown_time = 0
	shared_cooldown = NONE
	click_to_activate = TRUE

/datum/action/cooldown/mob_cooldown/warframe_iai/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/vestige_warframe/warframe = owner
	return !istype(warframe) || !warframe.committed

/datum/action/cooldown/mob_cooldown/warframe_iai/Activate(atom/target)
	if(!isliving(owner) || isnull(target))
		return FALSE
	var/turf/aim_at = get_turf(target)
	var/turf/here = get_turf(owner)
	if(isnull(aim_at) || isnull(here) || aim_at == here)
		return FALSE
	if(get_dist(here, aim_at) > WARFRAME_IAI_RANGE)
		return FALSE

	var/list/path = build_path(here, aim_at)
	if(!length(path))
		return FALSE

	StartCooldown()
	var/mob/living/caster = owner
	caster.face_atom(aim_at)
	caster.visible_message(span_boldwarning("[caster] drops its shoulder and sights straight down the line at [target]."))
	playsound(caster, 'sound/items/weapons/sear.ogg', 65, TRUE)
	for(var/turf/marked as anything in path)
		new /obj/effect/temp_visual/warframe_line(marked, WARFRAME_IAI_TELEGRAPH)
	commit(TRUE)
	addtimer(CALLBACK(src, PROC_REF(cut), path, 1), WARFRAME_IAI_TELEGRAPH)
	return TRUE

/// The tiles the cut will cover: everything from the caster to the aim point, stopping
/// at the first thing it cannot pass through.
/datum/action/cooldown/mob_cooldown/warframe_iai/proc/build_path(turf/here, turf/aim_at)
	var/list/path = list()
	for(var/turf/step_turf as anything in get_line(here, aim_at))
		if(step_turf == here)
			continue
		if(step_turf.is_blocked_turf(exclude_mobs = TRUE))
			break
		path += step_turf
	return path

/// One tile of the cut, then the next. Timer-driven rather than a sleeping loop, so the
/// AI planner is never sitting inside it.
/datum/action/cooldown/mob_cooldown/warframe_iai/proc/cut(list/path, index)
	var/mob/living/caster = owner
	if(QDELETED(caster) || caster.stat == DEAD)
		release()
		return
	if(index > length(path))
		finish_cut()
		return

	var/turf/step_turf = path[index]
	if(QDELETED(step_turf) || step_turf.is_blocked_turf(exclude_mobs = TRUE))
		finish_cut()
		return

	if(index == 1)
		playsound(caster, 'sound/items/weapons/bladeslice.ogg', 75, TRUE)
	new /obj/effect/temp_visual/decoy/fading(caster.loc, caster)
	caster.forceMove(step_turf)
	for(var/mob/living/victim in step_turf)
		if(victim == caster || victim.stat == DEAD)
			continue
		strike(victim, caster)
	addtimer(CALLBACK(src, PROC_REF(cut), path, index + 1), WARFRAME_IAI_STEP_DELAY)

/// One person caught on the line.
/datum/action/cooldown/mob_cooldown/warframe_iai/proc/strike(mob/living/victim, mob/living/caster)
	victim.apply_damage(WARFRAME_IAI_DAMAGE, BRUTE, spread_damage = TRUE)
	victim.Knockdown(WARFRAME_IAI_KNOCKDOWN)
	to_chat(victim, span_userdanger("[caster] goes straight through where you were standing!"))
	playsound(victim, 'sound/items/weapons/bladeslice.ogg', 70, TRUE)

/// Cut's over. It stands in the follow-through, wide open.
/datum/action/cooldown/mob_cooldown/warframe_iai/proc/finish_cut()
	var/mob/living/caster = owner
	if(!QDELETED(caster) && caster.stat != DEAD)
		caster.visible_message(span_boldwarning("[caster] holds the follow-through, blade out, feet planted."))
		caster.Shake(pixelshiftx = 1, pixelshifty = 0, duration = WARFRAME_IAI_RECOVERY)
	addtimer(CALLBACK(src, PROC_REF(release)), WARFRAME_IAI_RECOVERY)

/datum/action/cooldown/mob_cooldown/warframe_iai/proc/release()
	commit(FALSE)

/// Lock or unlock the caster. Safe on a non-Warframe owner, so the loot actuator can
/// ride this whole ability without pretending to be a boss.
/datum/action/cooldown/mob_cooldown/warframe_iai/proc/commit(locked)
	var/mob/living/basic/vestige_warframe/warframe = owner
	if(!istype(warframe))
		return
	warframe.set_committed(locked)

// =========================================================================
// THE STANDING GUARD
// =========================================================================

/**
 * The signature, and the reason it reads as a duelist rather than a monster.
 *
 * It raises guard and stops doing anything else. Every melee attack that lands during
 * the window is deflected outright and answered with a counter. The counterplay is to
 * stop attacking for three and a half seconds, which is a genuinely hard habit to break
 * mid-fight and costs nothing but patience.
 *
 * The window is also its own weakness: it cannot move, swing or cast for any of it, so a
 * player who reads the tell gets a free reposition, a free reload, or in the first round
 * a free burst of ranged damage. In the second round the guard catches bullets too and
 * the only right answer is to wait.
 *
 * The deflection itself lives on [/datum/status_effect/warframe_guard] rather than here,
 * because the sparring blade in the drop pool applies exactly the same effect to a
 * player. One code path, two callers.
 */
/datum/action/cooldown/mob_cooldown/warframe_guard
	name = "The Standing Guard"
	desc = "Raise guard for 3.5 seconds. Melee attacks are deflected and answered with a 22 brute counter, and you cannot move, attack or cast while it is up."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
	cooldown_time = 24 SECONDS
	melee_cooldown_time = 0
	shared_cooldown = NONE
	click_to_activate = FALSE
	/// How long the guard is held.
	var/guard_duration = WARFRAME_GUARD_DURATION

/datum/action/cooldown/mob_cooldown/warframe_guard/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/vestige_warframe/warframe = owner
	return !istype(warframe) || !warframe.committed

/datum/action/cooldown/mob_cooldown/warframe_guard/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	StartCooldown()
	var/mob/living/caster = owner
	caster.visible_message(
		span_boldwarning("[caster] brings the blade up flat and stops moving. It is waiting for you to swing."),
		span_boldwarning("You raise guard."),
	)
	caster.balloon_alert_to_viewers("guard up!")
	playsound(caster, 'sound/items/weapons/parry.ogg', 70, TRUE)

	var/mob/living/basic/vestige_warframe/warframe = owner
	var/datum/status_effect/warframe_guard/stance = caster.apply_status_effect(/datum/status_effect/warframe_guard, guard_duration)
	if(istype(warframe))
		warframe.set_committed(TRUE)
		if(stance && warframe.round_number >= 2)
			stance.deflects_ranged = TRUE
		addtimer(CALLBACK(warframe, TYPE_PROC_REF(/mob/living/basic/vestige_warframe, set_committed), FALSE), guard_duration)
	return TRUE

/**
 * Guard, as a thing that can sit on anybody.
 *
 * Hangs off COMSIG_LIVING_CHECK_BLOCK, which `/mob/living/attacked_by` fires for item
 * melee (item_attack.dm:341), `/mob/living/basic/attack_hand` fires for punches
 * (basic_defense.dm:26) and `/mob/living/hitby` fires for thrown things. Projectiles only
 * route through it on humans, so a basic-mob owner that wants to catch bullets has to
 * handle `bullet_act` itself — the Warframe does.
 */
/datum/status_effect/warframe_guard
	id = "warframe_guard"
	duration = WARFRAME_GUARD_DURATION
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/warframe_guard
	/// Whether it turns projectiles aside as well as blades.
	var/deflects_ranged = FALSE
	/// Brute the counter deals.
	var/riposte_damage = WARFRAME_RIPOSTE_DAMAGE
	/// Rate limit on the counter.
	COOLDOWN_DECLARE(riposte_cooldown)

/datum/status_effect/warframe_guard/on_creation(mob/living/new_owner, set_duration)
	if(isnum(set_duration))
		duration = set_duration
	return ..()

/datum/status_effect/warframe_guard/on_apply()
	RegisterSignal(owner, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(on_check_block))
	owner.add_filter(WARFRAME_GUARD_FILTER, 2, list("type" = "outline", "color" = COLOR_WHITE, "size" = 1))
	return TRUE

/datum/status_effect/warframe_guard/on_remove()
	UnregisterSignal(owner, COMSIG_LIVING_CHECK_BLOCK)
	owner.remove_filter(WARFRAME_GUARD_FILTER)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.visible_message(span_warning("[owner] lets the guard drop."))
	return ..()

/// Signal proc for [COMSIG_LIVING_CHECK_BLOCK]. Turns the hit aside and counters.
/datum/status_effect/warframe_guard/proc/on_check_block(
	mob/living/source,
	atom/hit_by,
	damage = 0,
	attack_text = "the attack",
	attack_type = MELEE_ATTACK,
	armour_penetration = 0,
	damage_type = BRUTE,
)
	SIGNAL_HANDLER
	if(attack_type == PROJECTILE_ATTACK && !deflects_ranged)
		return
	// Shoves and stamina pokes are not a duel. Let them through so a disarm still reads.
	if(attack_type == LEAP_ATTACK)
		return
	INVOKE_ASYNC(src, PROC_REF(deflect), hit_by, attack_text)
	return SUCCESSFUL_BLOCK

/// The parry and the counter. Async — it messages, plays sound and hurts people.
/datum/status_effect/warframe_guard/proc/deflect(atom/hit_by, attack_text)
	if(QDELETED(owner))
		return
	playsound(owner, 'sound/items/weapons/parry.ogg', 75, TRUE)
	owner.visible_message(span_warning("[owner] turns [attack_text] aside without stepping."))

	var/mob/living/attacker = ismob(hit_by) ? hit_by : get(hit_by, /mob/living)
	if(!isliving(attacker) || attacker == owner || attacker.stat == DEAD)
		return
	if(!COOLDOWN_FINISHED(src, riposte_cooldown))
		return
	COOLDOWN_START(src, riposte_cooldown, WARFRAME_RIPOSTE_INTERVAL)

	attacker.apply_damage(riposte_damage, BRUTE, spread_damage = TRUE)
	attacker.Knockdown(0.8 SECONDS)
	to_chat(attacker, span_userdanger("[owner] answers your swing before you have finished it!"))
	playsound(attacker, 'sound/items/weapons/bladeslice.ogg', 70, TRUE)
	var/throw_dir = get_dir(owner, attacker)
	if(!throw_dir)
		return
	var/atom/landing = get_edge_target_turf(attacker, throw_dir)
	attacker.safe_throw_at(landing, 1, 1, owner)

/atom/movable/screen/alert/status_effect/warframe_guard
	name = "Guard Up"
	desc = "Your guard is up. Melee attacks against you are deflected and answered."
	icon_state = "radiation_shield"

// =========================================================================
// SWEEP OF THE LOWER HALL
// =========================================================================

/**
 * The anti-hug. A wide arc in whatever direction it is facing, telegraphed on the floor,
 * that throws whoever is in it three tiles clear.
 *
 * Sightline-gated on purpose: a pillar between you and it is a real answer, which is why
 * the arena has pillars.
 */
/datum/action/cooldown/mob_cooldown/warframe_sweep
	name = "Sweep of the Lower Hall"
	desc = "Sweep a wide arc in front out to three tiles. 26 brute, and it throws you three tiles back and knocks you down. Get behind it or get out of range."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
	cooldown_time = 17 SECONDS
	melee_cooldown_time = 0
	shared_cooldown = NONE
	click_to_activate = TRUE

/datum/action/cooldown/mob_cooldown/warframe_sweep/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/vestige_warframe/warframe = owner
	return !istype(warframe) || !warframe.committed

/datum/action/cooldown/mob_cooldown/warframe_sweep/Activate(atom/target)
	if(!isliving(owner) || isnull(target))
		return FALSE
	var/turf/aim_at = get_turf(target)
	var/turf/here = get_turf(owner)
	if(isnull(aim_at) || isnull(here) || aim_at == here)
		return FALSE

	var/list/arc = build_arc(here, aim_at)
	if(!length(arc))
		return FALSE

	StartCooldown()
	var/mob/living/caster = owner
	caster.face_atom(aim_at)
	caster.visible_message(span_boldwarning("[caster] winds the blade back across its body."))
	playsound(caster, 'sound/effects/servostep.ogg', 70, TRUE)
	for(var/turf/marked as anything in arc)
		new /obj/effect/temp_visual/warframe_arc(marked, WARFRAME_SWEEP_TELEGRAPH)
	commit(TRUE)
	addtimer(CALLBACK(src, PROC_REF(land), arc, here), WARFRAME_SWEEP_TELEGRAPH)
	return TRUE

/// Every tile inside the arc that it can actually see.
/datum/action/cooldown/mob_cooldown/warframe_sweep/proc/build_arc(turf/here, turf/aim_at)
	var/list/arc = list()
	var/facing_angle = get_angle(here, aim_at)
	for(var/turf/candidate as anything in RANGE_TURFS(WARFRAME_SWEEP_RADIUS, here))
		if(candidate == here)
			continue
		if(get_dist(here, candidate) > WARFRAME_SWEEP_RADIUS)
			continue
		if(abs(closer_angle_difference(facing_angle, get_angle(here, candidate))) > WARFRAME_SWEEP_ARC)
			continue
		if(!can_see(here, candidate, WARFRAME_SWEEP_RADIUS))
			continue
		arc += candidate
	return arc

/// The blade arrives.
/datum/action/cooldown/mob_cooldown/warframe_sweep/proc/land(list/arc, turf/here)
	var/mob/living/caster = owner
	if(QDELETED(caster) || caster.stat == DEAD)
		commit(FALSE)
		return
	playsound(caster, 'sound/items/weapons/smash.ogg', 85, TRUE)
	for(var/turf/hit_turf as anything in arc)
		if(QDELETED(hit_turf))
			continue
		for(var/mob/living/victim in hit_turf)
			if(victim == caster || victim.stat == DEAD)
				continue
			hurl(victim, caster, here)
	commit(FALSE)

/// One person caught by the sweep.
/datum/action/cooldown/mob_cooldown/warframe_sweep/proc/hurl(mob/living/victim, mob/living/caster, turf/here)
	victim.apply_damage(WARFRAME_SWEEP_DAMAGE, BRUTE, spread_damage = TRUE)
	victim.Knockdown(1.5 SECONDS)
	victim.visible_message(
		span_boldwarning("[caster]'s blade catches [victim] across the middle and launches [victim.p_them()]!"),
		span_userdanger("The sweep takes you off your feet and throws you across the hall!"),
	)
	playsound(victim, 'sound/effects/gravhit.ogg', 70, TRUE)
	var/throw_dir = get_dir(here, victim) || pick(GLOB.cardinals)
	var/atom/landing = get_edge_target_turf(victim, throw_dir)
	victim.safe_throw_at(landing, WARFRAME_SWEEP_THROW, 1, caster)

/datum/action/cooldown/mob_cooldown/warframe_sweep/proc/commit(locked)
	var/mob/living/basic/vestige_warframe/warframe = owner
	if(!istype(warframe))
		return
	warframe.set_committed(locked)

// =========================================================================
// LIVE FLOOR
// =========================================================================

/**
 * The second-round move, and the one that makes the hall itself part of the fight: it
 * puts a hand on the deck and pushes the hall's own contact plates live under you.
 *
 * Nothing about it needs the capstone. It is footwork, and the plates are painted a full
 * second and a half before they bite.
 */
/datum/action/cooldown/mob_cooldown/warframe_live_floor
	name = "Live Floor"
	desc = "Energise a scatter of deck plates around the target for 5 seconds. Standing on one is 18 burn and a knockdown."
	button_icon = 'icons/mob/actions/actions_AI.dmi'
	button_icon_state = "blackout"
	cooldown_time = 20 SECONDS
	melee_cooldown_time = 0
	shared_cooldown = NONE
	click_to_activate = TRUE

/datum/action/cooldown/mob_cooldown/warframe_live_floor/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/vestige_warframe/warframe = owner
	if(!istype(warframe))
		return TRUE
	if(warframe.committed)
		return FALSE
	// The hall breaker cuts this and nothing else. That is the whole reward for pulling it.
	return COOLDOWN_FINISHED(warframe, brownout)

/datum/action/cooldown/mob_cooldown/warframe_live_floor/Activate(atom/target)
	if(!isliving(owner) || isnull(target))
		return FALSE
	var/turf/centre = get_turf(target)
	if(isnull(centre))
		return FALSE
	var/list/plates = pick_plates(centre)
	if(!length(plates))
		return FALSE

	StartCooldown()
	var/mob/living/caster = owner
	caster.visible_message(span_boldwarning("[caster] puts a hand flat on the deck. Something under the floor starts humming."))
	playsound(caster, 'sound/machines/terminal/terminal_on.ogg', 75, TRUE)
	for(var/turf/marked as anything in plates)
		new /obj/effect/temp_visual/warframe_arc(marked, WARFRAME_PLATE_TELEGRAPH)
	addtimer(CALLBACK(src, PROC_REF(energise), plates), WARFRAME_PLATE_TELEGRAPH)
	return TRUE

/// Scattered rather than a shape, deliberately: it is a footwork problem, not a maze.
/datum/action/cooldown/mob_cooldown/warframe_live_floor/proc/pick_plates(turf/centre)
	var/turf/caster_turf = get_turf(owner)
	var/list/candidates = list()
	for(var/turf/open/candidate in RANGE_TURFS(WARFRAME_PLATE_RADIUS, centre))
		if(candidate == caster_turf)
			continue
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		candidates += candidate
	if(!length(candidates))
		return list()
	candidates = shuffle(candidates)
	var/wanted = min(WARFRAME_PLATE_COUNT, length(candidates))
	return candidates.Copy(1, wanted + 1)

/datum/action/cooldown/mob_cooldown/warframe_live_floor/proc/energise(list/plates)
	if(QDELETED(owner))
		return
	playsound(owner, 'sound/effects/magic/lightningbolt.ogg', 70, TRUE)
	for(var/turf/plate_turf as anything in plates)
		if(QDELETED(plate_turf))
			continue
		new /obj/effect/warframe_live_plate(plate_turf, owner)

// =========================================================================
// FIELD OBJECTS AND TELEGRAPHS
// =========================================================================

/**
 * A deck plate with the hall's power running through it. Spawned by Live Floor and by
 * the contact plate in the drop pool — one implementation, two callers, so retuning the
 * numbers here retunes both.
 *
 * Pass whoever put it down as the second `new` argument; they walk over their own plates.
 */
/obj/effect/warframe_live_plate
	name = "live plate"
	desc = "A deck plate with far too much power running through it. It is buzzing."
	icon = 'icons/effects/effects.dmi'
	icon_state = "electricity3"
	alpha = 190
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	light_range = 1.5
	light_power = 0.6
	light_color = COLOR_LIGHT_ORANGE
	/// How long the plate stays live.
	var/plate_duration = WARFRAME_PLATE_DURATION
	/// Burn dealt per shock.
	var/plate_damage = WARFRAME_PLATE_DAMAGE
	/// Whoever energised it. Never shocked by it.
	var/datum/weakref/creator_ref
	/// Last shock time per victim (weakref -> world.time), so walking across is not a stunlock.
	var/list/recently_shocked = list()

/obj/effect/warframe_live_plate/Initialize(mapload, mob/living/creator)
	. = ..()
	if(!isnull(creator))
		creator_ref = WEAKREF(creator)
	playsound(src, SFX_SPARKS, 30, TRUE)
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)
	START_PROCESSING(SSfastprocess, src)
	QDEL_IN(src, plate_duration)

/obj/effect/warframe_live_plate/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	creator_ref = null
	recently_shocked = null
	return ..()

/obj/effect/warframe_live_plate/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(isliving(arrived))
		INVOKE_ASYNC(src, PROC_REF(bite), arrived)

/obj/effect/warframe_live_plate/process(seconds_per_tick)
	for(var/mob/living/standing in loc)
		bite(standing)

/// Shock whoever is standing on us, at most once every [WARFRAME_PLATE_REFRACTORY].
/obj/effect/warframe_live_plate/proc/bite(mob/living/victim)
	if(QDELETED(victim) || victim.stat == DEAD)
		return
	if(victim == creator_ref?.resolve())
		return
	var/datum/weakref/key = WEAKREF(victim)
	var/last = recently_shocked?[key]
	if(last && world.time < last + WARFRAME_PLATE_REFRACTORY)
		return
	LAZYSET(recently_shocked, key, world.time)
	// SHOCK_NOGLOVES: the current is coming up through the deck, not through a wire
	// you could be insulated from.
	victim.electrocute_act(plate_damage, src, flags = SHOCK_NOGLOVES|SHOCK_KNOCKDOWN)
	to_chat(victim, span_userdanger("The plate under you is live!"))

/// The line Iai is about to travel.
/obj/effect/temp_visual/warframe_line
	icon = 'icons/mob/telegraphing/telegraph_holographic.dmi'
	icon_state = "target_box"
	color = COLOR_VIVID_RED
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	randomdir = FALSE
	duration = WARFRAME_IAI_TELEGRAPH

/obj/effect/temp_visual/warframe_line/Initialize(mapload, new_duration)
	if(new_duration)
		duration = new_duration
	return ..()

/// Floor paint for the sweep and for Live Floor.
/obj/effect/temp_visual/warframe_arc
	icon = 'icons/mob/telegraphing/telegraph.dmi'
	icon_state = "blank_semi_transparent"
	color = COLOR_ORANGE
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	randomdir = FALSE
	duration = WARFRAME_SWEEP_TELEGRAPH

/obj/effect/temp_visual/warframe_arc/Initialize(mapload, new_duration)
	if(new_duration)
		duration = new_duration
	return ..()

/**
 * Invisible movable the leash component hangs off.
 *
 * `/datum/component/leash` requires a movable owner and rejects turfs outright
 * (leash.dm:35-37), so the Warframe drops one of these on its spawn turf at init.
 */
/obj/effect/warframe_mark
	name = "hall mark"
	desc = "You should not be able to see this."
	icon = null
	icon_state = null
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	density = FALSE
	move_resist = INFINITY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

// =========================================================================
// THE HALL'S OWN MACHINERY
// =========================================================================

/**
 * Levers. Deliberately structures rather than machinery.
 *
 * The arena area is `requires_power = FALSE`, so a powered gate would in fact work —
 * but these are one-shot set pieces with one job each, and a gate that cannot be
 * de-powered, EMPed or hacked shut is a gate that cannot strand a supplicant in the
 * approach with the clock running. The gate is destructible as a second way out.
 */
/obj/structure/warframe_lever
	name = "hall lever"
	desc = "A long mechanical lever set into the wall. No wiring, no keypad, no card reader. You just pull it."
	icon = 'icons/obj/machines/wallmounts.dmi'
	icon_state = "crema_switch"
	anchored = TRUE
	density = FALSE
	max_integrity = 200
	/// TRUE once it has been pulled and has not reset.
	var/pulled = FALSE

/obj/structure/warframe_lever/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(pulled)
		balloon_alert(user, "already down!")
		return TRUE
	pulled = TRUE
	playsound(src, 'sound/machines/airlock/boltsdown.ogg', 60, TRUE)
	on_pulled(user)
	return TRUE

/// What this lever actually does. Overridden per subtype.
/obj/structure/warframe_lever/proc/on_pulled(mob/living/user)
	return

/// Directional variants, so the lever sits on the wall it belongs to rather than in the
/// middle of the tile. Mapping helper only; the behaviour is identical.
/obj/structure/warframe_lever/north
	pixel_y = 26

/obj/structure/warframe_lever/south
	pixel_y = -26

/obj/structure/warframe_lever/east
	pixel_x = 26

/obj/structure/warframe_lever/west
	pixel_x = -26

/**
 * The gate lever, in the generator room off the equipment hall. Pulling it opens every
 * hall gate on the map and stays down.
 */
/obj/structure/warframe_lever/gate
	name = "hall gate lever"
	desc = "The lever that raises the gates into the lower hall. Someone has hung a wooden sign off it reading 'ONE AT A TIME'."

/obj/structure/warframe_lever/gate/north
	pixel_y = 26

/obj/structure/warframe_lever/gate/south
	pixel_y = -26

/obj/structure/warframe_lever/gate/east
	pixel_x = 26

/obj/structure/warframe_lever/gate/west
	pixel_x = -26

/obj/structure/warframe_lever/gate/on_pulled(mob/living/user)
	var/turf/here = get_turf(src)
	if(isnull(here))
		return
	// Reservations share a z-level with every other reservation in the round, so the
	// sweep is z-gated. Two arenas loaded at once must not open each other's gates.
	var/opened = 0
	for(var/obj/structure/warframe_gate/gate as anything in GLOB.warframe_gates)
		if(QDELETED(gate))
			continue
		var/turf/gate_turf = get_turf(gate)
		if(isnull(gate_turf) || gate_turf.z != here.z)
			continue
		gate.raise()
		opened++
	if(opened)
		visible_message(span_boldnotice("Somewhere below, something heavy slides up into the ceiling."))
	else
		balloon_alert(user, "nothing answers")

/**
 * The in-fight lever, on the wall of the lower hall itself.
 *
 * Pulling it drops the hall's power for a moment: the Warframe locks up, and it cannot
 * use Live Floor again until the current comes back. It resets itself after a minute, so
 * it is a resource to time rather than a switch to spam, and the fight is entirely
 * winnable by somebody who never touches it.
 */
/obj/structure/warframe_lever/breaker
	name = "hall breaker"
	desc = "The breaker for the lower hall's floor circuit. Pulling it kills the current under the mats. It winds itself back up on a spring, so it will not stay down."

/obj/structure/warframe_lever/breaker/north
	pixel_y = 26

/obj/structure/warframe_lever/breaker/south
	pixel_y = -26

/obj/structure/warframe_lever/breaker/east
	pixel_x = 26

/obj/structure/warframe_lever/breaker/west
	pixel_x = -26

/obj/structure/warframe_lever/breaker/on_pulled(mob/living/user)
	visible_message(span_boldnotice("The breaker slams down. Every light in the hall drops to half."))
	playsound(src, 'sound/machines/terminal/terminal_off.ogg', 70, TRUE)
	for(var/mob/living/basic/vestige_warframe/warframe in view(WARFRAME_DISENGAGE_RANGE, src))
		if(warframe.stat == DEAD)
			continue
		COOLDOWN_START(warframe, brownout, WARFRAME_BREAKER_BROWNOUT)
		warframe.visible_message(span_boldwarning("[warframe] stops dead, one arm still out."))
		do_sparks(3, FALSE, warframe)
		warframe.set_committed(TRUE)
		warframe.ai_controller?.PauseAi(WARFRAME_BREAKER_STAGGER)
		addtimer(CALLBACK(warframe, TYPE_PROC_REF(/mob/living/basic/vestige_warframe, set_committed), FALSE), WARFRAME_BREAKER_STAGGER, TIMER_UNIQUE|TIMER_OVERRIDE)
	addtimer(CALLBACK(src, PROC_REF(reset_lever)), WARFRAME_BREAKER_RESET)

/obj/structure/warframe_lever/breaker/proc/reset_lever()
	if(QDELETED(src))
		return
	pulled = FALSE
	playsound(src, 'sound/machines/terminal/terminal_on.ogg', 50, TRUE)
	visible_message(span_notice("The breaker springs back up."))

/// Every hall gate currently loaded, so the lever does not have to sweep the world.
GLOBAL_LIST_EMPTY(warframe_gates)

/**
 * The gate into the lower hall. Levered open, and beatable with a weapon if the lever is
 * somehow unreachable — a run that cannot be finished is worse than a shortcut.
 */
/obj/structure/warframe_gate
	name = "hall gate"
	desc = "A slab of lacquered steel filling the doorway. There is no handle on this side."
	icon = 'icons/obj/doors/blastdoor.dmi'
	icon_state = "closed"
	density = TRUE
	opacity = TRUE
	anchored = TRUE
	max_integrity = 400
	can_atmos_pass = ATMOS_PASS_DENSITY
	layer = BLASTDOOR_LAYER
	/// TRUE once it has been raised.
	var/raised = FALSE

/obj/structure/warframe_gate/Initialize(mapload)
	. = ..()
	GLOB.warframe_gates += src

/obj/structure/warframe_gate/Destroy()
	GLOB.warframe_gates -= src
	return ..()

/obj/structure/warframe_gate/examine(mob/user)
	. = ..()
	if(!raised)
		. += span_notice("It is closed. Something else in this hall opens it.")

/// Slide it up. Idempotent.
/obj/structure/warframe_gate/proc/raise()
	if(raised)
		return
	raised = TRUE
	set_density(FALSE)
	set_opacity(FALSE)
	icon_state = "open"
	playsound(src, 'sound/machines/blastdoor.ogg', 70, TRUE)
	air_update_turf(TRUE, FALSE)

// =========================================================================
// THE DROPS
// =========================================================================

/**
 * Guaranteed. The blade it has been beating people with for a century, and the guard
 * that goes with it: the same [/datum/status_effect/warframe_guard] the boss uses,
 * applied to you, riposte included.
 *
 * The blade is blunt. Its force is respectable but not exceptional and there is no
 * armour penetration on it, because the value here is the stance, not the edge.
 */
/obj/item/sparring_blade
	name = "sparring blade"
	desc = "A blunted practice blade in clan lacquer, worn silver along one edge from a hundred years of contact. \
		It is heavier than it looks."
	icon = 'icons/obj/weapons/sword.dmi'
	icon_state = "katana"
	inhand_icon_state = "katana"
	worn_icon_state = "katana"
	color = "#9aa4ad"
	icon_angle = -45
	lefthand_file = 'icons/mob/inhands/weapons/swords_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/swords_righthand.dmi'
	force = 22
	throwforce = 12
	block_chance = 15
	w_class = WEIGHT_CLASS_BULKY
	slot_flags = ITEM_SLOT_BELT | ITEM_SLOT_BACK
	sharpness = NONE
	attack_verb_continuous = list("strikes", "beats", "cracks")
	attack_verb_simple = list("strike", "beat", "crack")
	hitsound = 'sound/items/weapons/smash.ogg'
	resistance_flags = FIRE_PROOF | ACID_PROOF
	actions_types = list(/datum/action/cooldown/mob_cooldown/warframe_guard/held)
	action_slots = ITEM_SLOT_HANDS

/obj/item/sparring_blade/examine(mob/user)
	. = ..()
	. += span_notice("Hold it and use the ability to take the guard. In your hands it only catches melee.")

/**
 * The player's version of the guard. Shorter, on a much longer leash, and it never
 * catches bullets — the second-round upgrade stayed with the machine.
 *
 * It does not commit its user the way the boss's does. A player who cannot move for
 * three seconds in a firefight is a player who does not use the item.
 */
/datum/action/cooldown/mob_cooldown/warframe_guard/held
	name = "Standing Guard"
	desc = "Take the Warframe's guard for 3 seconds. Melee attacks against you are deflected and answered with a 16 brute counter."
	cooldown_time = 30 SECONDS
	click_to_activate = FALSE
	guard_duration = 3 SECONDS

/datum/action/cooldown/mob_cooldown/warframe_guard/held/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	StartCooldown()
	var/mob/living/caster = owner
	caster.visible_message(
		span_warning("[caster] brings their guard up and stops moving their feet."),
		span_notice("You take the guard."),
	)
	playsound(caster, 'sound/items/weapons/parry.ogg', 60, TRUE)
	var/datum/status_effect/warframe_guard/stance = caster.apply_status_effect(/datum/status_effect/warframe_guard, guard_duration)
	if(stance)
		stance.riposte_damage = 16
	return TRUE

/**
 * Jackpot. Live Floor in your hand: the same plates, dropped where you are standing.
 *
 * Spawned with you as the creator, so unlike the Matriarch's Heart it does spare its
 * owner — the boss's version does the same, and a floor hazard you cannot walk on is a
 * floor hazard nobody deploys.
 */
/obj/item/warframe_contact_plate
	name = "contact plate"
	desc = "A slab of deck plate cut out of the lower hall with the hall's current still in it. The cut edges are still bright."
	icon = 'icons/obj/devices/mecha_equipment.dmi'
	icon_state = "tesla"
	w_class = WEIGHT_CLASS_NORMAL
	throwforce = 8
	resistance_flags = FIRE_PROOF | ACID_PROOF
	light_range = 1
	light_power = 0.4
	light_color = COLOR_LIGHT_ORANGE
	/// Radius of plates it puts down.
	var/deploy_radius = 3
	/// How many plates it puts down.
	var/deploy_count = 8
	/// Time between deployments.
	var/deploy_cooldown_time = 30 SECONDS
	COOLDOWN_DECLARE(deploy_cooldown)

/obj/item/warframe_contact_plate/examine(mob/user)
	. = ..()
	. += span_notice("Use it in hand to put [deploy_count] live plates on the floor around you. They spare you and nobody else.")
	if(!COOLDOWN_FINISHED(src, deploy_cooldown))
		. += span_warning("It is still building charge - about [round(COOLDOWN_TIMELEFT(src, deploy_cooldown) / 10)] seconds.")

/obj/item/warframe_contact_plate/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	deploy(user)
	return TRUE

/obj/item/warframe_contact_plate/proc/deploy(mob/living/user)
	if(!COOLDOWN_FINISHED(src, deploy_cooldown))
		balloon_alert(user, "still charging!")
		return
	var/turf/here = get_turf(src)
	if(isnull(here))
		return
	var/list/candidates = list()
	for(var/turf/open/candidate in RANGE_TURFS(deploy_radius, here))
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		candidates += candidate
	if(!length(candidates))
		balloon_alert(user, "no floor to charge!")
		return
	COOLDOWN_START(src, deploy_cooldown, deploy_cooldown_time)
	user.visible_message(
		span_boldwarning("[user] slaps [src] against the deck and the floor starts buzzing!"),
		span_boldwarning("You slap [src] down. Mind where you step."),
	)
	playsound(src, 'sound/machines/terminal/terminal_on.ogg', 70, TRUE)
	candidates = shuffle(candidates)
	for(var/i in 1 to min(deploy_count, length(candidates)))
		new /obj/effect/warframe_live_plate(candidates[i], user)

/**
 * Jackpot. Its arm, near enough: the drawn cut, scaled to something a person can hold.
 *
 * Rides the boss's own ability class, so the line, the telegraph and the damage are one
 * implementation. The ability's commit hooks no-op on a non-Warframe owner, so a player
 * is never frozen in place by it.
 */
/obj/item/warframe_actuator
	name = "arm actuator"
	desc = "A length of servo assembly cut off at both ends, still tensioned. Squeezing the grip fires the whole travel at once."
	icon = 'icons/obj/devices/mecha_equipment.dmi'
	icon_state = "mecha_abooster_ccw"
	w_class = WEIGHT_CLASS_NORMAL
	force = 10
	throwforce = 10
	resistance_flags = FIRE_PROOF | ACID_PROOF
	actions_types = list(/datum/action/cooldown/mob_cooldown/warframe_iai/held)
	action_slots = ITEM_SLOT_HANDS

/obj/item/warframe_actuator/examine(mob/user)
	. = ..()
	. += span_notice("Hold it and use the ability, then click where you want the cut to end.")

/// The player's Iai. Shorter, weaker, and on a much longer cooldown.
/datum/action/cooldown/mob_cooldown/warframe_iai/held
	name = "Drawn Cut"
	desc = "Click a spot up to five tiles away to cut a line to it. 20 brute and a knockdown to everything on the line, yourself excepted."
	cooldown_time = 25 SECONDS

/datum/action/cooldown/mob_cooldown/warframe_iai/held/Activate(atom/target)
	if(!isliving(owner) || isnull(target))
		return FALSE
	var/turf/aim_at = get_turf(target)
	var/turf/here = get_turf(owner)
	if(isnull(aim_at) || isnull(here) || aim_at == here)
		return FALSE
	if(get_dist(here, aim_at) > 5)
		owner.balloon_alert(owner, "too far!")
		return FALSE
	var/list/path = build_path(here, aim_at)
	if(!length(path))
		owner.balloon_alert(owner, "nowhere to go!")
		return FALSE
	StartCooldown()
	var/mob/living/caster = owner
	caster.face_atom(aim_at)
	caster.visible_message(span_warning("[caster] snaps forward, blurring."))
	playsound(caster, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)
	cut(path, 1)
	return TRUE

/datum/action/cooldown/mob_cooldown/warframe_iai/held/strike(mob/living/victim, mob/living/caster)
	victim.apply_damage(20, BRUTE, spread_damage = TRUE)
	victim.Knockdown(WARFRAME_IAI_KNOCKDOWN)
	to_chat(victim, span_userdanger("[caster] goes straight through you!"))
	playsound(victim, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)

/// No follow-through for the hand-held version. It just stops.
/datum/action/cooldown/mob_cooldown/warframe_iai/held/finish_cut()
	return

// =========================================================================
// MACHINE COMMUNION — THE CAPSTONE
// =========================================================================

/datum/vestige_boon/spell/machine_communion
	name = "Machine Communion"
	desc = "Machines treat you as the station AI, so ID locks stop applying to you. On top of that you get a quickhack \
		list: click anything within nine tiles and pick from blowing it up, cutting its safeties, bolting or electrifying \
		a door, killing an area's power, bursting its lights, jamming radios, or dumping every cell a person is carrying \
		into the person."
	grant_text = "Something settles in behind your ear and starts listing every powered thing in the room."
	spell_type = /datum/action/cooldown/spell/machine_communion

/**
 * The capstone ability.
 *
 * Two halves, and the passive one matters as much as the button. On Grant it hands the
 * owner TRAIT_SILICON_ACCESS and TRAIT_AI_ACCESS — the same pair the machine wand grants
 * a person holding it (machine_wand.dm:30-31) — which is what "as if you were an AI"
 * actually means in this codebase: airlock and APC interfaces open for you, access checks
 * stop applying, and nothing has to be reimplemented to make that true.
 *
 * The active half is a click ability with a per-hack cooldown. The base spell chassis
 * starts a cooldown automatically after `cast`, which is wrong here because the length
 * depends on a choice the player has not made yet, so [before_cast] returns
 * SPELL_NO_IMMEDIATE_COOLDOWN and the menu starts it by hand. Backing out of the radial
 * costs nothing, on purpose.
 *
 * It is NOT `/datum/action/cooldown/spell/pointed`: the framework names this exact
 * typepath. The range check below is the one piece of the pointed chassis worth copying.
 */
/datum/action/cooldown/spell/machine_communion
	name = "Machine Communion"
	desc = "Click a machine or a person within nine tiles to open its quickhack list. Each hack has its own cooldown, \
		from 8 seconds to bolt a door up to 60 to fry everything somebody is carrying."
	button_icon = 'icons/mob/actions/actions_AI.dmi'
	button_icon_state = "ai_malf_core"
	background_icon_state = "bg_tech_blue"
	overlay_icon_state = "bg_tech_blue_border"
	ranged_mousepointer = 'icons/effects/mouse_pointers/override_machine_target.dmi'
	panel = "Spells"
	school = SCHOOL_TRANSMUTATION
	sound = null
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	cooldown_time = 20 SECONDS
	click_to_activate = TRUE
	/// How far it reaches.
	var/cast_range = COMMUNION_RANGE
	/// Guards against stacked radial menus.
	var/hacking = FALSE

/datum/action/cooldown/spell/machine_communion/Grant(mob/grant_to)
	. = ..()
	if(!owner)
		return
	owner.add_traits(list(TRAIT_SILICON_ACCESS, TRAIT_AI_ACCESS), REF(src))

/datum/action/cooldown/spell/machine_communion/Remove(mob/living/remove_from)
	remove_from?.remove_traits(list(TRAIT_SILICON_ACCESS, TRAIT_AI_ACCESS), REF(src))
	return ..()

/datum/action/cooldown/spell/machine_communion/is_valid_target(atom/cast_on)
	if(cast_on == owner)
		to_chat(owner, span_warning("You can hear your own gear perfectly well already."))
		return FALSE
	if(!length(applicable_hacks(cast_on, owner)))
		cast_on.balloon_alert(owner, "nothing to talk to!")
		return FALSE
	return TRUE

/datum/action/cooldown/spell/machine_communion/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	if(hacking)
		return . | SPELL_CANCEL_CAST
	if(owner && get_dist(get_turf(owner), get_turf(cast_on)) > cast_range)
		cast_on.balloon_alert(owner, "out of range!")
		return . | SPELL_CANCEL_CAST
	// The chosen hack decides the cooldown, and it has not been chosen yet.
	return . | SPELL_NO_IMMEDIATE_COOLDOWN

/datum/action/cooldown/spell/machine_communion/cast(atom/cast_on)
	. = ..()
	INVOKE_ASYNC(src, PROC_REF(open_hack_menu), cast_on)

/// Hacks this target could accept right now.
/datum/action/cooldown/spell/machine_communion/proc/applicable_hacks(atom/cast_on, mob/living/user)
	var/list/found = list()
	if(QDELETED(cast_on) || !isliving(user))
		return found
	for(var/datum/machine_quickhack/hack as anything in get_machine_quickhacks())
		if(hack.valid_for(cast_on, user))
			found += hack
	return found

/// Menu validity: we still exist, we still belong to this mob, and the target is still there.
/datum/action/cooldown/spell/machine_communion/proc/menu_check(mob/living/user, atom/cast_on)
	if(QDELETED(src) || QDELETED(user) || QDELETED(cast_on))
		return FALSE
	if(!(src in user.actions))
		return FALSE
	return get_dist(get_turf(user), get_turf(cast_on)) <= cast_range

/// The radial. Sleeps; only ever called through INVOKE_ASYNC.
/datum/action/cooldown/spell/machine_communion/proc/open_hack_menu(atom/cast_on)
	var/mob/living/user = owner
	if(hacking || !isliving(user) || QDELETED(cast_on))
		return
	var/list/available = applicable_hacks(cast_on, user)
	if(!length(available))
		cast_on.balloon_alert(user, "nothing to talk to!")
		return

	var/list/options = list()
	var/list/by_name = list()
	for(var/datum/machine_quickhack/hack as anything in available)
		var/datum/radial_menu_choice/option = new()
		option.image = image(icon = hack.radial_icon, icon_state = hack.radial_icon_state)
		option.name = hack.name
		option.info = "[hack.desc] ([round(hack.cooldown / 10)] second cooldown.)"
		options[hack.name] = option
		by_name[hack.name] = hack

	// autopick_single_option is off deliberately: several of these are expensive and a
	// target that only accepts one of them must not fire it on a stray click.
	hacking = TRUE
	var/choice = show_radial_menu(user, cast_on, options, custom_check = CALLBACK(src, PROC_REF(menu_check), user, cast_on), tooltips = TRUE, autopick_single_option = FALSE)
	hacking = FALSE
	if(!choice || !menu_check(user, cast_on))
		return

	var/datum/machine_quickhack/chosen = by_name[choice]
	if(!chosen?.valid_for(cast_on, user))
		cast_on.balloon_alert(user, "it stopped answering!")
		return
	if(!chosen.execute(cast_on, user))
		return
	user.log_message("used the [chosen.name] quickhack on [cast_on] ([cast_on.type]).", LOG_ATTACK)
	StartCooldown(chosen.cooldown)
	build_all_button_icons()

// =========================================================================
// THE QUICKHACKS
// =========================================================================

/**
 * One thing Machine Communion can do to one thing.
 *
 * Stateless singletons, built once into a global list and shared by every owner, so
 * nothing here may hold per-cast state. Timers hang off the singleton, which is fine
 * because it is never deleted.
 */
/datum/machine_quickhack
	/// Shown on the radial slice.
	var/name = "Quickhack"
	/// Shown in the slice's tooltip. Lead with the effect, then the numbers.
	var/desc = ""
	/// Radial slice icon.
	var/radial_icon = 'icons/mob/actions/actions_AI.dmi'
	/// Icon state paired with radial_icon.
	var/radial_icon_state = "overload_machine"
	/// Cooldown this hack puts on the whole ability.
	var/cooldown = 20 SECONDS

/// Can this hack be run on this target at all? Decides whether the slice is even shown.
/datum/machine_quickhack/proc/valid_for(atom/target, mob/living/user)
	return FALSE

/// Do it. Return TRUE if it landed; a FALSE return costs no cooldown.
/datum/machine_quickhack/proc/execute(atom/target, mob/living/user)
	return FALSE

/// Every quickhack, built once on demand.
GLOBAL_LIST_EMPTY(machine_quickhacks)

/proc/get_machine_quickhacks()
	if(!length(GLOB.machine_quickhacks))
		for(var/datum/machine_quickhack/hack_type as anything in subtypesof(/datum/machine_quickhack))
			GLOB.machine_quickhacks += new hack_type()
	return GLOB.machine_quickhacks

// ===== OVERLOAD =====

/**
 * Straight off `/datum/action/innate/ai/ranged/overload_machine` (malf_ai_modules.dm:521),
 * including its blacklist, with a smaller blast because this one is repeatable rather
 * than two uses a purchase. Lights burst instead of exploding — a light bulb should not
 * take out a wall.
 */
/datum/machine_quickhack/overload
	name = "Overload"
	desc = "Feed the machine power until it comes apart. Four seconds of loud buzzing, then a small explosion that destroys it. Lights just burst."
	radial_icon_state = "overload_machine"
	cooldown = 45 SECONDS

/datum/machine_quickhack/overload/valid_for(atom/target, mob/living/user)
	if(!ismachinery(target))
		return FALSE
	var/obj/machinery/victim = target
	if(victim.resistance_flags & INDESTRUCTIBLE)
		return FALSE
	return !is_type_in_typecache(victim, GLOB.blacklisted_malf_machines)

/datum/machine_quickhack/overload/execute(atom/target, mob/living/user)
	var/obj/machinery/victim = target
	victim.audible_message(span_userdanger("[victim] starts buzzing, loudly."))
	playsound(victim, SFX_SPARKS, 60, TRUE)
	user.playsound_local(user, 'sound/misc/interference.ogg', 40, FALSE)
	// ADMIN_VERBOSEJMP expands to a ternary over its argument, so it needs a plain
	// variable — a proc call inlined here doesn't parse inside the string
	var/turf/blast_site = get_turf(victim)
	message_admins("[ADMIN_LOOKUPFLW(user)] overloaded [victim.name] ([victim.type]) at [ADMIN_VERBOSEJMP(blast_site)] with Machine Communion.")
	addtimer(CALLBACK(src, PROC_REF(detonate), victim), COMMUNION_OVERLOAD_DELAY)
	return TRUE

/datum/machine_quickhack/overload/proc/detonate(obj/machinery/victim)
	if(QDELETED(victim))
		return
	if(istype(victim, /obj/machinery/light))
		var/obj/machinery/light/bulb = victim
		bulb.break_light_tube()
		return
	explosion(victim, heavy_impact_range = 1, light_impact_range = 3)
	if(!QDELETED(victim))
		qdel(victim)

// ===== CUT THE SAFETIES =====

/**
 * `emag_act` on anything that has one. The compatible-type list is lifted from the malf
 * targeted override module (malf_ai_modules.dm:1090-1097) so the surface area is a known
 * quantity rather than "every atom in the game".
 */
/datum/machine_quickhack/safeties
	name = "Cut the Safeties"
	desc = "Strip the target's safety interlocks. Exactly what an emag would do to it, which depends entirely on what it is."
	radial_icon = 'icons/obj/card.dmi'
	radial_icon_state = "emag"
	cooldown = 25 SECONDS

/datum/machine_quickhack/safeties/valid_for(atom/target, mob/living/user)
	var/static/list/compatible = list(
		/obj/machinery,
		/obj/item/modular_computer,
		/obj/item/radio/intercom,
		/mob/living/basic/bot,
		/mob/living/silicon,
		/mob/living/simple_animal/bot,
	)
	if(!is_type_in_list(target, compatible))
		return FALSE
	if(ismachinery(target))
		var/obj/machinery/machine = target
		return machine.is_operational
	return TRUE

/datum/machine_quickhack/safeties/execute(atom/target, mob/living/user)
	if(!target.emag_act(user))
		target.balloon_alert(user, "nothing to strip!")
		return FALSE
	playsound(target, SFX_SPARKS, 50, TRUE)
	to_chat(user, span_notice("[target] drops its safety interlocks."))
	return TRUE

// ===== BOLTS =====

/datum/machine_quickhack/bolts
	name = "Bolts"
	desc = "Throw the door's bolts, or pull them if they are already down. Works on the AI wire, so a cut door will not answer."
	radial_icon_state = "lockdown"
	cooldown = 8 SECONDS

/datum/machine_quickhack/bolts/valid_for(atom/target, mob/living/user)
	return istype(target, /obj/machinery/door/airlock)

/datum/machine_quickhack/bolts/execute(atom/target, mob/living/user)
	var/obj/machinery/door/airlock/door = target
	if(!door.canAIControl(user) || door.machine_stat)
		door.balloon_alert(user, "no interface!")
		return FALSE
	if(door.locked)
		door.unbolt()
		door.balloon_alert(user, "bolts up")
	else
		door.bolt()
		door.balloon_alert(user, "bolts down")
	return TRUE

// ===== ELECTRIFY =====

/**
 * Stock electrification alone is not worth a capstone hack. A shock through the frame is
 * `ELECTROCUTE_DAMAGE(area APC's spare energy)`, which is 0 below a kilojoule and jumps
 * straight to 20 above it — so on a derelict with a flat cell the door does nothing at all,
 * no burn and no stun, and `shock()` returning FALSE means it opens for them anyway.
 *
 * So a door the vestige has electrified carries its own current: a flat
 * [COMMUNION_ELECTRIFY_DAMAGE] burn and a [COMMUNION_ELECTRIFY_STUN] stun no matter how little
 * the local powernet has left in it. The door still has to be powered at all, same as ever —
 * the hack cannot be cast on a dead one. That is what `communion_live` below is for.
 */
/datum/machine_quickhack/electrify
	name = "Electrify"
	desc = "Run the door's frame live for 30 seconds. It draws on your own current rather than the area's, so a \
		nearly-empty APC still lands the shock. Touching it without insulated gloves is 20 burn and a stun."
	radial_icon = 'icons/obj/machines/wallmounts.dmi'
	radial_icon_state = "apc-spark"
	cooldown = 20 SECONDS

/datum/machine_quickhack/electrify/valid_for(atom/target, mob/living/user)
	return istype(target, /obj/machinery/door/airlock)

/datum/machine_quickhack/electrify/execute(atom/target, mob/living/user)
	var/obj/machinery/door/airlock/door = target
	if(!door.canAIControl(user) || door.machine_stat)
		door.balloon_alert(user, "no interface!")
		return FALSE
	door.set_electrified(COMMUNION_ELECTRIFY_SECONDS, user)
	door.set_communion_live(COMMUNION_ELECTRIFY_SECONDS)
	door.balloon_alert(user, "live")
	playsound(door, SFX_SPARKS, 50, TRUE)
	return TRUE

/// Set for as long as a Machine Communion electrification lasts. See [/datum/machine_quickhack/electrify].
/obj/machinery/door/airlock/var/communion_live = FALSE

/// Makes this airlock's electrification self-powered for `seconds`, matching the seconds `set_electrified` takes.
/obj/machinery/door/airlock/proc/set_communion_live(seconds)
	communion_live = TRUE
	addtimer(VARSET_CALLBACK(src, communion_live, FALSE), seconds SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE)

/**
 * Every path that shocks somebody on an airlock funnels through here, so overriding it once
 * covers bumping the door, touching it, and prying at it with a crowbar alike. Off a
 * communion-live door we do the parent's job by hand rather than through `electrocute_mob`,
 * which reads its damage off the area's APC and refuses non-carbons outright.
 *
 * `electrocute_act` with default flags still runs the victim's siemens coefficient, so
 * insulated gloves zero it out and nothing lands — same as an ordinary electrified door.
 * The explicit Paralyze is what carries the stun onto simple and basic mobs, whose
 * `electrocute_act` only ever adjusts fire loss.
 */
/obj/machinery/door/airlock/shock(mob/living/user, prb)
	if(!communion_live || !isElectrified())
		return ..()
	// Gating lifted from the parent: same power requirement, same one-second-per-victim grace
	// so a live doorway is not a stunlock, same probability roll.
	if(!istype(user) || !hasPower())
		return FALSE
	if(HAS_TRAIT(user, TRAIT_AIRLOCK_SHOCKIMMUNE))
		return FALSE
	if(!COOLDOWN_FINISHED(src, shockCooldown))
		return FALSE
	if(!prob(prb))
		return FALSE
	do_sparks(5, TRUE, src)
	if(!user.electrocute_act(COMMUNION_ELECTRIFY_DAMAGE, src))
		return FALSE
	user.Paralyze(COMMUNION_ELECTRIFY_STUN)
	log_combat(src, user, "electrocuted")
	COOLDOWN_START(src, shockCooldown, 1 SECONDS)
	ADD_TRAIT(user, TRAIT_AIRLOCK_SHOCKIMMUNE, REF(src))
	addtimer(TRAIT_CALLBACK_REMOVE(user, TRAIT_AIRLOCK_SHOCKIMMUNE, REF(src)), 1 SECONDS)
	return TRUE

// ===== KILL THE POWER =====

/datum/machine_quickhack/kill_power
	name = "Kill the Power"
	desc = "Flip an APC's breaker. Lights, equipment and air handling across that whole area go dead until it is flipped back."
	radial_icon = 'icons/obj/machines/wallmounts.dmi'
	radial_icon_state = "apc0"
	cooldown = 30 SECONDS

/datum/machine_quickhack/kill_power/valid_for(atom/target, mob/living/user)
	return isapc(target)

/datum/machine_quickhack/kill_power/execute(atom/target, mob/living/user)
	var/obj/machinery/power/apc/apc = target
	if(apc.aidisabled || !apc.is_operational || apc.failure_timer)
		apc.balloon_alert(user, "no interface!")
		return FALSE
	apc.toggle_breaker(user)
	playsound(apc, 'sound/machines/terminal/terminal_off.ogg', 50, FALSE)
	return TRUE

// ===== BURST THE LIGHTS =====

/**
 * The malf blackout, aimed at one APC instead of every APC on the station.
 *
 * It breaks the tubes directly rather than going through `overload_lighting()`, which
 * silently does nothing when the APC's cell is flat (apc_main.dm:732-736) — a hack that
 * fails invisibly is worse than one that does not exist.
 */
/datum/machine_quickhack/burst_lights
	name = "Burst the Lights"
	desc = "Push an APC's lighting circuit until every bulb in its area breaks. They stay broken."
	radial_icon_state = "blackout"
	cooldown = 30 SECONDS

/datum/machine_quickhack/burst_lights/valid_for(atom/target, mob/living/user)
	return isapc(target)

/datum/machine_quickhack/burst_lights/execute(atom/target, mob/living/user)
	var/obj/machinery/power/apc/apc = target
	if(apc.aidisabled)
		apc.balloon_alert(user, "no interface!")
		return FALSE
	var/burst = 0
	for(var/obj/machinery/light/bulb as anything in apc.get_lights())
		if(QDELETED(bulb))
			continue
		bulb.on = TRUE
		bulb.break_light_tube()
		burst++
		CHECK_TICK
	if(!burst)
		apc.balloon_alert(user, "no lights on this circuit!")
		return FALSE
	playsound(apc, 'sound/effects/light_flicker.ogg', 60, FALSE)
	to_chat(user, span_notice("Overcurrent applied. [burst] bulb\s gone."))
	return TRUE

// ===== FEEDBACK SURGE =====

/**
 * The headline, and the part of the spec that has no prior art to lift: everything a
 * person is carrying that holds a charge dumps that charge into the person.
 *
 * The shock scales with what they were carrying, so this is a hard counter to somebody
 * walking around with an armoury and close to nothing against somebody in a jumpsuit.
 * SHOCK_NOGLOVES is deliberate — the current is coming out of their own belt, and
 * insulated gloves have nothing to do with it.
 */
/datum/machine_quickhack/feedback_surge
	name = "Feedback Surge"
	desc = "Dump everything a person's gear is holding into the person. Empties every power cell they are carrying and shocks them for up to 60 burn, scaled to how much charge there was."
	radial_icon = 'icons/obj/weapons/baton.dmi'
	radial_icon_state = "stunbaton_active"
	cooldown = 60 SECONDS

/datum/machine_quickhack/feedback_surge/valid_for(atom/target, mob/living/user)
	if(!isliving(target) || target == user)
		return FALSE
	var/mob/living/victim = target
	return victim.stat != DEAD

/datum/machine_quickhack/feedback_surge/execute(atom/target, mob/living/user)
	var/mob/living/victim = target
	var/drained = vestige_drain_carried_cells(victim)
	if(drained <= 0)
		victim.balloon_alert(user, "carrying nothing live!")
		return FALSE

	var/shock = clamp(round(drained / STANDARD_CELL_CHARGE) * COMMUNION_SURGE_PER_CELL, COMMUNION_SURGE_MIN, COMMUNION_SURGE_MAX)
	victim.visible_message(
		span_boldwarning("Everything [victim] is carrying goes off at once in a sheet of sparks!"),
		span_userdanger("Every powered thing on you empties itself through you!"),
	)
	do_sparks(5, FALSE, victim)
	playsound(victim, 'sound/items/weapons/egloves.ogg', 75, TRUE)
	victim.electrocute_act(shock, user, flags = SHOCK_NOGLOVES|SHOCK_KNOCKDOWN)
	victim.drop_all_held_items()
	return TRUE

// ===== CUTOUT =====

/**
 * The quiet half of the same trick. No shock, no stun, no announcement — their gear
 * simply stops working and their radios stop transmitting, and they find out when they
 * pull a trigger. Half the cooldown, none of the damage.
 */
/datum/machine_quickhack/cutout
	name = "Cutout"
	desc = "Quietly empty every power cell a person is carrying and switch their radios off for 45 seconds. No shock and no stun; their gear just stops."
	radial_icon = 'icons/obj/weapons/baton.dmi'
	radial_icon_state = "stunbaton_nocell"
	cooldown = 35 SECONDS

/datum/machine_quickhack/cutout/valid_for(atom/target, mob/living/user)
	if(!isliving(target) || target == user)
		return FALSE
	var/mob/living/victim = target
	return victim.stat != DEAD

/datum/machine_quickhack/cutout/execute(atom/target, mob/living/user)
	var/mob/living/victim = target
	var/drained = vestige_drain_carried_cells(victim)
	var/silenced = 0
	for(var/obj/item/radio/radio in victim.get_all_contents())
		if(communion_radio_off(radio))
			silenced++
	if(drained <= 0 && !silenced)
		victim.balloon_alert(user, "carrying nothing live!")
		return FALSE
	to_chat(user, span_notice("[victim]'s gear goes quiet. [victim.p_they(TRUE)] [victim.p_do()]n't seem to have noticed."))
	// The tell lands a beat later, and it is the only one they get.
	addtimer(CALLBACK(src, PROC_REF(notice), victim), 2 SECONDS)
	return TRUE

/datum/machine_quickhack/cutout/proc/notice(mob/living/victim)
	if(QDELETED(victim) || victim.stat == DEAD)
		return
	to_chat(victim, span_warning("Something in your gear clicks, and every charge light you can see goes out."))

// ===== SILENCE =====

/datum/machine_quickhack/silence
	name = "Silence"
	desc = "Jam every radio within nine tiles of what you clicked for 45 seconds, and switch the ones already in range off outright for as long."
	radial_icon = 'icons/obj/devices/syndie_gadget.dmi'
	radial_icon_state = "jammer"
	cooldown = 40 SECONDS

/datum/machine_quickhack/silence/valid_for(atom/target, mob/living/user)
	var/turf/spot = get_turf(target)
	if(isnull(spot))
		return FALSE
	// Only offered where there is somebody to silence. Jamming an empty corridor burns
	// forty seconds for nothing, and this hack is targetable at almost anything.
	for(var/mob/living/candidate in view(COMMUNION_JAM_RANGE, spot))
		if(candidate != user)
			return TRUE
	return FALSE

/datum/machine_quickhack/silence/execute(atom/target, mob/living/user)
	var/turf/spot = get_turf(target)
	if(isnull(spot))
		return FALSE
	new /obj/item/jammer/machine_communion(spot)
	for(var/mob/living/holder in view(COMMUNION_JAM_RANGE, spot))
		for(var/obj/item/radio/radio in holder.get_all_contents())
			communion_radio_off(radio)
	for(var/obj/item/radio/loose in view(COMMUNION_JAM_RANGE, spot))
		communion_radio_off(loose)
	to_chat(user, span_notice("Everything with an aerial around [target] stops talking."))
	playsound(spot, 'sound/misc/interference.ogg', 40, TRUE)
	return TRUE

/**
 * The Silence bubble.
 *
 * `is_within_radio_jammer_range()` walks `GLOB.active_jammers` and reads `.range` off
 * each entry (traitordevices.dm:318-322), so the cheapest correct way to jam an area is
 * to be a jammer. Invisible, unclickable, and it deletes itself.
 */
/obj/item/jammer/machine_communion
	name = "silence"
	desc = "You should not be able to see this."
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	range = COMMUNION_JAM_RANGE

/obj/item/jammer/machine_communion/Initialize(mapload)
	. = ..()
	active = TRUE
	GLOB.active_jammers |= src
	QDEL_IN(src, COMMUNION_JAM_DURATION)

// ===== SHARED HELPERS =====

/**
 * Switches a radio off the way an EMP does, and books the same recovery.
 *
 * `set_broadcasting(FALSE)` is NOT this: broadcasting is the open-mic hot function,
 * already off on every standard headset, and `talk_into` ignores it entirely
 * (radio.dm:233-234 says so in as many words). The switch that actually gates both
 * talking and hearing is `on`, and riding the radio's own EMP bookkeeping
 * (`emped` + [/obj/item/radio/proc/end_emp_effect]) means a real EMP landing
 * mid-outage extends it instead of having it cancelled by our recovery timer.
 *
 * Returns TRUE if the radio was on and is now off.
 */
/proc/communion_radio_off(obj/item/radio/radio, duration = COMMUNION_RADIO_OFF_DURATION)
	if(QDELETED(radio) || !radio.on)
		return FALSE
	radio.emped++
	radio.set_on(FALSE)
	addtimer(CALLBACK(radio, TYPE_PROC_REF(/obj/item/radio, end_emp_effect), radio.emped), duration)
	return TRUE

/**
 * Empties every power cell inside an atom and returns the total charge taken, in joules.
 *
 * Works off `get_cell()`, which is the codebase's one honest answer to "does this thing
 * hold a charge" — energy guns, security batons, MOD suits, tablets, defibs, cyborgs and
 * bare cells all implement it. Cells are deduplicated because a gun and the cell inside
 * it both show up in `get_all_contents()` and both resolve to the same cell.
 */
/proc/vestige_drain_carried_cells(atom/holder)
	if(QDELETED(holder))
		return 0
	var/total = 0
	var/list/already_drained = list()
	for(var/atom/movable/thing as anything in holder.get_all_contents())
		if(thing == holder)
			continue
		var/obj/item/stock_parts/power_store/cell = thing.get_cell()
		if(isnull(cell) || (cell in already_drained))
			continue
		already_drained += cell
		if(cell.charge <= 0)
			continue
		total += cell.use(cell.charge, TRUE)
		cell.update_appearance()
		if(thing != cell)
			thing.update_appearance()
	return total

#undef WARFRAME_SECOND_ROUND_THRESHOLD
#undef WARFRAME_ROUND_CHANGE_TIME
#undef WARFRAME_SECOND_ROUND_COOLDOWN_SCALE
#undef WARFRAME_TRAIT
#undef WARFRAME_ROUND_FILTER
#undef WARFRAME_GUARD_FILTER
#undef WARFRAME_LEASH_RANGE
#undef WARFRAME_DISENGAGE_GRACE
#undef WARFRAME_DISENGAGE_RANGE
#undef WARFRAME_DISENGAGE_REPAIR
#undef WARFRAME_CLOSE_RANGE
#undef WARFRAME_READ_CAP
#undef WARFRAME_READ_MARGIN
#undef WARFRAME_READ_ANNOUNCE_COOLDOWN
#undef WARFRAME_BASE_WEIGHT
#undef WARFRAME_READ_WEIGHT
#undef WARFRAME_IAI_RANGE
#undef WARFRAME_IAI_TELEGRAPH
#undef WARFRAME_IAI_STEP_DELAY
#undef WARFRAME_IAI_DAMAGE
#undef WARFRAME_IAI_KNOCKDOWN
#undef WARFRAME_IAI_RECOVERY
#undef WARFRAME_GUARD_DURATION
#undef WARFRAME_RIPOSTE_DAMAGE
#undef WARFRAME_RIPOSTE_INTERVAL
#undef WARFRAME_SWEEP_RADIUS
#undef WARFRAME_SWEEP_ARC
#undef WARFRAME_SWEEP_TELEGRAPH
#undef WARFRAME_SWEEP_DAMAGE
#undef WARFRAME_SWEEP_THROW
#undef WARFRAME_PLATE_COUNT
#undef WARFRAME_PLATE_RADIUS
#undef WARFRAME_PLATE_TELEGRAPH
#undef WARFRAME_PLATE_DURATION
#undef WARFRAME_PLATE_DAMAGE
#undef WARFRAME_PLATE_REFRACTORY
#undef WARFRAME_BREAKER_STAGGER
#undef WARFRAME_BREAKER_BROWNOUT
#undef WARFRAME_BREAKER_RESET
#undef BB_WARFRAME_IAI
#undef BB_WARFRAME_GUARD
#undef BB_WARFRAME_SWEEP
#undef BB_WARFRAME_LIVE_FLOOR
#undef BB_WARFRAME_LAST_ABILITY
#undef COMMUNION_RANGE
#undef COMMUNION_ELECTRIFY_SECONDS
#undef COMMUNION_ELECTRIFY_DAMAGE
#undef COMMUNION_ELECTRIFY_STUN
#undef COMMUNION_OVERLOAD_DELAY
#undef COMMUNION_JAM_RANGE
#undef COMMUNION_JAM_DURATION
#undef COMMUNION_RADIO_OFF_DURATION
#undef COMMUNION_SURGE_PER_CELL
#undef COMMUNION_SURGE_MAX
#undef COMMUNION_SURGE_MIN
