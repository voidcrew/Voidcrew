/**
 * # The descent, seen from aboard
 *
 * Laid out against the moment the hull is expected to touch down (T), in the order a falling ship meets things:
 *
 * | from     | what                                                                                    |
 * |----------|-----------------------------------------------------------------------------------------|
 * | start    | the planet, whole, swelling under the ship until its rim has left the screen            |
 * | T-9.2s   | heat: the hull's edge glows and sheds sparks, streaks fly out past it                    |
 * | T-8.4s   | the planet thins into the colour of its own sky                                          |
 * | T-7.4s   | a deck of cloud comes up from below, then the ship is in it: everything white           |
 * | T-5.2s   | out of the cloud's underside over the real ground, small and hazy, rushing up            |
 * | T-1.4s   | the thrusters reach the ground: dust blows out from under the hull                       |
 * | T-0.3s   | the ground is at full size; the ship hangs on its thrusters until the hull really moves |
 *
 * The ground is the real terrain around the berth, so when the hull moves onto it nothing outside changes.
 */

/// Size of the ground when it comes out of the cloud
#define DESCENT_GROUND_START 0.3
/// How far past the hull's box the ground picture reaches, and how far things on it are drawn
#define DESCENT_GROUND_REACH 44
#define DESCENT_GROUND_DETAIL 16

/// The view from aboard, for the length of this descent
/datum/landing_animation/var/datum/landing_view/descent/inside_view

/datum/landing_view/descent
	/// world.time the hull is expected to move
	var/touchdown

/datum/landing_view/descent/New(obj/docking_port/mobile/shuttle, list/hull_turfs, list/berth_turfs, rotation, obj/structure/overmap/site, touchdown)
	. = ..()
	if(ended)
		return
	src.touchdown = touchdown
	palette = landing_view_palette_for(site)
	add_planet()
	add_heat()
	add_clouds()
	add_ground()
	sync_viewers()
	cue_at(touchdown - 9.2 SECONDS, 'voidcrew/sound/effects/landing/entry.ogg', 55, 3.6 SECONDS, 0.08)
	cue_at(touchdown - 6.6 SECONDS, 'voidcrew/sound/effects/landing/clouds.ogg', 45, 1.4 SECONDS, 0.05)
	cue_at(touchdown - 4.6 SECONDS, 'voidcrew/sound/effects/landing/thrusters.ogg', 50)

/// The planet whole, growing under the ship, then thinning into its own sky
/datum/landing_view/descent/proc/add_planet()
	var/now = world.time
	var/list/datum/landing_view_piece/planet = new_planet()
	var/datum/landing_track/size = planet[1].scale
	size.mark(now, 0.3)
	size.mark(touchdown - 6.2 SECONDS, 6.4, LANDING_CURVE_IN)
	var/datum/landing_track/opacity = new
	opacity.mark(now, 0)
	opacity.mark(now + 0.6 SECONDS, 255)
	opacity.mark(touchdown - 7.6 SECONDS, 255)
	opacity.mark(touchdown - 6.2 SECONDS, 0)
	chain_detail(planet, size, opacity, LANDING_PLANET_DETAIL)

	var/datum/landing_view_piece/air = new_air(planet[1])
	air.alpha.mark(now, 0)
	air.alpha.mark(now + 0.6 SECONDS, 235)
	air.alpha.mark(touchdown - 8 SECONDS, 235)
	air.alpha.mark(touchdown - 6.6 SECONDS, 0)
	show(air)

	// inside its air: the sky's own colour over everything, until the ground shows under it
	var/datum/landing_view_piece/sky = add_sky(LANDING_VIEW_LAYER_SKY, fill = palette.sky)
	sky.alpha.mark(touchdown - 8.4 SECONDS, 0)
	sky.alpha.mark(touchdown - 6.2 SECONDS, 255, LANDING_CURVE_BOTH)
	sky.alpha.mark(touchdown - 5.2 SECONDS, 255)
	sky.alpha.mark(touchdown - 4.4 SECONDS, 0)
	show(sky)

/// Heat of entry: streaks flying out past the hull, and the hull's edge glowing
/datum/landing_view/descent/proc/add_heat()
	for(var/turned in list(0, 137))
		var/datum/landing_view_piece/streaks = add_sky(LANDING_VIEW_LAYER_HEAT + 1, LANDING_VIEW_ICON, "streaks", LANDING_VIEW_ICON_SIZE)
		streaks.sky.color = palette.heat
		streaks.turn = turned
		// they fly outward: each sheet grows, and the second follows the first so there is always one coming
		var/lead = turned ? 0.9 SECONDS : 0
		streaks.scale.mark(touchdown - 9.2 SECONDS + lead, 1.5)
		streaks.scale.mark(touchdown - 5.6 SECONDS + lead, 3.4)
		streaks.alpha.mark(touchdown - 9.2 SECONDS + lead, 0)
		streaks.alpha.mark(touchdown - 8.4 SECONDS + lead, 190)
		streaks.alpha.mark(touchdown - 6.6 SECONDS, 190)
		streaks.alpha.mark(touchdown - 5.6 SECONDS, 0)
		show(streaks)
	heat_hull(touchdown - 9.2 SECONDS, touchdown - 5.6 SECONDS)

