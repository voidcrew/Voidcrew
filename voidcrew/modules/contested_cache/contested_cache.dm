/**
 * # Contested cache
 *
 * Galaxy-wide announced PvP loot event. On a schedule (SSovermap addtimer chain,
 * same pattern as the vestige ruins in voidcrew/modules/antag_ruins/antag_ruin.dm),
 * a "bonded courier drop platform" surfaces in yellow/red space. Everyone is told
 * what it is, where it is, and that its vault unseals in CONTESTED_CACHE_UNLOCK_DELAY -
 * the delay IS the PvP window: every crew converges knowing every other crew heard
 * the same broadcast. Possession is winning: once the vault unseals, any living
 * player can run an interruptible on-site channel to crack it, and the prize is a
 * physical crate of class-weighted ship parts (spawn_ship_part_prize(),
 * voidcrew/modules/shuttle/ship_parts/spawners.dm) that still has to be cased,
 * carried home and extracted - and can be robbed on the way.
 *
 * Scheduling deliberately does NOT ride SSdynamic_events: that subsystem is a
 * weight-rolled roster of ship-victim events on a minutes cadence, while this is
 * a fixed-cadence galaxy-scope site with an hour-long lifecycle. The vestige
 * addtimer chain is exactly the right shape and needs no new plumbing.
 *
 * State discipline: ruin interiors are wiped whenever the site unloads (everyone
 * leaves), so ALL event state (unlock time, claimed flag) lives on the overmap
 * signal object, never on the vault machine - the vault re-syncs from the signal
 * each time the interior loads (link_vault()).
 */

// ===== MAP TEMPLATE =====

/datum/map_template/ruin/space/contested_cache
	prefix = "_maps/voidcrew/RandomRuins/SpaceRuins/"
	id = "contested_cache"
	suffix = "contested_cache.dmm"
	name = "Bonded Courier Drop Platform"
	description = "An automated freight-escrow platform. The courier firm that built it went under decades ago, but the vault still runs on schedule and still tells the whole sector when a drop goes live."
	unpickable = TRUE // never naturally seeded; only the event scheduler surfaces it
	allow_duplicates = TRUE

// ===== INTERIOR AREA =====

/area/ruin/space/has_grav/powered/contested_cache
	name = "\improper Bonded Courier Drop Platform"

// ===== OVERMAP SIGNAL =====

/obj/structure/overmap/space_ruin/contested_cache
	name = "bonded courier beacon"
	desc = "A logistics beacon broadcasting a drop notice on every open channel. Every ship in the sector got the same message you did."
	fleet_waypoint_name = "Contested Cache"

	/// world.time at which the vault unseals. 0 until start_event().
	var/unlock_at = 0
	/// Whether the prize has been claimed this event. Lives here, not on the vault - interiors get wiped on unload.
	var/vault_opened = FALSE
	/// Whether the event is over and the site is trying to clean itself up.
	var/event_over = FALSE
	/// Internal wideband transmitter for the beacon's galaxy-wide broadcasts.
	var/obj/item/radio/headset/radio

/obj/structure/overmap/space_ruin/contested_cache/Initialize(mapload, datum/map_template/ruin/space/template)
	. = ..()
	color = "#33e0ff"
	radio = new(src)
	radio.subspace_transmission = TRUE
	radio.canhear_range = 0
	radio.set_listening(FALSE)
	radio.recalculateChannels()

/obj/structure/overmap/space_ruin/contested_cache/Destroy()
	clear_fleet_waypoint()
	QDEL_NULL(radio)
	return ..()

/obj/structure/overmap/space_ruin/contested_cache/categorize_ruin()
	ruin_category = "contested_cache"

/obj/structure/overmap/space_ruin/contested_cache/update_icon_for_category()
	icon_state = "strange_event"

/obj/structure/overmap/space_ruin/contested_cache/examine(mob/user)
	. = ..()
	if(event_over)
		. += span_notice("The escrow contract is settled. The platform is powering down.")
	else if(vault_opened)
		. += span_boldwarning("The cache has been claimed - but whoever claimed it still has to make it home.")
	else if(unlock_at && world.time < unlock_at)
		. += span_boldwarning("The vault unseals in [DisplayTimeText(unlock_at - world.time)]. Expect company.")
	else if(unlock_at)
		. += span_boldwarning("The vault is unsealed. Whoever cracks it first gets the cache.")

