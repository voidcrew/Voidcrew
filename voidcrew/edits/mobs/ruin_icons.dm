// Static/editor fallbacks for dynamically assembled basic mobs used by legacy
// Voidcrew ruins. These states are sourced from Voidcrew-LRP's simple_human.dmi.

/mob/living/basic/skeleton/plasmaminer
	icon = 'voidcrew/icons/mob/legacy_ruin_mobs.dmi'

/mob/living/basic/cat_butcherer
	icon = 'voidcrew/icons/mob/legacy_ruin_mobs.dmi'
	icon_dead = null
	icon_gib = null

/mob/living/basic/dark_wizard
	icon = 'voidcrew/icons/mob/legacy_ruin_mobs.dmi'

// Pandora's inherited gib animation references "syndicate_gib", a state that
// does not exist in either the current or Voidcrew-LRP simple-animal assets.
/mob/living/simple_animal/hostile/asteroid/elite/pandora
	icon_gib = null

// These inherited gib animations reference "syndicate_gib", a state that does
// not exist in either the current or Voidcrew-LRP simple-animal assets.
/mob/living/simple_animal/hostile/asteroid/elite/herald
	icon_gib = null

/mob/living/basic/mining/goldgrub
	icon_gib = null

/mob/living/basic/mining/legion
	icon_gib = null

/mob/living/basic/legion_brood
	icon_gib = null

// The base clown drops a generated corpse and is deleted on death; its old
// declared death/gib states never existed in either current or LRP assets.
/mob/living/basic/clown
	icon_dead = null
	icon_gib = null
