/**
 * # Bounty chrome: Gorilla Arms
 *
 * The player's Gorilla Arms (voidcrew/modules/cyberware/ware_military_arms.dm) on a bounty brawler,
 * a brawler companion or a Juggernaut. The plating shows on both arms and hands wherever the clothes
 * leave them bare, as it does on a player.
 *
 * How it fights:
 * - Bare fists, always: whatever put the arms in them (a roll, an admin's pick), a fighter who isn't a
 *   brawler becomes one (bounty_chrome_fit_style()), so no gun, blade or bottle ever comes with them.
 * - Every ordinary blow is the player implant's empowered punch: its flat brute, wound bonus and armour
 *   penetration, its sound and its one-tile knock-back, at the pair of arms' rhythm
 *   (BOUNTY_GORILLA_FIST_INTERVAL). A brawler's own shove stays out of it (owns_blow()). While the
 *   chrome is down from an EMP they punch like anyone else.
 * - The grab and pummel. Now and then, with someone right beside them, they lean in and reach with
 *   both hands: the tile lights up in a ring and the pistons sigh. After BOUNTY_GORILLA_REACH_TIME they
 *   take whoever still stands there in tg's own aggressive grab (take_hold()), the one a player with
 *   the implant uses, so it holds, shows and breaks like anyone's: no walking off, hands tied up, and
 *   Resist or a step struggles against it (resist_grab()). Then they drive two fast punches into the
 *   face and finish with the piston punch (below) to the face, which lets go and throws them back.
 *   Never more than BOUNTY_GORILLA_PUMMEL_BUDGET brute for the whole of it, never longer than
 *   BOUNTY_GORILLA_HOLD_MAX, and they let go of anyone who drops. Counterplay: step off the ring; a
 *   shield stops the grab outright; struggle free; a friend can pull them out of it; hitting them hard
 *   (BOUNTY_GORILLA_HOLD_BREAK_DAMAGE) while they reach or hold makes them let go; a stun, a knockdown
 *   or an EMP ends it at once. Anyone who struggles or is pulled free, or a reach that closes on air or
 *   a shield, leaves them stumbling. Someone just let go can't be grabbed again for a while
 *   (BOUNTY_GORILLA_GRAB_GUARD), and someone another holds is never punched (no stepping off that tile).
 * - The piston punch. Every so often, with someone right beside them, they plant their feet and draw
 *   back a glowing fist: the tile they aim at lights up and the pistons hiss. After
 *   BOUNTY_GORILLA_WINDUP it lands on whoever still stands there, with the player implant's flat
 *   brute and wound bonus, a two-tile throw (never onto lava, into a chasm or out into space:
 *   bounty_throw_back()) and a stagger. With a wall or something solid right behind them, they are
 *   driven into it and knocked flat for a moment instead. A mech takes the implant's structure
 *   damage on its hull. A shield can block it.
 * - Stepping off the lit tile makes the punch hit air. They stumble, rooted and unable to swing, for
 *   BOUNTY_GORILLA_WHIFF_STUMBLE: the window to hit back.
 * - Doors. When whoever they were fighting gets behind a closed airlock, they force it, as the
 *   player's set bonus does: a short heave on an unpowered door, a slow loud pry on a powered one.
 *   Bolted, welded or sealed doors hold, as they do for the player implant, and that door is then
 *   left alone for a while. They never force a door on a player's ship, a hangar, an outpost or
 *   anywhere off their site (a pirate ship they are wanted aboard is their site, so its doors are
 *   fair game), or one with space or a big pressure difference across it.
 * - An EMP. A punch winding up, a reach or a hold seizes at once: whoever was held is let go and they
 *   go down; otherwise their next swing while the chrome is down seizes the same way (tg's strongarm
 *   backfire). A Juggernaut can't be knocked down while fresh, so it reels instead (boss_stagger()),
 *   open to damage.
 *
 * On a Juggernaut the punch, the grab and the pry go by its own rules: they start only when it could
 * start an ability, they push its next ability back, and they keep it busy (boss_set_busy()) so its AI
 * stays quiet meanwhile and a stun or knockdown cuts them off like any wind-up. Its own pounding
 * blows are heavier than the implant's punch, so they stay the kit's.
 */

/// Wind-up before the piston punch lands: long enough to see it and step away
#define BOUNTY_GORILLA_WINDUP (0.9 SECONDS)
/// Gap between piston punches, from the moment the wind-up starts
#define BOUNTY_GORILLA_PUNCH_COOLDOWN (8 SECONDS)
/// The first piston punch of a fight comes no sooner than this: inside a solo fight's first few seconds, or the arms never show
#define BOUNTY_GORILLA_OPENING_DELAY (1.5 SECONDS)
/// The player implant's punch (CYBERWARE_GORILLA_PUNCH_DAMAGE), before the zone's NPC scaling, and its wound bonus
#define BOUNTY_GORILLA_PUNCH_DAMAGE 20
#define BOUNTY_GORILLA_PUNCH_WOUND_BONUS 10
/// Armour penetration of the punch: a human arm's unarmed effectiveness, which the player's punch uses
#define BOUNTY_GORILLA_PUNCH_AP 10
/// What the punch caves into a mech's hull (the player implant's CYBERWARE_GORILLA_STRUCTURE_DAMAGE)
#define BOUNTY_GORILLA_MECH_DAMAGE 40
/// How far the punch throws someone, and how fast
#define BOUNTY_GORILLA_THROW_TILES 2
#define BOUNTY_GORILLA_THROW_SPEED 2
/// How long someone punched reels (slowed, swaying)
#define BOUNTY_GORILLA_STAGGER (2.5 SECONDS)
/// Knocked flat this long when driven into a wall or something solid behind them
#define BOUNTY_GORILLA_PINNED_KNOCKDOWN (1 SECONDS)
/// A punch at an empty tile: rooted and unable to swing this long
#define BOUNTY_GORILLA_WHIFF_STUMBLE (1.5 SECONDS)
/// How far they lean back while winding up, in pixels
#define BOUNTY_GORILLA_PULLBACK 3
/// An EMP'd swing: down this long. A mini-boss reels for BOUNTY_GORILLA_BACKFIRE_STAGGER instead, taking this much more damage.
#define BOUNTY_GORILLA_BACKFIRE_KNOCKDOWN (2.5 SECONDS)
#define BOUNTY_GORILLA_BACKFIRE_STAGGER (2 SECONDS)
#define BOUNTY_GORILLA_BACKFIRE_VULNERABLE 1.25
/// How long forcing a door takes: powered, unpowered, and a try at one that holds
#define BOUNTY_GORILLA_PRY_POWERED (3 SECONDS)
#define BOUNTY_GORILLA_PRY_UNPOWERED (1.2 SECONDS)
#define BOUNTY_GORILLA_PRY_HELD (1.5 SECONDS)
/// A door that held is left alone this long
#define BOUNTY_GORILLA_HELD_MEMORY (30 SECONDS)
/// Someone they lost sight of is still worth a door this long
#define BOUNTY_GORILLA_QUARRY_MEMORY (12 SECONDS)
/// How far from them a door may be to go for it: one step, then the pry
#define BOUNTY_GORILLA_DOOR_REACH 2
/// Someone further off than this isn't worth breaking in for
#define BOUNTY_GORILLA_CHASE_RANGE 9
/// Out of sight, someone this close to a door is taken to be behind it; anyone further off could be anywhere
#define BOUNTY_GORILLA_BEHIND_RANGE 5
/// A door with more than this pressure (kPa) between its sides is left shut
#define BOUNTY_GORILLA_PRESSURE_GAP 20
/// Every ordinary blow: the player implant's punch (CYBERWARE_GORILLA_PUNCH_DAMAGE, before the zone's NPC scaling), its sound, and the time between blows (each arm on the implant's rhythm, in turn)
#define BOUNTY_GORILLA_FIST_SOUND 'sound/items/weapons/punch1.ogg'
#define BOUNTY_GORILLA_FIST_INTERVAL (1.5 SECONDS)
/// The reach before a grab: long enough to see it and step off the ring
#define BOUNTY_GORILLA_REACH_TIME (0.8 SECONDS)
/// Gap between grabs, from the moment the reach starts, and the first grab of a fight comes no sooner than this
#define BOUNTY_GORILLA_GRAB_COOLDOWN (20 SECONDS)
#define BOUNTY_GORILLA_GRAB_OPENING (3 SECONDS)
/// After a grab or a piston punch, the other waits at least this long, so the two never come back to back
#define BOUNTY_GORILLA_SPECIAL_GAP (4 SECONDS)
/// Fast punches to the face before the finishing piston punch, and the beat before each blow of the pummel
#define BOUNTY_GORILLA_PUMMEL_PUNCHES 2
#define BOUNTY_GORILLA_PUMMEL_GAP (0.5 SECONDS)
/// Brute of a punch to the face, before the zone's NPC scaling: the player implant's punch
#define BOUNTY_GORILLA_FACE_DAMAGE 20
/// The most brute the whole grab may do to one hunter, after armour, finisher and all: it hurts a lot, and never kills someone healthy
#define BOUNTY_GORILLA_PUMMEL_BUDGET 55
/// Someone held is let go after this whatever happens: the hold's own clock, should the pummel be cut off without a word
#define BOUNTY_GORILLA_HOLD_MAX (2.5 SECONDS)
/// Damage they take while reaching or holding (after armour) that makes them let go
#define BOUNTY_GORILLA_HOLD_BREAK_DAMAGE 20
/// Someone just let go can't be grabbed again, by them or another, for this long
#define BOUNTY_GORILLA_GRAB_GUARD (12 SECONDS)
/// How far they lean in as they reach, in pixels
#define BOUNTY_GORILLA_REACH_LEAN 4
/// The ring under someone they reach for: the mark's pure red turned to the arms' orange (a plain colour would only darken it), so it reads apart from the piston punch's red box
#define BOUNTY_GORILLA_MARK_COLOR list(1, 0.54, 0.12, 0, 0, 0, 0, 0, 0)
/// Trait source for standing still mid-punch, mid-pry and stumbling
#define BOUNTY_GORILLA_TRAIT "bounty_chrome_gorilla"
/// What a mini-boss's boss_busy says while its arms are busy
#define BOUNTY_GORILLA_BOSS_BUSY "gorilla"
/// What its arms are doing (busy)
#define BOUNTY_GORILLA_PUNCH "punch"
#define BOUNTY_GORILLA_PRY "pry"
#define BOUNTY_GORILLA_STUMBLE "stumble"
#define BOUNTY_GORILLA_REACH "reach"
#define BOUNTY_GORILLA_HOLD "hold"
/// The glow on them while a punch winds up, and the colour of the lit tile
#define BOUNTY_GORILLA_GLOW "bounty_gorilla_glow"
#define BOUNTY_GORILLA_COLOR "#ff8a1f"