/**
 * Kicks the event off: sets the unlock clock, reveals the site, charts a helm
 * waypoint onto the whole fleet, broadcasts galaxy-wide and schedules the
 * unseal announcement plus the no-show hard timeout. Called once by the
 * scheduler right after set_ruin_template().
 */
/obj/structure/overmap/space_ruin/contested_cache/proc/start_event()
	unlock_at = world.time + CONTESTED_CACHE_UNLOCK_DELAY
	on_surveyed() // no mystery: the whole point is that everyone knows exactly what this is

	var/list/coords = get_relative_overmap_coords()
	var/where = coords ? "grid [coords[1]], [coords[2]]" : "an unknown position"
	var/pvp_window_minutes = round(CONTESTED_CACHE_UNLOCK_DELAY / (1 MINUTES))

	broadcast_galaxy(
		"Sector drop notice: bonded courier cache active at [where]. Escrow seals disengage in [pvp_window_minutes] minutes. Contents: ship-grade components, unclaimed. All claims settled on-site.",
		"Contested Cache",
	)

	// Registers as well as pushes, so a ship built during the PvP window is told
	// about the drop the same as everyone else.
	broadcast_fleet_waypoint()

	notify_ghosts("A contested cache has surfaced - its vault unseals in [pvp_window_minutes] minutes!", source = src, header = "Contested Cache")

	addtimer(CALLBACK(src, PROC_REF(announce_unlock)), CONTESTED_CACHE_UNLOCK_DELAY)
	addtimer(CALLBACK(src, PROC_REF(hard_timeout)), CONTESTED_CACHE_UNLOCK_DELAY + CONTESTED_CACHE_HARD_TIMEOUT)
	log_game("Contested cache event started at overmap [where].")

/**
 * Galaxy-wide broadcast: a Wideband transmission from the beacon (in-fiction,
 * reaches every headset) plus a priority announcement (guaranteed delivery to
 * players without radios). See voidcrew/modules/comms/comms.dm - Wideband is
 * unscoped, so the beacon's overmap z-level doesn't matter.
 */
/obj/structure/overmap/space_ruin/contested_cache/proc/broadcast_galaxy(message, title)
	priority_announce(message, title, sender_override = "Sector Courier Network")
	radio?.talk_into(src, message, RADIO_CHANNEL_WIDEBAND)

/// The T-elapsed beat: tell the galaxy the vault is open to claim.
/obj/structure/overmap/space_ruin/contested_cache/proc/announce_unlock()
	if(QDELETED(src) || event_over || vault_opened)
		return
	broadcast_galaxy("Escrow seals disengaged. The bonded cache is open to claim - first to crack the vault keeps the contents.", "Contested Cache")

/// Called by the vault when someone finishes the cracking channel and takes the prize.
/obj/structure/overmap/space_ruin/contested_cache/proc/on_vault_cracked(mob/living/user)
	if(vault_opened)
		return
	vault_opened = TRUE
	broadcast_galaxy("Escrow contract settled: the bonded cache has been claimed. Platform retirement scheduled.", "Contested Cache")
	log_game("Contested cache vault cracked by [user ? key_name(user) : "unknown"].")
	addtimer(CALLBACK(src, PROC_REF(finish_event)), CONTESTED_CACHE_LINGER_TIME)

/// No-show guard: retires the site only if nobody ever cracked the vault.
/// A cracked vault always gets its full CONTESTED_CACHE_LINGER_TIME instead,
/// even when the crack lands close to the timeout.
/obj/structure/overmap/space_ruin/contested_cache/proc/hard_timeout()
	if(QDELETED(src) || vault_opened)
		return
	finish_event()

/// Ends the event and starts trying to retire the site. Safe to call twice
/// (claim linger and hard timeout can both schedule it).
/obj/structure/overmap/space_ruin/contested_cache/proc/finish_event()
	if(QDELETED(src) || event_over)
		return
	event_over = TRUE
	clear_fleet_waypoint()
	try_cleanup()

/**
 * Retires the site: unloads the interior and deletes the signal, but only once
 * nobody is docked or standing on the reservation - otherwise retries later.
 * Never spawns a replacement ruin.
 */
/obj/structure/overmap/space_ruin/contested_cache/proc/try_cleanup()
	if(QDELETED(src))
		return
	if(reservation)
		// Refused because someone is aboard or a dock is in flight - both fix
		// themselves given a little time.
		if(!release_interior())
			addtimer(CALLBACK(src, PROC_REF(try_cleanup)), CONTESTED_CACHE_CLEANUP_RETRY)
			return
	log_game("Contested cache site retired.")
	qdel(src)

