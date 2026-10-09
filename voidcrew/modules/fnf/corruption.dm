/**
 * Corruption, from Carlito049's Corruption+ (a fan extension of Phantom Fear and Pincer's
 * Corruption mod): songs where a dark violet corruption eats its singers.
 *
 * A corruption song says who it starts with and when anyone changes, the way the mod does it: its
 * chart names the player, the opponent and whoever's in the girlfriend's place, and its "Change
 * Character" events swap them mid-song. Each of the mod's characters is a look and a level of
 * corruption here (GLOB.fnf_corruption_cast): Kapi goes from himself to fully corrupted over the
 * arcade songs, the corrupted Pico and Kapi fight it off and lose it again, the "bait" versions are
 * flashbacks to before. Whoever sings as the player keeps their own look and takes on the level;
 * the opponent and whoever's behind them are summoned as the mod's characters.
 *
 * Corruption spreads as it does in the mod's sprites: the far side first (the arm and leg away
 * from the crowd, the tail), then the hands go red, then the near limbs, the body and the head,
 * each piece taken over in growing dark violet splotches while every colour drains. Once the
 * head's gone, the face glows hot pink: "( • )" eyes turned on their side and a candy-corn grin.
 * Clothes it's taken go dark violet, and their bright trims glow hot pink.
 *
 * Fighting it off doesn't run that backwards. Like the mod's Pico and Kapi breaking free for a
 * while, the head comes back first (their hair, then half their face: the near eye), and the near
 * hand with it, while the body comes back only slowly and the far side stays taken.
 */

/**
 * The mod's characters: each a look (see opponents.dm; null for nobody, just the speakers), how
 * corrupted they are, and anything else about them: "eyes" ("red" instead of pink, "blank" for no
 * pupils glowing in them), "wings" ("angel", "demon"), "flying", "peak": how far it had them before
 * they started fighting it off (the ones partway free), "face": "manic" for a desperate grin,
 * sweating, between notes, and "bar": their colour on the health bar, "seat": what they're sat on in the girlfriend's place (see
 * /datum/fnf_stage/proc/set_seat()), "prop": what they have by them (see set_singer_prop()), and
 * "facing": "enemy" for someone in the girlfriend's place turned to face the opponent, not the front.
 */
GLOBAL_LIST_INIT(fnf_corruption_cast, list(
	// Pico, corrupted from the start of the arcade; the second and third fight back (orange hair and
	// a green collar through the dark, then half his face), then it takes him again.
	"corruptedpico" = list("bar" = "#1a152a", "look" = "pico", "level" = 1),
	"corruptedpico2" = list("bar" = "#1a152a", "look" = "pico", "level" = 0.85, "peak" = 1, "eyes" = "blank"),
	"corruptedpico3" = list("bar" = "#1a152a", "look" = "pico", "level" = 0.7, "peak" = 1),
	"corruptedpico4" = list("bar" = "#1a152a", "look" = "pico", "level" = 1),
	"corruptedpico5" = list("bar" = "#1a152a", "look" = "pico", "level" = 1),
	"pico-bait" = list("bar" = "#b7d855", "look" = "pico", "level" = 0),
	// Kapi at his arcade machine, taken a little more each time: a red hand, then the far side, then
	// half his face, then all of him.
	"kapi" = list("bar" = "#76719e", "look" = "kapi", "level" = 0, "prop" = "dance_pad"),
	"kapi1" = list("bar" = "#76719e", "look" = "kapi", "level" = 0.08, "prop" = "dance_pad"),
	"kapi2" = list("bar" = "#76719e", "look" = "kapi", "level" = 0.25, "prop" = "dance_pad"),
	"kapi3" = list("bar" = "#76719e", "look" = "kapi", "level" = 0.45, "prop" = "dance_pad"),
	"kapi4" = list("bar" = "#1f1a2f", "look" = "kapi", "level" = 0.65, "prop" = "dance_pad"),
	"kapi5" = list("bar" = "#1f1a2f", "look" = "kapi", "level" = 0.85, "eyes" = "blank", "prop" = "dance_pad"),
	"kapi6" = list("bar" = "#1f1a2f", "look" = "kapi", "level" = 1, "prop" = "dance_pad"),
	"kapi-bait" = list("bar" = "#76719e", "look" = "kapi", "level" = 0, "prop" = "dance_pad"),
	// Kapi corrupted, hunting: he fights it (a grey ear and his blue coming back), then his eyes go red.
	"corruptedkapi" = list("bar" = "#1f1a2f", "look" = "kapi", "level" = 1, "prop" = "dance_pad_corrupt"),
	"corruptedkapi2" = list("bar" = "#1f1a2f", "look" = "kapi", "level" = 1, "prop" = "dance_pad_corrupt"),
	"corruptedkapi3" = list("bar" = "#1f1a2f", "look" = "kapi", "level" = 0.75, "peak" = 1, "prop" = "dance_pad_corrupt"),
	"corruptedkapi35" = list("bar" = "#1f1a2f", "look" = "kapi", "level" = 0.85, "peak" = 1, "prop" = "dance_pad_corrupt"),
	"corruptedkapi4" = list("bar" = "#1f1a2f", "look" = "kapi", "level" = 1, "eyes" = "red", "prop" = "dance_pad_corrupt"),
	"morabait" = list("bar" = "#1f1a2f", "look" = "mora", "level" = 0),
	// Skarlet Bunny, with the corruption at her boots from the start, then in patches all over, then
	// nearly all of her, though her face is still her own.
	"skarlet1" = list("bar" = "#ff006e", "look" = "skarlet", "level" = 0.1),
	"skarlet2" = list("bar" = "#ff006e", "look" = "skarlet", "level" = 0.35),
	"skarlet3" = list("bar" = "#1a152a", "look" = "skarlet", "level" = 0.62),
	// Marble, behind the speaker, long gone.
	"corruptedmarble" = list("bar" = "#1f1a2f", "look" = "marble", "level" = 1, "prop" = "speaker_small"),
	"corruptedmarble2" = list("bar" = "#1f1a2f", "look" = "marble", "level" = 0.9, "peak" = 1, "eyes" = "blank", "prop" = "speaker_small"),
	"corruptedmarble3" = list("bar" = "#1f1a2f", "look" = "marble", "level" = 1, "prop" = "speaker_small"),
	// Carol in the church ruins, then flying, half angel and half demon, then all demon.
	"carol1" = list("bar" = "#666699", "look" = "carol", "level" = 0.05),
	"carol2" = list("bar" = "#666699", "look" = "carol", "level" = 0.15),
	"carolBait" = list("bar" = "#666699", "look" = "carol", "level" = 0),
	"Acarol3" = list("bar" = "#ff7900", "look" = "carol", "level" = 0.6, "wings" = "angel", "flying" = TRUE),
	"Acarol4" = list("bar" = "#ff7900", "look" = "carol", "level" = 0.6, "wings" = "angel", "flying" = TRUE, "face" = "manic"),
	"Acarol5" = list("bar" = "#1a152a", "look" = "carol", "level" = 0.9, "wings" = "demon", "eyes" = "blank", "flying" = TRUE),
	// Girlfriend, corrupted, singing and flying; Boyfriend corrupted on the speakers.
	"corruptedgirlfriend" = list("bar" = "#1f1a2f", "look" = "gf", "level" = 1),
	"corruptedgirlfriendBait" = list("bar" = "#a5004d", "look" = "gf", "level" = 0),
	"corruptedgirlfriendflying" = list("bar" = "#1f1a2f", "look" = "gf", "level" = 0.9, "flying" = TRUE),
	"corruptedgirlfriendflying2" = list("bar" = "#1f1a2f", "look" = "gf", "level" = 1, "flying" = TRUE),
	"EVILspeakersGF" = list("bar" = "#1f1a2f", "look" = "gf", "level" = 1, "seat" = "speakers_evil"),
	"EVILspeakersBF" = list("bar" = "#1f1a2f", "look" = "bf", "level" = 1, "seat" = "speakers_evil"),
	"EVILspeakersBFbait" = list("bar" = "#31b0d1", "look" = "bf", "level" = 0, "seat" = "speakers"),
	"GFPcorruptedBF" = list("bar" = "#1f1a2f", "look" = "bf", "level" = 1, "facing" = "enemy"),
	"corruptedbf2" = list("bar" = "#1f1a2f", "look" = "bf", "level" = 1),
	// Nobody: just the speakers, or an empty stage.
	"speakers" = list("bar" = "#3d3d65", "look" = null, "seat" = "speakers"),
	"EVILspeakers" = list("bar" = "#3d3d65", "look" = null, "seat" = "speakers_evil"),
	"nocharacter" = list("bar" = "#000000", "look" = null, "hidden" = TRUE),
))