/datum/bounty_chrome/gorilla
	key = BOUNTY_CHROME_GORILLA
	name = "Gorilla Arms"
	weight = 12
	min_tier = BOUNTY_TIER_PETTY
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL, BOUNTY_ARCHETYPE_BOSS, BOUNTY_CHROME_COMPANION)
	// Bare fists only: the player implant powers a punch, not a bat, a knife or a trigger finger
	styles = list(BOUNTY_STYLE_BRAWLER)
	// The one mini-boss that fights bare-handed; can_roll() lets it past the style check
	kits = list(BOUNTY_KIT_JUGGERNAUT)
	// Both are arm implants, and an arm takes one
	exclusive_with = list(BOUNTY_CHROME_MANTIS)
	organ_looks = list(
		/obj/item/organ/cyberimp/cyberware/gorilla_arms,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/left,
	)
	examine_text = "Dull chrome plates %THEIR arms from knuckle to shoulder."
	/// What its arms are doing now: BOUNTY_GORILLA_PUNCH, _REACH, _HOLD, _PRY or _STUMBLE, or null
	var/busy
	/// Goes up with everything it starts or stops, so a stale timer does nothing
	var/serial = 0
	var/busy_timer
	/// A mini-boss's own busy serial while it is busy with this
	var/boss_serial = 0
	/// The tile the punch winding up (or the reach) lands on, who it was meant for, and the light on that tile
	var/turf/strike_turf
	var/datum/weakref/strike_target
	var/datum/weakref/strike_mark
	/// The door being forced
	var/datum/weakref/door_ref
	/// world.time the next piston punch may start
	var/punch_ready_at = 0
	/// Who they were last fighting, and when they last saw them
	var/datum/weakref/quarry_ref
	var/quarry_seen_at = 0
	/// Doors that held: weakref -> world.time they may be tried again
	var/list/held_doors
	/// EMP'd: the next swing seizes
	var/seized = FALSE
	/// A door check queued for just after they lose sight of someone
	var/door_check_timer
	/// Their ordinary blows are the implant's punch now, and the look of a blow before it was
	var/fists_armed = FALSE
	var/saved_vis_effect
	/// world.time the next grab may start
	var/grab_ready_at = 0
	/// Who they hold, the face punches still to come before the finisher, and the brute the grab may still do
	var/datum/weakref/held_ref
	var/punches_left = 0
	var/pummel_budget = 0
	/// The hold's own clock: lets go at BOUNTY_GORILLA_HOLD_MAX whatever became of the pummel
	var/hold_timer
	/// Damage they have taken since the reach started
	var/busy_damage = 0
	/// REF() of someone let go of -> world.time they may be grabbed again, shared by every gorilla
	var/static/list/grab_guard = list()

/datum/bounty_chrome/gorilla/Destroy(force)
	release()
	deltimer(busy_timer)
	busy_timer = null
	deltimer(door_check_timer)
	door_check_timer = null
	strike_turf = null
	strike_target = null
	strike_mark = null
	door_ref = null
	quarry_ref = null
	held_doors = null
	return ..()

/// A mini-boss only with the Juggernaut's kit, which has no style to check
/datum/bounty_chrome/gorilla/can_roll(tier, archetype, style, kit, list/picked)
	if(archetype == BOUNTY_ARCHETYPE_BOSS)
		if(kit != BOUNTY_KIT_JUGGERNAUT)
			return FALSE
		style = BOUNTY_STYLE_BRAWLER
	return ..(tier, archetype, style, kit, picked)

/datum/bounty_chrome/gorilla/attach(mob/living/basic/fighter)
	. = ..()
	// Sent just before their target goes: who they were after, for the doors
	RegisterSignal(fighter, COMSIG_AI_BLACKBOARD_KEY_PRECLEAR(BB_BASIC_MOB_CURRENT_TARGET), PROC_REF(on_target_lost))
	// Knocked down or stunned mid-reach or mid-hold: they let go at once, not at the next blow
	RegisterSignals(fighter, list(SIGNAL_ADDTRAIT(TRAIT_FLOORED), SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED)), PROC_REF(on_disabled))
	// Bare fists, whatever put the arms in them
	bounty_chrome_fit_style(fighter, list(BOUNTY_STYLE_BRAWLER), BOUNTY_STYLE_BRAWLER)
	update_fists()

/datum/bounty_chrome/gorilla/detach()
	if(owner)
		stop()
		unseize()
		disarm_fists()
		UnregisterSignal(owner, list(
			COMSIG_AI_BLACKBOARD_KEY_PRECLEAR(BB_BASIC_MOB_CURRENT_TARGET),
			SIGNAL_ADDTRAIT(TRAIT_FLOORED),
			SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED),
		))
	deltimer(door_check_timer)
	door_check_timer = null
	quarry_ref = null
	held_doors = null
	return ..()

/datum/bounty_chrome/gorilla/on_fight_start(atom/target)
	punch_ready_at = max(punch_ready_at, world.time + BOUNTY_GORILLA_OPENING_DELAY)
	grab_ready_at = max(grab_ready_at, world.time + BOUNTY_GORILLA_GRAB_OPENING)
	update_fists()

