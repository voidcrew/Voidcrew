/**
 * Pirate crew guns.
 *
 * A ranged pirate rolls a gun when it joins a crew (pirate_crew_arm()), weighted by its faction: an
 * energy gun, a laser rifle, a pistol, an SMG or a shotgun. The gun shows in its hand and fires the
 * real gun's rounds: a ballistic gun's are read off the item by bounty_real_weapon() (bounties
 * module), with its magazine, pellets, spread and damage multiplier; an energy gun fires its
 * casing's beam. Nothing is spawned for the fight and nothing drops.
 *
 * Each loadout has a magazine and a reload, and the SMG and shotgun wind up before they fire (a
 * hit during the wind-up spoils it). The shotgun walks in close before it fires. Every loadout
 * deals about what the old two-laser volley every 6 seconds did, so a crew hits as hard as before.
 */

/// One of each loadout, by type
GLOBAL_LIST_INIT(pirate_gun_loadouts, init_pirate_gun_loadouts())

/proc/init_pirate_gun_loadouts()
	. = list()
	for(var/loadout_type in subtypesof(/datum/pirate_gun_loadout))
		.[loadout_type] = new loadout_type

/// What a gunner rolls when its faction says nothing: an even mix of energy and ballistic
GLOBAL_LIST_INIT(pirate_gun_default_weights, list(
	/datum/pirate_gun_loadout/energy_gun = 2,
	/datum/pirate_gun_loadout/laser_rifle = 1,
	/datum/pirate_gun_loadout/pistol = 2,
	/datum/pirate_gun_loadout/smg = 2,
	/datum/pirate_gun_loadout/shotgun = 2,
))

/**
 * A pirate gun: the item in the hand, its rounds, and how it is fired. Read-only, shared by every
 * pirate carrying it; the ammunition and timers live on the pirate's /datum/component/pirate_gun.
 */
/datum/pirate_gun_loadout
	/// The gun in the hand
	var/gun_type
	/// For a ballistic gun, what it is loaded with (null: the magazine's own rounds)
	var/ammo_type
	/// For an energy gun, the casing it fires (its beam and its sound)
	var/obj/item/ammo_casing/energy/energy_casing
	/// For an energy gun, shots in a cell
	var/energy_shots = 0
	/// Shots in one burst, and the time between them
	var/burst = 1
	var/burst_delay = 0.2 SECONDS
	/// From the start of one burst (or wind-up) to the next
	var/cooldown = 6 SECONDS
	var/reload_time = 2.5 SECONDS
	/// The spin-up or pump before a burst, if any; a hit during it spoils the burst
	var/windup = 0
	var/windup_sound
	var/fire_sound
	var/reload_sound = 'sound/items/weapons/gun/general/magazine_insert_full.ogg'
	/// Tiles: it walks in to this before it fires (0: the usual gunner range)
	var/close_range = 0
	/// What its carrier may shout on reloading
	var/list/reload_lines = list("Reloading!", "Changing mags!", "Cover me, I'm reloading!")
	/// The real gun's numbers, for a ballistic gun (/datum/bounty_real_weapon)
	var/datum/bounty_real_weapon/weapon

/datum/pirate_gun_loadout/New()
	. = ..()
	if(ispath(gun_type, /obj/item/gun/ballistic))
		weapon = bounty_real_weapon(gun_type, ammo_type)
		if(!fire_sound)
			fire_sound = weapon.fire_sound
	else if(energy_casing && !fire_sound)
		fire_sound = initial(energy_casing.fire_sound)

/// Rounds in a full magazine, or shots in a full cell
/datum/pirate_gun_loadout/proc/magazine_size()
	if(weapon)
		return max(1, weapon.magazine)
	return max(1, energy_shots)

/// Projectiles one round fires
/datum/pirate_gun_loadout/proc/pellets()
	if(weapon)
		return max(1, weapon.pellets)
	return max(1, initial(energy_casing.pellets))

/// A new projectile of one round (one pellet of a shell) at `start`, carrying the real round's numbers
/datum/pirate_gun_loadout/proc/make_projectile(turf/start)
	if(weapon)
		if(!weapon.round_type)
			return null
		var/obj/projectile/bullet = new weapon.round_type(start)
		weapon.load(bullet)
		return bullet
	var/projectile_type = initial(energy_casing.projectile_type)
	return projectile_type ? new projectile_type(start) : null

