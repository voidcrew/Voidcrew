/**
 * # Colosseum Capture the Flag
 *
 * Team mode: each team's banner stands on its plinth (arena west = red,
 * east = blue). Carry the enemy banner onto your own plinth to capture; first
 * team to CTF_CAPS_TO_WIN captures wins. Flags imitate the tg CTF banner's
 * carry mechanics (heavy, slowing, undestroyable, auto-returns when left on
 * the ground) but are wired to the colosseum controller instead of the
 * station CTF controller, that system is inseparable from its own team/
 * faction machinery.
 */

/// Captures needed to win a colosseum CTF match.
#define CTF_CAPS_TO_WIN 2
/// Seconds a dropped banner lies on the sand before returning to its plinth.
#define CTF_FLAG_RESET_TIME (15 SECONDS)

/obj/item/colosseum_flag
	name = "war banner"
	desc = "A ceremonial war banner. It goes wherever its bearer does, slowly."
	icon = 'icons/obj/banner.dmi'
	icon_state = "banner"
	inhand_icon_state = "banner"
	lefthand_file = 'icons/mob/inhands/equipment/banners_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/banners_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	slowdown = 2
	throw_speed = 0
	throw_range = 1
	force = 5
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	anchored = TRUE
	item_flags = SLOWS_WHILE_IN_HAND
	/// Which team owns this banner (COLOSSEUM_TEAM_RED/BLUE)
	var/team = COLOSSEUM_TEAM_RED
	/// The CTF game running this banner
	var/datum/colosseum_game/capture_the_flag/game
	/// The plinth turf this banner returns to
	var/turf/home_turf
	/// world.time after which a grounded banner returns home
	var/reset_after = 0

/obj/item/colosseum_flag/Destroy()
	STOP_PROCESSING(SSobj, src)
	game = null
	home_turf = null
	return ..()

/obj/item/colosseum_flag/examine(mob/user)
	. = ..()
	. += span_notice("Carry the enemy's banner to your own plinth to capture it. Touch your own grounded banner to send it home.")

/// Contestants of the opposing team may take it; own team touching it afield returns it.
/obj/item/colosseum_flag/attack_hand(mob/living/user, list/modifiers)
	if(!game?.controller || game.controller.state != COLOSSEUM_STATE_LIVE)
		to_chat(user, span_warning("There's no match running - the banner is just decoration."))
		return
	var/datum/colosseum_contestant/entry = game.controller.entry_for_body(user)
	if(!entry || entry.eliminated)
		to_chat(user, span_warning("Only contestants may handle the war banners!"))
		return
	if(entry.team == team)
		if(get_turf(src) != home_turf && !ismob(loc))
			return_home()
			user.visible_message(span_notice("[user] sends [src] back to its plinth."))
		else
			to_chat(user, span_warning("You can't move your own banner!"))
		return
	// Enemy contestant: the anchored dance mirrors tg's flag, anchored blocks
	// pickup, so it drops only for the actual grab attempt.
	STOP_PROCESSING(SSobj, src)
	anchored = FALSE
	. = ..()
	if(.)
		anchored = TRUE
		return
	anchored = TRUE // held: anchored again so it can't be bagged or thrown

/obj/item/colosseum_flag/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(!(slot & ITEM_SLOT_HANDS))
		return
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_carrier_moved))
	game?.on_flag_taken(src, user)

/obj/item/colosseum_flag/dropped(mob/user, silent = FALSE)
	. = ..()
	UnregisterSignal(user, COMSIG_MOVABLE_MOVED)
	anchored = TRUE
	reset_after = world.time + CTF_FLAG_RESET_TIME
	START_PROCESSING(SSobj, src)
	game?.on_flag_dropped(src, user)

/// Left lying on the sand too long: walk itself home.
/obj/item/colosseum_flag/process()
	if(ismob(loc))
		return PROCESS_KILL
	if(world.time >= reset_after)
		return_home()
		game?.announce("\The [src] returns to its plinth.")
		return PROCESS_KILL

/obj/item/colosseum_flag/proc/return_home()
	STOP_PROCESSING(SSobj, src)
	if(home_turf)
		forceMove(home_turf)
	anchored = TRUE

/// Capture check: fires on every step the carrier takes.
/obj/item/colosseum_flag/proc/on_carrier_moved(mob/living/carrier)
	SIGNAL_HANDLER
	game?.check_capture(src, carrier)

/obj/item/colosseum_flag/red
	name = "red war banner"
	icon_state = "banner-red"
	inhand_icon_state = "banner-red"
	team = COLOSSEUM_TEAM_RED

