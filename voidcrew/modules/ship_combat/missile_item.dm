// Ship Combat Missiles
// Physical missile items that can be purchased from cargo and loaded into launchers

/obj/item/ship_combat_missile
	name = "ship missile"
	desc = "A heavy ship-to-ship missile. Load it into a missile launcher to fire at enemy vessels."
	icon = 'icons/obj/weapons/guns/ammo.dmi'
	icon_state = "rocketwarhead"
	inhand_icon_state = "rocketwarhead"
	w_class = WEIGHT_CLASS_BULKY
	/// Damage dealt on impact
	var/damage = MISSILE_DAMAGE_STANDARD
	/// Explosion devastation range
	var/explosion_devastation = MISSILE_EXPLOSION_DEVASTATION
	/// Explosion heavy range
	var/explosion_heavy = MISSILE_EXPLOSION_HEAVY
	/// Explosion light range
	var/explosion_light = MISSILE_EXPLOSION_LIGHT
	/// Explosion flame range
	var/explosion_flame = MISSILE_EXPLOSION_FLAME
	/// The missile effect type spawned when fired
	var/missile_effect_type = /obj/effect/ship_missile

/obj/item/ship_combat_missile/examine(mob/user)
	. = ..()
	. += span_notice("Damage output: [damage]")
	. += span_notice("Explosion radius: [explosion_light] tiles")

// ========== MISSILE VARIANTS ==========

/obj/item/ship_combat_missile/light
	name = "light ship missile"
	desc = "A smaller ship-to-ship missile. Less damage but cheaper to produce."
	icon_state = "rocketwarhead"
	w_class = WEIGHT_CLASS_NORMAL
	damage = MISSILE_DAMAGE_LIGHT
	explosion_heavy = 0
	explosion_light = 1
	explosion_flame = 1

/obj/item/ship_combat_missile/heavy
	name = "heavy ship missile"
	desc = "A massive ship-to-ship warhead. Devastating damage but expensive and bulky."
	icon_state = "rocketwarhead"
	w_class = WEIGHT_CLASS_HUGE
	damage = MISSILE_DAMAGE_HEAVY
	explosion_devastation = 1
	explosion_heavy = 2
	explosion_light = 3
	explosion_flame = 3

/obj/item/ship_combat_missile/incendiary
	name = "incendiary ship missile"
	desc = "A ship-to-ship missile with an incendiary payload. Sets the impact area ablaze."
	icon_state = "rocketwarhead"
	damage = MISSILE_DAMAGE_LIGHT
	explosion_heavy = 0
	explosion_light = 1
	explosion_flame = 4

/obj/item/ship_combat_missile/emp
	name = "EMP ship missile"
	desc = "A ship-to-ship missile with an electromagnetic pulse warhead. Disables electronics on impact."
	icon_state = "rocketwarhead"
	damage = MISSILE_DAMAGE_LIGHT
	explosion_heavy = 0
	explosion_light = 1
	explosion_flame = 0
	missile_effect_type = /obj/effect/ship_missile/emp
