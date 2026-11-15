// Gun feel: a directional recoil kick, a muzzle flash and flying casings for every gun.
// The firing feel is modelled on Shiptest (shiptest-ss13/Shiptest), whose code is AGPL-3.0 like ours.
//
// Hooks, all chained onto the upstream procs (this file loads after code/, so these run first and call ..()):
// - shoot_live_shot(): kick the shooter's camera and show the muzzle flash, once per shot.
// The upstream random camera shake in shoot_live_shot() is removed (marked VOIDCREW EDIT in gun.dm).

/obj/item/gun
	/// Camera kick in tiles. Null picks a default from gun_feel_class.
	var/recoil_kick
	/// GUN_FEEL_CLASS_*. Null until first needed; a subtype may preset it.
	var/gun_feel_class
	/// TRUE once gun_feel_resolve() has filled in the values above.
	var/gun_feel_resolved = FALSE
	/// The short-lived light from the last muzzle flash.
	var/obj/effect/dummy/lighting_obj/moblight/gun_feel_light

/obj/item/gun/Destroy()
	gun_feel_clear_light()
	return ..()

/// Picks this gun's class and fills in any feel values its type left unset.
/obj/item/gun/proc/gun_feel_resolve()
	if(gun_feel_resolved)
		return
	gun_feel_resolved = TRUE
	if(isnull(gun_feel_class))
		gun_feel_class = gun_feel_pick_class()
	var/kick = 0
	switch(gun_feel_class)
		if(GUN_FEEL_CLASS_PISTOL)
			kick = GUN_FEEL_KICK_PISTOL
		if(GUN_FEEL_CLASS_REVOLVER)
			kick = GUN_FEEL_KICK_REVOLVER
		if(GUN_FEEL_CLASS_SMG)
			kick = GUN_FEEL_KICK_SMG
		if(GUN_FEEL_CLASS_RIFLE)
			kick = GUN_FEEL_KICK_RIFLE
		if(GUN_FEEL_CLASS_SHOTGUN)
			kick = GUN_FEEL_KICK_SHOTGUN
		if(GUN_FEEL_CLASS_MARKSMAN)
			kick = GUN_FEEL_KICK_MARKSMAN
		if(GUN_FEEL_CLASS_HEAVY)
			kick = GUN_FEEL_KICK_HEAVY
		if(GUN_FEEL_CLASS_LAUNCHER)
			kick = GUN_FEEL_KICK_LAUNCHER
	if(isnull(recoil_kick))
		recoil_kick = kick

/// Works out what kind of gun this is from its type, weight and size.
/obj/item/gun/proc/gun_feel_pick_class()
	var/long_frame = weapon_weight >= WEAPON_MEDIUM || w_class >= WEIGHT_CLASS_BULKY
	if(istype(src, /obj/item/gun/energy))
		return long_frame ? GUN_FEEL_CLASS_ENERGY_LONG : GUN_FEEL_CLASS_ENERGY
	if(!istype(src, /obj/item/gun/ballistic) || istype(src, /obj/item/gun/ballistic/bow))
		return GUN_FEEL_CLASS_NONE
	if(istype(src, /obj/item/gun/ballistic/rocketlauncher) || istype(src, /obj/item/gun/ballistic/revolver/grenadelauncher))
		return GUN_FEEL_CLASS_LAUNCHER
	if(istype(src, /obj/item/gun/ballistic/shotgun))
		return GUN_FEEL_CLASS_SHOTGUN
	if(istype(src, /obj/item/gun/ballistic/rifle))
		return GUN_FEEL_CLASS_MARKSMAN
	if(istype(src, /obj/item/gun/ballistic/revolver))
		return GUN_FEEL_CLASS_REVOLVER
	if(istype(src, /obj/item/gun/ballistic/automatic/pistol))
		return GUN_FEEL_CLASS_PISTOL
	if(istype(src, /obj/item/gun/ballistic/automatic))
		if(weapon_weight >= WEAPON_HEAVY && w_class >= WEIGHT_CLASS_HUGE)
			return GUN_FEEL_CLASS_HEAVY
		if(long_frame)
			return GUN_FEEL_CLASS_RIFLE
		return GUN_FEEL_CLASS_SMG
	return long_frame ? GUN_FEEL_CLASS_RIFLE : GUN_FEEL_CLASS_PISTOL