/obj/item/colosseum_flag/blue
	name = "blue war banner"
	icon_state = "banner-blue"
	inhand_icon_state = "banner-blue"
	team = COLOSSEUM_TEAM_BLUE

// ===== THE MODE =====

/datum/colosseum_game/capture_the_flag
	name = "Capture the Flag"
	desc = "Steal the enemy banner and carry it home. First to two captures."
	min_players = 4
	max_players = 16
	weight = 8
	team_based = TRUE
	time_limit = 12 MINUTES
	/// Captures per team (team id -> count)
	var/list/captures = list()
	/// The two live banners
	var/obj/item/colosseum_flag/red_flag
	var/obj/item/colosseum_flag/blue_flag
	/// Plinth turfs per team (team id -> list of turfs)
	var/list/plinths = list()

/datum/colosseum_game/capture_the_flag/Destroy()
	QDEL_NULL(red_flag)
	QDEL_NULL(blue_flag)
	return ..()

/// Venue-wide announcement helper for banner events.
/datum/colosseum_game/capture_the_flag/proc/announce(message)
	controller?.site?.venue_message(span_boldannounce(message))

/datum/colosseum_game/capture_the_flag/on_match_start()
	captures = list()
	// West plinth = red, east = blue, per DESIGN.md; landmark-first with
	// coordinate fallbacks so a re-mapped plinth can't strand the banners.
	plinths[COLOSSEUM_TEAM_RED] = get_spots(/obj/effect/landmark/colosseum/flag_red, list(list(20, 32), list(20, 33)))
	plinths[COLOSSEUM_TEAM_BLUE] = get_spots(/obj/effect/landmark/colosseum/flag_blue, list(list(43, 32), list(43, 33)))
	var/list/red_spots = plinths[COLOSSEUM_TEAM_RED]
	var/list/blue_spots = plinths[COLOSSEUM_TEAM_BLUE]
	if(!length(red_spots) || !length(blue_spots))
		return // resolved turfs missing entirely: degrade to plain TDM rules
	red_flag = new /obj/item/colosseum_flag/red(red_spots[1])
	red_flag.game = src
	red_flag.home_turf = red_spots[1]
	blue_flag = new /obj/item/colosseum_flag/blue(blue_spots[1])
	blue_flag.game = src
	blue_flag.home_turf = blue_spots[1]
	announce("The war banners are placed. Steal the enemy's, keep your own!")

/datum/colosseum_game/capture_the_flag/on_match_end()
	QDEL_NULL(red_flag)
	QDEL_NULL(blue_flag)

/datum/colosseum_game/capture_the_flag/proc/on_flag_taken(obj/item/colosseum_flag/flag, mob/living/carrier)
	announce("[carrier.real_name] has taken \the [flag]!")

/datum/colosseum_game/capture_the_flag/proc/on_flag_dropped(obj/item/colosseum_flag/flag, mob/living/carrier)
	if(controller?.state == COLOSSEUM_STATE_LIVE)
		announce("\The [flag] has been dropped!")

/// A carrier stepped somewhere: capture if they're on their own plinth with the enemy banner.
/datum/colosseum_game/capture_the_flag/proc/check_capture(obj/item/colosseum_flag/flag, mob/living/carrier)
	if(controller?.state != COLOSSEUM_STATE_LIVE)
		return
	var/datum/colosseum_contestant/entry = controller.entry_for_body(carrier)
	if(!entry || entry.eliminated || entry.team == flag.team)
		return
	var/list/home_plinth = plinths[entry.team]
	if(!length(home_plinth) || !(get_turf(carrier) in home_plinth))
		return
	captures[entry.team] = (captures[entry.team] || 0) + 1
	carrier.dropItemToGround(flag, force = TRUE)
	flag.return_home()
	announce("CAPTURE! [carrier.real_name] scores for team [entry.team], [captures[entry.team]]/[CTF_CAPS_TO_WIN]!")
	if(captures[entry.team] >= CTF_CAPS_TO_WIN)
		controller.resolve(live_team_minds(entry.team))

/// Clock expiry: most captures wins; equal captures is a draw.
/datum/colosseum_game/capture_the_flag/expiry_winners()
	var/red_caps = captures[COLOSSEUM_TEAM_RED] || 0
	var/blue_caps = captures[COLOSSEUM_TEAM_BLUE] || 0
	if(red_caps == blue_caps)
		return list()
	return live_team_minds(red_caps > blue_caps ? COLOSSEUM_TEAM_RED : COLOSSEUM_TEAM_BLUE)

#undef CTF_CAPS_TO_WIN
#undef CTF_FLAG_RESET_TIME
