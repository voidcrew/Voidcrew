// Gut spill (hyperviolence, braingut part): the gore item that lands on the floor when a victim is
// disemboweled. Sprite drawn for this module (icons/gore_guts.dmi); the idea of guts on a tether
// comes from Vanderlin (Monkestation/Vanderlin 1fc0bf8, AGPL code, CC BY-SA 3.0 art) but neither
// its code nor its art is copied here.

/// A coil of someone's intestines, spilled by a disemboweling wound. Plain item: it is not an organ,
/// so nothing counts it as a body part and surgery never holds it.
/obj/item/hv_intestines
	name = "intestines"
	desc = "Someone's intestines. There is a lot more of it than there seems to be room for."
	icon = 'voidcrew/modules/hyperviolence/braingut/icons/gore_guts.dmi'
	icon_state = "intestines"
	w_class = WEIGHT_CLASS_BULKY
	item_flags = NOBLUDGEON
	force = 0
	throwforce = 0
	throw_range = 3
	drop_sound = 'sound/misc/moist_impact.ogg'
	pickup_sound = 'sound/misc/moist_impact.ogg'
	sound_vary = TRUE

/obj/item/hv_intestines/Initialize(mapload)
	. = ..()
	pixel_x = base_pixel_x + rand(-6, 6)
	pixel_y = base_pixel_y + rand(-5, 5)
