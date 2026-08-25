/**
 * # Chop Shop parlor fixtures
 *
 * Cosmetic hardware that dresses Splice's parlor: the CHROME sign over the
 * door and the stock cases behind the counter glass.
 *
 * The sign is a 64x32 neon board that never goes dark. It carries no power
 * draw and no interaction, it exists to throw magenta light on the operating
 * cradle and tell the Dregs which door the ripperdoc is behind.
 *
 * The O runs on a failing ballast. That lives entirely in the icon: the
 * "chrome_sign" state is a 15-frame loop that leaves the letter dead for
 * seconds at a stretch, then catches and flares before dropping out again.
 * Frame one is the old static sprite, so the board's resting look is unchanged.
 */

// =========================================================================
// CHROME SIGN
// =========================================================================

/// Emissive left on the board while the neon is cut, enough to make out dead
/// tubing in a dark parlor, not enough to read as lit.
#define CHROME_SIGN_DARK_EMISSIVE 45

/obj/machinery/chrome_sign
	name = "\improper CHROME sign"
	desc = "A neon board buzzing over the ripperdoc's counter. One letter flickers on a bad ballast, and has done for years."
	icon = 'voidcrew/modules/cyberware/icons/cyberware_signs.dmi'
	icon_state = "chrome_sign"
	// 64x32 art: map it on the LEFT tile of a two-tile blank wall stretch.
	// It reads across that tile and the one to its right. Keep doors and
	// windows out from under it.
	pixel_x = 0
	layer = ABOVE_WINDOW_LAYER
	density = FALSE
	anchored = TRUE
	use_power = NO_POWER_USE
	idle_power_usage = 0
	active_power_usage = 0
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Neon colour, thrown as light and baked into the emissive glow.
	var/neon_color = "#ff2079"
	/// FALSE while the cradle has the neon browned out.
	var/lit = TRUE

/obj/machinery/chrome_sign/Initialize(mapload)
	. = ..()
	set_light(3, 0.8, neon_color)
	update_appearance()

/obj/machinery/chrome_sign/update_overlays()
	. = ..()
	// The whole board is neon tubing, so the whole sprite self-illuminates, it
	// reads through the parlor's deliberately low light, and sharing icon_state
	// with the base sprite gets the ballast flicker on the glow for free.
	//
	// Emission is alpha-keyed, not brightness-keyed: emissive_appearance throws
	// away the sprite's colour and lights whatever is opaque. The darkened
	// off-state sprite would glow exactly as hard as the lit one, so the cut has
	// to be made here rather than in the icon.
	. += emissive_appearance(icon, icon_state, src, alpha = lit ? src.alpha : CHROME_SIGN_DARK_EMISSIVE)

/// Kill the neon for a beat, then bring it back, the cradle stutters every
/// fixture in the room during a legend-tier install.
/obj/machinery/chrome_sign/proc/flicker()
	set_lit(FALSE)
	addtimer(CALLBACK(src, PROC_REF(relight)), rand(2, 5), TIMER_OVERRIDE | TIMER_UNIQUE)

/obj/machinery/chrome_sign/proc/relight()
	set_lit(TRUE)

/// Board, glow and thrown light move together. A sign that keeps burning after
/// its light is cut reads as a bug rather than as a brownout.
/obj/machinery/chrome_sign/proc/set_lit(new_lit)
	lit = new_lit
	icon_state = lit ? "chrome_sign" : "chrome_sign_off"
	set_light_on(lit)
	update_appearance()

#undef CHROME_SIGN_DARK_EMISSIVE

// =========================================================================
// STOCK DISPLAY CASES
// =========================================================================

/**
 * The parlor's stock display: real cases holding the real organ, stood along
 * the back wall of Splice's booth where customers read them through the
 * counter glass.
 *
 * Locked shut and indestructible like the rest of the outpost's property. The
 * stock base treats an empty req_access as "any ID card opens it", and the
 * booth counter is a climbable table, so a stock case here would hand tier 3
 * and 4 ware to anyone who wandered in with a spare ID. Chrome leaves this
 * room through the Cradle or not at all.
 */
/obj/structure/displaycase/chop_shop
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/structure/displaycase/chop_shop/allowed(mob/accessor)
	return FALSE

/obj/structure/displaycase/chop_shop/gorilla
	desc = "A myomer lattice stood upright on the pedestal, knuckle plates open. The tag underneath says ASK SPLICE; the scratches on the glass are from someone who didn't."
	start_showpiece_type = /obj/item/organ/cyberimp/cyberware/gorilla_arms

/obj/structure/displaycase/chop_shop/mantis
	desc = "A folded forearm housing on a stand, emitter rail lit low. The price tag has been turned face-down."
	start_showpiece_type = /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis

/obj/structure/displaycase/chop_shop/cascade
	desc = "A segmented chrome spine suspended upright in the case. The whole shop is arranged so you end up looking at it."
	start_showpiece_type = /obj/item/organ/cyberimp/cyberware/cascade
