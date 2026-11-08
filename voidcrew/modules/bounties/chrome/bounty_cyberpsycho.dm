/**
 * # Bounty hunting: the cyberpsycho
 *
 * A mini-boss kit (BOUNTY_KIT_CYBERPSYCHO) whose kit is its chrome, all seven pieces at once. Its
 * record rolls "all of it" (bounty_roll_chrome()), and every piece shows and reads on it as on anyone
 * else: the real implants in its look, each piece's examine line, each piece's chrome read.
 *
 * Where it sits: everything but the fight is any mini-boss's. The record rolls it as a kit, the
 * rarest (bounty_roll_kit()); its posting, pay, shares, suit in the void, capture and prison riot
 * move (the Juggernaut's charge) are the standard ones. Nothing drops.
 *
 * How its pieces work together. Each piece here is a psycho subtype of the real one: the same
 * telegraphs, effects, counterplay and clean-up, but a piece never starts a move on its own. The
 * psycho's moves are boss abilities (/datum/action/cooldown/mob_cooldown/bounty_boss/psycho subtypes), chosen
 * by the boss AI like any kit's: one at a time, never the same twice running while another is ready,
 * with the boss's gap between them. A move holds the boss's busy state (boss_set_busy()) for as long
 * as it runs, so nothing else starts meanwhile and a stun or a downing cuts it off.
 * - Gorilla Arms (its left arm, bare while the blade is out in its right): the piston punch, and the
 *   grab and pummel, on someone right beside it. It pries doors open on its own, under the same
 *   busy rule.
 * - Mantis Blades (its right arm): the blade is its weapon while it fights; the lunge, two to five
 *   tiles down a marked line.
 * - Meteor Piledriver: the leap, three to seven tiles, under the landing shadow.
 * - Deadeye optics: before a lunge or a leap its eyes go red and the hunter it is going for glints.
 * - Cascade lattice: the surge. Its spin-up holds the next move back; in the window it is fast and
 *   dodges and keeps making moves; in the crash it starts nothing at all. That is the hunters' turn.
 * - Redline core: phase two. It trips once, where the boss tires: whatever it was doing stops, a
 *   surge under way crashes (the hunters get their crash), it stands and roars, burns, then
 *   collapses into stamina crit: the capture.
 * - Lazarus: the one time it gets up again, after it is downed. Once a spawn, however long the fight.
 * An EMP throws it into a malfunction for BOUNTY_PSYCHO_MALFUNCTION: every piece down at once, so it
 * starts no move, sparking and twitching all the while (bounty_chrome_malfunction_fx()), then it
 * recovers. For BOUNTY_PSYCHO_EMP_GRACE after that its chrome shrugs further pulses off, so EMPs are
 * timed, not spammed.
 */

// ===== ITS BODY =====

/// Health for 1, 2, 3 and 4+ engaged hunters (review r1, balance.md 6.7's table for zone scaling kept). The Redline burn, the Cascade dodge and the Lazarus jolt all add to it.
#define BOUNTY_PSYCHO_HEALTH_1 800
#define BOUNTY_PSYCHO_HEALTH_2 1300
#define BOUNTY_PSYCHO_HEALTH_3 1900
#define BOUNTY_PSYCHO_HEALTH_4 2600
/// Its pace (on the scale of BOUNTY_JUGGERNAUT_SPEED): a little slower than a running hunter; the Cascade window runs them down
#define BOUNTY_PSYCHO_SPEED 0.35
/// Between blows; the blade's own numbers are its blows (Mantis Blades)
#define BOUNTY_PSYCHO_MELEE_COOLDOWN (0.9 SECONDS)

// ===== ITS MOVES =====

