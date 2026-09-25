/**
 * # Voidcrew virology: the survival box carries spaceacillin
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). This is the counterplay the ported PR argues
 * the game actually needed: it is not that viruses were too strong, it is that a crew member who
 * caught one had nothing to do but sit outside medbay. Every crew member now spawns holding a
 * 10u spaceacillin pill (see voidcrew/modules/virology/pill.dm and the reagent override in
 * voidcrew/modules/virology/spaceacillin.dm), so the answer to "a disease got loose on my ship"
 * is in their own inventory.
 *
 * ## Why this copies the FORK's PopulateContents, not upstream's
 *
 * The ported diff patches upstream's version of this proc, which in this codebase is only part of
 * the story - Voidcrew added two more branches to it (`give_premium_goods` gating the flare and
 * radio, and `give_hook` gating the climbing hook) and the var list carries both flags. Pasted
 * from upstream, this override would silently delete the escape hook and the premium internals
 * goods from every survival box in the game. So the body below is the fork-local one, with the
 * pill `new` inserted after the medipen exactly where the port puts it.
 *
 * ## Scope
 *
 * `pill_type` is inherited by every survival box subtype, including
 * `/obj/item/storage/box/survival/prisoner`, which only clears `give_hook` and
 * `give_premium_goods`. That matches the ported PR's intent ("every survival box"), and a
 * prisoner holding a disease cure is not a balance problem worth a special case. Set
 * `pill_type = null` on a subtype if that ever changes.
 *
 * ## Path rebase
 *
 * The ported PR writes `/obj/item/reagent_containers/pill/antiviral`; this codebase re-parented
 * pills to `/obj/item/reagent_containers/applicator/pill`, so the default is rebased.
 *
 * If upstream retunes the survival box again, re-sync this proc by hand.
 */
/obj/item/storage/box/survival
	/// What medical pill should be present in this box?
	var/pill_type = /obj/item/reagent_containers/applicator/pill/antiviral

/obj/item/storage/box/survival/PopulateContents()
	if(crafted)
		return
	if(!isnull(mask_type))
		new mask_type(src)

	if(!isnull(internal_type))
		new internal_type(src)

	if(!isnull(medipen_type))
		new medipen_type(src)

	if(!isnull(pill_type))
		new pill_type(src)

	if(give_premium_goods && HAS_TRAIT(SSstation, STATION_TRAIT_PREMIUM_INTERNALS))
		new /obj/item/flashlight/flare(src)
		new /obj/item/radio/off(src)

	if(HAS_TRAIT(SSstation, STATION_TRAIT_RADIOACTIVE_NEBULA))
		new /obj/item/storage/pill_bottle/potassiodide(src)

	if(give_hook && length(SSmapping.levels_by_trait(ZTRAIT_STATION)) > 1 && SSmapping.current_map.give_players_hooks)
		new /obj/item/climbing_hook/emergency(src)