/datum/bounty_chrome/gorilla/on_tick(seconds_per_tick, fighting)
	update_fists()
	if(!fighting)
		return
	var/atom/target = bounty_chrome_target(owner)
	if(!QDELETED(target) && can_see(owner, target, BOUNTY_GORILLA_CHASE_RANGE))
		quarry_ref = WEAKREF(target)
		quarry_seen_at = world.time
	if(busy)
		return
	if(!QDELETED(target) && get_dist(owner, target) == 1 && try_special(target))
		return
	check_doors()

/// Their blow landed: the next one may be a grab or the big one, and otherwise the fist knocks them back a tile
/datum/bounty_chrome/gorilla/on_melee_hit(mob/living/target)
	if(busy || QDELETED(owner))
		return
	if(try_special(target))
		return
	if(fists_armed)
		knock_back(target)

/datum/bounty_chrome/gorilla/on_downed()
	stop()
	unseize()

/datum/bounty_chrome/gorilla/on_death()
	stop()
	unseize()
	quarry_ref = null

/// Mid-swing, mid-reach or mid-hold the arm seizes now; otherwise the next swing does. Either way their fists are only fists until the reboot.
/datum/bounty_chrome/gorilla/on_emp(severity)
	var/was_busy = busy
	stop()
	disarm_fists()
	if(was_busy == BOUNTY_GORILLA_PUNCH || was_busy == BOUNTY_GORILLA_REACH || was_busy == BOUNTY_GORILLA_HOLD)
		backfire()
	else
		seize()

/datum/bounty_chrome/gorilla/on_reboot()
	unseize()
	update_fists()

/// A hard hit while they reach or hold, and they let go
/datum/bounty_chrome/gorilla/on_damaged(damage, damagetype)
	if(busy != BOUNTY_GORILLA_REACH && busy != BOUNTY_GORILLA_HOLD)
		return
	if(damage <= 0 || !(damagetype in list(BRUTE, BURN, STAMINA)))
		return
	busy_damage += damage
	if(busy_damage >= BOUNTY_GORILLA_HOLD_BREAK_DAMAGE)
		lose_grip()

/// Every blow is the empowered punch, so a brawler's own shove stays out of it
/datum/bounty_chrome/gorilla/owns_blow()
	return fists_armed

// ----- state -----

/// Whether its arms can be used now: in a fight they can take part in, standing on a tile, the chrome working, and nobody playing them (whose own clicks would set it off)
/datum/bounty_chrome/gorilla/proc/able()
	if(!online() || !isturf(owner.loc) || owner.client || owner.mind)
		return FALSE
	// Still getting up after a knockdown: tg's pull is blocked while lying, so no grab could take hold
	if(owner.body_position == LYING_DOWN)
		return FALSE
	return bounty_chrome_fighting(owner)

/// The mini-boss it is in, or null
/datum/bounty_chrome/gorilla/proc/boss()
	return istype(owner, /mob/living/basic/bounty_criminal/boss) ? owner : null

/**
 * Whether a piston punch may land on `victim`: someone they may hit who is a hunter (or the one it
 * was thrown at), or a mech with a hunter in it. A mini-boss goes by its own rules (boss_can_hurt()).
 */
/datum/bounty_chrome/gorilla/proc/may_punch(atom/victim, atom/meant_for)
	if(QDELETED(victim) || victim == owner || !(isliving(victim) || ismecha(victim)))
		return FALSE
	var/mob/living/basic/bounty_criminal/boss/boss = boss()
	if(boss)
		return boss.boss_can_hurt(victim)
	if(!bounty_ai_may_hit(owner, victim))
		return FALSE
	if(victim == meant_for)
		return TRUE
	if(ismecha(victim))
		var/obj/vehicle/sealed/mecha/mech = victim
		for(var/mob/living/pilot in mech.occupants)
			if(bounty_ai_is_hunter(pilot))
				return TRUE
		return FALSE
	return bounty_ai_is_hunter(victim)

/**
 * Starts `state` for `duration`: rooted, no blows meanwhile, and a mini-boss kept busy so its AI
 * stays quiet and its own abilities wait. Returns FALSE if a mini-boss can't start anything now.
 */
/datum/bounty_chrome/gorilla/proc/begin(state, duration)
	var/mob/living/basic/bounty_criminal/boss/boss = boss()
	if(boss)
		if(!boss.boss_can_use_ability())
			return FALSE
		boss.boss_next_ability_at = max(boss.boss_next_ability_at, world.time + duration + rand(BOUNTY_BOSS_ABILITY_GAP_MIN, BOUNTY_BOSS_ABILITY_GAP_MAX))
		boss_serial = boss.boss_set_busy(BOUNTY_GORILLA_BOSS_BUSY, duration + 1 SECONDS)
	busy = state
	serial++
	busy_damage = 0
	ADD_TRAIT(owner, TRAIT_IMMOBILIZED, BOUNTY_GORILLA_TRAIT)
	owner.changeNext_move(duration + 0.2 SECONDS)
	return TRUE

/// Whether a mini-boss is still busy with this (nothing stunned it or cut it off); TRUE for anyone else
/datum/bounty_chrome/gorilla/proc/boss_still_busy()
	var/mob/living/basic/bounty_criminal/boss/boss = boss()
	return !boss || (boss.boss_busy == BOUNTY_GORILLA_BOSS_BUSY && boss.boss_busy_serial == boss_serial)

/// Free again: on the move, the glow off, a mini-boss's busy given back
/datum/bounty_chrome/gorilla/proc/end_busy()
	busy = null
	if(!owner)
		boss_serial = 0
		return
	REMOVE_TRAIT(owner, TRAIT_IMMOBILIZED, BOUNTY_GORILLA_TRAIT)
	owner.remove_filter(BOUNTY_GORILLA_GLOW)
	var/mob/living/basic/bounty_criminal/boss/boss = boss()
	if(boss_serial && boss && boss.boss_busy == BOUNTY_GORILLA_BOSS_BUSY && boss.boss_busy_serial == boss_serial)
		boss.boss_clear_busy(boss_serial)
	boss_serial = 0

/// Cuts off whatever its arms are doing: nothing lands, nothing opens, and whoever they hold is let go
/datum/bounty_chrome/gorilla/proc/stop()
	serial++
	deltimer(busy_timer)
	busy_timer = null
	release()
	clear_mark()
	strike_turf = null
	strike_target = null
	door_ref = null
	end_busy()

/datum/bounty_chrome/gorilla/proc/clear_mark()
	var/obj/effect/mark = strike_mark?.resolve()
	strike_mark = null
	if(!QDELETED(mark))
		qdel(mark)

/// Whether nothing is in their hand: the punch and the grab are a bare fist's (blades out, the blades are the weapon)
/datum/bounty_chrome/gorilla/proc/bare_handed()
	return !bounty_ai_held_look(owner)

/// A knockdown or a stun mid-reach, mid-hold or mid-wind-up: it all stops now
/datum/bounty_chrome/gorilla/proc/on_disabled(datum/source)
	SIGNAL_HANDLER
	if(busy == BOUNTY_GORILLA_REACH || busy == BOUNTY_GORILLA_HOLD || busy == BOUNTY_GORILLA_PUNCH)
		stop()

/// The grab first when it is ready (the rarer of the two), else the piston punch. TRUE if one started.
/datum/bounty_chrome/gorilla/proc/try_special(atom/target)
	if(busy)
		return FALSE
	return start_grab(target) || start_punch(target)

// ----- the fists -----

/**
 * Keeps their ordinary blow the implant's punch while the chrome works and their hands are bare; a
 * mini-boss keeps its kit's heavier blow. Re-arms if a style change put a plain punch back. Cheap.
 */
/datum/bounty_chrome/gorilla/proc/update_fists()
	if(!owner)
		return
	if(!online() || boss() || !bare_handed())
		if(fists_armed)
			disarm_fists()
		return
	if(!fists_armed || owner.npc_zone_original_melee_upper != BOUNTY_GORILLA_PUNCH_DAMAGE || owner.melee_attack_cooldown != BOUNTY_GORILLA_FIST_INTERVAL)
		arm_fists()

