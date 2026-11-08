/// How far off they can lock someone, and how far a homing round keeps steering (the player implant's tag range)
#define BOUNTY_DEADEYE_RANGE 9
/// Rounds that home per lock
#define BOUNTY_DEADEYE_SHOTS 3
/// The beat between the lock and the first homing round: the red line shows and they hold their fire
#define BOUNTY_DEADEYE_ARM (1.2 SECONDS)
/// How long an armed lock lasts if they never fire its rounds
#define BOUNTY_DEADEYE_WINDOW (6 SECONDS)
/// From the end of one lock, however it ended, to the next
#define BOUNTY_DEADEYE_COOLDOWN (15 SECONDS)
/// The soonest they lock after a fight starts
#define BOUNTY_DEADEYE_FIRST_DELAY (2 SECONDS)
/// How often a held lock checks they can still see their mark
#define BOUNTY_DEADEYE_WATCH (0.5 SECONDS)
/// A homing round's turn per tile, as the player implant's
#define BOUNTY_DEADEYE_TURN 30
/// The mark's colour, as the player implant's
#define BOUNTY_DEADEYE_RED "#ff3300"
/// Their red eyes draw just over their own, under glasses, masks, hair and helmets
#define BOUNTY_DEADEYE_EYE_LAYER (EYES_LAYER - 0.1)
/// A colour matrix that fills an eye sprite with the mark's red (#ff3300), whatever colour it was drawn in
#define BOUNTY_DEADEYE_EYE_MATRIX list(0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0.2, 0)

/**
 * # Bounty chrome: Deadeye optics
 *
 * The Deadeye link a player buys (voidcrew/modules/cyberware/ware_pro_combat.dm), behind a gunman's
 * eyes. In a fight, every so often, their eyes turn red and lock onto whoever they are shooting
 * at: a red line from them to the mark for BOUNTY_DEADEYE_ARM, the player implant's red outline
 * on the mark, its reticle and its chirp, and the gun held for that beat. Then the next
 * BOUNTY_DEADEYE_SHOTS rounds they fire at the mark home in on them, each with the player
 * implant's reticle flash. A shotgun shell counts as one round: all its pellets home together.
 *
 * Sight is everything. The lock drops the moment the mark is out of their view (round a corner,
 * behind a closed door, in smoke, out of reach), goes down, or stops being who they are shooting
 * at, and the next lock is BOUNTY_DEADEYE_COOLDOWN off whatever ended it. A homing round steers
 * only while it can see its mark itself, so it never bends round a corner, and only toward someone
 * its shooter may hit at all (bounty_ai_may_hit(), as /obj/projectile/bullet/bounty does). An EMP
 * drops the lock and straightens every round in the air.
 *
 * Guns only: pistol, SMG, revolver and shotgun criminals and companions. Not the meek (their one
 * cornered volley is not a fight) and not the mini-bosses: only the Heavy fires rounds, and its
 * burst is built to be stepped out of. No worn look: the implant shows nothing on a player's body,
 * and its plain robotic eyes would draw human eyes on a moth or a jellyperson, so their own eyes
 * stay as their record has them and turn red only while they hold a lock.
 */
/datum/bounty_chrome/deadeye
	key = BOUNTY_CHROME_DEADEYE
	name = "Deadeye optics"
	weight = 12
	min_tier = BOUNTY_TIER_PETTY
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL, BOUNTY_CHROME_COMPANION)
	styles = list(BOUNTY_STYLE_PISTOL, BOUNTY_STYLE_SMG, BOUNTY_STYLE_REVOLVER, BOUNTY_STYLE_SHOTGUN)
	/// Weakref to who they have locked onto, while they hold a lock
	var/datum/weakref/mark_ref
	/// Rounds of this lock still to home
	var/shots_left = 0
	/// world.time rounds start homing, after the beat
	var/armed_at = 0
	/// world.time this lock runs out
	var/lock_ends_at = 0
	/// world.time they may lock again
	var/next_lock_at = 0
	/// The held lock's sight check
	var/watch_timer
	/// Weakref to the red line shown during the beat
	var/datum/weakref/beam_ref
	/// Their mark's filter name, one per piece, so two pieces on one person never clear each other's
	var/mark_filter
	/// world.time of the last round counted, and weakref to who it was at: a shell's other pellets, fired the same moment, go with it
	var/last_round_at = -1
	var/datum/weakref/last_round_mark
	/// Weakrefs to their homing rounds in the air
	var/list/rounds