/**
 * How each song's own script drains the player whenever the opponent hits a note: list of list(from
 * step, to step or null, only while health is over this, how much), in Funkin's units (the bar is 2).
 */
GLOBAL_LIST_INIT(fnf_corruption_drains, list(
	"claws" = list(list(0, null, 0.1, 0.016)),
	"vile-vice" = list(list(0, null, 0.1, 0.025)),
	"feral" = list(list(0, null, 0.25, 0.024)),
	"broken-wires" = list(list(0, 509, 0.1, 0.025), list(509, null, 1, 0.02)),
	"cursed" = list(list(0, null, 0.1, 0.005)),
	"purification" = list(list(0, 1408, 0.1, 0.009), list(1408, 2432, 0.1, 0.02)),
))

// The body.

/mob/living/carbon
	/// Corruption on this body, kept on the mob so a rebuilt rig (a species change, or one that isn't
	/// made yet) picks it up: list(level, peak, eyes), or null when clean.
	var/list/fnf_corruption_state

/// Corrupts this body (see /datum/limb_rig/proc/set_corruption()), rig or no rig yet.
/mob/living/carbon/proc/fnf_set_corruption(level, eyes, peak)
	if(limb_rig)
		limb_rig.set_corruption(level, eyes, peak)
		return
	level = clamp(level, 0, 1)
	fnf_corruption_state = level ? list(level, max(fnf_corruption_state?[2] || 0, level, peak || 0), eyes || "pink") : null

/datum/limb_rig/New(mob/living/carbon/owner)
	. = ..()
	var/list/state = owner.fnf_corruption_state
	if(state)
		corruption = state[1]
		corruption_peak = state[2]
		corruption_eyes = state[3]
		refresh_corruption()

/datum/limb_rig
	/// How far corruption has taken this body, 0 to 1.
	var/corruption = 0
	/// The furthest it's got since the body was last clean: anything less is being fought off.
	var/corruption_peak = 0
	/// The colour its corrupted eyes glow: "pink", or "red".
	var/corruption_eyes = "pink"
	/// What corruption's drawn on each piece, by piece.
	var/list/corruption_images

/**
 * Corrupts the body this far (0 to 1), its eyes glowing pink or red once its face is taken. With a
 * peak, it's fighting its way back down from there.
 */
/datum/limb_rig/proc/set_corruption(level, eyes = "pink", peak)
	corruption = clamp(level, 0, 1)
	corruption_peak = corruption ? max(corruption_peak, corruption, peak || 0) : 0
	corruption_eyes = eyes || "pink"
	owner.fnf_corruption_state = corruption ? list(corruption, corruption_peak, corruption_eyes) : null
	refresh_corruption()
	refresh_fnf_face()

