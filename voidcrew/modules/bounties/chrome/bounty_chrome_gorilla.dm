/**
 * # Bounty chrome: Gorilla Arms
 *
 * Owner: C2 (Mantis Blades and Gorilla Arms). Built on the chrome core, bounty_chrome.dm.
 *
 * The player's Gorilla Arms (voidcrew/modules/cyberware/ware_military_arms.dm), the real pair of myomer
 * lattices, in a brawler, a brawler companion or a Juggernaut. Everything they do is the implant's: a punch
 * from an arm whose own 4 second cooldown is over is its empowered punch (flat brute, wound bonus, a knock
 * back a tile), the same punch on someone it holds in an aggressive grab hurls them across the room, and
 * with both arms in it pries airlocks open by hand. The AI only chooses how to use them, with a tell of at
 * least BOUNTY_CHROME_TELL_MIN before each big blow (owner decision 5):
 * - Ordinary blows (/datum/ai_behavior/basic_melee_attack/human_npc/bounty/gorilla) are thrown with a fist
 *   whose punch isn't loaded, so they are plain punches. Its loaded fists wait for the two told moves.
 * - The piston punch (/datum/bounty_chrome_move/gorilla_punch): it draws back a fist in an orange outline
 *   and the tile it aims at lights up, then it punches with a loaded arm: the implant's punch. Stepping off
 *   the lit tile makes it hit air.
 * - The grab (/datum/bounty_chrome_move/gorilla_grab): with one fist just used and the other loaded, it
 *   reaches for someone beside it and takes hold, tg's own pull (the player's first ctrl-click), while an
 *   orange ring lights under them. A step away or Resist breaks that at once. If they stay, the grip
 *   tightens into tg's aggressive grab (the second ctrl-click); then two punches to the face with the used
 *   fist (tg's grapple pummel), and the loaded fist's punch, which on someone held fast is the implant's
 *   hurl. tg's grab rules hold throughout: Resist struggles free at tg's odds, a friend can pull them away,
 *   and a stun, a knockdown, cuffs or an EMP make it let go. It never grabs someone on the floor, held by
 *   someone else, or someone it just let go of (BOUNTY_GORILLA_GRAB_GUARD), and it never throws anyone
 *   toward a drop, lava or space.
 * - Doors (/datum/bounty_chrome_move/gorilla_doors): when whoever it fights is behind a closed airlock
 *   near it, it puts a hand on the door out of combat mode, as the set bonus lets a player: an unpowered
 *   door gives at once, a powered one after the implant's slow pry, and bolts, welds and seals hold (the
 *   implant refuses them, and the AI leaves them alone). Only on its own ground (environment_damage_allowed()):
 *   never a ship, a hangar, an outpost, or a door with space or a big pressure difference behind it.
 *
 * A Juggernaut carrying the arms gets the grab as an ability in its own rotation (the core's adaptor); its
 * own blows are its kit's melee, so the implant empowers them as it would a player's.
 */

/// The piston punch's tell: the fist drawn back, long enough to step off the lit tile
#define BOUNTY_GORILLA_PUNCH_TELL (0.8 SECONDS)
/// The grab's tell, a hand on them: long enough to pull free before the grip tightens
#define BOUNTY_GORILLA_GRAB_TELL (0.8 SECONDS)
/// The first piston punch and the first grab of a fight come no sooner than these
#define BOUNTY_GORILLA_PUNCH_OPENING (1.5 SECONDS)
#define BOUNTY_GORILLA_GRAB_OPENING (3 SECONDS)
/// Between two grabs of one gorilla
#define BOUNTY_GORILLA_GRAB_COOLDOWN (12 SECONDS)
/// Someone it let go of isn't grabbed by it again for this long
#define BOUNTY_GORILLA_GRAB_GUARD (12 SECONDS)
/// Punches to the face before the finisher
#define BOUNTY_GORILLA_PUMMEL_PUNCHES 2
/// It lets go after holding someone fast this long, whatever became of the punches
#define BOUNTY_GORILLA_HOLD_MAX (4 SECONDS)
/**
 * A grab starts only while its used fist stays unloaded at least this long: the tell, the second
 * ctrl-click and both face punches come a click apart (CLICK_CD_MELEE), so the face punches are plain
 * ones and only the finisher is the implant's punch (its cooldown is per arm, CYBERWARE_GORILLA_PUNCH_COOLDOWN).
 */
#define BOUNTY_GORILLA_PUMMEL_FIST_LEFT (2.6 SECONDS)
/// How far the implant hurls someone held fast (CYBERWARE_GORILLA_HURL_RANGE), and knocks back anyone else
#define BOUNTY_GORILLA_HURL_RANGE 4
#define BOUNTY_GORILLA_KNOCKBACK_RANGE 1
/// Doors: how far one may be to go for, and how near its quarry has to be to it, out of sight, to be taken for behind it
#define BOUNTY_GORILLA_DOOR_REACH 2
#define BOUNTY_GORILLA_BEHIND_RANGE 5
/// Someone further off than this isn't worth breaking in for
#define BOUNTY_GORILLA_CHASE_RANGE 9
/// Someone it lost sight of is still worth a door this long
#define BOUNTY_GORILLA_QUARRY_MEMORY (12 SECONDS)
/// A door it went for is left alone this long, so it doesn't paw at one that won't give
#define BOUNTY_GORILLA_DOOR_RETRY (10 SECONDS)
/// A door with more than this pressure (kPa) between its sides stays shut
#define BOUNTY_GORILLA_PRESSURE_GAP 20
/// The arms' orange: the outline, and the ring under someone it reaches for (the mark art's red turned orange by a matrix)
#define BOUNTY_GORILLA_COLOR "#ff8a1f"
#define BOUNTY_GORILLA_MARK_MATRIX list(1, 0.54, 0.12, 0, 0, 0, 0, 0, 0)
/// Trait source for standing still while it holds someone
#define BOUNTY_GORILLA_TRAIT "bounty_chrome_gorilla"
/// What a mini-boss's boss_busy reads while it holds someone
#define BOUNTY_GORILLA_BOSS_BUSY "gorilla_hold"

