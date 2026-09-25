// Voidcrew extensions to code/modules/mod/modules/modules_supply.dm.

// VOIDCREW EDIT: keep the bookkeeping list honest however ore leaves - dumped,
// stolen out by hand, or deleted (qdel nullspaces contents through Exited)
/obj/item/mod/module/orebag/Exited(atom/movable/gone, direction)
	. = ..()
	ores -= gone