/// A lunge holds its moves this long at most (wind-up, dash and the longest recovery); it lets go as soon as it is back on balance
#define BOUNTY_PSYCHO_LUNGE_HOLD (4 SECONDS)
/// The Cascade lattice's spin-up (its BOUNTY_CASCADE_SPINUP_TIME): no move starts while it whines
#define BOUNTY_PSYCHO_SURGE_SPINUP (1.5 SECONDS)
/// How long its Deadeye optics mark the hunter a lunge or a leap is going for: about its wind-up
#define BOUNTY_PSYCHO_MARK_LUNGE (1 SECONDS)
#define BOUNTY_PSYCHO_MARK_LEAP (1.6 SECONDS)
/// What boss_busy says while it lunges, and while its Redline core winds up
#define BOUNTY_PSYCHO_BUSY_LUNGE "lunge"
#define BOUNTY_PSYCHO_BUSY_REDLINE "redline"
/// Its pieces' states, as numbers: their defines stay in their own files
#define BOUNTY_PSYCHO_CASCADE_IDLE 0
#define BOUNTY_PSYCHO_CASCADE_SPINUP 1
#define BOUNTY_PSYCHO_CASCADE_WINDOW 2
#define BOUNTY_PSYCHO_CASCADE_CRASH 3
#define BOUNTY_PSYCHO_REDLINE_IDLE 0
#define BOUNTY_PSYCHO_PILEDRIVER_IDLE 0

// ===== EMP =====

/// An EMP's malfunction: every piece down this long (its emp_reboot), sparking and twitching
#define BOUNTY_PSYCHO_MALFUNCTION (5 SECONDS)
/// After the malfunction, further pulses slide off this long
#define BOUNTY_PSYCHO_EMP_GRACE (8 SECONDS)
/// The line about a pulse sliding off shows at most this often
#define BOUNTY_PSYCHO_STATIC_MESSAGE (2 SECONDS)

// ===== ITS RECORD =====

/**
 * Its chrome, key -> the psycho's own subtype of that piece, in the order they go in. The order sets
 * its look (bounty_chrome_organ_looks()): the Redline core's grille, not the lattice, shows in the
 * slot they share, and the blade housing takes the right arm before the Gorilla plating gets the left.
 */
/proc/bounty_psycho_chrome_types()
	var/static/list/types = list(
		BOUNTY_CHROME_REDLINE = /datum/bounty_chrome/redline/psycho,
		BOUNTY_CHROME_CASCADE = /datum/bounty_chrome/cascade/psycho,
		BOUNTY_CHROME_MANTIS = /datum/bounty_chrome/mantis/psycho,
		BOUNTY_CHROME_GORILLA = /datum/bounty_chrome/gorilla/psycho,
		BOUNTY_CHROME_PILEDRIVER = /datum/bounty_chrome/piledriver/psycho,
		BOUNTY_CHROME_LAZARUS = /datum/bounty_chrome/lazarus/psycho,
		BOUNTY_CHROME_DEADEYE = /datum/bounty_chrome/deadeye/psycho,
	)
	return types

/// Its chrome's keys, in order, as its record lists them
/proc/bounty_psycho_chrome_keys()
	var/list/keys = list()
	for(var/key in bounty_psycho_chrome_types())
		keys += key
	return keys

/**
 * Makes `record` a cyberpsycho's: the kit and every piece of chrome. Idempotent: the body calls it as it
 * spawns, so an admin's spawn (which picks the kit only) carries all of it too.
 */
/proc/bounty_psycho_make_record(datum/bounty_record/record)
	if(!record)
		return
	record.archetype = BOUNTY_ARCHETYPE_BOSS
	record.kit = BOUNTY_KIT_CYBERPSYCHO
	record.style = null
	record.chrome = bounty_psycho_chrome_keys()

// ===== THE BOSS =====

/mob/living/basic/bounty_criminal/boss/cyberpsycho
	name = "cyberpsycho"
	desc = "A twitching criminal with more chrome than skin."
	maxHealth = BOUNTY_PSYCHO_HEALTH_1
	health = BOUNTY_PSYCHO_HEALTH_1
	speed = BOUNTY_PSYCHO_SPEED
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 1, STAMINA = BOUNTY_BOSS_STAMINA_FRESH * 100 / BOUNTY_BOSS_STAMINA, OXY = 1)
	melee_attack_cooldown = BOUNTY_PSYCHO_MELEE_COOLDOWN
	boss_kit = BOUNTY_KIT_CYBERPSYCHO
	boss_ability_types = list(
		/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/surge,
		/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/lunge,
		/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/leap,
		/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/punch,
		/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/grab,
	)
	/// world.time until which its chrome shrugs off EMPs, after one took it down
	var/psycho_emp_shield_until = 0
	/// The line about a pulse sliding off shows at most every BOUNTY_PSYCHO_STATIC_MESSAGE
	COOLDOWN_DECLARE(psycho_static_message)