// ===== THE ARMS =====

/// The Gorilla Arms lattices in `npc`
/proc/bounty_gorilla_arms(mob/living/carbon/npc)
	. = list()
	if(QDELETED(npc))
		return
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in npc.organs)
		. += arm

/// Whether `arm`'s next punch is the implant's: its chrome running and its own cooldown over
/proc/bounty_gorilla_loaded(obj/item/organ/cyberimp/cyberware/gorilla_arms/arm)
	var/datum/component/cyberware/chrome = arm?.GetComponent(/datum/component/cyberware)
	if(!chrome?.is_running() || (arm.organ_flags & ORGAN_FAILING))
		return FALSE
	return COOLDOWN_FINISHED(arm, slam_cooldown)

/// How long until `arm`'s punch is loaded again: 0 if it is, INFINITY while its chrome is down (its punches are plain ones)
/proc/bounty_gorilla_reload_left(obj/item/organ/cyberimp/cyberware/gorilla_arms/arm)
	var/datum/component/cyberware/chrome = arm?.GetComponent(/datum/component/cyberware)
	if(!chrome?.is_running() || (arm.organ_flags & ORGAN_FAILING))
		return INFINITY
	return COOLDOWN_TIMELEFT(arm, slam_cooldown)

/// The free hand (a held index) on `arm`'s side of `npc`, or null
/proc/bounty_gorilla_hand(mob/living/carbon/npc, obj/item/organ/cyberimp/cyberware/gorilla_arms/arm)
	return npc.get_empty_held_index_for_side(arm.zone == BODY_ZONE_R_ARM ? RIGHT_HANDS : LEFT_HANDS)

/// The lattice in the arm of `npc`'s hand `index`, or null
/proc/bounty_gorilla_arm_of_hand(mob/living/carbon/npc, index)
	var/zone = IS_RIGHT_INDEX(index) ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in bounty_gorilla_arms(npc))
		if(arm.zone == zone)
			return arm
	return null

/// An arm of `npc`'s whose punch is loaded and whose hand is free, or null
/proc/bounty_gorilla_loaded_arm(mob/living/carbon/npc)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in bounty_gorilla_arms(npc))
		if(bounty_gorilla_loaded(arm) && bounty_gorilla_hand(npc, arm))
			return arm
	return null

/**
 * An arm of `npc`'s whose loaded punch would hurl someone it holds fast, or null. Only the real Gorilla
 * Arms hurl (heavy_moves and a hurl_range: Brawler myomers never do), and the hurl shares the bearer's
 * grab-move cooldown with the slam (hyperviolence_gorilla/gorilla_punch.dm, piston_hit()).
 */
/proc/bounty_gorilla_hurl_arm(mob/living/carbon/npc)
	if(!TIMER_COOLDOWN_FINISHED(npc, COOLDOWN_GORILLA_GRAB_MOVE))
		return null
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in bounty_gorilla_arms(npc))
		if(arm.heavy_moves && arm.hurl_range > 0 && bounty_gorilla_loaded(arm) && bounty_gorilla_hand(npc, arm))
			return arm
	return null

/// A free hand of `npc`'s whose punch is a plain one (its arm's punch not loaded), the one furthest from loaded, or null
/proc/bounty_gorilla_plain_hand(mob/living/carbon/npc)
	var/best
	var/best_left = 0
	for(var/index in npc.get_empty_held_indexes())
		var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = bounty_gorilla_arm_of_hand(npc, index)
		var/left = arm ? bounty_gorilla_reload_left(arm) : INFINITY
		if(left > best_left)
			best = index
			best_left = left
	return best

/// Makes `npc`'s hand `index` the one it punches with. TRUE if it is.
/proc/bounty_gorilla_use_hand(mob/living/carbon/npc, index)
	if(!index || npc.held_items[index])
		return FALSE
	if(npc.active_hand_index != index)
		npc.swap_hand(index, silent = TRUE)
	return npc.active_hand_index == index

/// Whether it has the two fists a grab needs: one loaded for the finisher that can hurl, and another that stays unloaded through the face punches
/proc/bounty_gorilla_fists_for_grab(mob/living/carbon/npc)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/finisher = bounty_gorilla_hurl_arm(npc)
	if(!finisher)
		return FALSE
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in bounty_gorilla_arms(npc))
		if(arm != finisher && bounty_gorilla_hand(npc, arm) && bounty_gorilla_reload_left(arm) >= BOUNTY_GORILLA_PUMMEL_FIST_LEFT)
			return TRUE
	return FALSE

/// The way `npc` faces `victim` (face_atom()'s rule), which is the way the implant throws them
/proc/bounty_gorilla_facing(atom/npc, atom/victim)
	var/dx = victim.x - npc.x
	var/dy = victim.y - npc.y
	if(abs(dx) < abs(dy))
		return dy > 0 ? NORTH : SOUTH
	return dx > 0 ? EAST : WEST

