/**
 * # Chop Shop parlor fixtures
 *
 * Cosmetic hardware that dresses Splice's parlor. Right now that's the CHROME
 * sign: a 64x32 neon board that hangs over the counter and never goes dark. It
 * carries no power draw and no interaction — it exists to throw magenta light
 * on the operating cradle and tell the Dregs which door the ripperdoc is behind.
 */
/obj/machinery/chrome_sign
	name = "\improper CHROME sign"
	desc = "A neon board buzzing over the ripperdoc's counter. One letter flickers on a bad ballast; nobody's ever fixed it, and nobody ever will."
	icon = 'voidcrew/modules/cyberware/icons/cyberware_signs.dmi'
	icon_state = "chrome_sign"
	// 64x32 art: sits on one wall tile and reads across the two above the door.
	pixel_x = -16
	layer = ABOVE_WINDOW_LAYER
	density = FALSE
	anchored = TRUE
	use_power = NO_POWER_USE
	idle_power_usage = 0
	active_power_usage = 0
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Neon colour, thrown as light and baked into the emissive glow.
	var/neon_color = "#ff2079"

/obj/machinery/chrome_sign/Initialize(mapload)
	. = ..()
	set_light(3, 0.8, neon_color)
	update_appearance()

/obj/machinery/chrome_sign/update_overlays()
	. = ..()
	// The whole board is neon tubing, so the whole sprite self-illuminates —
	// it reads through the parlor's deliberately low light.
	. += emissive_appearance(icon, icon_state, src, alpha = src.alpha)

/// Kill the neon for a beat, then bring it back — the cradle stutters every
/// fixture in the room during a legend-tier install.
/obj/machinery/chrome_sign/proc/flicker()
	set_light(0)
	addtimer(CALLBACK(src, PROC_REF(relight)), rand(2, 5))

/obj/machinery/chrome_sign/proc/relight()
	set_light(3, 0.8, neon_color)