/// A deck of cloud coming up from below, the white of being inside it, and the last of it rushing past
/datum/landing_view/descent/proc/add_clouds()
	// always bigger than the screen: small and sharp far below, huge as the ship reaches it
	var/list/datum/landing_view_piece/deck = new_clouds()
	var/datum/landing_track/size = deck[1].scale
	size.mark(touchdown - 7.4 SECONDS, 1.8)
	size.mark(touchdown - 4.6 SECONDS, 11, LANDING_CURVE_IN)
	var/datum/landing_track/opacity = new
	opacity.mark(touchdown - 7.4 SECONDS, 0)
	opacity.mark(touchdown - 6.4 SECONDS, 235)
	opacity.mark(touchdown - 5 SECONDS, 235)
	opacity.mark(touchdown - 4.4 SECONDS, 0)
	chain_detail(deck, size, opacity, LANDING_CLOUD_DETAIL)

	var/datum/landing_view_piece/inside = add_sky(LANDING_VIEW_LAYER_CLOUD + 1, fill = palette.cloud)
	inside.alpha.mark(touchdown - 5.8 SECONDS, 0)
	inside.alpha.mark(touchdown - 5 SECONDS, 250, LANDING_CURVE_IN)
	inside.alpha.mark(touchdown - 4.6 SECONDS, 250)
	inside.alpha.mark(touchdown - 3.8 SECONDS, 0, LANDING_CURVE_OUT)
	show(inside)

	// the underside of the deck, torn into wisps, flying up and out past the ship
	var/datum/landing_view_piece/wisps = add_sky(LANDING_VIEW_LAYER_CLOUD + 0.5, LANDING_VIEW_ICON, "wisps", LANDING_VIEW_ICON_SIZE)
	wisps.sky.color = palette.cloud
	wisps.scale.mark(touchdown - 4.8 SECONDS, 1.8)
	wisps.scale.mark(touchdown - 3 SECONDS, 5, LANDING_CURVE_IN)
	wisps.alpha.mark(touchdown - 4.8 SECONDS, 0)
	wisps.alpha.mark(touchdown - 4.4 SECONDS, 210)
	wisps.alpha.mark(touchdown - 3 SECONDS, 0)
	show(wisps)

	// haze between the ship and the ground, clearing as it comes down
	var/datum/landing_view_piece/haze = add_sky(LANDING_VIEW_LAYER_HAZE, fill = palette.sky)
	haze.alpha.mark(touchdown - 5.2 SECONDS, 0)
	haze.alpha.mark(touchdown - 5 SECONDS, 170)
	haze.alpha.mark(touchdown - 1.2 SECONDS, 0)
	show(haze)

/// The real ground, rushing up to full size, and the hull's shadow tightening on it
/datum/landing_view/descent/proc/add_ground()
	ground = add_picture()
	ground.scale.mark(touchdown - 5.2 SECONDS, DESCENT_GROUND_START)
	ground.scale.mark(touchdown - 0.3 SECONDS, 1, LANDING_CURVE_OUT)
	// under the sky until the sky has covered everything
	ground.alpha.mark(touchdown - 5.4 SECONDS, 0)
	ground.alpha.mark(touchdown - 5.3 SECONDS, 255)
	bake_ground(ground, DESCENT_GROUND_REACH, DESCENT_GROUND_DETAIL, palette.sky, CALLBACK(src, PROC_REF(show), ground))

	// the same shadow the people on the ground see spreading over the berth (see /datum/landing_animation)
	shadow = add_picture()
	shadow.parts = list(list(landing_view_shadow_look(berth_turfs, ground_x, ground_y), 0, 0, 1))
	shadow.scale.mark(touchdown - 3 SECONDS, 1.35)
	shadow.scale.mark(touchdown - 1 SECONDS, 1.15, LANDING_CURVE_BOTH)
	shadow.scale.mark(touchdown, 1, LANDING_CURVE_OUT)
	shadow.scale_with = ground.scale
	shadow.alpha.mark(touchdown - 5 SECONDS, 0)
	shadow.alpha.mark(touchdown - 4.4 SECONDS, 56)
	shadow.alpha.mark(touchdown - 3 SECONDS, 56)
	shadow.alpha.mark(touchdown - 1 SECONDS, 80, LANDING_CURVE_BOTH)
	shadow.alpha.mark(touchdown, 100, LANDING_CURVE_OUT)
	show(shadow)

/// The hull has started to move onto the berth
/datum/landing_view/descent/proc/touchdown()
	return

/// The hull is down: the people aboard are looking at the real ground now
/datum/landing_view/descent/proc/landed()
	qdel(src)

#undef DESCENT_GROUND_START
#undef DESCENT_GROUND_REACH
#undef DESCENT_GROUND_DETAIL