/// Whether nothing in the `tiles` tiles behind `victim`, seen from `npc`, is a drop, lava or space: where the implant would throw them
/proc/bounty_gorilla_safe_behind(atom/npc, mob/living/victim, tiles)
	var/direction = bounty_gorilla_facing(npc, victim)
	var/turf/spot = get_turf(victim)
	for(var/i in 1 to tiles)
		spot = get_step(spot, direction)
		if(!spot || isclosedturf(spot))
			return TRUE
		if(isspaceturf(spot) || isopenspaceturf(spot) || isgroundlessturf(spot) || islava(spot) || ischasm(spot))
			return FALSE
	return TRUE

// ===== ORDINARY BLOWS =====

/**
 * A Gorilla Arms carrier's ordinary blows: the bounty brawler's melee (a punch, now and then a shove,
 * bounty_styles.dm) thrown with a plain fist. Its loaded fists wait for the piston punch and the grab,
 * which it tells first; with no plain fist free it stays on its target and throws nothing. A mech, or
 * anything that isn't a person, takes whatever fist.
 */
/datum/ai_behavior/basic_melee_attack/human_npc/bounty/gorilla

/datum/ai_behavior/basic_melee_attack/human_npc/bounty/gorilla/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/carbon/fighter = controller.pawn
	var/atom/target = controller.blackboard[target_key]
	if(isliving(target) && !human_npc_held_melee_weapon(fighter))
		if(!bounty_gorilla_use_hand(fighter, bounty_gorilla_plain_hand(fighter)))
			return AI_BEHAVIOR_DELAY
	return ..()

// ===== THE PISTON PUNCH =====

/**
 * The piston punch: a fist drawn back in an orange outline over the lit tile for BOUNTY_GORILLA_PUNCH_TELL,
 * then a loaded fist's punch at whoever still stands there, the implant's own. It also runs the gorilla's
 * fighting each planning tick (plan()): the grab first when it can start, then this, else its ordinary blows.
 */
/datum/bounty_chrome_move/gorilla_punch
	piece_key = BOUNTY_CHROME_GORILLA
	name = "piston punch"
	tell_time = BOUNTY_GORILLA_PUNCH_TELL
	tell_color = BOUNTY_GORILLA_COLOR
	tell_sound = 'sound/machines/piston/piston_raise.ogg'
	max_range = 1
	// A mini-boss's own blows are the implant's punches already: the grab is the move it gets
	boss_usable = FALSE
	/// world.time its first piston punch of this fight may start
	var/opens_at = 0
	/// world.time this fight started
	var/fight_started_at = 0
	/// The tile the fist is aimed at, through the tell
	var/turf/aimed_turf

/datum/bounty_chrome_move/gorilla_punch/detach()
	aimed_turf = null
	return ..()

/datum/bounty_chrome_move/gorilla_punch/on_fight_start(atom/target)
	fight_started_at = world.time
	opens_at = world.time + BOUNTY_GORILLA_PUNCH_OPENING

/datum/bounty_chrome_move/gorilla_punch/can_start(atom/target)
	var/mob/living/victim = target
	if(!isliving(victim) || !isturf(victim.loc) || !owner.Adjacent(victim) || bounty_gorilla_held_by_another(victim, owner) || HAS_TRAIT(owner, TRAIT_HANDS_BLOCKED))
		return FALSE
	if(!..())
		return FALSE
	if(!bounty_gorilla_loaded_arm(owner))
		return FALSE
	return bounty_gorilla_safe_behind(owner, victim, BOUNTY_GORILLA_KNOCKBACK_RANGE)

