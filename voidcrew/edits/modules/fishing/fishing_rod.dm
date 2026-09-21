// Voidcrew extensions to code/modules/fishing/fishing_rod.dm.

/obj/item/fishing_rod/rescue/examine(mob/user)
	. = ..()
	. += span_info("Cast it into a chasm to haul out anyone who fell in. \
		Any chasm on the same site reaches them - it doesn't have to be the exact hole they fell down. \
		It only retrieves people: mechs and lost gear have to be fished out with a regular hook or a magnet, at the chasm they fell into.")
// VOIDCREW EDIT END
