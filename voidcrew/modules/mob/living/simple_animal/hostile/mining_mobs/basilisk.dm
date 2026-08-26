
/mob/living/basic/mining/watcher/magmawing/wasteland
	faction = list(FACTION_WASTELAND)

// Ported from Voidcrew-LRP: a watcher deformed by a cancerous crystal growth.
/mob/living/basic/mining/watcher/forgotten
	name = "forgotten watcher"
	desc = "This watcher has a cancerous crystal growth on it, forever scarring it and deforming it into this twisted form."
	icon = 'voidcrew/icons/mob/watcher.dmi'
	icon_state = "forgotten"
	icon_living = "forgotten"
	icon_dead = "forgotten_dead"
	pixel_x = -10
	base_pixel_x = -10
	// Our sheet is the ice-wing palette, not the stock watcher's: the parent
	// default "watcher_glow" only exists in tg's sheet, so the ready-to-fire
	// eye overlay resolved to nothing once icon moved here.
	eye_glow = "ice_glow"
	maxHealth = 250
	health = 250
	melee_damage_lower = 25
	melee_damage_upper = 25
	projectile_type = /obj/projectile/temp/watcher/ice_wing
	gaze_attack = /datum/action/cooldown/mob_cooldown/watcher_gaze/ice
	butcher_results = list(
		/obj/item/stack/ore/diamond = 3,
		/obj/item/stack/sheet/sinew = 2,
		/obj/item/stack/sheet/bone = 2,
	)

/mob/living/basic/mining/watcher/forgotten/wasteland
	faction = list(FACTION_WASTELAND)