/datum/bounty_chrome_move/gorilla_punch/plan(datum/ai_controller/controller, atom/target)
	var/datum/component/bounty_chrome/chrome = owner.GetComponent(/datum/component/bounty_chrome)
	if(!chrome)
		return FALSE
	var/datum/bounty_chrome_move/gorilla_grab/grab = chrome.move_of(/datum/bounty_chrome_move/gorilla_grab)
	if(grab)
		if(grab.held_ref)
			// It is holding someone: its grab's own clock throws the punches
			return TRUE
		if(grab.may_go_now() && grab.can_start(target) && chrome.start_move(grab, target))
			return TRUE
		if(grab.pending(target))
			// The fist it just used is the one the face punches come from: it closes in for the grab and throws nothing meanwhile
			controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_BASIC_MOB_CURRENT_TARGET, 1)
			return TRUE
	if(bounty_melee_chrome_may_start(owner, opens_at, fight_started_at) && can_start(target) && chrome.start_move(src, target))
		return TRUE
	// Another piece's move that plans its own behaviours, and comes after this one, plans first: ending the planning here would starve it
	var/after = chrome.moves.Find(src)
	for(var/index in after + 1 to length(chrome.moves))
		var/datum/bounty_chrome_move/later = chrome.moves[index]
		if(later.piece_key != BOUNTY_CHROME_GORILLA && later.plan(controller, target))
			return TRUE
	// Another piece's move is ready: the core starts it, so planning goes on to it
	if(world.time >= chrome.next_move_at)
		for(var/datum/bounty_chrome_move/other as anything in chrome.moves)
			if(other.action_type && other.can_start(target))
				return FALSE
	// Its ordinary blows, with a plain fist. Anything in its hands fights by the style's own melee.
	if(!isliving(target) || human_npc_held_melee_weapon(owner))
		return FALSE
	controller.queue_behavior(/datum/ai_behavior/basic_melee_attack/human_npc/bounty/gorilla, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	return TRUE

/datum/bounty_chrome_move/gorilla_punch/tell_text(atom/target)
	return "[owner] draws back a chrome fist!"

/datum/bounty_chrome_move/gorilla_punch/tell(atom/target)
	..()
	aimed_turf = get_turf(target)
	if(aimed_turf)
		add_mark(new /obj/effect/temp_visual/bounty_boss_mark(aimed_turf, tell_time + 1))

/datum/bounty_chrome_move/gorilla_punch/effect(atom/target)
	var/turf/spot = aimed_turf
	aimed_turf = null
	var/mob/living/victim = target
	if(!isliving(victim) || QDELETED(victim) || get_turf(victim) != spot || !owner.Adjacent(victim))
		// They stepped off the lit tile
		if(spot && owner.Adjacent(spot))
			owner.face_atom(spot)
			owner.do_attack_animation(spot)
			playsound(owner, 'sound/items/weapons/punchmiss.ogg', 50, TRUE)
			owner.visible_message(span_warning("[owner]'s fist swings through empty air."))
		return FALSE
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = bounty_gorilla_loaded_arm(owner)
	if(!arm || !bounty_gorilla_safe_behind(owner, victim, BOUNTY_GORILLA_KNOCKBACK_RANGE))
		return FALSE
	if(!bounty_gorilla_use_hand(owner, bounty_gorilla_hand(owner, arm)))
		return FALSE
	owner.zone_selected = BODY_ZONE_CHEST
	return !!owner.ai_controller?.ai_interact(target = victim, combat_mode = TRUE)

/// Whether someone other than `npc` holds `victim` fast: it doesn't swing at someone who can't step off the lit tile, or grab them from another
/proc/bounty_gorilla_held_by_another(mob/living/victim, mob/living/npc)
	return !!victim.pulledby && victim.pulledby != npc && victim.pulledby.grab_state >= GRAB_AGGRESSIVE

// ===== THE GRAB =====

/**
 * The grab and pummel. Its tell is a hand on them (tg's pull) and an orange ring under them for
 * BOUNTY_GORILLA_GRAB_TELL; then tg's aggressive grab, two face punches with a plain fist and the loaded
 * fist's hurl, each a click apart, driven by its own clock (pummel()), not the AI's planning. A mini-boss
 * gets it as an ability in its rotation, busy while it holds on.
 */
/datum/bounty_chrome_move/gorilla_grab
	piece_key = BOUNTY_CHROME_GORILLA
	name = "grab"
	tell_time = BOUNTY_GORILLA_GRAB_TELL
	tell_color = BOUNTY_GORILLA_COLOR
	tell_sound = 'sound/machines/piston/piston_lower.ogg'
	max_range = 1
	/// world.time its next grab may start (its opener, then BOUNTY_GORILLA_GRAB_COOLDOWN)
	var/grab_ready_at = 0
	/// world.time this fight started
	var/fight_started_at = 0
	/// Who its hand is on through the tell
	var/datum/weakref/reach_ref
	/// Who it holds fast now
	var/datum/weakref/held_ref
	/// Face punches thrown in this hold
	var/punches = 0
	/// Goes up with every hold and every let-go, so a stale timer does nothing
	var/hold_serial = 0
	/// The next click of the hold, and the hold's own clock
	var/step_timer
	var/hold_timer
	/// A mini-boss's busy serial while it holds on
	var/boss_serial = 0
	/// REF() of someone it let go of -> world.time it may grab them again
	var/list/guard

/datum/bounty_chrome_move/gorilla_grab/attach(mob/living/carbon/human/npc/npc)
	. = ..()
	// A mini-boss runs it through its own rotation; the core wraps only moves with an implant action, so this one is wrapped here
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = npc
	if(istype(boss) && !boss_ability)
		var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability = new(boss)
		ability.set_move(src)
		ability.Grant(boss)
		boss.boss_abilities += ability

/datum/bounty_chrome_move/gorilla_grab/detach()
	let_go()
	reach_ref = null
	guard = null
	return ..()

/datum/bounty_chrome_move/gorilla_grab/on_fight_start(atom/target)
	fight_started_at = world.time
	grab_ready_at = max(grab_ready_at, world.time + BOUNTY_GORILLA_GRAB_OPENING)

/datum/bounty_chrome_move/gorilla_grab/on_fight_end()
	let_go()

/datum/bounty_chrome_move/gorilla_grab/on_downed()
	let_go()

/datum/bounty_chrome_move/gorilla_grab/on_death()
	let_go()

/datum/bounty_chrome_move/gorilla_grab/on_emp(severity)
	// Its chrome glitching, it lets go
	let_go()

/datum/bounty_chrome_move/gorilla_grab/plan(datum/ai_controller/controller, atom/target)
	// Holding someone, nothing else is planned: its own clock throws the punches
	return !!held_ref

/**
 * Whether its other chrome lets the grab start now: past the gap after the last move fired, or straight
 * after a piston punch, the fist that punch used being the one the face punches come from.
 */
/datum/bounty_chrome_move/gorilla_grab/proc/may_go_now()
	var/datum/component/bounty_chrome/chrome = owner?.GetComponent(/datum/component/bounty_chrome)
	if(!chrome || chrome.telling)
		return FALSE
	if(world.time >= chrome.next_move_at)
		return TRUE
	var/datum/bounty_chrome_move/gorilla_punch/punch = chrome.move_of(/datum/bounty_chrome_move/gorilla_punch)
	if(!punch?.last_fired || punch.last_fired < fight_started_at)
		return FALSE
	return punch.last_fired > bounty_melee_chrome_last_move_at(owner, list(/datum/bounty_chrome_move/gorilla_punch))

/datum/bounty_chrome_move/gorilla_grab/can_start(atom/target)
	var/mob/living/victim = target
	if(held_ref || world.time < grab_ready_at || world.time < owner.next_move || HAS_TRAIT(owner, TRAIT_HANDS_BLOCKED) || !may_grab(victim))
		return FALSE
	if(!..())
		return FALSE
	if(!bounty_gorilla_fists_for_grab(owner))
		return FALSE
	return bounty_gorilla_safe_behind(owner, victim, BOUNTY_GORILLA_HURL_RANGE)

/// Whether a grab at `target` could follow as soon as it is beside them: its fists and its other chrome allow one now, and they are someone it may grab
/datum/bounty_chrome_move/gorilla_grab/proc/pending(atom/target)
	if(held_ref || world.time < grab_ready_at || !may_go_now() || !bounty_gorilla_fists_for_grab(owner))
		return FALSE
	var/mob/living/victim = target
	return may_grab(victim, need_adjacent = FALSE) && bounty_ai_dist(owner, victim) <= 2 && bounty_chrome_can_act(owner)

/**
 * Whether it may take hold of `victim`: someone beside it (unless `need_adjacent` is FALSE), awake and on
 * their feet on a tile of their own, whom tg's grab can take hold of and tighten on, not held by anyone
 * else, and not someone it let go of in the last BOUNTY_GORILLA_GRAB_GUARD.
 */
/datum/bounty_chrome_move/gorilla_grab/proc/may_grab(mob/living/victim, need_adjacent = TRUE)
	if(!isliving(victim) || QDELETED(victim) || victim == owner || !isturf(victim.loc) || victim.buckled || victim.anchored)
		return FALSE
	if(victim.stat != CONSCIOUS || victim.body_position == LYING_DOWN || (need_adjacent && !owner.Adjacent(victim)))
		return FALSE
	// tg's grab never tightens on these (grabbedby())
	if(issilicon(victim) || !(victim.status_flags & CANPUSH) || HAS_TRAIT(victim, TRAIT_PUSHIMMUNE))
		return FALSE
	if(victim.pulledby && victim.pulledby != owner)
		return FALSE
	if(LAZYACCESS(guard, REF(victim)) > world.time)
		return FALSE
	return victim.can_be_pulled(owner, owner.pull_force)

/datum/bounty_chrome_move/gorilla_grab/tell_text(atom/target)
	return "[owner] reaches for [target] with both chrome hands!"

/datum/bounty_chrome_move/gorilla_grab/tell(atom/target)
	..()
	grab_ready_at = world.time + BOUNTY_GORILLA_GRAB_COOLDOWN
	var/turf/spot = get_turf(target)
	if(spot)
		add_mark(new /obj/effect/temp_visual/bounty_boss_mark(spot, tell_time + 1, BOUNTY_GORILLA_MARK_MATRIX, "target_circle"))
	var/mob/living/victim = target
	if(!isliving(victim))
		return
	// Its hand on them: tg's pull, a player's first ctrl-click. It hurts nobody, and a step or Resist breaks it.
	reach_ref = WEAKREF(victim)
	grab_click(victim)

/// A player's ctrl-click on `victim`: tg's grab, a pull the first time and the grip tightened the next
/datum/bounty_chrome_move/gorilla_grab/proc/grab_click(mob/living/victim)
	return !!owner.ai_controller?.ai_interact(target = victim, modifiers = list(CTRL_CLICK = TRUE))

/datum/bounty_chrome_move/gorilla_grab/cancel(reason)
	// Cut short with its hand on them: it lets go
	var/mob/living/victim = reach_ref?.resolve()
	reach_ref = null
	if(victim && !QDELETED(owner) && owner.pulling == victim && !held_ref)
		owner.stop_pulling()

/datum/bounty_chrome_move/gorilla_grab/effect(atom/target)
	var/mob/living/victim = reach_ref?.resolve()
	reach_ref = null
	if(!isliving(victim) || victim != target || owner.pulling != victim)
		return FALSE
	if(!may_hold(victim))
		owner.stop_pulling()
		return FALSE
	// They stayed: the grip tightens, the second ctrl-click
	grab_click(victim)
	if(!holding(victim))
		if(owner.pulling == victim)
			owner.stop_pulling()
		return FALSE
	start_hold(victim)
	return TRUE

/// Whether it holds `victim` fast now: tg's aggressive grab, its own
/datum/bounty_chrome_move/gorilla_grab/proc/holding(mob/living/victim)
	return !QDELETED(owner) && !QDELETED(victim) && owner.pulling == victim && owner.grab_state >= GRAB_AGGRESSIVE

/// Whether `victim` is someone it goes on holding: awake, on their feet and beside it
/datum/bounty_chrome_move/gorilla_grab/proc/may_hold(mob/living/victim)
	return !QDELETED(victim) && victim.stat == CONSCIOUS && victim.body_position != LYING_DOWN && isturf(victim.loc) && owner.Adjacent(victim)

/// Whether the hold goes on: it holds them fast, can still act with its hands, isn't cut off as a mini-boss, and they are still someone it holds
/datum/bounty_chrome_move/gorilla_grab/proc/hold_ok(mob/living/victim)
	if(!holding(victim) || !may_hold(victim))
		return FALSE
	if(!bounty_chrome_can_act(owner) || HAS_TRAIT(owner, TRAIT_HANDS_BLOCKED))
		return FALSE
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = owner
	if(istype(boss) && (boss.boss_busy != BOUNTY_GORILLA_BOSS_BUSY || boss.boss_busy_serial != boss_serial))
		return FALSE
	return TRUE

/// It holds `victim` fast: it stands still, and its clock throws the punches a click apart
/datum/bounty_chrome_move/gorilla_grab/proc/start_hold(mob/living/victim)
	held_ref = WEAKREF(victim)
	punches = 0
	hold_serial++
	// Struggled free, pulled away by a friend, thrown by the finisher: tg lets go, and it hears of it
	RegisterSignal(owner, COMSIG_ATOM_NO_LONGER_PULLING, PROC_REF(on_no_longer_pulling))
	RegisterSignals(owner, list(SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED), SIGNAL_ADDTRAIT(TRAIT_FLOORED), SIGNAL_ADDTRAIT(TRAIT_HANDS_BLOCKED), SIGNAL_ADDTRAIT(TRAIT_RESTRAINED)), PROC_REF(on_disabled))
	ADD_TRAIT(owner, TRAIT_IMMOBILIZED, BOUNTY_GORILLA_TRAIT)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = owner
	if(istype(boss))
		boss.boss_next_ability_at = max(boss.boss_next_ability_at, world.time + BOUNTY_GORILLA_HOLD_MAX)
		boss_serial = boss.boss_set_busy(BOUNTY_GORILLA_BOSS_BUSY, BOUNTY_GORILLA_HOLD_MAX + 1 SECONDS)
	hold_timer = addtimer(CALLBACK(src, PROC_REF(hold_expired), hold_serial), BOUNTY_GORILLA_HOLD_MAX, TIMER_STOPPABLE | TIMER_DELETE_ME)
	next_click()

