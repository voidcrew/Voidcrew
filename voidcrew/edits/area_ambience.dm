/// Voidcrew tracks added to tg's open space ambience.
GLOBAL_LIST_INIT(voidcrew_space_ambience, list(
	'voidcrew/sound/ambience/space.ogg',
))

/// Voidcrew tracks added to tg's ruin ambience, for space ruins only.
GLOBAL_LIST_INIT(voidcrew_space_ruin_ambience, list(
	'voidcrew/sound/ambience/space_ruins.ogg',
	'voidcrew/sound/ambience/space_ruins_2.ogg',
))

/area/space/Initialize(mapload)
	if(isnull(ambientsounds) && ambience_index == AMBIENCE_SPACE)
		ambientsounds = GLOB.space_ambience + GLOB.voidcrew_space_ambience
	return ..()

/area/ruin/space/Initialize(mapload)
	if(isnull(ambientsounds) && ambience_index == AMBIENCE_RUINS)
		ambientsounds = GLOB.ruins_ambience + GLOB.voidcrew_space_ruin_ambience
	return ..()

/area/overmap_encounter/planetoid
	/// Voidcrew tracks played alongside this planet's ambientsounds.
	var/list/added_ambience

/area/overmap_encounter/planetoid/Initialize(mapload)
	if(length(added_ambience))
		ambientsounds = ambientsounds + added_ambience
	return ..()