/datum/limb_rig/proc/refresh_corruption()
	for(var/atom/movable/piece as anything in corruption_images)
		piece.cut_overlay(corruption_images[piece])
		piece.color = null
	corruption_images = null
	set_sprite_saturation(1 - corruption * 0.7)
	if(!corruption)
		return
	corruption_images = list()
	var/far_side = get_facing() == EAST ? "l" : (get_facing() == WEST ? "r" : null)
	var/list/drained = color_matrix_saturation(1 - corruption * 0.7)
	var/list/tainted_clothes
	var/list/coated_flesh
	// A taken face sits on a head that's all coat, whatever the splotches are doing.
	var/face_taken = is_face_corrupted() && !is_face_half_freed()
	// Until then, never so dark the face can't be made out on it.
	var/head_most = face_taken ? 1 : 0.5
	for(var/list/piece_info as anything in get_corruption_pieces())
		var/atom/movable/piece = piece_info[1]
		var/part_id = piece_info[2]
		var/kind = piece_info[3]
		if(!piece)
			continue
		var/list/images = list()
		var/taken = get_corruption_of(part_id, far_side)
		if(part_id == RIG_HEAD)
			taken = face_taken ? 1 : min(taken, head_most)
		var/amount = round(taken * 8)
		switch(kind)
			if("clothes")
				// Clothes go over to dark violet as it takes them, their bright trims to hot pink.
				tainted_clothes = tainted_clothes || get_tainted_clothes_matrix()
				piece.color = fnf_blend_colour_matrices(drained, tainted_clothes, taken)
			if("flesh")
				// A species' own head, hair, tail and wings (drawn as they draw them): into the coat.
				coated_flesh = coated_flesh || get_coated_flesh_matrix()
				piece.color = fnf_blend_colour_matrices(drained, coated_flesh, taken)
			else
				// The body's own sprite (drained, see set_sprite_saturation()): the coat, baked to
				// each piece's shape, in splotches, over it.
				if(amount)
					var/image/coat = image('voidcrew/modules/fnf/icons/corruption_coats.dmi', "coat_[kind]_[amount]")
					coat.color = FNF_CORRUPTION_COLOUR
					coat.alpha = 235
					coat.pixel_w = -16
					coat.layer = FLOAT_LAYER + 0.01
					images += coat
		// The Experiment's orange tail tip glows hot pink as it's taken.
		var/tip = part_id == RIG_TAIL && kind != "flesh" ? get_corruption_tail_tip() : null
		if(tip && amount)
			var/image/glow = image('voidcrew/modules/fnf/icons/corruption_64.dmi', tip)
			glow.color = FNF_CORRUPTION_TRIM
			glow.alpha = amount * 32 - 1
			glow.appearance_flags = RESET_COLOR
			glow.pixel_w = -16
			glow.layer = FLOAT_LAYER + 0.03
			images += glow
		var/hands = piece_info[4]
		// Blood red hands, until the hand's fought free.
		if(hands && corruption >= 0.2 && get_corruption_fought(part_id, far_side) < 0.5)
			var/image/red = image('voidcrew/modules/fnf/icons/corruption_64.dmi', hands)
			red.color = FNF_CORRUPTION_HANDS
			// Blood red whatever's drained the rest.
			red.appearance_flags = RESET_COLOR
			red.pixel_w = -16
			red.layer = FLOAT_LAYER + 0.02
			images += red
		piece.add_overlay(images)
		corruption_images[piece] = images

/// A species' own flesh taken by corruption: its dark violet, keeping just enough shading to read.
/datum/limb_rig/proc/get_coated_flesh_matrix()
	var/list/violet = rgb2num(FNF_CORRUPTION_COLOUR)
	var/list/weights = list(0.3, 0.59, 0.11)
	. = new /list(12)
	for(var/channel in 1 to 3)
		var/shade = violet[channel] / 255
		for(var/source in 1 to 3)
			.[(source - 1) * 3 + channel] = shade * weights[source] * 0.9
		.[9 + channel] = shade * 0.55

/// Blends two colour matrices (3 by 4 or 4 by 5) this far from the first to the second.
/proc/fnf_blend_colour_matrices(list/start_matrix, list/end_matrix, amount)
	start_matrix = fnf_full_colour_matrix(start_matrix)
	end_matrix = fnf_full_colour_matrix(end_matrix)
	amount = clamp(amount, 0, 1)
	. = new /list(20)
	for(var/i in 1 to 20)
		.[i] = start_matrix[i] + (end_matrix[i] - start_matrix[i]) * amount

/// A colour matrix as the full 4 by 5 (rows for red, green, blue, alpha, then the constants).
/proc/fnf_full_colour_matrix(list/matrix)
	if(length(matrix) == 20)
		return matrix
	return list(
		matrix[1], matrix[2], matrix[3], 0,
		matrix[4], matrix[5], matrix[6], 0,
		matrix[7], matrix[8], matrix[9], 0,
		0, 0, 0, 1,
		matrix[10], matrix[11], matrix[12], 0,
	)

/**
 * The colour matrix for clothes corruption's taken whole: their main colour turns its dark violet,
 * anything darker goes on down to black, and anything brighter (trims, stripes, buttons, highlights)
 * climbs to hot pink.
 */
/datum/limb_rig/proc/get_tainted_clothes_matrix()
	var/list/main = rgb2num(get_main_clothes_colour())
	// Dark clothes stay dark, only what really stands out on them glowing: going by a dark main
	// colour itself would send every shade on them pink.
	var/main_brightness = max((main[1] * 0.3 + main[2] * 0.59 + main[3] * 0.11) / 255, FNF_CORRUPTION_DARKEST_MAIN)
	var/list/violet = rgb2num(FNF_CORRUPTION_CLOTHES_COLOUR)
	var/list/trim = rgb2num(FNF_CORRUPTION_TRIM)
	var/list/weights = list(0.3, 0.59, 0.11)
	. = new /list(12)
	for(var/channel in 1 to 3)
		// How fast this channel climbs from violet to pink with brightness.
		var/climb = (trim[channel] - violet[channel]) / 255 / FNF_CORRUPTION_TRIM_RISE
		for(var/source in 1 to 3)
			.[(source - 1) * 3 + channel] = climb * weights[source]
		.[9 + channel] = violet[channel] / 255 - climb * main_brightness

/// What colour the owner's clothes mostly are: their outer suit's, or else their jumpsuit's.
/datum/limb_rig/proc/get_main_clothes_colour()
	var/mob/living/carbon/human/wearer = owner
	if(istype(wearer))
		for(var/obj/item/worn in list(wearer.wear_suit, wearer.w_uniform))
			var/list/colours = worn.greyscale_colors ? splittext(worn.greyscale_colors, "#") : null
			if(length(colours) > 1 && length(colours[2]) == 6)
				return "#[colours[2]]"
			if(istext(worn.color))
				return worn.color
			if(worn)
				return get_icon_main_colour(worn.icon, worn.icon_state)
	return "#737373"

/// The colour most of an icon is (its outline and anything nearly black aside), worked out once per icon.
/proc/get_icon_main_colour(icon_file, icon_state)
	var/static/list/found = list()
	var/key = "[icon_file]-[icon_state]"
	if(found[key])
		return found[key]
	var/icon/sprite = icon(icon_file, icon_state, SOUTH, 1)
	var/list/counts = list()
	for(var/x in 1 to sprite.Width())
		for(var/y in 1 to sprite.Height())
			var/pixel = sprite.GetPixel(x, y)
			if(!pixel)
				continue
			var/list/rgb = rgb2num(pixel)
			if(length(rgb) > 3 && rgb[4] < 128)
				continue
			if(rgb[1] + rgb[2] + rgb[3] < 60)
				continue
			var/colour = copytext(pixel, 1, 8)
			counts[colour] = (counts[colour] || 0) + 1
	var/best = "#737373"
	var/most = 0
	for(var/colour in counts)
		if(counts[colour] > most)
			most = counts[colour]
			best = colour
	found[key] = best
	return best