/// Its next click of the hold, the moment its hand is free to click again
/datum/bounty_chrome_move/gorilla_grab/proc/next_click()
	deltimer(step_timer)
	step_timer = addtimer(CALLBACK(src, PROC_REF(pummel), hold_serial), max(owner.next_move - world.time, 1), TIMER_STOPPABLE | TIMER_DELETE_ME)

/**
 * One click of the hold under `serial`: a punch to the face with a plain fist while any are left, then
 * the loaded fist's punch, the implant's hurl. With no loaded fist yet it holds on and waits, until the
 * hold's own clock lets them go. If the hold broke meanwhile it lets go and nothing lands. Returns TRUE if
 * it threw a punch.
 */
/datum/bounty_chrome_move/gorilla_grab/proc/pummel(serial)
	step_timer = null
	if(serial != hold_serial || !held_ref)
		return FALSE
	var/mob/living/victim = held_ref.resolve()
	if(!hold_ok(victim))
		let_go()
		return FALSE
	if(world.time < owner.next_move)
		next_click()
		return FALSE
	if(punches < BOUNTY_GORILLA_PUMMEL_PUNCHES)
		var/plain = bounty_gorilla_plain_hand(owner)
		var/obj/item/organ/cyberimp/cyberware/gorilla_arms/plain_arm = plain && bounty_gorilla_arm_of_hand(owner, plain)
		if(plain && (!plain_arm || !bounty_gorilla_loaded(plain_arm)))
			punches++
			punch(victim, plain)
			if(serial == hold_serial && held_ref)
				next_click()
			return TRUE
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/finisher = bounty_gorilla_hurl_arm(owner)
	if(!finisher)
		// Its loaded fist isn't back yet: it holds on
		step_timer = addtimer(CALLBACK(src, PROC_REF(pummel), hold_serial), 1, TIMER_STOPPABLE | TIMER_DELETE_ME)
		return FALSE
	if(!bounty_gorilla_safe_behind(owner, victim, BOUNTY_GORILLA_HURL_RANGE))
		let_go()
		return FALSE
	punch(victim, bounty_gorilla_hand(owner, finisher))
	// The hurl took them out of its hands (tg ends the pull as they fly); if anything stopped it, it lets go
	let_go()
	return TRUE