/mob/living/basic/bounty_criminal/boss/cyberpsycho/Initialize(mapload)
	. = ..()
	psycho_install_chrome()
	// After its chrome's own EMP hook, so each piece takes the pulse first
	RegisterSignal(src, COMSIG_ATOM_PRE_EMP_ACT, PROC_REF(psycho_pre_emp))
	RegisterSignal(src, COMSIG_ATOM_EMP_ACT, PROC_REF(psycho_on_emp))

// It is its chrome: whatever its record was given, it carries all of it, and the record says so
/mob/living/basic/bounty_criminal/boss/cyberpsycho/body_setup(datum/bounty_record/new_record, datum/criminal_bounty/new_posting)
	bounty_psycho_make_record(new_record)
	return ..()

/mob/living/basic/bounty_criminal/boss/cyberpsycho/boss_health_table()
	return list(BOUNTY_PSYCHO_HEALTH_1, BOUNTY_PSYCHO_HEALTH_2, BOUNTY_PSYCHO_HEALTH_3, BOUNTY_PSYCHO_HEALTH_4)

/mob/living/basic/bounty_criminal/boss/cyberpsycho/boss_kit_outfit()
	return /datum/outfit/bounty_boss/cyberpsycho

/// Shorts and nothing else, so every piece shows: arms, chest, back and legs
/datum/outfit/bounty_boss/cyberpsycho
	name = "Bounty mini-boss: Cyberpsycho"
	uniform = /obj/item/clothing/under/shorts/black
	gloves = null
	shoes = null

/// Puts in its chrome: the psycho's own subtype of each piece, before its record's chrome would go in (body_setup() then adds nothing)
/mob/living/basic/bounty_criminal/boss/cyberpsycho/proc/psycho_install_chrome()
	var/datum/component/bounty_chrome/chrome = GetComponent(/datum/component/bounty_chrome) || AddComponent(/datum/component/bounty_chrome, list())
	if(!chrome)
		return
	var/list/types = bounty_psycho_chrome_types()
	for(var/key in types)
		if(chrome.pieces[key])
			continue
		var/piece_type = types[key]
		var/datum/bounty_chrome/piece = new piece_type
		piece.key = key
		// An EMP is a short malfunction on it, not a long reboot
		piece.emp_reboot = BOUNTY_PSYCHO_MALFUNCTION
		chrome.pieces[key] = piece
		piece.attach(src)

/// One of its pieces, by key
/mob/living/basic/bounty_criminal/boss/cyberpsycho/proc/psycho_piece(key)
	return bounty_chrome_piece(src, key)

/// Its cooldowns stretch once it tires, as a kit's own do: `ready_at` pushed back by boss_cooldown_mult()
/mob/living/basic/bounty_criminal/boss/cyberpsycho/proc/psycho_stretch(ready_at)
	var/mult = boss_cooldown_mult()
	if(mult == 1 || ready_at <= world.time)
		return ready_at
	return world.time + (ready_at - world.time) * mult

// It tires where its Redline core trips: the roar says so, not a "worn out" a stun can't use yet
/mob/living/basic/bounty_criminal/boss/cyberpsycho/boss_update_tired(silent = FALSE, force = FALSE)
	var/datum/bounty_chrome/redline/psycho/redline = psycho_piece(BOUNTY_CHROME_REDLINE)
	if(istype(redline) && redline.online() && (!redline.psycho_spent || redline.state != BOUNTY_PSYCHO_REDLINE_IDLE))
		silent = TRUE
	return ..(silent, force)

// Crashed, it is leaden: it starts nothing at all until the crash wears off
/mob/living/basic/bounty_criminal/boss/cyberpsycho/boss_can_use_ability()
	if(!..())
		return FALSE
	var/datum/bounty_chrome/cascade/cascade = psycho_piece(BOUNTY_CHROME_CASCADE)
	return cascade?.phase != BOUNTY_PSYCHO_CASCADE_CRASH