/// Their blow becomes the implant's punch: its brute, wound bonus, armour penetration and sound, at the arms' pace
/datum/bounty_chrome/gorilla/proc/arm_fists()
	if(!fists_armed)
		saved_vis_effect = owner.attack_vis_effect
	fists_armed = TRUE
	owner.set_npc_zone_melee(BOUNTY_GORILLA_PUNCH_DAMAGE, BOUNTY_GORILLA_PUNCH_DAMAGE)
	owner.melee_damage_type = BRUTE
	owner.sharpness = NONE
	owner.wound_bonus = BOUNTY_GORILLA_PUNCH_WOUND_BONUS
	owner.armour_penetration = BOUNTY_GORILLA_PUNCH_AP
	owner.attack_sound = BOUNTY_GORILLA_FIST_SOUND
	owner.attack_vis_effect = ATTACK_EFFECT_SMASH
	owner.melee_attack_cooldown = BOUNTY_GORILLA_FIST_INTERVAL

/**
 * Their blow is their own again: their style's pace, and a plain punch if their hands are bare (a
 * blade that came out keeps the blade's numbers, which are already on them).
 */
/datum/bounty_chrome/gorilla/proc/disarm_fists()
	if(!fists_armed)
		return
	fists_armed = FALSE
	if(!owner)
		return
	var/datum/bounty_style/style = bounty_ai_style(owner)
	if(style)
		owner.melee_attack_cooldown = style.interval
	if(!bare_handed())
		return
	owner.attack_vis_effect = saved_vis_effect
	bounty_real_weapon(null).apply_melee(owner)

/// An ordinary punch knocks `target` back a tile, gently, as the player implant's does (never onto lava, into a chasm or out into space)
/datum/bounty_chrome/gorilla/proc/knock_back(mob/living/target)
	if(QDELETED(target) || target.stat == DEAD || target.body_position == LYING_DOWN || owner.body_position == LYING_DOWN)
		return FALSE
	return bounty_throw_back(owner, target, 1, rand(1, 4), gentle = TRUE) > 0

// ----- the piston punch -----

/**
 * Winds up a piston punch at `target`, right beside them: rooted, a glow, a lean back, the tile lit
 * and the pistons heard. Returns TRUE if it started.
 */
