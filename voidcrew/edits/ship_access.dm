/**
 * Ship interiors carry no internal access control.
 *
 * A hull is run by a handful of people who between them hold one department's ID
 * each, so stock /tg/ department locks mostly amount to the medic being unable to
 * reach a toolbox and nobody aboard being able to touch the air alarms. Inside a
 * crewed hull every lock opens for anyone standing in it, whatever their ID says.
 *
 * Ships still under AI control are the exception. A pirate frigate's armory is
 * loot, and it stays shut until the crew takes the hull with a ship key - claiming
 * an NPC ship clears its ai_controller, which is what opens its locks.
 *
 * Everything outside a ship - outposts, ruins, planets, the colosseum - sits in
 * /area/voidcrew or an upstream area root and is untouched by this.
 */
/atom/movable/proc/in_unrestricted_ship()
	var/area/shuttle/voidcrew/ship_area = get_area(src)
	if(!istype(ship_area))
		return FALSE
	var/obj/structure/overmap/ship/ship = ship_area.shuttle_port?.current_ship
	return !isnull(ship) && isnull(ship.ai_controller)

/**
 * check_access_list() is the single choke point every lock funnels through:
 * allowed() calls it via check_access(), and the machines that read an ID
 * directly - the bank machine, APC control, comms console, ore redemption - call
 * check_access() themselves. Overriding here catches both paths.
 *
 * The req_access length test comes first so the common case (a ship door mapped
 * with no access at all) stays a pair of list reads. This runs on every airlock
 * bump and inside bot pathfinding, so the area lookup has to stay off that path.
 */
/obj/check_access_list(list/access_list)
	if((length(req_access) || length(req_one_access)) && in_unrestricted_ship())
		return TRUE
	return ..()

/mob/check_access_list(list/access_list)
	if((length(req_access) || length(req_one_access)) && in_unrestricted_ship())
		return TRUE
	return ..()

/**
 * NPCs never benefit from the crewed-ship access waiver.
 *
 * The waiver above exists so a five-person crew is not locked out of its own
 * toolbox; it was never meant to hold the door for anything that is not crew.
 * Without this check a boarding party bumping any access-locked door on a crewed
 * hull sails straight through it - check_access_list() has no idea who is asking,
 * so the waiver answered yes for everyone, and playtest crews watched boarders
 * "walk thru" doors they had deliberately locked. Their AI already knows how to
 * bash a door that refuses them (mob_patrol.dm pre-marks access-locked doors for
 * attack), so denying here restores break-in behavior instead of a free stroll.
 *
 * This started as a pirate-only rule, and pirates were never the only NPC that
 * walked through the waiver. Slimes did too: an access-locked windoor is the ONLY
 * thing holding a slime in a xenobiology pen (windowdoor.dm Bumped() opens for any
 * mob that is not hands-blocked, and allowed() said yes to all of them), so the
 * Phalanx pens leaked slimes into the lab every round. Any clientless critter that
 * wanders a hull - a carp that got in through a breach, an escaped monkey - has the
 * same free run. The rule is therefore "not crew", not "pirate".
 *
 * Still scoped tightly: only clientless mobs, only doors that actually carry an
 * access requirement, and only where the waiver itself would have applied. Bots
 * and silicons are left on the upstream path so their own credentials still get
 * read (a bot carries an access_card, a borg has TRAIT_SILICON_ACCESS), and doors
 * mapped with no access at all still open for anyone, exactly as they would
 * upstream for any ID-less mob.
 */
/obj/machinery/door/allowed(mob/M)
	if(isliving(M) && !GET_CLIENT(M) && (length(req_access) || length(req_one_access)) \
		&& !isbot(M) && !HAS_SILICON_ACCESS(M) && in_unrestricted_ship())
		return FALSE
	return ..()

/**
 * Crew-only airlocks.
 *
 * A captain can key their hull's airlocks to the crew roster from Ship Management.
 * Only player-created hulls qualify - the roundstart fleet stays public, the same rule
 * the join password follows. While the lock is on, every airlock and windoor inside
 * that ship refuses any player who is not crew: not on the ship team, and not cleared
 * past its join password. Boarders and tourists get the normal deny animation and a
 * line of chat; the crew never notice it is there.
 *
 * Only those two door types are gated. A firedoor is safety equipment and stays
 * openable by anyone, which is the whole point of a firedoor.
 *
 * Nothing else about a door changes. An unpowered one is still crowbarred open, an
 * emagged one is still emagged and a disabled ID scanner still disables the reader.
 * Bolts are still bolts. Hanging the refusal on the two subtypes rather
 * than on the /obj/machinery/door override above is deliberate: it runs ahead of
 * `emergency` and `unres_sides`, neither of which should punch a hole in a lock the
 * captain deliberately set.
 */
