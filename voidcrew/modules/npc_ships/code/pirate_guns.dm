/**
 * Pirate crew guns: how a human pirate handles the real gun in its hands.
 *
 * PR #500 rolled a drawn gun for each basic-mob gunner and fired its rounds from the body. Human
 * pirates (faction_pirate_humans.dm) hold the real thing, chosen by their faction's outfit table
 * (voidcrew/modules/human_npcs/human_npc_outfits_pirates.dm, weighted as PR #500's crew_gun_weights),
 * with real spare magazines or shells, and fire it through the real fire path. What is left of PR #500's
 * loadouts is how each kind of gun is used: how many pulls of the trigger make a volley and how long the
 * pirate waits between volleys (tuned, as before, to about the old two-laser volley every six seconds),
 * the SMG's spin-up and the shotgun's moment of aim that a hit spoils, the shotgunner walking in close,
 * and what it shouts when it reloads. The pump, the magazine change and their sounds are the gun's own.
 */

/// One of each handling, most specific gun type first
GLOBAL_LIST_INIT(pirate_gun_handlings, init_pirate_gun_handlings())

/proc/init_pirate_gun_handlings()
	. = list()
	// Most specific first: pistols are automatic guns too, and every gun type is a /obj/item/gun.
	for(var/handling_type in list(
		/datum/pirate_gun_handling/plasma/rifle, // plasma_weapons module (plasma_pirates.dm)
		/datum/pirate_gun_handling/plasma,
		/datum/pirate_gun_handling/shotgun,
		/datum/pirate_gun_handling/pistol,
		/datum/pirate_gun_handling/smg,
		/datum/pirate_gun_handling/ballistic,
		/datum/pirate_gun_handling/crossbow,
		/datum/pirate_gun_handling/energy,
		/datum/pirate_gun_handling,
	))
		. += new handling_type

/// How a pirate uses `gun`: the first handling whose gun type it is.
/proc/pirate_gun_handling_for(obj/item/gun/gun)
	for(var/datum/pirate_gun_handling/handling as anything in GLOB.pirate_gun_handlings)
		if(istype(gun, handling.gun_type))
			return handling
	return GLOB.pirate_gun_handlings[length(GLOB.pirate_gun_handlings)]

/**
 * How a pirate fires one kind of gun. Read-only and shared; the timers live on the pirate's AI
 * blackboard (BB_PIRATE_VOLLEY_LEFT, BB_PIRATE_WINDUP_UNTIL, BB_HUMAN_NPC_NEXT_SHOT).
 */
/datum/pirate_gun_handling
	/// The guns it covers
	var/gun_type = /obj/item/gun
	/// Pulls of the trigger in one volley, and the time between them
	var/shots = 1
	var/shot_gap = 0.3 SECONDS
	/// From the last pull of a volley to the first of the next
	var/volley_gap = 3 SECONDS
	/// The spin-up or aim before a volley, if any: a hit during it spoils the volley
	var/windup = 0
	var/windup_sound
	/// Tiles: it walks in to this before it fires (0: the usual gunner range)
	var/close_range = 0
	/// What it may shout as it changes magazines or loads shells
	var/list/reload_lines = list("Reloading!", "Changing mags!", "Cover me, I'm reloading!")
	/// What it may shout when the gun runs dry and can't be reloaded
	var/list/dry_lines

/// Energy guns: two beams every six seconds. A cell can't be changed by hand, so a dry one is put away.
/datum/pirate_gun_handling/energy
	gun_type = /obj/item/gun/energy
	shots = 2
	shot_gap = 0.2 SECONDS
	volley_gap = 6 SECONDS
	reload_lines = null
	dry_lines = list("Cell's dry!", "Cover me!")

/// The medieval crossbow: one bolt every six seconds. It draws itself again.
/datum/pirate_gun_handling/crossbow
	gun_type = /obj/item/gun/energy/recharge
	shots = 1
	volley_gap = 6 SECONDS
	reload_lines = null

/// Any other bullet gun: one shot every three seconds.
/datum/pirate_gun_handling/ballistic
	gun_type = /obj/item/gun/ballistic

/// Pistols: a quick pair every seven seconds.
/datum/pirate_gun_handling/pistol
	gun_type = /obj/item/gun/ballistic/automatic/pistol
	shots = 2
	shot_gap = 0.3 SECONDS
	volley_gap = 7 SECONDS

/// SMGs: spins up, then three bursts, every seven seconds.
/datum/pirate_gun_handling/smg
	gun_type = /obj/item/gun/ballistic/automatic
	shots = 3
	shot_gap = 0.3 SECONDS
	volley_gap = 7 SECONDS
	windup = 0.4 SECONDS
	windup_sound = 'sound/items/weapons/gun/smg/smgrack.ogg'

/// Pump shotguns: walks in close, aims a moment and fires a shell every four seconds. The pump after
/// each shot is the gun's own (the AI racks it as a player does).
/datum/pirate_gun_handling/shotgun
	gun_type = /obj/item/gun/ballistic/shotgun
	shots = 1
	volley_gap = 4 SECONDS
	windup = 0.4 SECONDS
	close_range = 3
	reload_lines = list("Reloading!", "Loading shells!", "Cover me!")
