/**
 * # Voidcrew virology: the spaceacillin pill
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). This is the counterplay half of the rework:
 * the ported PR's own argument is that the problem with virology was never that viruses were
 * strong, it was that the crew had no answer to one. A pill anyone can get from a vendor (see
 * voidcrew/edits/vending/medical.dm) is that answer - ten units of spaceacillin, enough to fight
 * a virus off and, per the reagent override in voidcrew/modules/virology/spaceacillin.dm, a
 * coin-flip chance of simply ending it.
 *
 * ## Path rebase
 *
 * The ported PR defines this as `/obj/item/reagent_containers/pill/antiviral`. This codebase has
 * no such type - pills were re-parented to `/obj/item/reagent_containers/applicator/pill`
 * (code/modules/reagents/reagent_containers/pill.dm), so every pill path in the port had to be
 * rebased. `rename_with_volume` and `icon_state = "pill1"` are inherited conventions from the
 * pills around it.
 */
/obj/item/reagent_containers/applicator/pill/antiviral
	name = "spaceacillin pill"
	desc = "Used to suppress the symptoms of disease, and possibly eliminate it."
	icon_state = "pill1"
	list_reagents = list(/datum/reagent/medicine/spaceacillin = 10)
	rename_with_volume = TRUE