// Stunned, downed, cuffed or killed: every move under way stops where it is
/mob/living/basic/bounty_criminal/boss/cyberpsycho/boss_on_interrupted()
	psycho_stop_moves()

/// Stops every move under way, with no harm done: a lunge, a punch or a grab (whoever it holds is let go), a leap, and the mark on whoever they were for
/mob/living/basic/bounty_criminal/boss/cyberpsycho/proc/psycho_stop_moves()
	var/datum/bounty_chrome/mantis/mantis = psycho_piece(BOUNTY_CHROME_MANTIS)
	mantis?.cancel_lunge()
	var/datum/bounty_chrome/gorilla/gorilla = psycho_piece(BOUNTY_CHROME_GORILLA)
	if(gorilla?.busy)
		gorilla.stop()
	var/datum/bounty_chrome/piledriver/piledriver = psycho_piece(BOUNTY_CHROME_PILEDRIVER)
	piledriver?.end_leap()
	var/datum/bounty_chrome/deadeye/deadeye = psycho_piece(BOUNTY_CHROME_DEADEYE)
	deadeye?.end_lock()

/**
 * Its Redline core trips: the red takes over. Whatever it was doing stops, and a surge winding up or
 * running crashes, as an EMP crashes it: the burn starts leaden, and the hunters get the crash they
 * earned. A crash under way runs on. Called by the core as it trips; must not sleep.
 */
/mob/living/basic/bounty_criminal/boss/cyberpsycho/proc/psycho_before_redline()
	if(boss_busy)
		boss_clear_busy()
	psycho_stop_moves()
	var/datum/bounty_chrome/cascade/cascade = psycho_piece(BOUNTY_CHROME_CASCADE)
	if(cascade && (cascade.phase == BOUNTY_PSYCHO_CASCADE_SPINUP || cascade.phase == BOUNTY_PSYCHO_CASCADE_WINDOW))
		cascade.start_crash()

/// For a while after an EMP took its chrome down, further pulses slide off
/mob/living/basic/bounty_criminal/boss/cyberpsycho/proc/psycho_pre_emp(datum/source, severity)
	SIGNAL_HANDLER
	if(stat == DEAD || world.time >= psycho_emp_shield_until)
		return NONE
	if(COOLDOWN_FINISHED(src, psycho_static_message))
		COOLDOWN_START(src, psycho_static_message, BOUNTY_PSYCHO_STATIC_MESSAGE)
		visible_message(span_warning("Static crawls over [src]'s chrome and dies away."))
	return EMP_PROTECT_SELF

/// An EMP threw it into a malfunction (every piece has reacted already): it comes back on the dot, and the grace runs from then
/mob/living/basic/bounty_criminal/boss/cyberpsycho/proc/psycho_on_emp(datum/source, severity, protection)
	SIGNAL_HANDLER
	if(stat == DEAD || (protection & EMP_PROTECT_SELF))
		return
	psycho_emp_shield_until = world.time + BOUNTY_PSYCHO_MALFUNCTION + BOUNTY_PSYCHO_EMP_GRACE
	addtimer(CALLBACK(src, PROC_REF(psycho_recover)), BOUNTY_PSYCHO_MALFUNCTION, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)

/// The malfunction is over: its chrome comes back now, not at its next breath
/mob/living/basic/bounty_criminal/boss/cyberpsycho/proc/psycho_recover()
	var/datum/component/bounty_chrome/chrome = GetComponent(/datum/component/bounty_chrome)
	if(!chrome || stat == DEAD)
		return
	for(var/key in chrome.pieces)
		var/datum/bounty_chrome/piece = chrome.pieces[key]
		piece.check_reboot()

// ===== ITS MOVES =====

/**
 * One of the cyberpsycho's moves: a piece of its chrome doing what it does, started by the boss AI
 * like any kit's ability (boss_choose_ability()). The piece has its own wind-up and telegraph, so
 * this has none; the piece holds the boss's busy state while it runs.
 */
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho
	name = "Chrome"
	desc = "Run one piece of your chrome."
	cooldown_time = 0
	windup = 0
	/// BOUNTY_CHROME_* key of the piece it runs
	var/piece_key