GLOBAL_LIST_EMPTY(crew_locked_ships)

/**
 * Whether this door has to refuse `user` because its ship is crew-locked. Also prints
 * the refusal, at most once every few seconds per player: walking into a door repeats
 * this call several times a second.
 *
 * The empty-global test comes first and is the entire reason that global exists. In a
 * round where nobody has turned the lock on this is one list read on a path that runs
 * for every airlock bump and inside bot pathfinding, and the area lookup below never
 * happens at all.
 */
/obj/machinery/door/proc/refused_by_ship_crew_lock(mob/user)
	if(!length(GLOB.crew_locked_ships))
		return FALSE
	// Players only. Clientless mobs are covered by the NPC rule above, and bots and
	// silicons stay on the upstream path so their own credentials are still read.
	if(!user || !GET_CLIENT(user))
		return FALSE
	if(isbot(user) || HAS_SILICON_ACCESS(user))
		return FALSE
	var/area/shuttle/voidcrew/ship_area = get_area(src)
	if(!istype(ship_area))
		return FALSE
	var/obj/structure/overmap/ship/ship = ship_area.shuttle_port?.current_ship
	if(isnull(ship) || !ship.crew_only_airlocks)
		return FALSE
	if(ship.is_ship_crew(user))
		return FALSE
	if(TIMER_COOLDOWN_FINISHED(user, "ship_crew_lock_refusal"))
		TIMER_COOLDOWN_START(user, "ship_crew_lock_refusal", 5 SECONDS)
		to_chat(user, span_warning("This airlock is keyed to the [ship.name]'s crew."))
	return TRUE

/obj/machinery/door/airlock/allowed(mob/user)
	if(refused_by_ship_crew_lock(user))
		return FALSE
	return ..()

// Exterior airlocks skip allowed() when docked or facing safe air. Their safety
// override may bypass department access, but must still respect the crew lock.
/obj/machinery/door/airlock/try_to_activate_door(mob/living/user, access_bypass = FALSE)
	if(access_bypass && requiresID() && refused_by_ship_crew_lock(user))
		access_bypass = FALSE
	return ..()

/obj/machinery/door/window/allowed(mob/user)
	if(refused_by_ship_crew_lock(user))
		return FALSE
	return ..()

/**
 * Lockers never check access at all, anywhere.
 *
 * /tg/ maps department access onto most of its secure furniture, which on a hull
 * with five people aboard mostly means the toolbox and the spare hardsuit sit
 * behind a lock nobody present can open. Unlike the rule above this is not scoped
 * to ships: a locker in a ruin or aboard an NPC frigate is guarded by whatever is
 * standing next to it, not by an ID card that nobody in this codebase is issued.
 *
 * req_access is deliberately left populated. Deconstructing a secure closet still
 * pops out electronics carrying its original access list, and a player who wires
 * that into something else gets a working lock.
 *
 * A closet a player has ID-locked with a multitool is unaffected, because that
 * path compares the stored card reference instead of an access list. Personal
 * lockers are the exception: their can_unlock() treats allowed() as an override on
 * top of the registered card, so with access gone they open for the whole crew.
 */
/obj/structure/closet/check_access_list(list/access_list)
	return TRUE

/**
 * Ore silos hand out materials without checking for an ID.
 *
 * Upstream ships silos with ID_required set, which makes every lathe print and every
 * sheet withdrawal check that the user is wearing an ID card carrying a registered
 * bank account. That gate assumes a station: an HoP who can reissue a broken card, and
 * a Quartermaster who can switch the requirement off from the silo's own interface.
 *
 * A hull has neither. Most themes spawn no quartermaster at all, and ACCESS_QM is the
 * only key that opens the toggle, so on those ships the requirement is permanent and
 * the silo simply refuses everyone - a miner who left their ID in their bunk gets
 * "ID interface failure" from the protolathe and no way to clear it. Defaulting it off
 * matches how the rest of a ship interior behaves.
 *
 * The logs are unaffected and still record the name and account behind every action, so
 * a ship that does field a quartermaster can turn the requirement back on and ban
 * individual accounts from the same interface.
 */
/obj/machinery/ore_silo
	ID_required = FALSE
