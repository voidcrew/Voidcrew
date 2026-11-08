// Bullets: the long glowing streak sprite, an impact sound that matches what was hit, and a whizz and
// flinch for anyone a bullet passes close to. After Shiptest's bullet look, bullet_hit_sfx() and the
// near-miss check in its scan_moved_turf(). No ricochets: a bullet that hits something stops as before.

/obj/projectile/bullet
	// Shiptest's streak. tg ships the same "gauss" state in this icon file.
	icon_state = "gauss"
	// gun_feel_impact_sound() picks the hit sound from what was hit instead.
	// A round that sets its own hitsound (cannonball, sonic slug...) keeps it.
	hitsound = null
	hitsound_wall = null
	/// Mobs this bullet has already whizzed past, so it whizzes once per mob.
	var/list/gun_feel_whizzed

/// .50 rounds draw a thicker streak.
/obj/projectile/bullet/p50
	icon_state = "gaussstrong"

// A slug is one heavy round, not a pellet. Shiptest draws slugs as a streak too.
/obj/projectile/bullet/shotgun_slug
	icon_state = "gauss"

/obj/projectile/bullet/shotgun_slug/milspec
	icon_state = "gauss"

/obj/projectile/bullet/Destroy()
	gun_feel_whizzed = null
	return ..()

// ---- Impact sounds ----

/atom
	/// world.time until which a bullet hitting this makes no new impact sound (pellets hitting together).
	var/tmp/gun_feel_impact_quiet_until = 0

/obj/projectile/bullet/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(. != BULLET_ACT_BLOCK)
		gun_feel_impact_sound(target, blocked)

/// Plays the sound of this bullet hitting `target`: flesh, or the surface it is made of.
/obj/projectile/bullet/proc/gun_feel_impact_sound(atom/target, blocked = 0)
	if(hitsound || hitsound_wall || QDELETED(target))
		return
	if(world.time < target.gun_feel_impact_quiet_until)
		return
	var/surface = gun_feel_surface_of(target)
	// Fully stopped by armour: it rings off the plate.
	if(surface == GUN_FEEL_SURFACE_FLESH && blocked >= 100)
		surface = GUN_FEEL_SURFACE_METAL
	var/sound_key = GLOB.gun_feel_surface_sounds[surface]
	if(!sound_key)
		return
	target.gun_feel_impact_quiet_until = world.time + GUN_FEEL_IMPACT_SOUND_WINDOW
	var/volume
	if(suppressed)
		volume = GUN_FEEL_SUPPRESSED_HIT_VOLUME
	else if(surface == GUN_FEEL_SURFACE_FLESH)
		volume = GUN_FEEL_FLESH_HIT_VOLUME
	else
		// The same loudness upstream gave a bullet hitting a wall.
		volume = clamp(vol_by_damage() + 20, GUN_FEEL_SUPPRESSED_HIT_VOLUME, 100)
	playsound(src, sound_key, volume, TRUE, -1, frequency = GUN_FEEL_PITCH(GUN_FEEL_IMPACT_PITCH_SPREAD))

/// Surface name to sound effect key.
GLOBAL_LIST_INIT(gun_feel_surface_sounds, list(
	GUN_FEEL_SURFACE_FLESH = SFX_GUN_FEEL_BULLET_FLESH,
	GUN_FEEL_SURFACE_METAL = SFX_GUN_FEEL_HIT_METAL,
	GUN_FEEL_SURFACE_GLASS = SFX_GUN_FEEL_HIT_GLASS,
	GUN_FEEL_SURFACE_STONE = SFX_GUN_FEEL_HIT_STONE,
	GUN_FEEL_SURFACE_WOOD = SFX_GUN_FEEL_HIT_WOOD,
	GUN_FEEL_SURFACE_SNOW = SFX_GUN_FEEL_HIT_SNOW,
))

/// Types whose surface can't be read from their materials, by surface. Subtypes count too.
GLOBAL_LIST_INIT(gun_feel_surface_types, list(
	GUN_FEEL_SURFACE_GLASS = typecacheof(list(
		/obj/machinery/door/window,
		/obj/structure/displaycase,
		/obj/structure/table/glass,
		/obj/structure/window,
	)),
	GUN_FEEL_SURFACE_WOOD = typecacheof(list(
		/obj/structure/barricade/wooden,
		/obj/structure/bookcase,
		/obj/structure/chair/wood,
		/obj/structure/closet/crate/wooden,
		/obj/structure/dresser,
		/obj/structure/flora/tree,
		/obj/structure/table/wood,
	)),
	GUN_FEEL_SURFACE_STONE = typecacheof(list(
		/obj/structure/flora/rock,
		/obj/structure/statue,
		/turf/closed/indestructible/rock,
		/turf/closed/mineral,
		/turf/closed/wall/rock,
		/turf/open/misc,
	)),
	GUN_FEEL_SURFACE_SNOW = typecacheof(list(
		/obj/structure/barricade/sandbags,
		/turf/closed/wall/ice,
	)),
))

/// Surface by type, worked out once per type.
GLOBAL_LIST_EMPTY(gun_feel_surface_by_type)