/// A punch to `victim`'s face with hand `index`: a player's click in combat mode, so tg's punch, or the implant's if that fist is loaded
/datum/bounty_chrome_move/gorilla_grab/proc/punch(mob/living/victim, index)
	if(!bounty_gorilla_use_hand(owner, index))
		return FALSE
	owner.zone_selected = BODY_ZONE_HEAD
	return !!owner.ai_controller?.ai_interact(target = victim, combat_mode = TRUE)

/// The hold's own clock under `serial` ran out: it lets go
/datum/bounty_chrome_move/gorilla_grab/proc/hold_expired(serial)
	hold_timer = null
	if(serial == hold_serial && held_ref)
		let_go()

/// tg let go of someone it pulled (inside stop_pulling()). If it was whoever it held, the hold is over. Must not sleep.
/datum/bounty_chrome_move/gorilla_grab/proc/on_no_longer_pulling(datum/source, atom/movable/was_pulling)
	SIGNAL_HANDLER
	if(was_pulling == held_ref?.resolve())
		end_hold()

/// Stunned, knocked down, cuffed or its hands tied up mid-hold: it lets go. Inside a signal handler.
/datum/bounty_chrome_move/gorilla_grab/proc/on_disabled(datum/source)
	SIGNAL_HANDLER
	let_go()

/// Lets go of whoever it holds, or has its hand on (tg's stop_pulling()). Safe at any time.
/datum/bounty_chrome_move/gorilla_grab/proc/let_go()
	var/mob/living/victim = held_ref?.resolve() || reach_ref?.resolve()
	end_hold()
	reach_ref = null
	if(victim && !QDELETED(owner) && owner.pulling == victim)
		owner.stop_pulling()

