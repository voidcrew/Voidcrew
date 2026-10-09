/**
 * I Like Trains (asdfmovie): they're stood in a row with two kids, in the sketch's white, on a tram
 * track. "I like singing!" "I like dancing!" Then it's their turn, and it waits for them to say it
 * (or says it for them after a while). When they do, the tram comes through and takes all three.
 * The room goes shortly after.
 *
 * In trains.dmm the track runs along y 7 to 11; they stand in the middle of it, on y 9, the kids at
 * x 12 and 13 and them at 14. The tram's tramstation's own car (tram.dmm), loaded somewhere out of
 * the way and copied onto one thing that slides through.
 */
/datum/smite/i_like_trains
	name = "I Like Trains"

/datum/smite/i_like_trains/effect(client/user, mob/living/target)
	. = ..()
	var/mob/living/carbon/human/victim = target
	if(!istype(victim) || victim.current_gag)
		to_chat(user, span_warning("This must be used on a human who isn't in the middle of another gag."), confidential = TRUE)
		return
	new /datum/gag/trains(victim)

/// How long into trains.ogg the tram hits (measured off the clip).
#define TRAINS_HIT (1.55 SECONDS)
/// How long the tram takes to cross the room, and how far into that its front reaches them.
#define TRAINS_CROSSING 10
#define TRAINS_REACH (TRAINS_CROSSING * 12 / 38)
/// How long they're given to say it.
#define TRAINS_PATIENCE (30 SECONDS)

/datum/gag/trains
	var/list/mob/living/carbon/human/kids = list()
	var/datum/turf_reservation/tram_room
	var/obj/effect/abstract/gag_tram/tram
	/// Whether they've said it.
	var/said = FALSE

/// The tram going by: how the car looks where it's loaded, a tile at a time (one thing can only carry
/// so many overlays), all of them sliding together.
/obj/effect/abstract/gag_tram
	layer = ABOVE_MOB_LAYER
	appearance_flags = PIXEL_SCALE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/list/obj/effect/abstract/gag_tram/tiles = list()

/// Takes on the car's looks, laid out from this one tile as they are from the car's bottom left. Done
/// once it's had time to settle (its walls join up a little after it's loaded).
/obj/effect/abstract/gag_tram/proc/copy_car(datum/turf_reservation/car)
	var/turf/corner = car.bottom_left_turfs[1]
	for(var/turf/spot as anything in car.reserved_turfs)
		var/obj/effect/abstract/gag_tram/tile = new(null)
		tile.pixel_w = (spot.x - corner.x) * world.icon_size
		tile.pixel_z = (spot.y - corner.y) * world.icon_size
		// Not the floor under it all: the car's own floor covers it.
		var/list/parts = list()
		for(var/atom/movable/thing as anything in spot)
			parts += new /mutable_appearance(thing.appearance)
		tile.add_overlay(parts)
		tiles += tile
		vis_contents += tile

/obj/effect/abstract/gag_tram/Destroy()
	vis_contents.Cut()
	QDEL_LIST(tiles)
	return ..()

