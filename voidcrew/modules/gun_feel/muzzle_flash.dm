// Muzzle flash for powder guns: tg's muzzle_bullet sprite at the barrel, turned to the shot, plus a
// short cone of light thrown ahead of the shooter. After Shiptest's handle_muzzle_flash() and its
// directional gun light. Energy weapons already glow (their projectiles carry a light) and hitscan
// rounds already spawn a lit muzzle, so neither gets one.

/obj/item/ammo_casing
	/// FALSE for rounds that don't burn powder (darts, arrows, lenses, gumballs...).
	var/gun_feel_flash = TRUE

/obj/item/ammo_casing/energy
	gun_feel_flash = FALSE

/obj/item/ammo_casing/laser
	gun_feel_flash = FALSE

/obj/item/ammo_casing/foam_dart
	gun_feel_flash = FALSE

/obj/item/ammo_casing/arrow
	gun_feel_flash = FALSE

/obj/item/ammo_casing/rebar
	gun_feel_flash = FALSE

/obj/item/ammo_casing/harpoon
	gun_feel_flash = FALSE

/obj/item/ammo_casing/gumball
	gun_feel_flash = FALSE

/obj/item/ammo_casing/lollipop
	gun_feel_flash = FALSE

/obj/item/ammo_casing/pea
	gun_feel_flash = FALSE

/obj/item/ammo_casing/magic
	gun_feel_flash = FALSE

/obj/item/ammo_casing/syringegun
	gun_feel_flash = FALSE

/obj/item/ammo_casing/chemgun
	gun_feel_flash = FALSE

/obj/item/ammo_casing/dnainjector
	gun_feel_flash = FALSE

/// TRUE if the round that was just fired should flash.
/obj/item/gun/proc/gun_feel_wants_flash()
	if(suppressed)
		return FALSE
	var/obj/item/ammo_casing/casing = chambered
	if(!istype(casing) || !casing.gun_feel_flash || !casing.firing_effect_type)
		return FALSE
	var/obj/projectile/shot_type = casing.projectile_type
	if(ispath(shot_type, /obj/projectile) && initial(shot_type.hitscan) && initial(shot_type.muzzle_type))
		return FALSE
	return TRUE

/obj/item/gun/proc/gun_feel_muzzle_flash(mob/living/user, angle)
	if(!isturf(user.loc))
		return
	new /obj/effect/temp_visual/gun_feel_muzzle_flash(user, angle)
	if(QDELETED(gun_feel_light) || gun_feel_light.loc != user)
		gun_feel_clear_light()
		gun_feel_light = user.mob_light(GUN_FEEL_FLASH_LIGHT_RANGE, GUN_FEEL_FLASH_LIGHT_POWER, GUN_FEEL_FLASH_LIGHT_COLOR, null, /obj/effect/dummy/lighting_obj/moblight/gun_feel_muzzle)
		if(QDELETED(gun_feel_light))
			gun_feel_light = null
			return
		RegisterSignal(gun_feel_light, COMSIG_QDELETING, PROC_REF(gun_feel_light_deleted))
	// Each shot pushes the light-off back, so automatic fire keeps one light lit instead of making one per shot.
	addtimer(CALLBACK(src, PROC_REF(gun_feel_clear_light)), GUN_FEEL_FLASH_LIGHT_TIME, TIMER_UNIQUE | TIMER_OVERRIDE)

/// The flash light. Directional, like a flashlight: it follows the shooter's facing, and firing turns
/// the shooter to face the target, so the cone points down the line of fire.
/obj/effect/dummy/lighting_obj/moblight/gun_feel_muzzle
	name = "muzzle flash lighting"
	light_system = OVERLAY_LIGHT_DIRECTIONAL

/obj/item/gun/proc/gun_feel_clear_light()
	if(isnull(gun_feel_light))
		return
	UnregisterSignal(gun_feel_light, COMSIG_QDELETING)
	QDEL_NULL(gun_feel_light)

/obj/item/gun/proc/gun_feel_light_deleted(datum/source)
	SIGNAL_HANDLER
	gun_feel_light = null

/// The flash itself. It rides in the shooter's vis_contents so it stays at the barrel while they move.
/obj/effect/temp_visual/gun_feel_muzzle_flash
	name = "muzzle flash"
	icon = GUN_FEEL_FLASH_ICON
	icon_state = GUN_FEEL_FLASH_ICON_STATE
	layer = ABOVE_MOB_LAYER
	duration = GUN_FEEL_FLASH_TIME
	randomdir = FALSE
	appearance_flags = KEEP_APART | RESET_COLOR | TILE_BOUND | PIXEL_SCALE
	vis_flags = VIS_INHERIT_PLANE

/obj/effect/temp_visual/gun_feel_muzzle_flash/Initialize(mapload, angle = 0)
	. = ..()
	var/side = sin(angle)
	var/forward = cos(angle)
	// The barrel: out to the side, up when aiming away from the viewer, down when aiming at them.
	var/barrel_x = side * GUN_FEEL_FLASH_REACH_SIDE
	var/barrel_y = GUN_FEEL_FLASH_HAND_HEIGHT + forward * (forward > 0 ? GUN_FEEL_FLASH_REACH_UP : GUN_FEEL_FLASH_REACH_DOWN)
	// Push the sprite out so its bright core, not its centre, sits on the barrel.
	pixel_x = round(barrel_x + side * GUN_FEEL_FLASH_HOTSPOT)
	pixel_y = round(barrel_y + forward * GUN_FEEL_FLASH_HOTSPOT)
	var/matrix/turned = matrix()
	turned.Turn(angle)
	transform = turned
	// Aiming away from the viewer puts the barrel behind the shooter's body.
	if(forward > 0.5)
		layer = BELOW_MOB_LAYER
	if(ismovable(loc))
		var/atom/movable/shooter = loc
		shooter.vis_contents += src