/// The hold is over: it may move again, a mini-boss is free, and whoever it held isn't grabbed by it again for a while
/datum/bounty_chrome_move/gorilla_grab/proc/end_hold()
	if(!held_ref)
		return
	var/mob/living/victim = held_ref.resolve()
	held_ref = null
	punches = 0
	hold_serial++
	deltimer(step_timer)
	step_timer = null
	deltimer(hold_timer)
	hold_timer = null
	if(owner)
		UnregisterSignal(owner, list(COMSIG_ATOM_NO_LONGER_PULLING, SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED), SIGNAL_ADDTRAIT(TRAIT_FLOORED), SIGNAL_ADDTRAIT(TRAIT_HANDS_BLOCKED), SIGNAL_ADDTRAIT(TRAIT_RESTRAINED)))
		REMOVE_TRAIT(owner, TRAIT_IMMOBILIZED, BOUNTY_GORILLA_TRAIT)
		var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = owner
		if(istype(boss) && boss_serial && boss.boss_busy == BOUNTY_GORILLA_BOSS_BUSY && boss.boss_busy_serial == boss_serial)
			boss.boss_clear_busy(boss_serial)
	boss_serial = 0
	if(!victim)
		return
	// Forget the guards that are over, then guard this one
	for(var/key in guard)
		if(guard[key] <= world.time)
			guard -= key
	LAZYSET(guard, REF(victim), world.time + BOUNTY_GORILLA_GRAB_GUARD)

// ===== DOORS =====

/**
 * Doors. Whoever it fights got behind a closed airlock near it: it goes to the door and puts a hand on it
 * out of combat mode, which the arms' set bonus turns into the implant's own pry (tg's door_pryer). Looked
 * at every Life tick (on_tick()), since the one it fought may no longer be its target once out of sight.
 */
/datum/bounty_chrome_move/gorilla_doors
	piece_key = BOUNTY_CHROME_GORILLA
	name = "door pry"
	boss_usable = FALSE
	/// Who it was last fighting, and when it last saw them
	var/datum/weakref/quarry_ref
	var/quarry_seen_at = 0
	/// REF() of a door it went for -> world.time it may go for it again
	var/list/tried

/datum/bounty_chrome_move/gorilla_doors/detach()
	quarry_ref = null
	tried = null
	return ..()

/datum/bounty_chrome_move/gorilla_doors/plan(datum/ai_controller/controller, atom/target)
	note_quarry(target)
	return FALSE

/datum/bounty_chrome_move/gorilla_doors/on_fight_end()
	quarry_ref = null

/datum/bounty_chrome_move/gorilla_doors/on_tick(seconds_per_tick, fighting, atom/target)
	if(!fighting)
		quarry_ref = null
		return
	note_quarry(target)
	try_door()

/// Remembers `target` as who it fights while it can see them
/datum/bounty_chrome_move/gorilla_doors/proc/note_quarry(atom/target)
	if(!QDELETED(target) && (isliving(target) || ismecha(target)) && bounty_ai_can_see(owner, target, BOUNTY_GORILLA_CHASE_RANGE))
		quarry_ref = WEAKREF(target)
		quarry_seen_at = world.time

/// Whether the arms' set bonus is working: both arms in and synced, Gorilla or Brawler, so it can force doors
/datum/bounty_chrome_move/gorilla_doors/proc/can_pry()
	return gorilla_synced(owner) || brawler_synced(owner)

/**
 * Whoever it is after and can't get at, its target out of sight or behind a closed glass door, or someone
 * it lost sight of in the last BOUNTY_GORILLA_QUARRY_MEMORY: if a closed airlock near it is in the way, it
 * goes for it, a step to it if need be, then a hand on it. Returns TRUE if it did something.
 */
/datum/bounty_chrome_move/gorilla_doors/proc/try_door()
	if(!bounty_chrome_can_act(owner) || QDELETED(owner.ai_controller) || LAZYLEN(owner.do_afters) || HAS_TRAIT(owner, TRAIT_IMMOBILIZED) || HAS_TRAIT(owner, TRAIT_HANDS_BLOCKED) || !can_pry())
		return FALSE
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = owner
	if(istype(boss) && boss.boss_busy)
		return FALSE
	var/datum/component/bounty_chrome/chrome = owner.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/gorilla_grab/grab = chrome?.move_of(/datum/bounty_chrome_move/gorilla_grab)
	if(chrome?.telling || grab?.held_ref)
		return FALSE
	var/atom/quarry = bounty_chrome_target(owner)
	var/in_sight = FALSE
	if(!QDELETED(quarry))
		in_sight = bounty_ai_can_see(owner, quarry, BOUNTY_GORILLA_CHASE_RANGE)
		if(in_sight && owner.Adjacent(quarry))
			return FALSE
	else
		quarry = quarry_ref?.resolve()
		if(QDELETED(quarry) || world.time > quarry_seen_at + BOUNTY_GORILLA_QUARRY_MEMORY)
			return FALSE
	var/turf/goal = get_turf(quarry)
	if(!goal || goal.z != owner.z || get_dist(owner, goal) > BOUNTY_GORILLA_CHASE_RANGE || !bounty_ai_may_hit(owner, quarry))
		return FALSE
	var/obj/machinery/door/airlock/door = find_door(goal, in_sight)
	if(!door)
		return FALSE
	var/turf/here = get_turf(owner)
	var/turf/door_turf = get_turf(door)
	if(get_dist(here, door_turf) == 1 && (get_dir(here, door_turf) in GLOB.cardinals))
		LAZYSET(tried, REF(door), world.time + BOUNTY_GORILLA_DOOR_RETRY)
		if(!human_npc_ready_empty_hand(owner))
			return FALSE
		owner.face_atom(door)
		// A hand on the door out of combat mode: the set bonus pries it (tg's door_pryer)
		INVOKE_ASYNC(owner.ai_controller, TYPE_PROC_REF(/datum/ai_controller, ai_interact), door, FALSE)
		return TRUE
	return step_to_door(door)