/**
 * How far corruption has taken one piece of the body, 0 to 1: the far side first, then the near
 * limbs, the body, and the head last. Whatever's been fought off since its peak is taken back out.
 */
/datum/limb_rig/proc/get_corruption_of(part_id, far_side)
	return get_corruption_spread(part_id, far_side, corruption_peak) * (1 - get_corruption_fought(part_id, far_side))

/**
 * How much of one piece has been fought free, 0 to 1, going by how far the body's come back from
 * its peak: the head first, the near hand and the body next, the far side last.
 */
/datum/limb_rig/proc/get_corruption_fought(part_id, far_side)
	var/fought = corruption_peak - corruption
	if(fought <= 0)
		return 0
	var/delay
	switch(part_id)
		if(RIG_HEAD)
			delay = 0
		if(RIG_CHEST)
			delay = 0.2
		if(RIG_TAIL, "wings")
			delay = 0.3
		else
			var/side = copytext(part_id, 1, 2)
			var/is_arm = findtext(part_id, "arm")
			if(!far_side)
				delay = 0.2
			else if(side == far_side)
				delay = is_arm ? 0.4 : 0.35
			else if(findtext(part_id, "forearm"))
				delay = 0.03
			else
				delay = is_arm ? 0.2 : 0.25
	return clamp((fought - delay) / FNF_CORRUPTION_FIGHT, 0, 1)

/// How far corruption at this level spreads over one piece, 0 to 1.
/datum/limb_rig/proc/get_corruption_spread(part_id, far_side, level)
	var/start
	switch(part_id)
		if(RIG_CHEST)
			start = 0.3
		if(RIG_HEAD)
			start = 0.5
		if(RIG_TAIL)
			start = 0.05
		if("wings")
			start = 0.1
		else
			var/side = copytext(part_id, 1, 2)
			var/is_arm = findtext(part_id, "arm")
			if(!far_side)
				start = 0.15
			else if(side == far_side)
				start = is_arm ? 0 : 0.05
			else
				start = is_arm ? 0.35 : 0.25
	return clamp((level - start) / FNF_CORRUPTION_SPAN, 0, 1)

/// The mask of the tail's own bright tip, to glow once it's taken, if it has one.
/datum/limb_rig/proc/get_corruption_tail_tip()
	return null

/datum/limb_rig/sprites/get_corruption_tail_tip()
	return fnf_face_set ? "tail_[fnf_face_set]" : null

/**
 * Every piece corruption draws on: list(piece, piece id, how it's taken, its hand mask or null). How
 * it's taken is "clothes", "flesh" (drawn by the species itself), or the coat state for a body sprite.
 */
/datum/limb_rig/proc/get_corruption_pieces()
	return list()

/datum/limb_rig/sprites/get_corruption_pieces()
	. = list()
	var/list/zones = get_rig_piece_zones()
	for(var/part_id in parts)
		// A humanoid's pieces show a body sprite only where a limb is.
		if(istype(src, /datum/limb_rig/sprites/humanoid) && !zones[part_id])
			continue
		var/hands = findtext(part_id, "_forearm") ? "hands_[get_corruption_sheet()]_[part_id]" : null
		. += list(list(parts[part_id], part_id, "[get_corruption_sheet()]_[get_corruption_sprite_state(part_id)]", hands))
	for(var/part_id in cloth_parts)
		. += list(list(cloth_parts[part_id], part_id, "clothes", null))
	for(var/side in shoe_parts)
		. += list(list(shoe_parts[side], "[side]_foot", "clothes", null))

/datum/limb_rig/sprites/humanoid/get_corruption_pieces()
	. = ..()
	// The head's piece carries the species' own head, hair and all: flesh, not clothes.
	for(var/list/piece_info as anything in .)
		if(piece_info[1] == cloth_parts[RIG_HEAD])
			piece_info[3] = "flesh"
	. += list(list(wings_part, "wings", "flesh", null))
	. += list(list(tail_part, RIG_TAIL, "flesh", null))

/// Which body sprites the coat's baked for (see icons/corruption_coats.dmi).
/datum/limb_rig/sprites/proc/get_corruption_sheet()
	return fnf_face_set || "humanoid"

/// Which of them a piece shows.
/datum/limb_rig/sprites/proc/get_corruption_sprite_state(part_id)
	return part_id

/datum/limb_rig/sprites/humanoid/get_corruption_sprite_state(part_id)
	var/mob/living/carbon/human/human_owner = owner
	if(part_id == RIG_CHEST && istype(human_owner) && human_owner.physique == FEMALE)
		return "chest_f"
	return part_id

/// Which side's far changes with facing: corruption goes with it.
/datum/limb_rig/refresh_facing()
	. = ..()
	if(corruption)
		refresh_corruption()

// Singing it.

/**
 * A corruption song's cast, played out: the player taking on whoever the song says they are now,
 * the summoned opponent and the one behind them changing with the song.
 */
/datum/fnf_corruption
	var/datum/fnf_battle/battle
	/// The changes still to come: list(list(ms, role, character), ...), in order.
	var/list/changes
	var/next_change = 1
	/// The song's overlays, flashes, animations and shakes (see /datum/fnf_song/var/overlay_events), in order.
	var/list/overlay_events
	var/next_overlay = 1
	/// Everyone it's touched, to put right after.
	var/list/mob/living/carbon/touched = list()
	/// Who each role ("player", "opponent", "gf") is now, as the mod's cast: kept to, in case a
	/// singer's body is rebuilt, or wasn't ready yet, when they were made it.
	var/list/current_cast = list()
	/// When the cast was last checked on.
	var/next_check = 0
	/// Health each of the opponent's notes takes, as set by the song's "HealthDrainCustom" (Funkin's
	/// units, the bar being 2), on top of its own drain (see GLOB.fnf_corruption_drains).
	var/opponent_drain = 0
	/// And health each of the player's notes gives back.
	var/player_bonus = 0
	/// What the song lays over the stage (see get_layer()), by name.
	var/list/obj/effect/abstract/fnf_hud/layers = list()
	/// Who's drawn as a silhouette right now (the "Bad Apple" events), and in what colour.
	var/list/mob/silhouetted = list()
	/// Which silhouettes are up: "white" (black figures on white), "black" (white on black),
	/// "colour" (each in their colour, on black), or null.
	var/apple
	/// Words the song puts on screen (see show_subtitle()).
	var/obj/effect/abstract/fnf_hud/text/subtitle
	/// How much of the stage each listener's map window really shows, in pixels, by listener's ref:
	/// list(width, height). A zoomed-in map in a small window shows less than its whole view.
	var/list/visible_sizes = list()
	/// When the listeners' windows are next measured.
	var/next_measure = 0

