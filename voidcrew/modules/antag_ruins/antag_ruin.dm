/**
 * # Vestige ruins
 *
 * Antag-themed space ruins housing patrons: the remnants of dead antagonists
 * who trade boons (ported antagonist abilities) for bespoke trials. See
 * patron.dm / trial.dm / boon.dm for the actors; this file owns the map
 * templates, the overmap signal and the progressive arrival schedule.
 *
 * Vestige ruins never seed naturally (unpickable, like rare rumor ruins).
 * They surface one at a time as the round ages, the first at
 * VESTIGE_FIRST_SPAWN_TIME, another every VESTIGE_SPAWN_INTERVAL after, each
 * theme at most once per round, announced with a broadcast and shown on
 * sensors under its patron's name (patron_name below), colored red, distinct
 * from the gold of a rare ruin.
 *
 * The signal persists all round: interiors unload when everyone leaves (same
 * as any space ruin) but the overmap object never respawn-cycles away, so
 * crews can come back to their patron. Because interiors are wiped on unload,
 * NOTHING about a player's trial may live on the patron mob or the map,
 * trial state rides the player's mind (see trial.dm).
 */

// ===== MAP TEMPLATES =====

/datum/map_template/ruin/space/vestige
	prefix = "_maps/voidcrew/RandomRuins/SpaceRuins/"
	unpickable = TRUE
	allow_duplicates = FALSE
	/// Broadcast to everyone when this ruin surfaces mid-round
	var/arrival_announcement = "A new signal has surfaced in the sector. Approach is not advised."
	/// The patron's name (matches the vestige_patron mob mapped inside), this is what
	/// the overmap signal is called, both before and after survey. `name` above stays
	/// the vessel's name, used for admin tooling and mapping logs, not shown to players.
	var/patron_name

// ===== INTERIOR AREAS =====
// The offering rite (theme_cult.dm) refuses to work inside any vestige area,
// so every vestige map must use its own subtype below.

/area/ruin/space/has_grav/vestige
	name = "vestige ruin"
	ambience_index = AMBIENCE_SPOOKY

/area/ruin/space/has_grav/vestige/chrysalis
	name = "\improper The Chrysalis"

/area/ruin/space/has_grav/vestige/sepulcher
	name = "\improper The Scarlet Sepulcher"

/area/ruin/space/has_grav/vestige/gloaming
	name = "\improper The Gloaming"

/area/ruin/space/has_grav/vestige/athenaeum
	name = "\improper The Athenaeum"

/area/ruin/space/has_grav/vestige/reliquary
	name = "\improper The Reliquary"

/area/ruin/space/has_grav/vestige/wake
	name = "\improper The Wake"

/area/ruin/space/has_grav/vestige/silent_dojo
	name = "\improper The Silent Dojo"

/area/ruin/space/has_grav/vestige/aperture
	name = "\improper The Aperture"

/area/ruin/space/has_grav/vestige/roost
	name = "\improper The Roost"

/area/ruin/space/has_grav/vestige/menagerie
	name = "\improper The Menagerie"

/area/ruin/space/has_grav/vestige/facsimile
	name = "\improper The Facsimile"

/area/ruin/space/has_grav/vestige/comb
	name = "\improper The Comb"

/area/ruin/space/has_grav/vestige/shambles
	name = "\improper The Shambles"

/area/ruin/space/has_grav/vestige/loom
	name = "\improper The Loom"

// ===== OVERMAP SIGNAL =====

/obj/structure/overmap/space_ruin/vestige
	name = "dread signal"
	desc = "A signal that reads wrong on every instrument. Whatever is broadcasting it wants visitors, not cargo."

/obj/structure/overmap/space_ruin/vestige/Initialize(mapload, datum/map_template/ruin/space/template)
	. = ..()
	color = "#ff5964"

// Vestige signals name themselves after their patron immediately, not just on
// survey, you're meant to recognize your own patron from across the sector.
/obj/structure/overmap/space_ruin/vestige/set_ruin_template(datum/map_template/ruin/space/vestige/template)
	. = ..()
	if(template.patron_name)
		true_name = template.patron_name
		apply_patron_name()

