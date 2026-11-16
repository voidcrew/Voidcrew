/*
 * Cassette tapes, the walkman and the dual cassette deck.
 *
 * Ported from Voidcrew-LRP (github.com/voidcrew/Voidcrew-LRP @ 0e6a385, AGPL-3.0) and rewritten
 * for current tg. The walkman and cassette sprites in icons/walkman.dmi come from that port,
 * which took them from CM-SS13 (cmss13-devs/cmss13), licensed CC-BY-SA 3.0. Some stickers
 * were dropped (third-party branding and map jokes); the rest are unchanged.
 *
 * Music comes only from the server's jukebox songs (config/jukebox_music/sounds), loaded by the
 * jukebox's own loader. With no songs configured, mixtapes spawn blank.
 */

/// Every track a tape can hold: the server's jukebox songs, minus the built-in fallback track.
GLOBAL_LIST(cassette_tracks)

/// Returns the shared list of /datum/track a tape can carry. Loaded once through the jukebox's
/// own config loader. `host` is any movable, needed only because a jukebox datum wants a parent.
/proc/get_cassette_tracks(atom/movable/host)
	if(!isnull(GLOB.cassette_tracks))
		return GLOB.cassette_tracks
	GLOB.cassette_tracks = list()
	if(!ismovable(host))
		return GLOB.cassette_tracks
	var/datum/jukebox/single_mob/catalog = new(host)
	for(var/song_name in catalog.songs)
		var/datum/track/track = catalog.songs[song_name]
		// The jukebox falls back to a lobby song when no music is configured. Tapes stay blank instead.
		if(istype(track, /datum/track/default) || !track.song_path)
			continue
		GLOB.cassette_tracks += track
	qdel(catalog)
	return GLOB.cassette_tracks

/// A track's name as written on a label, cut short if the file name runs long.
/proc/cassette_track_label(datum/track/track)
	var/label = track?.song_name
	if(!label)
		return "untitled"
	if(length_char(label) > 40)
		label = "[copytext_char(label, 1, 38)]..."
	return label

/obj/item/cassette_tape
	name = "cassette tape"
	desc = "A cassette tape."
	icon = 'voidcrew/modules/cassettes/icons/walkman.dmi'
	icon_state = "cassette_flip"
	w_class = WEIGHT_CLASS_TINY
	force = 1
	throwforce = 0
	obj_flags = UNIQUE_RENAME
	drop_sound = 'sound/items/handling/tape_drop.ogg'
	pickup_sound = 'sound/items/handling/tape_pickup.ogg'
	/// Two lists of /datum/track, side A then side B. Each tape owns its own lists.
	var/list/sides
	/// Whether side B is the one facing up.
	var/flipped = FALSE
	/// Most tracks one side holds.
	var/max_side_tracks = 7
	/// Sticker icon state.
	var/sticker = "cassette_flip"

/obj/item/cassette_tape/Initialize(mapload)
	. = ..()
	sides = list(list(), list())
	icon_state = sticker

/obj/item/cassette_tape/Destroy()
	sides = null
	return ..()

/// The tracks on the side facing up. This is the tape's own list: changes write straight to the tape.
/obj/item/cassette_tape/proc/current_side()
	return sides[flipped ? 2 : 1]

/// Whether either side has anything on it.
/obj/item/cassette_tape/proc/has_tracks()
	return length(sides[1]) || length(sides[2])

/// Adds a track to the side facing up. FALSE if that side is full.
/obj/item/cassette_tape/proc/record_track(datum/track/track)
	var/list/side = current_side()
	if(!istype(track) || length(side) >= max_side_tracks)
		return FALSE
	side += track
	return TRUE

/// Removes the track at this position on the side facing up.
/obj/item/cassette_tape/proc/erase_track(position)
	var/list/side = current_side()
	if(position < 1 || position > length(side))
		return FALSE
	side.Cut(position, position + 1)
	return TRUE

/obj/item/cassette_tape/proc/flip()
	flipped = !flipped

/obj/item/cassette_tape/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	flip()
	playsound(src, 'sound/items/taperecorder/tape_flip.ogg', 50, FALSE)
	balloon_alert(user, "side [flipped ? "B" : "A"]")
	return TRUE

/obj/item/cassette_tape/examine(mob/user)
	. = ..()
	if(!has_tracks())
		. += span_notice("The label is blank.")
		return
	for(var/side_number in 1 to 2)
		var/list/side = sides[side_number]
		if(!length(side))
			continue
		var/list/labels = list()
		for(var/datum/track/track as anything in side)
			labels += cassette_track_label(track)
		. += span_notice("Side [side_number == 1 ? "A" : "B"]: [jointext(labels, ", ")]")
	. += span_notice("Side [flipped ? "B" : "A"] is up.")

/// A tape somebody filled with songs. Rolls its tracks and sticker when it spawns.
/obj/item/cassette_tape/mixtape
	name = "mixtape"
	desc = "A cassette tape with a hand-written track list on the label."
	icon_state = "cassette_rainbow"
	sticker = "cassette_rainbow"

/obj/item/cassette_tape/mixtape/Initialize(mapload)
	var/static/list/stickers = list(
		"cassette_aesthetic",
		"cassette_blue",
		"cassette_camo",
		"cassette_eighties",
		"cassette_friday",
		"cassette_ftl",
		"cassette_gray",
		"cassette_green",
		"cassette_midnight",
		"cassette_ocean",
		"cassette_orange",
		"cassette_orange_blue",
		"cassette_pink_stripe",
		"cassette_purple",
		"cassette_rainbow",
		"cassette_red_black",
		"cassette_red_stripe",
		"cassette_smiley",
		"cassette_solaris",
		"cassette_starlight",
		"cassette_synth",
		"cassette_white_stripe",
	)
	sticker = pick(stickers)
	. = ..()
	fill_sides(get_cassette_tracks(src))

/// Fills each side with a random handful of different songs from `library`.
/obj/item/cassette_tape/mixtape/proc/fill_sides(list/library)
	if(!length(library))
		// Nothing to record. It comes out of the box blank.
		name = /obj/item/cassette_tape::name
		desc = /obj/item/cassette_tape::desc
		return
	for(var/list/side as anything in sides)
		var/list/pool = library.Copy()
		for(var/i in 1 to rand(1, min(max_side_tracks, length(pool))))
			side += pick_n_take(pool)

/obj/item/cassette_tape/blank
	name = "blank cassette tape"
	desc = "A blank cassette tape."

/obj/item/cassette_tape/blank/record_track(datum/track/track)
	. = ..()
	// Once something is on it, it isn't blank. A name someone wrote on it stays.
	if(. && name == initial(name))
		name = /obj/item/cassette_tape::name
		desc = /obj/item/cassette_tape::desc