/// Degrees one projectile strays
/datum/pirate_gun_loadout/proc/shot_spread()
	if(weapon)
		return weapon.shot_spread()
	var/variance = initial(energy_casing.variance)
	return variance ? round((rand() - 0.5) * variance) : 0

/// Energy gun (lethal): two beams every six seconds, twelve shots to a cell
/datum/pirate_gun_loadout/energy_gun
	gun_type = /obj/item/gun/energy/e_gun/lethal
	energy_casing = /obj/item/ammo_casing/energy/laser
	energy_shots = 12
	burst = 2
	cooldown = 6 SECONDS
	reload_time = 3 SECONDS
	reload_sound = 'sound/items/weapons/gun/general/magazine_insert_empty.ogg'
	reload_lines = list("Swapping cells!", "Cell's dry!", "Cover me!")

/// Laser rifle: as the energy gun, with a bigger cell
/datum/pirate_gun_loadout/laser_rifle
	gun_type = /obj/item/gun/energy/laser
	energy_casing = /obj/item/ammo_casing/energy/lasergun
	energy_shots = 16
	burst = 2
	cooldown = 6 SECONDS
	reload_time = 3 SECONDS
	reload_sound = 'sound/items/weapons/gun/general/magazine_insert_empty.ogg'
	reload_lines = list("Swapping cells!", "Cell's dry!", "Cover me!")

/// Makarov: a quick pair of 9mm every seven seconds, a reload every six pairs
/datum/pirate_gun_loadout/pistol
	gun_type = /obj/item/gun/ballistic/automatic/pistol
	burst = 2
	burst_delay = 0.3 SECONDS
	cooldown = 7 SECONDS
	reload_time = 2 SECONDS
	reload_sound = 'sound/items/weapons/gun/pistol/mag_insert.ogg'

/// Uzi: a five-round string after a short wind-up, every seven seconds
/datum/pirate_gun_loadout/smg
	gun_type = /obj/item/gun/ballistic/automatic/mini_uzi
	burst = 5
	burst_delay = 0.1 SECONDS
	cooldown = 7 SECONDS
	reload_time = 2.5 SECONDS
	windup = 0.4 SECONDS
	windup_sound = 'sound/items/weapons/gun/smg/smgrack.ogg'

/// Pump shotgun with buckshot: walks in close, pumps, and fires a shell every four seconds
/datum/pirate_gun_loadout/shotgun
	gun_type = /obj/item/gun/ballistic/shotgun
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	burst = 1
	cooldown = 4 SECONDS
	reload_time = 3 SECONDS
	windup = 0.4 SECONDS
	windup_sound = 'sound/items/weapons/gun/shotgun/rack.ogg'
	reload_sound = 'sound/items/weapons/gun/shotgun/insert_shell.ogg'
	close_range = 3
	reload_lines = list("Reloading!", "Loading shells!", "Cover me!")

// ===== ARMING =====

/// The loadout weights for `gunner`'s faction: type => weight, or null to keep its own gun
/proc/pirate_gun_weights_for(mob/living/basic/gunner)
	var/mob/living/basic/trooper/pirate/faction/faction_pirate = gunner
	if(istype(faction_pirate))
		if(faction_pirate.crew_keeps_gun)
			return null
		return faction_pirate.crew_gun_weights || GLOB.pirate_gun_default_weights
	if(istype(gunner, /mob/living/basic/trooper/pirate))
		return GLOB.pirate_gun_default_weights
	return null

/**
 * Hands `gunner` a rolled pirate gun in place of its stock ranged attack: the gun shows in its hand
 * and fires real rounds. Only a gunner whose faction has loadouts, and only once. Returns the loadout.
 */