// Re-link the vault (and re-sync its claimed/sealed state) every time the
// interior loads - the template reloads fresh if crews leave and come back,
// and a fresh vault must not pay out a second prize.
/obj/structure/overmap/space_ruin/contested_cache/load_level()
	..()
	if(loaded)
		link_vault()

/obj/structure/overmap/space_ruin/contested_cache/proc/link_vault()
	if(!ruin_bottom_left || !ruin_template?.width || !ruin_template?.height)
		return
	var/turf/top_right = locate(
		ruin_bottom_left.x + ruin_template.width - 1,
		ruin_bottom_left.y + ruin_template.height - 1,
		ruin_bottom_left.z
	)
	if(!top_right)
		return
	for(var/turf/interior_turf as anything in block(ruin_bottom_left, top_right))
		var/obj/structure/contested_cache_vault/vault = locate() in interior_turf
		if(!vault)
			continue
		vault.signal_ref = WEAKREF(src)
		if(vault_opened)
			vault.set_breached()
		return

// The site never respawn-cycles into a different ruin: unload the interior when
// everyone leaves, hold overmap position while the event runs, and retire fully
// once the event is over.
/obj/structure/overmap/space_ruin/contested_cache/check_and_respawn()
	if(!release_interior())
		// Same re-arm as the base proc: a refusal is usually the departing hull still
		// mid-move, or the worldgen queue timing out - retry rather than holding the
		// reservation until try_cleanup happens to come around.
		addtimer(CALLBACK(src, PROC_REF(check_and_respawn)), 30 SECONDS, TIMER_UNIQUE)
		return
	if(event_over)
		qdel(src)

// Base proc would relocate the signal to a fresh overmap square; the cache
// holds position (everyone was told where it is) until the event retires it.
/obj/structure/overmap/space_ruin/contested_cache/unload_level()
	release_interior()

// ===== THE VAULT =====

/**
 * The prize gate. Indestructible - the unseal timer and the cracking channel
 * are the only way in, so the PvP window can't be skipped with a welder or a
 * bomb. All authoritative state lives on the overmap signal (see file header).
 */
/obj/structure/contested_cache_vault
	name = "bonded courier vault"
	desc = "An armored escrow vault bolted through the platform's keel. It only opens on schedule, and the plating is there for everyone who didn't want to wait."
	icon = 'voidcrew/modules/contested_cache/icons/cache.dmi'
	icon_state = "cache_vault"
	anchored = TRUE
	density = TRUE
	max_integrity = 500
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	/// Weakref to the /obj/structure/overmap/space_ruin/contested_cache running this event. Set by link_vault().
	var/datum/weakref/signal_ref
	/// Local mirror of the cracked state, for icon/feedback. Truth lives on the signal.
	var/breached = FALSE
	/// Whether someone is currently running the cracking channel.
	var/busy = FALSE

/obj/structure/contested_cache_vault/examine(mob/user)
	. = ..()
	var/obj/structure/overmap/space_ruin/contested_cache/signal = signal_ref?.resolve()
	if(breached || signal?.vault_opened)
		. += span_notice("The vault hangs open and empty.")
	else if(!signal)
		. += span_notice("The seal display is dark. The vault is dormant.")
	else if(world.time < signal.unlock_at)
		. += span_boldwarning("The seal display counts down: [DisplayTimeText(signal.unlock_at - world.time)] until the escrow seals disengage.")
	else
		. += span_boldwarning("The seals are disengaged. Forcing it open by hand would take [CONTESTED_CACHE_OPEN_TIME / 10] seconds.")

/obj/structure/contested_cache_vault/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	try_crack(user)
	return TRUE

