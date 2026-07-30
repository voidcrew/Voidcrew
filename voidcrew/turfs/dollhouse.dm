// Dollhouse theme turfs (kilo "pink" ship theme): pastel wall + floor types.
// Icons are recolors of the stock shuttle wall / white floor sheets that
// preserve every smoothing junction state (voidcrew/icons/turf/...).

// ---------- Walls ----------

/turf/closed/wall/mineral/titanium/dollhouse
	name = "pastel wall"
	desc = "A light-weight titanium wall enameled in strawberry-cream pink. Absolutely spotless."
	icon = 'voidcrew/icons/turf/walls/dollhouse_wall.dmi'

/turf/closed/wall/mineral/titanium/dollhouse/nodiagonal
	icon = 'voidcrew/icons/turf/walls/dollhouse_wall.dmi'
	icon_state = "map-shuttle_nd"
	base_icon_state = "shuttle_wall"
	smoothing_flags = SMOOTH_BITMASK

// A false wall that pretends to be a pastel wall (the kilo hull hides one in
// engineering). Open animation states come from the stock false_walls sheet.
/obj/structure/falsewall/titanium/dollhouse
	desc = "A light-weight titanium wall enameled in strawberry-cream pink. Absolutely spotless."
	fake_icon = 'voidcrew/icons/turf/walls/dollhouse_wall.dmi'
	walltype = /turf/closed/wall/mineral/titanium/dollhouse

// ---------- Floors ----------

/turf/open/floor/iron/dollhouse
	name = "pastel deck"
	desc = "Soft pink decking, polished until it sparkles."
	icon = 'voidcrew/icons/turf/floors/dollhouse_floors.dmi'
	icon_state = "dollhouse"
	base_icon_state = "dollhouse"
	floor_tile = /obj/item/stack/tile/iron/white

/turf/open/floor/iron/dollhouse/white
	name = "blush deck"
	desc = "Clean white decking with rosy pink seams."
	icon_state = "dollhouse_white"
	base_icon_state = "dollhouse_white"

/turf/open/floor/iron/dollhouse/checker
	name = "candy checker deck"
	desc = "Pink and white checkerboard tiling, like a milkshake parlor."
	icon_state = "dollhouse_checker"
	base_icon_state = "dollhouse_checker"

// ---------- Grass ----------

// Behaves exactly like stock grass; the sheet is the same four tufts run through
// the theme's pink ramp, so the hydroponics lawn can stay a lawn on a pink ship.
/turf/open/floor/grass/dollhouse
	name = "pink lawn"
	desc = "Soft pastel turf. It smells faintly of strawberry."
	icon = 'voidcrew/icons/turf/floors/dollhouse_grass.dmi'
	icon_state = "dollhouse_grass0"

/turf/open/floor/grass/dollhouse/spawniconchange()
	icon_state = "dollhouse_grass[rand(0, 3)]"

// Our sheet carries no damage frame - borrow the stock grass scuff, which lives
// in damaged_dmi rather than in icon.
/turf/open/floor/grass/dollhouse/broken_states()
	return list("grass_damaged")
