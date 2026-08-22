/**
 * Voidcrew: sunglasses are welding-rated again.
 *
 * Upstream dropped sunglasses to FLASH_PROTECTION_FLASH, which leaves a welder at
 * intensity 2 doing one point of damage through them every time it sparks. On a ship
 * where the only welding mask is usually in someone else's toolbox, that turned routine
 * hull repair into an eye-damage tax. Back to FLASH_PROTECTION_WELDER.
 *
 * Tint is deliberately left at 1. Tint is the downside of eye protection, not the source
 * of it, so sunglasses keep their lighter vision penalty while welding goggles keep tint 2
 * plus a flip-up visor and their fishing penalty. The tradeoff is that sunglasses are now
 * strictly the better welding eyewear, which is the point of the request.
 */
/obj/item/clothing/glasses/sunglasses
	desc = "Strangely ancient technology used to help provide rudimentary eye cover. Enhanced shielding blocks flashes and welding arcs."
	flash_protect = FLASH_PROTECTION_WELDER

// The HUD variants are a separate branch of the tree that re-declares flash protection,
// so they need it spelled out. Anything with "sunglasses" in the name and a tint gets it,
// for consistency - a security HUDSunglasses is a pair of sunglasses.
/obj/item/clothing/glasses/hud/health/sunglasses
	flash_protect = FLASH_PROTECTION_WELDER

/obj/item/clothing/glasses/hud/diagnostic/sunglasses
	flash_protect = FLASH_PROTECTION_WELDER

/obj/item/clothing/glasses/hud/security/sunglasses
	flash_protect = FLASH_PROTECTION_WELDER

/obj/item/clothing/glasses/hud/spacecop
	flash_protect = FLASH_PROTECTION_WELDER

// Deliberately NOT upgraded: /obj/item/clothing/glasses/hud/security/chameleon. It has no
// tint at all, so welding protection there would be a free upgrade with no cost attached.