/**
 * The closed airlock within BOUNTY_GORILLA_DOOR_REACH of it that stands between it and `goal`, nearest
 * first: on the straight line to `goal` when it can see there (a glass door), or else nearer `goal` than
 * it is and within BOUNTY_GORILLA_BEHIND_RANGE of it. Only one it may force (may_force()).
 */
/datum/bounty_chrome_move/gorilla_doors/proc/find_door(turf/goal, in_sight)
	var/turf/here = get_turf(owner)
	var/list/line = in_sight ? get_line(here, goal) : null
	var/to_goal = get_dist(here, goal)
	var/obj/machinery/door/airlock/best
	var/best_score = INFINITY
	for(var/turf/spot as anything in RANGE_TURFS(BOUNTY_GORILLA_DOOR_REACH, here))
		var/obj/machinery/door/airlock/door = locate() in spot
		if(!door)
			continue
		if(in_sight)
			if(!(spot in line))
				continue
		else if(get_dist(spot, goal) >= to_goal || get_dist(spot, goal) > BOUNTY_GORILLA_BEHIND_RANGE)
			continue
		if(!may_force(door))
			continue
		var/score = get_dist(here, spot) * 10 + get_dist(spot, goal)
		if(score < best_score)
			best = door
			best_score = score
	return best

/**
 * Whether it may go at `door`: shut and not bolted, welded or sealed (the implant won't force those), not
 * one it went for a moment ago, on its side's own ground where it may break things
 * (environment_damage_allowed(): never a ship, a hangar, an outpost or a trader outpost), and one that lets
 * no air out when it opens.
 */
/datum/bounty_chrome_move/gorilla_doors/proc/may_force(obj/machinery/door/airlock/door)
	if(QDELETED(door) || !door.density || door.operating || door.locked || door.welded || door.seal)
		return FALSE
	// A trader outpost's doors refuse the pry (hyperviolence_gorilla/gorilla_pry.dm)
	if(gorilla_pry_refused(door))
		return FALSE
	if(LAZYACCESS(tried, REF(door)) > world.time)
		return FALSE
	var/mob/living/carbon/human/npc/bounty_criminal/side = bounty_ai_side_of(owner)
	if(!side || !side.environment_damage_allowed(get_turf(door)))
		return FALSE
	return bounty_gorilla_door_holds_air(door)

/// One step to a free side of `door` beside it, on its side's leash. Returns TRUE if it moved.
/datum/bounty_chrome_move/gorilla_doors/proc/step_to_door(obj/machinery/door/airlock/door)
	var/turf/here = get_turf(owner)
	var/turf/door_turf = get_turf(door)
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(door_turf, direction)
		if(!beside || get_dist(here, beside) != 1)
			continue
		if(bounty_ai_step(owner, beside))
			owner.face_atom(door)
			return TRUE
	return FALSE

/**
 * Whether opening `door` lets no air out: none of its open sides is space, open space or a drop, and the
 * pressures on them are within BOUNTY_GORILLA_PRESSURE_GAP of each other.
 */
/proc/bounty_gorilla_door_holds_air(obj/machinery/door/door)
	var/turf/spot = get_turf(door)
	if(!spot)
		return FALSE
	var/lowest = INFINITY
	var/highest = 0
	var/sides = 0
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(spot, direction)
		if(!beside || isclosedturf(beside))
			continue
		if(isspaceturf(beside) || isopenspaceturf(beside) || isgroundlessturf(beside))
			return FALSE
		var/datum/gas_mixture/air = beside.return_air()
		var/pressure = air ? air.return_pressure() : 0
		lowest = min(lowest, pressure)
		highest = max(highest, pressure)
		sides++
	return sides >= 2 && highest - lowest <= BOUNTY_GORILLA_PRESSURE_GAP

#undef BOUNTY_GORILLA_PUNCH_TELL
#undef BOUNTY_GORILLA_GRAB_TELL
#undef BOUNTY_GORILLA_PUNCH_OPENING
#undef BOUNTY_GORILLA_GRAB_OPENING
#undef BOUNTY_GORILLA_GRAB_COOLDOWN
#undef BOUNTY_GORILLA_GRAB_GUARD
#undef BOUNTY_GORILLA_PUMMEL_PUNCHES
#undef BOUNTY_GORILLA_HOLD_MAX
#undef BOUNTY_GORILLA_PUMMEL_FIST_LEFT
#undef BOUNTY_GORILLA_HURL_RANGE
#undef BOUNTY_GORILLA_KNOCKBACK_RANGE
#undef BOUNTY_GORILLA_DOOR_REACH
#undef BOUNTY_GORILLA_BEHIND_RANGE
#undef BOUNTY_GORILLA_CHASE_RANGE
#undef BOUNTY_GORILLA_QUARRY_MEMORY
#undef BOUNTY_GORILLA_DOOR_RETRY
#undef BOUNTY_GORILLA_PRESSURE_GAP
#undef BOUNTY_GORILLA_COLOR
#undef BOUNTY_GORILLA_MARK_MATRIX
#undef BOUNTY_GORILLA_TRAIT
#undef BOUNTY_GORILLA_BOSS_BUSY