/datum/bounty_chrome/gorilla/proc/start_punch(atom/target)
	if(busy || world.time < punch_ready_at || !able() || !bare_handed())
		return FALSE
	if(QDELETED(target) || !isturf(target.loc) || get_dist(owner, target) != 1 || !owner.Adjacent(target) || !may_punch(target, target) || held_by_other(target))
		return FALSE
	if(!begin(BOUNTY_GORILLA_PUNCH, BOUNTY_GORILLA_WINDUP))
		return FALSE
	punch_ready_at = world.time + BOUNTY_GORILLA_PUNCH_COOLDOWN
	grab_ready_at = max(grab_ready_at, world.time + BOUNTY_GORILLA_WINDUP + BOUNTY_GORILLA_SPECIAL_GAP)
	strike_turf = get_turf(target)
	strike_target = WEAKREF(target)
	owner.face_atom(target)
	owner.visible_message(span_boldwarning("[owner] draws back a piston-driven fist!"), blind_message = span_hear("You hear pistons hiss."))
	playsound(owner, 'sound/machines/piston/piston_raise.ogg', 60, TRUE)
	strike_mark = WEAKREF(new /obj/effect/temp_visual/bounty_boss_mark(strike_turf, BOUNTY_GORILLA_WINDUP, BOUNTY_GORILLA_COLOR))
	owner.add_filter(BOUNTY_GORILLA_GLOW, 2, outline_filter(1, BOUNTY_GORILLA_COLOR))
	// Leans back from the tile over the wind-up, and is back where it was as the fist comes down
	var/direction = get_dir(owner, strike_turf)
	var/lean_x = (direction & EAST) ? -BOUNTY_GORILLA_PULLBACK : ((direction & WEST) ? BOUNTY_GORILLA_PULLBACK : 0)
	var/lean_y = (direction & NORTH) ? -BOUNTY_GORILLA_PULLBACK : ((direction & SOUTH) ? BOUNTY_GORILLA_PULLBACK : 0)
	animate(owner, pixel_x = owner.pixel_x + lean_x, pixel_y = owner.pixel_y + lean_y, time = BOUNTY_GORILLA_WINDUP * 0.8, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(pixel_x = owner.pixel_x - lean_x, pixel_y = owner.pixel_y - lean_y, time = BOUNTY_GORILLA_WINDUP * 0.2)
	busy_timer = addtimer(CALLBACK(src, PROC_REF(finish_punch), serial), BOUNTY_GORILLA_WINDUP, TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

/**
 * The wind-up under `for_serial` is over: the punch lands on whoever it may hit on the lit tile.
 * If the one it was meant for stepped off it, it hits air and they stumble; if that one is still
 * there but down, or held fast by someone else meanwhile, it is pulled. Nothing at all if they were
 * stunned, downed or EMP'd meanwhile. Returns TRUE if it hurt someone.
 */
/datum/bounty_chrome/gorilla/proc/finish_punch(for_serial)
	if(for_serial != serial || busy != BOUNTY_GORILLA_PUNCH)
		return FALSE
	busy_timer = null
	var/turf/spot = strike_turf
	var/atom/meant = strike_target?.resolve()
	strike_turf = null
	strike_target = null
	clear_mark()
	var/still_busy = boss_still_busy()
	end_busy()
	if(!still_busy || !spot || !able() || !owner.Adjacent(spot))
		return FALSE
	var/atom/victim
	if(!QDELETED(meant) && get_turf(meant) == spot && may_punch(meant, meant) && !held_by_other(meant))
		victim = meant
	else
		for(var/atom/movable/thing as anything in spot)
			if(may_punch(thing, meant) && !held_by_other(thing))
				victim = thing
				break
	if(victim)
		return slam(victim)
	if(QDELETED(meant) || get_turf(meant) != spot)
		whiff(spot)
	return FALSE

/**
 * The punch lands on `victim`: a person, or a mech's hull. `damage_cap` is the most brute it may do a
 * person after armour (what is left of the grab's budget), or null for no cap. `aim` is the body zone
 * it lands on (the pummel's finisher goes to the face), or null for wherever. Returns TRUE if it hurt.
 */
/datum/bounty_chrome/gorilla/proc/slam(atom/victim, damage_cap, aim)
	owner.face_atom(victim)
	owner.do_attack_animation(victim, ATTACK_EFFECT_SMASH)
	if(ismecha(victim))
		var/obj/vehicle/sealed/mecha/mech = victim
		playsound(mech, 'sound/effects/clang.ogg', 70, TRUE)
		owner.visible_message(span_danger("[owner] caves [mech] in with a piston-driven fist!"))
		mech.take_damage(npc_zone_damage(BOUNTY_GORILLA_MECH_DAMAGE, owner), BRUTE, MELEE, TRUE, get_dir(mech, owner), BOUNTY_GORILLA_PUNCH_AP)
		return TRUE
	var/mob/living/person = victim
	if(person.check_block(owner, BOUNTY_GORILLA_PUNCH_DAMAGE, "[owner]'s piston punch", MELEE_ATTACK, BOUNTY_GORILLA_PUNCH_AP))
		playsound(person, 'sound/items/weapons/punchmiss.ogg', 40, TRUE)
		return FALSE
	var/throw_dir = get_dir(owner, person)
	playsound(person, 'sound/items/weapons/punch1.ogg', 60, TRUE)
	playsound(person, 'sound/effects/meteorimpact.ogg', 30, TRUE)
	var/zone = aim || person.get_random_valid_zone(BODY_ZONE_CHEST)
	var/armour = person.run_armor_check(zone, MELEE, armour_penetration = BOUNTY_GORILLA_PUNCH_AP, silent = TRUE)
	var/damage = npc_zone_damage(BOUNTY_GORILLA_PUNCH_DAMAGE, owner)
	if(!isnull(damage_cap))
		damage = bounty_gorilla_capped_damage(damage, armour, damage_cap)
	if(damage > 0)
		person.apply_damage(damage, BRUTE, zone, armour, wound_bonus = BOUNTY_GORILLA_PUNCH_WOUND_BONUS, attack_direction = throw_dir)
	shake_camera(person, 3, 2)
	log_combat(owner, person, "piston-punched", "gorilla arms")
	if(QDELETED(person) || person.stat == DEAD)
		return TRUE
	var/atom/backstop = bounty_gorilla_backstop(person, throw_dir)
	if(backstop)
		person.visible_message(
			span_danger("[owner] drives [person] into [backstop] with a piston-driven fist!"),
			span_userdanger("[owner] drives you into [backstop] with a piston-driven fist!"),
		)
		playsound(person, 'sound/effects/bang.ogg', 50, TRUE)
		person.Knockdown(BOUNTY_GORILLA_PINNED_KNOCKDOWN)
	else
		person.visible_message(
			span_danger("[owner] slams [person] with a piston-driven fist!"),
			span_userdanger("[owner] slams you with a piston-driven fist!"),
		)
		bounty_throw_back(owner, person, BOUNTY_GORILLA_THROW_TILES, BOUNTY_GORILLA_THROW_SPEED, gentle = TRUE)
	person.apply_status_effect(/datum/status_effect/staggered, BOUNTY_GORILLA_STAGGER)
	return TRUE

/// The punch hit air over `spot`: they overbalance, rooted and unable to swing for a moment
/datum/bounty_chrome/gorilla/proc/whiff(turf/spot)
	owner.do_attack_animation(spot)
	playsound(owner, 'sound/items/weapons/punchmiss.ogg', 50, TRUE)
	owner.visible_message(span_warning("[owner]'s fist hits nothing but air, and [owner.p_they()] stumble[owner.p_s()]!"))
	stumble()

/// Off balance: rooted and unable to swing for BOUNTY_GORILLA_WHIFF_STUMBLE, the window to hit back. A mini-boss reels instead.
/datum/bounty_chrome/gorilla/proc/stumble()
	if(QDELETED(owner) || owner.stat != CONSCIOUS)
		return
	owner.apply_status_effect(/datum/status_effect/staggered, BOUNTY_GORILLA_WHIFF_STUMBLE)
	var/mob/living/basic/bounty_criminal/boss/boss = boss()
	if(boss)
		boss.boss_stagger(BOUNTY_GORILLA_WHIFF_STUMBLE)
		return
	deltimer(busy_timer)
	busy = BOUNTY_GORILLA_STUMBLE
	serial++
	ADD_TRAIT(owner, TRAIT_IMMOBILIZED, BOUNTY_GORILLA_TRAIT)
	owner.changeNext_move(BOUNTY_GORILLA_WHIFF_STUMBLE)
	busy_timer = addtimer(CALLBACK(src, PROC_REF(end_stumble), serial), BOUNTY_GORILLA_WHIFF_STUMBLE, TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/bounty_chrome/gorilla/proc/end_stumble(for_serial)
	if(for_serial != serial || busy != BOUNTY_GORILLA_STUMBLE)
		return
	busy_timer = null
	end_busy()

/**
 * What `person` would be driven into if punched toward `throw_dir`: a wall, or something solid on
 * the tile behind them. Null when there is room to throw them (or the tile behind is a drop, lava or
 * space, which bounty_throw_back() refuses on its own).
 */
/proc/bounty_gorilla_backstop(mob/living/person, throw_dir)
	var/turf/behind = get_step(person, throw_dir)
	if(!behind)
		return null
	if(isclosedturf(behind))
		return behind
	for(var/obj/thing in behind)
		if(thing.density && !thing.CanPass(person, throw_dir))
			return thing
	return null

// ----- the grab and pummel -----

/**
 * Whether they may grab `person`: a hunter beside them they may hit, awake and on their feet, on a
 * tile of their own (not in a mech, not strapped into anything), someone tg's grab can take hold of
 * aggressively (not a borg, not someone who can't be pushed about or pulled), not held fast by anyone
 * already, and not one just let go (BOUNTY_GORILLA_GRAB_GUARD).
 */
/datum/bounty_chrome/gorilla/proc/may_grab(mob/living/person)
	if(!isliving(person) || QDELETED(person) || person == owner || !isturf(person.loc) || person.buckled || person.anchored)
		return FALSE
	if(person.stat != CONSCIOUS || person.body_position == LYING_DOWN)
		return FALSE
	// tg's grab never tightens on these (grabbedby(), silicon grippedby())
	if(issilicon(person) || !(person.status_flags & CANPUSH) || HAS_TRAIT(person, TRAIT_PUSHIMMUNE))
		return FALSE
	if(person.pulledby?.grab_state >= GRAB_AGGRESSIVE)
		return FALSE
	if(grab_guard[REF(person)] > world.time)
		return FALSE
	if(!may_punch(person, person))
		return FALSE
	return person.can_be_pulled(owner, owner.pull_force)

/// Whether they hold `person` fast now: tg's aggressive grab, theirs
/datum/bounty_chrome/gorilla/proc/holding(mob/living/person)
	return owner && !QDELETED(person) && owner.pulling == person && owner.grab_state >= GRAB_AGGRESSIVE

/// Whether someone other than them holds `target` fast: no piston punch at a person who can't step off the lit tile
/datum/bounty_chrome/gorilla/proc/held_by_other(atom/target)
	var/mob/living/person = target
	if(!isliving(person) || !person.pulledby || person.pulledby == owner)
		return FALSE
	return person.pulledby.grab_state >= GRAB_AGGRESSIVE

/**
 * Reaches for `target`, right beside them: rooted, a glow, a lean in, a ring lit under them and the
 * pistons heard. Returns TRUE if it started.
 */
/datum/bounty_chrome/gorilla/proc/start_grab(mob/living/target)
	if(busy || world.time < grab_ready_at || !able() || !bare_handed())
		return FALSE
	if(!may_grab(target) || get_dist(owner, target) != 1 || !owner.Adjacent(target))
		return FALSE
	var/hold_time = BOUNTY_GORILLA_PUMMEL_GAP * (BOUNTY_GORILLA_PUMMEL_PUNCHES + 1)
	if(!begin(BOUNTY_GORILLA_REACH, BOUNTY_GORILLA_REACH_TIME))
		return FALSE
	grab_ready_at = world.time + BOUNTY_GORILLA_GRAB_COOLDOWN
	punch_ready_at = max(punch_ready_at, world.time + BOUNTY_GORILLA_REACH_TIME + hold_time + BOUNTY_GORILLA_SPECIAL_GAP)
	strike_turf = get_turf(target)
	strike_target = WEAKREF(target)
	owner.face_atom(target)
	owner.visible_message(span_boldwarning("[owner] reaches for [target] with both chrome hands!"), blind_message = span_hear("You hear pistons sigh."))
	playsound(owner, 'sound/machines/piston/piston_lower.ogg', 60, TRUE)
	strike_mark = WEAKREF(new /obj/effect/temp_visual/bounty_boss_mark(strike_turf, BOUNTY_GORILLA_REACH_TIME, BOUNTY_GORILLA_MARK_COLOR, "target_circle"))
	owner.add_filter(BOUNTY_GORILLA_GLOW, 2, outline_filter(1, BOUNTY_GORILLA_COLOR))
	// Leans in toward them over the reach, and is back where it was as the hands close
	var/direction = get_dir(owner, strike_turf)
	var/lean_x = (direction & EAST) ? BOUNTY_GORILLA_REACH_LEAN : ((direction & WEST) ? -BOUNTY_GORILLA_REACH_LEAN : 0)
	var/lean_y = (direction & NORTH) ? BOUNTY_GORILLA_REACH_LEAN : ((direction & SOUTH) ? -BOUNTY_GORILLA_REACH_LEAN : 0)
	animate(owner, pixel_x = owner.pixel_x + lean_x, pixel_y = owner.pixel_y + lean_y, time = BOUNTY_GORILLA_REACH_TIME * 0.8, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(pixel_x = owner.pixel_x - lean_x, pixel_y = owner.pixel_y - lean_y, time = BOUNTY_GORILLA_REACH_TIME * 0.2)
	busy_timer = addtimer(CALLBACK(src, PROC_REF(finish_reach), serial), BOUNTY_GORILLA_REACH_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

/**
 * The reach under `for_serial` is over: they grab whoever they may on the ringed tile. If the one they
 * reached for stepped off it, their hands close on air and they stumble; a shield stops the grab
 * outright, and they stumble too. Nothing at all if they were stunned, downed, hit hard or EMP'd
 * meanwhile, or whoever stands there can't be grabbed now. Returns TRUE if they got hold of someone.
 */
/datum/bounty_chrome/gorilla/proc/finish_reach(for_serial)
	if(for_serial != serial || busy != BOUNTY_GORILLA_REACH)
		return FALSE
	busy_timer = null
	var/turf/spot = strike_turf
	var/mob/living/meant = strike_target?.resolve()
	strike_turf = null
	strike_target = null
	clear_mark()
	if(!boss_still_busy() || !spot || !able() || !owner.Adjacent(spot))
		end_busy()
		return FALSE
	var/mob/living/victim
	if(!QDELETED(meant) && get_turf(meant) == spot && may_grab(meant))
		victim = meant
	else
		for(var/mob/living/person in spot)
			if(may_grab(person))
				victim = person
				break
	if(!victim)
		end_busy()
		if(QDELETED(meant) || get_turf(meant) != spot)
			owner.do_attack_animation(spot)
			playsound(owner, 'sound/items/weapons/punchmiss.ogg', 50, TRUE)
			owner.visible_message(span_warning("[owner]'s hands close on empty air, and [owner.p_they()] stumble[owner.p_s()]!"))
			stumble()
		return FALSE
	// A shield takes a grab as it takes a tackle: outright
	if(victim.check_block(owner, npc_zone_damage(BOUNTY_GORILLA_FACE_DAMAGE, owner), "[owner]'s grab", LEAP_ATTACK, BOUNTY_GORILLA_PUNCH_AP))
		end_busy()
		playsound(victim, 'sound/effects/bang.ogg', 40, TRUE)
		stumble()
		return FALSE
	return grab(victim)

/**
 * They get hold of `victim` in tg's aggressive grab (take_hold()), the pummel's first punch a beat
 * away. A mini-boss is kept busy for the whole of it.
 */
/datum/bounty_chrome/gorilla/proc/grab(mob/living/victim)
	var/hold_time = BOUNTY_GORILLA_PUMMEL_GAP * (BOUNTY_GORILLA_PUMMEL_PUNCHES + 1)
	owner.face_atom(victim)
	if(!take_hold(victim))
		end_busy()
		return FALSE
	owner.do_attack_animation(victim)
	busy = BOUNTY_GORILLA_HOLD
	serial++
	held_ref = WEAKREF(victim)
	punches_left = BOUNTY_GORILLA_PUMMEL_PUNCHES
	pummel_budget = BOUNTY_GORILLA_PUMMEL_BUDGET
	// Struggled free, pulled away by a friend, or the two parted: tg lets go, and they hear of it
	RegisterSignal(owner, COMSIG_ATOM_NO_LONGER_PULLING, PROC_REF(on_hold_broken))
	deltimer(hold_timer)
	hold_timer = addtimer(CALLBACK(src, PROC_REF(hold_expired)), BOUNTY_GORILLA_HOLD_MAX, TIMER_STOPPABLE | TIMER_DELETE_ME)
	ADD_TRAIT(owner, TRAIT_IMMOBILIZED, BOUNTY_GORILLA_TRAIT)
	owner.changeNext_move(hold_time + 0.2 SECONDS)
	var/mob/living/basic/bounty_criminal/boss/boss = boss()
	if(boss)
		boss.boss_next_ability_at = max(boss.boss_next_ability_at, world.time + hold_time + rand(BOUNTY_BOSS_ABILITY_GAP_MIN, BOUNTY_BOSS_ABILITY_GAP_MAX))
		boss_serial = boss.boss_set_busy(BOUNTY_GORILLA_BOSS_BUSY, hold_time + 1 SECONDS)
	busy_timer = addtimer(CALLBACK(src, PROC_REF(pummel), serial), BOUNTY_GORILLA_PUMMEL_GAP, TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

/**
 * tg's own aggressive grab on `victim`, the way a player takes one: the pull, then the grip tightened
 * at once (a first upgrade always is), with tg's sound, line and log, and all its rules from then on.
 * A basic mob may only pull (max_grab), so the arms lift that just for this. TRUE if they now hold
 * `victim` aggressively; otherwise nothing is left half-done.
 */
/datum/bounty_chrome/gorilla/proc/take_hold(mob/living/victim)
	var/old_max_grab = owner.max_grab
	owner.max_grab = max(old_max_grab, GRAB_AGGRESSIVE)
	victim.grabbedby(owner, supress_message = TRUE)
	if(owner.pulling == victim && owner.grab_state < GRAB_AGGRESSIVE)
		victim.grabbedby(owner)
	owner.max_grab = old_max_grab
	if(holding(victim))
		return TRUE
	if(owner.pulling == victim)
		owner.stop_pulling()
	return FALSE

/// Whether the hold on `victim` goes on: they can still act, nothing cut them off, and the one they hold is awake, on their feet, beside them and still held by them
/datum/bounty_chrome/gorilla/proc/hold_ok(mob/living/victim)
	if(!able() || !boss_still_busy() || QDELETED(victim) || victim.stat != CONSCIOUS || victim.body_position == LYING_DOWN || !isturf(victim.loc))
		return FALSE
	return holding(victim) && owner.Adjacent(victim)

/**
 * tg let go of the one they hold, and not because they did: struggled free (resist_grab()), pulled
 * away by a friend, or the two parted. They are left off balance, unless whatever did it put them down
 * too. Must not sleep: it runs inside stop_pulling().
 */
/datum/bounty_chrome/gorilla/proc/on_hold_broken(datum/source, atom/movable/was_pulling)
	SIGNAL_HANDLER
	if(busy != BOUNTY_GORILLA_HOLD || was_pulling != held_ref?.resolve())
		return
	var/shaken_off = owner.stat == CONSCIOUS && owner.body_position != LYING_DOWN && !HAS_TRAIT(owner, TRAIT_INCAPACITATED)
	stop()
	if(shaken_off)
		stumble()

/// The hold's own clock ran out with someone still held: let go, whatever kept the pummel from finishing
/datum/bounty_chrome/gorilla/proc/hold_expired()
	hold_timer = null
	if(held_ref)
		stop()

/**
 * One blow of the pummel under `for_serial`: a punch to the face while any are left, then the
 * finisher, the piston punch, which lets go and throws them back (slam()). Every blow keeps to what
 * is left of the budget. If the hold broke meanwhile (they went down, got loose, were knocked out of
 * reach) they let go and nothing lands. Returns TRUE if a blow was thrown.
 */
/datum/bounty_chrome/gorilla/proc/pummel(for_serial)
	if(for_serial != serial || busy != BOUNTY_GORILLA_HOLD)
		return FALSE
	busy_timer = null
	var/mob/living/victim = held_ref?.resolve()
	if(!hold_ok(victim))
		stop()
		return FALSE
	if(punches_left > 0)
		punches_left--
		face_punch(victim)
		if(QDELETED(victim) || victim.stat != CONSCIOUS)
			stop()
			return TRUE
		serial++
		busy_timer = addtimer(CALLBACK(src, PROC_REF(pummel), serial), BOUNTY_GORILLA_PUMMEL_GAP, TIMER_STOPPABLE | TIMER_DELETE_ME)
		return TRUE
	// The finisher: let go, and the piston punch to the face sends them off
	var/budget_left = pummel_budget
	serial++
	release()
	end_busy()
	slam(victim, budget_left, BODY_ZONE_HEAD)
	return TRUE

/// A punch to `victim`'s face: the implant's punch, against their head's armour, within what is left of the budget
/datum/bounty_chrome/gorilla/proc/face_punch(mob/living/victim)
	owner.face_atom(victim)
	owner.do_attack_animation(victim, ATTACK_EFFECT_PUNCH)
	playsound(victim, BOUNTY_GORILLA_FIST_SOUND, 70, TRUE)
	playsound(victim, 'sound/effects/hit_punch.ogg', 40, TRUE)
	var/armour = victim.run_armor_check(BODY_ZONE_HEAD, MELEE, armour_penetration = BOUNTY_GORILLA_PUNCH_AP, silent = TRUE)
	var/damage = bounty_gorilla_capped_damage(npc_zone_damage(BOUNTY_GORILLA_FACE_DAMAGE, owner), armour, pummel_budget)
	if(damage > 0)
		pummel_budget = max(0, pummel_budget - victim.apply_damage(damage, BRUTE, BODY_ZONE_HEAD, armour, attack_direction = get_dir(owner, victim)))
	shake_camera(victim, 2, 2)
	victim.set_eye_blur_if_lower(1 SECONDS)
	victim.visible_message(
		span_danger("[owner] drives a chrome fist into [victim]'s face!"),
		span_userdanger("[owner] drives a chrome fist into your face!"),
	)
	log_combat(owner, victim, "pummelled", "gorilla arms")

/// Hit hard while reaching or holding: they let go and reel
/datum/bounty_chrome/gorilla/proc/lose_grip()
	var/mob/living/victim = held_ref?.resolve()
	if(victim)
		owner.visible_message(span_warning("[owner] loses [owner.p_their()] grip on [victim]!"))
	else
		owner.visible_message(span_warning("[owner] flinches back!"))
	stop()
	stumble()

/// Lets go of whoever they hold (tg's stop_pulling()), who can't be grabbed again for a while. Safe at any time.
/datum/bounty_chrome/gorilla/proc/release()
	var/mob/living/victim = held_ref?.resolve()
	held_ref = null
	punches_left = 0
	deltimer(hold_timer)
	hold_timer = null
	if(owner)
		// Before letting go, so on_hold_broken() doesn't take it for a struggle
		UnregisterSignal(owner, COMSIG_ATOM_NO_LONGER_PULLING)
		if(victim && owner.pulling == victim)
			owner.stop_pulling()
	if(QDELETED(victim))
		return
	var/list/expired = list()
	for(var/key in grab_guard)
		if(grab_guard[key] <= world.time)
			expired += key
	grab_guard -= expired
	grab_guard[REF(victim)] = world.time + BOUNTY_GORILLA_GRAB_GUARD

/// The most of `raw` brute that lets through no more than `budget` past `armour` (percent blocked)
/proc/bounty_gorilla_capped_damage(raw, armour, budget)
	if(budget <= 0 || raw <= 0)
		return 0
	return min(raw, budget * 100 / max(100 - armour, 1))

// ----- EMP -----

/// The arms are seized: the next swing while the chrome is down backfires
/datum/bounty_chrome/gorilla/proc/seize()
	if(seized || !owner)
		return
	seized = TRUE
	RegisterSignal(owner, COMSIG_HOSTILE_PRE_ATTACKINGTARGET, PROC_REF(on_seized_swing))

/datum/bounty_chrome/gorilla/proc/unseize()
	if(!seized)
		return
	seized = FALSE
	if(owner)
		UnregisterSignal(owner, COMSIG_HOSTILE_PRE_ATTACKINGTARGET)

/// A swing at someone while seized: it never lands, and they go down
/datum/bounty_chrome/gorilla/proc/on_seized_swing(mob/living/basic/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!seized || source.stat != CONSCIOUS || !may_punch(target, target))
		return NONE
	unseize()
	INVOKE_ASYNC(src, PROC_REF(backfire))
	return COMPONENT_HOSTILE_NO_ATTACK

/// The arm seizes mid-swing: they go down. A mini-boss reels instead, open to damage.
/datum/bounty_chrome/gorilla/proc/backfire()
	if(QDELETED(owner) || owner.stat != CONSCIOUS)
		return
	owner.visible_message(span_warning("[owner]'s arm seizes mid-swing, and [owner.p_they()] go[owner.p_es()] down!"))
	do_sparks(2, FALSE, owner)
	playsound(owner, SFX_BODYFALL, 50, TRUE)
	var/mob/living/basic/bounty_criminal/boss/boss = boss()
	if(boss)
		boss.boss_stagger(BOUNTY_GORILLA_BACKFIRE_STAGGER, BOUNTY_GORILLA_BACKFIRE_VULNERABLE)
		return
	owner.Knockdown(BOUNTY_GORILLA_BACKFIRE_KNOCKDOWN)

// ----- doors -----

/// Their target is about to go (out of sight, down, gone): who it was, and a look for a door in a moment. Must return NONE, or the target stays.
/datum/bounty_chrome/gorilla/proc/on_target_lost(datum/source)
	SIGNAL_HANDLER
	if(!online() || QDELETED(owner.ai_controller))
		return NONE
	var/atom/target = owner.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(target) || !(isliving(target) || ismecha(target)))
		return NONE
	quarry_ref = WEAKREF(target)
	quarry_seen_at = world.time
	if(!door_check_timer)
		door_check_timer = addtimer(CALLBACK(src, PROC_REF(check_doors)), 0.5 SECONDS, TIMER_STOPPABLE | TIMER_DELETE_ME)
	return NONE

/**
 * Whoever they are after and can't get at: their target out of sight or behind a closed glass door,
 * or someone they lost sight of in the last BOUNTY_GORILLA_QUARRY_MEMORY. If a closed airlock near
 * them is in the way, they go for it: a step to it if need be, then the pry. Returns TRUE if they
 * did something.
 */
/datum/bounty_chrome/gorilla/proc/check_doors()
	door_check_timer = null
	if(busy || !able())
		return FALSE
	var/atom/quarry = bounty_chrome_target(owner)
	var/in_sight = FALSE
	if(!QDELETED(quarry))
		in_sight = can_see(owner, quarry, BOUNTY_GORILLA_CHASE_RANGE)
		if(in_sight && get_dist(owner, quarry) <= 1)
			return FALSE
	else
		quarry = quarry_ref?.resolve()
		if(QDELETED(quarry) || world.time > quarry_seen_at + BOUNTY_GORILLA_QUARRY_MEMORY)
			return FALSE
	var/turf/goal = get_turf(quarry)
	if(!goal || goal.z != owner.z || get_dist(owner, goal) > BOUNTY_GORILLA_CHASE_RANGE || !may_punch(quarry, quarry))
		return FALSE
	var/obj/machinery/door/airlock/door = find_door(goal, in_sight)
	if(!door)
		return FALSE
	var/turf/here = get_turf(owner)
	var/turf/door_turf = get_turf(door)
	if(get_dist(here, door_turf) == 1 && (get_dir(here, door_turf) in GLOB.cardinals))
		return start_pry(door)
	return step_to_door(door)

/**
 * The closed airlock within BOUNTY_GORILLA_DOOR_REACH of them that stands between them and `goal`,
 * nearest first: on the straight line to `goal` when it is in sight (a glass door), or, when it
 * isn't, nearer to it than they are and within BOUNTY_GORILLA_BEHIND_RANGE of it. Only one they may
 * force (door_may_force()).
 */
/datum/bounty_chrome/gorilla/proc/find_door(turf/goal, in_sight)
	var/turf/here = get_turf(owner)
	var/list/line = in_sight ? get_line(here, goal) : null
	var/to_goal = get_dist(here, goal)
	var/obj/machinery/door/airlock/best
	var/best_score = INFINITY
	for(var/turf/spot as anything in RANGE_TURFS(BOUNTY_GORILLA_DOOR_REACH, here))
		var/obj/machinery/door/airlock/door = locate() in spot
		if(!door || !door.density || door.operating)
			continue
		if(in_sight)
			if(!(spot in line))
				continue
		else if(get_dist(spot, goal) >= to_goal || get_dist(spot, goal) > BOUNTY_GORILLA_BEHIND_RANGE)
			continue
		if(!door_may_force(door))
			continue
		var/score = get_dist(here, spot) * 10 + get_dist(spot, goal)
		if(score < best_score)
			best = door
			best_score = score
	return best

/**
 * Whether they may go at `door`: their side's own ground (never a player's ship, a hangar, an
 * outpost, or anywhere at a trader outpost: bounty_ai_may_hit(); a pirate ship they are wanted aboard
 * is their own ground), one that hasn't held against them lately, and one that lets no air out when
 * it opens.
 */
/datum/bounty_chrome/gorilla/proc/door_may_force(obj/machinery/door/airlock/door)
	if(QDELETED(door) || !door.density)
		return FALSE
	var/until = LAZYACCESS(held_doors, WEAKREF(door))
	if(until && world.time < until)
		return FALSE
	if(!bounty_ai_side_of(owner) || !bounty_ai_may_hit(owner, door))
		return FALSE
	return bounty_gorilla_door_holds_air(door)

/**
 * Whether opening `door` lets no air out: none of its open sides is space, open space or a drop,
 * and the pressures on them are within BOUNTY_GORILLA_PRESSURE_GAP of each other.
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

/// One step to the side of `door` facing them, then the pry in a moment. Returns TRUE if they moved.
/datum/bounty_chrome/gorilla/proc/step_to_door(obj/machinery/door/airlock/door)
	var/turf/here = get_turf(owner)
	var/turf/door_turf = get_turf(door)
	var/mob/living/basic/bounty_criminal/side = bounty_ai_side_of(owner)
	var/turf/best
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(door_turf, direction)
		if(!beside || get_dist(here, beside) != 1 || beside.is_blocked_turf(source_atom = owner) || !beside.can_cross_safely(owner))
			continue
		if(side && !side.leash_ok(beside))
			continue
		best = beside
		break
	if(!best || !owner.Move(best, get_dir(here, best)))
		return FALSE
	owner.face_atom(door)
	if(!door_check_timer)
		door_check_timer = addtimer(CALLBACK(src, PROC_REF(check_doors)), 0.5 SECONDS, TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

/**
 * Fingers in the seam and pulling, rooted: a short heave on an unpowered door, a slow loud pry on a
 * powered one, and a try that comes to nothing on one bolted, welded or sealed. Returns TRUE if it
 * started.
 */
/datum/bounty_chrome/gorilla/proc/start_pry(obj/machinery/door/airlock/door)
	var/held = door.locked || door.welded || door.seal
	var/time = held ? BOUNTY_GORILLA_PRY_HELD : (door.hasPower() ? BOUNTY_GORILLA_PRY_POWERED : BOUNTY_GORILLA_PRY_UNPOWERED)
	if(!begin(BOUNTY_GORILLA_PRY, time))
		return FALSE
	door_ref = WEAKREF(door)
	owner.face_atom(door)
	owner.visible_message(
		span_warning("[owner] digs [owner.p_their()] fingers into the seam of [door] and pulls!"),
		blind_message = span_hear("You hear metal screeching."),
	)
	playsound(door, 'sound/machines/airlock/airlock_alien_prying.ogg', held ? 60 : 100, TRUE)
	door.Shake(1, 0, time)
	busy_timer = addtimer(CALLBACK(src, PROC_REF(finish_pry), serial), time, TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

/**
 * The pry under `for_serial` is over: the door comes open, unless it is bolted, welded or sealed,
 * when it holds and is left alone for a while. Nothing if they were stunned, downed or EMP'd
 * meanwhile, or the door was opened, moved or made unsafe to open. Returns TRUE if it opened.
 */
/datum/bounty_chrome/gorilla/proc/finish_pry(for_serial)
	if(for_serial != serial || busy != BOUNTY_GORILLA_PRY)
		return FALSE
	busy_timer = null
	var/obj/machinery/door/airlock/door = door_ref?.resolve()
	door_ref = null
	var/still_busy = boss_still_busy()
	end_busy()
	if(!still_busy || !able() || QDELETED(door) || !door.density || get_dist(owner, door) > 1)
		return FALSE
	if(door.locked || door.welded || door.seal)
		owner.visible_message(span_warning("[owner] heaves at [door], but it holds."))
		playsound(door, 'sound/effects/clang.ogg', 50, TRUE)
		LAZYSET(held_doors, WEAKREF(door), world.time + BOUNTY_GORILLA_HELD_MEMORY)
		return FALSE
	if(!door_may_force(door))
		return FALSE
	var/powered = door.hasPower()
	owner.visible_message(span_danger("[owner] forces [door] open!"))
	playsound(door, 'sound/machines/airlock/airlockforced.ogg', 60, TRUE)
	INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door, open), powered ? BYPASS_DOOR_CHECKS : FORCING_DOOR_CHECKS)
	if(powered)
		door.take_damage(AIRLOCK_PRY_DAMAGE, BRUTE, sound_effect = FALSE)
	return TRUE

#undef BOUNTY_GORILLA_WINDUP
#undef BOUNTY_GORILLA_PUNCH_COOLDOWN
#undef BOUNTY_GORILLA_OPENING_DELAY
#undef BOUNTY_GORILLA_PUNCH_DAMAGE
#undef BOUNTY_GORILLA_PUNCH_WOUND_BONUS
#undef BOUNTY_GORILLA_PUNCH_AP
#undef BOUNTY_GORILLA_MECH_DAMAGE
#undef BOUNTY_GORILLA_THROW_TILES
#undef BOUNTY_GORILLA_THROW_SPEED
#undef BOUNTY_GORILLA_STAGGER
#undef BOUNTY_GORILLA_PINNED_KNOCKDOWN
#undef BOUNTY_GORILLA_WHIFF_STUMBLE
#undef BOUNTY_GORILLA_PULLBACK
#undef BOUNTY_GORILLA_BACKFIRE_KNOCKDOWN
#undef BOUNTY_GORILLA_BACKFIRE_STAGGER
#undef BOUNTY_GORILLA_BACKFIRE_VULNERABLE
#undef BOUNTY_GORILLA_PRY_POWERED
#undef BOUNTY_GORILLA_PRY_UNPOWERED
#undef BOUNTY_GORILLA_PRY_HELD
#undef BOUNTY_GORILLA_HELD_MEMORY
#undef BOUNTY_GORILLA_QUARRY_MEMORY
#undef BOUNTY_GORILLA_DOOR_REACH
#undef BOUNTY_GORILLA_CHASE_RANGE
#undef BOUNTY_GORILLA_BEHIND_RANGE
#undef BOUNTY_GORILLA_PRESSURE_GAP
#undef BOUNTY_GORILLA_TRAIT
#undef BOUNTY_GORILLA_BOSS_BUSY
#undef BOUNTY_GORILLA_PUNCH
#undef BOUNTY_GORILLA_PRY
#undef BOUNTY_GORILLA_STUMBLE
#undef BOUNTY_GORILLA_GLOW
#undef BOUNTY_GORILLA_COLOR
#undef BOUNTY_GORILLA_FIST_SOUND
#undef BOUNTY_GORILLA_FIST_INTERVAL
#undef BOUNTY_GORILLA_REACH_TIME
#undef BOUNTY_GORILLA_GRAB_COOLDOWN
#undef BOUNTY_GORILLA_GRAB_OPENING
#undef BOUNTY_GORILLA_SPECIAL_GAP
#undef BOUNTY_GORILLA_PUMMEL_PUNCHES
#undef BOUNTY_GORILLA_PUMMEL_GAP
#undef BOUNTY_GORILLA_FACE_DAMAGE
#undef BOUNTY_GORILLA_PUMMEL_BUDGET
#undef BOUNTY_GORILLA_HOLD_MAX
#undef BOUNTY_GORILLA_HOLD_BREAK_DAMAGE
#undef BOUNTY_GORILLA_GRAB_GUARD
#undef BOUNTY_GORILLA_REACH_LEAN
#undef BOUNTY_GORILLA_MARK_COLOR
#undef BOUNTY_GORILLA_REACH
#undef BOUNTY_GORILLA_HOLD
