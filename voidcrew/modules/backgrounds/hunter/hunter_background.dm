/// Backgrounds: owned by P3. See data/backgrounds/spec.md.

/datum/background/bounty_hunter
	parent_type = /datum/background/hull_start
	key = BACKGROUND_BOUNTY_HUNTER
	name = "Bounty Hunter"
	hull_type = /datum/map_template/shuttle/voidcrew/marshal

/obj/structure/overmap/ship
	/// ckeys of everyone who has been aboard this hull while free. P3 fills it; P2 and P4 read it.
	var/list/background_ever_crew