/datum/gag/trains/act()
	room = gag_load_room("trains.dmm")
	tram_room = gag_load_room("tram.dmm")
	if(!room || !tram_room)
		qdel(src)
		return
	came_from = get_turf(victim)
	victim.forceMove(gag_room_turf(room, 14, 9))
	victim.setDir(SOUTH)
	var/mob/living/carbon/human/singer = make_kid(12)
	var/mob/living/carbon/human/dancer = make_kid(13)
	GAG_AT(2 SECONDS)
	singer.say("I like singing!", forced = "i like trains")
	playsound(singer, 'voidcrew/modules/gags/sound/trains_singing.ogg', 80, FALSE)
	gag_pose(singer, list(RIG_HEAD = list("nod" = -15), RIG_L_ARM = list("raise" = 80, "swing" = 20), RIG_R_ARM = list("raise" = 80, "swing" = 20)), 3)
	GAG_AT(4 SECONDS)
	dancer.say("I like dancing!", forced = "i like trains")
	playsound(dancer, 'voidcrew/modules/gags/sound/trains_dancing.ogg', 80, FALSE)
	var/list/sway_left = list(RIG_CHEST = list("lean" = 12), RIG_L_ARM = list("raise" = 120), RIG_R_ARM = list("raise" = 30), RIG_L_LEG = list("swing" = 20))
	var/list/sway_right = list(RIG_CHEST = list("lean" = -12), RIG_L_ARM = list("raise" = 30), RIG_R_ARM = list("raise" = 120), RIG_R_LEG = list("swing" = 20))
	dancer.limb_rig?.play(list(list(sway_left, 3), list(sway_right, 3)), loop = -1, settle_after = FALSE)
	// Their turn, once the dancer's done.
	GAG_AT(6.5 SECONDS)
	to_chat(victim, span_notice("They're both looking at you. What do <i>you</i> like?"))
	RegisterSignal(victim, COMSIG_MOB_SAY, PROC_REF(on_say))
	while(!said && world.time < started + 6.5 SECONDS + TRAINS_PATIENCE)
		sleep(world.tick_lag)
		if(QDELETED(src))
			return
	if(!said)
		victim.say("I like trains.", forced = "i like trains")
	UnregisterSignal(victim, COMSIG_MOB_SAY)
	started = world.time
	playsound(victim, 'voidcrew/modules/gags/sound/trains.ogg', 90, FALSE)
	// From off the right of the room to off its left, front first.
	GAG_AT(TRAINS_HIT - TRAINS_REACH)
	// On their tile, so it's drawn while they can see it, wherever it's slid to.
	tram = new(gag_room_turf(room, 14, 7))
	tram.copy_car(tram_room)
	tram.pixel_w = (26 - 14) * 32
	animate(tram, pixel_w = (-12 - 14) * 32, time = TRAINS_CROSSING)
	// It takes them as it gets to them, a tile apart: the one who likes trains first. Their going
	// doesn't end this; the room's to be cleared up after.
	var/list/in_line = list(victim, dancer, singer)
	UnregisterSignal(victim, list(COMSIG_QDELETING, COMSIG_LIVING_SET_BODY_POSITION))
	victim.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), GAG_TRAIT)
	victim.current_gag = null
	victim = null
	for(var/tiles in 0 to 2)
		GAG_AT(TRAINS_HIT + tiles * TRAINS_CROSSING / 38)
		var/mob/living/carbon/human/hit = in_line[tiles + 1]
		if(!QDELETED(hit))
			hit.gib(DROP_ORGANS|DROP_BODYPARTS)
	GAG_AT(TRAINS_HIT + 4 SECONDS)
	qdel(src)

/datum/gag/trains/proc/make_kid(x)
	var/mob/living/carbon/human/kid = new(gag_room_turf(room, x, 9))
	kid.randomize_human_appearance(~RANDOMIZE_SPECIES)
	kid.fully_replace_character_name(kid.real_name, "Kid")
	kid.equip_to_slot_or_del(new /obj/item/clothing/under/color/random(kid), ITEM_SLOT_ICLOTHING)
	kid.setDir(SOUTH)
	kid.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), GAG_TRAIT)
	kids += kid
	return kid

/datum/gag/trains/proc/on_say(datum/source, list/speech_args)
	SIGNAL_HANDLER
	if(findtext(speech_args[SPEECH_MESSAGE], "train"))
		said = TRUE

/datum/gag/trains/Destroy()
	QDEL_NULL(tram)
	QDEL_LIST(kids)
	QDEL_NULL(tram_room)
	return ..()

#undef TRAINS_HIT
#undef TRAINS_CROSSING
#undef TRAINS_REACH
#undef TRAINS_PATIENCE
