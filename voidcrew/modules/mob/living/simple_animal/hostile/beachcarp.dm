/mob/living/basic/carp/beach
	faction = list(FACTION_BEACH)
	name = "judge"
	desc = "A large, ferocious fish with massive fangs. It appears ready to attack."
	icon = 'voidcrew/icons/mob/beach/aquatic.dmi'
	icon_state = "judge"
	icon_living = "judge"
	icon_dead = "judge_dead" // lol
	greyscale_config = NONE // The beach sheet has no greyscale states to recolour.
	maxHealth = 40
	health = 40

/mob/living/basic/carp/beach/small
	name = "grump"
	desc = "A small, menacing fish with large fangs. It appears ready to attack."
	icon = 'voidcrew/icons/mob/beach/aquatic.dmi'
	icon_state = "grump"
	icon_living = "grump"
	icon_dead = "grump_dead"
	maxHealth = 10
	health = 10

/mob/living/basic/carp/beach/apply_colour()

/mob/living/basic/carp/mega/beach
	name = "shark"
	desc = "A vicious shark. It seems to have a lust for blood. Your blood."
	faction = list(FACTION_BEACH)
	icon = 'voidcrew/icons/mob/beach/aquatic.dmi'
	icon_state = "shark"
	icon_living = "shark"
	icon_dead = "shark_dead"
	greyscale_config = NONE // The beach sheet has no greyscale states to recolour.
	pixel_x = 0
	maxHealth = 50
	health = 50

/mob/living/basic/carp/mega/beach/Initialize(mapload)
	. = ..()
	// /mob/living/basic/carp/mega's Initialize renames itself off the megacarp name
	// lists, so the declared "shark" was arriving in the round as "Sharkbait Chum"
	// or similar. It also rolls extra health and melee on top of whatever the
	// subtype declared; that part is left alone.
	name = initial(name)

/mob/living/basic/carp/mega/beach/apply_colour()

