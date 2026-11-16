/**
 * # The climb, seen from aboard
 *
 * Starts the moment the hull leaves its berth for transit (L), over a picture of the ground it just stood on,
 * so nothing outside changes as it goes. Then, in step with what the people on the ground see of the ship
 * (a level lift, the nose coming up, off toward the bow):
 *
 * | from    | what                                                                                  |
 * |---------|---------------------------------------------------------------------------------------|
 * | L       | the ground falls away under the hull, dust blowing out from under it                  |
 * | L+1s    | the ground starts to slide off sternward as the ship gathers way, haze thickening     |
 * | L+3.3s  | into the cloud: everything white                                                      |
 * | L+3.9s  | out of its top: the deck of cloud drops away below, the sky darkens                   |
 * | L+4.8s  | the planet, whole, shrinking astern until it is lost among the stars                  |
 *
 * Made while the engines wind up, so the country around the berth is already drawn when the hull lifts; only
 * the ground the hull itself stood on has to wait for it to be gone. Deletes itself when it is done.
 */

#define ASCENT_LENGTH (9 SECONDS)
/// How long a view made ready for a takeoff waits for the hull to lift before it gives up
#define ASCENT_WAIT (40 SECONDS)

/// The view from aboard of this ship's climb out: made ready as its engines wind up, gone when the climb is over
/obj/structure/overmap/ship/var/datum/landing_view/ascent/launch_view

/datum/landing_view/ascent
	/// The ship climbing out, which holds us
	var/obj/structure/overmap/ship/ship
	/// world.time the hull left the ground; null while it is still on it
	var/liftoff
	/// The way the bow points, as a step on the ground picture and on the screen
	var/bow_dir = NORTH
	var/bow_x = 0
	var/bow_y = 0
	var/screen_bow_x = 0
	var/screen_bow_y = 0

/**
 * * hull_turfs - null while the hull is still on its berth; lift_off() is called when it leaves
 * * berth_turfs - the turfs it stands on, or stood on
 * * bow_dir - the way its bow points on the berth
 */
/datum/landing_view/ascent/New(obj/docking_port/mobile/shuttle, list/hull_turfs, list/berth_turfs, rotation, obj/structure/overmap/site, bow_dir = NORTH, obj/structure/overmap/ship/ship)
	. = ..()
	if(ended)
		return
	src.ship = ship
	src.bow_dir = bow_dir
	palette = landing_view_palette_for(site)
	bow_x = (bow_dir & EAST) ? 1 : ((bow_dir & WEST) ? -1 : 0)
	bow_y = (bow_dir & NORTH) ? 1 : ((bow_dir & SOUTH) ? -1 : 0)
	ground = add_picture()
	close = add_picture()
	shadow = add_picture()
	// all the country around the berth; the ground under the hull is drawn once the hull is off it
	bake_far(ground, CALLBACK(src, PROC_REF(country_drawn)))
	bake_near(close, detail_reach(), CALLBACK(src, PROC_REF(country_drawn)), LANDING_GROUND_AROUND)
	if(hull_turfs)
		lift_off(hull_turfs, berth_turfs, rotation)
	else
		addtimer(CALLBACK(src, PROC_REF(give_up)), ASCENT_WAIT, TIMER_DELETE_ME)

/datum/landing_view/ascent/Destroy(force)
	if(ship?.launch_view == src)
		ship.launch_view = null
	ship = null
	return ..()

/// The takeoff this was made ready for never came
/datum/landing_view/ascent/proc/give_up()
	if(!liftoff)
		qdel(src)

/// The country around the berth is drawn; if the hull has already lifted, the people aboard get it now
/datum/landing_view/ascent/proc/country_drawn()
	if(liftoff)
		show(ground, FALSE)
		show(close, FALSE)

/**
 * The hull has just left its berth for transit.
 * * hull_turfs - where it stands now
 * * planet_turfs - the berth turfs it left, in the same order
 * * rotation - clockwise degrees from its heading in transit to its heading on the berth
 */
/datum/landing_view/ascent/proc/lift_off(list/hull_turfs, list/planet_turfs, rotation)
	if(ended || liftoff)
		return
	if(!set_ground(planet_turfs) || !attach(hull_turfs, rotation))
		qdel(src)
		return
	liftoff = world.time
	var/screen_bow = rotation ? turn(bow_dir, rotation) : bow_dir
	screen_bow_x = (screen_bow & EAST) ? 1 : ((screen_bow & WEST) ? -1 : 0)
	screen_bow_y = (screen_bow & NORTH) ? 1 : ((screen_bow & SOUTH) ? -1 : 0)
	// the ground the hull stood on, bare now it has gone
	bake_near(close, detail_reach(), null, LANDING_GROUND_UNDER, TRUE)
	add_ground()
	add_clouds()
	add_planet()
	sync_viewers()
	cue('voidcrew/sound/effects/landing/launch.ogg', 60, 3 SECONDS, 0.06)
	// a hard reference: nothing else is sure to hold us for this long
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), src), ASCENT_LENGTH)