/datum/bounty_chrome/deadeye/attach(mob/living/basic/fighter)
	..()
	mark_filter = "bounty_deadeye_[REF(src)]"
	RegisterSignal(fighter, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(on_update_overlays))

/datum/bounty_chrome/deadeye/detach()
	end_lock()
	stop_rounds()
	if(owner)
		UnregisterSignal(owner, COMSIG_ATOM_UPDATE_OVERLAYS)
	return ..()

/datum/bounty_chrome/deadeye/Destroy(force)
	// Normally detach() has done this; a piece deleted without it must not leave its mark on anyone
	end_lock()
	stop_rounds()
	return ..()

/datum/bounty_chrome/deadeye/examine_line()
	if(!owner)
		return null
	return "[owner.p_Their()] eyes are milspec optics, cold and unblinking."

/datum/bounty_chrome/deadeye/on_fight_start(atom/target)
	next_lock_at = max(next_lock_at, world.time + BOUNTY_DEADEYE_FIRST_DELAY)

/datum/bounty_chrome/deadeye/on_tick(seconds_per_tick, fighting)
	if(mark_ref)
		if(!fighting)
			end_lock()
		return
	if(fighting && world.time >= next_lock_at)
		try_lock()

/datum/bounty_chrome/deadeye/on_fire(obj/projectile/shot, atom/original)
	if(!istype(shot, /obj/projectile/bullet/bounty) || QDELETED(original))
		return
	// The rest of a shell's pellets, fired the same moment as the one counted, home with it
	if(world.time == last_round_at && original == last_round_mark?.resolve() && bounty_ai_real_weapon(owner)?.pellets > 1)
		home(shot, original)
		return
	var/atom/target = mark_ref?.resolve()
	if(!target || original != target || world.time < armed_at)
		return
	if(!lockable(target))
		end_lock(lost = TRUE)
		return
	if(!home(shot, target))
		return
	last_round_at = world.time
	last_round_mark = mark_ref
	new /obj/effect/temp_visual/smartgun_target(get_turf(target))
	shots_left--
	if(shots_left <= 0)
		end_lock()

/datum/bounty_chrome/deadeye/on_downed()
	end_lock()
	stop_rounds()

/datum/bounty_chrome/deadeye/on_death()
	end_lock()
	stop_rounds()

/datum/bounty_chrome/deadeye/on_emp(severity)
	end_lock()
	stop_rounds()

/// Locks onto whoever they are shooting at, if their gun fires rounds and they can see them. TRUE if it locked.
/datum/bounty_chrome/deadeye/proc/try_lock()
	var/datum/bounty_style/style = bounty_ai_style(owner)
	if(!style?.ranged || !ispath(style.projectile_type, /obj/projectile/bullet/bounty))
		return FALSE
	var/atom/target = bounty_chrome_target(owner)
	if(!lockable(target))
		return FALSE
	start_lock(target)
	return TRUE

/// Whether they can hold a lock on `target`: a person or a mech they may shoot, in plain view and in reach. Never while someone plays them: the lock is the NPC's.
/datum/bounty_chrome/deadeye/proc/lockable(atom/target)
	if(QDELETED(target) || !(isliving(target) || ismecha(target)) || !online() || owner.client)
		return FALSE
	return bounty_ai_may_hit(owner, target) && bounty_ai_can_see(owner, target, BOUNTY_DEADEYE_RANGE)

