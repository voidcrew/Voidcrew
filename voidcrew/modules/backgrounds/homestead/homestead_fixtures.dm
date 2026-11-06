/// Backgrounds: owned by P6. See data/backgrounds/spec.md.

/obj/structure/water_source/homestead_well

/obj/structure/homestead_coop
	name = "nesting box"
	desc = "Straw and a lid. The hens like it."
	icon = 'icons/obj/storage/crates.dmi'
	icon_state = "wooden"
	anchored = TRUE

/obj/effect/mapping_helpers/homestead_crop
	/// The seed type planted in the soil tray on this tile, set on the map
	var/obj/item/seeds/crop

/obj/effect/landmark/homestead

/obj/effect/landmark/homestead/spouse
	name = "homestead spouse"

/obj/effect/landmark/homestead/child
	name = "homestead child"

/obj/effect/landmark/homestead/settler
	name = "homestead settler"