/proc/pirate_crew_arm(mob/living/basic/gunner, loadout_type)
	if(QDELETED(gunner) || gunner.GetComponent(/datum/component/pirate_gun))
		return null
	if(!gunner.GetComponent(/datum/component/ranged_attacks))
		return null
	if(!loadout_type)
		var/list/weights = pirate_gun_weights_for(gunner)
		if(!length(weights))
			return null
		loadout_type = pick_weight(weights)
	var/datum/pirate_gun_loadout/loadout = GLOB.pirate_gun_loadouts[loadout_type]
	if(!loadout)
		return null
	qdel(gunner.GetComponent(/datum/component/ranged_attacks))
	gunner.AddComponent(/datum/component/pirate_gun, loadout)
	var/mob/living/basic/trooper/trooper = gunner
	if(istype(trooper))
		trooper.r_hand = loadout.gun_type
		if(trooper.use_dynamic_appearance)
			apply_dynamic_human_appearance(trooper, mob_spawn_path = trooper.mob_spawner, r_hand = trooper.r_hand, l_hand = trooper.l_hand)
	return loadout

/// The pirate gun `gunner` carries, if any
/proc/pirate_gun_of(mob/living/gunner)
	return gunner?.GetComponent(/datum/component/pirate_gun)

// ===== THE GUN IN HAND =====

/**
 * A pirate's gun in use: its ammunition and timers. The AI's ranged attack (RangedAttack()) asks it
 * to fire; it fires a burst when it's ready, winds up first if it has to, and reloads when empty.
 * Its timers check `serial`, so a spoiled or cancelled burst does nothing.
 */
/datum/component/pirate_gun
	var/datum/pirate_gun_loadout/loadout
	/// Rounds left in the magazine
	var/ammo = 0
	/// world.time it may start the next burst or wind-up
	var/next_fire_at = 0
	/// world.time the reload is done
	var/reloading_until = 0
	/// Winding up now
	var/winding = FALSE
	/// Goes up with every burst, wind-up and fumble, so stale timers do nothing
	var/serial = 0
	/// What it's aimed at
	var/datum/weakref/aim_ref

/datum/component/pirate_gun/Initialize(datum/pirate_gun_loadout/loadout)
	if(!isbasicmob(parent) || !istype(loadout))
		return COMPONENT_INCOMPATIBLE
	src.loadout = loadout
	ammo = loadout.magazine_size()

/datum/component/pirate_gun/Destroy(force)
	serial++
	loadout = null
	aim_ref = null
	return ..()

/datum/component/pirate_gun/RegisterWithParent()
	. = ..()
	ADD_TRAIT(parent, TRAIT_SUBTREE_REQUIRED_OPERATIONAL_DATUM, type)
	RegisterSignal(parent, COMSIG_MOB_ATTACK_RANGED, PROC_REF(on_ranged_attack))
	RegisterSignal(parent, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_damaged))

/datum/component/pirate_gun/UnregisterFromParent()
	. = ..()
	UnregisterSignal(parent, list(COMSIG_MOB_ATTACK_RANGED, COMSIG_MOB_AFTER_APPLY_DAMAGE))
	REMOVE_TRAIT(parent, TRAIT_SUBTREE_REQUIRED_OPERATIONAL_DATUM, type)

/datum/component/pirate_gun/proc/on_ranged_attack(mob/living/basic/source, atom/target, modifiers)
	SIGNAL_HANDLER
	try_fire(target)

/// A hit during the wind-up spoils it: nothing fires, and the next try waits a moment
/datum/component/pirate_gun/proc/on_damaged(mob/living/source, damage_dealt)
	SIGNAL_HANDLER
	if(!winding || damage_dealt <= 0)
		return
	serial++
	winding = FALSE
	next_fire_at = max(next_fire_at, world.time + 1 SECONDS)

/datum/component/pirate_gun/proc/ready()
	return !winding && world.time >= next_fire_at

/datum/component/pirate_gun/proc/is_reloading()
	return world.time < reloading_until

/datum/component/pirate_gun/proc/can_fire(mob/living/owner)
	return owner && owner.stat == CONSCIOUS && isturf(owner.loc) && !HAS_TRAIT(owner, TRAIT_INCAPACITATED) && !HAS_TRAIT(owner, TRAIT_HANDS_BLOCKED)