/// The ground it stood on, falling away and sliding off astern, and its shadow left behind on it
/datum/landing_view/ascent/proc/add_ground()
	// height gained under steady thrust, and way gathered once the nose is up: sampled, so the motion is smooth
	for(var/step in 0 to 21)
		var/seconds = step * 0.2
		var/when = liftoff + seconds * 10
		ground.scale.mark(when, 1 / (1 + (seconds / 2.3) ** 2.4))
		var/slid = seconds > 1 ? 2.2 * (seconds - 1) ** 2.2 : 0
		ground.slide_x.mark(when, bow_x * slid)
		ground.slide_y.mark(when, bow_y * slid)
	// gone once the sky has closed over it
	ground.alpha.mark(liftoff + 3.7 SECONDS, 255)
	ground.alpha.mark(liftoff + 3.8 SECONDS, 0)
	ground.drop_at = liftoff + 3.9 SECONDS
	chain_ground(ground, close)
	show(ground)
	show(close)

	shadow.parts = list(list(landing_view_shadow_look(berth_turfs, ground_x, ground_y), 0, 0, 1))
	shadow.scale.mark(liftoff, 1)
	shadow.scale.mark(liftoff + 1.2 SECONDS, 1.2, LANDING_CURVE_BOTH)
	shadow.scale_with = ground.scale
	shadow.slide_x = ground.slide_x
	shadow.slide_y = ground.slide_y
	shadow.alpha.mark(liftoff, 0)
	shadow.alpha.mark(liftoff + 0.3 SECONDS, 90)
	shadow.alpha.mark(liftoff + 1.2 SECONDS, 70)
	shadow.alpha.mark(liftoff + 2.4 SECONDS, 0)
	show(shadow)

	var/datum/landing_view_piece/haze = add_sky(LANDING_VIEW_LAYER_HAZE, fill = palette.sky)
	haze.alpha.mark(liftoff + 0.8 SECONDS, 0)
	haze.alpha.mark(liftoff + 2.4 SECONDS, 110)
	haze.alpha.mark(liftoff + 3.4 SECONDS, 235)
	haze.alpha.mark(liftoff + 3.8 SECONDS, 235)
	haze.alpha.mark(liftoff + 3.9 SECONDS, 0)
	show(haze)

/// Through the cloud and out of its top, the deck dropping away below
/datum/landing_view/ascent/proc/add_clouds()
	var/datum/landing_view_piece/sky = add_sky(LANDING_VIEW_LAYER_SKY, fill = palette.sky)
	sky.alpha.mark(liftoff + 2.8 SECONDS, 0)
	sky.alpha.mark(liftoff + 3.6 SECONDS, 255, LANDING_CURVE_BOTH)
	sky.alpha.mark(liftoff + 5.2 SECONDS, 255)
	sky.alpha.mark(liftoff + 6.8 SECONDS, 0, LANDING_CURVE_BOTH)
	show(sky)

	var/datum/landing_view_piece/inside = add_sky(LANDING_VIEW_LAYER_CLOUD + 1, fill = palette.cloud)
	inside.alpha.mark(liftoff + 3.3 SECONDS, 0)
	inside.alpha.mark(liftoff + 3.8 SECONDS, 250, LANDING_CURVE_IN)
	inside.alpha.mark(liftoff + 4.1 SECONDS, 250)
	inside.alpha.mark(liftoff + 4.8 SECONDS, 0, LANDING_CURVE_OUT)
	show(inside)

	var/list/datum/landing_view_piece/deck = new_clouds()
	var/datum/landing_track/size = deck[1].scale
	size.mark(liftoff + 3.9 SECONDS, 11)
	size.mark(liftoff + 6.8 SECONDS, 1.8, LANDING_CURVE_OUT)
	deck[1].slide_x.mark(liftoff + 3.9 SECONDS, 0)
	deck[1].slide_x.mark(liftoff + 6.8 SECONDS, screen_bow_x * 300)
	deck[1].slide_y.mark(liftoff + 3.9 SECONDS, 0)
	deck[1].slide_y.mark(liftoff + 6.8 SECONDS, screen_bow_y * 300)
	var/datum/landing_track/opacity = new
	opacity.mark(liftoff + 3.9 SECONDS, 0)
	opacity.mark(liftoff + 4.3 SECONDS, 235)
	opacity.mark(liftoff + 5.6 SECONDS, 235)
	opacity.mark(liftoff + 6.8 SECONDS, 0)
	chain_detail(deck, size, opacity, LANDING_CLOUD_DETAIL)

/// The planet whole, shrinking astern
/datum/landing_view/ascent/proc/add_planet()
	var/list/planet = new_planet()
	var/list/grains = planet[1]
	var/datum/landing_view_piece/whole = grains[1][1]
	var/datum/landing_track/size = whole.scale
	size.mark(liftoff + 4.6 SECONDS, 6.4)
	size.mark(liftoff + 8.6 SECONDS, 0.7, LANDING_CURVE_OUT)
	whole.slide_x.mark(liftoff + 4.6 SECONDS, 0)
	whole.slide_x.mark(liftoff + 8.6 SECONDS, screen_bow_x * 240)
	whole.slide_y.mark(liftoff + 4.6 SECONDS, 0)
	whole.slide_y.mark(liftoff + 8.6 SECONDS, screen_bow_y * 240)
	var/datum/landing_track/opacity = new
	opacity.mark(liftoff + 4.8 SECONDS, 0)
	opacity.mark(liftoff + 5.8 SECONDS, 255)
	opacity.mark(liftoff + 7.6 SECONDS, 255)
	opacity.mark(liftoff + 8.8 SECONDS, 0)
	chain_detail(grains, size, opacity, LANDING_PLANET_DETAIL)
	var/datum/landing_view_piece/shade = planet[2]
	shade.alpha = opacity
	show(shade)

	var/datum/landing_view_piece/air = new_air(whole)
	air.alpha.mark(liftoff + 5 SECONDS, 0)
	air.alpha.mark(liftoff + 6 SECONDS, 235)
	air.alpha.mark(liftoff + 7.6 SECONDS, 235)
	air.alpha.mark(liftoff + 8.8 SECONDS, 0)
	show(air)

#undef ASCENT_LENGTH
#undef ASCENT_WAIT