/datum/fnf_corruption/New(datum/fnf_battle/battle)
	src.battle = battle
	var/datum/fnf_song/song = battle.song
	changes = song.character_changes || list()
	overlay_events = song.overlay_events || list()
	apply("player", song.legacy_cast["player"])
	apply("opponent", song.legacy_cast["opponent"])
	apply("gf", song.legacy_cast["gf"])
	make_screens()

/datum/fnf_corruption/Destroy()
	for(var/mob/living/carbon/singer as anything in touched)
		if(QDELETED(singer))
			continue
		singer.fnf_face_mood = null
		singer.fnf_set_corruption(0)
		singer.alpha = initial(singer.alpha)
		if(HAS_TRAIT_FROM(singer, TRAIT_MOVE_FLOATING, FNF_BATTLE_TRAIT))
			REMOVE_TRAIT(singer, TRAIT_MOVE_FLOATING, FNF_BATTLE_TRAIT)
	touched.Cut()
	set_apple(null, 0)
	for(var/name in layers)
		battle?.healthbar?.vis_contents -= layers[name]
	QDEL_LIST_ASSOC_VAL(layers)
	battle?.healthbar?.vis_contents -= subtitle
	QDEL_NULL(subtitle)
	battle = null
	return ..()

/datum/fnf_corruption/proc/tick(now)
	if(world.time >= next_check)
		next_check = world.time + 5
		keep_cast()
	if(world.time >= next_measure)
		next_measure = world.time + 5 SECONDS
		for(var/mob/listener as anything in battle.listeners)
			if(listener.client)
				INVOKE_ASYNC(src, PROC_REF(measure_view), listener)
	while(next_change <= length(changes))
		var/list/change = changes[next_change]
		if(change[1] > now)
			break
		next_change++
		apply(change[2], change[3])
	while(next_overlay <= length(overlay_events))
		var/list/event = overlay_events[next_overlay]
		if(event[1] > now)
			break
		next_overlay++
		show(event[2], event[3], event[4])

/// In Skarlet's songs, her tainted frame round the health bar.
/datum/fnf_corruption/proc/make_screens()
	var/obj/effect/abstract/fnf_hud/healthbar/bar = battle.healthbar
	if(!bar || battle.song.note_skin != "skarlet")
		return
	bar.set_frame('voidcrew/modules/fnf/icons/fnf_healthbar_tainted.dmi')

/**
 * One of the things the song lays over the stage, as the mod lays them over its screen: over the
 * world and under the arrows, centred where the singers' cameras look, and sized to cover their
 * views (with room for the camera's sway between the singers).
 * - "overlay", "flash", "dark": one of the mod's overlays (320 by 180), across the whole width of
 *   the view so no words are cut off; "_top" and "_bottom" carry its edges on above and below.
 * - "light", "black": a flash of colour, or the dark, over everything.
 * - "backdrop": the stage blacked or whited out behind whoever's on it, for the silhouettes.
 */
/datum/fnf_corruption/proc/get_layer(name)
	var/obj/effect/abstract/fnf_hud/healthbar/bar = battle.healthbar
	if(!bar)
		return null
	var/obj/effect/abstract/fnf_hud/layer_obj = layers[name]
	if(!layer_obj)
		layer_obj = new
		layer_obj.alpha = 0
		var/is_fill = (name in list("light", "black", "backdrop"))
		if(is_fill)
			layer_obj.icon_state = "bar"
			layer_obj.color = "#000000"
			layer_obj.layer = ABOVE_ALL_MOB_LAYER + 0.004
		else
			layer_obj.icon = 'voidcrew/modules/fnf/icons/fnf_corruption_overlays.dmi'
			layer_obj.layer = ABOVE_ALL_MOB_LAYER + (findtext(name, "flash") ? 0.007 : (findtext(name, "dark") ? 0.006 : 0.005))
		if(name == "backdrop")
			// Down among the singers, just under them.
			layer_obj.vis_flags = NONE
			SET_PLANE_EXPLICIT(layer_obj, GAME_PLANE, bar)
			layer_obj.layer = MOB_LAYER - 0.01
		bar.vis_contents += layer_obj
		layers[name] = layer_obj
	fit_layer(layer_obj, name)
	return layer_obj

/// Measures how much of the stage one listener's map window shows (see visible_sizes).
/datum/fnf_corruption/proc/measure_view(mob/listener)
	var/client/viewer = listener.client
	var/list/size = getviewsize(viewer.view)
	var/width = size[1] * ICON_SIZE_X
	var/height = size[2] * ICON_SIZE_Y
	// Stretched to fit (no zoom), the whole view's in the window. Zoomed, only what fits.
	var/zoom = viewer.view_size?.zoom
	if(zoom)
		var/list/window = splittext(winget(viewer, "mapwindow.map", "size"), "x")
		if(length(window) == 2 && text2num(window[1]) && text2num(window[2]))
			width = min(width, text2num(window[1]) / zoom)
			height = min(height, text2num(window[2]) / zoom)
	if(QDELETED(src) || !battle)
		return
	// A singer's screen is zoomed in on the stage (see /datum/fnf_side/proc/zoom_screen()).
	for(var/datum/fnf_side/side as anything in battle.sides)
		if(side.singer == listener && side.zoomed)
			width /= FNF_ZOOM
			height /= FNF_ZOOM
	var/list/old = visible_sizes[REF(listener)]
	if(old && old[1] == width && old[2] == height)
		return
	visible_sizes[REF(listener)] = list(width, height)
	for(var/name in layers)
		fit_layer(layers[name], name)

