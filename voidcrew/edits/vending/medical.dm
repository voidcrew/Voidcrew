/**
 * # Voidcrew virology: the counterplay pills at the vendors
 *
 * Ported from tgstation #84356 / #89062 (hyperjll), which stocks the spaceacillin pill in
 * `/obj/machinery/vending/medical` ("NanoMed Plus") and `/obj/machinery/vending/wallmed`
 * ("Emergency NanoMed"). NanoMed Plus also gets isolated-symptom bottles, per the decision that
 * the random-symptom roll should be reachable from a vendor counter rather than only from the
 * virology fridge.
 *
 * `wallmed` matters more than it looks: it is the wall-mounted unit, and there are roughly two
 * hundred of them on the map files versus a few dozen NanoMed Plus units, most of which sit on
 * the legacy station layouts rather than on ships.
 *
 * ## Mechanism: append in Initialize, never re-declare the list
 *
 * `products` is a type-level list. Re-declaring `/obj/machinery/vending/medical` with a whole new
 * `products` list would work, but it silently pins a copy of upstream's seventeen entries - the
 * next upstream addition to that list would vanish with nobody the wiser. Appending before the
 * parent's Initialize keeps upstream's list authoritative and adds one entry. `+=` on an assoc
 * list overwrites the key rather than duplicating it, so this is idempotent if Initialize somehow
 * runs twice.
 *
 * ## READ THIS: the stock below is currently unreachable
 *
 * `/obj/machinery/vending/Initialize` is overridden in voidcrew/modules/vending/_vending.dm by a
 * four-line shim (`onstation = FALSE` after `..()`). Under DreamMaker's last-definition-wins
 * rule that shim REPLACES upstream's fifty-line `Initialize` - the one that calls
 * `build_inventories()` for mapped vendors. SpacemanDMM resolves
 * `/obj/machinery/vending/Initialize` to the Voidcrew file and nothing else, so as the code
 * stands no mapped vending machine anywhere in this codebase builds a stock list at spawn, and
 * the same override also drops `set_wires()`, the slogan list, `power_change()`, the payment
 * component / restock registration and `register_context()`.
 *
 * That is a pre-existing fork bug, not part of this port, and fixing it means copying upstream's
 * fifty-line Initialize into the Voidcrew edit so it can append `onstation = FALSE` - a change
 * that would switch every vendor on every map from inert to functioning, so it belongs in its own
 * reviewable PR rather than riding along with a virology port.
 *
 * The entries below are therefore written the drift-proof way and are correct, but they do nothing
 * until that override is repaired. The counterplay reachable TODAY is the survival-box pill
 * (voidcrew/edits/objects/items/storage/boxes/job_boxes.dm) and the stocked fridges
 * (voidcrew/edits/machinery/smartfridge.dm), both of which use different machinery and work.
 */
/obj/machinery/vending/medical/Initialize(mapload)
	products += list(
		/obj/item/reagent_containers/applicator/pill/antiviral = 5,
		/obj/item/reagent_containers/cup/bottle/random_symptom = 2,
	)
	return ..()

/obj/machinery/vending/wallmed/Initialize(mapload)
	products += list(
		/obj/item/reagent_containers/applicator/pill/antiviral = 3,
	)
	return ..()
