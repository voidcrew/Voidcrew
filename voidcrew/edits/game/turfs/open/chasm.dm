// Voidcrew extensions to code/game/turfs/open/chasm.dm.

/turf/open/chasm/examine(mob/user)
	. = ..()
	var/datum/component/chasm/chasm_comp = GetComponent(/datum/component/chasm)
	if(chasm_comp?.target_turf)
		. += span_info("Anything that falls in will land on the level below.")
	else
		. += span_info("Whatever falls in isn't destroyed - it gets caught in the depths. \
			A fishing rod fitted with a rescue hook can pull out anyone who fell into a chasm anywhere on this site; it doesn't have to be the exact hole they fell down. \
			Mechs and other lost gear can be fished back out with a regular hook or a magnet, but only at the chasm they actually fell into.")
