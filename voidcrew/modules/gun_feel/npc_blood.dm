// Human NPCs bleed when shot: blood splatters off them and sometimes onto the floor, as it does off
// players. Basic mobs default to no blood, so create_projectile_hit_effects() showed nothing at all.
//
// The blood is only for show. Basic mobs never run handle_blood(), so they don't lose blood over time,
// never die of blood loss and have no wounds. Troopers are deleted on death and leave a separate corpse.

/mob/living/basic
	/// TRUE for NPCs that should have blood like a person. Only organic, non-robotic mobs get it.
	var/gun_feel_bleeds = FALSE

/mob/living/basic/Initialize(mapload)
	. = ..()
	if(gun_feel_bleeds && !blood_volume && (mob_biotypes & MOB_ORGANIC) && !(mob_biotypes & MOB_ROBOTIC))
		blood_volume = BLOOD_VOLUME_NORMAL

// Pirates, Russians, Nanotrasen, Syndicate and the rest of the trooper family.
/mob/living/basic/trooper
	gun_feel_bleeds = TRUE

// Voidcrew's other human NPCs.
/mob/living/basic/ambient_npc
	gun_feel_bleeds = TRUE

/mob/living/basic/mission_survivor
	gun_feel_bleeds = TRUE

/mob/living/basic/outpost_trader
	gun_feel_bleeds = TRUE

/mob/living/basic/outpost_kessler_staff
	gun_feel_bleeds = TRUE