/// Starts a burst at `target`, after the wind-up if it has one. TRUE if it started.
/datum/component/pirate_gun/proc/try_fire(atom/target)
	var/mob/living/owner = parent
	if(!can_fire(owner) || !ready() || QDELETED(target))
		return FALSE
	if(loadout.close_range && get_dist(owner, target) > loadout.close_range)
		return FALSE
	aim_ref = WEAKREF(target)
	serial++
	owner.face_atom(target)
	if(loadout.windup)
		winding = TRUE
		next_fire_at = world.time + loadout.windup + loadout.cooldown
		if(loadout.windup_sound)
			playsound(owner, loadout.windup_sound, 50, TRUE)
		addtimer(CALLBACK(src, PROC_REF(finish_windup), serial), loadout.windup, TIMER_DELETE_ME)
		return TRUE
	fire_burst()
	return TRUE

/datum/component/pirate_gun/proc/finish_windup(fire_serial)
	if(fire_serial != serial || !winding)
		return
	winding = FALSE
	if(can_fire(parent))
		fire_burst()

/// A burst: as many shots as the magazine has left, then a reload if it's spent
/datum/component/pirate_gun/proc/fire_burst()
	var/shots = clamp(loadout.burst, 1, ammo)
	ammo -= shots
	next_fire_at = max(next_fire_at, world.time + loadout.cooldown)
	var/fire_serial = serial
	shoot_once(fire_serial)
	for(var/i in 2 to shots)
		addtimer(CALLBACK(src, PROC_REF(shoot_once), fire_serial), (i - 1) * loadout.burst_delay, TIMER_DELETE_ME)
	if(ammo <= 0)
		start_reload((shots - 1) * loadout.burst_delay)

/// One round of the burst under `fire_serial`: every pellet of it
/datum/component/pirate_gun/proc/shoot_once(fire_serial)
	if(fire_serial != serial)
		return null
	var/mob/living/owner = parent
	var/atom/target = aim_ref?.resolve()
	if(!can_fire(owner) || QDELETED(target))
		return null
	if(isliving(target))
		var/mob/living/living_target = target
		if(living_target.stat == DEAD)
			return null
	owner.face_atom(target)
	var/turf/start = get_turf(owner)
	if(!start || start == get_turf(target))
		return null
	var/obj/projectile/first
	for(var/pellet in 1 to loadout.pellets())
		var/obj/projectile/shot = loadout.make_projectile(start)
		if(!shot)
			break
		shot.firer = owner
		shot.fired_from = owner
		shot.ignored_factions = owner.faction?.Copy()
		shot.aim_projectile(target, owner, null, loadout.shot_spread())
		if(QDELETED(shot))
			continue
		shot.fire()
		if(!first && !QDELETED(shot))
			first = shot
	if(loadout.fire_sound)
		playsound(owner, loadout.fire_sound, 60, TRUE)
	SEND_SIGNAL(owner, COMSIG_BASICMOB_POST_ATTACK_RANGED, target, null)
	return first

/// A fresh magazine, ready `delay` + the reload time from now
/datum/component/pirate_gun/proc/start_reload(delay = 0)
	ammo = loadout.magazine_size()
	reloading_until = world.time + delay + loadout.reload_time
	next_fire_at = max(next_fire_at, reloading_until)
	addtimer(CALLBACK(src, PROC_REF(reload_effects)), delay, TIMER_DELETE_ME)

/datum/component/pirate_gun/proc/reload_effects()
	var/mob/living/owner = parent
	if(QDELETED(owner) || owner.stat != CONSCIOUS)
		return
	if(loadout.reload_sound)
		playsound(owner, loadout.reload_sound, 40, TRUE)
	if(length(loadout.reload_lines) && prob(PIRATE_CREW_RELOAD_BARK_CHANCE))
		INVOKE_ASYNC(owner, TYPE_PROC_REF(/atom/movable, say), message = pick(loadout.reload_lines), forced = "pirate crew")

/// For the admin status readout
/datum/component/pirate_gun/proc/status_text()
	var/obj/item/gun_path = loadout.gun_type
	return "[initial(gun_path.name)] [ammo]/[loadout.magazine_size()][is_reloading() ? " reloading" : ""][winding ? " winding up" : ""]"