/// The cyberpsycho it belongs to, or null
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/proc/psycho()
	return istype(owner, /mob/living/basic/bounty_criminal/boss/cyberpsycho) ? owner : null

/// Its piece, or null
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/proc/piece()
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = psycho()
	return psycho?.psycho_piece(piece_key)

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/worth_using(atom/target)
	var/datum/bounty_chrome/piece = piece()
	return aimable(target) && piece?.online() && piece_ready(piece, target)

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/Activate(atom/target)
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = psycho()
	var/datum/bounty_chrome/piece = piece()
	if(!psycho || !piece?.online() || !aimable(target) || !psycho.boss_can_use_ability())
		return FALSE
	if(!piece_start(psycho, piece, target))
		return FALSE
	psycho.boss_last_ability = type
	psycho.boss_bark("ability")
	return TRUE

/// Whether `piece` can make this move at `target` now
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/proc/piece_ready(datum/bounty_chrome/piece, atom/target)
	return FALSE

/// Starts the move. TRUE if it started.
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/proc/piece_start(mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho, datum/bounty_chrome/piece, atom/target)
	return FALSE

/// The Cascade surge: the whine holds the next move back; the window and the crash run on their own
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/surge
	name = "Cascade Surge"
	desc = "Run your lattice past its limit."
	piece_key = BOUNTY_CHROME_CASCADE

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/surge/piece_ready(datum/bounty_chrome/cascade/cascade, atom/target)
	if(cascade.phase != BOUNTY_PSYCHO_CASCADE_IDLE || world.time < cascade.next_surge_at || !cascade.ready_to_surge())
		return FALSE
	// One burst at a time: never over the Redline core's burn or its collapse
	var/datum/bounty_chrome/redline/redline = piece_redline()
	return !redline || (redline.state == BOUNTY_PSYCHO_REDLINE_IDLE && !redline.crash_timer)

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/surge/proc/piece_redline()
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = psycho()
	return psycho?.psycho_piece(BOUNTY_CHROME_REDLINE)

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/surge/piece_start(mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho, datum/bounty_chrome/cascade/cascade, atom/target)
	cascade.spin_up()
	cascade.next_surge_at = psycho.psycho_stretch(cascade.next_surge_at)
	psycho.boss_next_ability_at = max(psycho.boss_next_ability_at, world.time + BOUNTY_PSYCHO_SURGE_SPINUP + rand(BOUNTY_BOSS_ABILITY_GAP_MIN, BOUNTY_BOSS_ABILITY_GAP_MAX))
	return TRUE

/// The Mantis lunge, down a marked line, its Deadeye optics on whoever it is for
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/lunge
	name = "Mantis Lunge"
	desc = "Dash down a line, blade first."
	piece_key = BOUNTY_CHROME_MANTIS

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/lunge/piece_ready(datum/bounty_chrome/mantis/mantis, atom/target)
	return mantis.deployed && mantis.can_lunge(target)

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/lunge/piece_start(mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho, datum/bounty_chrome/mantis/psycho/mantis, atom/target)
	if(!istype(mantis))
		return FALSE
	mantis.psycho_called = TRUE
	var/started = mantis.start_lunge(target)
	mantis.psycho_called = FALSE
	if(!started)
		return FALSE
	mantis.next_lunge_at = psycho.psycho_stretch(mantis.next_lunge_at)
	var/datum/bounty_chrome/deadeye/psycho/deadeye = psycho.psycho_piece(BOUNTY_CHROME_DEADEYE)
	if(istype(deadeye))
		deadeye.psycho_mark(target, BOUNTY_PSYCHO_MARK_LUNGE)
	return TRUE