// The base proc renames the signal to its true_name on survey, which would undo the
// \proper marker applied above - so re-apply it rather than let the article come back.
/obj/structure/overmap/space_ruin/vestige/on_surveyed()
	. = ..()
	apply_patron_name()

/**
 * Names the signal after its patron, marked as a proper noun.
 *
 * Twelve of the fourteen patron names start with "the" ("the Stranger", "the Curator"),
 * and BYOND prepends a definite article to any atom name that isn't flagged proper. Left
 * unflagged they read - and log - as "the the Stranger", which is how round-7's crash
 * traces name the ruin that was loading when the host died.
 */
/obj/structure/overmap/space_ruin/vestige/proc/apply_patron_name()
	if(!true_name)
		return
	name = "\proper [true_name]"

/obj/structure/overmap/space_ruin/vestige/categorize_ruin()
	ruin_category = "vestige"

/obj/structure/overmap/space_ruin/vestige/update_icon_for_category()
	icon_state = "strange_event"

/obj/structure/overmap/space_ruin/vestige/examine(mob/user)
	. = ..()
	. += span_boldwarning("Something in there is offering work.")

// Vestige ruins persist all round: unload when empty like anything else, but
// stay on the overmap and never spawn a replacement. Crews come back for
// their patron.
/obj/structure/overmap/space_ruin/vestige/check_and_respawn()
	if(!release_interior())
		// Same re-arm as the base proc: a refusal is usually the departing hull still
		// mid-move, or the worldgen queue timing out - and nothing else ever retries,
		// so giving up here would hold the slot for the rest of the round.
		addtimer(CALLBACK(src, PROC_REF(check_and_respawn)), 30 SECONDS, TIMER_UNIQUE)

// The base proc relocates the signal to a fresh overmap square on unload;
// vestige signals hold position so known patrons stay findable.
/obj/structure/overmap/space_ruin/vestige/unload_level()
	release_interior()

// ===== PROGRESSIVE ARRIVAL SCHEDULE =====

/datum/controller/subsystem/overmap
	/// Vestige ruin templates already surfaced this round (each theme appears once)
	var/list/spawned_vestige_templates = list()

/// Starts the round-long vestige arrival schedule. Called once from Initialize.
/datum/controller/subsystem/overmap/proc/schedule_vestige_ruins()
	addtimer(CALLBACK(src, PROC_REF(spawn_next_vestige_ruin)), VESTIGE_FIRST_SPAWN_TIME)

/// Surfaces one not-yet-seen vestige ruin and reschedules itself while themes remain
/datum/controller/subsystem/overmap/proc/spawn_next_vestige_ruin()
	if(length(spawned_vestige_templates) >= VESTIGE_MAX_PER_ROUND)
		return

	var/list/candidates = list()
	for(var/ruin_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/vestige/template = SSmapping.space_ruins_templates[ruin_id]
		if(!istype(template))
			continue
		if(template in spawned_vestige_templates)
			continue
		candidates += template
	if(!length(candidates))
		return

	var/datum/map_template/ruin/space/vestige/chosen = pick(candidates)
	var/turf/spawn_turf = get_unused_overmap_square()
	if(spawn_turf)
		var/obj/structure/overmap/space_ruin/vestige/signal = new(spawn_turf)
		signal.set_ruin_template(chosen)
		spawned_vestige_templates += chosen
		priority_announce(chosen.arrival_announcement, "Deep Space Advisory", sender_override = "Sector Sensor Net")
		log_mapping("SSovermap: Vestige ruin '[chosen.name]' surfaced on the overmap")

	// Reschedule while themes remain; a failed placement retries next interval
	if(length(spawned_vestige_templates) < VESTIGE_MAX_PER_ROUND && length(candidates) > (spawn_turf ? 1 : 0))
		addtimer(CALLBACK(src, PROC_REF(spawn_next_vestige_ruin)), VESTIGE_SPAWN_INTERVAL)