/// What a bullet hitting `target` should sound like: one of the GUN_FEEL_SURFACE_* names.
/proc/gun_feel_surface_of(atom/target)
	if(isliving(target))
		var/mob/living/victim = target
		return (victim.mob_biotypes & MOB_ROBOTIC) ? GUN_FEEL_SURFACE_METAL : GUN_FEEL_SURFACE_FLESH
	// Materials vary per object (a table made of wood or of glass), so they are read every time.
	var/from_materials = gun_feel_surface_of_materials(target.custom_materials)
	if(from_materials)
		return from_materials
	var/surface = GLOB.gun_feel_surface_by_type[target.type]
	if(isnull(surface))
		surface = gun_feel_surface_of_type(target.type)
		GLOB.gun_feel_surface_by_type[target.type] = surface
	return surface

/// Surface for a type with no materials to go by.
/proc/gun_feel_surface_of_type(atom_type)
	// Snowy and icy rock looks like stone by type, so check its name first.
	if(ispath(atom_type, /turf/closed/mineral) || ispath(atom_type, /turf/closed/indestructible/rock) || ispath(atom_type, /turf/open/misc))
		var/type_name = "[atom_type]"
		if(findtext(type_name, "snow") || findtext(type_name, "/ice") || findtext(type_name, "glacial"))
			return GUN_FEEL_SURFACE_SNOW
	for(var/surface in GLOB.gun_feel_surface_types)
		var/list/types = GLOB.gun_feel_surface_types[surface]
		if(types[atom_type])
			return surface
	return GUN_FEEL_SURFACE_METAL

/// Surface for the main material in a custom_materials list, or null if there is none.
/proc/gun_feel_surface_of_materials(list/materials)
	if(!length(materials))
		return null
	var/main_type
	var/most = 0
	for(var/material in materials)
		var/amount = materials[material]
		if(!isnum(amount) || amount <= most)
			continue
		var/datum/material/as_datum = material
		var/material_type = ispath(material) ? material : (istype(as_datum) ? as_datum.type : null)
		if(!material_type)
			continue
		main_type = material_type
		most = amount
	if(!main_type)
		return null
	if(ispath(main_type, /datum/material/wood) || ispath(main_type, /datum/material/bamboo) || ispath(main_type, /datum/material/paper) || ispath(main_type, /datum/material/cardboard))
		return GUN_FEEL_SURFACE_WOOD
	if(ispath(main_type, /datum/material/glass) || ispath(main_type, /datum/material/alloy/plasmaglass) || ispath(main_type, /datum/material/alloy/titaniumglass) || ispath(main_type, /datum/material/alloy/plastitaniumglass) || ispath(main_type, /datum/material/diamond))
		return GUN_FEEL_SURFACE_GLASS
	if(ispath(main_type, /datum/material/sandstone) || ispath(main_type, /datum/material/sand) || ispath(main_type, /datum/material/bone))
		return GUN_FEEL_SURFACE_STONE
	if(ispath(main_type, /datum/material/snow))
		return GUN_FEEL_SURFACE_SNOW
	if(ispath(main_type, /datum/material/meat))
		return GUN_FEEL_SURFACE_FLESH
	return GUN_FEEL_SURFACE_METAL

// ---- Near misses ----

/mob/living
	/// Stops one mob hearing a whole shotgun blast whizz past as six separate bullets.
	COOLDOWN_DECLARE(gun_feel_whizz_cooldown)

/obj/projectile/bullet/scan_moved_turf()
	. = ..()
	if(!QDELETED(src) && !deletion_queued)
		gun_feel_near_miss()

/// Whizzes past and flinches every conscious mob next to this bullet that it hasn't already passed.
/// Suppressed rounds don't: a whizz would give away a shot nobody heard.
/obj/projectile/bullet/proc/gun_feel_near_miss()
	if(suppressed)
		return
	var/turf/here = loc
	if(!isturf(here) || !starting || get_dist(starting, here) < GUN_FEEL_NEAR_MISS_MIN_TRAVEL)
		return
	for(var/turf/nearby as anything in RANGE_TURFS(1, here))
		for(var/mob/living/bystander in nearby)
			if(bystander == firer || bystander.stat != CONSCIOUS)
				continue
			if(LAZYFIND(gun_feel_whizzed, bystander) || impacted[bystander.weak_reference])
				continue
			LAZYADD(gun_feel_whizzed, bystander)
			if(!COOLDOWN_FINISHED(bystander, gun_feel_whizz_cooldown))
				continue
			COOLDOWN_START(bystander, gun_feel_whizz_cooldown, GUN_FEEL_NEAR_MISS_COOLDOWN)
			if(bystander.client)
				bystander.playsound_local(here, SFX_GUN_FEEL_BULLET_MISS, GUN_FEEL_NEAR_MISS_VOLUME, TRUE, GUN_FEEL_PITCH(GUN_FEEL_IMPACT_PITCH_SPREAD))
			bystander.gun_feel_flinch(GUN_FEEL_NEAR_MISS_FLINCH, nearby == here ? null : get_dir(here, bystander))