/// The Piledriver leap, onto whoever its Deadeye optics marked
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/leap
	name = "Piledriver Leap"
	desc = "Leap onto someone and bring the floor up around them."
	piece_key = BOUNTY_CHROME_PILEDRIVER

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/leap/piece_ready(datum/bounty_chrome/piledriver/piledriver, atom/movable/target)
	return piledriver.phase == BOUNTY_PSYCHO_PILEDRIVER_IDLE && world.time >= piledriver.next_leap_at && !isnull(piledriver.landing_for(target))

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/leap/piece_start(mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho, datum/bounty_chrome/piledriver/psycho/piledriver, atom/movable/target)
	if(!istype(piledriver))
		return FALSE
	piledriver.psycho_called = TRUE
	var/started = piledriver.try_leap(target)
	piledriver.psycho_called = FALSE
	if(!started)
		return FALSE
	var/datum/bounty_chrome/deadeye/psycho/deadeye = psycho.psycho_piece(BOUNTY_CHROME_DEADEYE)
	if(istype(deadeye))
		deadeye.psycho_mark(target, BOUNTY_PSYCHO_MARK_LEAP)
	return TRUE

/// The Gorilla piston punch, on someone right beside it
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/punch
	name = "Piston Punch"
	desc = "Draw back a piston-driven fist."
	piece_key = BOUNTY_CHROME_GORILLA

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/punch/piece_ready(datum/bounty_chrome/gorilla/gorilla, atom/target)
	if(gorilla.busy || world.time < gorilla.punch_ready_at || !isturf(target.loc))
		return FALSE
	return get_dist(owner, target) == 1 && owner.Adjacent(target) && gorilla.may_punch(target, target)

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/punch/piece_start(mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho, datum/bounty_chrome/gorilla/psycho/gorilla, atom/target)
	if(!istype(gorilla))
		return FALSE
	gorilla.psycho_called = TRUE
	var/started = gorilla.start_punch(target)
	gorilla.psycho_called = FALSE
	if(!started)
		return FALSE
	gorilla.punch_ready_at = psycho.psycho_stretch(gorilla.punch_ready_at)
	return TRUE

/// The Gorilla grab and pummel, on someone right beside it
/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/grab
	name = "Gorilla Grab"
	desc = "Grab someone by the collar and pummel them."
	piece_key = BOUNTY_CHROME_GORILLA

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/grab/piece_ready(datum/bounty_chrome/gorilla/gorilla, mob/living/target)
	if(gorilla.busy || world.time < gorilla.grab_ready_at || !isliving(target))
		return FALSE
	return get_dist(owner, target) == 1 && owner.Adjacent(target) && gorilla.may_grab(target)

/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/grab/piece_start(mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho, datum/bounty_chrome/gorilla/psycho/gorilla, mob/living/target)
	if(!istype(gorilla) || !isliving(target))
		return FALSE
	gorilla.psycho_called = TRUE
	var/started = gorilla.start_grab(target)
	gorilla.psycho_called = FALSE
	if(!started)
		return FALSE
	gorilla.grab_ready_at = psycho.psycho_stretch(gorilla.grab_ready_at)
	return TRUE

// ===== ITS PIECES =====
// Each is the real piece with its own trigger taken away: only the psycho's moves start one. Their
// key is null, so they are never a prototype; psycho_install_chrome() sets it on each one.

/// The Cascade lattice: surges only when the psycho calls one. Out of the fight it fizzles or crashes as ever.
/datum/bounty_chrome/cascade/psycho
	key = null

/datum/bounty_chrome/cascade/psycho/on_tick(seconds_per_tick, fighting)
	if(fighting && in_fight())
		return
	return ..()

/// Mantis Blades in its right arm only (the left is a Gorilla arm), out while it fights; it lunges only when the psycho calls a lunge
/datum/bounty_chrome/mantis/psycho
	key = null
	/// The psycho's lunge is starting this one: nothing else may
	var/psycho_called = FALSE
	/// The psycho's busy serial for the lunge under way
	var/psycho_serial = 0

// Unlike any other mini-boss, its blade is how it fights: out while it is hostile and on its feet
/datum/bounty_chrome/mantis/psycho/in_fight()
	var/mob/living/basic/bounty_criminal/boss/psycho = owner
	if(!istype(psycho) || QDELETED(psycho) || psycho.stat != CONSCIOUS)
		return FALSE
	return psycho.boss_hostile && !psycho.boss_is_downed() && !psycho.boss_is_restrained() && !HAS_TRAIT(psycho, TRAIT_BOUNTY_SURRENDERED)

/datum/bounty_chrome/mantis/psycho/show_left_blade()
	return