/// Sizes and places one of the song's layers (see get_layer()) for the views it's seen in now.
/datum/fnf_corruption/proc/fit_layer(obj/effect/abstract/fnf_hud/layer_obj, name)
	var/obj/effect/abstract/fnf_hud/healthbar/bar = battle.healthbar
	// Fills cover the biggest view; overlays fit in the smallest window, words and all.
	var/view_width = 15 * ICON_SIZE_X
	var/view_height = 15 * ICON_SIZE_Y
	var/seen_width
	var/seen_height
	for(var/mob/listener as anything in battle.listeners)
		if(!listener.client)
			continue
		var/list/size = getviewsize(listener.client.view)
		view_width = max(view_width, size[1] * ICON_SIZE_X)
		view_height = max(view_height, size[2] * ICON_SIZE_Y)
		var/list/seen = visible_sizes[REF(listener)] || list(size[1] * ICON_SIZE_X / FNF_ZOOM, size[2] * ICON_SIZE_Y / FNF_ZOOM)
		seen_width = isnull(seen_width) ? seen[1] : min(seen_width, seen[1])
		seen_height = isnull(seen_height) ? seen[2] : min(seen_height, seen[2])
	seen_width = seen_width || view_width
	seen_height = seen_height || view_height
	// The cameras sway 24 pixels either way between the singers.
	view_width += 48
	view_height += 16
	var/center_x = battle.camera_x - bar.x * ICON_SIZE_X
	var/center_y = battle.camera_y - bar.y * ICON_SIZE_Y
	if(layer_obj.icon_state == "bar" || (name in list("light", "black", "backdrop")))
		layer_obj.pixel_w = center_x - 16
		layer_obj.pixel_z = center_y - 16
		layer_obj.transform = matrix((view_width + 64) / ICON_SIZE_X, 0, 0, 0, (view_height + 64) / ICON_SIZE_Y, 0)
		return
	layer_obj.pixel_w = center_x - 160
	layer_obj.pixel_z = center_y - 90
	// Right across the smallest window, edge to edge (with the zoom on a singer's screen taken into
	// account, its words fit): its edges carry on above and below to the top and bottom.
	// The cameras lean 24 pixels either way, so it reaches that much further.
	var/scale = (seen_width + 48) / 320
	var/part = findtext(name, "_top") ? "top" : (findtext(name, "_bottom") ? "bottom" : null)
	if(!part)
		layer_obj.transform = matrix(scale, 0, 0, 0, scale, 0)
		return
	// A pixel of overlap, so no seam.
	var/strip = max((view_height - 180 * scale) / 2, 0) + 2
	var/offset = (180 * scale + strip) / 2 - 1
	layer_obj.transform = matrix(scale, 0, 0, 0, strip / 180, part == "top" ? offset : -offset)

/**
 * The mod's screen events, as it plays them:
 * - "overlay": an overlay fades in over three quarters of a second (value 1) or back out (0)
 * - "flash": an overlay up for its value in seconds, then quickly gone
 * - "light": the screen flashes a colour (the image), fading over the value in seconds
 * - "black": the screen fades to black over the value in seconds (image "1"), or comes back ("0")
 * - "apple": silhouettes (see set_apple()), the image saying which, over the value in seconds
 * - "blammed": the lights go down and everyone's lit a colour (the value, 1 to 5), or back up (0)
 * - "anim": someone on stage acts something out (the image), the value saying who
 * - "shake": the screen shakes for the value in seconds
 * - "drain", "health_drain": health taken or given (see drain())
 */
/datum/fnf_corruption/proc/show(kind, image_name, value)
	switch(kind)
		if("anim")
			act_out(image_name, value)
		if("shake")
			for(var/mob/listener as anything in battle.listeners)
				shake_camera(listener, max(round(value * 10), 1), 0.5)
		if("drain")
			drain(value)
		if("health_drain")
			opponent_drain = value
			player_bonus = text2num(image_name) || 0
		if("overlay", "flash")
			var/static/list/images = icon_states('voidcrew/modules/fnf/icons/fnf_corruption_overlays.dmi')
			// Missing ones (the mod names a "yourcalls" it doesn't have) are skipped, as the mod skips them.
			if(!(image_name in images))
				return
			// The overlay itself, and its edges carried on above and below it.
			for(var/part in list("", "_top", "_bottom"))
				var/obj/effect/abstract/fnf_hud/layer_obj = get_layer("[kind][part]")
				if(!layer_obj)
					return
				if(kind == "flash")
					layer_obj.icon_state = "[image_name][part]"
					layer_obj.alpha = 255
					animate(layer_obj, alpha = 255, time = max(value, 0.1) * 10)
					animate(alpha = 0, time = 3)
				else if(value)
					layer_obj.icon_state = "[image_name][part]"
					animate(layer_obj, alpha = 255, time = 7.5, easing = QUAD_EASING)
				else if(layer_obj.icon_state == "[image_name][part]")
					animate(layer_obj, alpha = 0, time = 7.5, easing = QUAD_EASING)
		if("light")
			var/obj/effect/abstract/fnf_hud/layer_obj = get_layer("light")
			if(layer_obj)
				layer_obj.color = image_name
				layer_obj.alpha = 255
				animate(layer_obj, alpha = 0, time = max(value, 0.1) * 10)
		if("black")
			var/obj/effect/abstract/fnf_hud/layer_obj = get_layer("black")
			if(layer_obj)
				if(image_name == "1")
					animate(layer_obj, alpha = 255, time = max(value, 0.1) * 10, easing = QUAD_EASING)
				else
					animate(layer_obj, alpha = 0, time = 0)
		if("apple")
			var/mode = image_name
			if(mode == "toggle-black")
				mode = apple == "black" ? null : "black"
			else if(mode == "toggle-colour")
				mode = apple == "colour" ? null : "colour"
			else if(mode == "off")
				mode = null
			set_apple(mode, value)
		if("subtitle")
			show_subtitle(image_name, value)
		if("alt_idle")
			// Purification's Girlfriend, once Boyfriend's swooped in to take over: the corruption eases
			// off her a little, and her eyes go blank.
			var/list/cast = current_cast["player"]
			if(image_name != "bf" || !cast || value != "-alt")
				return
			var/list/eased = cast.Copy()
			eased["peak"] = max(cast["peak"] || 0, cast["level"] || 0)
			eased["level"] = max((cast["level"] || 0) - 0.06, 0)
			eased["face"] = "blank"
			current_cast["player"] = eased
			corrupt(get_singer("player"), eased)
			// And she just hangs there, twitching, while he sings.
			battle.right?.hanging = TRUE
		if("blammed")
			var/static/list/colours = list("#31a2fd", "#31fd8c", "#f794f7", "#f96d63", "#fba633")
			set_apple(value ? "blammed" : null, 1, colours[clamp(value, 1, 5)])

/**
 * The mod's "Bad Apple" moments: the stage blacked or whited out behind everyone on it, and them
 * drawn as flat silhouettes against it: black on white, white on black, or each in their own colour.
 * And its "Blammed Lights": the stage dark, and everyone lit one colour.
 */
