/**
 * # Megafauna containment
 *
 * Outposts - the trader stations and the crews' own colonies alike - are
 * permanent installations. They can't be flown away, their walls can't be
 * blown open, their NPC staff can't run, and the shop standing in one is the
 * only one of its kind that round. A megafauna that gets inside has nothing
 * left to stop it: MOVE_FORCE_OVERPOWERING means nobody can drag it back out,
 * and MOB_SIZE_HUGE means nobody can box it up either.
 *
 * The realistic way one arrives is a beast that followed a landing party home:
 * aggro it on a planet, let it walk in through the ship's airlock, fly to an
 * outpost, dock, and open the hangar door. It then walks onto the hangar deck
 * on its own feet - an area transition, which is what this guard watches.
 *
 * Anything ismegafauna() that crosses into an area with repels_megafauna set
 * is destroyed a tick later. Deferring keeps the qdel out of the beast's own
 * movement call stack (the colosseum boundary wardens defer for the same
 * reason) and makes the removal a visible event rather than a silent vanish.
 *
 * The teleport routes are refused further upstream and never reach here: the
 * transporter's mass blacklist (GLOB.transporter_mass_blacklist) and the drop
 * pod's blacklisted_mob_types both cover the full ismegafauna() set.
 */

/// Areas that must never host a megafauna. Set on the outpost areas; the
/// enforcement is the Entered() overrides at the bottom of this file.
/area/var/repels_megafauna = FALSE

/**
 * Boundary check for a warded area: schedules the removal of a megafauna that
 * just crossed in. Called from the area's Entered(), so it must not touch the
 * mob itself - see purge_repelled_megafauna() for the actual destruction.
 */
/proc/repel_megafauna(atom/movable/arrived, area/entering)
	if(!entering.repels_megafauna || !ismegafauna(arrived))
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(purge_repelled_megafauna), WEAKREF(arrived)), 1)

/**
 * Destroys a repelled megafauna, one tick after it crossed the line. Re-checks
 * the area first: a beast that walked back out under its own power (or was
 * teleported clear by an admin) is left alone.
 */
/proc/purge_repelled_megafauna(datum/weakref/beast_ref)
	var/mob/living/beast = beast_ref?.resolve()
	if(QDELETED(beast))
		return
	var/area/current = get_area(beast)
	if(!current?.repels_megafauna)
		return
	var/turf/site = get_turf(beast)
	site?.visible_message(span_boldwarning("[beast] is cut to pieces by a sustained burst of automated defensive fire."))
	playsound(site, 'sound/items/weapons/plasma_cutter.ogg', 75, TRUE)
	log_game("MEGAFAUNA CONTAINMENT: [beast] ([beast.type]) was destroyed for entering [current.name] ([current.type]) at [AREACOORD(beast)].")
	message_admins("Megafauna containment: [beast] ([beast.type]) was destroyed for entering [current.name] [ADMIN_JMP(site)].")
	qdel(beast)

/area/voidcrew/trader_outpost/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	repel_megafauna(arrived, src)

/area/voidcrew/outpost_hangar/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	repel_megafauna(arrived, src)

/area/voidcrew/player_outpost/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	repel_megafauna(arrived, src)