/datum/bounty_chrome/mantis/psycho/examine_line()
	if(deployed)
		return "A hardlight blade juts from %THEIR right forearm."
	return "A chrome housing sheathes %THEIR right forearm."

// One blade, in the right arm
/datum/bounty_chrome/mantis/psycho/blades_out_line()
	return "A blade of hard light slides out of [owner]'s right forearm!"

/datum/bounty_chrome/mantis/psycho/blades_in_line()
	return "[owner]'s blade slides back into [owner.p_their()] right forearm."

/datum/bounty_chrome/mantis/psycho/flicker_line()
	return "[owner]'s blade flickers out."

/datum/bounty_chrome/mantis/psycho/crouch_line()
	return "[owner] drops low, blade laid flat along [owner.p_their()] arm!"

/datum/bounty_chrome/mantis/psycho/rake_line(obj/vehicle/sealed/mecha/mech)
	return "[owner] rakes [owner.p_their()] blade across [mech]!"

/datum/bounty_chrome/mantis/psycho/skid_line()
	return "[owner] skids to a stop, blade scraping the floor."

// The lunge is one of its moves: nothing else starts until it is back on balance
/datum/bounty_chrome/mantis/psycho/start_lunge(atom/target)
	var/mob/living/basic/bounty_criminal/boss/psycho = owner
	if(!psycho_called || !istype(psycho) || !psycho.boss_can_use_ability())
		return FALSE
	. = ..()
	if(!.)
		return
	psycho_serial = psycho.boss_set_busy(BOUNTY_PSYCHO_BUSY_LUNGE, BOUNTY_PSYCHO_LUNGE_HOLD, immobile = FALSE)
	psycho.boss_next_ability_at = max(psycho.boss_next_ability_at, world.time + BOUNTY_PSYCHO_LUNGE_HOLD)

/datum/bounty_chrome/mantis/psycho/end_recovery(serial)
	var/was = lunge_state
	. = ..()
	if(was && !lunge_state)
		psycho_release()

/datum/bounty_chrome/mantis/psycho/cancel_lunge()
	. = ..()
	psycho_release()

/// The lunge is over: the psycho is free for its next move, after the usual gap
/datum/bounty_chrome/mantis/psycho/proc/psycho_release()
	var/serial = psycho_serial
	psycho_serial = 0
	var/mob/living/basic/bounty_criminal/boss/psycho = owner
	if(!serial || !istype(psycho) || psycho.boss_busy != BOUNTY_PSYCHO_BUSY_LUNGE || psycho.boss_busy_serial != serial)
		return
	psycho.boss_clear_busy(serial)
	psycho.boss_next_ability_at = world.time + rand(BOUNTY_BOSS_ABILITY_GAP_MIN, BOUNTY_BOSS_ABILITY_GAP_MAX)

/// Gorilla Arms in its left arm only: punches and grabs only when the psycho calls one. It still forces doors on its own, under the boss's busy rule.
/datum/bounty_chrome/gorilla/psycho
	key = null
	examine_text = "Dull chrome plates %THEIR left arm from knuckle to shoulder."
	/// The psycho's punch is starting this one: nothing else may
	var/psycho_called = FALSE

/datum/bounty_chrome/gorilla/psycho/start_punch(atom/target)
	if(!psycho_called)
		return FALSE
	return ..()

/datum/bounty_chrome/gorilla/psycho/start_grab(mob/living/target)
	if(!psycho_called)
		return FALSE
	return ..()

// The blade is out in its right hand; the Gorilla arm is the left, and that hand is always empty
/datum/bounty_chrome/gorilla/psycho/bare_handed()
	return TRUE

/// The Redline core: trips once a spawn, where it tires, and takes over from whatever was running
/datum/bounty_chrome/redline/psycho
	key = null
	/// It has tripped: the core is burnt out for good
	var/psycho_spent = FALSE

/datum/bounty_chrome/redline/psycho/can_trip()
	return !psycho_spent && ..()