/datum/fnf_corruption/proc/set_apple(mode, seconds, light_colour)
	for(var/mob/living/figure as anything in silhouetted)
		if(!QDELETED(figure))
			figure.remove_atom_colour(ADMIN_COLOUR_PRIORITY, silhouetted[figure])
	silhouetted.Cut()
	apple = mode
	if(!battle)
		return
	battle.healthbar?.set_portrait_tints(null, null)
	var/obj/effect/abstract/fnf_hud/backdrop = get_layer("backdrop")
	if(backdrop)
		if(mode)
			backdrop.color = mode == "white" ? "#ffffff" : "#000000"
			animate(backdrop, alpha = 255, time = max(seconds, 0.1) * 10)
		else
			animate(backdrop, alpha = 0, time = max(seconds, 0.1) * 10)
	if(!mode)
		return
	// Each in their colour on the health bar (the girlfriend in hers).
	var/list/figures = list()
	if(battle.left?.singer)
		figures[battle.left.singer] = "#e0453a"
	if(battle.right?.singer)
		figures[battle.right.singer] = "#5de83a"
	if(battle.stage?.girlfriend)
		figures[battle.stage.girlfriend] = "#a5004d"
	var/left_tint
	var/right_tint
	for(var/mob/living/figure in figures)
		if(QDELETED(figure))
			continue
		var/list/rgb = rgb2num(mode == "blammed" ? light_colour : figures[figure])
		var/silhouette
		switch(mode)
			if("white")
				silhouette = "#000000"
			if("black")
				silhouette = list(0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1)
			if("blammed")
				// Lit, not flattened: the colour over their own shading.
				silhouette = light_colour
			else
				silhouette = list(0, 0, 0, 0, 0, 0, 0, 0, 0, rgb[1] / 255, rgb[2] / 255, rgb[3] / 255)
		figure.add_atom_colour(silhouette, ADMIN_COLOUR_PRIORITY)
		silhouetted[figure] = silhouette
		// Their heads on the health bar go with them.
		if(figure == battle.left?.singer)
			left_tint = silhouette
		else if(figure == battle.right?.singer)
			right_tint = silhouette
	battle.healthbar?.set_portrait_tints(left_tint, right_tint)

/// Words on screen under the stage, in a colour (or none, to clear them).
/datum/fnf_corruption/proc/show_subtitle(text, colour)
	var/obj/effect/abstract/fnf_hud/healthbar/bar = battle.healthbar
	if(!bar)
		return
	if(!subtitle)
		subtitle = new
		subtitle.maptext_width = 256
		subtitle.maptext_x = -112
		subtitle.layer = ABOVE_ALL_MOB_LAYER + 0.05
		subtitle.pixel_w = bar.center_x - 16
		subtitle.pixel_z = bar.center_y - FNF_STRUM_Y - 44 - 30
		bar.vis_contents += subtitle
	subtitle.maptext = text ? MAPTEXT("<span style='text-align:center;font-size:8pt;color:[colour];-dm-text-outline:1px #000000'><b>[html_encode(text)]</b></span>") : null

/// Someone acting out one of the mod's animations, the way the stage acts out Funkin's own.
/datum/fnf_corruption/proc/act_out(animation, who)
	var/static/list/roles = list("bf" = "bf", "boyfriend" = "bf", "0" = "bf", "dad" = "dad", "1" = "dad", "gf" = "gf", "girlfriend" = "gf", "2" = "gf")
	battle.stage?.play_animation(roles[lowertext(who)], lowertext(animation))

/**
 * A miss in Skarlet's songs: the dark comes down over everything at once and the music drops out,
 * then both come back over a second or two.
 */
/datum/fnf_corruption/proc/player_missed()
	if(battle.song.note_skin != "skarlet")
		return
	for(var/part in list("", "_top", "_bottom"))
		var/obj/effect/abstract/fnf_hud/layer_obj = get_layer("dark[part]")
		if(!layer_obj)
			break
		layer_obj.icon_state = "overlayskarlet[part]"
		animate(layer_obj, alpha = 255, time = 1, easing = QUAD_EASING|EASE_OUT)
		animate(alpha = 255, time = 10)
		animate(alpha = 0, time = 10)
	for(var/channel in list(battle.inst_channel, battle.left_voice_channel))
		battle.set_channel_volume(channel, 0)
		for(var/step in 1 to 5)
			addtimer(CALLBACK(battle, TYPE_PROC_REF(/datum/fnf_battle, set_channel_volume), channel, step / 5), 5 + step * 3, TIMER_DELETE_ME)

/**
 * The opponent hitting a note, in a song whose script drains the player for it (the mod's songs push
 * back hard): whatever its own script takes, then any drain its events have set. Funkin' counts
 * every step's piece of a held note as a note of its own, so a held one drains on all the way
 * through (length in milliseconds).
 */
/datum/fnf_corruption/proc/opponent_hit(length = 0)
	opponent_piece()
	var/step_ms = battle.crochet / 4
	for(var/piece in 1 to floor(length / step_ms))
		addtimer(CALLBACK(src, PROC_REF(opponent_piece)), piece * step_ms / 100, TIMER_DELETE_ME)

/// One piece of an opponent's note (see opponent_hit()).
/datum/fnf_corruption/proc/opponent_piece()
	// The drains are the song's character pushing back; a person singing it doesn't get them.
	if(!battle || battle.state != FNF_STATE_PLAYING || battle.is_pvp())
		return
	var/step = battle.get_song_time() / (battle.crochet / 4)
	for(var/list/rule as anything in GLOB.fnf_corruption_drains[battle.song.id])
		if(step < rule[1] || (rule[2] && step >= rule[2]))
			continue
		if(battle.health > rule[3] * FNF_HEALTH_MAX / 2)
			battle.adjust_health(-rule[4] * FNF_HEALTH_MAX / 2, battle.right)
		break
	if(opponent_drain && battle.health > 0.1 * FNF_HEALTH_MAX / 2)
		battle.adjust_health(-opponent_drain * FNF_HEALTH_MAX / 2, battle.right)

/// The player hitting a note: any extra health the song's events take for it, held pieces and all.
/datum/fnf_corruption/proc/player_hit(length = 0)
	if(!player_bonus)
		return
	player_piece()
	var/step_ms = battle.crochet / 4
	for(var/piece in 1 to floor(length / step_ms))
		addtimer(CALLBACK(src, PROC_REF(player_piece)), piece * step_ms / 100, TIMER_DELETE_ME)