/// The lock on `target`: eyes red, the red line and the mark, and their gun held for the beat
/datum/bounty_chrome/deadeye/proc/start_lock(atom/target)
	if(mark_ref)
		end_lock()
	mark_ref = WEAKREF(target)
	shots_left = BOUNTY_DEADEYE_SHOTS
	armed_at = world.time + BOUNTY_DEADEYE_ARM
	lock_ends_at = armed_at + BOUNTY_DEADEYE_WINDOW
	rounds = null
	target.add_filter(mark_filter, 2, list("type" = "outline", "color" = BOUNTY_DEADEYE_RED, "size" = 1))
	new /obj/effect/temp_visual/smartgun_target(get_turf(target))
	beam_ref = WEAKREF(owner.Beam(target, icon_state = "r_beam", time = BOUNTY_DEADEYE_ARM, maxdistance = BOUNTY_DEADEYE_RANGE + 1))
	owner.face_atom(target)
	owner.visible_message(span_warning("[owner]'s eyes flash red."))
	playsound(owner, 'sound/machines/synth/synth_yes.ogg', 40, TRUE)
	for(var/mob/living/person as anything in marked_people(target))
		to_chat(person, span_userdanger("A red targeting glint settles on you!"))
	var/datum/component/ranged_attacks/gun = owner.GetComponent(/datum/component/ranged_attacks)
	if(gun)
		gun.fire_cooldown = max(gun.fire_cooldown, armed_at)
	owner.update_appearance(UPDATE_OVERLAYS)
	watch_timer = addtimer(CALLBACK(src, PROC_REF(watch_lock)), BOUNTY_DEADEYE_WATCH, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/// The people a mark on `target` is on: them, or whoever sits in the mech
/datum/bounty_chrome/deadeye/proc/marked_people(atom/target)
	if(isliving(target))
		return list(target)
	. = list()
	if(ismecha(target))
		var/obj/vehicle/sealed/mecha/mech = target
		for(var/mob/living/pilot in mech.occupants)
			. += pilot

/// The held lock's check: it ends when it runs out, the fight ends or moves on, or the mark is down, and drops with a chirp when they lose sight of the mark
/datum/bounty_chrome/deadeye/proc/watch_lock()
	var/atom/target = mark_ref?.resolve()
	if(!target || !online() || owner.client || !bounty_chrome_fighting(owner) || world.time >= lock_ends_at || bounty_chrome_target(owner) != target || !bounty_ai_may_hit(owner, target))
		end_lock()
		return
	if(!lockable(target))
		end_lock(lost = TRUE)

/// Ends the lock, if they hold one: the mark, the line and the red eyes go, and the next lock is a cooldown off. `lost` chirps: their mark got away.
/datum/bounty_chrome/deadeye/proc/end_lock(lost = FALSE)
	if(!mark_ref)
		return
	var/atom/target = mark_ref.resolve()
	target?.remove_filter(mark_filter)
	mark_ref = null
	shots_left = 0
	var/datum/beam/line = beam_ref?.resolve()
	beam_ref = null
	if(!QDELETED(line))
		qdel(line)
	if(watch_timer)
		deltimer(watch_timer)
		watch_timer = null
	next_lock_at = world.time + BOUNTY_DEADEYE_COOLDOWN
	if(QDELETED(owner))
		return
	owner.update_appearance(UPDATE_OVERLAYS)
	if(lost && owner.stat == CONSCIOUS)
		playsound(owner, 'sound/machines/synth/synth_no.ogg', 30, TRUE)

/**
 * Sets `shot` homing on `target`, as the player implant does, and has it check every tile that it
 * can still see them. Only toward someone they may hit. TRUE if it homes.
 */
/datum/bounty_chrome/deadeye/proc/home(obj/projectile/shot, atom/target)
	if(QDELETED(shot) || QDELETED(target) || !bounty_ai_may_hit(owner, target))
		return FALSE
	shot.set_homing_target(target)
	if(shot.homing_target != target)
		return FALSE
	shot.homing_turn_speed = max(shot.homing_turn_speed, BOUNTY_DEADEYE_TURN)
	RegisterSignal(shot, COMSIG_PROJECTILE_MOVE_PROCESS_STEP, PROC_REF(on_round_step), override = TRUE)
	LAZYADD(rounds, WEAKREF(shot))
	return TRUE

/// Each tile a homing round flies: it flies straight from the moment it can't see its mark, they may not hit them, or the optics are down
/datum/bounty_chrome/deadeye/proc/on_round_step(obj/projectile/shot)
	SIGNAL_HANDLER
	var/atom/target = shot.homing_target
	var/turf/target_turf = get_turf(target)
	if(target_turf && online() && !QDELETED(target) && bounty_ai_may_hit(owner, target) && can_see(get_turf(shot), target_turf, BOUNTY_DEADEYE_RANGE))
		return
	stop_round(shot)

/// `shot` flies straight from here on
/datum/bounty_chrome/deadeye/proc/stop_round(obj/projectile/shot)
	shot.homing_target = null
	UnregisterSignal(shot, COMSIG_PROJECTILE_MOVE_PROCESS_STEP)
	LAZYREMOVE(rounds, shot.weak_reference)

/// Every homing round of theirs in the air flies straight from here on
/datum/bounty_chrome/deadeye/proc/stop_rounds()
	for(var/datum/weakref/round_ref as anything in rounds)
		var/obj/projectile/shot = round_ref.resolve()
		if(shot)
			shot.homing_target = null
			UnregisterSignal(shot, COMSIG_PROJECTILE_MOVE_PROCESS_STEP)
	rounds = null

/// Red eyes while they hold a lock, drawn in the eyes of their own species, under anything worn over them
/datum/bounty_chrome/deadeye/proc/on_update_overlays(atom/source, list/new_overlays)
	SIGNAL_HANDLER
	if(!mark_ref || !online())
		return
	var/mob/living/basic/bounty_criminal/criminal = owner
	if(istype(criminal) && (criminal.hidden || criminal.blended))
		return
	var/state = eye_state()
	if(!state)
		return
	for(var/side in list("l", "r"))
		var/mutable_appearance/eye = mutable_appearance('icons/mob/human/human_face.dmi', "[state]_[side]", -BOUNTY_DEADEYE_EYE_LAYER)
		// Filled, not tinted: a moth's eyes are drawn dark, and a red tint of dark stays dark
		eye.color = BOUNTY_DEADEYE_EYE_MATRIX
		new_overlays += eye

/// The eye sprite of their species (human_face.dmi, without its _l/_r), or null for none
/datum/bounty_chrome/deadeye/proc/eye_state()
	var/datum/bounty_look/look
	if(istype(owner, /mob/living/basic/bounty_criminal))
		var/mob/living/basic/bounty_criminal/criminal = owner
		look = criminal.record?.look
	else if(istype(owner, /mob/living/basic/bounty_companion))
		var/mob/living/basic/bounty_companion/companion = owner
		look = companion.eva_look
	var/datum/species/species_type = ispath(look?.species, /datum/species) ? look.species : /datum/species/human
	var/obj/item/organ/eyes/eyes_type = initial(species_type.mutanteyes)
	return ispath(eyes_type, /obj/item/organ/eyes) ? initial(eyes_type.eye_icon_state) : null

#undef BOUNTY_DEADEYE_RANGE
#undef BOUNTY_DEADEYE_SHOTS
#undef BOUNTY_DEADEYE_ARM
#undef BOUNTY_DEADEYE_WINDOW
#undef BOUNTY_DEADEYE_COOLDOWN
#undef BOUNTY_DEADEYE_FIRST_DELAY
#undef BOUNTY_DEADEYE_WATCH
#undef BOUNTY_DEADEYE_TURN
#undef BOUNTY_DEADEYE_RED
#undef BOUNTY_DEADEYE_EYE_LAYER
#undef BOUNTY_DEADEYE_EYE_MATRIX