/datum/bounty_chrome/redline/psycho/start_tell()
	psycho_spent = TRUE
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = owner
	if(istype(psycho))
		psycho.psycho_before_redline()
	..()
	if(!istype(psycho) || psycho.stat != CONSCIOUS)
		return
	// It stands and roars: the tell is a move of its own. A rage line (cyberpsycho_redline), not a burnt-out one.
	psycho.boss_bark("redline")
	var/tell = timeleft(burn_timer) || 0
	psycho.boss_set_busy(BOUNTY_PSYCHO_BUSY_REDLINE, tell)
	psycho.boss_next_ability_at = max(psycho.boss_next_ability_at, world.time + tell + rand(BOUNTY_BOSS_ABILITY_GAP_MIN, BOUNTY_BOSS_ABILITY_GAP_MAX))

// The collapse: now it is burnt out, and sounds it
/datum/bounty_chrome/redline/psycho/crash()
	..()
	var/mob/living/basic/bounty_criminal/boss/psycho = owner
	if(istype(psycho))
		psycho.boss_bark("burnout", "exhausted")

/// The Lazarus node: stands it up once a spawn, not once a recharge (review r1 F7)
/datum/bounty_chrome/lazarus/psycho
	key = null
	/// It has jolted, or charged trying to: spent for good
	var/psycho_spent = FALSE

/datum/bounty_chrome/lazarus/psycho/on_downed()
	if(psycho_spent)
		return
	return ..()

/datum/bounty_chrome/lazarus/psycho/start_charge()
	psycho_spent = TRUE
	return ..()

// Spent, it ticks for good: it never hums again
/datum/bounty_chrome/lazarus/psycho/examine_line()
	if(psycho_spent && !charging && owner && owner.stat != DEAD && !offline_until)
		return "Something under %THEIR ribs ticks."
	return ..()

/// The Meteor Piledriver: leaps only when the psycho calls a leap
/datum/bounty_chrome/piledriver/psycho
	key = null
	/// The psycho's leap is starting this one: nothing else may
	var/psycho_called = FALSE

/datum/bounty_chrome/piledriver/psycho/try_leap(atom/movable/target)
	if(!psycho_called)
		return FALSE
	return ..()

/// Deadeye optics with no gun to steer: they mark the hunter its lunge or leap is going for
/datum/bounty_chrome/deadeye/psycho
	key = null

/datum/bounty_chrome/deadeye/psycho/try_lock()
	return FALSE

/**
 * Marks `target` for `duration`: the ordinary lock (red eyes, the red line, the outline, the reticle,
 * the chirp and the glint on them) for as long as the move's wind-up. No line to the room: the move's
 * own wind-up says what is coming. No gun to steer, so no round homes on it. TRUE if it marked them.
 */
/datum/bounty_chrome/deadeye/psycho/proc/psycho_mark(atom/target, duration)
	if(!lockable(target))
		return FALSE
	start_lock(target, duration, quiet = TRUE)
	shots_left = 0
	armed_at = world.time
	lock_ends_at = world.time + duration
	return TRUE

#undef BOUNTY_PSYCHO_HEALTH_1
#undef BOUNTY_PSYCHO_HEALTH_2
#undef BOUNTY_PSYCHO_HEALTH_3
#undef BOUNTY_PSYCHO_HEALTH_4
#undef BOUNTY_PSYCHO_SPEED
#undef BOUNTY_PSYCHO_MELEE_COOLDOWN
#undef BOUNTY_PSYCHO_LUNGE_HOLD
#undef BOUNTY_PSYCHO_SURGE_SPINUP
#undef BOUNTY_PSYCHO_MARK_LUNGE
#undef BOUNTY_PSYCHO_MARK_LEAP
#undef BOUNTY_PSYCHO_BUSY_LUNGE
#undef BOUNTY_PSYCHO_BUSY_REDLINE
#undef BOUNTY_PSYCHO_CASCADE_IDLE
#undef BOUNTY_PSYCHO_CASCADE_SPINUP
#undef BOUNTY_PSYCHO_CASCADE_WINDOW
#undef BOUNTY_PSYCHO_CASCADE_CRASH
#undef BOUNTY_PSYCHO_REDLINE_IDLE
#undef BOUNTY_PSYCHO_PILEDRIVER_IDLE
#undef BOUNTY_PSYCHO_MALFUNCTION
#undef BOUNTY_PSYCHO_EMP_GRACE
#undef BOUNTY_PSYCHO_STATIC_MESSAGE