// Classes and values for guns the type rules above would get wrong.
/obj/item/gun/ballistic/automatic/toy
	gun_feel_class = GUN_FEEL_CLASS_NONE

/obj/item/gun/ballistic/automatic/pistol/toy
	gun_feel_class = GUN_FEEL_CLASS_NONE

/obj/item/gun/ballistic/shotgun/toy
	gun_feel_class = GUN_FEEL_CLASS_NONE

/// Fires laser casings from a magazine; it should handle like a laser rifle, not a powder rifle.
/obj/item/gun/ballistic/automatic/laser
	gun_feel_class = GUN_FEEL_CLASS_ENERGY_LONG

/// A crossbow, not a rifle.
/obj/item/gun/ballistic/rifle/rebarxbow
	recoil_kick = 0.06

// ---- Per shot ----

/obj/item/gun/shoot_live_shot(mob/living/user, pointblank = FALSE, atom/pbtarget = null, message = TRUE)
	. = ..()
	gun_feel_on_shot(user, pbtarget)

/// Kick and flash for one shot that just left the barrel.
/obj/item/gun/proc/gun_feel_on_shot(mob/living/user, atom/target)
	if(!isliving(user) || QDELETED(src) || tk_firing(user))
		return
	gun_feel_resolve()
	var/angle = gun_feel_fire_angle(user, target)
	gun_feel_kick(user, angle)
	if(gun_feel_wants_flash())
		gun_feel_muzzle_flash(user, angle)

/// Direction of the shot in degrees clockwise from north.
/obj/item/gun/proc/gun_feel_fire_angle(mob/living/user, atom/target)
	var/turf/shooter_turf = get_turf(user)
	var/turf/target_turf = get_turf(target)
	if(shooter_turf && target_turf && shooter_turf != target_turf)
		return get_angle(shooter_turf, target_turf)
	var/facing = dir2angle(user.dir)
	return isnull(facing) ? 0 : facing

/obj/item/gun/proc/gun_feel_kick(mob/living/user, angle)
	if(!user.client)
		return
	var/strength = min(recoil_kick + max(recoil, 0) * GUN_FEEL_LEGACY_RECOIL_KICK, GUN_FEEL_MAX_KICK)
	if(strength <= 0)
		return
	var/kick_angle = angle + 180 + (rand() * 2 - 1) * GUN_FEEL_RECOIL_DEVIATION
	gun_feel_recoil_camera(user, strength + 1, strength * 2 + 1, strength, kick_angle)

/**
 * Jolts a mob's camera a short way along `angle` and lets it spring back.
 *
 * After Shiptest's recoil_camera(). It runs as a named, parallel animation sequence that only adds
 * a temporary offset on top of whatever else animates the client (explosion shakes, choking), and
 * every value it writes ends at the client's current resting pixel offset, so it never shifts the
 * view for good. A newer kick replaces the last one instead of stacking on it.
 *
 * Arguments:
 * * recoiler - the mob whose camera kicks
 * * duration - deciseconds to reach the full kick
 * * backtime - deciseconds to settle back
 * * strength - distance in tiles
 * * angle - direction of the kick in degrees clockwise from north
 */
/proc/gun_feel_recoil_camera(mob/recoiler, duration, backtime, strength, angle)
	var/client/viewer = recoiler?.client
	if(!viewer)
		return
	// Players who asked for screen shake to be toned down get no kick at all.
	if(viewer.prefs?.read_preference(/datum/preference/toggle/screen_shake_darken))
		return
	// A scope re-aims the camera every tick and would cut the kick off anyway.
	if(HAS_TRAIT(recoiler, TRAIT_USER_SCOPED))
		return
	var/kick_x = round(sin(angle) * strength * ICON_SIZE_X, 1)
	var/kick_y = round(cos(angle) * strength * ICON_SIZE_Y, 1)
	if(!kick_x && !kick_y)
		return
	var/rest_x = viewer.pixel_x
	var/rest_y = viewer.pixel_y
	animate(viewer, pixel_x = rest_x + kick_x, pixel_y = rest_y + kick_y, time = duration, easing = CUBIC_EASING | EASE_OUT, tag = GUN_FEEL_RECOIL_ANIM_TAG)
	animate(pixel_x = rest_x, pixel_y = rest_y, time = backtime, easing = BACK_EASING | EASE_OUT)