/obj/structure/contested_cache_vault/proc/try_crack(mob/living/user)
	var/obj/structure/overmap/space_ruin/contested_cache/signal = signal_ref?.resolve()
	if(breached || signal?.vault_opened)
		balloon_alert(user, "already emptied!")
		return
	if(!signal)
		balloon_alert(user, "vault dormant!")
		return
	if(world.time < signal.unlock_at)
		to_chat(user, span_warning("The seals are still locked. The display reads [DisplayTimeText(signal.unlock_at - world.time)] until they disengage."))
		return
	if(busy)
		balloon_alert(user, "someone is already cracking it!")
		return

	busy = TRUE
	user.visible_message(
		span_warning("[user] starts forcing [src]'s escrow locks!"),
		span_notice("You start forcing the escrow locks... hold still, any hit will break your grip."),
	)
	playsound(src, 'sound/machines/click.ogg', 50, TRUE)
	var/health_at_start = user.health
	var/cracked = do_after(user, CONTESTED_CACHE_OPEN_TIME, target = src, extra_checks = CALLBACK(src, PROC_REF(crack_still_valid), user, health_at_start))
	busy = FALSE
	if(!cracked)
		balloon_alert(user, "override interrupted!")
		return
	crack_open(user)

/// do_after side conditions: the vault is still sealed and the cracker hasn't taken damage.
/// (Moving away and incapacitation already cancel the do_after itself.)
/obj/structure/contested_cache_vault/proc/crack_still_valid(mob/living/user, health_at_start)
	if(breached)
		return FALSE
	if(user.health < health_at_start)
		return FALSE
	return TRUE

/obj/structure/contested_cache_vault/proc/crack_open(mob/living/user)
	if(QDELETED(src) || breached)
		return
	var/obj/structure/overmap/space_ruin/contested_cache/signal = signal_ref?.resolve()
	if(!signal || signal.vault_opened || world.time < signal.unlock_at)
		return
	set_breached()
	playsound(src, 'sound/machines/airlock/boltsup.ogg', 75, TRUE)
	user.visible_message(
		span_boldwarning("[src] grinds open!"),
		span_boldnotice("The escrow locks release. The cache is yours."),
	)
	var/obj/structure/closet/crate/secure/ship_part_prize/crate = spawn_ship_part_prize(get_drop_turf())
	if(crate)
		crate.visible_message(span_notice("[crate] slides out of [src]'s dispensary rack."))
	signal.on_vault_cracked(user)

/// Marks the vault as cracked without paying out - used both on a real crack and
/// when the interior reloads after the prize was already claimed.
/obj/structure/contested_cache_vault/proc/set_breached()
	breached = TRUE
	icon_state = "cache_vault_open"
	update_appearance()

/// First open cardinal turf beside the vault (the vault itself is dense), falling back to our own turf.
/obj/structure/contested_cache_vault/proc/get_drop_turf()
	for(var/check_dir in list(SOUTH, EAST, WEST, NORTH))
		var/turf/candidate = get_step(src, check_dir)
		if(candidate && !candidate.is_blocked_turf())
			return candidate
	return get_turf(src)

// ===== SCHEDULER =====

/datum/controller/subsystem/overmap
	/// Contested cache events surfaced so far this round.
	var/contested_caches_spawned = 0

/// Starts the round-long contested cache schedule. Called once from Initialize.
/datum/controller/subsystem/overmap/proc/schedule_contested_caches()
	addtimer(CALLBACK(src, PROC_REF(spawn_next_contested_cache)), CONTESTED_CACHE_FIRST_SPAWN_TIME)

/// Surfaces one contested cache in yellow/red space and reschedules while the round budget lasts.
/datum/controller/subsystem/overmap/proc/spawn_next_contested_cache()
	if(contested_caches_spawned >= CONTESTED_CACHE_MAX_PER_ROUND)
		return

	var/datum/map_template/ruin/space/contested_cache/template
	for(var/ruin_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/contested_cache/candidate = SSmapping.space_ruins_templates[ruin_id]
		if(istype(candidate))
			template = candidate
			break
	if(!template)
		log_mapping("SSovermap: contested cache template missing, event disabled this round")
		return

	// Mid-to-dangerous space: the prize should never sit in the safe outer ring.
	var/turf/spawn_turf = get_unused_overmap_square_in_zone_band(pick(ZONE_YELLOW, ZONE_RED))
	if(!spawn_turf)
		spawn_turf = get_unused_overmap_square()
	if(spawn_turf)
		var/obj/structure/overmap/space_ruin/contested_cache/signal = new(spawn_turf)
		signal.set_ruin_template(template)
		signal.start_event()
		contested_caches_spawned++
		log_mapping("SSovermap: contested cache event surfaced on the overmap")

	// A failed placement retries next interval
	if(contested_caches_spawned < CONTESTED_CACHE_MAX_PER_ROUND)
		addtimer(CALLBACK(src, PROC_REF(spawn_next_contested_cache)), CONTESTED_CACHE_SPAWN_INTERVAL)