/// One piece of the player's note (see player_hit()).
/datum/fnf_corruption/proc/player_piece()
	if(!battle || battle.state != FNF_STATE_PLAYING || !player_bonus || battle.is_pvp())
		return
	battle.adjust_health(-player_bonus * FNF_HEALTH_MAX / 2, battle.right)

/// The mod's "Drain" event: takes 0.02 more than its value (a negative value gives health back), unless that would finish the player.
/datum/fnf_corruption/proc/drain(value)
	if(battle.is_pvp())
		return
	var/damage = (0.02 + value) * FNF_HEALTH_MAX / 2
	if(battle.health > damage)
		battle.adjust_health(-damage, battle.right)

/// Makes sure everyone on stage looks as corrupted as their role says, whatever happened to their body.
/datum/fnf_corruption/proc/keep_cast()
	for(var/role in current_cast)
		var/list/cast = current_cast[role]
		// Nobody behind the speakers: she's just hidden (see apply()).
		if(role == "gf" && !cast["look"])
			continue
		var/mob/living/carbon/singer = get_singer(role)
		if(!istype(singer) || QDELETED(singer) || !singer.limb_rig)
			continue
		var/datum/limb_rig/rig = singer.limb_rig
		var/level = cast["level"] || 0
		if(rig.corruption != level || rig.corruption_eyes != (cast["eyes"] || "pink") || rig.corruption_peak < (cast["peak"] || 0))
			corrupt(singer, cast)
		else if(level && !rig.corruption_images)
			rig.refresh_corruption()
			rig.refresh_fnf_face()

/// Who's in a role on stage now.
/datum/fnf_corruption/proc/get_singer(role)
	switch(role)
		if("player")
			return battle.right?.singer
		if("opponent")
			return battle.left?.singer
		if("gf")
			return battle.stage?.girlfriend

/// Makes someone on stage whoever the song says they are now.
/datum/fnf_corruption/proc/apply(role, character)
	var/list/cast = GLOB.fnf_corruption_cast[character]
	if(!cast)
		return
	current_cast[role] = cast
	// A new character for the player moves as usual again (see the "alt_idle" event).
	if(role == "player" && battle.right)
		battle.right.hanging = FALSE
	// Their colour on the health bar, as the mod has it.
	if(role == "player")
		battle.healthbar?.set_colours(null, cast["bar"])
	else if(role == "opponent")
		battle.healthbar?.set_colours(cast["bar"], null)
	switch(role)
		if("player")
			corrupt(battle.right?.singer, cast)
		if("opponent")
			corrupt(battle.left?.singer, cast)
			// Moving as the mod's character does (see fnf_apply_style()), up on their wings or not.
			if(battle.left && cast["look"])
				battle.left.style = cast["flying"] ? "[cast["look"]]_flying" : cast["look"]
		if("gf")
			var/datum/fnf_stage/stage = battle.stage
			if(!stage)
				return
			if(!cast["look"])
				if(stage.girlfriend)
					stage.girlfriend.alpha = 0
				// Just the speakers, if anything.
				stage.set_seat(get_seat(cast))
				return
			if(!stage.girlfriend || stage.girlfriend.fnf_look != cast["look"])
				QDEL_NULL(stage.girlfriend)
				stage.summon_girlfriend_as(cast["look"])
			if(stage.girlfriend)
				stage.girlfriend.alpha = 255
				corrupt(stage.girlfriend, cast)
				stage.girlfriend_facing = cast["facing"] == "enemy" ? stage.get_enemy_side(stage.girlfriend) : SOUTH
				stage.girlfriend.setDir(stage.girlfriend_facing)
			stage.set_seat(get_seat(cast))

/// What someone in the girlfriend's place is sat on. Kapi's arcade has no speakers to sit on.
/datum/fnf_corruption/proc/get_seat(list/cast)
	if(battle.song.note_skin == "kapi")
		return null
	return cast["seat"]

/datum/fnf_corruption/proc/corrupt(mob/living/carbon/singer, list/cast)
	if(!istype(singer))
		return
	touched |= singer
	singer.alpha = cast["hidden"] ? 0 : initial(singer.alpha)
	battle.healthbar?.show_portrait(singer, !cast["hidden"])
	// With the player gone (the end of Purification), the camera's all on the opponent.
	if(cast["hidden"] && singer == battle.right?.singer)
		battle.camera_focus = -battle.stage?.gap_px / 48 || -1
		battle.pan_cameras()
		// And zoomed right in on them, once the player's last notes are played: zoomed, they'd lose them.
		for(var/datum/fnf_side/side as anything in battle.sides)
			if(side.zoomed)
				side.zoom_when_done = FNF_ZOOM + 1
	singer.fnf_face_mood = cast["face"]
	// Kapi's dance pad, Marble's speaker.
	battle.stage?.set_singer_prop(singer, cast["prop"])
	singer.fnf_set_corruption(cast["level"] || 0, cast["eyes"], cast["peak"])
	// Only the song's own characters grow wings; a player stays as they are.
	if(singer == battle.npc || singer == battle.stage?.girlfriend)
		fnf_set_wings(singer, cast["wings"])
	if(cast["flying"])
		ADD_TRAIT(singer, TRAIT_MOVE_FLOATING, FNF_BATTLE_TRAIT)
	else
		REMOVE_TRAIT(singer, TRAIT_MOVE_FLOATING, FNF_BATTLE_TRAIT)

/// Gives a summoned singer wings for the song ("angel", "demon"), or takes them away.
/proc/fnf_set_wings(mob/living/carbon/singer, wings)
	var/obj/item/organ/wings/current = singer.get_organ_slot(ORGAN_SLOT_EXTERNAL_WINGS)
	var/wanted_type = wings == "angel" ? /obj/item/organ/wings/functional/angel : (wings == "demon" ? /obj/item/organ/wings/functional/dragon : null)
	if(current && (!wanted_type || current.type != wanted_type))
		// Only wings the song gave: a singer's own stay.
		if(!HAS_TRAIT_FROM(current, TRAIT_NODROP, FNF_BATTLE_TRAIT))
			return
		current.Remove(singer)
		qdel(current)
		current = null
	if(wanted_type && !current)
		var/obj/item/organ/wings/given = new wanted_type
		ADD_TRAIT(given, TRAIT_NODROP, FNF_BATTLE_TRAIT)
		given.Insert(singer, special = TRUE)
